import Foundation
import Testing
import UserNotifications
@testable import Actuali

@MainActor
private final class RecordingTransactionLogNotificationCenter: TransactionLogNotificationCenter {
    private(set) var authorizationRequestCount = 0
    private(set) var addedRequests: [UNNotificationRequest] = []

    func requestAuthorization() async throws -> Bool {
        authorizationRequestCount += 1
        return true
    }

    func add(_ request: UNNotificationRequest) async throws {
        addedRequests.append(request)
    }
}

@MainActor
struct TransactionLogNotifierTests {
    /// Locale is pinned: the composers format via the runner's locale by
    /// default, and symbol placement differs by locale (de_DE renders
    /// "12,50 €").
    private let enUS = Locale(identifier: "en_US")

    private func makeSettings(showsSuccessNotification: Bool) -> TransactionLogNotificationSettings {
        let name = "TransactionLogNotifierTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        var settings = TransactionLogNotificationSettings(defaults: defaults)
        settings.showsSuccessNotification = showsSuccessNotification
        return settings
    }

    @Test func disabledShortcutSuccessNotificationSkipsAuthorizationAndDelivery() async {
        let center = RecordingTransactionLogNotificationCenter()

        await TransactionLogNotifier.notifySuccess(
            payee: "Coffee Shop",
            amountCents: -450,
            currencyCode: "USD",
            settings: makeSettings(showsSuccessNotification: false),
            notificationCenter: center
        )

        #expect(center.authorizationRequestCount == 0)
        #expect(center.addedRequests.isEmpty)
    }

    @Test func enabledShortcutSuccessNotificationIsDelivered() async {
        let center = RecordingTransactionLogNotificationCenter()

        await TransactionLogNotifier.notifySuccess(
            payee: "Coffee Shop",
            amountCents: -450,
            currencyCode: "USD",
            settings: makeSettings(showsSuccessNotification: true),
            notificationCenter: center
        )

        #expect(center.authorizationRequestCount == 1)
        #expect(center.addedRequests.count == 1)
    }

    @Test func composeFailureBodyUsesConfiguredCurrencyCode() {
        let bodyEUR = TransactionLogNotifier.composeBody(
            message: "Error message",
            payee: "Starbucks",
            amountCents: 1250,
            currencyCode: "EUR",
            locale: enUS
        )
        #expect(bodyEUR.contains("€12.50 at Starbucks"))

        let bodyGBP = TransactionLogNotifier.composeBody(
            message: "Error message",
            payee: "Tesco",
            amountCents: 500,
            currencyCode: "GBP",
            locale: enUS
        )
        #expect(bodyGBP.contains("£5.00 at Tesco"))
    }

    /// Expenses are negative cents; the failure body must carry that sign too
    /// (composeSuccessBody is covered separately below, GH #258).
    @Test func composeFailureBodyShowsExpenseAsNegative() {
        let body = TransactionLogNotifier.composeBody(
            message: "Error message",
            payee: "Starbucks",
            amountCents: -1250,
            currencyCode: "USD",
            locale: enUS
        )
        #expect(body == "-$12.50 at Starbucks. Error message")
    }

    @Test func composeFailureBodyHonorsNarrowSymbol() {
        let bodyNarrow = TransactionLogNotifier.composeBody(
            message: "Error message",
            payee: "Supermarket",
            amountCents: 2000,
            currencyCode: "NZD",
            narrowSymbol: true,
            locale: enUS
        )
        #expect(bodyNarrow.contains("$20.00 at Supermarket"))
    }

    @Test func composeSuccessBodyUsesConfiguredCurrencyCode() {
        let bodyEUR = TransactionLogNotifier.composeSuccessBody(
            payee: "Starbucks",
            amountCents: 1250,
            currencyCode: "EUR",
            narrowSymbol: false,
            locale: enUS
        )
        #expect(bodyEUR == "€12.50 at Starbucks")

        let bodyGBP = TransactionLogNotifier.composeSuccessBody(
            payee: "Tesco",
            amountCents: 500,
            currencyCode: "GBP",
            narrowSymbol: false,
            locale: enUS
        )
        #expect(bodyGBP == "£5.00 at Tesco")
    }

    /// Expenses are negative cents (Actual's sign convention); the notification
    /// must show that sign so outflows read distinctly from income (GH #258).
    @Test func composeSuccessBodyShowsExpenseAsNegative() {
        let body = TransactionLogNotifier.composeSuccessBody(
            payee: "Starbucks",
            amountCents: -1250,
            currencyCode: "USD",
            narrowSymbol: false,
            locale: enUS
        )
        #expect(body == "-$12.50 at Starbucks")
    }

    @Test func composeSuccessBodyShowsIncomeAsPositive() {
        let body = TransactionLogNotifier.composeSuccessBody(
            payee: "Employer",
            amountCents: 1250,
            currencyCode: "USD",
            narrowSymbol: false,
            locale: enUS
        )
        #expect(body == "$12.50 at Employer")
    }

    /// A write that never reached the server must not read as a plain success —
    /// the transaction exists only on the phone until the next sync (issue #139).
    @Test func composeSuccessBodySaysWhenTheRowIsOnlyLocal() {
        let body = TransactionLogNotifier.composeSuccessBody(
            payee: "Starbucks",
            amountCents: 1250,
            currencyCode: "USD",
            narrowSymbol: false,
            synced: false,
            locale: enUS
        )
        #expect(body.hasPrefix("$12.50 at Starbucks."))
        #expect(body.contains("sync when you open Actuali"))
    }
}
