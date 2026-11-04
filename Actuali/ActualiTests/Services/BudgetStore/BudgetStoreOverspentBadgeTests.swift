import Foundation
import Testing
@testable import Actuali

/// The Budget tab badge count must respect the "Overspent Badge" display
/// setting: the real overspent count when enabled, always 0 when disabled.
@MainActor
struct BudgetStoreOverspentBadgeTests {
    private func makeMonth(availables: [Int]) -> BudgetMonth {
        BudgetMonth(
            month: "2026-07",
            categoryBudgets: availables.enumerated().map { index, available in
                CategoryBudget(
                    month: "2026-07",
                    categoryId: "cat\(index)",
                    categoryName: "Category \(index)",
                    groupId: "g1",
                    groupName: "Everyday",
                    groupSortOrder: 0,
                    categorySortOrder: 0,
                    budgeted: 10000,
                    spent: 10000 - available,
                    available: available,
                    carryover: 0
                )
            }
        )
    }

    @Test func badgeCountsOverspentWhenEnabled() {
        let store = BudgetStore.previewInstance()
        store.showOverspentBadge = true
        store.currentBudgetMonth = makeMonth(availables: [-100, 500, -1])
        #expect(store.overspentBadgeCount == 2)
    }

    @Test func badgeIsZeroWhenDisabled() {
        let store = BudgetStore.previewInstance()
        store.showOverspentBadge = false
        store.currentBudgetMonth = makeMonth(availables: [-100, 500, -1])
        #expect(store.overspentBadgeCount == 0)
    }

    @Test func badgeIsZeroWithoutLoadedMonth() {
        let store = BudgetStore.previewInstance()
        store.showOverspentBadge = true
        store.currentBudgetMonth = nil
        #expect(store.overspentBadgeCount == 0)
    }

    /// The spoken value and the badge read the same count. This keeps the
    /// wiring covered after BudgetTabBadgeUITests was removed: XCUITest cannot
    /// read the tab badge.
    @Test func badgeValueMatchesTheStoreCount() {
        let store = BudgetStore.previewInstance()
        store.showOverspentBadge = true
        store.currentBudgetMonth = makeMonth(availables: [-100, -250])

        #expect(store.overspentBadgeCount == 2)
        #expect(MainTabView.overspentBadgeValue(count: store.overspentBadgeCount)
            == MainTabView.overspentBadgeValue(count: 2))
    }

    @Test func settingDefaultsToOn() {
        UserDefaults.standard.removeObject(forKey: "showOverspentBadge")
        let store = BudgetStore.previewInstance()
        #expect(store.showOverspentBadge)
    }

    @Test func appIconBadgeAddsOnlyEnabledCounts() {
        let store = BudgetStore.previewInstance()
        store.uncategorizedCount = 4
        store.currentBudgetMonth = makeMonth(availables: [-100, -100, -100, -100])
        store.widgetBudgetMonth = makeMonth(availables: [-100, 500, -1])
        store.showOverspentBadge = false
        store.showAppIconBadgeForUncategorizedTransactions = true
        store.showAppIconBadgeForOverspentCategories = true

        #expect(store.appIconBadgeCount == 6)

        // Browsing a historical month must not change the Home Screen badge.
        store.currentBudgetMonth = makeMonth(availables: [-100, -100, -100, -100, -100])
        #expect(store.appIconBadgeCount == 6)

        store.showAppIconBadgeForOverspentCategories = false
        #expect(store.appIconBadgeCount == 4)

        store.showAppIconBadgeForUncategorizedTransactions = false
        store.showAppIconBadgeForOverspentCategories = true
        #expect(store.appIconBadgeCount == 2)

        store.showAppIconBadgeForOverspentCategories = false
        #expect(store.appIconBadgeCount == 0)
    }

    @Test func appIconBadgePreferencesDefaultToOff() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "showAppIconBadgeForUncategorizedTransactions")
        defaults.removeObject(forKey: "showAppIconBadgeForOverspentCategories")

        let store = BudgetStore.previewInstance()
        #expect(!store.showAppIconBadgeForUncategorizedTransactions)
        #expect(!store.showAppIconBadgeForOverspentCategories)
    }

    @Test func appIconBadgePreferencesRestoreFromUserDefaults() {
        let defaults = UserDefaults.standard
        let uncategorizedKey = "showAppIconBadgeForUncategorizedTransactions"
        let overspentKey = "showAppIconBadgeForOverspentCategories"
        let oldUncategorized = defaults.object(forKey: uncategorizedKey)
        let oldOverspent = defaults.object(forKey: overspentKey)
        defer {
            if let oldUncategorized {
                defaults.set(oldUncategorized, forKey: uncategorizedKey)
            } else {
                defaults.removeObject(forKey: uncategorizedKey)
            }
            if let oldOverspent {
                defaults.set(oldOverspent, forKey: overspentKey)
            } else {
                defaults.removeObject(forKey: overspentKey)
            }
        }

        defaults.removeObject(forKey: uncategorizedKey)
        defaults.removeObject(forKey: overspentKey)
        let initial = BudgetStore.previewInstanceLoadingPersistedPreferencesForTesting()
        #expect(!initial.showAppIconBadgeForUncategorizedTransactions)
        #expect(!initial.showAppIconBadgeForOverspentCategories)

        initial.showAppIconBadgeForUncategorizedTransactions = true
        initial.showAppIconBadgeForOverspentCategories = true
        let restored = BudgetStore.previewInstanceLoadingPersistedPreferencesForTesting()
        #expect(restored.showAppIconBadgeForUncategorizedTransactions)
        #expect(restored.showAppIconBadgeForOverspentCategories)
    }
}
