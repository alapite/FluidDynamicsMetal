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
        app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.5)).click()
        app.typeKey("s", modifierFlags: [])
        assertSelected("Pressure", among: fields)
        app.typeKey(XCUIKeyboardKey.space, modifierFlags: [])
        XCTAssertTrue(app.buttons["Resume simulation"].exists)
    }

    private func assertSelected(_ expected: String, among fields: [String], file: StaticString = #file, line: UInt = #line) {
        for name in fields {
            XCTAssertEqual(app.checkBoxes[name].value as? String, name == expected ? "Selected" : "Not selected", file: file, line: line)
        }
    }
}
