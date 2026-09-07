import Foundation
import Testing

@MainActor
struct HistoryStoreTests {
    private func transaction(id: String, amount: Int = -1000) -> Transaction {
        Transaction(
            id: id,
            accountId: "account",
            date: 20260906,
            amount: amount,
            payeeId: "payee",
            payeeName: "Groceries",
            categoryId: "category",
            categoryName: "Food",
            notes: nil,
            cleared: false,
            reconciled: false,
            transferId: nil,
            isParent: false,
            parentId: nil,
            tombstone: false,
            sortOrder: nil,
            importedPayee: nil
        )
    }

    @Test func retainsNewest10Actions() {
        let suite = "HistoryStoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = HistoryStore(defaults: defaults)

        for index in 0..<11 {
            store.record(
                budgetID: "budget",
                kind: .created,
                before: [],
                after: [transaction(id: "\(index)")]
            )
        }

        #expect(store.actions.count == 10)
        #expect(store.actions.allSatisfy { $0.status == .applied })
        #expect(store.actions.allSatisfy { $0.after.count == 1 })
        #expect(store.actions.contains { $0.after.first?.id == "0" } == false)
        #expect(store.actions.contains { $0.after.first?.id == "10" })
    }

    @Test func actionsPersistAndReload() {
        let suite = "HistoryStoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let first = HistoryStore(defaults: defaults)
        first.record(
            budgetID: "budget",
            kind: .created,
            before: [],
            after: [transaction(id: "persisted")]
        )

        let second = HistoryStore(defaults: defaults)
        second.load(budgetID: "budget")
        #expect(second.actions.count == 1)
        #expect(second.actions.first?.after.first?.id == "persisted")
    }

    @Test func undoneActionsCannotBeUndone() {
        let suite = "HistoryStoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let action = HistoryAction(
            id: "undone",
            createdAt: Date(),
            budgetID: "budget",
            kind: .edited,
            before: [],
            after: [HistoryTransactionSnapshot(transaction(id: "tx"))],
            status: .undone
        )

        let store = HistoryStore(defaults: defaults)
        #expect(store.canUndo(action) == false)
    }

    @Test func liveSnapshotComparisonIgnoresUnstableReadOnlyFields() {
        var recorded = HistoryTransactionSnapshot(transaction(id: "tx"))
        recorded.sortOrder = 123.0
        recorded.financialId = "wallet-id"
        recorded.startingBalanceFlag = true
        recorded.payeeName = "Old Display Name"
        recorded.categoryName = "Old Category Name"

        var fetched = transaction(id: "tx")
        fetched.sortOrder = 456.0
        fetched.financialId = nil
        fetched.startingBalanceFlag = false
        fetched.payeeName = "New Display Name"
        fetched.categoryName = "New Category Name"

        #expect(recorded.matchesLiveTransaction(fetched))
    }

    @Test func transferAndSplitDeletionTitlesAreExplicit() {
        let source = transaction(id: "source")
        let target = transaction(id: "target")

        var transferSource = HistoryTransactionSnapshot(source)
        var transferTarget = HistoryTransactionSnapshot(target)
        transferSource.transferId = target.id
        transferTarget.transferId = source.id
        transferSource.tombstone = true
        transferTarget.tombstone = true
        let deletedTransfer = HistoryAction(
            id: "transfer",
            createdAt: Date(),
            budgetID: "budget",
            kind: .deleted,
            before: [HistoryTransactionSnapshot(source), HistoryTransactionSnapshot(target)],
            after: [transferSource, transferTarget],
            status: .applied
        )
        #expect(deletedTransfer.title == "Deleted transfer")

        var splitParent = HistoryTransactionSnapshot(source)
        splitParent.isParent = true
        splitParent.tombstone = true
        let deletedSplit = HistoryAction(
            id: "split",
            createdAt: Date(),
            budgetID: "budget",
            kind: .deleted,
            before: [HistoryTransactionSnapshot(source)],
            after: [splitParent],
            status: .applied
        )
        #expect(deletedSplit.title == "Deleted split transaction")
    }
}
