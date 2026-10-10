import XCTest

/// The Actuali-mark menu handles creation/reordering; the ellipsis holds all month-budget actions.
final class BudgetActionsMenuUITests: XCTestCase {
    @MainActor private func launchBudgetTab(_ app: XCUIApplication) {
        app.launchArguments = ["-loadDemoData", "-budgetDisplayStyle", "clean"]
        app.launch()
        app.tabBars.buttons["Budget"].tap()
    }

    @MainActor
    func testActualiMenuOffersOnlyCreationAndReordering() {
        let app = XCUIApplication()
        launchBudgetTab(app)

        let logoMenu = app.buttons["Actuali menu"]
        XCTAssertTrue(logoMenu.waitForExistence(timeout: 10))
        logoMenu.tap()

        for action in ["New Category", "Reorder Items"] {
            XCTAssertTrue(app.buttons[action].waitForExistence(timeout: 5),
                          "the Actuali menu should offer '\(action)'")
        }
        XCTAssertTrue(app.buttons.matching(
            NSPredicate(format: "label IN %@", ["New Group", "New Category Group"])
        ).firstMatch.waitForExistence(timeout: 5), "the Actuali menu should offer New Group")

        for action in ["Copy last month's budget", "Set budgets to zero", "Check Templates",
                       "Apply Budget Template", "Overwrite with Budget Template", "End of Month Cleanup"] {
            XCTAssertFalse(app.buttons[action].exists,
                           "'\(action)' belongs in the ellipsis menu, not the Actuali menu")
        }
    }

    @MainActor
    func testEllipsisContainsFormerTemplateMenuBudgetActions() {
        let app = XCUIApplication()
        launchBudgetTab(app)

        let optionsMenu = app.buttons["Budget options"]
        XCTAssertTrue(optionsMenu.waitForExistence(timeout: 10))
        optionsMenu.tap()
        XCTAssertTrue(app.buttons["Clean"].waitForExistence(timeout: 5))

        for action in ["Copy last month's budget", "Set budgets to zero"] {
            XCTAssertTrue(app.buttons[action].waitForExistence(timeout: 5),
                          "the ellipsis should keep '\(action)' from the old template menu")
        }
        for action in ["New Category", "Reorder Items"] {
            XCTAssertFalse(app.buttons[action].exists,
                           "'\(action)' belongs in the Actuali-mark menu, not the ellipsis menu")
        }
        for action in ["Check Templates", "Apply Budget Template", "Overwrite with Budget Template", "End of Month Cleanup"] {
            let option = app.buttons[action]
            XCTAssertTrue(option.waitForExistence(timeout: 5),
                          "'\(action)' should remain visible in the ellipsis menu")
            XCTAssertFalse(option.isEnabled,
                           "'\(action)' should be disabled until Budget Goal Templates is enabled")
        }
        XCTAssertFalse(app.buttons.matching(
            NSPredicate(format: "label IN %@", ["New Group", "New Category Group"])
        ).firstMatch.exists)
    }

    @MainActor
    func testEnvelopeBudgetOffersAllTemplateActionsInEllipsis() {
        assertTemplateActions(tracking: false)
    }

    @MainActor
    func testTrackingBudgetOffersTemplatesWithoutCleanup() {
        assertTemplateActions(tracking: true)
    }

    @MainActor private func assertTemplateActions(tracking: Bool) {
        let app = XCUIApplication()
        app.launchArguments = ["-loadDemoData", "-initialTab", "4"]
        if tracking {
            app.launchArguments.append("-loadTrackingDemoData")
        }
        app.launch()

        let budgetSettings = app.buttons["Budget View"]
        XCTAssertTrue(budgetSettings.waitForExistence(timeout: 10))
        budgetSettings.tap()
        let templates = app.switches["Budget Goal Templates"]
        for _ in 0..<5 where !templates.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(templates.isHittable)
        let toggle = templates.switches.firstMatch
        let control = toggle.exists ? toggle : templates
        control.tap()
        let enabled = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", "1"), object: control
        )
        XCTAssertEqual(XCTWaiter.wait(for: [enabled], timeout: 5), .completed)

        app.tabBars.buttons["Budget"].tap()
        let optionsMenu = app.buttons["Budget options"]
        XCTAssertTrue(optionsMenu.waitForExistence(timeout: 10))
        optionsMenu.tap()
        for action in ["Copy last month's budget", "Set budgets to zero", "Check Templates",
                       "Apply Budget Template", "Overwrite with Budget Template"] {
            let option = app.buttons[action]
            XCTAssertTrue(option.waitForExistence(timeout: 5))
            XCTAssertTrue(option.isEnabled, "'\(action)' should be enabled when Goal Templates is on")
        }
        XCTAssertEqual(app.buttons["End of Month Cleanup"].exists, !tracking)
        if !tracking {
            XCTAssertTrue(app.buttons["End of Month Cleanup"].isEnabled)
        }
    }
}
