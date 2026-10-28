import XCTest

/// Drives the simulator through the surfaces that can only be verified by real
/// interaction: the app's own screens and the pull-down Notification Center.
///
/// The Dynamic Island is captured too, but only to record that it stays empty —
/// the activity is not meant to appear there.
///
/// Screenshots are attached to the test result bundle; verify.sh exports them.
final class WorkdayUITests: XCTestCase {
    private var app: XCUIApplication!
    private let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    private func capture(_ name: String) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    /// iOS asks once, on the first activity, whether the app may show Live
    /// Activities. The prompt is attached to the card itself, so it has to be
    /// answered before the card can be screenshotted on its own.
    private func grantLiveActivityPermissionIfAsked() {
        let allow = springboard.buttons["允许"]
        if allow.waitForExistence(timeout: 3) {
            allow.tap()
            sleep(2)
        }
    }

    /// The app home screen and the settings sheet.
    func testAppScreens() {
        app.launch()
        XCTAssertTrue(
            app.staticTexts["工作日"].waitForExistence(timeout: 10),
            "app home did not appear"
        )
        capture("10-app-home")

        // The settings entry point is the only toolbar button on the home screen.
        let gear = app.navigationBars.buttons.firstMatch
        XCTAssertTrue(gear.waitForExistence(timeout: 5), "settings button missing")
        gear.tap()

        XCTAssertTrue(
            app.staticTexts["工作时间"].waitForExistence(timeout: 5),
            "settings sheet did not appear"
        )
        capture("11-app-settings")

        // Scroll to the bottom so the 关于 section (author credit) is visible.
        app.swipeUp()
        app.swipeUp()
        capture("12-app-settings-about")
    }

    /// The Live Activity once the app is no longer foreground: a card in the
    /// pull-down Notification Center, and nothing in the Dynamic Island.
    func testLiveActivitySurfaces() {
        app.launch()
        XCTAssertTrue(
            app.staticTexts["工作日"].waitForExistence(timeout: 10),
            "app home did not appear"
        )
        // The app starts the activity on foreground; give ActivityKit a moment.
        sleep(3)

        XCUIDevice.shared.press(.home)
        sleep(3)

        // Notification Center first: the one-time permission prompt is attached
        // to the card there, and it has to be answered before anything shows.
        openNotificationCenter()
        grantLiveActivityPermissionIfAsked()
        capture("22-notification-center")

        // Home dismisses Notification Center. Swiping down again would just
        // re-open it. The island should be back to its plain pill here.
        XCUIDevice.shared.press(.home)
        sleep(3)
        capture("20-island-empty")

        // Long-pressing must not surface an empty expanded panel either.
        springboard
            .coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.016))
            .press(forDuration: 1.3)
        sleep(3)
        capture("21-island-longpress-empty")
    }

    /// Swipes down from the top-left — away from the island, so the gesture
    /// opens Notification Center rather than Control Center.
    private func openNotificationCenter() {
        let top = springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.0))
        let bottom = springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.7))
        top.press(forDuration: 0.1, thenDragTo: bottom)
        sleep(3)
    }
}
