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
}
