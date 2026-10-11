import XCTest

/// Walks the profile steps and saves a screenshot of each to `build/screenshots/profile-*.png` (light, dark, Korean and the
/// daily-guide variants). It is a tool, not a test: it skips itself unless the run asks for it, so the normal suite stays fast.
///
///     TEST_RUNNER_NURI_SCREENSHOTS=1 xcodebuild test -project ios/Nuri.xcodeproj -scheme Nuri \
///       -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath build/DerivedData \
///       -parallel-testing-enabled NO -only-testing:NuriUITests/ProfileScreenshotTour
final class ProfileScreenshotTour: XCTestCase {
    /// `.../ios/NuriUITests/ProfileScreenshotTour.swift` is three levels below the repo root.
    private static let folder = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("build/screenshots").path

    override func setUpWithError() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["NURI_SCREENSHOTS"] == "1",
                          "Screenshot tour: set TEST_RUNNER_NURI_SCREENSHOTS=1 to run it")
        continueAfterFailure = false
    }

    override func tearDown() { XCUIDevice.shared.appearance = .light }

    @MainActor
    func testLightAndDark() {
        XCUIDevice.shared.appearance = .light
        tour(language: "en", locale: "en_US", suffix: "light")
        XCUIDevice.shared.appearance = .dark
        tour(language: "en", locale: "en_US", suffix: "dark")
    }

    @MainActor
    func testKorean() {
        XCUIDevice.shared.appearance = .light
        tour(language: "ko", locale: "ko_KR", suffix: "ko")
    }

    /// Step 7 without a sex value, with a number under the commonly suggested minimum (committed with Done), with a number that
    /// cannot be used, and with numbers hidden (no sex value, then tracking without a guide).
    @MainActor
    func testGuideVariants() {
        XCUIDevice.shared.appearance = .light
        var app = launch(language: "en", locale: "en_US")
        for _ in 1..<7 { app.buttons["profile.continue"].tap() }
        step(app, 7)
        shot("profile-7-nosex-light")
        let manual = app.textFields["profile.manualTarget"]
        manual.tap()
        manual.typeText("900")
        app.buttons["profile.manualTarget.done"].tap()
        shot("profile-7-manual-below-light")
        // The numbers are right-aligned: a tap at the very end of the field puts the caret after them, where Delete works.
        manual.coordinate(withNormalizedOffset: CGVector(dx: 0.99, dy: 0.5)).tap()
        manual.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 3) + "0")
        shot("profile-7-manual-invalid-light")

        app = launch(language: "en", locale: "en_US")
        app.segmentedControls["profile.sex"].buttons.element(boundBy: 1).tap()
        for _ in 1..<6 { app.buttons["profile.continue"].tap() }
        step(app, 6)
        flip(app.switches["profile.hideNumbers"])
        shot("profile-6-hidden-light")
        app.buttons["profile.continue"].tap()
        step(app, 7)
        shot("profile-7-hidden-light")

        app = launch(language: "en", locale: "en_US")
        for _ in 1..<6 { app.buttons["profile.continue"].tap() }
        step(app, 6)
        flip(app.switches["profile.hideNumbers"])
        app.buttons["profile.continue"].tap()
        step(app, 7)
        shot("profile-7-hidden-nosex-light")
        flip(app.switches["profile.trackWithoutGuide"])
        shot("profile-7-hidden-tracking-light")
    }

    /// Steps 1, 2 and 7 at the largest accessibility text size (menus instead of wheels and segments, labels that wrap).
    @MainActor
    func testAccessibilitySize() {
        XCUIDevice.shared.appearance = .light
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestFreshState", "-uiTestSkipToProfile", "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        step(app, 1)
        shot("profile-1-ax-light")
        for n in 2...7 {
            app.buttons["profile.continue"].tap()
            step(app, n)
            if n == 2 || n == 7 { shot("profile-\(n)-ax-light") }
        }
        app.swipeUp()
        shot("profile-7-ax-scrolled-light")
    }

    // MARK: - Helpers

    @MainActor
    private func tour(language: String, locale: String, suffix: String) {
        let app = launch(language: language, locale: locale)
        for n in 1...7 {
            step(app, n)
            shot("profile-\(n)-\(suffix)")
            if n == 1 { app.segmentedControls["profile.sex"].buttons.element(boundBy: 1).tap() }   // Male, so step 7 shows a guide
            if n < 7 { app.buttons["profile.continue"].tap() }
        }
    }

    @MainActor
    private func launch(language: String, locale: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestFreshState", "-AppleLanguages", "(\(language))", "-AppleLocale", locale]
        app.launch()
        app.buttons["welcome.withoutAccount"].tap()
        flip(app.switches["consent.adult"])
        flip(app.switches["consent.healthData"])
        app.buttons["consent.continue"].tap()
        step(app, 1)
        return app
    }

    @MainActor
    private func step(_ app: XCUIApplication, _ number: Int) {
        XCTAssertTrue(app.descendants(matching: .any)["profile.step.\(number)"].waitForExistence(timeout: 8), "step \(number)")
    }

    @MainActor
    private func flip(_ toggle: XCUIElement) {
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
    }

    @MainActor
    private func shot(_ name: String) {
        Thread.sleep(forTimeInterval: 0.8)
        let png = XCUIScreen.main.screenshot().pngRepresentation
        try? FileManager.default.createDirectory(atPath: Self.folder, withIntermediateDirectories: true)
        try? png.write(to: URL(fileURLWithPath: "\(Self.folder)/\(name).png"))
    }
}
