import XCTest

final class PlanningUITests: XCTestCase {
    func testWeeklyGoalSetupAndJournal() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()
        let todayScreen = app.scrollViews["todayScreen"]
        XCTAssertTrue(todayScreen.waitForExistence(timeout: 20))
        XCTAssertEqual(app.windows.element(boundBy: 0).frame.width, 414, accuracy: 1, "Test must run at iPhone 11 portrait width")
        XCTAssertLessThan(todayScreen.frame.minY, 60, "Today must start below the status bar, not inside a partial-height sheet")
        XCTAssertGreaterThan(todayScreen.frame.maxY, 800, "Today must use the iPhone 11 height above the tab bar")
        let todayShot = XCTAttachment(screenshot: app.screenshot())
        todayShot.name = "Today on iPhone 11"
        todayShot.lifetime = .keepAlways
        add(todayShot)
        app.tabBars.buttons["Plan"].tap()
        XCTAssertTrue(app.buttons["Set up my plan"].waitForExistence(timeout: 10))
        app.buttons["Set up my plan"].tap()
        let calories = app.textFields["weeklyCalories"]
        XCTAssertTrue(calories.waitForExistence(timeout: 10))
        let protein = app.textFields["dailyProtein"]
        XCTAssertEqual((calories.value as? String ?? "").filter(\.isNumber), "14000")
        XCTAssertEqual((protein.value as? String ?? "").filter(\.isNumber), "140")
        let save = app.buttons["saveGoals"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        save.tap()
        XCTAssertTrue(app.scrollViews["planScreen"].waitForExistence(timeout: 10))
        app.swipeUp()
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Weekly coach after saving goals"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.buttons["Edit goals"].tap()
        XCTAssertTrue(calories.waitForExistence(timeout: 10))
        let caloriesValue = (calories.value as? String ?? "").filter(\.isNumber)
        XCTAssertEqual(caloriesValue, "14000", "Weekly target must persist through sheet dismissal")
        XCTAssertEqual((protein.value as? String ?? "").filter(\.isNumber), "140")
    }
}
