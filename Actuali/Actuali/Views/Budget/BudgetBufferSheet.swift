import SwiftUI

/// PWA-equivalent editor for an envelope budget's manual next-month buffer.
struct BudgetBufferSheet: View {
    @EnvironmentObject private var budgetStore: BudgetStore
    @Environment(\.dismiss) private var dismiss

    let month: String
    let available: Int
    @State private var amountText: String
    @State private var errorMessage: String?
    @State private var isSaving = false

    init(month: String, available: Int) {
        self.month = month
        self.available = available
        _amountText = State(initialValue: available > 0
            ? String(format: "%.2f", Double(available) / 100.0)
            : "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Amount", text: $amountText)
                        .keyboardType(.decimalPad)
                } header: {
                    Text("Hold this amount")
                } footer: {
                    Text("This amount will be removed from this month's To Budget and available to budget next month.")
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Hold for next month")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Hold") { save() }
                        .disabled(isSaving)
                }
            }
        }
    }

    private func save() {
        guard !isSaving else { return }
        errorMessage = nil
        isSaving = true
        Task {
            do {
                let cents = try BudgetStore.budgetAmountCents(
                    from: amountText.isEmpty ? "0" : amountText
                )
                try await budgetStore.holdBudgetForNextMonth(
                    month: month,
                    amountCents: cents
                )
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                isSaving = false
            }
        }
    }
}

/// Compact budget summary's interactive To Budget cell.
struct BudgetBufferCompactSummaryStat: View {
    @EnvironmentObject private var budgetStore: BudgetStore
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale
    @State private var showingActions = false
    @State private var showingHoldSheet = false

    let stat: CompactBudgetOverview.Stat
    var alignment: HorizontalAlignment = .trailing

    var body: some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(stat.label(locale: locale, bundle: .main))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                .minimumScaleFactor(dynamicTypeSize.isAccessibilitySize ? 1 : 0.65)
                .allowsTightening(!dynamicTypeSize.isAccessibilitySize)
                .fixedSize(horizontal: false, vertical: dynamicTypeSize.isAccessibilitySize)
            Button {
                showingActions = true
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
        .confirmationDialog("To Budget", isPresented: $showingActions, titleVisibility: .visible) {
            if let budget = budgetStore.currentBudgetMonth, budget.buffered > 0 {
                Button("Reset next month's buffer") {
                    Task { try? await budgetStore.resetBudgetBuffer(month: budget.month) }
                }
            } else if let budget = budgetStore.currentBudgetMonth,
                      let toBudget = budget.toBudget,
                      toBudget > 0 {
                Button("Hold for next month") { showingHoldSheet = true }
            }
            Button("Cancel", role: .cancel) { }
        }
        .sheet(isPresented: $showingHoldSheet) {
            if let budget = budgetStore.currentBudgetMonth {
                BudgetBufferSheet(month: budget.month, available: budget.toBudget ?? 0)
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
