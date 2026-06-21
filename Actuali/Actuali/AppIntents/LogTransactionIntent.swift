import AppIntents
import Foundation

struct LogTransactionIntent: AppIntent {
    static let title: LocalizedStringResource = "Log Transaction"
    static let description = IntentDescription(
        "Add a transaction to your Actual budget.",
        categoryName: "Transactions"
    )
    static let openAppWhenRun = false

    @Parameter(title: "Account")
    var account: AccountEntity?

    @Parameter(title: "Amount")
    var amount: Double

    @Parameter(title: "Payee")
    var payee: String

    @Parameter(title: "Notes", default: "")
    var notes: String

    @Parameter(title: "Date")
    var date: Date?

    @Parameter(title: "Is Income", default: false)
    var isIncome: Bool

    @Parameter(title: "Cleared", default: true)
    var cleared: Bool

    static var parameterSummary: some ParameterSummary {
        Summary("Log \(\.$amount) at \(\.$payee) in \(\.$account)") {
            \.$notes
            \.$date
            \.$isIncome
            \.$cleared
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        // Validate amount.
        guard amount.isFinite, amount > 0 else {
            await reportFailure(.invalidAmount)
            throw LogTransactionError.invalidAmount
        }

        // Resolve account: explicit parameter, else defaultAccountId, else error.
        let store = BudgetStore.shared
        // Headless launch (openAppWhenRun = false) can reach the write path before
        // init()'s background load has wired syncClient; wait for it so the write
        // doesn't fail with "Sync not configured".
        await store.ensureBudgetReady()
        let resolvedAccountId: String
        if let account {
            resolvedAccountId = account.id
        } else if let defaultId = store.defaultAccountId {
            resolvedAccountId = defaultId
        } else {
            await reportFailure(.noBudgetLoaded)
            throw LogTransactionError.noBudgetLoaded
        }

        // Verify the account still exists and is open. Use accountsForIntent()
        // so this works on a cold headless launch where the in-memory cache is
        // not yet populated.
        let availableAccounts = await store.accountsForIntent()
        guard let activeAccount = availableAccounts.first(where: { $0.id == resolvedAccountId && !$0.closed }) else {
            await reportFailure(.accountUnavailable)
            throw LogTransactionError.accountUnavailable
        }

        // Compute signed cents.
        guard let unsigned = Transaction.cents(fromDollars: amount) else {
            await reportFailure(.invalidAmount)
            throw LogTransactionError.invalidAmount
        }
        let amountCents = isIncome ? unsigned : -unsigned

        // Delegate to logger.
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedDate = date ?? Date()

        do {
            let written = try await TransactionLogger(store: .shared).logTransaction(
                accountId: activeAccount.id,
                amountCents: amountCents,
                rawMerchant: payee,
                notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
                date: resolvedDate,
                cleared: cleared
            )

            let displayPayee = written.payeeName ?? payee
            await TransactionLogNotifier.notifySuccess(
                payee: displayPayee,
                amountCents: amountCents,
                currencyCode: store.currencyCode
            )
            return .result()
        } catch {
            let mapped: LogTransactionError = (error as? LogTransactionError)
                ?? .writeFailed(underlying: error.localizedDescription)
            await reportFailure(mapped)
            throw mapped
        }
    }

    @MainActor
    private func reportFailure(_ error: LogTransactionError) async {
        await TransactionLogNotifier.notifyFailure(
            message: error.errorDescription ?? "Unknown error",
            payee: payee,
            amountCents: Transaction.cents(fromDollars: amount) ?? 0
        )
    }
}
