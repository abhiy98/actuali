import Testing
@testable import Actuali

struct TransferCategoryTests {
    @Test func keepsCategoryOnlyOnOnBudgetLegToOffBudgetAccount() {
        #expect(
            BudgetStore.transferCategory(
                categoryId: "category",
                accountIsOffBudget: false,
                otherAccountIsOffBudget: true
            ) == "category"
        )
    }

    @Test func clearsCategoryForBudgetTransfer() {
        #expect(
            BudgetStore.transferCategory(
                categoryId: "category",
                accountIsOffBudget: false,
                otherAccountIsOffBudget: false
            ) == nil
        )
    }

    @Test func clearsCategoryForOffBudgetLeg() {
        #expect(
            BudgetStore.transferCategory(
                categoryId: "category",
                accountIsOffBudget: true,
                otherAccountIsOffBudget: false
            ) == nil
        )
    }
}
