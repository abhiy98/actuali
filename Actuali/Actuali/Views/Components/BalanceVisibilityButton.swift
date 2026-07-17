import SwiftUI

/// A shared navigation-bar control for the app-wide balance privacy setting.
///
/// All three financial tabs read the same `BudgetStore` instance. Keeping the
/// toggle here prevents their icons, labels, or behavior from drifting apart.
struct BalanceVisibilityButton: View {
    @EnvironmentObject private var budgetStore: BudgetStore

    var body: some View {
        Button {
            budgetStore.hideBalances.toggle()
        } label: {
            Image(systemName: budgetStore.hideBalances ? "eye.slash" : "eye")
        }
        .accessibilityLabel(budgetStore.hideBalances ? "Show balances" : "Hide balances")
        .accessibilityHint("Applies to Accounts, Budget, and Reports")
    }
}

#Preview("Balances visible") {
    BalanceVisibilityButton()
        .environmentObject(BudgetStore.previewInstance())
}
