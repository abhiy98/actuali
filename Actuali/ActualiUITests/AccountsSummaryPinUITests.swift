import XCTest

/// The All Accounts summary can stay pinned above the list or scroll with it.
final class AccountsSummaryPinUITests: XCTestCase {
    @MainActor
    private func launchOnAccounts() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-loadDemoData"]
        app.launch()

        app.tabBars.buttons["Accounts"].tap()
        return app
    }

    @MainActor
    private func toggleSummaryPin(in app: XCUIApplication) {
        let options = app.buttons["accounts.optionsMenu"]
        XCTAssertTrue(options.waitForExistence(timeout: 10))
        options.tap()

        let toggle = app.descendants(matching: .any)
            .matching(identifier: "accounts.pinSummary")
            .firstMatch
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        toggle.tap()
    }

    /// Returns whether the summary's frame moves when the list scrolls.
    @MainActor
    private func summaryMovesWhenScrolled(_ summary: XCUIElement, in app: XCUIApplication) -> Bool {
        let restingY = summary.frame.minY
        app.swipeUp()
        return summary.frame.minY < restingY - 1
    }

    @MainActor
    private func setSummaryPinned(_ shouldBePinned: Bool, in app: XCUIApplication) {
        let summary = app.descendants(matching: .any)
            .matching(identifier: "accounts.topBox")
            .firstMatch
        XCTAssertTrue(summary.waitForExistence(timeout: 10))

        let isScrollable = summaryMovesWhenScrolled(summary, in: app)
        app.swipeDown()
        if isScrollable == shouldBePinned {
            toggleSummaryPin(in: app)
        }
    }

    @MainActor
    func testPinnedAndUnpinnedSummaryUseTheSameWidth() {
        let app = launchOnAccounts()
        let summary = app.descendants(matching: .any)
            .matching(identifier: "accounts.topBox")
            .firstMatch
        XCTAssertTrue(summary.waitForExistence(timeout: 10),
                      "the accounts summary should be visible")

        let wasScrollable = summaryMovesWhenScrolled(summary, in: app)
        app.swipeDown()
        if wasScrollable {
            toggleSummaryPin(in: app)
        }
        let pinnedFrame = summary.frame
        XCTAssertGreaterThan(pinnedFrame.width, app.frame.width * 0.8,
                             "the pinned card should use the available list width")

        toggleSummaryPin(in: app)
        let unpinnedFrame = summary.frame
        XCTAssertGreaterThan(unpinnedFrame.width, app.frame.width * 0.8,
                             "the scrollable card should use the available list width")

        XCTAssertEqual(unpinnedFrame.minX, pinnedFrame.minX, accuracy: 1,
                       "unpinning should not change the card's horizontal position")
        XCTAssertEqual(unpinnedFrame.width, pinnedFrame.width, accuracy: 1,
                       "unpinning should not change the card's width")

        defer {
            if !wasScrollable {
                toggleSummaryPin(in: app)
            }
        }

    }

    @MainActor
    func testSummaryStaysPinnedWhileAccountsScroll() {
        let app = launchOnAccounts()
        let summary = app.descendants(matching: .any)
            .matching(identifier: "accounts.topBox")
            .firstMatch
        XCTAssertTrue(summary.waitForExistence(timeout: 10),
                      "the accounts summary should be visible")

        let wasScrollable = summaryMovesWhenScrolled(summary, in: app)
        if wasScrollable {
            app.swipeDown()
            toggleSummaryPin(in: app)
        }
        defer {
            if wasScrollable {
                toggleSummaryPin(in: app)
            }
        }

        let restingY = summary.frame.minY
        app.swipeUp()

        XCTAssertTrue(summary.isHittable,
                      "the pinned summary stays reachable while the list is scrolled")
        XCTAssertEqual(summary.frame.minY, restingY, accuracy: 1,
                       "scrolling the accounts must not move the summary")
    }

    @MainActor
    func testPinToggleIsGroupedWithExpandCollapseOptions() {
        let app = launchOnAccounts()
        app.buttons["accounts.optionsMenu"].tap()

        let expandAll = app.buttons["accounts.expandAll"]
        let collapseAll = app.buttons["accounts.collapseAll"]
        let pinSummary = app.descendants(matching: .any)
            .matching(identifier: "accounts.pinSummary")
            .firstMatch
        XCTAssertTrue(expandAll.waitForExistence(timeout: 5))
        XCTAssertTrue(collapseAll.exists)
        XCTAssertTrue(pinSummary.exists)
        XCTAssertLessThan(expandAll.frame.minY, collapseAll.frame.minY)
        XCTAssertLessThan(collapseAll.frame.minY, pinSummary.frame.minY,
                          "the pin toggle should appear directly with the expand/collapse actions")
    }

    @MainActor
    func testUnpinnedSectionBarsScrollWithAccountsAndRemainCollapsible() {
        let app = launchOnAccounts()
        let summary = app.descendants(matching: .any)
            .matching(identifier: "accounts.topBox")
            .firstMatch
        XCTAssertTrue(summary.waitForExistence(timeout: 10))

        let wasInitiallyScrollable = summaryMovesWhenScrolled(summary, in: app)
        app.swipeDown()
        setSummaryPinned(false, in: app)
        defer { setSummaryPinned(!wasInitiallyScrollable, in: app) }

        let header = app.buttons["account.group.on-budget.disclosure"]
        let chase = app.staticTexts["Chase Checking"].firstMatch
        XCTAssertTrue(header.waitForExistence(timeout: 10))
        if !chase.waitForExistence(timeout: 2) {
            header.tap()
        }
        XCTAssertTrue(chase.waitForExistence(timeout: 10),
                      "the expanded section should show its account rows")

        let restingY = header.frame.minY
        app.swipeUp()
        XCTAssertLessThan(header.frame.minY, restingY - 1,
                          "an unpinned section bar should scroll with its account rows")

        app.swipeDown()
        XCTAssertTrue(header.isHittable,
                      "the section bar should return with the list")
        header.tap()
        XCTAssertTrue(chase.waitForNonExistence(timeout: 10),
                      "the section bar should still collapse its accounts when unpinned")
        header.tap()
        XCTAssertTrue(chase.waitForExistence(timeout: 10),
                      "the unpinned section bar should still expand its accounts")
    }

    @MainActor
    func testSummaryOpensAllAccountsWhenPinnedAndUnpinned() {
        let app = launchOnAccounts()
        let summary = app.descendants(matching: .any)
            .matching(identifier: "accounts.topBox")
            .firstMatch
        XCTAssertTrue(summary.waitForExistence(timeout: 10))

        let wasInitiallyScrollable = summaryMovesWhenScrolled(summary, in: app)
        app.swipeDown()
        defer { setSummaryPinned(!wasInitiallyScrollable, in: app) }

        setSummaryPinned(true, in: app)
        XCTAssertTrue(summary.isHittable)
        summary.tap()
        XCTAssertTrue(app.navigationBars["All Accounts"].waitForExistence(timeout: 10),
                      "tapping the pinned summary should open All Accounts")

        let backButton = app.navigationBars.buttons.firstMatch
        XCTAssertTrue(backButton.waitForExistence(timeout: 10))
        backButton.tap()
        XCTAssertTrue(summary.waitForExistence(timeout: 10))

        setSummaryPinned(false, in: app)
        XCTAssertTrue(summary.isHittable)
        summary.tap()
        XCTAssertTrue(app.navigationBars["All Accounts"].waitForExistence(timeout: 10),
                      "tapping the scrollable summary should also open All Accounts")

        app.navigationBars.buttons.firstMatch.tap()
    }

    @MainActor
    func testSummaryScrollsWithAccountsAndStaysUnpinnedAfterRelaunch() {
        var app = launchOnAccounts()
        let summary = app.descendants(matching: .any)
            .matching(identifier: "accounts.topBox")
            .firstMatch
        XCTAssertTrue(summary.waitForExistence(timeout: 10),
                      "the accounts summary should be visible")

        let wasPinned = !summaryMovesWhenScrolled(summary, in: app)
        app.swipeDown()
        if wasPinned {
            toggleSummaryPin(in: app)
        }
        defer {
            if wasPinned {
                toggleSummaryPin(in: app)
            }
        }

        let restingY = summary.frame.minY
        app.swipeUp()

        XCTAssertLessThan(summary.frame.minY, restingY - 1,
                          "the unpinned summary should scroll with the accounts")

        app.terminate()
        app = launchOnAccounts()

        let relaunchedSummary = app.descendants(matching: .any)
            .matching(identifier: "accounts.topBox")
            .firstMatch
        XCTAssertTrue(relaunchedSummary.waitForExistence(timeout: 10),
                      "the summary should still be visible after relaunch")
        let relaunchedY = relaunchedSummary.frame.minY

        app.swipeUp()

        XCTAssertLessThan(relaunchedSummary.frame.minY, relaunchedY - 1,
                          "the unpinned preference should survive relaunch")
    }
}
