import AppIntents
import Testing
@testable import Actuali

struct LogTransactionIntentTests {
    @Test func silentByDefaultSoAutomationsDoNotShowADialog() {
        let result = LogTransactionIntent.result(dialogText: "Logged $4.50 at Blue Bottle", showConfirmation: false)
        #expect(result.dialog == nil)
    }

    @Test func speaksWhenTheCallerAsksFor() {
        let result = LogTransactionIntent.result(dialogText: "Logged $4.50 at Blue Bottle", showConfirmation: true)
        #expect(result.dialog != nil)
    }

    private var appBundle: Bundle {
        Bundle(identifier: "com.mfazz.ActualiOS")!
    }

    @Test func siriShortcutOptsIntoTheSpokenConfirmation() {
        #expect(LogTransactionIntent(showConfirmation: true).showConfirmation)
        #expect(LogTransactionIntent().showConfirmation == false)
    }

    @MainActor @Test func replayGuardSuppressesConcurrentAndRecentlyCompletedInvocations() {
        let replayGuard = LogTransactionReplayGuard(duplicateWindow: 3)
        let now = Date(timeIntervalSince1970: 1_000)
        let original = LogTransactionReplayKey(
            accountId: "account-1",
            amountCents: -450,
            rawPayee: "SQ * Blue Bottle #123",
            notes: nil,
            categoryId: nil,
            date: nil,
            isIncome: false,
            cleared: true
        )
        let repeated = LogTransactionReplayKey(
            accountId: "account-1",
            amountCents: -450,
            rawPayee: "Blue Bottle",
            notes: nil,
            categoryId: nil,
            date: nil,
            isIncome: false,
            cleared: true
        )

        #expect(replayGuard.begin(original, now: now))
        #expect(!replayGuard.begin(repeated, now: now.addingTimeInterval(0.5)))
        replayGuard.finish(original, succeeded: true, now: now.addingTimeInterval(1))
        #expect(!replayGuard.begin(repeated, now: now.addingTimeInterval(2)))
        #expect(replayGuard.begin(repeated, now: now.addingTimeInterval(4)))
    }

    @MainActor @Test func replayGuardAllowsRetryAfterFailureAndKeepsDistinctPayments() {
        let replayGuard = LogTransactionReplayGuard()
        let now = Date(timeIntervalSince1970: 1_000)
        let key = LogTransactionReplayKey(
            accountId: "account-1",
            amountCents: -450,
            rawPayee: "Blue Bottle",
            notes: nil,
            categoryId: nil,
            date: nil,
            isIncome: false,
            cleared: true
        )
        let otherAccount = LogTransactionReplayKey(
            accountId: "account-2",
            amountCents: -450,
            rawPayee: "Blue Bottle",
            notes: nil,
            categoryId: nil,
            date: nil,
            isIncome: false,
            cleared: true
        )
        let otherAmount = LogTransactionReplayKey(
            accountId: "account-1",
            amountCents: -550,
            rawPayee: "Blue Bottle",
            notes: nil,
            categoryId: nil,
            date: nil,
            isIncome: false,
            cleared: true
        )

        #expect(replayGuard.begin(key, now: now))
        replayGuard.finish(key, succeeded: false, now: now)
        #expect(replayGuard.begin(key, now: now.addingTimeInterval(0.1)))
        #expect(replayGuard.begin(otherAccount, now: now.addingTimeInterval(0.1)))
        #expect(replayGuard.begin(otherAmount, now: now.addingTimeInterval(0.1)))
    }

    @Test(arguments: [
        (Locale(identifier: "en_US"), "Amount must be greater than 0 (received \"12\").", "Couldn't save transaction. Tap to retry. (disk full)"),
        (Locale(identifier: "fr_FR"), "Le montant doit être supérieur à 0 (valeur reçue : \"12\").", "Impossible d'enregistrer la transaction. Touchez pour réessayer. (disk full)"),
        (Locale(identifier: "pt_BR"), "O valor deve ser maior que 0 (valor recebido: \"12\").", "Não foi possível salvar a transação. Toque para tentar novamente. (disk full)"),
    ])
    func errorsUseRequestedLocaleAndTypedDetails(locale: Locale, invalidAmount: String, writeFailed: String) {
        #expect(LogTransactionError.localizedString(
            for: .invalidAmount(received: " 12 "), locale: locale, bundle: appBundle
        ) == invalidAmount)
        #expect(LogTransactionError.localizedString(
            for: .writeFailed(underlying: "disk full"), locale: locale, bundle: appBundle
        ) == writeFailed)
    }

    @Test func errorDescriptionMatchesTheLocalizedResource() {
        let error = LogTransactionError.invalidAmount(received: "12")
        #expect(error.errorDescription == String(localized: error.localizedStringResource))
    }

    @MainActor @Test func loggerErrorsRemainTypedUntilPresentation() {
        let locale = Locale(identifier: "fr_FR")
        let mapped = LogTransactionError.wrapping(
            TransactionLogger.LoggerError.transactionSuppressedByRule
        )

        guard case .transactionSuppressedByRule = mapped else {
            Issue.record("Expected a typed suppressed-by-rule error")
            return
        }
        #expect(LogTransactionError.localizedString(
            for: mapped, locale: locale, bundle: appBundle
        ) == "Une règle de transaction a ignoré cette transaction.")
        #expect(TransactionLogger.LoggerError.transactionAlreadyExists.message(
            locale: locale, bundle: appBundle
        ) == "Cette transaction a déjà été enregistrée.")
    }

    @Test(arguments: [
        (Locale(identifier: "en_US"), "Account was not found. Select a valid account in your shortcut."),
        (Locale(identifier: "fr_FR"), "Compte introuvable. Sélectionnez un compte valide dans votre raccourci."),
        (Locale(identifier: "pt_BR"), "A conta não foi encontrada. Selecione uma conta válida no atalho."),
    ])
    func balanceErrorsUseRequestedLocale(locale: Locale, value: String) {
        #expect(GetBalanceError.localizedString(for: .accountNotFound, locale: locale, bundle: appBundle) == value)
    }

    @Test(arguments: [
        ("en_US", true, "AMOUNT", "PAYEE", "Logged AMOUNT at PAYEE"),
        ("fr_FR", true, "AMOUNT", "PAYEE", "Transaction de AMOUNT chez PAYEE enregistrée"),
        ("pt_BR", true, "AMOUNT", "PAYEE", "Transação de AMOUNT em PAYEE registrada"),
        ("en_US", false, "AMOUNT", "PAYEE", "Saved locally: AMOUNT at PAYEE"),
        ("fr_FR", false, "AMOUNT", "PAYEE", "Enregistrée localement : AMOUNT chez PAYEE"),
        ("pt_BR", false, "AMOUNT", "PAYEE", "Salva localmente: AMOUNT em PAYEE"),
        ("en_US", true, "AMOUNT", "", "Logged AMOUNT"),
        ("fr_FR", false, "AMOUNT", "", "Enregistrée localement : AMOUNT"),
    ])
    func dialogFormatterPreservesAmountThenPayeePlaceholderOrder(
        localeIdentifier: String, synced: Bool, amount: String, payee: String, expected: String
    ) {
        #expect(LogTransactionDialogFormatter.string(
            amount: amount,
            payee: payee,
            synced: synced,
            locale: Locale(identifier: localeIdentifier),
            bundle: appBundle
        ) == expected)
    }
}
