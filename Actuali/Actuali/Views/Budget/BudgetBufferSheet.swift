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
        .sheet(isPresented: $showingSummary) {
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

/// PWA-style budget summary for the envelope budget's To Budget / Overbudgeted figure.
struct BudgetSummarySheet: View {
    @EnvironmentObject private var budgetStore: BudgetStore
    @Environment(\.dismiss) private var dismiss
    @State private var summary: BudgetSummaryValues?
    @State private var showingActions = false
    @State private var showingCategorySheet = false
    @State private var showingHoldSheet = false

    let month: String

    private struct BudgetSummaryValues {
        let availableFunds: Int
        let lastMonthOverspent: Int
        let budgeted: Int
        let forNextMonth: Int
        let toBudget: Int
        let manualBuffer: Int
    }

    var body: some View {
        NavigationStack {
            Group {
                if let summary {
                    Form {
                        Section {
                            summaryRow("Available Funds", summary.availableFunds)
                            summaryRow(
                                "Overspent in previous month",
                                summary.lastMonthOverspent,
                                tint: summary.lastMonthOverspent < 0 ? .red : .primary
                            )
                            summaryRow(
                                "Budgeted",
                                -summary.budgeted,
                                tint: summary.budgeted > 0 ? .primary : .secondary
                            )
                            summaryRow(
                                "For next month",
                                -summary.forNextMonth,
                                tint: summary.forNextMonth > 0 ? .primary : .secondary
                            )
                        }

                        Section {
                            Button {
                                showingActions = true
                            } label: {
                                LabeledContent(
                                    summary.toBudget < 0 ? "Overbudgeted" : "To Budget",
                                    value: budgetStore.displayBalance(summary.toBudget)
                                )
                                .foregroundStyle(summary.toBudget < 0 ? .red : .green)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("budgetSummaryResultAction")
                        }
                    }
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Budget Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task(id: month) {
            await loadSummary()
        }
        .confirmationDialog(
            summary.map { $0.toBudget < 0 ? "Overbudgeted" : "To Budget" } ?? "Budget Summary",
            isPresented: $showingActions,
            titleVisibility: .visible
        ) {
            if let summary, summary.toBudget > 0 {
                Button("Move to a category") { showingCategorySheet = true }
                if summary.manualBuffer > 0 {
                    // Preserve the existing Hold feature's reset behavior when
                    // a manual next-month buffer is already present.
                    Button("Reset next month's buffer") {
                        Task { try? await budgetStore.resetBudgetBuffer(month: month) }
                    }
                } else {
                    Button("Hold for next month") { showingHoldSheet = true }
                }
                Button("Cancel", role: .cancel) {}
            } else if summary?.toBudget ?? 0 < 0 {
                Button("Cover from a category") { showingCategorySheet = true }
                Button("Cancel", role: .cancel) {}
            } else {
                Button("Cancel", role: .cancel) {}
            }
        }
        .sheet(isPresented: $showingHoldSheet) {
            if let summary, summary.toBudget > 0 {
                BudgetBufferSheet(month: month, available: summary.toBudget)
            }
        }
        .sheet(isPresented: $showingCategorySheet) {
            if let current = budgetStore.currentBudgetMonth, let toBudget = current.toBudget {
                BudgetToCategorySheet(
                    budget: current,
                    amount: toBudget,
                    isCovering: toBudget < 0
                )
            }
        }
    }

    private func loadSummary() async {
        guard let current = await budgetStore.fetchBudgetMonthSnapshot(month),
              let toBudget = current.toBudget else {
            summary = nil
            return
        }

        let previousMonth = BudgetStore.shiftBudgetMonth(month, by: -1)
        let previous = previousMonth.flatMap { previousMonth in
            // This call is safe because fetchBudgetMonthSnapshot is explicitly
            // non-mutating: it never changes the month currently shown on screen.
            return await budgetStore.fetchBudgetMonthSnapshot(previousMonth)
        }

        let lastMonthOverspent = previous?.categoryBudgets.reduce(0) { total, category in
            category.carryoverEnabled ? total : total + min(0, category.available)
        } ?? 0

        // The current implementation stores manual buffers in BudgetMonth.buffered.
        // For this feature that is the selected "For next month" value.
        let buffered = current.buffered
        let availableFunds = current.totalIncome + (previous?.toBudget ?? 0) + (previous?.buffered ?? 0)

        summary = BudgetSummaryValues(
            availableFunds: availableFunds,
            lastMonthOverspent: lastMonthOverspent,
            budgeted: current.totalBudgeted,
            forNextMonth: buffered,
            toBudget: toBudget,
            manualBuffer: current.buffered
        )
    }

    @ViewBuilder
    private func summaryRow(_ title: String, _ amount: Int, tint: Color = .primary) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(budgetStore.displayBalance(amount))
                .monospacedDigit()
                .foregroundStyle(tint)
        }
    }
}

/// Move positive To Budget into a category, or cover a negative To Budget from
/// a category with available funds.
struct BudgetToCategorySheet: View {
    @EnvironmentObject private var budgetStore: BudgetStore
    @Environment(\.dismiss) private var dismiss

    let budget: BudgetMonth
    let amount: Int
    let isCovering: Bool
    @State private var selectedCategoryId: String
    @State private var amountText: String
    @State private var errorMessage: String?
    @State private var isSaving = false

    init(budget: BudgetMonth, amount: Int, isCovering: Bool) {
        self.budget = budget
        self.amount = abs(amount)
        self.isCovering = isCovering
        let candidates = budget.categoryBudgets.filter { isCovering ? $0.available > 0 : true }
        _selectedCategoryId = State(initialValue: candidates.first?.categoryId ?? "")
        _amountText = State(initialValue: String(format: "%.2f", Double(abs(amount)) / 100.0))
    }

    private var candidates: [CategoryBudget] {
        budget.categoryBudgets.filter { isCovering ? $0.available > 0 : true }
    }

    var body: some View {
        NavigationStack {
            Form {
                if candidates.isEmpty {
                    Section {
                        Text(isCovering
                            ? "There are no categories with available funds to cover this overbudgeted amount."
                            : "There are no categories available to move this money into.")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Section(isCovering ? "Cover from a category" : "Move to a category") {
                        Picker(isCovering ? "From" : "To", selection: $selectedCategoryId) {
                            ForEach(candidates, id: \.categoryId) { category in
                                Text("\(category.categoryName) (\(budgetStore.displayBalance(category.available)))")
                                    .tag(category.categoryId)
                            }
                        }

                        AmountInputField(
                            text: $amountText,
                            conventionalAmountEntry: budgetStore.conventionalAmountEntry,
                            allowsNegative: false,
                            autofocus: true
                        )
                    }

                    if let errorMessage {
                        Section {
                            Text(errorMessage)
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            .navigationTitle(isCovering ? "Cover Overbudgeted" : "Move to Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isCovering ? "Cover" : "Move") { save() }
                        .disabled(isSaving || candidates.isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .interactiveDismissDisabled(isSaving)
    }

    private func save() {
        guard !isSaving else { return }
        errorMessage = nil
        isSaving = true
        Task {
            do {
                let cents = try BudgetStore.budgetAmountCents(from: amountText)
                guard cents > 0 else { throw BudgetStoreError.invalidAmount }
                guard let category = candidates.first(where: { $0.categoryId == selectedCategoryId }) else {
                    throw BudgetStoreError.invalidAmount
                }

                if isCovering {
                    guard cents <= category.available else {
                        throw BudgetStoreError.invalidAmount
                    }
                    try await budgetStore.transferBudget(
                        month: budget.month,
                        fromCategoryId: category.categoryId,
                        toCategoryId: nil,
                        amountCents: cents
                    )
                } else {
                    guard cents <= amount else { throw BudgetStoreError.invalidAmount }
                    try await budgetStore.transferBudget(
                        month: budget.month,
                        fromCategoryId: nil,
                        toCategoryId: category.categoryId,
                        amountCents: cents
                    )
                }
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                isSaving = false
            }
        }
    }
}
