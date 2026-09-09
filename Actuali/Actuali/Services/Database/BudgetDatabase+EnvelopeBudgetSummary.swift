import Foundation
import GRDB

extension BudgetDatabase {
    struct EnvelopeBudgetSummary: Sendable, Equatable {
        let availableFunds: Int
        let lastMonthOverspent: Int
        let budgeted: Int
        let forNextMonth: Int
        let toBudget: Int
        let manualBuffered: Int
        let autoBuffered: Int
    }

    /// Returns the same envelope-budget summary values used by the budget walk.
    /// The view layer must not reconstruct these financial figures independently.
    func fetchEnvelopeBudgetSummary(month: String) async throws -> EnvelopeBudgetSummary? {
        try await databaseRead { db in
            let parts = month.split(separator: "-")
            guard parts.count == 2,
                  let year = Int(parts[0]),
                  let monthNumber = Int(parts[1]),
                  (1...12).contains(monthNumber) else { return nil }
            let targetMonthInt = year * 100 + monthNumber
            let previousMonthInt: Int = monthNumber == 1
                ? (year - 1) * 100 + 12
                : year * 100 + monthNumber - 1

            let walk = try Self.budgetWalk(db, targetMonthInt: targetMonthInt)
            guard walk.isEnvelope else { return nil }

            let manualBuffered: Int = {
                guard (try? db.tableExists("zero_budget_months")) == true else { return 0 }
                return (try? Int.fetchOne(
                    db,
                    sql: "SELECT buffered FROM zero_budget_months WHERE id = ?",
                    arguments: [month]
                )) ?? 0
            }()

            let targetBudgets = walk.budgetByMonthCat[targetMonthInt] ?? [:]
            let targetSpent = walk.spentByMonthCat[targetMonthInt] ?? [:]
            let previousLeftover = walk.leftoverByMonthCat[previousMonthInt] ?? [:]
            let previousBudgets = walk.budgetByMonthCat[previousMonthInt] ?? [:]

            let budgeted = walk.categories
                .filter { $0.isIncome != 1 }
                .reduce(0) { $0 + (targetBudgets[$1.id]?.amount ?? 0) }

            let lastMonthOverspent = walk.categories
                .filter { $0.isIncome != 1 }
                .reduce(0) { total, category in
                    guard previousBudgets[category.id]?.flag != true else { return total }
                    return total + min(0, previousLeftover[category.id] ?? 0)
                }

            let autoBuffered = walk.incomeCatIds.reduce(0) {
                guard targetBudgets[$1]?.flag == true else { return $0 }
                return $0 + (targetSpent[$1] ?? 0)
            }
            let forNextMonth = manualBuffered != 0 ? manualBuffered : autoBuffered
            let incomeAvailable = walk.toBudget + budgeted + forNextMonth - lastMonthOverspent

            return EnvelopeBudgetSummary(
                availableFunds: incomeAvailable,
                lastMonthOverspent: lastMonthOverspent,
                budgeted: budgeted,
                forNextMonth: forNextMonth,
                toBudget: walk.toBudget,
                manualBuffered: manualBuffered,
                autoBuffered: autoBuffered
            )
        }
    }

    /// Execute a read on this database's serialized GRDB queue.
    /// Kept here so this extension remains independent of BudgetDatabase's private queue.
    private func databaseRead<T>(_ body: @escaping (Database) throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            do {
                continuation.resume(returning: try bodyOnQueue(body))
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private func bodyOnQueue<T>(_ body: (Database) throws -> T) throws -> T {
        fatalError("BudgetDatabase+EnvelopeBudgetSummary requires the database queue accessor")
    }
}
