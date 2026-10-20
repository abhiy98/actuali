import SwiftUI

struct CategoryFundingAutomationView: View {
    @EnvironmentObject private var budgetStore: BudgetStore
    @State private var configuration = CategoryFundingAutomationConfiguration()

    /// Every non-income category is a valid configured source. The automation
    /// checks the source balance again for the transaction's own month, so the
    /// settings screen must not depend on the month the Budget tab is viewing.
    private var fundingCategories: [Category] {
        budgetStore.categoryGroups
            .flatMap(\.categories)
            .filter { !$0.isIncome && !$0.hidden }
            .sorted {
                budgetStore.displayCategoryName(id: $0.id, fallback: $0.name)
                    .localizedCaseInsensitiveCompare(
                        budgetStore.displayCategoryName(id: $1.id, fallback: $1.name)
                    ) == .orderedAscending
            }
    }

    var body: some View {
        Form {
            Section {
                Picker(String(localized: "Account"), selection: $configuration.accountId) {
                    Text(String(localized: "None")).tag(String?.none)
                    ForEach(budgetStore.accounts.filter { !$0.closed && !$0.offBudget }, id: \.id) { account in
                        Text(budgetStore.displayAccountName(account)).tag(Optional(account.id))
                    }
                }
                .accessibilityIdentifier("categoryFunding.accountPicker")
            } header: {
                Text(String(localized: "Trigger"))
            }

            Section {
                Toggle(String(localized: "Enable Automation"), isOn: $configuration.isEnabled)
                    .disabled(configuration.accountId == nil)
            } footer: {
                Text(String(localized: "When a new expense is manually entered from the selected account and would overdraw its category, Actuali automatically funds only the amount needed to cover that expense."))
            }

            Section {
                Picker(String(localized: "Funding Source"), selection: $configuration.fundingSource) {
                    Text(String(localized: "To Budget")).tag(CategoryFundingSource.toBudget)

                    ForEach(fundingCategories, id: \.id) { category in
                        Text(budgetStore.displayCategoryName(id: category.id, fallback: category.name))
                            .tag(CategoryFundingSource.category(category.id))
                    }
                }
            } header: {
                Text(String(localized: "Funding"))
            } footer: {
                Text(String(localized: "To Budget is the default. You can also fund the category from another budget category that has available money."))
            }
        }
        .navigationTitle(String(localized: "Category Funding"))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            configuration = CategoryFundingAutomation.loadConfiguration(for: budgetStore.currentBudgetId)
                ?? CategoryFundingAutomationConfiguration()
        }
        .onChange(of: configuration.accountId) { _, accountId in
            if accountId == nil {
                configuration.isEnabled = false
            }
        }
        .onChange(of: configuration) { _, _ in
            save()
        }
    }

    private func save() {
        CategoryFundingAutomation.saveConfiguration(
            configuration,
            for: budgetStore.currentBudgetId
        )
    }
}

#Preview {
    NavigationStack {
        CategoryFundingAutomationView()
            .environmentObject(BudgetStore.previewInstance())
    }
}
