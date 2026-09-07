import Foundation
import Combine

struct HistorySplitPortionSnapshot: Codable, Equatable {
    var categoryName: String?
    var amount: Int

    init(_ value: Transaction.SplitPortion) {
        categoryName = value.categoryName
        amount = value.amount
    }

    func value() -> Transaction.SplitPortion {
        Transaction.SplitPortion(categoryName: categoryName, amount: amount)
    }
}

struct HistoryTransactionSnapshot: Codable, Equatable, Identifiable {
    let id: String
    var accountId: String
    var date: Int
    var amount: Int
    var payeeId: String?
    var payeeName: String?
    var categoryId: String?
    var categoryName: String?
    var notes: String?
    var cleared: Bool
    var reconciled: Bool
    var transferId: String?
    var isParent: Bool
    var parentId: String?
    var tombstone: Bool
    var sortOrder: Double?
    var importedPayee: String?
    var schedule: String?
    var financialId: String?
    var startingBalanceFlag: Bool
    var transferAcct: String?
    var splitPortions: [HistorySplitPortionSnapshot]?

    init(_ tx: Transaction) {
        id = tx.id
        accountId = tx.accountId
        date = tx.date
        amount = tx.amount
        payeeId = tx.payeeId
        payeeName = tx.payeeName
        categoryId = tx.categoryId
        categoryName = tx.categoryName
        notes = tx.notes
        cleared = tx.cleared
        reconciled = tx.reconciled
        transferId = tx.transferId
        isParent = tx.isParent
        parentId = tx.parentId
        tombstone = tx.tombstone
        sortOrder = tx.sortOrder
        importedPayee = tx.importedPayee
        schedule = tx.schedule
        financialId = tx.financialId
        startingBalanceFlag = tx.startingBalanceFlag
        transferAcct = tx.transferAcct
        splitPortions = tx.splitPortions?.map(HistorySplitPortionSnapshot.init)
    }

    func transaction() -> Transaction {
        Transaction(
            id: id,
            accountId: accountId,
            date: date,
            amount: amount,
            payeeId: payeeId,
            payeeName: payeeName,
            categoryId: categoryId,
            categoryName: categoryName,
            notes: notes,
            cleared: cleared,
            reconciled: reconciled,
            transferId: transferId,
            isParent: isParent,
            parentId: parentId,
            tombstone: tombstone,
            sortOrder: sortOrder,
            importedPayee: importedPayee,
            schedule: schedule,
            financialId: financialId,
            startingBalanceFlag: startingBalanceFlag,
            transferAcct: transferAcct,
            splitPortions: splitPortions?.map { $0.value() }
        )
    }

    /// Compares the stable transaction state available from the normal fetch
    /// path. Display-only values, insert-only values that aren't read back,
    /// and `sortOrder` normalization must not make a live row look different
    /// from the snapshot that was recorded.
    func matchesLiveTransaction(_ transaction: Transaction) -> Bool {
        id == transaction.id &&
        accountId == transaction.accountId &&
        date == transaction.date &&
        amount == transaction.amount &&
        payeeId == transaction.payeeId &&
        categoryId == transaction.categoryId &&
        notes == transaction.notes &&
        cleared == transaction.cleared &&
        reconciled == transaction.reconciled &&
        transferId == transaction.transferId &&
        isParent == transaction.isParent &&
        parentId == transaction.parentId &&
        tombstone == transaction.tombstone &&
        importedPayee == transaction.importedPayee &&
        schedule == transaction.schedule
    }
}

enum HistoryActionKind: String, Codable {
    case created
    case edited
    case deleted
}

enum HistoryActionStatus: String, Codable {
    case applied
    case undone
}

struct HistoryAction: Identifiable, Codable, Equatable {
    let id: String
    let createdAt: Date
    let budgetID: String
    let kind: HistoryActionKind
    let before: [HistoryTransactionSnapshot]
    let after: [HistoryTransactionSnapshot]
    var status: HistoryActionStatus

    var primarySnapshot: HistoryTransactionSnapshot? {
        after.first(where: { $0.parentId == nil }) ?? after.first ?? before.first
    }

    var title: String {
        if after.count == 2, after.allSatisfy({ $0.transferId != nil }) {
            switch kind {
            case .created: return "Created transfer"
            case .edited: return "Edited transfer"
            case .deleted: return "Deleted transfer"
            }
        }
        if after.contains(where: { $0.isParent }) {
            switch kind {
            case .created: return "Added split transaction"
            case .edited: return "Edited split transaction"
            case .deleted: return "Deleted split transaction"
            }
        }
        let name = primarySnapshot?.payeeName.flatMap { $0.isEmpty ? nil : $0 } ?? "Transaction"
        switch kind {
        case .created: return "Added \(name)"
        case .edited: return "Edited \(name)"
        case .deleted: return "Deleted \(name)"
        }
    }

    var detail: String {
        primarySnapshot.map { Transaction.formattedDate(from: $0.date) } ?? ""
    }

    var amountText: String? {
        guard let amount = primarySnapshot?.amount else { return nil }
        return "\(amount < 0 ? "−" : "")$\(String(format: "%.2f", Double(abs(amount)) / 100.0))"
    }
}

@MainActor
final class HistoryStore: ObservableObject {
    static let shared = HistoryStore()
    static var recordingSuppressed = false

    struct PendingUndo {
        let budgetID: String
        let expected: [HistoryTransactionSnapshot]
        let removedIDs: Set<String>
    }

    static var pendingUndo: PendingUndo?

    @Published private(set) var actions: [HistoryAction] = []
    @Published private(set) var errorMessage: String?

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load(budgetID: String) {
        guard let data = defaults.data(forKey: key(budgetID)) else {
            clearLoadedActions()
            return
        }
        guard let decoded = try? JSONDecoder().decode([HistoryAction].self, from: data) else {
            actions = []
            errorMessage = "History couldn't be loaded. New history will continue from here."
            return
        }
        errorMessage = nil
        actions = decoded.sorted { $0.createdAt > $1.createdAt }
    }

    func clearLoadedActions() {
        actions = []
        errorMessage = nil
    }

    func record(budgetID: String, kind: HistoryActionKind, before: [Transaction], after: [Transaction]) {
        guard !Self.recordingSuppressed, !before.isEmpty || !after.isEmpty else { return }
        actions.insert(
            HistoryAction(
                id: UUID().uuidString,
                createdAt: Date(),
                budgetID: budgetID,
                kind: kind,
                before: before.map(HistoryTransactionSnapshot.init),
                after: after.map(HistoryTransactionSnapshot.init),
                status: .applied
            ),
            at: 0
        )
        actions = Array(actions.prefix(10))
        save(budgetID)
    }

    func canUndo(_ action: HistoryAction) -> Bool {
        action.status == .applied && actions.first(where: { $0.status == .applied })?.id == action.id
    }

    func clearError() {
        errorMessage = nil
    }

    func undo(_ action: HistoryAction, using budgetStore: BudgetStore) async {
        guard canUndo(action), action.budgetID == budgetStore.currentBudgetId else { return }
        errorMessage = nil

        let live = Dictionary(uniqueKeysWithValues: budgetStore.transactions.map { ($0.id, $0) })
        for expected in action.after {
            if expected.tombstone {
                if live[expected.id] != nil {
                    errorMessage = "This action changed after it was recorded, so it cannot be safely undone."
                    return
                }
            } else if let actual = live[expected.id], !expected.matchesLiveTransaction(actual) {
                errorMessage = "This action changed after it was recorded, so it cannot be safely undone."
                return
            } else if live[expected.id] == nil {
                errorMessage = "This action changed after it was recorded, so it cannot be safely undone."
                return
            }
        }

        let expected: [HistoryTransactionSnapshot] = action.kind == .created ? [] : action.before
        let removedIDs: Set<String> = action.kind == .created ? Set(action.after.map(\.id)) : []
        Self.pendingUndo = PendingUndo(budgetID: action.budgetID, expected: expected, removedIDs: removedIDs)
        Self.recordingSuppressed = true

        do {
            switch action.kind {
            case .created:
                budgetStore.error = nil
                await budgetStore.deleteTransactions(
                    action.after
                        .filter { $0.parentId == nil }
                        .map { $0.transaction() }
                )
                guard budgetStore.error == nil else {
                    errorMessage = budgetStore.error
                    Self.finishUndoRecording()
                    return
                }
            case .edited, .deleted:
                let afterByID = Dictionary(uniqueKeysWithValues: action.after.map { ($0.id, $0) })
                for previous in action.before {
                    guard let recordedAfter = afterByID[previous.id] else {
                        errorMessage = "The recorded action is incomplete and cannot be safely undone."
                        Self.finishUndoRecording()
                        return
                    }
                    guard let current = live[previous.id], recordedAfter.matchesLiveTransaction(current) else {
                        errorMessage = "This action changed after it was recorded, so it cannot be safely undone."
                        Self.finishUndoRecording()
                        return
                    }
                }
                try await budgetStore.restoreTransactions(
                    action.before.map { $0.transaction() },
                    from: action.after.map { $0.transaction() }
                )
            }
        } catch {
            errorMessage = error.localizedDescription
            Self.finishUndoRecording()
            return
        }

        guard let index = actions.firstIndex(where: { $0.id == action.id }) else {
            Self.finishUndoRecording()
            return
        }
        actions[index].status = .undone
        save(action.budgetID)
        Self.finishUndoRecording()
    }

    static func finishUndoRecording() {
        recordingSuppressed = false
        pendingUndo = nil
    }

    #if DEBUG
    func appendForTesting(_ action: HistoryAction, budgetID: String) {
        actions.insert(action, at: 0)
        actions = Array(actions.prefix(10))
        save(budgetID)
    }
    #endif

    private func key(_ budgetID: String) -> String {
        "history.actions.\(budgetID)"
    }

    private func save(_ budgetID: String) {
        guard let data = try? JSONEncoder().encode(actions) else { return }
        defaults.set(data, forKey: key(budgetID))
    }
}
