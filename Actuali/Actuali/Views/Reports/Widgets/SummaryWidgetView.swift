import SwiftUI

struct SummaryWidgetView: View {
    @EnvironmentObject private var budgetStore: BudgetStore
    let displayName: String
    let totalCents: Int

    private var formatted: String {
        // Display absolute value; the color communicates direction. Matches the
        // webapp's Summary widget rendering (e.g., "$95,597.58" in red for
        // spending instead of "-$95,597.58").
        budgetStore.formatCurrency(abs(totalCents))
    }

    private var color: Color {
        if totalCents > 0 { return .green }
        if totalCents < 0 { return .red }
        return .primary
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(displayName)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(formatted)
                .font(.system(size: 36, weight: .semibold, design: .rounded))
                .foregroundStyle(color)
                .monospacedDigit()
                .minimumScaleFactor(0.5)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    VStack {
        SummaryWidgetView(displayName: "Spent This Month", totalCents: -316310)
        SummaryWidgetView(displayName: "Saved This Month", totalCents: 1188352)
    }
    .padding()
    .environmentObject(BudgetStore.previewInstance())
}
