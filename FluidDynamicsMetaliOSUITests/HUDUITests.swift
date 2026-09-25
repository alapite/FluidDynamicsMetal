import XCTest

final class HUDUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    func testNamedSelectionAndPausedFieldChanges() {
        let fields = ["Density", "Pressure", "Velocity", "Vorticity"]
        for name in fields { XCTAssertTrue(app.buttons[name].waitForExistence(timeout: 15)) }
        assertSelected("Density", among: fields)

        app.buttons["Vorticity"].tap()
        assertSelected("Vorticity", among: fields)

        app.buttons["Pause simulation"].tap()
        XCTAssertTrue(app.buttons["Resume simulation"].exists)
        app.buttons["Pressure"].tap()
        assertSelected("Pressure", among: fields)
        XCTAssertTrue(app.buttons["Resume simulation"].exists)

        app.buttons["Resume simulation"].tap()
        XCTAssertTrue(app.buttons["Pause simulation"].exists)
        assertSelected("Pressure", among: fields)
    }

    func testCanvasDoubleTapUpdatesHUDWithoutBreakingFieldSelection() {
        let fields = ["Density", "Pressure", "Velocity", "Vorticity"]
        XCTAssertTrue(app.buttons["Density"].waitForExistence(timeout: 15))
        // A point in the upper-left canvas is outside the lower-trailing HUD.
        let canvasPoint = app.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.2))
        canvasPoint.doubleTap()
        XCTAssertTrue(app.buttons["Resume simulation"].exists)
        assertSelected("Density", among: fields)

        app.buttons["Velocity"].tap()
        assertSelected("Velocity", among: fields)
        XCTAssertTrue(app.buttons["Resume simulation"].exists)
        app.buttons["Velocity"].doubleTap()
        XCTAssertTrue(app.buttons["Resume simulation"].exists, "HUD-origin double tap must not toggle canvas pause shortcut")
        app.buttons["Resume simulation"].tap()
        XCTAssertTrue(app.buttons["Pause simulation"].exists)
    }

    func testTuningStartsClosedWithSharedDefaultValues() {
        XCTAssertTrue(app.buttons["Show Tuning"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.sliders["Force"].exists)
        app.buttons["Show Tuning"].tap()
        for (name, value) in [("Force", "50%"), ("Dye", "40%"), ("Swirl", "20%"), ("Fade", "17%")] {
            let slider = app.sliders[name]
            XCTAssertTrue(slider.exists)
            XCTAssertEqual(slider.value as? String, value)
        }
    }

    func testTuningPersistsThroughFieldPauseAndCanvasGestures() {
        XCTAssertTrue(app.buttons["Show Tuning"].waitForExistence(timeout: 15))
        app.buttons["Show Tuning"].tap()
        let force = app.sliders["Force"]
        XCTAssertTrue(force.exists)
        force.adjust(toNormalizedSliderPosition: 0.75)
        let changed = force.value as? String
        XCTAssertNotEqual(changed, "50%")
        app.buttons["Velocity"].tap()
        app.buttons["Pause simulation"].tap()
        XCTAssertTrue(app.buttons["Resume simulation"].exists)
        XCTAssertTrue(app.buttons["Hide Tuning"].exists)
        app.buttons["Hide Tuning"].tap()
        XCTAssertFalse(app.sliders["Force"].exists)
        app.buttons["Show Tuning"].tap()
        XCTAssertEqual(app.sliders["Force"].value as? String, changed)
        app.buttons["Hide Tuning"].doubleTap()
        XCTAssertTrue(app.buttons["Resume simulation"].exists, "A HUD double tap must not toggle the canvas pause shortcut")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.2)).doubleTap()
        XCTAssertTrue(app.buttons["Pause simulation"].exists, "Outside-HUD double tap must still resume")
    }

    func testLandscapeKeepsFadeAndPauseReachableInsideHUD() {
        XCTAssertTrue(app.buttons["Show Tuning"].waitForExistence(timeout: 15))
        app.buttons["Show Tuning"].tap()
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        let fade = app.sliders["Fade"]
        for _ in 0..<8 where !fade.isHittable {
            app.scrollViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(fade.isHittable, "Fade must be scroll-reachable in landscape")
        fade.adjust(toNormalizedSliderPosition: 0.8)
        XCTAssertNotEqual(fade.value as? String, "17%")
        for _ in 0..<8 where !app.buttons["Pause simulation"].isHittable {
            app.scrollViews.firstMatch.swipeDown()
        }
        XCTAssertTrue(app.buttons["Pause simulation"].isHittable)
    }

    func testLandscapeClosedHudStillExposesAllFields() {
        XCTAssertTrue(app.buttons["Show Tuning"].waitForExistence(timeout: 15))
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        for name in ["Density", "Pressure", "Velocity", "Vorticity"] {
            XCTAssertTrue(app.buttons[name].isHittable, "\(name) must be reachable in landscape")
        }
    }

    private func assertSelected(_ expected: String, among fields: [String], file: StaticString = #file, line: UInt = #line) {
        for name in fields {
            XCTAssertEqual(app.buttons[name].value as? String, name == expected ? "Selected" : "Not selected", file: file, line: line)
        }
    }
}
