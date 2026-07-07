import Foundation
import Testing
import UserNotifications
@testable import Actuali

struct NewTransactionNotifierTests {

    private func makeTransaction(id: String, payeeName: String? = nil,
                                 categoryId: String? = nil, amount: Int = -1250) -> Transaction {
        Transaction(id: id, accountId: "acct1", date: 20260707, amount: amount,
                    payeeId: nil, payeeName: payeeName, categoryId: categoryId,
                    categoryName: nil, notes: nil, cleared: false, reconciled: false,
                    transferId: nil, isParent: false, parentId: nil, tombstone: false,
                    sortOrder: nil, importedPayee: nil)
    }

    @Test func noContentForEmptyBatch() {
        #expect(NewTransactionNotifier.makeContent(for: [], currencyCode: "USD") == nil)
    }

    @Test func singleTransactionShowsAmountAndPayee() {
        let content = NewTransactionNotifier.makeContent(
            for: [makeTransaction(id: "t1", payeeName: "Starbucks", categoryId: "food")],
            currencyCode: "USD")

        #expect(content?.title == "New transaction")
        #expect(content?.body.contains("12.50") == true)
        #expect(content?.body.contains("Starbucks") == true)
        #expect(content?.body.localizedCaseInsensitiveContains("category") == false)
    }

    @Test func singleUncategorizedTransactionAsksForCategory() {
        let content = NewTransactionNotifier.makeContent(
            for: [makeTransaction(id: "t1", payeeName: "Starbucks")],
            currencyCode: "USD")

        #expect(content?.body.localizedCaseInsensitiveContains("needs a category") == true)
    }

    @Test func multipleTransactionsSummarizeCountAndUncategorized() {
        let batch = [
            makeTransaction(id: "t1", categoryId: "food"),
            makeTransaction(id: "t2"),
            makeTransaction(id: "t3"),
            makeTransaction(id: "t4"),
            makeTransaction(id: "t5", categoryId: "fuel"),
        ]

        let content = NewTransactionNotifier.makeContent(for: batch, currencyCode: "USD")

        #expect(content?.title == "5 new transactions")
        #expect(content?.body.contains("3 need a category") == true)
        #expect(content?.userInfo[NewTransactionNotifier.transactionIdsKey] as? [String]
                == ["t1", "t2", "t3", "t4", "t5"])
    }

    @Test func multipleAllCategorizedSaysSo() {
        let batch = [
            makeTransaction(id: "t1", categoryId: "food"),
            makeTransaction(id: "t2", categoryId: "fuel"),
        ]

        let content = NewTransactionNotifier.makeContent(for: batch, currencyCode: "USD")

        #expect(content?.title == "2 new transactions")
        #expect(content?.body.localizedCaseInsensitiveContains("categorized") == true)
    }

    @Test func contentCarriesRoutingMetadata() {
        let content = NewTransactionNotifier.makeContent(
            for: [makeTransaction(id: "t1")], currencyCode: "USD")

        #expect(content?.userInfo[NewTransactionNotifier.transactionIdsKey] as? [String] == ["t1"])
        #expect(content?.categoryIdentifier == NewTransactionNotifier.categoryIdentifier)
        #expect(content?.threadIdentifier.isEmpty == false)
    }

    /// A stable request identifier makes a newer summary replace the previous
    /// one instead of stacking up in Notification Center.
    @Test func requestIdentifierIsStableAcrossBatches() {
        let first = NewTransactionNotifier.makeRequest(
            for: [makeTransaction(id: "t1")], currencyCode: "USD")
        let second = NewTransactionNotifier.makeRequest(
            for: [makeTransaction(id: "t2")], currencyCode: "USD")

        #expect(first?.identifier != nil)
        #expect(first?.identifier == second?.identifier)
    }
}
