import XCTest
import ImageIO

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
        assertFullBleedCanvas(in: app.screenshot().pngRepresentation)
        app.buttons["Plan"].tap()
        XCTAssertTrue(app.buttons["Set up my plan"].waitForExistence(timeout: 10))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Weekly plan setup on iPhone 11"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    private func assertFullBleedCanvas(in png: Data) {
        guard let source = CGImageSourceCreateWithData(png as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            XCTFail("Could not inspect the rendered app screenshot")
            return
        }
        let width = image.width
        let height = image.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(data: &pixels, width: width, height: height, bitsPerComponent: 8,
                                      bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            XCTFail("Could not create a screenshot pixel buffer")
            return
        }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        let offset = ((height / 8) * width + width / 2) * 4
        let brightness = Int(pixels[offset]) + Int(pixels[offset + 1]) + Int(pixels[offset + 2])
        XCTAssertGreaterThan(brightness, 180, "The app must paint the upper canvas instead of showing a black compatibility inset")
    }

    func testFoodDraftSurvivesTabSwitch() {
        let app = launch()
        app.buttons["Log"].tap()
        app.buttons["Manual"].tap()
        let name = app.textFields["foodName"]
        reveal(name, in: app)
        name.tap()
        name.typeText("My breakfast")
        app.buttons["Today"].tap()
        app.buttons["Log"].tap()
        XCTAssertEqual(name.value as? String, "My breakfast")
    }

    func testSavedLabelReachesDailyNutrientCoverage() {
        let app = launch(fixtures: true)
        app.buttons["Log"].tap()
        app.buttons["Test oats"].tap()
        let save = app.buttons["Log this meal"]
        XCTAssertTrue(save.isEnabled)
        save.tap()
        XCTAssertTrue(app.buttons["Back to your day"].waitForExistence(timeout: 5))
        app.buttons["Back to your day"].tap()
        app.buttons["Today"].tap()
        reveal(app.staticTexts["Beyond macros".uppercased()], in: app)
        XCTAssertTrue(app.staticTexts["10 g"].exists)
        XCTAssertTrue(app.staticTexts["50 mg"].exists)
        XCTAssertTrue(app.staticTexts["0 g"].exists)
        capture(app, name: "Daily label nutrient coverage")
    }

    func testShoppingListFromSavedStapleAndBoughtState() {
        let app = launch(fixtures: true)
        app.buttons["Shop"].tap()
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Basket'")).firstMatch.tap()
        app.buttons["planShop"].tap()
        app.buttons["Saved food"].tap()
        app.buttons["Test oats"].tap()
        XCTAssertTrue(app.buttons["addStaple"].isEnabled)
        app.buttons["addStaple"].tap()
        XCTAssertTrue(app.buttons["Mark Test oats bought"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["450 g total · 3 days"].exists)
        app.buttons["Mark Test oats bought"].tap()
        XCTAssertTrue(app.buttons["Mark Test oats still needed"].exists)
        XCTAssertTrue(app.staticTexts["0 left · 1 bought"].exists)
        app.buttons["Mark Test oats still needed"].tap()
        XCTAssertTrue(app.staticTexts["1 left · 0 bought"].exists)
        capture(app, name: "Shopping checklist")
    }

    func testWorkoutRequiresActualDurationAndAppearsOnToday() {
        let app = launch()
        app.buttons["Train"].tap()
        app.buttons["Start my program"].tap()
        let complete = app.buttons["trainingComplete"]
        reveal(complete, in: app)
        capture(app, name: "Guided strength session")
        complete.tap()
        app.buttons["saveWorkout"].tap()
        XCTAssertTrue(app.staticTexts["Enter the actual session duration in minutes."].exists)
        app.textFields["workoutDuration"].tap()
        app.textFields["workoutDuration"].typeText("32")
        app.buttons["saveWorkout"].tap()
        XCTAssertTrue(app.buttons["Session logged"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["trainingComplete"].isEnabled)
        app.buttons["Today"].tap()
        reveal(app.buttons["todayTraining"], in: app)
        XCTAssertTrue(app.staticTexts["Training logged"].exists)
        capture(app, name: "Today with completed training")
    }

    @discardableResult private func launch(fixtures: Bool = false) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"] + (fixtures ? ["-seed-fixtures"] : [])
        app.launch()
        XCTAssertTrue(app.scrollViews["todayScreen"].waitForExistence(timeout: 20))
        return app
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<8 {
            if element.exists && element.isHittable { return }
            app.swipeUp()
        }
        XCTAssertTrue(element.isHittable, "Element should be reachable by scrolling: \(element)")
    }

    private func capture(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
