import Foundation
import Testing
import GRDB
@testable import Actuali

@MainActor
struct BudgetDatabaseRolloverTests {

    private func makeDatabase(envelope: Bool = true) throws -> (BudgetDatabase, URL) {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-\(UUID().uuidString).sqlite")

        let queue = try DatabaseQueue(path: tempURL.path)
        try queue.write { db in
            try db.execute(sql: """
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

                CREATE TABLE categories (
                    id TEXT PRIMARY KEY,
                    name TEXT,
                    is_income INTEGER DEFAULT 0,
                    cat_group TEXT,
                    sort_order REAL,
                    hidden INTEGER DEFAULT 0,
                    tombstone INTEGER DEFAULT 0
                );

                CREATE TABLE category_groups (
                    id TEXT PRIMARY KEY,
                    name TEXT,
                    is_income INTEGER DEFAULT 0,
                    sort_order REAL,
                    hidden INTEGER DEFAULT 0,
                    tombstone INTEGER DEFAULT 0
                );

                INSERT INTO category_groups (id, name) VALUES ('grp-1', 'Daily');
                INSERT INTO categories (id, name, cat_group) VALUES ('cat-groceries', 'Groceries', 'grp-1');
            """)

            let table = envelope ? "zero_budgets" : "reflect_budgets"
            try db.execute(sql: """
                CREATE TABLE \(table) (
                    id TEXT PRIMARY KEY,
                    month INTEGER,
                    category TEXT,
                    amount INTEGER DEFAULT 0,
                    carryover INTEGER DEFAULT 0
                );
            """)
        }
        let database = try BudgetDatabase(path: tempURL)
        return (database, tempURL)
    }

    private func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    private func insertBudget(
        _ db: BudgetDatabase,
        table: String,
        month: Int,
        category: String,
        amount: Int,
        carryover: Bool = false
    ) throws {
        try db.dbQueueForTesting.write { conn in
            try conn.execute(sql: """
                INSERT INTO \(table) (id, month, category, amount, carryover) VALUES (?, ?, ?, ?, ?)
                """, arguments: [UUID().uuidString, month, category, amount, carryover ? 1 : 0])
        }
    }

    private func insertSpend(
        _ db: BudgetDatabase,
        date: Int,
        category: String,
        amount: Int,
        transferId: String? = nil
    ) throws {
        try db.dbQueueForTesting.write { conn in
            try conn.execute(sql: """
                INSERT INTO transactions (id, acct, category, amount, date, transferred_id, tombstone)
                VALUES (?, 'acct-1', ?, ?, ?, ?, 0)
                """, arguments: [UUID().uuidString, category, amount, date, transferId])
        }
    }

    // MARK: - The user's actual scenario

    @Test func unspentBudgetCarriesIntoNextMonth() async throws {
        // April: budgeted 5000, spent 4000 (=$40 of $50). Leftover = 1000.
        // May:   budgeted 5000, spent 0.
        // Expected May available = 5000 (May budget) + 1000 (Apr leftover) = 6000.
        let (db, url) = try makeDatabase(envelope: true)
        defer { cleanup(url) }

        try insertBudget(db, table: "zero_budgets", month: 202604, category: "cat-groceries", amount: 5000)
        try insertSpend(db, date: 20260415, category: "cat-groceries", amount: -4000)
        try insertBudget(db, table: "zero_budgets", month: 202605, category: "cat-groceries", amount: 5000)

        let may = try await db.fetchBudgetMonth(month: "2026-05")
        let groceries = may.categoryBudgets.first { $0.categoryId == "cat-groceries" }
        #expect(groceries?.budgeted == 5000)
        #expect(groceries?.spent == 0)
        #expect(groceries?.carryover == 1000)
        #expect(groceries?.available == 6000)
    }

    @Test func envelopeClampsNegativeLeftoverWhenFlagOff() async throws {
        // April: budgeted 5000, spent 6000 (overspent by 1000). Leftover = -1000.
        // Carryover flag = false on April (default).
        // May:   budgeted 5000, spent 0.
        // Expected: envelope clamps the negative and starts fresh -> May available = 5000.
        let (db, url) = try makeDatabase(envelope: true)
        defer { cleanup(url) }

        try insertBudget(db, table: "zero_budgets", month: 202604, category: "cat-groceries", amount: 5000, carryover: false)
        try insertSpend(db, date: 20260415, category: "cat-groceries", amount: -6000)
        try insertBudget(db, table: "zero_budgets", month: 202605, category: "cat-groceries", amount: 5000)

        let may = try await db.fetchBudgetMonth(month: "2026-05")
        let groceries = may.categoryBudgets.first { $0.categoryId == "cat-groceries" }
        #expect(groceries?.available == 5000)
        #expect(groceries?.carryover == 0)
    }

    @Test func envelopeCarriesNegativeWhenFlagOn() async throws {
        // April: budgeted 5000, spent 6000. Carryover flag ON.
        // May:   budgeted 5000.
        // Expected: full -1000 carries forward -> May available = 4000.
        let (db, url) = try makeDatabase(envelope: true)
        defer { cleanup(url) }

        try insertBudget(db, table: "zero_budgets", month: 202604, category: "cat-groceries", amount: 5000, carryover: true)
        try insertSpend(db, date: 20260415, category: "cat-groceries", amount: -6000)
        try insertBudget(db, table: "zero_budgets", month: 202605, category: "cat-groceries", amount: 5000)

        let may = try await db.fetchBudgetMonth(month: "2026-05")
        let groceries = may.categoryBudgets.first { $0.categoryId == "cat-groceries" }
        #expect(groceries?.available == 4000)
        #expect(groceries?.carryover == -1000)
    }

    @Test func leftoverChainsAcrossMultipleMonths() async throws {
        // Feb: budget 1000, spent 200 -> leftover 800
        // Mar: budget 1000, spent 0    -> leftover 800 + 1000 = 1800
        // Apr: budget 1000, spent 500  -> leftover 1800 + 1000 - 500 = 2300
        let (db, url) = try makeDatabase(envelope: true)
        defer { cleanup(url) }

        try insertBudget(db, table: "zero_budgets", month: 202602, category: "cat-groceries", amount: 1000)
        try insertSpend(db, date: 20260214, category: "cat-groceries", amount: -200)
        try insertBudget(db, table: "zero_budgets", month: 202603, category: "cat-groceries", amount: 1000)
        try insertBudget(db, table: "zero_budgets", month: 202604, category: "cat-groceries", amount: 1000)
        try insertSpend(db, date: 20260415, category: "cat-groceries", amount: -500)

        let apr = try await db.fetchBudgetMonth(month: "2026-04")
        let groceries = apr.categoryBudgets.first { $0.categoryId == "cat-groceries" }
        #expect(groceries?.available == 2300)
        #expect(groceries?.carryover == 1800)
    }

    @Test func leftoverWithNoBudgetRowStillTracksSpending() async throws {
        // Mar: no budget, but spent -500 -> leftover -500, clamps to 0 next month.
        // Apr: no budget, no spend       -> leftover 0.
        // May: budget 2000, spend 0      -> leftover 0 + 2000 = 2000.
        let (db, url) = try makeDatabase(envelope: true)
        defer { cleanup(url) }

        try insertSpend(db, date: 20260314, category: "cat-groceries", amount: -500)
        try insertBudget(db, table: "zero_budgets", month: 202605, category: "cat-groceries", amount: 2000)

        let may = try await db.fetchBudgetMonth(month: "2026-05")
        let groceries = may.categoryBudgets.first { $0.categoryId == "cat-groceries" }
        #expect(groceries?.available == 2000)
        #expect(groceries?.carryover == 0)
    }

    @Test func trackingBudgetDropsLeftoverWhenFlagOff() async throws {
        // April: budget 5000, spent 4000 -> leftover 1000.
        // May:   budget 5000.
        // Tracking semantics: drops prior leftover entirely when flag is off.
        // Expected May available = 5000 (no rollover).
        let (db, url) = try makeDatabase(envelope: false)
        defer { cleanup(url) }

        try insertBudget(db, table: "reflect_budgets", month: 202604, category: "cat-groceries", amount: 5000, carryover: false)
        try insertSpend(db, date: 20260415, category: "cat-groceries", amount: -4000)
        try insertBudget(db, table: "reflect_budgets", month: 202605, category: "cat-groceries", amount: 5000)

        let may = try await db.fetchBudgetMonth(month: "2026-05")
        let groceries = may.categoryBudgets.first { $0.categoryId == "cat-groceries" }
        #expect(groceries?.available == 5000)
        #expect(groceries?.carryover == 0)
    }

    @Test func trackingBudgetCarriesWhenFlagOn() async throws {
        let (db, url) = try makeDatabase(envelope: false)
        defer { cleanup(url) }

        try insertBudget(db, table: "reflect_budgets", month: 202604, category: "cat-groceries", amount: 5000, carryover: true)
        try insertSpend(db, date: 20260415, category: "cat-groceries", amount: -4000)
        try insertBudget(db, table: "reflect_budgets", month: 202605, category: "cat-groceries", amount: 5000)

        let may = try await db.fetchBudgetMonth(month: "2026-05")
        let groceries = may.categoryBudgets.first { $0.categoryId == "cat-groceries" }
        #expect(groceries?.available == 6000)
        #expect(groceries?.carryover == 1000)
    }

    @Test func transferLegsAreNotCounted() async throws {
        // A transfer leg pinned to a category shouldn't inflate "spent".
        let (db, url) = try makeDatabase(envelope: true)
        defer { cleanup(url) }

        try insertBudget(db, table: "zero_budgets", month: 202605, category: "cat-groceries", amount: 5000)
        try insertSpend(db, date: 20260510, category: "cat-groceries", amount: -2000) // real
        try insertSpend(db, date: 20260512, category: "cat-groceries", amount: -1000, transferId: "t-other") // transfer leg, ignored

        let may = try await db.fetchBudgetMonth(month: "2026-05")
        let groceries = may.categoryBudgets.first { $0.categoryId == "cat-groceries" }
        #expect(groceries?.spent == -2000)
        #expect(groceries?.available == 3000)
    }
}
