import Testing
@testable import Actuali

struct BudgetStoreEnvelopeBudgetSummaryTests {
    @Test("Budget months accept only YYYY-MM")
    func budgetMonthValidation() {
        #expect(BudgetStore.isValidBudgetMonth("2026-09"))
        #expect(!BudgetStore.isValidBudgetMonth("2026-9"))
        #expect(!BudgetStore.isValidBudgetMonth("09-2026"))
        #expect(!BudgetStore.isValidBudgetMonth("2026-13"))
    }

    @Test("Empty month is a safe summary baseline")
    func emptyMonthIsBaseline() {
        let budget = BudgetMonth(month: "2026-09", categoryBudgets: [], toBudget: 0)
        #expect(BudgetStore.isSummaryBaseline(budget))
    }

    @Test("A held amount keeps an empty month from being a baseline")
    func bufferedMonthIsNotBaseline() {
        var budget = BudgetMonth(month: "2026-09", categoryBudgets: [], toBudget: 0)
        budget.buffered = 100
        #expect(!BudgetStore.isSummaryBaseline(budget))
    }

    @Test("Income activity prevents a month from being treated as baseline")
    func activeMonthIsNotBaseline() {
        var budget = BudgetMonth(month: "2026-09", categoryBudgets: [], toBudget: 0)
        budget.incomeCategories = [
            IncomeCategory(
                month: "2026-09",
                categoryId: "income",
                categoryName: "Income",
                groupName: "Income",
                sortOrder: 0,
                budgeted: 0,
                received: 100
            )
        ]
        #expect(!BudgetStore.isSummaryBaseline(budget))
    }

    @Test("January and December month shifts cross the year")
    func yearBoundaryShift() {
        #expect(BudgetStore.shiftBudgetMonth("2026-01", by: -1) == "2025-12")
        #expect(BudgetStore.shiftBudgetMonth("2026-12", by: 1) == "2027-01")
    }
}
