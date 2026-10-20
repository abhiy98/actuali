import SwiftUI

struct PrivacySettingsView: View {
    @EnvironmentObject private var budgetStore: BudgetStore

    var body: some View {
        Form {
            Section {
                Toggle(String(localized: "Hide Balances"), isOn: $budgetStore.hideBalances)
                Toggle(String(localized: "Shake to Toggle Balances"), isOn: $budgetStore.shakeToHideBalances)
                if budgetStore.hideBalances || budgetStore.shakeToHideBalances || budgetStore.hideNamesWhenBalancesHidden {
                    Toggle(
                        String(localized: "Hide Account & Category Names"),
                        isOn: $budgetStore.hideNamesWhenBalancesHidden
                    )
                    .accessibilityIdentifier("privacy.hideAccountCategoryNames")
                }
                Toggle(String(localized: "Hide Decimal Places"), isOn: $budgetStore.hideDecimalPlaces)
            } header: {
                Text(String(localized: "Balance Visibility"))
            } footer: {
                VStack(alignment: .leading, spacing: 6) {
                    Text(String(localized: "Hide Balances masks amounts across the app while leaving amount entry and reconciliation visible. Shake to Toggle lets you quickly mask or unmask amounts by shaking your phone. Hide Decimal Places rounds displayed amounts to whole units without changing their values."))
                    if budgetStore.hideBalances || budgetStore.shakeToHideBalances || budgetStore.hideNamesWhenBalancesHidden {
                        Text(String(localized: "When enabled, Hide Account & Category Names replaces account, account group, category, and category group names with generic labels while balances are hidden."))
                    }
                }
            }
        }
        .readableWidth()
        .navigationTitle(String(localized: "Privacy"))
        .navigationBarTitleDisplayMode(.inline)
        .contentMargins(.horizontal, 6, for: .scrollContent)
    }
}
