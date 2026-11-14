//
//  RenderViewController.swift
//  FluidDynamicsMetalOSX
//
//  Created by Andrei-Sergiu Pițiș on 16/12/2017.
//  Copyright © 2017 Andrei-Sergiu Pițiș. All rights reserved.
//

import AppKit
import MetalKit

class RenderViewController: NSViewController, NSWindowDelegate, NSMenuItemValidation {
    private enum InspectionSliderKind: Int {
        case depth
        case orbit
        case elevation
        case zoom
    }

    private static let selectableModes: [(identity: String, mode: SimulationMode)] = [
        ("freePlay", .freePlay),
        ("advection", .experiment(.advection)),
        ("interactingVortices", .experiment(.interactingVortices)),
        ("dyeStretching", .experiment(.dyeStretching)),
        ("dyeAdvection3D", .dyeAdvection3D),
    ]

    var renderer: Renderer!
    private let experimentSelector = NSPopUpButton()
    private let stepButton = NSButton(title: "Step", target: nil, action: nil)
    private let restartButton = NSButton(title: "Reset fluid", target: nil, action: nil)
    private let stepLabel = NSTextField(wrappingLabelWithString: "Step 0")
    private let lessonGroup = NSStackView()
    private let question = NSTextField(wrappingLabelWithString: "")
    private let notice = NSTextField(wrappingLabelWithString: "")
    private let adjustmentLabel = NSTextField(labelWithString: "")
    private let adjustmentSelector = NSPopUpButton()
    private let colourLegend = ColourLegendView()
    private let threeDColourLegend = ColourLegendView()
    private let legend = NSTextField(wrappingLabelWithString: "")
    private let explanation = NSTextField(wrappingLabelWithString: "")
    private let twoDBodyStack = NSStackView()
    private let threeDBodyStack = NSStackView()
    private let threeDIntroStack = NSStackView()
    private let threeDLegendStack = NSStackView()
    private let threeDHeading = NSTextField(wrappingLabelWithString: "3D Dye Advection")
    private let threeDSlice = NSTextField(wrappingLabelWithString: "XY slice · Z depth: 50%")
    private let threeDConcentration = NSTextField(labelWithString: "Dye concentration")
    private let threeDLegend = NSTextField(wrappingLabelWithString: "Less dye → More dye")
    private let threeDNote = NSTextField(wrappingLabelWithString: "This slice shows dye carried by an evolving 3D flow. Brighter areas contain more dye; dye can move out of the plane. There is no explicit dye fading, but numerical advection can smooth the dye. Steps count solver advances, not seconds.")
    private let inspectionSliceStack = NSStackView()
    private let inspectionCameraStack = NSStackView()
    private let inspectionPlaneControl = NSSegmentedControl(
        labels: ["XY", "XZ", "YZ"], trackingMode: .selectOne, target: nil, action: nil
    )
    private let inspectionDepthSlider = InspectionSlider3D(frame: .zero)
    private let inspectionDepthValue = NSTextField(labelWithString: "Z depth: 50%")
    private let inspectionCentreSliceButton = NSButton(title: "Centre Slice", target: nil, action: nil)
    private let inspectionOrbitSlider = InspectionSlider3D(frame: .zero)
    private let inspectionOrbitValue = NSTextField(labelWithString: "+25°")
    private let inspectionElevationSlider = InspectionSlider3D(frame: .zero)
    private let inspectionElevationValue = NSTextField(labelWithString: "+18°")
    private let inspectionZoomSlider = InspectionSlider3D(frame: .zero)
    private let inspectionZoomValue = NSTextField(labelWithString: "100%")
    private let inspectionResetCameraButton = NSButton(title: "Reset Camera", target: nil, action: nil)
    private let aboutButton = NSButton(title: "About this simulation", target: nil, action: nil)
    private let aboutText = NSTextField(wrappingLabelWithString: LearningCopy.about)
    private var overlayButtons: [NSButton] = []
    private let bodyStack = NSStackView()
    private let pinnedStack = NSStackView()
    private var displayedLesson: ExperimentID?
    private var mouseHeld = false
    private var rebaseDrag = false
    private var lastCanvasSize: CGSize = .zero
    private let hud = NSVisualEffectView()
    private let opaqueSurface = NSView()
    private let fieldGroup = NSStackView()
    private let controlsScroll = NSScrollView()
    private let pauseButton = NSButton(title: "Pause", target: nil, action: nil)
    private let tuningButton = NSButton(title: "Show Tuning", target: nil, action: nil)
    private let transportStack = NSStackView()
    private let primaryTransportRow = NSStackView()
    private let restartTransportRow = NSStackView()
    private let tuningGroup = NSStackView()
    private var tuningSliders: [TuningControl: NSSlider] = [:]
    private var tuningValues: [TuningControl: NSTextField] = [:]
    private var isTuningExpanded = false
    private var fieldButtons: [DisplayField: NSButton] = [:]
    private var controlsPanel: NSPanel?
    private weak var simulationMenu: NSMenu?
    private var panelConfigured = false
    private var restorePanelAfterMinimize = false
    private var modeTransitionInProgress = false
    private var modeTransitionSource: SimulationMode?
    private var isPresentingModeFailure = false
    private var hudWidth: NSLayoutConstraint?
    private var hudHeight: NSLayoutConstraint?
#if DEBUG
    private var testVisibleWidthOverride: CGFloat? {
        let prefix = "--fluid3d-test-visible-width="
        guard let argument = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix(prefix) }),
              let width = argument.split(separator: "=", maxSplits: 1).last.flatMap({ Double($0) }),
              width >= 256 else { return nil }
        return CGFloat(width)
    }
#endif
    var metalView: MTKView {
        return view as! MTKView
    }

    var eventMonitor: Any?

    override func viewDidLoad() {
        super.viewDidLoad()

        renderer = Renderer(metalView: metalView, threeDFactory: makeThreeDSessionFactory())
        metalView.delegate = renderer

        installControls()
        renderer.stateDidChange = { [weak self] in
            self?.refreshTransport()
            self?.refreshInspectionControls()
        }
        renderer.modeOutcomeDidChange = { [weak self] outcome in
            guard let self else { return }
            let sourceMode = self.modeTransitionSource
            self.modeTransitionSource = nil
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.refreshControls()
                if let error = outcome.errorMessage, outcome.requestedMode.is3D {
                    self.presentThreeDModeFailure(error: error, sourceMode: sourceMode,
                                                   committedMode: outcome.committedMode)
                }
            }
        }
        NotificationCenter.default.addObserver(self, selector: #selector(resignActive), name: NSApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(becomeActive), name: NSApplication.didBecomeActiveNotification, object: nil)

        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] in
            guard let self else { return $0 }
            guard $0.window == self.view.window || $0.window == self.controlsPanel else { return $0 }
            guard $0.modifierFlags.intersection([.command, .control, .option]).isEmpty else { return $0 }
            // AppKit may forward a focused button's Space through keyDown to the
            // controller. Activate it here so that forwarding cannot also pause.
            if $0.keyCode == 0x31, let button = $0.window?.firstResponder as? NSButton {
                button.performClick(nil); return nil
            }
            if $0.keyCode == 0x30 {
                DispatchQueue.main.async { [weak self] in self?.revealFocusedInspectionControl() }
                return $0
            }
            if $0.window?.firstResponder is NSControl || $0.window?.firstResponder is NSTextView { return $0 }
            if $0.keyCode == 0x31 || $0.keyCode == 0x01 {
                self.keyDown(with: $0)
                return nil
            }
            return $0
        }
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        view.window?.contentMinSize = NSSize(width: 320, height: 240)
        if let window = view.window {
            NotificationCenter.default.addObserver(self, selector: #selector(canvasBecameMain),
                                                   name: NSWindow.didBecomeMainNotification, object: window)
            if window.isMainWindow { showControlsPanel() }
        }
    }

    @objc private func canvasBecameMain() {
        if !panelConfigured { showControlsPanel() }
    }

    private func showControlsPanel() {
        guard let panel = controlsPanel, let window = view.window else { return }
        if !panelConfigured {
            panelConfigured = true
            updateControlLayout()
            let restored = panel.setFrameUsingName("SimulationControls")
            if !restored {
                panel.setFrameTopLeftPoint(NSPoint(x: window.frame.maxX - panel.frame.width - 16,
                                                  y: window.frame.maxY - 48))
            }
            panel.setFrameAutosaveName("SimulationControls")
            NotificationCenter.default.addObserver(self, selector: #selector(canvasWillClose), name: NSWindow.willCloseNotification, object: window)
            NotificationCenter.default.addObserver(self, selector: #selector(canvasWillMinimize), name: NSWindow.willMiniaturizeNotification, object: window)
            NotificationCenter.default.addObserver(self, selector: #selector(canvasDidRestore), name: NSWindow.didDeminiaturizeNotification, object: window)
            installControlsMenu()
        }
        if let screen = window.screen ?? NSScreen.main {
            let visible = screen.visibleFrame
            let frame = panel.frame
            panel.setFrameOrigin(NSPoint(x: min(max(frame.minX, visible.minX), visible.maxX - frame.width),
                                         y: min(max(frame.minY, visible.minY), visible.maxY - frame.height)))
        }
        panel.orderFront(nil)
    }

    @objc private func canvasWillClose() {
        controlsPanel?.delegate = nil
        controlsPanel?.close()
    }

    @objc private func canvasWillMinimize() {
        renderer.resignActive()
        restorePanelAfterMinimize = controlsPanel?.isVisible == true
        controlsPanel?.orderOut(nil)
    }

    @objc private func canvasDidRestore() {
        if NSApp.isActive { renderer.becomeActive() }
        if restorePanelAfterMinimize { showControlsPanel() }
    }

    @objc private func resignActive() { mouseHeld = false; rebaseDrag = false; renderer.resignActive() }
    @objc private func becomeActive() { if view.window?.isMiniaturized != true { renderer.becomeActive() } }

    private func installControlsMenu() {
        guard let mainMenu = NSApp.mainMenu else { return }
        let viewItem: NSMenuItem
        if let existing = mainMenu.items.first(where: { $0.title == "View" }) {
            viewItem = existing
        } else {
            viewItem = NSMenuItem(title: "View", action: nil, keyEquivalent: "")
            viewItem.submenu = NSMenu(title: "View")
            let index = mainMenu.items.firstIndex(where: { $0.title == "Window" }) ?? mainMenu.items.count
            mainMenu.insertItem(viewItem, at: index)
        }
        let item = NSMenuItem(title: "Hide Simulation Controls", action: #selector(toggleControlsPanel(_:)), keyEquivalent: "k")
        item.keyEquivalentModifierMask = [.command, .option]
        item.target = self
        viewItem.submenu?.addItem(item)
        // Storyboard text-editing menus ship Cmd-P (Print) and Cmd-R (Align Right).
        // Reserve the documented simulation equivalents before installing our commands.
        func clearConflicts(_ menu: NSMenu) {
            for item in menu.items {
                if item.keyEquivalentModifierMask == .command,
                   ["p", "r", "1", "2", "3", "4", String(UnicodeScalar(NSRightArrowFunctionKey)!)].contains(item.keyEquivalent) {
                    item.keyEquivalent = ""
                }
                if let submenu = item.submenu { clearConflicts(submenu) }
            }
        }
        clearConflicts(mainMenu)
        let simulationMenu = NSMenu(title: "Simulation")
        let root = NSMenuItem(title: "Simulation", action: nil, keyEquivalent: "")
        root.submenu = simulationMenu; mainMenu.insertItem(root, at: min(2, mainMenu.items.count))
        for (title, action, key) in [("Pause", #selector(togglePause(_:)), "p"), ("Step", #selector(singleStep(_:)), String(UnicodeScalar(NSRightArrowFunctionKey)!)), ("Reset fluid", #selector(restart(_:)), "r")] {
            let command = NSMenuItem(title: title, action: action, keyEquivalent: key)
            command.target = self; command.keyEquivalentModifierMask = .command; simulationMenu.addItem(command)
        }
        simulationMenu.addItem(.separator())
        appendModeGroup("2D", modes: SimulationMode.twoDimensionalModes, to: simulationMenu,
                        menuActions: true)
        simulationMenu.addItem(.separator())
        appendModeGroup("3D", modes: [.dyeAdvection3D], to: simulationMenu, menuActions: true)
        self.simulationMenu = simulationMenu
        refreshModeSelection()

    }

    private func makeThreeDSessionFactory() -> Renderer3DSessionFactory {
#if DEBUG
        let argumentPrefix = "--fluid3d-test-failure="
        if let argument = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix(argumentPrefix) }),
           let stage = argument.split(separator: "=", maxSplits: 1).last.map(String.init),
           ["allocation", "pipeline", "reset"].contains(stage) {
            var pendingFailure: String? = stage
            func inject(_ requestedStage: String) throws {
                guard pendingFailure == requestedStage else { return }
                pendingFailure = nil
                throw NSError(domain: "FluidDynamicsMetalUITestFailure", code: 1,
                              userInfo: [NSLocalizedDescriptionKey: "Injected 3D preparation failure"])
            }
            return Renderer3DSessionFactory(
                makeSimulation: { metal in
                    try inject("allocation")
                    return try FluidSimulation3D(metal: metal)
                },
                makeVisualization: { metal in
                    try inject("pipeline")
                    return try FieldVisualization3D(metal: metal)
                },
                encodeReset: { simulation, command in
                    try inject("reset")
                    return try simulation.encodeReset(command: command)
                }
            )
        }
#endif
        return Renderer3DSessionFactory()
    }

    private static func identity(for mode: SimulationMode) -> String? {
        selectableModes.first(where: { $0.mode == mode })?.identity
    }

    private static func mode(for item: NSMenuItem?) -> SimulationMode? {
        guard let identity = item?.representedObject as? String else { return nil }
        return selectableModes.first(where: { $0.identity == identity })?.mode
    }

    private static func shortcut(for mode: SimulationMode) -> String {
        switch mode {
        case .freePlay: return "1"
        case .experiment(.advection): return "2"
        case .experiment(.interactingVortices): return "3"
        case .experiment(.dyeStretching): return "4"
        case .dyeAdvection3D: return ""
        }
    }

    private func appendModeGroup(_ title: String, modes: [SimulationMode], to menu: NSMenu,
                                menuActions: Bool) {
        let heading = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        heading.representedObject = "mode-group.\(title)"
        heading.isEnabled = false
        menu.addItem(heading)
        for mode in modes {
            let shortcut = menuActions ? Self.shortcut(for: mode) : ""
            let item = NSMenuItem(title: mode.title,
                                  action: menuActions ? #selector(selectExperimentMenu(_:)) : nil,
                                  keyEquivalent: shortcut)
            item.representedObject = Self.identity(for: mode)
            if menuActions {
                item.target = self
                if !shortcut.isEmpty { item.keyEquivalentModifierMask = [.command] }
            }
            menu.addItem(item)
        }
    }

    @objc private func toggleControlsPanel(_ sender: Any?) {
        if controlsPanel?.isVisible == true {
            controlsPanel?.orderOut(nil)
        } else {
            showControlsPanel()
        }
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if (menuItem.representedObject as? String)?.hasPrefix("mode-group.") == true { return false }
        if menuItem.action == #selector(toggleControlsPanel(_:)) {
            menuItem.title = controlsPanel?.isVisible == true ? "Hide Simulation Controls" : "Show Simulation Controls"
        }
        if menuItem.action == #selector(singleStep(_:)) { return !modeTransitionInProgress && renderer.state.canStep }
        if menuItem.action == #selector(togglePause(_:)) {
            menuItem.title = pauseButton.title
            return !modeTransitionInProgress && !renderer.state.complete
        }
        if menuItem.action == #selector(restart(_:)) { menuItem.title = restartButton.title }
        if menuItem.action == #selector(selectExperimentMenu(_:)) {
            guard let mode = Self.mode(for: menuItem) else { return false }
            menuItem.state = renderer.state.mode == mode ? .on : .off
            return !modeTransitionInProgress && view.window?.isVisible == true
        }
        return view.window?.isVisible == true
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        return false
    }

    private func installControls() {
        hud.material = .hudWindow
        hud.blendingMode = .behindWindow
        hud.state = .active
        hud.wantsLayer = true
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 248, height: 196),
                            styleMask: [.titled, .closable, .utilityWindow],
                            backing: .buffered, defer: false)
        panel.title = "Simulation Controls"
        panel.identifier = NSUserInterfaceItemIdentifier("simulationControls")
        panel.isFloatingPanel = true
        panel.isMovable = true
        panel.hidesOnDeactivate = true
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.fullScreenAuxiliary]
        panel.delegate = self
        hud.translatesAutoresizingMaskIntoConstraints = false
        hudWidth = hud.widthAnchor.constraint(equalToConstant: 248)
        hudHeight = hud.heightAnchor.constraint(equalToConstant: 196)
        NSLayoutConstraint.activate([hudWidth!, hudHeight!])
        panel.contentView = hud
        controlsPanel = panel

        opaqueSurface.translatesAutoresizingMaskIntoConstraints = false
        opaqueSurface.wantsLayer = true
        hud.addSubview(opaqueSurface)
        NSLayoutConstraint.activate([
            opaqueSurface.leadingAnchor.constraint(equalTo: hud.leadingAnchor),
            opaqueSurface.trailingAnchor.constraint(equalTo: hud.trailingAnchor),
            opaqueSurface.topAnchor.constraint(equalTo: hud.topAnchor),
            opaqueSurface.bottomAnchor.constraint(equalTo: hud.bottomAnchor)
        ])

        func vertical(_ stack: NSStackView) {
            stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 8
        }
        func button(_ button: NSButton, _ action: Selector, _ id: String) {
            button.target = self; button.action = action; button.bezelStyle = .rounded
            button.setAccessibilityIdentifier(id)
            button.heightAnchor.constraint(greaterThanOrEqualToConstant: 28).isActive = true
        }
        let experimentMenu = NSMenu(title: "Experiments")
        appendModeGroup("2D", modes: SimulationMode.twoDimensionalModes, to: experimentMenu,
                        menuActions: false)
        experimentMenu.addItem(.separator())
        appendModeGroup("3D", modes: [.dyeAdvection3D], to: experimentMenu, menuActions: false)
        experimentSelector.menu = experimentMenu
        experimentSelector.target = self; experimentSelector.action = #selector(selectExperiment(_:))
        experimentSelector.setAccessibilityLabel("Experiments"); experimentSelector.setAccessibilityIdentifier("experimentSelector")
        button(pauseButton, #selector(togglePause(_:)), "transport.pause")
        button(stepButton, #selector(singleStep(_:)), "transport.step")
        button(restartButton, #selector(restart(_:)), "transport.restart")
        primaryTransportRow.orientation = .horizontal
        primaryTransportRow.alignment = .centerY
        primaryTransportRow.spacing = 4
        primaryTransportRow.addArrangedSubview(pauseButton)
        primaryTransportRow.addArrangedSubview(stepButton)
        restartTransportRow.orientation = .horizontal
        restartTransportRow.alignment = .centerY
        restartTransportRow.addArrangedSubview(restartButton)
        transportStack.orientation = .horizontal
        transportStack.alignment = .centerY
        transportStack.spacing = 4
        transportStack.addArrangedSubview(primaryTransportRow)
        transportStack.addArrangedSubview(restartTransportRow)
        stepLabel.setAccessibilityIdentifier("stepCount")
        vertical(pinnedStack)
        for view in [experimentSelector, transportStack, stepLabel] { pinnedStack.addArrangedSubview(view) }
        vertical(bodyStack); vertical(twoDBodyStack); vertical(threeDBodyStack)
        vertical(threeDIntroStack); vertical(threeDLegendStack)
        vertical(fieldGroup); vertical(lessonGroup); vertical(tuningGroup)
        threeDBodyStack.spacing = 16
        threeDIntroStack.spacing = 8
        threeDLegendStack.spacing = 4
        threeDHeading.font = .systemFont(ofSize: 17, weight: .semibold)
        threeDHeading.setAccessibilityIdentifier("lesson3d.heading")
        threeDHeading.setAccessibilityLabel("3D Dye Advection")
        threeDSlice.font = .systemFont(ofSize: 11, weight: .regular)
        threeDSlice.setAccessibilityIdentifier("lesson3d.slice")
        threeDSlice.setAccessibilityLabel("XY slice, Z depth 50 percent")
        threeDConcentration.font = .systemFont(ofSize: 11, weight: .semibold)
        threeDConcentration.setAccessibilityIdentifier("lesson3d.concentration")
        threeDConcentration.setAccessibilityLabel("Dye concentration")
        threeDLegend.font = .systemFont(ofSize: 11, weight: .regular)
        threeDLegend.setAccessibilityIdentifier("lesson3d.legend")
        threeDLegend.setAccessibilityLabel("Dye concentration, less dye to more dye")
        threeDNote.font = .systemFont(ofSize: 13, weight: .regular)
        threeDNote.setAccessibilityIdentifier("lesson3d.note")
        threeDNote.setAccessibilityLabel(threeDNote.stringValue)
        threeDNote.usesSingleLineMode = false
        threeDNote.maximumNumberOfLines = 0
        threeDNote.lineBreakMode = .byWordWrapping
        let noteParagraph = NSMutableParagraphStyle()
        noteParagraph.lineHeightMultiple = 1.5
        threeDNote.attributedStringValue = NSAttributedString(
            string: threeDNote.stringValue,
            attributes: [
                .font: threeDNote.font!,
                .paragraphStyle: noteParagraph,
                .foregroundColor: NSColor.labelColor,
            ]
        )
        threeDIntroStack.addArrangedSubview(threeDHeading)
        threeDIntroStack.addArrangedSubview(threeDSlice)
        threeDLegendStack.addArrangedSubview(threeDConcentration)
        threeDLegendStack.addArrangedSubview(threeDColourLegend)
        threeDLegendStack.addArrangedSubview(threeDLegend)
        configureInspectionControls()
        threeDBodyStack.addArrangedSubview(threeDIntroStack)
        threeDBodyStack.addArrangedSubview(threeDLegendStack)
        threeDBodyStack.addArrangedSubview(inspectionSliceStack)
        threeDBodyStack.addArrangedSubview(inspectionCameraStack)
        threeDBodyStack.addArrangedSubview(threeDNote)
        colourLegend.setAccessibilityElement(false)
        threeDColourLegend.setAccessibilityElement(false)
        question.font = .systemFont(ofSize: NSFont.systemFontSize, weight: .semibold)
        question.setAccessibilityIdentifier("lesson.question")
        let noticeHeading = NSTextField(labelWithString: "What to notice")
        noticeHeading.font = .systemFont(ofSize: NSFont.smallSystemFontSize, weight: .semibold)
        adjustmentSelector.target = self; adjustmentSelector.action = #selector(changeAdjustment(_:))
        adjustmentSelector.setAccessibilityIdentifier("experimentAdjustment")
        for view in [question, noticeHeading, notice, adjustmentLabel, adjustmentSelector, NSTextField(wrappingLabelWithString: LearningCopy.adjustment)] { lessonGroup.addArrangedSubview(view) }
        twoDBodyStack.addArrangedSubview(lessonGroup)
        twoDBodyStack.addArrangedSubview(NSTextField(labelWithString: "View"))
        for field in DisplayField.allCases {
            let item = NSButton(title: field.title, target: self, action: #selector(selectField(_:)))
            item.tag = field.rawValue; item.setButtonType(.toggle); item.bezelStyle = .rounded
            item.setAccessibilityIdentifier("field.\(field.rawValue)"); fieldButtons[field] = item
        }
        for fields in [[DisplayField.density, .pressure], [.velocity, .vorticity]] {
            let row = NSStackView(views: fields.compactMap { fieldButtons[$0] }); row.distribution = .fillEqually
            fieldGroup.addArrangedSubview(row); row.widthAnchor.constraint(equalTo: fieldGroup.widthAnchor).isActive = true
        }
        twoDBodyStack.addArrangedSubview(fieldGroup); twoDBodyStack.addArrangedSubview(explanation); twoDBodyStack.addArrangedSubview(colourLegend); twoDBodyStack.addArrangedSubview(legend)
        colourLegend.heightAnchor.constraint(equalToConstant: 12).isActive = true
        threeDColourLegend.heightAnchor.constraint(equalToConstant: 12).isActive = true
        legend.setAccessibilityIdentifier("fieldLegend")
        for (index, title) in ["Velocity arrows", "Particles", "Trails"].enumerated() {
            let item = NSButton(checkboxWithTitle: title, target: self, action: #selector(changeOverlay(_:)))
            item.tag = index; item.setAccessibilityIdentifier("overlay.\(index)"); overlayButtons.append(item); twoDBodyStack.addArrangedSubview(item)
        }
        twoDBodyStack.addArrangedSubview(NSTextField(wrappingLabelWithString: LearningCopy.trails))
        button(tuningButton, #selector(toggleTuning(_:)), "tuning.toggle")
        twoDBodyStack.addArrangedSubview(tuningButton)
        for control in TuningControl.allCases {
            let label = NSTextField(labelWithString: control.title), value = NSTextField(labelWithString: "")
            value.alignment = .right; tuningValues[control] = value
            let heading = NSStackView(views: [label, value]); heading.distribution = .fill
            let slider = NSSlider(value: 0, minValue: 0, maxValue: 1, target: self, action: #selector(changeTuning(_:)))
            slider.isContinuous = true; slider.tag = control.rawValue
            slider.setAccessibilityLabel(control.title); slider.setAccessibilityIdentifier("tuning.\(control.identifier)")
            tuningSliders[control] = slider
            let row = NSStackView(views: [heading, slider]); vertical(row)
            tuningGroup.addArrangedSubview(row); row.widthAnchor.constraint(equalTo: tuningGroup.widthAnchor).isActive = true
            slider.widthAnchor.constraint(equalTo: row.widthAnchor).isActive = true
        }
        tuningGroup.addArrangedSubview(NSTextField(wrappingLabelWithString: LearningCopy.fading))
        tuningGroup.isHidden = true; twoDBodyStack.addArrangedSubview(tuningGroup)
        button(aboutButton, #selector(toggleAbout(_:)), "about.toggle")
        aboutText.isHidden = true; twoDBodyStack.addArrangedSubview(aboutButton); twoDBodyStack.addArrangedSubview(aboutText)
        bodyStack.addArrangedSubview(twoDBodyStack)
        bodyStack.addArrangedSubview(threeDBodyStack)
        for stack in [pinnedStack, bodyStack, twoDBodyStack, threeDBodyStack,
                      threeDIntroStack, threeDLegendStack, inspectionSliceStack, inspectionCameraStack] {
            stack.translatesAutoresizingMaskIntoConstraints = false
            for child in stack.arrangedSubviews { child.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true }
        }
        for child in lessonGroup.arrangedSubviews { child.widthAnchor.constraint(equalTo: lessonGroup.widthAnchor).isActive = true }
        controlsScroll.drawsBackground = false; controlsScroll.hasVerticalScroller = true; controlsScroll.autohidesScrollers = true
        controlsScroll.translatesAutoresizingMaskIntoConstraints = false; controlsScroll.documentView = bodyStack
        hud.addSubview(pinnedStack); hud.addSubview(controlsScroll)
        NSLayoutConstraint.activate([
            pinnedStack.leadingAnchor.constraint(equalTo: hud.leadingAnchor, constant: 16),
            pinnedStack.trailingAnchor.constraint(equalTo: hud.trailingAnchor, constant: -16),
            pinnedStack.topAnchor.constraint(equalTo: hud.topAnchor, constant: 12),
            controlsScroll.leadingAnchor.constraint(equalTo: hud.leadingAnchor, constant: 16),
            controlsScroll.trailingAnchor.constraint(equalTo: hud.trailingAnchor, constant: -16),
            controlsScroll.topAnchor.constraint(equalTo: pinnedStack.bottomAnchor, constant: 12),
            controlsScroll.bottomAnchor.constraint(equalTo: hud.bottomAnchor, constant: -12),
            bodyStack.widthAnchor.constraint(equalTo: controlsScroll.contentView.widthAnchor)
        ])
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(updateAppearance), name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil)
        updateAppearance()
        refreshControls()
    }

    private func fieldTitle(_ field: DisplayField) -> String { field.title }

    private func configureInspectionControls() {
        inspectionSliceStack.orientation = .vertical
        inspectionSliceStack.alignment = .leading
        inspectionSliceStack.spacing = 8
        inspectionCameraStack.orientation = .vertical
        inspectionCameraStack.alignment = .leading
        inspectionCameraStack.spacing = 8

        let sliceHeading = NSTextField(labelWithString: "Slice")
        sliceHeading.font = .systemFont(ofSize: 13, weight: .semibold)
        let cameraHeading = NSTextField(labelWithString: "Camera")
        cameraHeading.font = .systemFont(ofSize: 13, weight: .semibold)

        let planeLabel = NSTextField(labelWithString: "Plane")
        planeLabel.setAccessibilityLabel("Plane")
        planeLabel.setContentHuggingPriority(.required, for: .horizontal)
        inspectionPlaneControl.setAccessibilityLabel("Plane")
        inspectionPlaneControl.setAccessibilityIdentifier("inspection3d.plane")
        inspectionPlaneControl.target = self
        inspectionPlaneControl.action = #selector(changeInspectionPlane(_:))
        for plane in InspectionPlane3D.allCases {
            inspectionPlaneControl.setSelected(plane == .xy, forSegment: plane.rawValue)
        }
        inspectionPlaneControl.widthAnchor.constraint(greaterThanOrEqualToConstant: 150).isActive = true
        inspectionPlaneControl.setAccessibilityValue("XY")
        let planeRow = NSStackView(views: [planeLabel, inspectionPlaneControl])
        planeRow.orientation = .horizontal
        planeRow.alignment = .centerY
        planeRow.distribution = .fill
        planeRow.spacing = 8

        let depthLabel = NSTextField(labelWithString: "Depth")
        inspectionDepthSlider.minValue = 0
        inspectionDepthSlider.maxValue = 100
        inspectionDepthSlider.doubleValue = 50
        inspectionDepthSlider.keyboardIncrement = 1
        inspectionDepthSlider.isContinuous = true
        inspectionDepthSlider.tag = InspectionSliderKind.depth.rawValue
        inspectionDepthSlider.target = self
        inspectionDepthSlider.action = #selector(changeInspectionSlider(_:))
        inspectionDepthSlider.setAccessibilityLabel("Z depth")
        inspectionDepthSlider.setAccessibilityIdentifier("inspection3d.depth")
        inspectionDepthSlider.setAccessibilityHelp("Move the XY slice along Z. Centre Slice returns the depth to 50%.")
        inspectionDepthSlider.setAccessibilityValue("50%")
        inspectionDepthValue.alignment = .right
        inspectionDepthValue.setAccessibilityIdentifier("inspection3d.depthValue")
        inspectionDepthValue.setAccessibilityLabel("Z depth: 50%")
        let depthRow = inspectionSliderRow(label: depthLabel, value: inspectionDepthValue,
                                           slider: inspectionDepthSlider)

        configureInspectionButton(inspectionCentreSliceButton, action: #selector(centreInspectionSlice(_:)),
                                  identifier: "inspection3d.centreSlice")
        inspectionCentreSliceButton.setAccessibilityHelp(
            "Set the current slice depth to 50% without changing its plane or the camera."
        )
        inspectionSliceStack.addArrangedSubview(sliceHeading)
        inspectionSliceStack.addArrangedSubview(planeRow)
        inspectionSliceStack.addArrangedSubview(depthRow)
        inspectionSliceStack.addArrangedSubview(inspectionCentreSliceButton)

        let orbitLabel = NSTextField(labelWithString: "Horizontal Orbit")
        inspectionOrbitSlider.minValue = -180
        inspectionOrbitSlider.maxValue = 180
        inspectionOrbitSlider.doubleValue = 25
        inspectionOrbitSlider.keyboardIncrement = 5
        inspectionOrbitSlider.isContinuous = true
        inspectionOrbitSlider.tag = InspectionSliderKind.orbit.rawValue
        inspectionOrbitSlider.target = self
        inspectionOrbitSlider.action = #selector(changeInspectionSlider(_:))
        inspectionOrbitSlider.setAccessibilityLabel("Horizontal Orbit")
        inspectionOrbitSlider.setAccessibilityIdentifier("inspection3d.orbit")
        inspectionOrbitValue.alignment = .right
        inspectionOrbitValue.setAccessibilityIdentifier("inspection3d.orbitValue")
        let orbitRow = inspectionSliderRow(label: orbitLabel, value: inspectionOrbitValue,
                                           slider: inspectionOrbitSlider)

        let elevationLabel = NSTextField(labelWithString: "Elevation")
        inspectionElevationSlider.minValue = -75
        inspectionElevationSlider.maxValue = 75
        inspectionElevationSlider.doubleValue = 18
        inspectionElevationSlider.keyboardIncrement = 3
        inspectionElevationSlider.isContinuous = true
        inspectionElevationSlider.tag = InspectionSliderKind.elevation.rawValue
        inspectionElevationSlider.target = self
        inspectionElevationSlider.action = #selector(changeInspectionSlider(_:))
        inspectionElevationSlider.setAccessibilityLabel("Elevation")
        inspectionElevationSlider.setAccessibilityIdentifier("inspection3d.elevation")
        inspectionElevationValue.alignment = .right
        inspectionElevationValue.setAccessibilityIdentifier("inspection3d.elevationValue")
        let elevationRow = inspectionSliderRow(label: elevationLabel, value: inspectionElevationValue,
                                               slider: inspectionElevationSlider)

        let zoomLabel = NSTextField(labelWithString: "Zoom")
        inspectionZoomSlider.minValue = 50
        inspectionZoomSlider.maxValue = 150
        inspectionZoomSlider.doubleValue = 100
        inspectionZoomSlider.keyboardIncrement = 5
        inspectionZoomSlider.isContinuous = true
        inspectionZoomSlider.tag = InspectionSliderKind.zoom.rawValue
        inspectionZoomSlider.target = self
        inspectionZoomSlider.action = #selector(changeInspectionSlider(_:))
        inspectionZoomSlider.setAccessibilityLabel("Zoom")
        inspectionZoomSlider.setAccessibilityIdentifier("inspection3d.zoom")
        inspectionZoomValue.alignment = .right
        inspectionZoomValue.setAccessibilityIdentifier("inspection3d.zoomValue")
        let zoomRow = inspectionSliderRow(label: zoomLabel, value: inspectionZoomValue,
                                          slider: inspectionZoomSlider)

        configureInspectionButton(inspectionResetCameraButton, action: #selector(resetInspectionCamera(_:)),
                                  identifier: "inspection3d.resetCamera")
        inspectionResetCameraButton.setAccessibilityHelp(
            "Restore the starting camera view without changing the slice or experiment."
        )
        let gestureHelp = NSTextField(wrappingLabelWithString:
            "Drag the canvas to orbit. Scroll to zoom. You can also use the camera sliders."
        )
        gestureHelp.font = .systemFont(ofSize: 11, weight: .regular)
        gestureHelp.setAccessibilityLabel(gestureHelp.stringValue)

        inspectionCameraStack.addArrangedSubview(cameraHeading)
        inspectionCameraStack.addArrangedSubview(orbitRow)
        inspectionCameraStack.addArrangedSubview(elevationRow)
        inspectionCameraStack.addArrangedSubview(zoomRow)
        inspectionCameraStack.addArrangedSubview(inspectionResetCameraButton)
        inspectionCameraStack.addArrangedSubview(gestureHelp)

        inspectionPlaneControl.nextKeyView = inspectionDepthSlider
        inspectionDepthSlider.nextKeyView = inspectionCentreSliceButton
        inspectionCentreSliceButton.nextKeyView = inspectionOrbitSlider
        inspectionOrbitSlider.nextKeyView = inspectionElevationSlider
        inspectionElevationSlider.nextKeyView = inspectionZoomSlider
        inspectionZoomSlider.nextKeyView = inspectionResetCameraButton
        inspectionResetCameraButton.nextKeyView = experimentSelector
    }

    private func configureInspectionButton(_ button: NSButton, action: Selector, identifier: String) {
        button.target = self
        button.action = action
        button.bezelStyle = .rounded
        button.setAccessibilityLabel(button.title)
        button.setAccessibilityIdentifier(identifier)
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 28).isActive = true
    }

    private func inspectionSliderRow(
        label: NSTextField,
        value: NSTextField,
        slider: InspectionSlider3D
    ) -> NSStackView {
        let heading = NSStackView(views: [label, value])
        heading.orientation = .horizontal
        heading.alignment = .centerY
        heading.distribution = .fill
        heading.spacing = 8
        value.setContentHuggingPriority(.required, for: .horizontal)

        let row = NSStackView(views: [heading, slider])
        row.orientation = .vertical
        row.alignment = .leading
        row.spacing = 4
        heading.widthAnchor.constraint(equalTo: row.widthAnchor).isActive = true
        slider.widthAnchor.constraint(equalTo: row.widthAnchor).isActive = true
        return row
    }

    @objc private func changeInspectionPlane(_ sender: NSSegmentedControl) {
        guard renderer.state.mode.is3D,
              let plane = InspectionPlane3D(rawValue: sender.selectedSegment) else { return }
        var inspection = renderer.state.inspection3D
        inspection.plane = plane
        renderer.setInspection3D(inspection)
        refreshInspectionControls()
    }

    @objc private func changeInspectionSlider(_ sender: InspectionSlider3D) {
        guard renderer.state.mode.is3D,
              let kind = InspectionSliderKind(rawValue: sender.tag) else { return }
        var inspection = renderer.state.inspection3D
        switch kind {
        case .depth:
            inspection.setDepth(sender.doubleValue / 100)
        case .orbit:
            inspection.camera.setYawDegrees(sender.doubleValue)
        case .elevation:
            inspection.camera.setElevationDegrees(sender.doubleValue)
        case .zoom:
            inspection.camera.setZoomPercent(sender.doubleValue)
        }
        renderer.setInspection3D(inspection)
        refreshInspectionControls()
    }

    @objc private func centreInspectionSlice(_ sender: Any?) {
        guard renderer.state.mode.is3D else { return }
        renderer.centreSlice3D()
        refreshInspectionControls()
    }

    @objc private func resetInspectionCamera(_ sender: Any?) {
        guard renderer.state.mode.is3D else { return }
        renderer.resetCamera3D()
        refreshInspectionControls()
    }

    private func refreshInspectionControls() {
        guard renderer.state.mode.is3D else { return }
        let inspection = renderer.state.inspection3D
        let planeName: String
        let depthAxis: String
        switch inspection.plane {
        case .xy: planeName = "XY"; depthAxis = "Z"
        case .xz: planeName = "XZ"; depthAxis = "Y"
        case .yz: planeName = "YZ"; depthAxis = "X"
        }
        let percentage = Int((inspection.depth * 100).rounded())
        let descriptor = "\(planeName) slice · \(depthAxis) depth: \(percentage)%"
        threeDSlice.stringValue = descriptor
        threeDSlice.setAccessibilityLabel("\(planeName) slice, \(depthAxis) depth \(percentage) percent")
        inspectionPlaneControl.setSelected(true, forSegment: inspection.plane.rawValue)
        inspectionPlaneControl.setAccessibilityValue(planeName)

        inspectionDepthSlider.doubleValue = inspection.depth * 100
        inspectionDepthSlider.setAccessibilityLabel("\(depthAxis) depth")
        inspectionDepthSlider.setAccessibilityHelp(
            "Move the \(planeName) slice along \(depthAxis). Centre Slice returns the depth to 50%."
        )
        inspectionDepthSlider.setAccessibilityValue("\(percentage)%")
        inspectionDepthValue.stringValue = "\(depthAxis) depth: \(percentage)%"
        inspectionDepthValue.setAccessibilityLabel(inspectionDepthValue.stringValue)

        let yawValue = Self.signedDegrees(inspection.camera.yawDegrees)
        let elevationValue = Self.signedDegrees(inspection.camera.elevationDegrees)
        let zoomValue = "\(Int(inspection.camera.zoomPercent.rounded()))%"
        inspectionOrbitSlider.doubleValue = inspection.camera.yawDegrees
        inspectionOrbitSlider.setAccessibilityValue(yawValue)
        inspectionOrbitValue.stringValue = yawValue
        inspectionElevationSlider.doubleValue = inspection.camera.elevationDegrees
        inspectionElevationSlider.setAccessibilityValue(elevationValue)
        inspectionElevationValue.stringValue = elevationValue
        inspectionZoomSlider.doubleValue = inspection.camera.zoomPercent
        inspectionZoomSlider.setAccessibilityValue(zoomValue)
        inspectionZoomValue.stringValue = zoomValue
    }

    private static func signedDegrees(_ value: Double) -> String {
        let rounded = Int(value.rounded())
        return "\(rounded >= 0 ? "+" : "")\(rounded)°"
    }

    private func revealFocusedInspectionControl() {
        guard let window = controlsPanel,
              let focusedView = window.firstResponder as? NSView,
              focusedView.isDescendant(of: threeDBodyStack) else { return }
        _ = focusedView.scrollToVisible(focusedView.bounds)
    }

    @objc private func updateAppearance() {
        opaqueSurface.isHidden = !NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
        opaqueSurface.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        colourLegend.needsDisplay = true
        threeDColourLegend.needsDisplay = true
    }

    private func updateControlLayout() {
        guard renderer != nil else { return }
        let visibleFrame = controlsPanel?.screen?.visibleFrame ?? NSScreen.main?.visibleFrame
        var availableWidth = visibleFrame?.width ?? 384
#if DEBUG
        if let testVisibleWidthOverride {
            availableWidth = min(availableWidth, testVisibleWidthOverride)
        }
#endif
        let width = min(368, max(240, availableWidth - 16))
        hudWidth?.constant = width
        hud.layoutSubtreeIfNeeded()
        let horizontalTransportWidth = primaryTransportRow.fittingSize.width
            + restartTransportRow.fittingSize.width + transportStack.spacing
        let shouldWrapRestart = width - 32 < horizontalTransportWidth
        transportStack.orientation = shouldWrapRestart ? .vertical : .horizontal
        transportStack.alignment = shouldWrapRestart ? .leading : .centerY
        hud.layoutSubtreeIfNeeded()
        let wanted = pinnedStack.fittingSize.height + bodyStack.fittingSize.height + 36
        let available = max(240, (visibleFrame?.height ?? 800) - 80)
        let height = min(available, max(240, wanted))
        hudHeight?.constant = height

        if let panel = controlsPanel {
            let targetSize = NSSize(width: width, height: height)
            let currentSize = panel.contentView?.bounds.size ?? .zero
            if abs(currentSize.width - targetSize.width) > 0.5 || abs(currentSize.height - targetSize.height) > 0.5 {
                let previousFrame = panel.frame
                panel.setContentSize(targetSize)
                let newFrame = panel.frame
                let targetX = min(max(previousFrame.minX, visibleFrame?.minX ?? previousFrame.minX),
                                  max(visibleFrame?.minX ?? previousFrame.minX,
                                      (visibleFrame?.maxX ?? newFrame.maxX) - newFrame.width))
                let targetY = min(max(previousFrame.maxY - newFrame.height,
                                      visibleFrame?.minY ?? previousFrame.minY),
                                  max(visibleFrame?.minY ?? previousFrame.minY,
                                      (visibleFrame?.maxY ?? newFrame.maxY) - newFrame.height))
                panel.setFrameOrigin(NSPoint(x: targetX, y: targetY))
            }
        }
    }
    @objc private func selectExperiment(_ sender: NSPopUpButton) {
        guard let mode = Self.mode(for: sender.selectedItem) else {
            refreshModeSelection()
            return
        }
        changeMode(mode)
    }
    @objc private func selectExperimentMenu(_ sender: NSMenuItem) {
        guard let mode = Self.mode(for: sender) else { return }
        changeMode(mode)
    }
    private func changeMode(_ mode: SimulationMode) {
        guard !modeTransitionInProgress else { return }
        modeTransitionSource = renderer.state.mode
        modeTransitionInProgress = true
        refreshTransport()
        mouseHeld = false
        rebaseDrag = false
        renderer.clearInput()
        renderer.selectMode(mode)
        modeTransitionInProgress = false
        refreshControls()
    }
    @objc private func singleStep(_ sender: Any?) {
        guard !modeTransitionInProgress else { return }
        renderer.requestSingleStep()
    }
    @objc private func restart(_ sender: Any?) {
        guard !modeTransitionInProgress else { return }
        if renderer.state.mode.is3D {
            modeTransitionSource = renderer.state.mode
            modeTransitionInProgress = true
            refreshTransport()
            mouseHeld = false
            renderer.restartCurrentSimulation()
            modeTransitionInProgress = false
            refreshControls()
            return
        }
        mouseHeld = false
        renderer.restartCurrentSimulation()
        refreshControls()
    }
    @objc private func changeAdjustment(_ sender: NSPopUpButton) {
        guard !renderer.state.mode.is3D, let lesson = renderer.state.mode.experiment else { return }
        renderer.setExperimentAdjustment(lesson.choices[sender.indexOfSelectedItem]); refreshControls()
    }
    @objc private func changeOverlay(_ sender: NSButton) {
        renderer.setDisplayOptions(DisplayOptions(arrows: overlayButtons[0].state == .on, particles: overlayButtons[1].state == .on, trails: overlayButtons[2].state == .on)); refreshControls()
    }
    @objc private func toggleAbout(_ sender: Any?) { aboutText.isHidden.toggle(); updateControlLayout() }
    private func refreshTransport() {
        let state = renderer.state
        stepLabel.stringValue = state.status
        pauseButton.title = state.userPaused ? (state.mode.isLesson && state.stepCount == 0 ? "Run" : "Resume") : "Pause"
        pauseButton.setAccessibilityLabel(state.userPaused ? "Resume simulation" : "Pause simulation")
        pauseButton.isEnabled = !modeTransitionInProgress && !state.complete
        stepButton.isEnabled = !modeTransitionInProgress && state.canStep
        experimentSelector.isEnabled = !modeTransitionInProgress
        restartButton.isEnabled = !modeTransitionInProgress
        restartButton.title = state.mode == .freePlay ? "Reset fluid" : "Restart experiment"
    }

    @objc private func selectField(_ sender: NSButton) {
        guard !renderer.state.mode.is3D else { return }
        guard let field = DisplayField(rawValue: sender.tag) else { return }
        renderer.selectField(field)
        refreshControls()
    }

    @objc private func togglePause(_ sender: NSButton) {
        guard !modeTransitionInProgress else { return }
        changePauseState()
    }

    @objc private func toggleTuning(_ sender: NSButton) {
        isTuningExpanded.toggle()
        tuningGroup.isHidden = !isTuningExpanded
        tuningButton.title = isTuningExpanded ? "Hide Tuning" : "Show Tuning"
        refreshControls()
    }

    @objc private func changeTuning(_ sender: NSSlider) {
        guard let control = TuningControl(rawValue: sender.tag) else { return }
        renderer.setTuningPosition(Float(sender.doubleValue), for: control)
        refreshTuningValues()
    }

    private func refreshTuningValues() {
        for control in TuningControl.allCases {
            let position = renderer.state.tuning.position(for: control)
            tuningSliders[control]?.floatValue = position
            let value = "\(Int((position * 100).rounded()))%"
            tuningValues[control]?.stringValue = value
            tuningSliders[control]?.setAccessibilityValue(value)
        }
    }

    private func refreshModeSelection() {
        guard let identity = Self.identity(for: renderer.state.mode) else { return }
        let popupItems = experimentSelector.menu?.items ?? []
        var selectedItem: NSMenuItem?
        for item in popupItems {
            guard let mode = Self.mode(for: item) else { continue }
            let isSelected = Self.identity(for: mode) == identity
            item.state = isSelected ? .on : .off
            if isSelected { selectedItem = item }
        }
        if let selectedItem { experimentSelector.select(selectedItem) }
        for item in simulationMenu?.items ?? [] {
            guard let mode = Self.mode(for: item) else { continue }
            item.state = mode == renderer.state.mode ? .on : .off
        }
    }

    private func presentThreeDModeFailure(error: String, sourceMode: SimulationMode?,
                                          committedMode: SimulationMode) {
        guard !isPresentingModeFailure else { return }
        isPresentingModeFailure = true
        NSLog("3D lesson preparation failed: %@", error)

        let restoredFreePlay = (sourceMode == nil || sourceMode?.is3D == true) && committedMode == .freePlay
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Couldn’t open 3D Dye Advection"
        alert.informativeText = restoredFreePlay
            ? "The 3D simulation could not be prepared. Free Play has been restored. Continue in 2D, or choose 3D Dye Advection again to retry."
            : "The 3D simulation could not be prepared. Your 2D simulation is still available. Continue in 2D, or choose 3D Dye Advection again to retry."
        alert.addButton(withTitle: "Continue in 2D")
        alert.buttons.first?.keyEquivalent = "\r"
        alert.buttons.first?.keyEquivalentModifierMask = []

        let alertWindow = alert.window
        let escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard event.keyCode == 53, event.window === alertWindow else { return event }
            NSApp.stopModal(withCode: .alertFirstButtonReturn)
            return nil
        }
        defer {
            if let escapeMonitor { NSEvent.removeMonitor(escapeMonitor) }
        }
        _ = alert.runModal()
        isPresentingModeFailure = false
        refreshControls()
    }

    private func refreshControls() {
        refreshModeSelection()
        for (field, button) in fieldButtons {
            let selected = renderer.state.field == field
            button.state = selected ? .on : .off
            button.title = selected ? "✓ \(fieldTitle(field))" : fieldTitle(field)
            button.font = NSFont.systemFont(ofSize: NSFont.systemFontSize, weight: selected ? .semibold : .regular)
            button.contentTintColor = selected ? .controlAccentColor : .labelColor
            button.setAccessibilityLabel(fieldTitle(field))
            button.setAccessibilityValue(selected ? "Selected" : "Not selected")
        }
        refreshTransport()
        let state = renderer.state
        let isThreeD = state.mode.is3D
        twoDBodyStack.isHidden = isThreeD
        threeDBodyStack.isHidden = !isThreeD
        threeDColourLegend.isThreeD = isThreeD
        if isThreeD {
            restartButton.nextKeyView = inspectionPlaneControl
            updateInspectionFocusOrder()
        } else {
            restartButton.nextKeyView = nil
        }
        refreshInspectionControls()
        stepButton.setAccessibilityHelp(isThreeD ? "Advance the 3D simulation by one step" : nil)
        restartButton.setAccessibilityHelp(
            isThreeD ? "Return the 3D experiment to step 0. Keep the camera, slice and tracer visibility." : nil
        )
        metalView.setAccessibilityLabel(isThreeD ? "Fixed XY cross-section of 3D dye concentration" : nil)
        lessonGroup.isHidden = state.mode == .freePlay || state.mode.is3D
        if let lesson = state.mode.experiment {
            question.stringValue = lesson.question; notice.stringValue = lesson.notice; adjustmentLabel.stringValue = lesson.adjustmentTitle
            adjustmentSelector.setAccessibilityLabel(lesson.adjustmentTitle)
            if displayedLesson != lesson { adjustmentSelector.removeAllItems(); adjustmentSelector.addItems(withTitles: lesson.choices.map(\.title)) }
            adjustmentSelector.selectItem(at: lesson.choices.firstIndex(of: state.adjustment!)!)
        }
        displayedLesson = state.mode.experiment
        explanation.stringValue = state.field.explanation
        colourLegend.field = state.field
        legend.stringValue = state.field.legend + "\n" + state.field.scaleNote
        let options = state.displayOptions
        for (button, value) in zip(overlayButtons, [options.arrows, options.particles, options.trails]) { button.state = value ? .on : .off }
        overlayButtons[2].isEnabled = options.particles
        tuningButton.isHidden = state.mode != .freePlay
        tuningGroup.isHidden = state.mode != .freePlay || !isTuningExpanded
        refreshTuningValues()
        updateControlLayout()
    }

    private func updateInspectionFocusOrder() {
        controlsPanel?.recalculateKeyViewLoop()
    }

    isolated deinit {
        if let eventMonitor { NSEvent.removeMonitor(eventMonitor) }
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        guard renderer != nil, metalView.bounds.size != lastCanvasSize else { return }
        lastCanvasSize = metalView.bounds.size
        renderer.clearInput()
        if mouseHeld { rebaseDrag = true }
        updateControlLayout()
    }

    override func mouseDown(with event: NSEvent) {
        mouseHeld = true
        rebaseDrag = false
        guard renderer.state.shouldAdvance else { return }
        let point = metalView.convert(event.locationInWindow, from: nil)

        let position = SIMD2<Float>(Float(point.x), Float(metalView.bounds.height - point.y))
        renderer.updateMouseInteraction(position: position, in: metalView)
    }

    override func mouseDragged(with event: NSEvent) {
        guard mouseHeld, renderer.state.shouldAdvance else { return }
        let point = metalView.convert(event.locationInWindow, from: nil)

        let position = SIMD2<Float>(Float(point.x), Float(metalView.bounds.height - point.y))
        if rebaseDrag {
            renderer.clearInput()
            rebaseDrag = false
        }
        renderer.updateMouseInteraction(position: position, in: metalView)
    }

    override func mouseUp(with event: NSEvent) {
        mouseHeld = false
        rebaseDrag = false
        renderer.updateMouseInteraction(position: nil, in: metalView)
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 0x31:
            changePauseState()
        case 0x01:
            changeSource()
        default:
            break
        }
    }

    private func changeSource() {
        guard !renderer.state.mode.is3D else { return }
        renderer.nextSlab()
        refreshControls()
    }

    private func changePauseState() {
        guard !modeTransitionInProgress else { return }
        renderer.togglePause()
        if mouseHeld { rebaseDrag = true }
        refreshControls()
    }
}

private final class ColourLegendView: NSView {
    var field: DisplayField = .density { didSet { needsDisplay = true } }
    var isThreeD = false { didSet { needsDisplay = true } }

    override func draw(_ dirtyRect: NSRect) {
        if isThreeD {
            let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
            let paletteStops = FieldVisualization3D.paletteStops
            let colors = paletteStops.map { stop in
                NSColor(srgbRed: CGFloat(stop.color.x), green: CGFloat(stop.color.y),
                        blue: CGFloat(stop.color.z), alpha: 1).cgColor
            } as CFArray
            let locations = paletteStops.map { CGFloat($0.concentration) }
            if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors,
                                         locations: locations),
               let context = NSGraphicsContext.current?.cgContext {
                context.drawLinearGradient(gradient,
                                          start: CGPoint(x: bounds.minX, y: bounds.midY),
                                          end: CGPoint(x: bounds.maxX, y: bounds.midY),
                                          options: [])
            }
        } else {
            let colors = field.palette.map {
                NSColor(srgbRed: CGFloat($0.x), green: CGFloat($0.y), blue: CGFloat($0.z), alpha: 1)
            }
            NSGradient(colors: colors)?.draw(in: bounds, angle: 0)
        }
        NSColor.labelColor.setStroke()
        NSBezierPath(rect: bounds.insetBy(dx: 0.5, dy: 0.5)).stroke()
    }
}
