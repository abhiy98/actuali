import Foundation

struct EnvelopeBudgetSummary: Equatable, Sendable {
    let availableFunds: Int
    let lastMonthOverspent: Int
    let budgeted: Int
    let forNextMonth: Int
    let toBudget: Int
    let manualBuffered: Int
    let autoBuffered: Int
}

extension BudgetStore {
    /// Reconstructs the envelope summary from the canonical BudgetMonth snapshots.
    /// This keeps the SwiftUI layer from maintaining a second copy of budget math.
    func fetchEnvelopeBudgetSummary(_ month: String) async -> EnvelopeBudgetSummary? {
        guard let database = databaseForLogger,
              let targetMonth = Self.parseBudgetMonth(month) else { return nil }

        var snapshots: [String: BudgetMonth] = [:]
        var cursor = targetMonth
        var foundBaseline = false

        for _ in 0..<120 {
            guard let snapshot = try? await database.fetchBudgetMonth(month: cursor) else { return nil }
            snapshots[cursor] = snapshot

            if Self.isSummaryBaseline(snapshot) {
                foundBaseline = true
                break
            }
            guard let previous = Self.shiftBudgetMonth(cursor, by: -1) else { break }
            cursor = previous
        }

        let calculationMonths = snapshots.keys
            .compactMap(Self.parseBudgetMonth)
            .sorted()
        guard !calculationMonths.isEmpty else { return nil }

        var previousToBudget = 0
        var previousForNextMonth = 0
        var targetSummary: EnvelopeBudgetSummary?

        for components in calculationMonths {
            let currentMonth = Self.formatBudgetMonth(components)
            guard let current = snapshots[currentMonth], let toBudget = current.toBudget else { continue }

            let previousMonth = Self.shiftBudgetMonth(currentMonth, by: -1)
            let previous = previousMonth.flatMap { snapshots[$0] }
            let lastMonthOverspent = previous?.allCategoryBudgets.reduce(0) { total, category in
                category.carryoverEnabled ? total : total + min(0, category.available)
            } ?? 0

            let budgeted = current.allCategoryBudgets.reduce(0) { $0 + $1.budgeted }
            let incomeAvailable = current.totalIncome + previousToBudget + previousForNextMonth
            let forNextMonth = incomeAvailable + lastMonthOverspent - budgeted - toBudget
            let manualBuffered = current.buffered
            let autoBuffered = manualBuffered == 0 ? max(forNextMonth, 0) : 0

            if currentMonth == month {
                targetSummary = EnvelopeBudgetSummary(
                    availableFunds: incomeAvailable,
                    lastMonthOverspent: lastMonthOverspent,
                    budgeted: budgeted,
                    forNextMonth: forNextMonth,
                    toBudget: toBudget,
                    manualBuffered: manualBuffered,
                    autoBuffered: autoBuffered
                )
            }

            previousToBudget = toBudget
            previousForNextMonth = forNextMonth
        }

        guard targetSummary != nil || foundBaseline else { return nil }
        return targetSummary
    }

    private static func parseBudgetMonth(_ month: String) -> DateComponents? {
        let parts = month.split(separator: "-")
        guard parts.count == 2,
              let year = Int(parts[0]),
              let monthNumber = Int(parts[1]),
              (1...12).contains(monthNumber) else { return nil }
        return DateComponents(year: year, month: monthNumber, day: 1)
    }

    private static func formatBudgetMonth(_ components: DateComponents) -> String {
        String(format: "%04d-%02d", components.year ?? 0, components.month ?? 0)
    }

    private static func isSummaryBaseline(_ budget: BudgetMonth) -> Bool {
        budget.toBudget == 0
            && budget.totalIncome == 0
            && budget.allIncomeCategories.allSatisfy { $0.received == 0 }
            && budget.allCategoryBudgets.allSatisfy {
                $0.budgeted == 0 && $0.spent == 0 && $0.available == 0 && $0.carryover == 0
            }
            && budget.buffered == 0
    }
}
