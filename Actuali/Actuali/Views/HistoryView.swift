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
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 20)
                            .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(action.title)
                                .foregroundStyle(action.status == .undone ? .secondary : .primary)
                                .lineLimit(1)
                            Text(action.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .layoutPriority(1)

                        Spacer(minLength: 6)

                        if let amount = action.amountText {
                            Text(amount)
                                .font(.callout.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }

                        if action.status == .undone {
                            Text("Undone")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        } else if historyStore.canUndo(action) {
                            Button("Undo") { selectedAction = action }
                                .font(.subheadline)
                                .frame(minWidth: 44, alignment: .trailing)
                        }
                    }
                    .frame(height: 48)
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                    .listRowSeparator(.visible)
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("History")
        .task { load() }
        .refreshable { load() }
        .sheet(item: $selectedAction) { action in
            HistoryUndoReviewView(action: action) {
                Task {
                    await historyStore.undo(action, using: budgetStore)
                    if historyStore.errorMessage == nil { selectedAction = nil }
                }
            }
            .presentationDetents([.medium])
        }
        .alert("Couldn't Undo", isPresented: Binding(
            get: { historyStore.errorMessage != nil },
            set: { if !$0 { historyStore.clearError() } }
        )) {
            Button("OK", role: .cancel) { historyStore.clearError() }
        } message: {
            Text(historyStore.errorMessage ?? "")
        }
    }

    private func load() {
        guard let budgetID = budgetStore.currentBudgetId else { return }
        historyStore.load(budgetID: budgetID)
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
    let confirm: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(action.title).font(.headline)
                    if let amount = action.amountText { Text(amount).font(.title3.monospacedDigit()) }
                    Text(action.detail).foregroundStyle(.secondary)
                }
                Section("Restore") {
                    if action.before.isEmpty {
                        Text("The transaction(s) created by this action will be removed.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(action.before) { snapshot in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(snapshot.payeeName?.isEmpty == false ? snapshot.payeeName! : "Transaction")
                                Text("\(snapshot.amount < 0 ? "−" : "")$\(String(format: "%.2f", Double(abs(snapshot.amount))/100.0))")
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
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Undo", action: confirm).fontWeight(.semibold) }
            }
        }
    }
}
