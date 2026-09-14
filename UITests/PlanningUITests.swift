import XCTest

final class PlanningUITests: XCTestCase {
    func testTodayLaunchesAndPlanIsReachable() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()
        let todayScreen = app.scrollViews["todayScreen"]
        XCTAssertTrue(todayScreen.waitForExistence(timeout: 20))
        let window = app.windows.element(boundBy: 0)
        XCTAssertEqual(window.frame.width, 414, accuracy: 1, "Test must run at iPhone 11 portrait width")
        let todayShot = XCTAttachment(screenshot: app.screenshot())
        todayShot.name = "Today on iPhone 11"
        todayShot.lifetime = .keepAlways
        add(todayShot)
        app.buttons["Plan"].tap()
        XCTAssertTrue(app.buttons["Set up my plan"].waitForExistence(timeout: 10))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Weekly plan setup on iPhone 11"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}
