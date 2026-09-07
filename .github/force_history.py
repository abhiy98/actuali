from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def replace_once(path: str, old: str, new: str) -> None:
    file = ROOT / path
    text = file.read_text()
    if text.count(old) != 1:
        raise SystemExit(f"Expected exactly one match in {path}; found {text.count(old)}")
    file.write_text(text.replace(old, new, 1))


history_store = r'''import Foundation
import Combine

/// A local, device-only record of one user-visible transaction mutation.
/// Snapshots keep undo independent of the current published transaction list.
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
    var splitPortions: [Transaction.SplitPortion]?

    init(_ transaction: Transaction) {
        id = transaction.id
        accountId = transaction.accountId
        date = transaction.date
        amount = transaction.amount
        payeeId = transaction.payeeId
        payeeName = transaction.payeeName
        categoryId = transaction.categoryId
        categoryName = transaction.categoryName
        notes = transaction.notes
        cleared = transaction.cleared
        reconciled = transaction.reconciled
        transferId = transaction.transferId
        isParent = transaction.isParent
        parentId = transaction.parentId
        tombstone = transaction.tombstone
        sortOrder = transaction.sortOrder
        importedPayee = transaction.importedPayee
        schedule = transaction.schedule
        financialId = transaction.financialId
        startingBalanceFlag = transaction.startingBalanceFlag
        transferAcct = transaction.transferAcct
        splitPortions = transaction.splitPortions
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
            splitPortions: splitPortions
        )
    }
}

// Transaction.SplitPortion is Hashable but intentionally not Codable in the
// app model, so history stores the display-only split breakdown separately.
extension HistoryTransactionSnapshot {
    enum CodingKeys: String, CodingKey {
        case id, accountId, date, amount, payeeId, payeeName, categoryId, categoryName
        case notes, cleared, reconciled, transferId, isParent, parentId, tombstone
        case sortOrder, importedPayee, schedule, financialId, startingBalanceFlag
        case transferAcct, splitPortions
    }

    struct SplitPortionSnapshot: Codable, Equatable {
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

    private enum SplitStorage {
        static func encode(_ values: [Transaction.SplitPortion]?) -> [SplitPortionSnapshot]? {
            values?.map(SplitPortionSnapshot.init)
        }
        static func decode(_ values: [SplitPortionSnapshot]?) -> [Transaction.SplitPortion]? {
            values?.map { $0.value() }
        }
    }
}

extension HistoryTransactionSnapshot: Encodable {
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(accountId, forKey: .accountId)
        try container.encode(date, forKey: .date)
        try container.encode(amount, forKey: .amount)
        try container.encode(payeeId, forKey: .payeeId)
        try container.encode(payeeName, forKey: .payeeName)
        try container.encode(categoryId, forKey: .categoryId)
        try container.encode(categoryName, forKey: .categoryName)
        try container.encode(notes, forKey: .notes)
        try container.encode(cleared, forKey: .cleared)
        try container.encode(reconciled, forKey: .reconciled)
        try container.encode(transferId, forKey: .transferId)
        try container.encode(isParent, forKey: .isParent)
        try container.encode(parentId, forKey: .parentId)
        try container.encode(tombstone, forKey: .tombstone)
        try container.encode(sortOrder, forKey: .sortOrder)
        try container.encode(importedPayee, forKey: .importedPayee)
        try container.encode(schedule, forKey: .schedule)
        try container.encode(financialId, forKey: .financialId)
        try container.encode(startingBalanceFlag, forKey: .startingBalanceFlag)
        try container.encode(transferAcct, forKey: .transferAcct)
        try container.encode(SplitStorage.encode(splitPortions), forKey: .splitPortions)
    }
}

extension HistoryTransactionSnapshot: Decodable {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        accountId = try container.decode(String.self, forKey: .accountId)
        date = try container.decode(Int.self, forKey: .date)
        amount = try container.decode(Int.self, forKey: .amount)
        payeeId = try container.decodeIfPresent(String.self, forKey: .payeeId)
        payeeName = try container.decodeIfPresent(String.self, forKey: .payeeName)
        categoryId = try container.decodeIfPresent(String.self, forKey: .categoryId)
        categoryName = try container.decodeIfPresent(String.self, forKey: .categoryName)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        cleared = try container.decode(Bool.self, forKey: .cleared)
        reconciled = try container.decode(Bool.self, forKey: .reconciled)
        transferId = try container.decodeIfPresent(String.self, forKey: .transferId)
        isParent = try container.decode(Bool.self, forKey: .isParent)
        parentId = try container.decodeIfPresent(String.self, forKey: .parentId)
        tombstone = try container.decode(Bool.self, forKey: .tombstone)
        sortOrder = try container.decodeIfPresent(Double.self, forKey: .sortOrder)
        importedPayee = try container.decodeIfPresent(String.self, forKey: .importedPayee)
        schedule = try container.decodeIfPresent(String.self, forKey: .schedule)
        financialId = try container.decodeIfPresent(String.self, forKey: .financialId)
        startingBalanceFlag = try container.decode(Bool.self, forKey: .startingBalanceFlag)
        transferAcct = try container.decodeIfPresent(String.self, forKey: .transferAcct)
        let stored = try container.decodeIfPresent([SplitPortionSnapshot].self, forKey: .splitPortions)
        splitPortions = SplitStorage.decode(stored)
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
            return kind == .created ? "Created transfer" : "Edited transfer"
        }
        if after.contains(where: \ .isParent) {
            return kind == .created ? "Added split transaction" : "Edited split transaction"
        }
        let name = primarySnapshot?.payeeName?.isEmpty == false
            ? (primarySnapshot?.payeeName ?? "Transaction")
            : "Transaction"
        switch kind {
        case .created: return "Added \(name)"
        case .edited: return "Edited \(name)"
        case .deleted: return "Deleted \(name)"
        }
    }

    var detail: String {
        let snapshot = primarySnapshot
        let date = snapshot.map { Transaction.formattedDate(from: $0.date) } ?? ""
        return date
    }

    var amountText: String? {
        guard let amount = primarySnapshot?.amount else { return nil }
        let sign = amount < 0 ? "−" : ""
        return "\(sign)$\(String(format: "%.2f", Double(abs(amount)) / 100.0))"
    }
}

@MainActor
final class HistoryStore: ObservableObject {
    static let shared = HistoryStore()
    static var recordingSuppressed = false

    @Published private(set) var actions: [HistoryAction] = []
    @Published private(set) var errorMessage: String?

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load(budgetID: String) {
        guard let data = defaults.data(forKey: key(for: budgetID)),
              let decoded = try? decoder.decode([HistoryAction].self, from: data) else {
            actions = []
            return
        }
        actions = decoded.sorted { $0.createdAt > $1.createdAt }
    }

    func record(
        budgetID: String,
        kind: HistoryActionKind,
        before: [Transaction],
        after: [Transaction]
    ) {
        guard !Self.recordingSuppressed, !before.isEmpty || !after.isEmpty else { return }
        var updated = actions
        updated.insert(
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
        actions = Array(updated.prefix(25))
        save(budgetID: budgetID)
    }

    func canUndo(_ action: HistoryAction) -> Bool {
        action.status == .applied && actions.first(where: { $0.status == .applied })?.id == action.id
    }

    func undo(_ action: HistoryAction, using budgetStore: BudgetStore) async {
        guard canUndo(action), action.budgetID == budgetStore.currentBudgetId else { return }
        errorMessage = nil

        // LIFO + equality against the recorded after-state keeps an undo from
        // overwriting a newer local or remote change. Tombstoned rows are absent
        // from the published list, which is exactly the expected post-delete state.
        let live = Dictionary(uniqueKeysWithValues: budgetStore.transactions.map { ($0.id, $0) })
        for expected in action.after {
            if expected.tombstone {
                if live[expected.id] != nil {
                    errorMessage = "This action changed after it was recorded, so it cannot be safely undone."
                    return
                }
            } else if live[expected.id].map(HistoryTransactionSnapshot.init) != expected {
                errorMessage = "This action changed after it was recorded, so it cannot be safely undone."
                return
            }
        }

        Self.recordingSuppressed = true
        defer { Self.recordingSuppressed = false }

        do {
            switch action.kind {
            case .created:
                let roots = action.after
                    .filter { $0.parentId == nil }
                    .map { $0.transaction() }
                budgetStore.error = nil
                await budgetStore.deleteTransactions(roots)
                if budgetStore.error != nil {
                    errorMessage = budgetStore.error
                    return
                }
            case .edited, .deleted:
                let afterByID = Dictionary(uniqueKeysWithValues: action.after.map { ($0.id, $0) })
                for previous in action.before {
                    guard let recordedAfter = afterByID[previous.id] else {
                        errorMessage = "The recorded action is incomplete and cannot be safely undone."
                        return
                    }
                    try await budgetStore.updateTransaction(
                        previous.transaction(),
                        original: recordedAfter.transaction()
                    )
                }
            }
        } catch {
            errorMessage = error.localizedDescription
            return
        }

        guard let index = actions.firstIndex(where: { $0.id == action.id }) else { return }
        actions[index].status = .undone
        save(budgetID: action.budgetID)
    }

    private func key(for budgetID: String) -> String {
        "history.actions.\(budgetID)"
    }

    private func save(budgetID: String) {
        guard let data = try? encoder.encode(actions) else { return }
        defaults.set(data, forKey: key(for: budgetID))
    }
}
'''

history_view = r'''import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var budgetStore: BudgetStore
    @StateObject private var historyStore = HistoryStore.shared
    @State private var selectedAction: HistoryAction?

    var body: some View {
        List {
            if historyStore.actions.isEmpty {
                ContentUnavailableView(
                    "No History Yet",
                    systemImage: "clock",
                    description: Text("Transactions you add, edit, or delete on this device will appear here.")
                )
            } else {
                ForEach(historyStore.actions) { action in
                    HistoryRow(action: action, canUndo: historyStore.canUndo(action)) {
                        selectedAction = action
                    }
                }
            }
        }
        .navigationTitle("History")
        .task {
            if let budgetID = budgetStore.currentBudgetId {
                historyStore.load(budgetID: budgetID)
            }
        }
        .refreshable {
            if let budgetID = budgetStore.currentBudgetId {
                historyStore.load(budgetID: budgetID)
            }
        }
        .sheet(item: $selectedAction) { action in
            HistoryUndoReviewView(action: action) {
                Task {
                    await historyStore.undo(action, using: budgetStore)
                    if historyStore.errorMessage == nil {
                        selectedAction = nil
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .alert(
            "Couldn't Undo",
            isPresented: Binding(
                get: { historyStore.errorMessage != nil },
                set: { if !$0 { historyStore.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { historyStore.errorMessage = nil }
        } message: {
            Text(historyStore.errorMessage ?? "")
        }
    }
}

private struct HistoryRow: View {
    let action: HistoryAction
    let canUndo: Bool
    let onUndo: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .frame(width: 22)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 3) {
                Text(action.title)
                    .font(.body)
                    .foregroundStyle(action.status == .undone ? .secondary : .primary)
                if !action.detail.isEmpty {
                    Text(action.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 8)

            if let amount = action.amountText {
                Text(amount)
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            if action.status == .undone {
                Text("Undone")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            } else if canUndo {
                Button("Undo", action: onUndo)
                    .font(.callout.weight(.semibold))
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("HistoryRow-\(action.id)")
    }

    private var symbol: String {
        switch action.kind {
        case .created: return "plus.circle"
        case .edited: return "pencil.circle"
        case .deleted: return "trash.circle"
        }
    }
}

private struct HistoryUndoReviewView: View {
    let action: HistoryAction
    let confirm: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(action.title)
                        .font(.headline)
                    if let amount = action.amountText {
                        Text(amount)
                            .font(.title3.monospacedDigit())
                    }
                    if !action.detail.isEmpty {
                        Text(action.detail)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("This will restore") {
                    ForEach(action.before) { snapshot in
                        HistorySnapshotRow(snapshot: snapshot)
                    }
                    if action.before.isEmpty {
                        Text("The transaction(s) created by this action will be removed.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Review Undo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Undo") {
                        confirm()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

private struct HistorySnapshotRow: View {
    let snapshot: HistoryTransactionSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(snapshot.payeeName?.isEmpty == false ? snapshot.payeeName! : "Transaction")
            Text("\(snapshot.amount < 0 ? "−" : "")$\(String(format: "%.2f", Double(abs(snapshot.amount)) / 100.0))")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }
}
'''

history_tests = r'''import Testing
import Foundation

@MainActor
struct HistoryStoreTests {
    @Test func retainsNewest25Actions() {
        let suite = "HistoryStoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = HistoryStore(defaults: defaults)

        for index in 0..<26 {
            store.actionsForTestingAppend(
                HistoryAction(
                    id: "\(index)",
                    createdAt: Date(timeIntervalSince1970: TimeInterval(index)),
                    budgetID: "budget",
                    kind: .created,
                    before: [],
                    after: [],
                    status: .applied
                ),
                budgetID: "budget"
            )
        }

        #expect(store.actions.count == 25)
        #expect(store.actions.first?.id == "25")
        #expect(store.actions.last?.id == "1")
    }

    @Test func actionsPersistAndReload() {
        let suite = "HistoryStoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let first = HistoryStore(defaults: defaults)
        first.actionsForTestingAppend(
            HistoryAction(
                id: "persisted",
                createdAt: Date(),
                budgetID: "budget",
                kind: .edited,
                before: [],
                after: [],
                status: .applied
            ),
            budgetID: "budget"
        )

        let second = HistoryStore(defaults: defaults)
        second.load(budgetID: "budget")
        #expect(second.actions.first?.id == "persisted")
    }
}

private extension HistoryStore {
    func actionsForTestingAppend(_ action: HistoryAction, budgetID: String) {
        actionsForTesting = action
        saveForTesting(budgetID: budgetID)
    }

    var actionsForTesting: HistoryAction {
        get { fatalError() }
        set {
            var current = actions
            current.insert(newValue, at: 0)
            actions = Array(current.prefix(25))
        }
    }

    func saveForTesting(budgetID: String) {
        actionsForTestingSave(budgetID: budgetID)
    }

    func actionsForTestingSave(budgetID: String) {
        // Exercise the public persistence path by recording an equivalent empty action.
        record(budgetID: budgetID, kind: .created, before: [], after: [])
    }
}
'''

# The tests intentionally stay on public behavior; the helper below is removed in
# the final source and replaced with a tiny internal test hook to avoid weakening
# production encapsulation.

settings_old = '''                Section("Manage") {
                    NavigationLink {
                        SchedulesListView()
                    } label: {
                        Label("Scheduled Transactions", systemImage: "calendar.badge.clock")
                    }

                    if budgetStore.currentBudgetId != nil {
                        NavigationLink {
                            RulesListView()
                        } label: {
                            Label("Rules", systemImage: "list.bullet.rectangle")
                        }
                    }

                    NavigationLink {
                        BankSyncSetupView()
                    } label: {
                        Label("Bank Sync (SimpleFIN & Wallet)", systemImage: "building.columns")
                    }
                }'''
settings_new = '''                Section("Manage") {
                    NavigationLink {
                        SchedulesListView()
                    } label: {
                        Label("Scheduled Transactions", systemImage: "calendar.badge.clock")
                    }

                    if budgetStore.currentBudgetId != nil {
                        NavigationLink {
                            RulesListView()
                        } label: {
                            Label("Rules", systemImage: "list.bullet.rectangle")
                        }
                    }

                    NavigationLink {
                        BankSyncSetupView()
                    } label: {
                        Label("Bank Sync (SimpleFIN & Wallet)", systemImage: "building.columns")
                    }

                    NavigationLink {
                        HistoryView()
                    } label: {
                        Label("History", systemImage: "clock.arrow.circlepath")
                    }
                }'''
replace_once("Actuali/Actuali/Views/Settings/SettingsView.swift", settings_old, settings_new)

(root := ROOT / "Actuali/Actuali/Services/HistoryStore.swift").write_text(history_store)
(root.parent / "../Views/HistoryView.swift").resolve().write_text(history_view)
(ROOT / "ActualiTests/Services/History").mkdir(parents=True, exist_ok=True)

# Replace the test body with a small internal hook generated in production below.
root_test = ROOT / "ActualiTests/Services/History/HistoryStoreTests.swift"
root_test.write_text(history_tests)

# Small testing hook: keeps the production mutation path untouched while allowing
# deterministic retention/persistence tests. It is internal, not public API.
replace_once(
    "Actuali/Actuali/Services/HistoryStore.swift",
    "    private func key(for budgetID: String) -> String {",
    '''    #if DEBUG\n    func actionsForTestingAppend(_ action: HistoryAction, budgetID: String) {\n        actions.insert(action, at: 0)\n        actions = Array(actions.prefix(25))\n        save(budgetID: budgetID)\n    }\n    #endif\n\n    private func key(for budgetID: String) -> String {'''
)
# Simplify tests to call the internal DEBUG hook.
root_test.write_text(r'''import Testing
import Foundation

@MainActor
struct HistoryStoreTests {
    @Test func retainsNewest25Actions() {
        let suite = "HistoryStoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = HistoryStore(defaults: defaults)

        for index in 0..<26 {
            store.actionsForTestingAppend(
                HistoryAction(
                    id: "\(index)",
                    createdAt: Date(timeIntervalSince1970: TimeInterval(index)),
                    budgetID: "budget",
                    kind: .created,
                    before: [],
                    after: [],
                    status: .applied
                ),
                budgetID: "budget"
            )
        }

        #expect(store.actions.count == 25)
        #expect(store.actions.first?.id == "25")
        #expect(store.actions.last?.id == "1")
    }

    @Test func actionsPersistAndReload() {
        let suite = "HistoryStoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let first = HistoryStore(defaults: defaults)
        first.actionsForTestingAppend(
            HistoryAction(
                id: "persisted",
                createdAt: Date(),
                budgetID: "budget",
                kind: .edited,
                before: [],
                after: [],
                status: .applied
            ),
            budgetID: "budget"
        )

        let second = HistoryStore(defaults: defaults)
        second.load(budgetID: "budget")
        #expect(second.actions.first?.id == "persisted")
    }
}
''')

# Transaction.SplitPortion is not Codable; fix the stored property to the
# snapshot form and restore it manually in one small substitution.
replace_once(
    "Actuali/Actuali/Services/HistoryStore.swift",
    "    var splitPortions: [Transaction.SplitPortion]?\n",
    "    var splitPortions: [SplitPortionSnapshot]?\n"
)
replace_once(
    "Actuali/Actuali/Services/HistoryStore.swift",
    "        splitPortions = transaction.splitPortions\n",
    "        splitPortions = SplitStorage.encode(transaction.splitPortions)\n"
)
replace_once(
    "Actuali/Actuali/Services/HistoryStore.swift",
    "            splitPortions: splitPortions\n",
    "            splitPortions: splitPortions?.map { $0.value() }\n"
)
replace_once(
    "Actuali/Actuali/Services/HistoryStore.swift",
    "        splitPortions = SplitStorage.decode(stored)\n",
    "        splitPortions = stored\n"
)

# Instrument user-facing mutation points. The action log stays local and does
# not touch the CRDT schema, so sync byte compatibility is preserved.
replace_once(
    "Actuali/Actuali/Services/BudgetStore.swift",
    '''        let changedFields = Self.changedFields(original: original, updated: updated)\n        try await syncClient.updateTransaction(updated, changedFields: changedFields)\n        await refreshDataOnly()''',
    '''        let changedFields = Self.changedFields(original: original, updated: updated)\n        try await syncClient.updateTransaction(updated, changedFields: changedFields)\n        if let budgetID = currentBudgetId {\n            HistoryStore.shared.record(budgetID: budgetID, kind: .edited, before: [original], after: [updated])\n        }\n        await refreshDataOnly()'''
)

replace_once(
    "Actuali/Actuali/Services/BudgetStore.swift",
    '''        do {\n            try await syncClient.updateTransactions(deleted, changedFields: ["tombstone"])\n        } catch {\n            self.error = "Failed to delete transaction: \\(error.localizedDescription)"\n        }\n        await refreshDataOnly()''',
    '''        var didWrite = false\n        do {\n            try await syncClient.updateTransactions(deleted, changedFields: ["tombstone"])\n            didWrite = true\n        } catch {\n            self.error = "Failed to delete transaction: \\(error.localizedDescription)"\n        }\n        if didWrite, let budgetID = currentBudgetId {\n            let ids = Set(deleted.map(\\.id))\n            let before = transactions.filter { ids.contains($0.id) }\n            HistoryStore.shared.record(budgetID: budgetID, kind: .deleted, before: before, after: deleted)\n        }\n        await refreshDataOnly()'''
)

replace_once(
    "Actuali/Actuali/Services/BudgetStore.swift",
    '''                try await createTransaction(transaction)\n                if form.recordLocation, let payeeId {''',
    '''                try await createTransaction(transaction)\n                if let budgetID = currentBudgetId {\n                    HistoryStore.shared.record(budgetID: budgetID, kind: .created, before: [], after: [transaction])\n                }\n                if form.recordLocation, let payeeId {'''
)

replace_once(
    "Actuali/Actuali/Services/BudgetStore.swift",
    '''            try await syncClient.createSplit(parent: parent, children: children)\n            await refreshDataOnly()''',
    '''            try await syncClient.createSplit(parent: parent, children: children)\n            if let budgetID = currentBudgetId {\n                HistoryStore.shared.record(budgetID: budgetID, kind: .created, before: [], after: [parent] + children)\n            }\n            await refreshDataOnly()'''
)

replace_once(
    "Actuali/Actuali/Services/BudgetStore.swift",
    '''        try await syncClient.createTransfer(source: source, target: target)\n        await refreshDataOnly()''',
    '''        try await syncClient.createTransfer(source: source, target: target)\n        if let budgetID = currentBudgetId {\n            HistoryStore.shared.record(budgetID: budgetID, kind: .created, before: [], after: [source, target])\n        }\n        await refreshDataOnly()'''
)

replace_once(
    "Actuali/Actuali/Services/BudgetStore.swift",
    '''        if !targetChanges.isEmpty {\n            try await syncClient.updateTransaction(target, changedFields: targetChanges)\n        }\n        await refreshDataOnly()''',
    '''        if !targetChanges.isEmpty {\n            try await syncClient.updateTransaction(target, changedFields: targetChanges)\n        }\n        if let budgetID = currentBudgetId {\n            HistoryStore.shared.record(\n                budgetID: budgetID,\n                kind: .edited,\n                before: [sourceLeg, targetLeg],\n                after: [source, target]\n            )\n        }\n        await refreshDataOnly()'''
)

# Avoid recursive history rows during an undo. The guard lives at the write
# points rather than in the view, so every future caller gets the same invariant.
# The existing HistoryStore.record() already checks recordingSuppressed.

# Remove the temporary runner on the final commit.
(ROOT / ".github/force_history.py").unlink()
(ROOT / ".github/workflows/force-history.yml").unlink()
''