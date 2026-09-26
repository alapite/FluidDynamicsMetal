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
        let fields = ["Density", "Pressure", "Velocity", "Vorticity"]
        for name in fields { XCTAssertTrue(app.checkBoxes[name].waitForExistence(timeout: 10)) }
        assertSelected("Density", among: fields)

        app.checkBoxes["Vorticity"].click()
        assertSelected("Vorticity", among: fields)

        app.buttons["Pause simulation"].click()
        XCTAssertTrue(app.buttons["Resume simulation"].exists)
        app.checkBoxes["Pressure"].click()
        assertSelected("Pressure", among: fields)
        XCTAssertTrue(app.buttons["Resume simulation"].exists)

        app.buttons["Resume simulation"].click()
        XCTAssertTrue(app.buttons["Pause simulation"].exists)
        assertSelected("Pressure", among: fields)
    }

    func testCanvasShortcutsKeepControlsInSync() {
        let fields = ["Density", "Pressure", "Velocity", "Vorticity"]
        XCTAssertTrue(app.checkBoxes["Density"].waitForExistence(timeout: 10))
        // Make the Metal canvas the target before sending window shortcuts.
        app.windows["FluidDynamicsMetalOSX"].coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.5)).click()
        app.windows["FluidDynamicsMetalOSX"].typeKey("s", modifierFlags: [])
        assertSelected("Pressure", among: fields)
        app.windows["FluidDynamicsMetalOSX"].typeKey(XCUIKeyboardKey.space, modifierFlags: [])
        XCTAssertTrue(app.buttons["Resume simulation"].exists)
    }

    func testFocusedFieldSpaceSelectsWithoutPausing() {
        let vorticity = app.checkBoxes["Vorticity"]
        XCTAssertTrue(vorticity.waitForExistence(timeout: 10))
        vorticity.click()
        // The utility panel starts keyboard focus on Density; Tab moves to Pressure.
        app.typeKey(XCUIKeyboardKey.tab, modifierFlags: [])
        app.typeKey(XCUIKeyboardKey.space, modifierFlags: [])
        XCTAssertTrue(app.buttons["Pause simulation"].exists, "Space on a field control must not pause")
        assertSelected("Pressure", among: ["Density", "Pressure", "Velocity", "Vorticity"])
    }

    func testTuningDisclosureAndDefaultValuesSurvivePauseAndReopen() {
        XCTAssertTrue(app.buttons["Show Tuning"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.sliders["Force"].exists)
        app.buttons["Show Tuning"].click()
        for (name, value) in [("Force", "50%"), ("Dye", "40%"), ("Swirl", "20%"), ("Fade", "17%")] {
            let slider = app.sliders[name]
            XCTAssertTrue(slider.exists, "\(name) must be visible in Tuning")
            XCTAssertEqual(slider.value as? String, value)
        }
        app.buttons["Pause simulation"].click()
        XCTAssertTrue(app.buttons["Resume simulation"].exists)
        let force = app.sliders["Force"]
        XCTAssertTrue(force.isHittable, "Force slider frame: \(force.frame); window: \(app.windows.firstMatch.frame)")
        force.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.5)).click()
        let adjusted = force.value as? String
        XCTAssertNotEqual(adjusted, "50%")
        app.buttons["Hide Tuning"].click()
        XCTAssertFalse(force.exists)
        app.buttons["Show Tuning"].click()
        XCTAssertEqual(app.sliders["Force"].value as? String, adjusted)
        XCTAssertTrue(app.buttons["Resume simulation"].exists)
    }

    func testTuningRemainsOpenAfterCanvasAndFieldChanges() {
        XCTAssertTrue(app.buttons["Show Tuning"].waitForExistence(timeout: 10))
        app.buttons["Show Tuning"].click()
        app.checkBoxes["Velocity"].click()
        app.windows["FluidDynamicsMetalOSX"].coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.5)).click()
        XCTAssertTrue(app.buttons["Hide Tuning"].exists)
        XCTAssertTrue(app.sliders["Fade"].exists)
        XCTAssertEqual(app.checkBoxes["Velocity"].value as? String, "Selected")
    }

    func testFloatingPanelReopensWithoutChangingState() {
        let panel = app.windows["Simulation Controls"]
        XCTAssertTrue(panel.waitForExistence(timeout: 10))
        let canvas = app.windows["FluidDynamicsMetalOSX"]
        let canvasFrame = canvas.frame
        app.checkBoxes["Pressure"].click()
        app.buttons["Pause simulation"].click()
        XCTAssertEqual(canvas.frame, canvasFrame)
        panel.buttons[XCUIIdentifierCloseWindow].click()
        XCTAssertFalse(panel.exists)
        app.typeKey("k", modifierFlags: [.command, .option])
        XCTAssertTrue(panel.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Resume simulation"].exists)
        XCTAssertEqual(app.checkBoxes["Pressure"].value as? String, "Selected")
        app.typeKey("k", modifierFlags: [.command, .option])
        XCTAssertFalse(panel.exists)
    }

    private func assertSelected(_ expected: String, among fields: [String], file: StaticString = #filePath, line: UInt = #line) {
        for name in fields {
            XCTAssertEqual(app.checkBoxes[name].value as? String, name == expected ? "Selected" : "Not selected", file: file, line: line)
        }
    }
}
