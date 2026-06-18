import Foundation
import Testing
import GRDB
@testable import Actuali

/// Pins the balance semantics of `fetchAccounts()` after the per-account SUM
/// (N+1) was replaced with a single grouped query: every non-tombstoned
/// transaction row for the account counts (split parents/children and
/// transfer legs included), and accounts with no transactions report 0.
@MainActor
struct BudgetDatabaseAccountBalanceTests {

    private func makeDatabase() throws -> (BudgetDatabase, URL) {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-\(UUID().uuidString).sqlite")

        let queue = try DatabaseQueue(path: tempURL.path)
        try queue.write { db in
            try db.execute(sql: """
                CREATE TABLE accounts (
                    id TEXT PRIMARY KEY,
                    name TEXT,
                    type TEXT,
                    offbudget INTEGER DEFAULT 0,
                    closed INTEGER DEFAULT 0,
                    sort_order REAL,
                    tombstone INTEGER DEFAULT 0
                );

                CREATE TABLE transactions (
                    id TEXT PRIMARY KEY,
                    acct TEXT,
                    category TEXT,
                    description TEXT,
                    amount INTEGER,
                    date INTEGER,
                    transferred_id TEXT,
                    sort_order REAL,
                    tombstone INTEGER DEFAULT 0
                );
            """)
        }
        let database = try BudgetDatabase(path: tempURL)
        return (database, tempURL)
    }

    private func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    @Test func balancesSumNonTombstonedTransactionsPerAccount() async throws {
        let (db, url) = try makeDatabase()
        defer { cleanup(url) }

        try await db.dbQueueForTesting.write { conn in
            try conn.execute(sql: """
                INSERT INTO accounts (id, name, sort_order) VALUES
                    ('acct-checking', 'Checking', 1.0),
                    ('acct-savings',  'Savings',  2.0);

                INSERT INTO transactions (id, acct, amount, date, tombstone) VALUES
                    ('t1', 'acct-checking',  100000, 20260501, 0),
                    ('t2', 'acct-checking',   -2550, 20260502, 0),
                    ('t3', 'acct-checking',   -9999, 20260503, 1), -- tombstoned: excluded
                    ('t4', 'acct-savings',     5000, 20260504, 0);

                -- NULL tombstone counts the same as 0
                INSERT INTO transactions (id, acct, amount, date, tombstone) VALUES
                    ('t5', 'acct-savings', 250, 20260505, NULL);
            """)
        }

        let accounts = try await db.fetchAccounts()
        let checking = accounts.first { $0.id == "acct-checking" }
        let savings = accounts.first { $0.id == "acct-savings" }

        #expect(checking?.balance == 97450)
        #expect(savings?.balance == 5250)
    }

    @Test func accountWithNoTransactionsHasZeroBalance() async throws {
        let (db, url) = try makeDatabase()
        defer { cleanup(url) }

        try await db.dbQueueForTesting.write { conn in
            try conn.execute(sql: """
                INSERT INTO accounts (id, name, sort_order) VALUES ('acct-empty', 'Empty', 1.0);
            """)
        }

        let accounts = try await db.fetchAccounts()
        #expect(accounts.count == 1)
        #expect(accounts.first?.balance == 0)
    }

    @Test func transferLegsAndSplitRowsAllCount() async throws {
        // The balance SUM intentionally includes transfer legs and both split
        // parent and child rows — identical to the old per-account query.
        let (db, url) = try makeDatabase()
        defer { cleanup(url) }

        try await db.dbQueueForTesting.write { conn in
            try conn.execute(sql: """
                INSERT INTO accounts (id, name, sort_order) VALUES ('acct-1', 'One', 1.0);

                INSERT INTO transactions (id, acct, amount, date, transferred_id, tombstone) VALUES
                    ('leg',  'acct-1', -3000, 20260501, 't-other', 0),
                    ('main', 'acct-1', 10000, 20260502, NULL, 0);
            """)
        }

        let accounts = try await db.fetchAccounts()
        #expect(accounts.first?.balance == 7000)
    }

    @Test func tombstonedAccountsAreExcluded() async throws {
        let (db, url) = try makeDatabase()
        defer { cleanup(url) }

        try await db.dbQueueForTesting.write { conn in
            try conn.execute(sql: """
                INSERT INTO accounts (id, name, sort_order, tombstone) VALUES
                    ('acct-live', 'Live', 1.0, 0),
                    ('acct-dead', 'Dead', 2.0, 1);
            """)
        }

        let accounts = try await db.fetchAccounts()
        #expect(accounts.map(\.id) == ["acct-live"])
    }
}
