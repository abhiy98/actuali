import Foundation
import Testing
import GRDB
@testable import Actuali

struct BudgetDatabaseEnvelopeBufferTests {
    private func makeDatabase() throws -> (BudgetDatabase, URL) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("buffer-\(UUID().uuidString).sqlite")
        let queue = try DatabaseQueue(path: url.path)
        try queue.write { db in
            try db.execute(sql: """
                CREATE TABLE messages_crdt (
                    id INTEGER PRIMARY KEY,
                    timestamp TEXT NOT NULL UNIQUE,
                    dataset TEXT NOT NULL,
                    row TEXT NOT NULL,
                    column TEXT NOT NULL,
                    value BLOB NOT NULL
                )
                """)
            try db.execute(sql: """
                CREATE TABLE zero_budget_months (
                    id TEXT PRIMARY KEY,
                    buffered INTEGER NOT NULL DEFAULT 0
                )
                """)
        }
        return (try BudgetDatabase(path: url), url)
    }

    private func messages(
        amount: Int,
        millis: Int64
    ) async throws -> [CRDTMessage] {
        let generator = MessageGenerator(clock: HybridLogicalClock(node: "buffer-test-node"))
        return try await generator.messages(
            dataset: "zero_budget_months",
            row: "2026-09",
            fields: [("buffered", amount)]
        )
    }

    private func bufferedValue(path: URL) throws -> Int? {
        let queue = try DatabaseQueue(path: path.path)
        return try queue.read { db in
            try Int.fetchOne(
                db,
                sql: "SELECT buffered FROM zero_budget_months WHERE id = ?",
                arguments: ["2026-09"]
            )
        }
    }

    @Test("Buffer CRDT message creates a missing zero-budget row")
    func createsMissingRow() async throws {
        let (database, path) = try makeDatabase()
        try database.applyMessages(try await messages(amount: 500, millis: 1_700_000_000_000))

        #expect(try bufferedValue(path: path) == 500)
        #expect(try await database.messageTimestamps(
            dataset: "zero_budget_months",
            row: "2026-09"
        ).count == 1)
    }

    @Test("Buffer CRDT message updates an existing zero-budget row")
    func updatesExistingRow() async throws {
        let (database, path) = try makeDatabase()
        try database.applyMessages(try await messages(amount: 500, millis: 1_700_000_000_000))
        try database.applyMessages(try await messages(amount: 250, millis: 1_700_000_000_001))

        #expect(try bufferedValue(path: path) == 250)
    }

    @Test("Reset buffer writes zero to the synced row")
    func resetsExistingRow() async throws {
        let (database, path) = try makeDatabase()
        try database.applyMessages(try await messages(amount: 500, millis: 1_700_000_000_000))
        try database.applyMessages(try await messages(amount: 0, millis: 1_700_000_000_001))

        #expect(try bufferedValue(path: path) == 0)
    }

    @Test("Latest buffer CRDT message wins regardless of application order")
    func latestMessageWinsOutOfOrder() async throws {
        let earlier = try await messages(amount: 500, millis: 1_700_000_000_000)
        let later = try await messages(amount: 250, millis: 1_700_000_000_001)

        let (orderedDatabase, orderedPath) = try makeDatabase()
        try orderedDatabase.applyMessages(earlier + later)

        let (reversedDatabase, reversedPath) = try makeDatabase()
        try reversedDatabase.applyMessages(later + earlier)

        #expect(try bufferedValue(path: orderedPath) == 250)
        #expect(try bufferedValue(path: reversedPath) == 250)
    }
}
