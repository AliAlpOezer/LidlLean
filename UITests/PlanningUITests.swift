import XCTest

final class PlanningUITests: XCTestCase {
    func testWeeklyGoalSetupAndJournal() throws {
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
