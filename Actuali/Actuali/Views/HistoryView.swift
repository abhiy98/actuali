import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var budgetStore: BudgetStore
    @StateObject private var historyStore = HistoryStore.shared
    @State private var selectedAction: HistoryAction?

    var body: some View {
        List {
            if historyStore.actions.isEmpty {
                ContentUnavailableView(
                    "No History Yet",
                    systemImage: "clock",
                    description: Text("Transactions you add, edit, or delete on this device will appear here.")
                )
            } else {
                ForEach(historyStore.actions) { action in
                    HStack(spacing: 10) {
                        Image(systemName: symbol(for: action.kind))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 20)
                            .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: 1) {
                            HStack(spacing: 6) {
                                Text(action.title)
                                    .font(.caption2)
                                    .foregroundStyle(action.status == .undone ? .secondary : .primary)
                                    .lineLimit(1)
                                    .truncationMode(.tail)

                                if let amount = action.amountText {
                                    Text(amount)
                                        .font(.caption2.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .fixedSize(horizontal: true, vertical: false)
                                }
                            }

                            Text(detail(for: action))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                        .layoutPriority(1)

                        Spacer(minLength: 4)

                        if action.status == .undone {
                            Text("Undone")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                                .accessibilityLabel("Undone")
                        } else if historyStore.canUndo(action) {
                            Button("Undo") { selectedAction = action }
                                .font(.caption2)
                                .frame(minWidth: 44, alignment: .trailing)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                    }
                    .frame(height: 48)
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                    .listRowSeparator(.visible)
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("History")
        .task(id: budgetStore.currentBudgetId) { load() }
        .refreshable { load() }
        .sheet(item: $selectedAction) { action in
            HistoryUndoReviewView(
                action: action,
                detail: detail(for: action)
            ) {
                Task {
                    await historyStore.undo(action, using: budgetStore)
                    if historyStore.errorMessage == nil {
                        selectedAction = nil
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .alert(historyStore.errorTitle, isPresented: Binding(
            get: { historyStore.errorMessage != nil },
            set: { if !$0 { historyStore.clearError() } }
        )) {
            Button("OK", role: .cancel) { historyStore.clearError() }
        } message: {
            Text(historyStore.errorMessage ?? "")
        }
    }

    private func load() {
        guard let budgetID = budgetStore.currentBudgetId else {
            historyStore.clearLoadedActions()
            return
        }
        historyStore.load(budgetID: budgetID)
    }

    private func detail(for action: HistoryAction) -> String {
        guard let snapshot = action.primarySnapshot else { return action.detail }

        let account = budgetStore.accounts.first(where: { $0.id == snapshot.accountId })?.name
        let category = snapshot.categoryName?.isEmpty == false ? snapshot.categoryName : nil
        let hasNotes = snapshot.notes?.isEmpty == false

        if action.kind == .edited,
           let before = action.before.first(where: { $0.id == snapshot.id }) {
            if before.amount != snapshot.amount {
                return "Amount: \(formattedAmount(before.amount)) → \(formattedAmount(snapshot.amount))"
            }
            if before.categoryName != snapshot.categoryName {
                return "Category: \(before.categoryName ?? "Uncategorized") → \(snapshot.categoryName ?? "Uncategorized")"
            }
            if before.payeeName != snapshot.payeeName {
                return "Payee: \(before.payeeName ?? "Transaction") → \(snapshot.payeeName ?? "Transaction")"
            }
            if before.notes != snapshot.notes {
                return before.notes?.isEmpty == false && hasNotes
                    ? "Note changed"
                    : hasNotes ? "Note added" : "Note removed"
            }
            if before.date != snapshot.date {
                return "Date changed"
            }
            if before.cleared != snapshot.cleared {
                return snapshot.cleared ? "Marked cleared" : "Marked uncleared"
            }
            if before.reconciled != snapshot.reconciled {
                return snapshot.reconciled ? "Marked reconciled" : "Marked unreconciled"
            }
        }

        if action.after.count == 2,
           let otherID = action.after.first(where: { $0.id != snapshot.id })?.accountId,
           let otherAccount = budgetStore.accounts.first(where: { $0.id == otherID })?.name {
            return "\(account ?? "Account") → \(otherAccount)"
        }

        if snapshot.isParent, let portions = snapshot.splitPortions, !portions.isEmpty {
            return "\(portions.count) categories · \(account ?? "Account")"
        }

        var parts: [String] = []
        if let category { parts.append(category) }
        if let account { parts.append(account) }
        if hasNotes { parts.append("Note") }
        return parts.isEmpty ? action.detail : parts.joined(separator: " · ")
    }

    private func formattedAmount(_ amount: Int) -> String {
        "\(amount < 0 ? "−" : "")$\(String(format: "%.2f", Double(abs(amount)) / 100.0))"
    }

    private func symbol(for kind: HistoryActionKind) -> String {
        switch kind {
        case .created: return "plus.circle"
        case .edited: return "pencil.circle"
        case .deleted: return "trash.circle"
        }
    }
}

private struct HistoryUndoReviewView: View {
    let action: HistoryAction
    let detail: String
    let confirm: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(action.title).font(.headline)
                    if let amount = action.amountText {
                        Text(amount).font(.title3.monospacedDigit())
                    }
                    Text(detail).foregroundStyle(.secondary)
                }
                Section("Restore") {
                    if action.before.isEmpty {
                        Text("The transaction(s) created by this action will be removed.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(action.before) { snapshot in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(snapshot.payeeName?.isEmpty == false ? snapshot.payeeName! : "Transaction")
                                Text("\(snapshot.amount < 0 ? "−" : "")$\(String(format: "%.2f", Double(abs(snapshot.amount)) / 100.0))")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Review Undo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Undo", action: confirm).fontWeight(.semibold)
                }
            }
        }
    }
}
