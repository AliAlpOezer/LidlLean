import XCTest

final class PlanningUITests: XCTestCase {
    func testWeeklyGoalSetupAndJournal() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()
        XCTAssertTrue(app.scrollViews["todayScreen"].waitForExistence(timeout: 20))
        XCTAssertEqual(app.windows.element(boundBy: 0).frame.width, 414, accuracy: 1, "Test must run at iPhone 11 portrait width")
        let todayShot = XCTAttachment(screenshot: app.screenshot())
        todayShot.name = "Today on iPhone 11"
        todayShot.lifetime = .keepAlways
        add(todayShot)
        app.tabBars.buttons["Plan"].tap()
        XCTAssertTrue(app.buttons["Set up my plan"].waitForExistence(timeout: 10))
        app.buttons["Set up my plan"].tap()
        let calories = app.textFields["weeklyCalories"]
        XCTAssertTrue(calories.waitForExistence(timeout: 10))
        calories.tap()
        calories.typeText(XCUIKeyboardKey.delete.rawValue + "14000")
        let protein = app.textFields["dailyProtein"]
        protein.tap()
        protein.typeText(XCUIKeyboardKey.delete.rawValue + "150")
        app.swipeUp()
        let save = app.buttons["saveGoals"]
        XCTAssertTrue(save.isEnabled)
        save.tap()
        XCTAssertTrue(app.navigationBars["Plan"].waitForExistence(timeout: 10))
        app.swipeUp()
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Weekly coach after saving goals"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.buttons["Goals"].tap()
        XCTAssertTrue(calories.waitForExistence(timeout: 10))
        let caloriesValue = (calories.value as? String ?? "").filter(\.isNumber)
        XCTAssertEqual(caloriesValue, "14000", "Weekly target must persist through sheet dismissal")
        XCTAssertEqual((protein.value as? String ?? "").filter(\.isNumber), "150")
    }
}
