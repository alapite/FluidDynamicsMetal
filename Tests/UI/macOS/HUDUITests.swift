import AppKit
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
        for name in fields { XCTAssertTrue(app.checkBoxes[name].waitForExistence(timeout: 10)) }
        assertSelected("Dye concentration", among: fields)

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
        let fields = ["Dye concentration", "Pressure", "Velocity", "Vorticity"]
        XCTAssertTrue(app.checkBoxes["Dye concentration"].waitForExistence(timeout: 10))
        // The floating panel can cover the chosen canvas point and keep an NSControl
        // as first responder. Dismiss it before focusing the Metal view explicitly.
        let panel = app.windows["Simulation Controls"]
        XCTAssertTrue(panel.waitForExistence(timeout: 10))
        panel.buttons[XCUIIdentifierCloseWindow].click()
        XCTAssertFalse(panel.exists)

        let canvas = app.windows["FluidDynamicsMetalOSX"]
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.5)).click()
        canvas.typeKey("s", modifierFlags: [])
        app.typeKey("k", modifierFlags: [.command, .option])
        XCTAssertTrue(panel.waitForExistence(timeout: 5))
        assertSelected("Pressure", among: fields)

        panel.buttons[XCUIIdentifierCloseWindow].click()
        XCTAssertFalse(panel.exists)
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.5)).click()
        canvas.typeKey(XCUIKeyboardKey.space, modifierFlags: [])
        app.typeKey("k", modifierFlags: [.command, .option])
        XCTAssertTrue(panel.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Resume simulation"].exists)
    }

    func testFocusedExperimentSpaceDoesNotPauseCanvas() {
        let selector = app.popUpButtons["experimentSelector"]
        XCTAssertTrue(selector.waitForExistence(timeout: 10))
        selector.click(); selector.menuItems["Free Play"].click()
        app.typeKey(XCUIKeyboardKey.space, modifierFlags: [])
        XCTAssertTrue(app.buttons["transport.pause"].label.contains("Pause"))
        app.typeKey(XCUIKeyboardKey.escape, modifierFlags: [])
    }

    func testTuningDisclosureAndDefaultValuesSurvivePauseAndReopen() {
        XCTAssertTrue(app.buttons["Show Tuning"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.sliders["Force"].exists)
        app.buttons["Show Tuning"].click()
        for (name, value) in [("Force", "50%"), ("Dye", "40%"), ("Swirl enhancement", "20%"), ("Dye fading", "17%"), ("Motion damping", "17%")] {
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
        XCTAssertTrue(app.sliders["Dye fading"].exists)
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

    func testMouseDragProducesVisibleDyeAndPausedResizePreservesIt() throws {
        let panel = app.windows["Simulation Controls"]
        XCTAssertTrue(panel.waitForExistence(timeout: 10))
        panel.buttons[XCUIIdentifierCloseWindow].click()
        let canvas = app.windows["FluidDynamicsMetalOSX"]

        func dyePixels() throws -> Int {
            let screenshot = canvas.screenshot()
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.lifetime = .keepAlways
            add(attachment)
            let bitmap = try XCTUnwrap(NSBitmapImageRep(data: screenshot.pngRepresentation))
            var count = 0
            // Exclude window chrome and scan only the canvas interior.
            for y in stride(from: bitmap.pixelsHigh / 5, to: bitmap.pixelsHigh * 4 / 5, by: 4) {
                for x in stride(from: bitmap.pixelsWide / 10, to: bitmap.pixelsWide * 9 / 10, by: 4) {
                    let color = try XCTUnwrap(bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB))
                    if color.blueComponent > color.redComponent + 0.03 &&
                       color.blueComponent > color.greenComponent + 0.015 { count += 1 }
                }
            }
            return count
        }

        XCTAssertEqual(try dyePixels(), 0, "A fresh density field must start empty")
        let start = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.4))
        let end = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.65, dy: 0.6))
        start.click(forDuration: 0.5, thenDragTo: end)
        canvas.typeKey(XCUIKeyboardKey.space, modifierFlags: [])
        XCTAssertGreaterThan(try dyePixels(), 10, "Real mouse input must deposit visible dye")

        let oldFrame = canvas.frame
        let corner = canvas.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 1))
            .withOffset(CGVector(dx: -2, dy: -2))
        corner.click(forDuration: 0.2, thenDragTo: corner.withOffset(CGVector(dx: -100, dy: -60)))
        XCTAssertNotEqual(canvas.frame.size, oldFrame.size)
        XCTAssertGreaterThan(try dyePixels(), 10, "Paused resize must preserve existing dye")
        app.typeKey("k", modifierFlags: [.command, .option])
        XCTAssertTrue(app.buttons["Resume simulation"].waitForExistence(timeout: 5))
        app.buttons["Resume simulation"].click()
        XCTAssertTrue(app.buttons["Pause simulation"].exists)
    }

    func testEveryLessonWorkflowAndKeyboardCommands() {
        XCTAssertTrue(app.popUpButtons["experimentSelector"].waitForExistence(timeout: 10))
        for index in 2...4 {
            command(String(index))
            XCTAssertEqual(app.staticTexts["stepCount"].value as? String, "Step 0")
            XCTAssertTrue(app.buttons["transport.step"].isEnabled)
            command(XCUIKeyboardKey.rightArrow.rawValue)
            XCTAssertTrue(app.staticTexts["Step 1"].waitForExistence(timeout: 5))
            app.checkBoxes["field.1"].click()
            XCTAssertEqual(app.staticTexts["stepCount"].value as? String, "Step 1")
            command("r")
            XCTAssertEqual(app.staticTexts["stepCount"].value as? String, "Step 0")
            XCTAssertEqual(app.checkBoxes["field.1"].value as? String, "Selected")
            let adjustment = app.popUpButtons["experimentAdjustment"]
            adjustment.click()
            adjustment.menuItems[["1.5 cells per step", "Opposite rotation", "Strong"][index - 2]].click()
            XCTAssertEqual(app.staticTexts["stepCount"].value as? String, "Step 0")
            command("p")
            XCTAssertFalse(app.buttons["transport.step"].isEnabled)
            command("p")
            XCTAssertTrue(app.buttons["transport.step"].isEnabled)
            for name in ["FluidDynamicsMetalOSX", "Simulation Controls"] {
                let capture = XCTAttachment(screenshot: app.windows[name].screenshot())
                capture.name = "Mac-lesson-\(index)-\(name)"; capture.lifetime = .keepAlways; add(capture)
            }
        }
        command("1")
        XCTAssertEqual(app.popUpButtons["experimentSelector"].value as? String, "Free Play")
        XCTAssertFalse(app.buttons["transport.step"].isEnabled)
    }

    func testThreeDGroupedNavigationAndTransport() throws {
        let selector = app.popUpButtons["experimentSelector"]
        XCTAssertTrue(selector.waitForExistence(timeout: 10))
        selector.click()

        let selectorItems = selector.menuItems
        let twoDHeading = selectorItems["2D"]
        let threeDHeading = selectorItems["3D"]
        XCTAssertTrue(twoDHeading.exists)
        XCTAssertTrue(threeDHeading.exists)
        XCTAssertFalse(twoDHeading.isEnabled)
        XCTAssertFalse(threeDHeading.isEnabled)
        let rows = selectorItems.allElementsBoundByIndex
        let expectedRows: [(Int, XCUIElement)] = [
            (0, twoDHeading),
            (1, selectorItems["Free Play"]),
            (2, selectorItems["Dye carried by a flow"]),
            (3, selectorItems["Two interacting vortices"]),
            (4, selectorItems["Stretching dye by stirring"]),
            (6, threeDHeading),
            (7, selectorItems["3D Dye Advection"]),
        ]
        XCTAssertEqual(rows.count, 8, "The selector must contain two groups and one native separator")
        for (index, expected) in expectedRows {
            XCTAssertEqual(rows[index].frame, expected.frame, "Unexpected selector row at index \(index)")
        }
        XCTAssertFalse(rows[5].isEnabled, "The group separator must not be selectable")
        XCTAssertTrue(selectorItems["Free Play"].isSelected)
        XCTAssertFalse(twoDHeading.isSelected)
        XCTAssertFalse(threeDHeading.isSelected)
        selectorItems["3D Dye Advection"].click()

        XCTAssertEqual(selector.value as? String, "3D Dye Advection")
        XCTAssertEqual(app.staticTexts["stepCount"].value as? String, "Step 0")
        XCTAssertTrue(app.buttons["Run"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["transport.step"].isEnabled)

        let simulationMenu = app.menuBars.menuBarItems["Simulation"]
        simulationMenu.click()
        let menuItems = app.menuItems
        XCTAssertTrue(menuItems["2D"].exists)
        XCTAssertFalse(menuItems["2D"].isEnabled)
        XCTAssertTrue(menuItems["3D"].exists)
        XCTAssertFalse(menuItems["3D"].isEnabled)
        XCTAssertTrue(menuItems["3D Dye Advection"].exists)
        XCTAssertEqual(selector.value as? String, "3D Dye Advection")
        let menuScreenshot = XCTAttachment(screenshot: app.screenshot())
        menuScreenshot.name = "Simulation menu with committed 3D selection"
        menuScreenshot.lifetime = .keepAlways
        add(menuScreenshot)
        app.typeKey(XCUIKeyboardKey.escape, modifierFlags: [])

        for (key, title) in [
            ("1", "Free Play"),
            ("2", "Dye carried by a flow"),
            ("3", "Two interacting vortices"),
            ("4", "Stretching dye by stirring")
        ] {
            command(key)
            assertSelectorValue(title, in: selector)
            if key == "1" {
                XCTAssertTrue(app.buttons["transport.pause"].label.contains("Pause"),
                              "Command-1 must restore fresh, running Free Play")
            } else {
                XCTAssertEqual(app.staticTexts["stepCount"].value as? String, "Step 0",
                               "2D lessons selected by Command-2–4 start paused at step 0")
            }
        }

        selector.click()
        selector.menuItems["3D Dye Advection"].click()
        XCTAssertEqual(selector.value as? String, "3D Dye Advection")
        XCTAssertEqual(app.staticTexts["stepCount"].value as? String, "Step 0")
        XCTAssertTrue(app.buttons["Run"].exists)
    }

    func testThreeDPanelFocusAndReturn() throws {
        let selector = app.popUpButtons["experimentSelector"]
        XCTAssertTrue(selector.waitForExistence(timeout: 10))

        app.checkBoxes["Vorticity"].click()
        app.buttons["Show Tuning"].click()
        selector.click()
        selector.menuItems["3D Dye Advection"].click()

        // The mode switch hides 2D-only tuning controls; AppKit may return focus
        // to the panel. Panel-originated Space is covered independently below.
        XCTAssertTrue(app.buttons["Run"].exists)
        XCTAssertEqual(app.staticTexts["stepCount"].value as? String, "Step 0")

        XCTAssertEqual(app.staticTexts["lesson3d.heading"].label, "3D Dye Advection")
        XCTAssertEqual(app.staticTexts["lesson3d.slice"].value as? String, "XY slice · Z depth: 50%")
        XCTAssertEqual(app.staticTexts["lesson3d.slice"].label, "XY slice, Z depth 50 percent")
        XCTAssertEqual(app.staticTexts["lesson3d.concentration"].label, "Dye concentration")
        XCTAssertEqual(app.staticTexts["lesson3d.legend"].value as? String, "Less dye → More dye")
        XCTAssertEqual(app.staticTexts["lesson3d.legend"].label, "Dye concentration, less dye to more dye")
        XCTAssertEqual(app.staticTexts["lesson3d.note"].label,
                       "This slice shows dye carried by an evolving 3D flow. Brighter areas contain more dye; dye can move out of the plane. There is no explicit dye fading, but numerical advection can smooth the dye. Steps count solver advances, not seconds.")
        for hiddenIdentifier in ["field.0", "overlay.0", "tuning.toggle", "about.toggle", "fieldLegend"] {
            XCTAssertFalse(app.descendants(matching: .any)[hiddenIdentifier].exists,
                            "Unsupported 2D content must be absent in 3D: \(hiddenIdentifier)")
        }

        let panel = app.windows["Simulation Controls"]
        XCTAssertTrue(panel.waitForExistence(timeout: 5))
        panel.buttons[XCUIIdentifierCloseWindow].click()
        XCTAssertFalse(panel.exists)

        let canvas = app.windows["FluidDynamicsMetalOSX"]

        // Keep the panel out of the canvas event path: S stays inert and Space
        // toggles transport once when the canvas itself owns focus.
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.5)).click()
        canvas.typeKey("s", modifierFlags: [])
        app.typeKey("k", modifierFlags: [.command, .option])
        XCTAssertTrue(panel.waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["stepCount"].value as? String, "Step 0")

        panel.buttons[XCUIIdentifierCloseWindow].click()
        XCTAssertFalse(panel.exists)
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.5)).click()
        canvas.typeKey(XCUIKeyboardKey.space, modifierFlags: [])
        app.typeKey("k", modifierFlags: [.command, .option])
        XCTAssertTrue(panel.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["transport.pause"].label.contains("Pause"))

        // Reopen the separate panel before checking the restored Free Play controls.
        command("1")
        assertSelectorValue("Free Play", in: selector)
        XCTAssertTrue(app.buttons["transport.pause"].label.contains("Pause"))
        XCTAssertEqual(app.checkBoxes["Vorticity"].value as? String, "Selected")
        XCTAssertTrue(app.buttons["Hide Tuning"].exists)
        XCTAssertTrue(app.sliders["Force"].exists)
    }

    func testPanelSpaceDoesNotResumePausedThreeD() {
        XCTAssertTrue(app.checkBoxes["Vorticity"].waitForExistence(timeout: 10))
        app.checkBoxes["Vorticity"].click()
        app.buttons["Show Tuning"].click()

        let selector = app.popUpButtons["experimentSelector"]
        XCTAssertTrue(selector.waitForExistence(timeout: 10))
        selector.click()
        selector.menuItems["3D Dye Advection"].click()

        XCTAssertTrue(app.buttons["Run"].waitForExistence(timeout: 5))
        // Closing the mode menu leaves the controls panel as first responder.
        // Space from that window must not act as a canvas transport shortcut.
        app.typeKey(XCUIKeyboardKey.space, modifierFlags: [])

        XCTAssertTrue(app.buttons["Run"].exists,
                      "Space originating in Simulation Controls must not resume the canvas")
        XCTAssertEqual(app.staticTexts["stepCount"].value as? String, "Step 0")
    }

    func testThreeDAppearanceCaptures() {
        let contrastVariant = NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
            ? "Increase Contrast" : "Standard Contrast"
        for appearance in ["Light", "Dark"] {
            app.terminate()
            app = XCUIApplication()
            app.launchArguments = ["-AppleInterfaceStyle", appearance]
            app.launch()

            let selector = app.popUpButtons["experimentSelector"]
            XCTAssertTrue(selector.waitForExistence(timeout: 10))
            selector.click()
            selector.menuItems["3D Dye Advection"].click()
            XCTAssertTrue(app.staticTexts["lesson3d.note"].waitForExistence(timeout: 5))

            for (windowName, suffix) in [("FluidDynamicsMetalOSX", "canvas"),
                                         ("Simulation Controls", "controls panel")] {
                let attachment = XCTAttachment(screenshot: app.windows[windowName].screenshot())
                attachment.name = "3D Dye Advection — \(appearance) appearance — \(contrastVariant) — \(suffix)"
                attachment.lifetime = .keepAlways
                add(attachment)
            }
        }
    }

    func testThreeDPanelLayoutPreservesState() throws {
        let selector = app.popUpButtons["experimentSelector"]
        XCTAssertTrue(selector.waitForExistence(timeout: 10))
        selector.click()
        selector.menuItems["3D Dye Advection"].click()
        XCTAssertTrue(app.staticTexts["lesson3d.note"].waitForExistence(timeout: 5),
                      "The factual 3D note must be present in the scrollable panel")

        let step = app.staticTexts["stepCount"]
        let stepButton = app.buttons["transport.step"]
        for _ in 0..<3 { stepButton.click() }
        let reachedThree = NSPredicate(format: "value == %@", "Step 3")
        expectation(for: reachedThree, evaluatedWith: step)
        waitForExpectations(timeout: 5)

        let panel = app.windows["Simulation Controls"]
        XCTAssertTrue(panel.waitForExistence(timeout: 5))
        let scrollView = panel.scrollViews.firstMatch
        XCTAssertTrue(scrollView.waitForExistence(timeout: 5))
        scrollView.swipeUp()
        XCTAssertEqual(step.value as? String, "Step 3", "Scrolling the body must not advance the solver")

        let originalPanelOrigin = panel.frame.origin
        let titleBar = panel.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.03))
        titleBar.click(forDuration: 0.2, thenDragTo: titleBar.withOffset(CGVector(dx: 50, dy: -20)))
        XCTAssertNotEqual(panel.frame.origin, originalPanelOrigin, "The utility panel should remain movable")
        XCTAssertEqual(step.value as? String, "Step 3", "Moving the panel must not advance the solver")

        panel.buttons[XCUIIdentifierCloseWindow].click()
        XCTAssertFalse(panel.exists)
        app.typeKey("k", modifierFlags: [.command, .option])
        XCTAssertTrue(panel.waitForExistence(timeout: 5))
        XCTAssertEqual(selector.value as? String, "3D Dye Advection")
        XCTAssertEqual(step.value as? String, "Step 3", "Reopening the panel must preserve lesson state")

        let canvas = app.windows["FluidDynamicsMetalOSX"]
        let oldFrame = canvas.frame
        let corner = canvas.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 1))
            .withOffset(CGVector(dx: -2, dy: -2))
        corner.click(forDuration: 0.2, thenDragTo: corner.withOffset(CGVector(dx: -80, dy: -50)))
        XCTAssertNotEqual(canvas.frame.size, oldFrame.size)
        XCTAssertEqual(step.value as? String, "Step 3", "Resizing the canvas must not advance the solver")
    }

    func testThreeDConstrainedPanelWrapsTransportAndText() {
        app.terminate()
        app = XCUIApplication()
        app.launchArguments = ["--fluid3d-test-visible-width=256"]
        app.launch()

        let selector = app.popUpButtons["experimentSelector"]
        XCTAssertTrue(selector.waitForExistence(timeout: 10))
        selector.click()
        selector.menuItems["3D Dye Advection"].click()

        let panel = app.windows["Simulation Controls"]
        XCTAssertTrue(panel.waitForExistence(timeout: 5))
        XCTAssertLessThanOrEqual(panel.frame.width, 260,
                                 "The constrained panel must respect its narrow content-width target")

        let run = app.buttons["transport.pause"]
        let step = app.buttons["transport.step"]
        let restart = app.buttons["transport.restart"]
        XCTAssertTrue(run.isHittable)
        XCTAssertTrue(step.isHittable)
        XCTAssertTrue(restart.isHittable)
        XCTAssertGreaterThan(restart.frame.minY, run.frame.minY,
                             "Restart must wrap below the Run/Step row at constrained widths")
        XCTAssertTrue(app.staticTexts["lesson3d.note"].exists,
                       "The factual note must remain available in the wrapped, scrollable body")
    }

    func testSpatialInspectionControlsAndKeyboard() throws {
        let selector = app.popUpButtons["experimentSelector"]
        XCTAssertTrue(selector.waitForExistence(timeout: 10))
        selector.click()
        selector.menuItems["3D Dye Advection"].click()

        let panel = app.windows["Simulation Controls"]
        XCTAssertTrue(panel.waitForExistence(timeout: 5))
        let plane = app.radioGroups["inspection3d.plane"]
        let depth = app.sliders["inspection3d.depth"]
        let centreSlice = app.buttons["inspection3d.centreSlice"]
        let orbit = app.sliders["inspection3d.orbit"]
        let elevation = app.sliders["inspection3d.elevation"]
        let zoom = app.sliders["inspection3d.zoom"]
        let resetCamera = app.buttons["inspection3d.resetCamera"]

        XCTAssertTrue(plane.waitForExistence(timeout: 5))
        XCTAssertTrue(depth.exists)
        XCTAssertTrue(centreSlice.exists)
        XCTAssertTrue(orbit.exists)
        XCTAssertTrue(elevation.exists)
        XCTAssertTrue(zoom.exists)
        XCTAssertTrue(resetCamera.exists)
        XCTAssertEqual(plane.label, "Plane")
        XCTAssertEqual(depth.label, "Z depth")
        XCTAssertEqual(centreSlice.label, "Centre Slice")
        XCTAssertEqual(orbit.label, "Horizontal Orbit")
        XCTAssertEqual(elevation.label, "Elevation")
        XCTAssertEqual(zoom.label, "Zoom")
        XCTAssertEqual(resetCamera.label, "Reset Camera")
        XCTAssertEqual(app.staticTexts["lesson3d.slice"].value as? String, "XY slice · Z depth: 50%")
        XCTAssertEqual(depth.value as? String, "50%")
        XCTAssertEqual(orbit.value as? String, "+25°")
        XCTAssertEqual(elevation.value as? String, "+18°")
        XCTAssertEqual(zoom.value as? String, "100%")

        // Selection retains the popup focus. Tab through the pinned controls and
        // Plane to adjust depth using only keyboard input.
        for _ in 0..<5 { app.typeKey(XCUIKeyboardKey.tab, modifierFlags: []) }
        app.typeKey(XCUIKeyboardKey.leftArrow, modifierFlags: [])
        XCTAssertEqual(depth.value as? String, "49%")
        XCTAssertEqual(app.staticTexts["inspection3d.depthValue"].value as? String, "Z depth: 49%")

        // The next Tab reaches Centre Slice. Space must operate that focused
        // control without also toggling the canvas transport.
        app.typeKey(XCUIKeyboardKey.tab, modifierFlags: [])
        app.typeKey(XCUIKeyboardKey.space, modifierFlags: [])
        XCTAssertEqual(depth.value as? String, "50%")
        XCTAssertTrue(app.buttons["Run"].exists)
        XCTAssertEqual(app.staticTexts["stepCount"].value as? String, "Step 0")

        plane.radioButtons["XZ"].click()
        XCTAssertEqual(app.staticTexts["lesson3d.slice"].value as? String, "XZ slice · Y depth: 50%")
        XCTAssertEqual(depth.label, "Y depth")
        XCTAssertEqual(app.staticTexts["inspection3d.depthValue"].value as? String, "Y depth: 50%")

        // Camera slider arrows use their own increments, and Centre Slice changes
        // only depth even after the camera and plane have changed. Choosing a
        // plane by pointer leaves keyboard focus on Centre Slice; Tab enters Orbit.
        app.typeKey(XCUIKeyboardKey.tab, modifierFlags: [])
        app.typeKey(XCUIKeyboardKey.rightArrow, modifierFlags: [])
        app.typeKey(XCUIKeyboardKey.tab, modifierFlags: [])
        app.typeKey(XCUIKeyboardKey.upArrow, modifierFlags: [])
        app.typeKey(XCUIKeyboardKey.tab, modifierFlags: [])
        app.typeKey(XCUIKeyboardKey.rightArrow, modifierFlags: [])
        XCTAssertEqual(orbit.value as? String, "+30°")
        XCTAssertEqual(elevation.value as? String, "+21°")
        XCTAssertEqual(zoom.value as? String, "105%")

        for _ in 0..<4 { app.typeKey(XCUIKeyboardKey.tab, modifierFlags: [.shift]) }
        app.typeKey(XCUIKeyboardKey.leftArrow, modifierFlags: [])
        app.typeKey(XCUIKeyboardKey.tab, modifierFlags: [])
        app.typeKey(XCUIKeyboardKey.space, modifierFlags: [])
        XCTAssertEqual(depth.value as? String, "50%")
        XCTAssertEqual(orbit.value as? String, "+30°")
        XCTAssertEqual(elevation.value as? String, "+21°")
        XCTAssertEqual(zoom.value as? String, "105%")
        XCTAssertEqual(app.staticTexts["lesson3d.slice"].value as? String, "XZ slice · Y depth: 50%")

        app.buttons["transport.step"].click()
        XCTAssertTrue(app.staticTexts["Step 1"].waitForExistence(timeout: 5))
        resetCamera.click()
        XCTAssertEqual(orbit.value as? String, "+25°")
        XCTAssertEqual(elevation.value as? String, "+18°")
        XCTAssertEqual(zoom.value as? String, "100%")
        XCTAssertEqual(depth.value as? String, "50%")
        XCTAssertEqual(app.staticTexts["lesson3d.slice"].value as? String, "XZ slice · Y depth: 50%")
        XCTAssertEqual(app.staticTexts["stepCount"].value as? String, "Step 1")
        XCTAssertTrue(app.buttons["Resume simulation"].exists,
                      "Reset Camera must preserve the paused transport state at Step 1")
    }

    func testSpatialInspectionLayoutAndModeReturn() throws {
        app.terminate()
        app = XCUIApplication()
        app.launchArguments = ["--fluid3d-test-visible-width=256"]
        app.launch()

        let selector = app.popUpButtons["experimentSelector"]
        XCTAssertTrue(selector.waitForExistence(timeout: 10))
        selector.click()
        selector.menuItems["3D Dye Advection"].click()

        let panel = app.windows["Simulation Controls"]
        XCTAssertTrue(panel.waitForExistence(timeout: 5))
        XCTAssertLessThanOrEqual(panel.frame.width, 260)
        XCTAssertTrue(app.buttons["transport.pause"].isHittable)
        XCTAssertTrue(app.buttons["transport.step"].isHittable)
        XCTAssertGreaterThan(app.buttons["transport.restart"].frame.minY,
                             app.buttons["transport.pause"].frame.minY,
                             "Restart must remain available below Run/Step at constrained width")

        let scrollView = panel.scrollViews.firstMatch
        XCTAssertTrue(scrollView.waitForExistence(timeout: 5))
        scrollView.swipeUp()
        XCTAssertTrue(app.sliders["inspection3d.depth"].exists)
        XCTAssertTrue(app.buttons["inspection3d.resetCamera"].exists,
                      "Camera recovery must remain reachable in the scrolling body")

        let plane = app.radioGroups["inspection3d.plane"]
        plane.radioButtons["YZ"].click()
        XCTAssertEqual(app.sliders["inspection3d.depth"].label, "X depth")
        // The 3D menu selection retains the Experiments focus. Traverse through
        // pinned controls and Plane to the offscreen Depth slider by keyboard.
        for _ in 0..<5 { app.typeKey(XCUIKeyboardKey.tab, modifierFlags: []) }
        app.typeKey(XCUIKeyboardKey.leftArrow, modifierFlags: [])
        XCTAssertEqual(app.staticTexts["lesson3d.slice"].value as? String, "YZ slice · X depth: 49%")

        panel.buttons[XCUIIdentifierCloseWindow].click()
        XCTAssertFalse(panel.exists)
        app.typeKey("k", modifierFlags: [.command, .option])
        XCTAssertTrue(panel.waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["lesson3d.slice"].value as? String, "YZ slice · X depth: 49%",
                       "Closing and reopening the panel must preserve inspection state")

        selector.click()
        selector.menuItems["Dye carried by a flow"].click()
        XCTAssertFalse(app.sliders["inspection3d.depth"].exists,
                       "Hidden 3D controls must not remain in the 2D accessibility tree")
        XCTAssertTrue(app.checkBoxes["Dye concentration"].exists)
        command("4")
        XCTAssertEqual(selector.value as? String, "Stretching dye by stirring",
                       "Existing 2D experiment shortcuts must retain their meanings")
        XCTAssertTrue(app.checkBoxes["Vorticity"].exists)
    }

    func testSpatialInspectionGestureIsolation() throws {
        let selector = app.popUpButtons["experimentSelector"]
        XCTAssertTrue(selector.waitForExistence(timeout: 10))
        selector.click()
        selector.menuItems["3D Dye Advection"].click()

        let panel = app.windows["Simulation Controls"]
        XCTAssertTrue(panel.waitForExistence(timeout: 5))
        let canvas = app.windows["FluidDynamicsMetalOSX"]
        let orbit = app.sliders["inspection3d.orbit"]
        let elevation = app.sliders["inspection3d.elevation"]
        let zoom = app.sliders["inspection3d.zoom"]
        let stepCount = app.staticTexts["stepCount"]

        func number(_ slider: XCUIElement) -> Double {
            let string = slider.value as? String ?? ""
            let numeric = string.filter { "0123456789.-".contains($0) }
            return Double(numeric) ?? .nan
        }

        let initialOrbit = number(orbit)
        let initialElevation = number(elevation)
        let initialZoom = number(zoom)
        XCTAssertEqual(stepCount.value as? String, "Step 0")
        XCTAssertTrue(app.buttons["Run"].exists)

        panel.buttons[XCUIIdentifierCloseWindow].click()
        XCTAssertFalse(panel.exists)

        // A paused canvas drag changes only the committed camera, not transport.
        let dragStart = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.42, dy: 0.56))
        dragStart.click(forDuration: 0.2, thenDragTo: dragStart.withOffset(CGVector(dx: 80, dy: -40)))
        app.typeKey("k", modifierFlags: [.command, .option])
        XCTAssertTrue(panel.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(number(orbit), initialOrbit, "Rightward drag must increase yaw")
        XCTAssertGreaterThan(number(elevation), initialElevation, "Upward drag must increase elevation")
        XCTAssertEqual(number(zoom), initialZoom, accuracy: 0.5)
        XCTAssertEqual(stepCount.value as? String, "Step 0")
        XCTAssertTrue(app.buttons["Run"].exists)
        XCTAssertTrue((-180.0...180.0).contains(number(orbit)))
        XCTAssertTrue((-75.0...75.0).contains(number(elevation)))

        // The separate panel owns its scroll and title-bar drag exclusively.
        let panelScroll = panel.scrollViews.firstMatch
        XCTAssertTrue(panelScroll.waitForExistence(timeout: 5))
        let panelOrbit = number(orbit)
        let panelElevation = number(elevation)
        let panelZoom = number(zoom)
        panelScroll.swipeUp()
        XCTAssertEqual(number(orbit), panelOrbit, accuracy: 0.5)
        XCTAssertEqual(number(elevation), panelElevation, accuracy: 0.5)
        XCTAssertEqual(number(zoom), panelZoom, accuracy: 0.5)
        let oldPanelOrigin = panel.frame.origin
        let titleBar = panel.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.03))
        titleBar.click(forDuration: 0.2, thenDragTo: titleBar.withOffset(CGVector(dx: 40, dy: -20)))
        XCTAssertNotEqual(panel.frame.origin, oldPanelOrigin)
        XCTAssertEqual(number(orbit), panelOrbit, accuracy: 0.5)
        XCTAssertEqual(number(elevation), panelElevation, accuracy: 0.5)
        XCTAssertEqual(number(zoom), panelZoom, accuracy: 0.5)

        // Canvas scroll zooms within both native bounds and does not advance.
        panel.buttons[XCUIIdentifierCloseWindow].click()
        XCTAssertFalse(panel.exists)
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .scroll(byDeltaX: 0, deltaY: 600)
        app.typeKey("k", modifierFlags: [.command, .option])
        XCTAssertTrue(panel.waitForExistence(timeout: 5))
        let afterPositiveScroll = number(zoom)
        XCTAssertTrue([50.0, 150.0].contains(afterPositiveScroll),
                      "A vertical scroll must reach a zoom bound")
        XCTAssertEqual(stepCount.value as? String, "Step 0")

        panel.buttons["inspection3d.resetCamera"].click()
        XCTAssertEqual(number(zoom), 100, accuracy: 0.5)
        panel.buttons[XCUIIdentifierCloseWindow].click()
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .scroll(byDeltaX: 600, deltaY: 0)
        app.typeKey("k", modifierFlags: [.command, .option])
        XCTAssertTrue(panel.waitForExistence(timeout: 5))
        XCTAssertEqual(number(zoom), 100, accuracy: 0.5,
                       "Horizontal scrolling must not change camera zoom")

        panel.buttons[XCUIIdentifierCloseWindow].click()
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .scroll(byDeltaX: 0, deltaY: -600)
        app.typeKey("k", modifierFlags: [.command, .option])
        XCTAssertTrue(panel.waitForExistence(timeout: 5))
        XCTAssertEqual(number(zoom), afterPositiveScroll == 50 ? 150 : 50, accuracy: 0.5,
                       "Opposite vertical scrolling must reach the opposite zoom bound")
        XCTAssertEqual(stepCount.value as? String, "Step 0")

        let guide = app.descendants(matching: .any)["orientationGuide3d"]
        XCTAssertTrue(guide.waitForExistence(timeout: 5))
        XCTAssertEqual(guide.label, "3D orientation guide: X, Y and Z axes")
        let beforeGuideDrag = number(orbit)
        panel.buttons[XCUIIdentifierCloseWindow].click()
        let guideStart = guide.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        guideStart.click(forDuration: 0.2,
                        thenDragTo: guideStart.withOffset(CGVector(dx: 40, dy: -20)))
        app.typeKey("k", modifierFlags: [.command, .option])
        XCTAssertTrue(panel.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(number(orbit), beforeGuideDrag,
                             "The hit-transparent guide must pass its drag to the canvas")
        XCTAssertEqual(stepCount.value as? String, "Step 0")

        // Focus the canvas: S stays inert in 3D, and Space toggles transport once.
        let beforeDeactivationOrbit = number(orbit)
        let beforeDeactivationElevation = number(elevation)
        let beforeDeactivationZoom = number(zoom)
        panel.buttons[XCUIIdentifierCloseWindow].click()
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.55, dy: 0.55)).click()
        canvas.typeKey("s", modifierFlags: [])
        app.typeKey("k", modifierFlags: [.command, .option])
        XCTAssertTrue(panel.waitForExistence(timeout: 5))
        XCTAssertEqual(stepCount.value as? String, "Step 0")
        XCTAssertTrue(app.buttons["Run"].exists)
        panel.buttons[XCUIIdentifierCloseWindow].click()
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.55, dy: 0.55)).click()
        canvas.typeKey(XCUIKeyboardKey.space, modifierFlags: [])
        app.typeKey("k", modifierFlags: [.command, .option])
        XCTAssertTrue(panel.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["transport.pause"].label.contains("Pause"),
                      "Canvas Space must toggle the paused 3D lesson exactly once")

        // Losing and regaining app activation must leave the committed camera
        // intact; choosing a 2D lesson then removes the guide and inspection UI.
        let finder = XCUIApplication(bundleIdentifier: "com.apple.finder")
        finder.activate()
        app.activate()
        if !panel.exists {
            app.typeKey("k", modifierFlags: [.command, .option])
        }
        XCTAssertTrue(panel.waitForExistence(timeout: 5))
        XCTAssertEqual(number(orbit), beforeDeactivationOrbit, accuracy: 0.5)
        XCTAssertEqual(number(elevation), beforeDeactivationElevation, accuracy: 0.5)
        XCTAssertEqual(number(zoom), beforeDeactivationZoom, accuracy: 0.5)

        selector.click()
        selector.menuItems["Dye carried by a flow"].click()
        XCTAssertFalse(guide.exists, "The orientation guide must be absent in 2D")
        XCTAssertFalse(app.sliders["inspection3d.zoom"].exists)
        XCTAssertTrue(app.checkBoxes["Dye concentration"].exists)
    }

    func testThreeDInitializationFailureRestoresTwoD() throws {
        app.terminate()
        app = XCUIApplication()
        app.launchArguments = ["--fluid3d-test-failure=allocation"]
        app.launch()

        let selector = app.popUpButtons["experimentSelector"]
        XCTAssertTrue(selector.waitForExistence(timeout: 10))
        selector.click()
        selector.menuItems["3D Dye Advection"].click()

        let alert = app.dialogs.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 10), app.debugDescription)
        XCTAssertEqual(selector.value as? String, "Free Play")
        XCTAssertTrue(app.buttons["transport.pause"].label.contains("Pause"))
        XCTAssertTrue(app.windows["FluidDynamicsMetalOSX"].exists)
        alert.buttons["Continue in 2D"].click()

        let canvas = app.windows["FluidDynamicsMetalOSX"]
        let start = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.4))
        let end = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.65, dy: 0.6))
        start.click(forDuration: 0.3, thenDragTo: end)
        XCTAssertTrue(app.buttons["transport.pause"].label.contains("Pause"))

        selector.click()
        selector.menuItems["3D Dye Advection"].click()
        XCTAssertEqual(selector.value as? String, "3D Dye Advection")
        XCTAssertEqual(app.staticTexts["stepCount"].value as? String, "Step 0")
    }

    func testLessonCompletion() {
        XCTAssertTrue(app.popUpButtons["experimentSelector"].waitForExistence(timeout: 10))
        command("2"); command("p")
        let complete = app.staticTexts["stepCount"]
        let predicate = NSPredicate(format: "value == %@", "Experiment complete. Restart to compare.")
        expectation(for: predicate, evaluatedWith: complete)
        waitForExpectations(timeout: 30)
        XCTAssertFalse(app.buttons["transport.step"].isEnabled); XCTAssertFalse(app.buttons["transport.pause"].isEnabled)
        command("r")
        XCTAssertTrue(app.buttons["transport.step"].isEnabled)
    }

    private func command(_ key: String) {
        app.activate()
        app.typeKey(key, modifierFlags: .command)
    }

    private func assertSelectorValue(_ expected: String, in selector: XCUIElement,
                                     file: StaticString = #filePath, line: UInt = #line) {
        let predicate = NSPredicate(format: "value == %@", expected)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: selector)
        let result = XCTWaiter.wait(for: [expectation], timeout: 5)
        XCTAssertEqual(result, .completed,
                       "Expected selector value \(expected), got \(String(describing: selector.value))",
                       file: file, line: line)
    }

    private func assertSelected(_ expected: String, among fields: [String], file: StaticString = #filePath, line: UInt = #line) {
        for name in fields {
            XCTAssertEqual(app.checkBoxes[name].value as? String, name == expected ? "Selected" : "Not selected", file: file, line: line)
        }
    }
}
