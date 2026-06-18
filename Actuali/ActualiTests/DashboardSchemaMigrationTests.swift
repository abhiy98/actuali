import Foundation
import Testing
import GRDB
@testable import Actuali

@MainActor
struct DashboardSchemaMigrationTests {

    private func makeDatabasePath() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("test-\(UUID().uuidString).sqlite")
    }

    @Test func createsDashboardTableOnFirstInit() throws {
        let path = makeDatabasePath()
        _ = try BudgetDatabase(path: path)

        let queue = try DatabaseQueue(path: path.path)
        try queue.read { db in
            let dashboardExists = try db.tableExists("dashboard")
            let customReportsExists = try db.tableExists("custom_reports")
            #expect(dashboardExists)
            #expect(customReportsExists)
        }
    }

    @Test func crdtMessageForDashboardLandsInTable() throws {
        let path = makeDatabasePath()
        // messages_crdt normally arrives with the imported budget file zip.
        // Create it explicitly for the test fixture.
        let fixtureQueue = try DatabaseQueue(path: path.path)
        try fixtureQueue.write { db in
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
        }
        let database = try BudgetDatabase(path: path)

        let timestamp = HLCTimestamp(
            millis: 1_700_000_000_000,
            counter: 0,
            node: "test000000000000"
        )
        let messages = [
            CRDTMessage(
                timestamp: timestamp,
                dataset: "dashboard",
                row: "widget-1",
                column: "type",
                value: "S:net-worth-card"
            ),
            CRDTMessage(
                timestamp: timestamp,
                dataset: "dashboard",
                row: "widget-1",
                column: "meta",
                value: "S:{\"name\":\"My Net Worth\"}"
            )
        ]

        _ = try database.insertMessages(messages)
        try database.applyMessages(messages)

        let queue = try DatabaseQueue(path: path.path)
        try queue.read { db in
            let row = try Row.fetchOne(
                db,
                sql: "SELECT type, meta FROM dashboard WHERE id = ?",
                arguments: ["widget-1"]
            )
            #expect(row != nil)
            #expect((row?["type"] as String?) == "net-worth-card")
            #expect((row?["meta"] as String?)?.contains("My Net Worth") == true)
        }
    }

    @Test func migrationIsIdempotent() throws {
        let path = makeDatabasePath()
        _ = try BudgetDatabase(path: path)
        _ = try BudgetDatabase(path: path)
    }

    @Test func createsCustomReportsTable() throws {
        let path = makeDatabasePath()
        _ = try BudgetDatabase(path: path)

        let queue = try DatabaseQueue(path: path.path)
        try queue.read { db in
            let exists = try db.tableExists("custom_reports")
            #expect(exists)
        }
    }
}
