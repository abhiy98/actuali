import SwiftUI

/// The Budget tab's Actuali-mark menu for creating and reordering budget items.
struct BudgetActionsMenu: View {
    var onNewCategory: () -> Void
    var canAddCategory = true
    var onNewGroup: () -> Void
    var onToggleReorder: () -> Void
    var isReordering = false

    var body: some View {
        Menu {
            Section {
                Button(action: onNewCategory) {
                    Label("New Category", systemImage: "tag")
                }
                .disabled(!canAddCategory)

                Button(action: onNewGroup) {
                    Label("New Group", systemImage: "folder")
                }
                .accessibilityLabel("New Category Group")

                Button(action: onToggleReorder) {
                    Label(
                        isReordering ? "Done Reordering" : "Reorder Items",
                        systemImage: isReordering ? "checkmark" : "arrow.up.arrow.down"
                    )
                }
                .accessibilityIdentifier("budgetOptions.reorder")
            }
        } label: {
            Image("ActualiMark")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 23, height: 23)
        }
        .accessibilityLabel("Actuali menu")
        .accessibilityIdentifier("budget.actionsMenu")
    }
}

#Preview {
    NavigationStack {
        Text("Budget")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    BudgetActionsMenu(
                        onNewCategory: {},
                        onNewGroup: {},
                        onToggleReorder: {}
                    )
                }
            }
    }
}
