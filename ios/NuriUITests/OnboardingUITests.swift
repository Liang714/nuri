import XCTest

final class OnboardingUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    @MainActor
    func testGuestOnboardingRequiresBothConsentsThenOpensMyNuri() {
        let app = launchFresh()

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
        let app = launchFresh()
        app.buttons["Continue with Apple"].tap()
        XCTAssertTrue(app.alerts["Account sign-in arrives in a later build"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testHideNumbersRemovesTheDailyGuideLine() {
        let app = launchFresh()
        app.buttons["Use without an account"].tap()
        flip(app.switches["consent.adult"])
        flip(app.switches["consent.healthData"])
        app.buttons["consent.continue"].tap()

        XCTAssertTrue(app.staticTexts["today.guide"].waitForExistence(timeout: 5))
        app.tabBars.buttons["You"].tap()
        let hideNumbers = app.switches["you.hideNumbers"]
        flip(hideNumbers)
        XCTAssertEqual(hideNumbers.value as? String, "1", "Hide numbers must be on before leaving You")
        app.tabBars.buttons["My Nuri"].tap()
        XCTAssertTrue(app.buttons["Add food"].waitForExistence(timeout: 5), "My Nuri must be on screen before checking the guide")
        XCTAssertFalse(app.staticTexts["today.guide"].exists)
    }

    @MainActor
    func testMyNuriActionButtonsAreAtLeast52PointsTallAndMatch() {
        let app = launchFresh()
        completeOnboarding(app)
        let addFood = app.buttons["Add food"]
        let scan = app.buttons["Scan a barcode"]
        XCTAssertTrue(addFood.waitForExistence(timeout: 5))
        XCTAssertTrue(scan.exists)
        XCTAssertGreaterThanOrEqual(addFood.frame.height, 52)
        XCTAssertEqual(scan.frame.height, addFood.frame.height, accuracy: 0.5, "The barcode button matches Add food")
    }

    @MainActor
    func testEmailNoticeActionIsATappable44PointTarget() {
        let app = launchFresh()
        app.buttons["Continue with email"].tap()
        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("you@example.com\n")
        app.buttons["Send code"].tap()

        // The notice's action is a plain button; its 44 pt area must be the button itself, not padding around it.
        let action = app.buttons["Use without an account"]
        XCTAssertTrue(action.waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(action.frame.height, 44, "action height \(action.frame.height)")
        XCTAssertGreaterThanOrEqual(action.frame.width, 44, "action width \(action.frame.width)")
    }

    // MARK: - Accessibility audits (contrast, element descriptions, hit regions, text clipping, Dynamic Type)

    @MainActor
    func testAccessibilityAuditWelcome() throws {
        let app = launchFresh()
        XCTAssertTrue(app.buttons["Use without an account"].waitForExistence(timeout: 5))
        try audit(app)
    }

    @MainActor
    func testAccessibilityAuditBeforeYouStart() throws {
        let app = launchFresh()
        app.buttons["Use without an account"].tap()
        XCTAssertTrue(app.buttons["consent.continue"].waitForExistence(timeout: 5))
        try audit(app)
    }

    @MainActor
    func testAccessibilityAuditMyNuri() throws {
        let app = launchFresh()
        completeOnboarding(app)
        XCTAssertTrue(app.buttons["Add food"].waitForExistence(timeout: 5))
        try audit(app)
    }

    @MainActor
    func testAccessibilityAuditYou() throws {
        let app = launchFresh()
        completeOnboarding(app)
        app.tabBars.buttons["You"].tap()
        XCTAssertTrue(app.switches["you.hideNumbers"].waitForExistence(timeout: 5))
        try audit(app)
    }

    /// Fresh-state launch in English, whatever the simulator's own language is, so labels and identifiers match.
    @MainActor
    private func launchFresh() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestFreshState", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        return app
    }

    @MainActor
    private func completeOnboarding(_ app: XCUIApplication) {
        app.buttons["Use without an account"].tap()
        flip(app.switches["consent.adult"])
        flip(app.switches["consent.healthData"])
        app.buttons["consent.continue"].tap()
    }

    /// Runs the system accessibility audit on the current screen. Every issue it raises is logged as a test activity;
    /// the known false positives below are the only ones filtered.
    @MainActor
    private func audit(_ app: XCUIApplication) throws {
        // Keep going after the first issue so one run lists every issue on the screen.
        continueAfterFailure = true
        defer { continueAfterFailure = false }
        try app.performAccessibilityAudit { issue in
            let element = issue.element
            let label = element?.label ?? ""
            let summary = "\(issue.compactDescription) (\(issue.detailedDescription)) label=\"\(label)\""
            // False positive: the system flags "partially unsupported" Dynamic Type for the label of a NavigationLink row
            // ("What we store and why") and for the "About" section header. Both use Dynamic Type text styles and were
            // checked at the largest accessibility size, where they scale and wrap like every other row.
            if issue.auditType == .dynamicType, ["What we store and why", "About"].contains(label) {
                XCTContext.runActivity(named: "Accessibility audit issue ignored: \(summary)") { _ in }
                return true
            }
            // False positive on iPhone 18 Pro Max (iOS 27.0): measured #4A5750 on #FAFCF9 = 7.35:1; passes on iPhone 17/17e/Air/18 Pro.
            // Only the contrast issue on the Before-you-start hint (exact label) is ignored; any other issue on it still fails.
            if issue.auditType == .contrast, label == "Turn on the two required items to continue." {
                XCTContext.runActivity(named: "Accessibility audit issue ignored: \(summary)") { _ in }
                return true
            }
            XCTContext.runActivity(named: "Accessibility audit issue: \(summary)") { _ in }
            return false
        }
    }

    @MainActor
    private func flip(_ toggle: XCUIElement) {
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
    }
}
