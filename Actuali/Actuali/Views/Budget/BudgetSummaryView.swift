import SwiftUI

/// Compact budget summary's interactive To Budget / Overbudgeted cell.
struct BudgetBufferCompactSummaryStat: View {
    @EnvironmentObject private var budgetStore: BudgetStore
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale
    @State private var showingSummary = false

    let stat: CompactBudgetOverview.Stat
    var alignment: HorizontalAlignment = .trailing

    private var displayedLabel: String {
        stat.amount < 0
            ? String(localized: "Overbudgeted", locale: locale)
            : String(localized: "To Budget", locale: locale)
    }

    var body: some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(displayedLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                .minimumScaleFactor(dynamicTypeSize.isAccessibilitySize ? 1 : 0.65)
                .allowsTightening(!dynamicTypeSize.isAccessibilitySize)
                .fixedSize(horizontal: false, vertical: dynamicTypeSize.isAccessibilitySize)

            Button {
                showingSummary = true
            } label: {
                Text(budgetStore.displayBudgetCell(stat.amount))
                    .font(.footnote.weight(.semibold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(dynamicTypeSize.isAccessibilitySize ? 1 : 0.35)
                    .allowsTightening(!dynamicTypeSize.isAccessibilitySize)
                    .foregroundStyle(resultColor)
                    .animatedAmount(budgetStore.displayBudgetCell(stat.amount))
            }
            .buttonStyle(.plain)
        }
        .fullScreenCover(isPresented: $showingSummary) {
            if let budget = budgetStore.currentBudgetMonth, budget.toBudget != nil {
                BudgetSummarySheet(month: budget.month)
            }
        }
    }

    private var resultColor: Color {
        switch CompactBalanceTone(amount: stat.amount, isMasked: budgetStore.hideBalances) {
        case .negative: return .red
        case .zero: return .secondary
        case .positive: return .green
        case .masked: return .primary
        }
    }
}
