import Foundation
import UserNotifications
import os

private let notifLog = Logger(subsystem: "com.mfazz.Actuali", category: "NewTransactionNotifier")

/// Posts one local notification per background-refresh cycle summarizing
/// transactions that arrived via sync (from NewTransactionDetector).
enum NewTransactionNotifier {

    /// Stable so a newer summary replaces the previous one in Notification
    /// Center instead of stacking. Also used as the thread identifier.
    static let requestIdentifier = "com.mfazz.Actuali.newTransactions"

    /// Notification category, used by the tap-through delegate to route to
    /// the transaction editor.
    static let categoryIdentifier = "NEW_TRANSACTIONS"

    /// userInfo key carrying the [String] of new transaction ids.
    static let transactionIdsKey = "transactionIds"

    @MainActor
    static func notify(about transactions: [Transaction], currencyCode: String) async {
        guard let request = makeRequest(for: transactions, currencyCode: currencyCode) else { return }

        let center = UNUserNotificationCenter.current()
        let granted: Bool
        do {
            granted = try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            notifLog.error("Notification authorization failed: \(error.localizedDescription, privacy: .public)")
            return
        }
        guard granted else { return }

        do {
            try await center.add(request)
            notifLog.info("Posted new-transaction notification (\(transactions.count) transactions)")
        } catch {
            notifLog.error("Failed to post new-transaction notification: \(error.localizedDescription, privacy: .public)")
        }
    }

    static func makeRequest(for transactions: [Transaction], currencyCode: String) -> UNNotificationRequest? {
        guard let content = makeContent(for: transactions, currencyCode: currencyCode) else { return nil }
        return UNNotificationRequest(identifier: requestIdentifier, content: content, trigger: nil)
    }

    static func makeContent(for transactions: [Transaction], currencyCode: String) -> UNNotificationContent? {
        guard !transactions.isEmpty else { return nil }

        let content = UNMutableNotificationContent()
        content.threadIdentifier = requestIdentifier
        content.categoryIdentifier = categoryIdentifier
        content.userInfo = [transactionIdsKey: transactions.map(\.id)]
        // No sound — a quiet reminder, matching the Wallet-automation banners.

        if transactions.count == 1, let transaction = transactions.first {
            content.title = "New transaction"
            var body = amountString(cents: transaction.amount, currencyCode: currencyCode)
            if let payee = transaction.payeeName, !payee.isEmpty {
                body += " at \(payee)"
            }
            if transaction.categoryId == nil {
                body += " · Needs a category"
            }
            content.body = body
        } else {
            let uncategorized = transactions.filter { $0.categoryId == nil }.count
            content.title = "\(transactions.count) new transactions"
            content.body = uncategorized == 0
                ? "All categorized"
                : "\(uncategorized) need\(uncategorized == 1 ? "s" : "") a category"
        }

        return content
    }

    private static func amountString(cents: Int, currencyCode: String) -> String {
        let dollars = Double(abs(cents)) / 100.0
        return currencyCode.isEmpty
            ? dollars.formatted(.number.precision(.fractionLength(2)))
            : dollars.formatted(.currency(code: currencyCode))
    }
}
