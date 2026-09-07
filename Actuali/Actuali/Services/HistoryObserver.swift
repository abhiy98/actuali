import Combine
import Foundation

@MainActor
final class HistoryObserver {
    private var cancellables = Set<AnyCancellable>()
    private var previousBudgetID: String?
    private var previous: [String: Transaction] = [:]

    init(store: BudgetStore) {
        previousBudgetID = store.currentBudgetId

        store.$currentBudgetId
            .sink { [weak self, weak store] budgetID in
                guard let self, let store else { return }
                if budgetID != self.previousBudgetID {
                    self.previousBudgetID = budgetID
                    self.previous = [:]
                }
                self.consume(store)
            }
            .store(in: &cancellables)

        store.$transactions
            .sink { [weak self, weak store] _ in
                guard let self, let store else { return }
                self.consume(store)
            }
            .store(in: &cancellables)

        consume(store)
    }

    private func consume(_ store: BudgetStore) {
        guard let budgetID = store.currentBudgetId else {
            previous = [:]
            return
        }

        let current = Dictionary(uniqueKeysWithValues: store.transactions.map { ($0.id, $0) })
        guard !previous.isEmpty else {
            previous = current
            previousBudgetID = budgetID
            return
        }

        if let pendingUndo = HistoryStore.pendingUndo {
            previous = current
            if pendingUndo.budgetID == budgetID && Self.matchesPendingUndo(pendingUndo, current: current) {
                HistoryStore.finishUndoRecording()
            }
            return
        }

        if HistoryStore.recordingSuppressed || store.isBankSyncing {
            previous = current
            return
        }

        let added = current.values.filter { previous[$0.id] == nil }
        let removed = previous.values.filter { current[$0.id] == nil }
        let changed = current.values.filter {
            guard let old = previous[$0.id] else { return false }
            return !Self.samePersistedState(old, $0)
        }

        if !added.isEmpty, removed.isEmpty, changed.isEmpty {
            HistoryStore.shared.record(budgetID: budgetID, kind: .created, before: [], after: added)
        } else if added.isEmpty, !removed.isEmpty, changed.isEmpty {
            HistoryStore.shared.record(
                budgetID: budgetID,
                kind: .deleted,
                before: removed,
                after: removed.map { Self.tombstoned($0) }
            )
        } else if added.isEmpty, removed.isEmpty, !changed.isEmpty {
            let before = changed.compactMap { previous[$0.id] }
            HistoryStore.shared.record(budgetID: budgetID, kind: .edited, before: before, after: changed)
        }

        previous = current
        previousBudgetID = budgetID
    }

    private static func matchesPendingUndo(_ pending: HistoryStore.PendingUndo, current: [String: Transaction]) -> Bool {
        let expectedByID = Dictionary(uniqueKeysWithValues: pending.expected.map { ($0.id, $0) })
        for expected in expectedByID.values {
            guard let actual = current[expected.id], HistoryTransactionSnapshot(actual) == expected else { return false }
        }
        return pending.removedIDs.allSatisfy { current[$0] == nil }
    }

    private static func tombstoned(_ transaction: Transaction) -> Transaction {
        var copy = transaction
        copy.tombstone = true
        return copy
    }

    // Payee/category display names, transfer display data, split portions,
    // and sort order are derived or normalized during reads. Comparing only
    // transaction content avoids recording a history row for a plain refresh.
    // ponytail: observing the published snapshot keeps this change small and
    // avoids duplicating every BudgetStore mutation path. Ceiling: mixed
    // topology edits (for example adding/removing split lines) are not logged,
    // and remote transaction changes cannot be perfectly distinguished here.
    private static func samePersistedState(_ lhs: Transaction, _ rhs: Transaction) -> Bool {
        HistoryTransactionSnapshot(lhs).matchesLiveTransaction(rhs)
    }
}
