import XCTest

final class OnboardingUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    @MainActor
    func testGuestOnboardingRequiresBothConsentsThenOpensMyNuri() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestFreshState"]
        app.launch()

        app.buttons["Use without an account"].tap()

        let proceed = app.buttons["consent.continue"]
        XCTAssertTrue(proceed.waitForExistence(timeout: 5))
        XCTAssertFalse(proceed.isEnabled)

        flip(app.switches["consent.adult"])
        XCTAssertFalse(proceed.isEnabled)
        flip(app.switches["consent.healthData"])
        XCTAssertTrue(proceed.isEnabled)

        let analytics = app.switches["consent.analytics"]
        XCTAssertEqual(analytics.value as? String, "0", "analytics must start off")

        proceed.tap()
        XCTAssertTrue(app.buttons["Add food"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testAccountSignInExplainsItArrivesLater() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestFreshState"]
        app.launch()
        app.buttons["Continue with Apple"].tap()
        XCTAssertTrue(app.alerts["Account sign-in arrives in a later build"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testHideNumbersRemovesTheDailyGuideLine() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestFreshState"]
        app.launch()
        app.buttons["Use without an account"].tap()
        flip(app.switches["consent.adult"])
        flip(app.switches["consent.healthData"])
        app.buttons["consent.continue"].tap()

        XCTAssertTrue(app.staticTexts["today.guide"].waitForExistence(timeout: 5))
        app.tabBars.buttons["You"].tap()
        flip(app.switches["you.hideNumbers"])
        app.tabBars.buttons["My Nuri"].tap()
        XCTAssertFalse(app.staticTexts["today.guide"].exists)
    }

    private func flip(_ toggle: XCUIElement) {
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
    }
}
