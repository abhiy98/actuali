import Foundation
import Testing
@testable import Actuali

@MainActor
struct BudgetStorePrivacyNameTests {
    @Test func displayNamesAreMaskedAndRestoredWithBalanceVisibility() {
        let originalNamesPreference = UserDefaults.standard.object(forKey: "hideNamesWhenBalancesHidden")
        let originalBalancesPreference = UserDefaults.standard.object(forKey: "hideBalances")
        defer {
            if let originalNamesPreference {
                UserDefaults.standard.set(originalNamesPreference, forKey: "hideNamesWhenBalancesHidden")
            } else {
                UserDefaults.standard.removeObject(forKey: "hideNamesWhenBalancesHidden")
            }
            if let originalBalancesPreference {
                UserDefaults.standard.set(originalBalancesPreference, forKey: "hideBalances")
            } else {
                UserDefaults.standard.removeObject(forKey: "hideBalances")
            }
        }

        let store = BudgetStore.previewInstance()
        store.accounts = [
            Account(id: "checking", name: "Checking", type: .checking,
                    offBudget: false, closed: false, sortOrder: 0, balance: 0),
            Account(id: "savings", name: "Savings", type: .savings,
                    offBudget: false, closed: false, sortOrder: 1, balance: 0),
        ]
        store.accountGroups = [AccountGroup(id: "cash", name: "Cash", sortOrder: 0)]
        store.categoryGroups = [
            CategoryGroup(
                id: "essentials", name: "Essentials", isIncome: false, hidden: false,
                sortOrder: 0,
                categories: [
                    Category(id: "rent", name: "Rent", groupId: "essentials",
                             isIncome: false, hidden: false, sortOrder: 0),
                    Category(id: "groceries", name: "Groceries", groupId: "essentials",
                             isIncome: false, hidden: false, sortOrder: 1),
                ]
            ),
        ]
        store.hideNamesWhenBalancesHidden = true
        store.hideBalances = true

        #expect(store.displayAccountName(store.accounts[0]) == "Account 1")
        #expect(store.displayAccountGroupName(id: "cash", fallback: "Cash") == "Account Group 1")
        #expect(store.displayCategoryName(id: "rent", fallback: "Rent") == "Category 1")
        #expect(store.displayCategoryName(id: "groceries", fallback: "Groceries") == "Category 2")
        #expect(store.displayCategoryGroupName(id: "essentials", fallback: "Essentials") == "Category Group 1")

        store.hideBalances = false

        #expect(store.displayAccountName(store.accounts[0]) == "Checking")
        #expect(store.displayAccountGroupName(id: "cash", fallback: "Cash") == "Cash")
        #expect(store.displayCategoryName(id: "rent", fallback: "Rent") == "Rent")
        #expect(store.displayCategoryGroupName(id: "essentials", fallback: "Essentials") == "Essentials")
    }

    @Test func namesAreMaskedOnlyWhileBalancesAreHidden() {
        let originalNamesPreference = UserDefaults.standard.object(forKey: "hideNamesWhenBalancesHidden")
        let originalBalancesPreference = UserDefaults.standard.object(forKey: "hideBalances")
        defer {
            if let originalNamesPreference {
                UserDefaults.standard.set(originalNamesPreference, forKey: "hideNamesWhenBalancesHidden")
            } else {
                UserDefaults.standard.removeObject(forKey: "hideNamesWhenBalancesHidden")
            }
            if let originalBalancesPreference {
                UserDefaults.standard.set(originalBalancesPreference, forKey: "hideBalances")
            } else {
                UserDefaults.standard.removeObject(forKey: "hideBalances")
            }
        }
        let store = BudgetStore.previewInstance()
        store.hideBalances = false
        store.hideNamesWhenBalancesHidden = false

        store.hideNamesWhenBalancesHidden = true
        #expect(!store.shouldHideNamesWithBalances)

        store.hideBalances = true
        #expect(store.shouldHideNamesWithBalances)

        store.hideBalances = false
        #expect(!store.shouldHideNamesWithBalances)

        store.hideNamesWhenBalancesHidden = false
        #expect(!store.shouldHideNamesWithBalances)
    }
}
