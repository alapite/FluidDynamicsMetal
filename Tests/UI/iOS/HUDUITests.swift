import XCTest

@MainActor
final class HUDUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    func testNamedSelectionAndPausedFieldChanges() {
        let fields = ["Dye concentration", "Pressure", "Velocity", "Vorticity"]
        for name in fields { XCTAssertTrue(app.buttons[name].waitForExistence(timeout: 15)) }
        assertSelected("Dye concentration", among: fields)

        tap(app.buttons["Vorticity"])
        assertSelected("Vorticity", among: fields)

        tap(app.buttons["Pause simulation"])
        XCTAssertTrue(app.buttons["Resume simulation"].exists)
        tap(app.buttons["Pressure"])
        assertSelected("Pressure", among: fields)
        XCTAssertTrue(app.buttons["Resume simulation"].exists)

        tap(app.buttons["Resume simulation"])
        XCTAssertTrue(app.buttons["Pause simulation"].exists)
        assertSelected("Pressure", among: fields)
    }

    func testCanvasDoubleTapUpdatesHUDWithoutBreakingFieldSelection() {
        let fields = ["Dye concentration", "Pressure", "Velocity", "Vorticity"]
        XCTAssertTrue(app.buttons["Dye concentration"].waitForExistence(timeout: 15))
        // A point in the upper-left canvas is outside the lower-trailing HUD.
        let canvasPoint = app.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.2))
        canvasPoint.doubleTap()
        XCTAssertTrue(app.buttons["Resume simulation"].exists)
        assertSelected("Dye concentration", among: fields)

        tap(app.buttons["Velocity"])
        assertSelected("Velocity", among: fields)
        XCTAssertTrue(app.buttons["Resume simulation"].exists)
        app.buttons["Velocity"].doubleTap()
        XCTAssertTrue(app.buttons["Resume simulation"].exists, "HUD-origin double tap must not toggle canvas pause shortcut")
        tap(app.buttons["Resume simulation"])
        XCTAssertTrue(app.buttons["Pause simulation"].exists)
    }

    func testTuningStartsClosedWithSharedDefaultValues() {
        XCTAssertTrue(app.buttons["Show Tuning"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.sliders["Force"].exists)
        tap(app.buttons["Show Tuning"])
        for (name, value) in [("Force", "50%"), ("Dye", "40%"), ("Swirl enhancement", "20%"), ("Dye fading", "17%"), ("Motion damping", "17%")] {
            let slider = app.sliders[name]
            XCTAssertTrue(slider.exists)
            XCTAssertEqual(slider.value as? String, value)
        }
    }

    func testTuningPersistsThroughFieldPauseAndCanvasGestures() {
        XCTAssertTrue(app.buttons["Show Tuning"].waitForExistence(timeout: 15))
        tap(app.buttons["Show Tuning"])
        let force = app.sliders["Force"]
        XCTAssertTrue(force.exists)
        reveal(force)
        force.adjust(toNormalizedSliderPosition: 0.75)
        let changed = force.value as? String
        XCTAssertNotEqual(changed, "50%")
        tap(app.buttons["Velocity"])
        tap(app.buttons["Pause simulation"])
        XCTAssertTrue(app.buttons["Resume simulation"].exists)
        XCTAssertTrue(app.buttons["Hide Tuning"].exists)
        tap(app.buttons["Hide Tuning"])
        XCTAssertFalse(app.sliders["Force"].exists)
        tap(app.buttons["Show Tuning"])
        XCTAssertEqual(app.sliders["Force"].value as? String, changed)
        app.buttons["Hide Tuning"].doubleTap()
        XCTAssertTrue(app.buttons["Resume simulation"].exists, "A HUD double tap must not toggle the canvas pause shortcut")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.2)).doubleTap()
        XCTAssertTrue(app.buttons["Pause simulation"].exists, "Outside-HUD double tap must still resume")
    }

    func testLandscapeKeepsFadeAndPauseReachableInsideHUD() {
        XCTAssertTrue(app.buttons["Show Tuning"].waitForExistence(timeout: 15))
        tap(app.buttons["Show Tuning"])
        rotate(to: .landscapeLeft)
        defer { XCUIDevice.shared.orientation = .portrait }
        let fade = app.sliders["Dye fading"]
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
        rotate(to: .landscapeLeft)
        defer { XCUIDevice.shared.orientation = .portrait }
        for name in ["Dye concentration", "Pressure", "Velocity", "Vorticity"] {
            reveal(app.buttons[name])
            XCTAssertTrue(app.buttons[name].isHittable, "\(name) must be reachable in landscape")
        }
    }

    private func reveal(_ element: XCUIElement) {
        let scroll = app.scrollViews["controlsBody"]
        for _ in 0..<16 {
            let frame = element.frame, visible = scroll.frame.insetBy(dx: 0, dy: 2)
            if element.isHittable && ((frame.minY >= visible.minY && frame.maxY <= visible.maxY) || element.identifier.hasPrefix("transport.")) { return }
            let direction: CGFloat = frame.midY < visible.midY ? -1 : 1
            let distance = min(max(abs(frame.midY - visible.midY), 12), visible.height * 0.5)
            let start = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: direction > 0 ? 0.75 : 0.25))
            let end = start.withOffset(CGVector(dx: 0, dy: -direction * distance))
            start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.1)
        }
    }
    private func tap(_ element: XCUIElement) { reveal(element); element.tap() }
    private func rotate(to orientation: UIDeviceOrientation) {
        XCUIDevice.shared.orientation = orientation
        let landscape = orientation == .landscapeLeft || orientation == .landscapeRight
        var lastFrame = CGRect.zero
        var stableSince = Date()
        let settled = NSPredicate { [weak self] _, _ in
            guard let frame = self?.app.frame else { return false }
            guard landscape ? frame.width > frame.height : frame.height > frame.width else { return false }
            if frame != lastFrame { lastFrame = frame; stableSince = Date(); return false }
            return Date().timeIntervalSince(stableSince) > 0.5
        }
        XCTAssertTrue(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: settled, object: nil)], timeout: 8) == .completed,
                      "Application must actually rotate before checking its layout")
    }
    private func chooseLesson(_ title: String) {
        app.buttons["experimentSelector"].tap()
        app.buttons[title].tap()
        XCTAssertEqual(app.staticTexts["stepCount"].label, "Step 0")
    }
    func testEveryLessonWorkflowAndSquareLayout() {
        XCTAssertTrue(app.buttons["experimentSelector"].waitForExistence(timeout: 15))
        for (index, title) in ["Dye carried by a flow", "Two interacting vortices", "Stretching dye by stirring"].enumerated() {
            chooseLesson(title)
            app.buttons["transport.step"].tap()
            XCTAssertTrue(app.staticTexts["Step 1"].waitForExistence(timeout: 5))
            tap(app.buttons["field.1"])
            XCTAssertEqual(app.staticTexts["stepCount"].label, "Step 1")
            reveal(app.switches["overlay.2"]); app.switches["overlay.2"].tap()
            XCTAssertEqual(app.staticTexts["stepCount"].label, "Step 1")
            app.buttons["transport.restart"].tap()
            XCTAssertEqual(app.staticTexts["stepCount"].label, "Step 0")
            XCTAssertEqual(app.buttons["field.1"].value as? String, "Selected")
            tap(app.buttons["experimentAdjustment"])
            let choice = ["1.5 cells per step", "Opposite rotation", "Strong"][index]
            app.buttons[choice].tap()
            XCTAssertEqual(app.staticTexts["stepCount"].label, "Step 0")
            app.buttons["transport.pause"].tap(); XCTAssertFalse(app.buttons["transport.step"].isEnabled)
            app.buttons["transport.pause"].tap(); XCTAssertTrue(app.buttons["transport.step"].isEnabled)
            for orientation in [UIDeviceOrientation.portrait, .landscapeLeft] {
                rotate(to: orientation)
                let canvas = app.images["lessonCanvas"], controls = app.otherElements["simulationControls"]
                XCTAssertTrue(canvas.waitForExistence(timeout: 5))
                XCTAssertEqual(canvas.frame.width, canvas.frame.height, accuracy: 1)
                XCTAssertFalse(canvas.frame.intersects(controls.frame), "Lesson canvas must not intersect controls")
                XCTAssertTrue(app.buttons["transport.pause"].isHittable)
                let capture = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); capture.name = "iOS-lesson-\(index)-\(orientation.rawValue)"; capture.lifetime = .keepAlways; add(capture)
            }
            rotate(to: .portrait)
        }
        app.buttons["experimentSelector"].tap(); app.buttons["Free Play"].tap()
        XCTAssertFalse(app.buttons["transport.step"].isEnabled)
    }

    func testExperimentMenuRemainsTwoDOnly() {
        let selector = app.buttons["experimentSelector"]
        XCTAssertTrue(selector.waitForExistence(timeout: 15))
        selector.tap()

        for title in ["Free Play", "Dye carried by a flow", "Two interacting vortices", "Stretching dye by stirring"] {
            XCTAssertTrue(app.buttons[title].waitForExistence(timeout: 5), "The existing 2D mode \(title) must remain available")
        }
        XCTAssertFalse(app.buttons["3D Dye Advection"].exists)
        XCTAssertFalse(app.staticTexts["3D"].exists)

        app.buttons["Dye carried by a flow"].tap()
        XCTAssertEqual(app.staticTexts["stepCount"].label, "Step 0")
        app.buttons["transport.step"].tap()
        XCTAssertTrue(app.staticTexts["Step 1"].waitForExistence(timeout: 5))

        selector.tap()
        XCTAssertTrue(app.buttons["Free Play"].waitForExistence(timeout: 5))
        app.buttons["Free Play"].tap()
        XCTAssertFalse(app.buttons["transport.step"].isEnabled)
    }

    func testLessonCompletion() {
        XCTAssertTrue(app.buttons["experimentSelector"].waitForExistence(timeout: 15))
        chooseLesson("Dye carried by a flow"); app.buttons["transport.pause"].tap()
        XCTAssertTrue(app.staticTexts["Experiment complete. Restart to compare."].waitForExistence(timeout: 45))
        XCTAssertFalse(app.buttons["transport.step"].isEnabled); XCTAssertFalse(app.buttons["transport.pause"].isEnabled)
        app.buttons["transport.restart"].tap(); XCTAssertTrue(app.buttons["transport.step"].isEnabled)
    }
    func testLargeTextLessonLayout() {
        app.terminate()
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch(); chooseLesson("Stretching dye by stirring")
        for orientation in [UIDeviceOrientation.portrait, .landscapeLeft] {
            rotate(to: orientation)
            XCTAssertTrue(app.buttons["transport.step"].isHittable)
            let controls = app.otherElements["simulationControls"]
            for identifier in ["experimentSelector", "transport.pause", "transport.step", "transport.restart"] {
                let button = app.buttons[identifier]
                XCTAssertTrue(controls.frame.contains(button.frame), "Pinned controls must fit inside their panel")
                for title in button.staticTexts.allElementsBoundByIndex {
                    XCTAssertTrue(button.frame.insetBy(dx: -1, dy: -1).contains(title.frame), "Button text must fit without overlapping adjacent controls")
                }
            }
            XCTAssertFalse(app.images["lessonCanvas"].frame.intersects(app.otherElements["simulationControls"].frame))
            let capture = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); capture.name = "iOS-large-text-\(orientation.rawValue)"; capture.lifetime = .keepAlways; add(capture)
        }
        XCUIDevice.shared.orientation = .portrait
    }

    func testLessonPresentationInBothOrientations() {
        XCTAssertTrue(app.buttons["experimentSelector"].waitForExistence(timeout: 15))
        for (index, title) in ["Dye carried by a flow", "Two interacting vortices", "Stretching dye by stirring"].enumerated() {
            rotate(to: .portrait)
            chooseLesson(title)
            for orientation in [UIDeviceOrientation.portrait, .landscapeLeft] {
                rotate(to: orientation)
                XCTAssertEqual(app.staticTexts["stepCount"].label, "Step 0")
                let canvas = app.images["lessonCanvas"], controls = app.otherElements["simulationControls"]
                XCTAssertEqual(canvas.frame.width, canvas.frame.height, accuracy: 1)
                XCTAssertFalse(canvas.frame.intersects(controls.frame))
                XCTAssertTrue(app.buttons["transport.step"].isHittable)
                let capture = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
                capture.name = "lesson-presentation-\(index)-\(orientation.rawValue)"
                capture.lifetime = .keepAlways; add(capture)
            }
        }
        rotate(to: .portrait)
    }

    private func assertSelected(_ expected: String, among fields: [String], file: StaticString = #filePath, line: UInt = #line) {
        for name in fields {
            XCTAssertEqual(app.buttons[name].value as? String, name == expected ? "Selected" : "Not selected", file: file, line: line)
        }
    }
}
