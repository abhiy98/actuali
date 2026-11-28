import XCTest

/// End-to-end coverage for the reconciliation button and the tappable
/// cleared-status dot (actios-8oe7): tapping a row's dot toggles cleared
/// without opening the edit sheet, and the account Reconcile flow locks
/// cleared transactions once the bank balance matches.
final class ReconciliationUITests: XCTestCase {
    @MainActor
    private func openChaseChecking() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-loadDemoData", "-resetStatusFilterState"]
        app.launch()

        app.tabBars.buttons["Accounts"].tap()
        let account = app.staticTexts["Chase Checking"].firstMatch
        XCTAssertTrue(account.waitForExistence(timeout: 10))
        account.tap()
        return app
    }

    @MainActor
    func testTappingDotTogglesClearedStatus() {
        let app = openChaseChecking()

        // Demo data leaves the newest transactions pending (uncleared).
        let uncleared = app.buttons.matching(
            NSPredicate(
                format: "identifier BEGINSWITH 'transaction.status.' AND label == 'Uncleared'"
            )
        )
        XCTAssertTrue(uncleared.firstMatch.waitForExistence(timeout: 10),
                      "demo data should include pending transactions")
        let before = uncleared.count

        uncleared.firstMatch.tap()

        // The dot flips in place instead of opening the edit sheet.
        let flipped = NSPredicate(format: "count == \(before - 1)")
        expectation(for: flipped, evaluatedWith: uncleared)
        waitForExpectations(timeout: 10)
        XCTAssertFalse(app.navigationBars["Edit Transaction"].exists,
                       "tapping the dot must not open the edit sheet")
    }

    @MainActor
    func testReconcileLocksClearedTransactions() {
        let app = openChaseChecking()

        // Wait for the pushed detail screen (rows + toolbar) to settle.
        let cleared = app.buttons.matching(
            NSPredicate(
                format: "identifier BEGINSWITH 'transaction.status.' AND label == 'Cleared'"
            )
        )
        XCTAssertTrue(cleared.firstMatch.waitForExistence(timeout: 10),
                      "demo data should include cleared transactions")
        XCTAssertEqual(app.buttons.matching(
            NSPredicate(
                format: "identifier BEGINSWITH 'transaction.status.' AND label == 'Reconciled'"
            )
        ).count, 0, "demo data starts with nothing reconciled")

        openReconciliation(app)
        let lock = app.buttons["reconcile.lock"]
        XCTAssertTrue(lock.waitForExistence(timeout: 10))

        // Change a real ledger row and verify both banner states using the
        // same bank balance. Restoring the row makes Lock available again.
        let dot = cleared.firstMatch
        let transactionStatus = app.buttons[dot.identifier]
        dot.tap()
        XCTAssertTrue(app.buttons["reconcile.createAdjustment"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["reconcile.exit"].exists)
        XCTAssertFalse(lock.exists)
        let uncleared = NSPredicate(format: "label == %@", "Uncleared")
        expectation(for: uncleared, evaluatedWith: transactionStatus)
        waitForExpectations(timeout: 10)
        transactionStatus.tap()

        XCTAssertTrue(lock.waitForExistence(timeout: 10))
        lock.tap()

        // Locking marks every cleared transaction reconciled (blue dot).
        let reconciled = app.buttons.matching(
            NSPredicate(
                format: "identifier BEGINSWITH 'transaction.status.' AND label == 'Reconciled'"
            )
        ).firstMatch
        XCTAssertTrue(reconciled.waitForExistence(timeout: 20),
                      "locking should mark cleared transactions as reconciled")
    }

    @MainActor
    func testLeavingMatchedAccountDoesNotLockTransactions() {
        let app = openChaseChecking()
        openReconciliation(app)
        let lock = app.buttons["reconcile.lock"]
        XCTAssertTrue(lock.waitForExistence(timeout: 10))

        app.navigationBars.buttons["Accounts"].tap()
        let account = app.staticTexts["Chase Checking"].firstMatch
        XCTAssertTrue(account.waitForExistence(timeout: 10))
        account.tap()

        let cleared = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'transaction.status.' AND label == 'Cleared'")
        ).firstMatch
        XCTAssertTrue(cleared.waitForExistence(timeout: 10))
        XCTAssertFalse(lock.exists)
        XCTAssertFalse(app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'transaction.status.' AND label == 'Reconciled'")
        ).firstMatch.exists)
    }

    @MainActor
    func testAddingClearedExpenseMatchesEditedBankBalance() {
        let app = openChaseChecking()
        openReconciliation(app) {
            app.textFields["reconcile.bankBalanceInput"].tap()
            let subtract = app.amountKeypad.buttons["Subtract"]
            XCTAssertTrue(subtract.waitForExistence(timeout: 5))
            subtract.tap()
            for digit in ["2", "0", "0", "0"] {
                app.amountKeypad.buttons[digit].tap()
            }
            app.buttons["Done"].tap()
        }

        let adjustment = app.buttons["reconcile.createAdjustment"]
        let lock = app.buttons["reconcile.lock"]
        XCTAssertTrue(adjustment.waitForExistence(timeout: 10))
        XCTAssertFalse(lock.exists)

        app.navigationBars.buttons["Add Transaction"].tap()
        XCTAssertTrue(app.amountKeypad.waitForExistence(timeout: 10))
        for digit in ["2", "0", "0", "0"] {
            app.amountKeypad.buttons[digit].tap()
        }
        app.buttons["Done"].tap()
        app.buttons["addTransaction.save"].tap()

        XCTAssertTrue(lock.waitForExistence(timeout: 10))
        XCTAssertFalse(adjustment.exists)
    }

    @MainActor
    private func openReconciliation(_ app: XCUIApplication, editBalance: () -> Void = {}) {
        let more = app.navigationBars.buttons["More"]
        XCTAssertTrue(more.waitForExistence(timeout: 10))
        more.tap()
        app.buttons["Reconcile"].tap()

        let submit = app.buttons["reconcile.submit"]
        XCTAssertTrue(submit.waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["All reconciled!"].exists)
        expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: submit)
        waitForExpectations(timeout: 10)
        editBalance()
        submit.tap()
    }

    @MainActor
    func testTappingBalanceRevealsBreakdown() {
        let app = openChaseChecking()

        let balanceToggle = app.buttons["accountBalance.toggle"].firstMatch
        XCTAssertTrue(balanceToggle.waitForExistence(timeout: 10),
                      "On Budget account should expose the balance disclosure")
        let enabled = NSPredicate(format: "isEnabled == true")
        expectation(for: enabled, evaluatedWith: balanceToggle)
        waitForExpectations(timeout: 10)
        XCTAssertTrue(app.staticTexts["Cleared"].exists,
                      "cleared should be visible without expanding the balance")
        XCTAssertTrue(app.staticTexts["Uncleared"].exists,
                      "uncleared should be visible without expanding the balance")
        XCTAssertFalse(app.staticTexts["Reconciled"].exists,
                       "reconciled starts collapsed")

        balanceToggle.tap()

        // GH #134: the split appears in place, without starting reconciliation.
        XCTAssertTrue(app.staticTexts["Reconciled"].waitForExistence(timeout: 10))

        balanceToggle.tap()

        let collapsed = NSPredicate(format: "exists == false")
        expectation(for: collapsed, evaluatedWith: app.staticTexts["Reconciled"])
        waitForExpectations(timeout: 10)
    }
}
