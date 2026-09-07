import Combine
import Foundation

@MainActor
final class HistoryObserver {
    private var cancellables = Set<AnyCancellable>()
    private var previousBudgetID: String?
    private var previous: [String: Transaction] = [:]
    private var previousSplitChildren: [String: [String: Transaction]] = [:]
    private var consumeTask: Task<Void, Never>?

    init(store: BudgetStore) {
        previousBudgetID = store.currentBudgetId

        store.$currentBudgetId
            .sink { [weak self, weak store] budgetID in
                guard let self, let store else { return }
                if budgetID != self.previousBudgetID {
                    self.previousBudgetID = budgetID
                    self.previous = [:]
                    self.previousSplitChildren = [:]
                    // Wait for the corresponding transaction publication. The
                    // old budget's rows can still be in memory when the budget
                    // ID changes, so consuming here could establish the wrong
                    // baseline and create a phantom History event.
                    return
                }
                self.enqueueConsume(store: store, budgetID: budgetID, transactions: store.transactions)
            }
            .store(in: &cancellables)

        store.$transactions
            .sink { [weak self, weak store] transactions in
                guard let self, let store else { return }
                self.enqueueConsume(store: store, budgetID: store.currentBudgetId, transactions: transactions)
            }
            .store(in: &cancellables)

        enqueueConsume(store: store, budgetID: store.currentBudgetId, transactions: store.transactions)
    }

    private func enqueueConsume(
        store: BudgetStore,
        budgetID: String?,
        transactions: [Transaction]
    ) {
        let previousTask = consumeTask
        consumeTask = Task { @MainActor [weak self, weak store] in
            _ = await previousTask?.result
            guard let self, let store else { return }
            await self.consume(store, budgetID: budgetID, transactions: transactions)
        }
    }

    private func consume(
        _ store: BudgetStore,
        budgetID: String?,
        transactions: [Transaction]
    ) async {
        guard let budgetID else {
            previous = [:]
            previousSplitChildren = [:]
            return
        }

        let current = Dictionary(uniqueKeysWithValues: transactions.map { ($0.id, $0) })
        let currentSplitChildren = await fetchSplitChildren(
            for: current.values.filter(\.isParent),
            using: store
        )

        guard !previous.isEmpty else {
            previous = current
            previousSplitChildren = currentSplitChildren
            previousBudgetID = budgetID
            return
        }

        if let pendingUndo = HistoryStore.pendingUndo {
            previous = current
            previousSplitChildren = currentSplitChildren
            if pendingUndo.budgetID == budgetID,
               Self.matchesPendingUndo(
                    pendingUndo,
                    current: current,
                    splitChildren: currentSplitChildren
               ) {
                HistoryStore.finishUndoRecording()
            }
            return
        }

        if HistoryStore.recordingSuppressed || store.isBankSyncing {
            previous = current
            previousSplitChildren = currentSplitChildren
            return
        }

        let added = current.values.filter { previous[$0.id] == nil }
        let removed = previous.values.filter { current[$0.id] == nil }
        let changed = current.values.filter {
            guard let old = previous[$0.id] else { return false }
            return !Self.samePersistedState(old, $0)
        }

        let previousParentIDs = Set(previous.values.filter(\.isParent).map(\.id))
        let currentParentIDs = Set(current.values.filter(\.isParent).map(\.id))
        let splitParentIDs = previousParentIDs.union(currentParentIDs)

        var handledRootIDs = Set<String>()
        for parentID in splitParentIDs.sorted() {
            let oldRoot = previous[parentID]
            let newRoot = current[parentID]
            let oldParent = oldRoot?.isParent == true ? oldRoot : nil
            let newParent = newRoot?.isParent == true ? newRoot : nil
            let oldChildren = previousSplitChildren[parentID] ?? [:]
            let newChildren = currentSplitChildren[parentID] ?? [:]
            let rootChanged: Bool
            switch (oldRoot, newRoot) {
            case (nil, nil):
                rootChanged = false
            case (let oldRoot?, nil), (nil, let newRoot?):
                rootChanged = oldRoot != newRoot
            case (let oldRoot?, let newRoot?):
                rootChanged = !Self.samePersistedState(oldRoot, newRoot)
            }
            let childrenChanged = !Self.samePersistedState(oldChildren, newChildren)

            // A split parent can be converted from a normal transaction and
            // back again. In either direction the same split action owns the
            // parent row plus all child rows.
            guard rootChanged || childrenChanged else { continue }
            handledRootIDs.insert(parentID)

            switch (oldRoot, newRoot) {
            case (nil, let newRoot?):
                let after = [HistoryTransactionSnapshot(newRoot)]
                    + newChildren.values
                        .sorted { Self.isBefore($0, $1) }
                        .map(HistoryTransactionSnapshot.init)
                HistoryStore.shared.recordSnapshots(
                    budgetID: budgetID,
                    kind: .created,
                    before: [],
                    after: after
                )

            case (let oldRoot?, nil):
                let before = [HistoryTransactionSnapshot(oldRoot)]
                    + oldChildren.values
                        .sorted { Self.isBefore($0, $1) }
                        .map(HistoryTransactionSnapshot.init)
                let after = before.map { snapshot in
                    var tombstoned = snapshot
                    tombstoned.tombstone = true
                    return tombstoned
                }
                HistoryStore.shared.recordSnapshots(
                    budgetID: budgetID,
                    kind: .deleted,
                    before: before,
                    after: after
                )

            case (let oldRoot?, let newRoot?):
                let allChildIDs = oldChildren.keys.union(newChildren.keys).sorted()
                var before = [HistoryTransactionSnapshot(oldRoot)]
                var after = [HistoryTransactionSnapshot(newRoot)]

                for childID in allChildIDs {
                    switch (oldChildren[childID], newChildren[childID]) {
                    case (let oldChild?, let newChild?):
                        before.append(HistoryTransactionSnapshot(oldChild))
                        after.append(HistoryTransactionSnapshot(newChild))
                    case (nil, let newChild?):
                        var absent = HistoryTransactionSnapshot(newChild)
                        absent.tombstone = true
                        before.append(absent)
                        after.append(HistoryTransactionSnapshot(newChild))
                    case (let oldChild?, nil):
                        before.append(HistoryTransactionSnapshot(oldChild))
                        var tombstoned = HistoryTransactionSnapshot(oldChild)
                        tombstoned.tombstone = true
                        after.append(tombstoned)
                    case (nil, nil):
                        break
                    }
                }

                HistoryStore.shared.recordSnapshots(
                    budgetID: budgetID,
                    kind: .edited,
                    before: before,
                    after: after
                )
            }
        }

        let remainingAdded = added.filter { !handledRootIDs.contains($0.id) }
        let remainingRemoved = removed.filter { !handledRootIDs.contains($0.id) }
        let remainingChanged = changed.filter { !handledRootIDs.contains($0.id) }

        if !remainingAdded.isEmpty, remainingRemoved.isEmpty, remainingChanged.isEmpty {
            HistoryStore.shared.record(budgetID: budgetID, kind: .created, before: [], after: remainingAdded)
        } else if remainingAdded.isEmpty, !remainingRemoved.isEmpty, remainingChanged.isEmpty {
            HistoryStore.shared.record(
                budgetID: budgetID,
                kind: .deleted,
                before: remainingRemoved,
                after: remainingRemoved.map { Self.tombstoned($0) }
            )
        } else if remainingAdded.isEmpty, remainingRemoved.isEmpty, !remainingChanged.isEmpty {
            let before = remainingChanged.compactMap { previous[$0.id] }
            HistoryStore.shared.record(budgetID: budgetID, kind: .edited, before: before, after: remainingChanged)
        }

        previous = current
        previousSplitChildren = currentSplitChildren
        previousBudgetID = budgetID
    }

    private func fetchSplitChildren(
        for parents: some Collection<Transaction>,
        using store: BudgetStore
    ) async -> [String: [String: Transaction]] {
        var result: [String: [String: Transaction]] = [:]
        for parent in parents {
            let children = await store.fetchSplitChildren(parentId: parent.id)
            result[parent.id] = Dictionary(uniqueKeysWithValues: children.map { ($0.id, $0) })
        }
        return result
    }

    private static func matchesPendingUndo(
        _ pending: HistoryStore.PendingUndo,
        current: [String: Transaction],
        splitChildren: [String: [String: Transaction]]
    ) -> Bool {
        var live = current
        for children in splitChildren.values {
            for child in children.values {
                live[child.id] = child
            }
        }

        for expected in pending.expected {
            guard let actual = live[expected.id], expected.matchesLiveTransaction(actual) else {
                return false
            }
        }
        return pending.removedIDs.allSatisfy { live[$0] == nil }
    }

    private static func tombstoned(_ transaction: Transaction) -> Transaction {
        var copy = transaction
        copy.tombstone = true
        return copy
    }

    private static func samePersistedState(_ lhs: Transaction, _ rhs: Transaction) -> Bool {
        HistoryTransactionSnapshot(lhs).matchesLiveTransaction(rhs)
    }

    private static func samePersistedState(
        _ lhs: [String: Transaction],
        _ rhs: [String: Transaction]
    ) -> Bool {
        guard lhs.count == rhs.count else { return false }
        for (id, old) in lhs {
            guard let new = rhs[id], samePersistedState(old, new) else { return false }
        }
        return true
    }

    private static func isBefore(_ lhs: Transaction, _ rhs: Transaction) -> Bool {
        let lhsSort = lhs.sortOrder ?? 0
        let rhsSort = rhs.sortOrder ?? 0
        if lhsSort != rhsSort { return lhsSort < rhsSort }
        return lhs.id < rhs.id
    }
}
