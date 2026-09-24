import Testing
@testable import Actuali

struct TransactionCategoryFieldVisibilityTests {
    @Test func onBudgetNonTransferIsEditable() {
        #expect(
            TransactionCategoryFieldState.resolve(
                isTransfer: false,
                openedAccountIsOffBudget: false,
                otherAccountIsOffBudget: false
            ) == .editable
        )
    }

    @Test func offBudgetNonTransferIsLockedOffBudget() {
        #expect(
            TransactionCategoryFieldState.resolve(
                isTransfer: false,
                openedAccountIsOffBudget: true,
                otherAccountIsOffBudget: false
            ) == .lockedOffBudget
        )
    }

    @Test func budgetTransferIsLockedTransfer() {
        #expect(
            TransactionCategoryFieldState.resolve(
                isTransfer: true,
                openedAccountIsOffBudget: false,
                otherAccountIsOffBudget: false
            ) == .lockedTransfer
        )
    }

    @Test func onBudgetLegOfOffBudgetTransferIsEditable() {
        #expect(
            TransactionCategoryFieldState.resolve(
                isTransfer: true,
                openedAccountIsOffBudget: false,
                otherAccountIsOffBudget: true
            ) == .editable
        )
    }

    @Test func offBudgetLegOfTransferIsLockedOffBudget() {
        #expect(
            TransactionCategoryFieldState.resolve(
                isTransfer: true,
                openedAccountIsOffBudget: true,
                otherAccountIsOffBudget: false
            ) == .lockedOffBudget
        )
    }
}
