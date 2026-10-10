import SwiftUI

enum BudgetCategoryFilter: String, CaseIterable, Identifiable {
    case all
    case overspent
    case unassigned
    case approachingLimit
    case onTrack

    var id: Self {
        self
    }

    func includes(_ category: CategoryBudget) -> Bool {
        switch self {
        case .all:
            true
        case .overspent:
            category.progressState == .overspent
        case .unassigned:
            category.progressState == .unassigned
        case .approachingLimit:
            category.isApproachingLimit
        case .onTrack:
            category.progressState == .funded || category.progressState == .spending
        }
    }
}

/// The Budget tab's single view-options control (GH #157).
///
/// Layout, expand/collapse and the spent-category visibility toggle used to be three
/// separate controls — two crowding the navigation bar and one stranded in a
/// footer section below the table. The status filters themselves live in the
/// visible check-in strip rather than in here; only whether that strip is
/// shown is a view option.
///
/// The ellipsis menu contains display preferences and optional goal-template actions.
/// Creation and reordering live behind the Actuali-mark menu on the leading side.
struct BudgetOptionsMenu: View {
    @EnvironmentObject private var budgetStore: BudgetStore

    /// Month-level budget actions used to live in a separate toolbar menu.
    var onCopyPreviousMonthBudget: (() -> Void)?
    var onSetBudgetsToZero: (() -> Void)?
    /// Template actions stay visible, but are disabled until goal templates are enabled.
    var onTemplateAction: ((BudgetStore.GoalTemplateAction) -> Void)?
    var onCleanup: (() -> Void)?

    /// Group actions are omitted when no budget is loaded — there are no
    /// groups to act on.
    var expandAllGroups: (() -> Void)?
    var collapseAllGroups: (() -> Void)?

    var body: some View {
        Menu {
            if let onCopyPreviousMonthBudget, let onSetBudgetsToZero {
                Section {
                    Button(action: onCopyPreviousMonthBudget) {
                        Label("Copy last month's budget", systemImage: "doc.on.doc")
                    }
                    .accessibilityIdentifier("budget.copyPreviousMonthBudget")

                    Button(action: onSetBudgetsToZero) {
                        Label("Set budgets to zero", systemImage: "0.circle")
                    }
                }
            }

            Picker("Layout", selection: $budgetStore.budgetDisplayStyle) {
                Label("Clean", systemImage: "list.bullet.rectangle")
                    .tag(BudgetDisplayStyle.clean)
                Label("Compact", systemImage: "list.bullet")
                    .tag(BudgetDisplayStyle.compact)
            }
            .pickerStyle(.inline)

            if let onTemplateAction {
                Section {
                    Button {
                        onTemplateAction(.check)
                    } label: {
                        Label("Check Templates", systemImage: "checkmark.seal")
                    }
                    .disabled(!budgetStore.goalTemplatesEnabled)
                    Button {
                        onTemplateAction(.apply)
                    } label: {
                        Label("Apply Budget Template", systemImage: "wand.and.stars")
                    }
                    .disabled(!budgetStore.goalTemplatesEnabled)
                    Button {
                        onTemplateAction(.overwrite)
                    } label: {
                        Label("Overwrite with Budget Template", systemImage: "wand.and.stars.inverse")
                    }
                    .disabled(!budgetStore.goalTemplatesEnabled)
                    if let onCleanup {
                        Button(action: onCleanup) {
                            Label("End of Month Cleanup", systemImage: "arrow.3.trianglepath")
                        }
                        .disabled(!budgetStore.goalTemplatesEnabled)
                    }
                }
            }

            Section {
                Toggle(isOn: budgetStore.budgetDisplayStyle == .clean
                    ? $budgetStore.showCleanBudgetOverview
                    : $budgetStore.showCompactBudgetOverview) {
                        Label("Show Overview", systemImage: "rectangle.topthird.inset.filled")
                    }
                    .accessibilityIdentifier("budgetOptions.showOverview")
                Toggle(isOn: $budgetStore.showBudgetedAmounts) {
                    Label("Show Budgeted", systemImage: "banknote")
                }
                .accessibilityLabel("Budgeted Amounts")
                .accessibilityIdentifier("budgetOptions.showBudgetedAmounts")
                if budgetStore.budgetDisplayStyle == .compact {
                    Toggle(isOn: $budgetStore.showCompactSpentColumn) {
                        Label("Show Spent", systemImage: "tablecells.badge.ellipsis")
                    }
                    .accessibilityLabel("Show Spent Column")
                }
            }

            if let expandAllGroups, let collapseAllGroups {
                Section {
                    Button(action: expandAllGroups) {
                        Label("Expand Groups", systemImage: "chevron.down")
                    }
                    .accessibilityLabel("Expand All Groups")
                    Button(action: collapseAllGroups) {
                        Label("Collapse Groups", systemImage: "chevron.right")
                    }
                    .accessibilityLabel("Collapse All Groups")
                }
            }

            // Amount masking isn't here: it's app-wide, so it lives in
            // Settings (GH #158) rather than in any one tab's menu.
            Section {
                if budgetStore.budgetDisplayStyle != .clean {
                    Toggle(isOn: $budgetStore.showGroupTotals) {
                        Label("Group Totals", systemImage: "sum")
                    }
                }
                Toggle(isOn: $budgetStore.showBudgetCheckInStrip) {
                    Label("Status Filters", systemImage: "line.3.horizontal.decrease.circle")
                }
                Toggle(isOn: $budgetStore.hideZeroBudgetCategories) {
                    Label("Hide Spent", systemImage: "line.3.horizontal.decrease")
                }
                .accessibilityLabel("Hide Spent Categories")
                Toggle(isOn: $budgetStore.showHiddenCategories) {
                    Label("Hidden Categories", systemImage: "eye")
                }
                .accessibilityLabel("Show Hidden Categories")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .accessibilityLabel("Budget options")
    }
}

#Preview {
    NavigationStack {
        Text("Budget")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    BudgetOptionsMenu(
                        onCopyPreviousMonthBudget: {},
                        onSetBudgetsToZero: {},
                        onTemplateAction: { _ in },
                        onCleanup: {},
                        expandAllGroups: {},
                        collapseAllGroups: {}
                    )
                }
            }
    }
    .environmentObject(BudgetStore.previewInstance())
}
