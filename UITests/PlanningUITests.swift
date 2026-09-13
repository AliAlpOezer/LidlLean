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
        replaceText(in: calories, with: "14000")
        let protein = app.textFields["dailyProtein"]
        replaceText(in: protein, with: "150")
        app.swipeUp()
        let save = app.buttons["saveGoals"]
        let enabled = NSPredicate(format: "enabled == true")
        expectation(for: enabled, evaluatedWith: save)
        waitForExpectations(timeout: 5)
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

    private func replaceText(in field: XCUIElement, with value: String) {
        field.tap()
        let existingCount = (field.value as? String ?? "").count
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: max(existingCount, 1)))
        field.typeText(value)
    }
}
