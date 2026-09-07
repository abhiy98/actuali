import Foundation
import Testing

@MainActor
struct HistoryStoreTests {
    @Test func retainsNewest25Actions() {
        let suite = "HistoryStoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = HistoryStore(defaults: defaults)

        for index in 0..<26 {
            store.appendForTesting(
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
        first.appendForTesting(
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
