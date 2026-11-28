import SwiftUI

struct ReconcileView: View {
    @EnvironmentObject private var budgetStore: BudgetStore
    @Environment(\.dismiss) private var dismiss

    let account: Account
    let onReconcile: (Int) -> Void

    @State private var clearedBalance: Int?
    @State private var balanceText = ""
    @State private var isEditingBalance = false
    @State private var loadFailed = false

    private var targetCents: Int? {
        guard let dollars = AmountParser.parse(balanceText) else { return nil }
        return Transaction.cents(fromDollars: dollars)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent(String(localized: "reconcile.clearedBalance")) {
                        if let clearedBalance {
                            Text(budgetStore.formatCurrency(clearedBalance))
                                .fontWeight(.semibold)
                        } else if !loadFailed {
                            ProgressView()
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("reconcile.balancePrompt")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("reconcile.bankBalance")
                            .font(.subheadline.weight(.semibold))
                        AmountInputField(
                            text: $balanceText,
                            conventionalAmountEntry: budgetStore.conventionalAmountEntry,
                            alignment: .right,
                            allowsNegative: true,
                            weight: .semibold,
                            onEditingChanged: { isEditingBalance = $0 }
                        )
                        .accessibilityLabel(Text("reconcile.bankBalance"))
                        .accessibilityIdentifier("reconcile.bankBalanceInput")
                        .frame(minHeight: 44)
                        .padding(.horizontal, 12)
                        .background {
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(
                                    isEditingBalance ? Color.accentColor : Color.secondary,
                                    lineWidth: isEditingBalance ? 2 : 1
                                )
                        }
                    }
                    if loadFailed {
                        Button("Retry") {
                            Task { await loadBalance() }
                        }
                    } else if !balanceText.isEmpty, targetCents == nil {
                        Text("reconcile.invalidAmount")
                            .foregroundStyle(.secondary)
                    }
                }
                Section {
                    Button("Reconcile") {
                        guard let targetCents else { return }
                        onReconcile(targetCents)
                        dismiss()
                    }
                    .disabled(clearedBalance == nil || targetCents == nil)
                    .accessibilityIdentifier("reconcile.submit")
                }
            }
            .navigationTitle("Reconcile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task { await loadBalance() }
        }
    }

    private func loadBalance() async {
        loadFailed = false
        let balance = await budgetStore.clearedBalance(accountId: account.id)
        guard !Task.isCancelled else { return }
        clearedBalance = balance
        loadFailed = balance == nil
        if let balance, balanceText.isEmpty {
            balanceText = AmountInputField.text(
                for: Double(balance) / 100,
                conventionalAmountEntry: budgetStore.conventionalAmountEntry
            )
        }
    }
}

struct ReconciliationBanner: View {
    @EnvironmentObject private var budgetStore: BudgetStore

    let bankBalance: Int
    let clearedBalance: Int?
    let isWorking: Bool
    let onCreateAdjustment: (Int) -> Void
    let onExit: () -> Void
    let onLock: () -> Void

    private var difference: Int? {
        guard let clearedBalance else { return nil }
        let (difference, overflow) = bankBalance.subtractingReportingOverflow(clearedBalance)
        return overflow ? nil : difference
    }

    var body: some View {
        VStack(spacing: 8) {
            if let clearedBalance, let difference {
                if difference == 0 {
                    Label("All reconciled!", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .accessibilityIdentifier("reconcile.matched")
                    Button("Lock Transactions", action: onLock)
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("reconcile.lock")
                } else {
                    let cleared = budgetStore.formatCurrency(clearedBalance)
                    let bank = budgetStore.formatCurrency(bankBalance)
                    let signed = (difference > 0 ? "+" : "") + budgetStore.formatCurrency(difference)
                    Text("Your cleared balance of \(cleared) needs \(signed) to match your bank balance of \(bank).")
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier("reconcile.differenceSummary")
                    ViewThatFits(in: .horizontal) {
                        HStack { unmatchedActions(difference) }
                        VStack { unmatchedActions(difference) }
                    }
                }
            } else {
                Button("Exit Reconciliation", action: onExit)
            }
        }
        .font(.subheadline)
        .disabled(isWorking)
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(.regularMaterial)
    }

    @ViewBuilder
    private func unmatchedActions(_ difference: Int) -> some View {
        Button("Create Reconciliation Transaction") { onCreateAdjustment(difference) }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("reconcile.createAdjustment")
        Button("Exit Reconciliation", action: onExit)
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("reconcile.exit")
    }
}
