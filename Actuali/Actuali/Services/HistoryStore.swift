import Foundation
import Combine

struct HistorySplitPortionSnapshot: Codable, Equatable {
    var categoryName: String?
    var amount: Int
    init(_ value: Transaction.SplitPortion) { categoryName = value.categoryName; amount = value.amount }
    func value() -> Transaction.SplitPortion { Transaction.SplitPortion(categoryName: categoryName, amount: amount) }
}

struct HistoryTransactionSnapshot: Codable, Equatable, Identifiable {
    let id: String
    var accountId: String; var date: Int; var amount: Int
    var payeeId: String?; var payeeName: String?
    var categoryId: String?; var categoryName: String?; var notes: String?
    var cleared: Bool; var reconciled: Bool; var transferId: String?
    var isParent: Bool; var parentId: String?; var tombstone: Bool
    var sortOrder: Double?; var importedPayee: String?; var schedule: String?
    var financialId: String?; var startingBalanceFlag: Bool; var transferAcct: String?
    var splitPortions: [HistorySplitPortionSnapshot]?

    init(_ tx: Transaction) {
        id=tx.id; accountId=tx.accountId; date=tx.date; amount=tx.amount
        payeeId=tx.payeeId; payeeName=tx.payeeName; categoryId=tx.categoryId; categoryName=tx.categoryName; notes=tx.notes
        cleared=tx.cleared; reconciled=tx.reconciled; transferId=tx.transferId; isParent=tx.isParent; parentId=tx.parentId; tombstone=tx.tombstone
        sortOrder=tx.sortOrder; importedPayee=tx.importedPayee; schedule=tx.schedule; financialId=tx.financialId
        startingBalanceFlag=tx.startingBalanceFlag; transferAcct=tx.transferAcct; splitPortions=tx.splitPortions?.map(HistorySplitPortionSnapshot.init)
    }

    func transaction() -> Transaction {
        Transaction(id:id, accountId:accountId, date:date, amount:amount, payeeId:payeeId, payeeName:payeeName,
                    categoryId:categoryId, categoryName:categoryName, notes:notes, cleared:cleared, reconciled:reconciled,
                    transferId:transferId, isParent:isParent, parentId:parentId, tombstone:tombstone, sortOrder:sortOrder,
                    importedPayee:importedPayee, schedule:schedule, financialId:financialId, startingBalanceFlag:startingBalanceFlag,
                    transferAcct:transferAcct, splitPortions:splitPortions?.map { $0.value() })
    }
}

enum HistoryActionKind: String, Codable { case created, edited, deleted }
enum HistoryActionStatus: String, Codable { case applied, undone }

struct HistoryAction: Identifiable, Codable, Equatable {
    let id: String; let createdAt: Date; let budgetID: String; let kind: HistoryActionKind
    let before: [HistoryTransactionSnapshot]; let after: [HistoryTransactionSnapshot]
    var status: HistoryActionStatus

    var primarySnapshot: HistoryTransactionSnapshot? { after.first(where: { $0.parentId == nil }) ?? after.first ?? before.first }
    var title: String {
        if after.count == 2, after.allSatisfy({ $0.transferId != nil }) { return kind == .created ? "Created transfer" : "Edited transfer" }
        if after.contains(where: { $0.isParent }) { return kind == .created ? "Added split transaction" : "Edited split transaction" }
        let name = primarySnapshot?.payeeName.flatMap { $0.isEmpty ? nil : $0 } ?? "Transaction"
        switch kind { case .created: return "Added \(name)"; case .edited: return "Edited \(name)"; case .deleted: return "Deleted \(name)" }
    }
    var detail: String { primarySnapshot.map { Transaction.formattedDate(from: $0.date) } ?? "" }
    var amountText: String? {
        guard let amount = primarySnapshot?.amount else { return nil }
        return "\(amount < 0 ? "−" : "")$\(String(format: "%.2f", Double(abs(amount))/100.0))"
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
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    func load(budgetID: String) {
        guard let data = defaults.data(forKey: key(budgetID)), let decoded = try? JSONDecoder().decode([HistoryAction].self, from: data) else { actions=[]; return }
        actions = decoded.sorted { $0.createdAt > $1.createdAt }
    }

    func record(budgetID: String, kind: HistoryActionKind, before: [Transaction], after: [Transaction]) {
        guard !Self.recordingSuppressed, !before.isEmpty || !after.isEmpty else { return }
        actions.insert(HistoryAction(id: UUID().uuidString, createdAt: Date(), budgetID: budgetID, kind: kind,
                                     before: before.map(HistoryTransactionSnapshot.init), after: after.map(HistoryTransactionSnapshot.init), status: .applied), at: 0)
        actions = Array(actions.prefix(25)); save(budgetID)
    }

    func canUndo(_ action: HistoryAction) -> Bool { action.status == .applied && actions.first(where: { $0.status == .applied })?.id == action.id }
    func clearError() { errorMessage = nil }

    func undo(_ action: HistoryAction, using budgetStore: BudgetStore) async {
        guard canUndo(action), action.budgetID == budgetStore.currentBudgetId else { return }
        errorMessage=nil
        let live = Dictionary(uniqueKeysWithValues: budgetStore.transactions.map { ($0.id,$0) })
        for expected in action.after {
            if expected.tombstone { if live[expected.id] != nil { errorMessage="This action changed after it was recorded, so it cannot be safely undone."; return } }
            else if live[expected.id].map(HistoryTransactionSnapshot.init) != expected { errorMessage="This action changed after it was recorded, so it cannot be safely undone."; return }
        }

        let expected: [HistoryTransactionSnapshot] = action.kind == .created ? [] : action.before
        let removedIDs: Set<String> = action.kind == .created ? Set(action.after.map(\.id)) : []
        Self.pendingUndo = PendingUndo(budgetID: action.budgetID, expected: expected, removedIDs: removedIDs)
        Self.recordingSuppressed=true
        do {
            switch action.kind {
            case .created:
                budgetStore.error=nil
                await budgetStore.deleteTransactions(action.after.filter { $0.parentId == nil }.map { $0.transaction() })
                guard budgetStore.error == nil else { errorMessage=budgetStore.error; Self.finishUndoRecording(); return }
            case .edited, .deleted:
                let afterByID=Dictionary(uniqueKeysWithValues: action.after.map { ($0.id,$0) })
                for previous in action.before {
                    guard let recordedAfter=afterByID[previous.id] else { errorMessage="The recorded action is incomplete and cannot be safely undone."; Self.finishUndoRecording(); return }
                    try await budgetStore.updateTransaction(previous.transaction(), original: recordedAfter.transaction())
                }
            }
        } catch { errorMessage=error.localizedDescription; Self.finishUndoRecording(); return }
        guard let index=actions.firstIndex(where: { $0.id == action.id }) else { Self.finishUndoRecording(); return }
        actions[index].status = .undone; save(action.budgetID)
    }

    static func finishUndoRecording() {
        recordingSuppressed=false
        pendingUndo=nil
    }

    #if DEBUG
    func appendForTesting(_ action: HistoryAction, budgetID: String) { actions.insert(action, at: 0); actions=Array(actions.prefix(25)); save(budgetID) }
    #endif

    private func key(_ budgetID: String) -> String { "history.actions.\(budgetID)" }
    private func save(_ budgetID: String) { if let data=try? JSONEncoder().encode(actions) { defaults.set(data, forKey:key(budgetID)) } }
}
