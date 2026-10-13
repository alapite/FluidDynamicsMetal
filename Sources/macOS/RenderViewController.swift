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
    private let legend = NSTextField(wrappingLabelWithString: "")
    private let explanation = NSTextField(wrappingLabelWithString: "")
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
    private let tuningGroup = NSStackView()
    private var tuningSliders: [TuningControl: NSSlider] = [:]
    private var tuningValues: [TuningControl: NSTextField] = [:]
    private var isTuningExpanded = false
    private var fieldButtons: [DisplayField: NSButton] = [:]
    private var controlsPanel: NSPanel?
    private var panelConfigured = false
    private var restorePanelAfterMinimize = false
    private var hudWidth: NSLayoutConstraint?
    private var hudHeight: NSLayoutConstraint?
    var metalView: MTKView {
        return view as! MTKView
    }

    var eventMonitor: Any?

    override func viewDidLoad() {
        super.viewDidLoad()

        renderer = Renderer(metalView: metalView)
        metalView.delegate = renderer

        installControls()
        renderer.stateDidChange = { [weak self] in self?.refreshTransport() }
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
        for (index, mode) in SimulationMode.allCases.enumerated() {
            let command = NSMenuItem(title: mode.title, action: #selector(selectExperimentMenu(_:)), keyEquivalent: String(index + 1))
            command.tag = index; command.target = self; command.keyEquivalentModifierMask = .command; simulationMenu.addItem(command)
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
        if menuItem.action == #selector(toggleControlsPanel(_:)) {
            menuItem.title = controlsPanel?.isVisible == true ? "Hide Simulation Controls" : "Show Simulation Controls"
        }
        if menuItem.action == #selector(singleStep(_:)) { return renderer.state.canStep }
        if menuItem.action == #selector(togglePause(_:)) { menuItem.title = pauseButton.title; return !renderer.state.complete }
        if menuItem.action == #selector(restart(_:)) { menuItem.title = restartButton.title }
        if menuItem.action == #selector(selectExperimentMenu(_:)) { menuItem.state = renderer.state.mode == SimulationMode.allCases[menuItem.tag] ? .on : .off }
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
        experimentSelector.addItems(withTitles: SimulationMode.allCases.map(\.title))
        experimentSelector.target = self; experimentSelector.action = #selector(selectExperiment(_:))
        experimentSelector.setAccessibilityLabel("Experiments"); experimentSelector.setAccessibilityIdentifier("experimentSelector")
        button(pauseButton, #selector(togglePause(_:)), "transport.pause")
        button(stepButton, #selector(singleStep(_:)), "transport.step")
        button(restartButton, #selector(restart(_:)), "transport.restart")
        let transport = NSStackView(views: [pauseButton, stepButton, restartButton]); transport.spacing = 4
        stepLabel.setAccessibilityIdentifier("stepCount")
        vertical(pinnedStack)
        for view in [experimentSelector, transport, stepLabel] { pinnedStack.addArrangedSubview(view) }
        vertical(bodyStack); vertical(fieldGroup); vertical(lessonGroup); vertical(tuningGroup)
        question.font = .systemFont(ofSize: NSFont.systemFontSize, weight: .semibold)
        question.setAccessibilityIdentifier("lesson.question")
        let noticeHeading = NSTextField(labelWithString: "What to notice")
        noticeHeading.font = .systemFont(ofSize: NSFont.smallSystemFontSize, weight: .semibold)
        adjustmentSelector.target = self; adjustmentSelector.action = #selector(changeAdjustment(_:))
        adjustmentSelector.setAccessibilityIdentifier("experimentAdjustment")
        for view in [question, noticeHeading, notice, adjustmentLabel, adjustmentSelector, NSTextField(wrappingLabelWithString: LearningCopy.adjustment)] { lessonGroup.addArrangedSubview(view) }
        bodyStack.addArrangedSubview(lessonGroup)
        bodyStack.addArrangedSubview(NSTextField(labelWithString: "View"))
        for field in DisplayField.allCases {
            let item = NSButton(title: field.title, target: self, action: #selector(selectField(_:)))
            item.tag = field.rawValue; item.setButtonType(.toggle); item.bezelStyle = .rounded
            item.setAccessibilityIdentifier("field.\(field.rawValue)"); fieldButtons[field] = item
        }
        for fields in [[DisplayField.density, .pressure], [.velocity, .vorticity]] {
            let row = NSStackView(views: fields.compactMap { fieldButtons[$0] }); row.distribution = .fillEqually
            fieldGroup.addArrangedSubview(row); row.widthAnchor.constraint(equalTo: fieldGroup.widthAnchor).isActive = true
        }
        bodyStack.addArrangedSubview(fieldGroup); bodyStack.addArrangedSubview(explanation); bodyStack.addArrangedSubview(colourLegend); bodyStack.addArrangedSubview(legend)
        colourLegend.heightAnchor.constraint(equalToConstant: 12).isActive = true
        legend.setAccessibilityIdentifier("fieldLegend")
        for (index, title) in ["Velocity arrows", "Particles", "Trails"].enumerated() {
            let item = NSButton(checkboxWithTitle: title, target: self, action: #selector(changeOverlay(_:)))
            item.tag = index; item.setAccessibilityIdentifier("overlay.\(index)"); overlayButtons.append(item); bodyStack.addArrangedSubview(item)
        }
        bodyStack.addArrangedSubview(NSTextField(wrappingLabelWithString: LearningCopy.trails))
        button(tuningButton, #selector(toggleTuning(_:)), "tuning.toggle")
        bodyStack.addArrangedSubview(tuningButton)
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
        tuningGroup.isHidden = true; bodyStack.addArrangedSubview(tuningGroup)
        button(aboutButton, #selector(toggleAbout(_:)), "about.toggle")
        aboutText.isHidden = true; bodyStack.addArrangedSubview(aboutButton); bodyStack.addArrangedSubview(aboutText)
        for stack in [pinnedStack, bodyStack] {
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

    @objc private func updateAppearance() {
        opaqueSurface.isHidden = !NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
        opaqueSurface.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
    }

    private func updateControlLayout() {
        guard renderer != nil else { return }
        let width: CGFloat = 368
        hudWidth?.constant = width
        hud.layoutSubtreeIfNeeded()
        let wanted = pinnedStack.fittingSize.height + bodyStack.fittingSize.height + 36
        let available = max(240, (controlsPanel?.screen?.visibleFrame.height ?? 800) - 80)
        let height = min(available, max(240, wanted))
        if hudHeight?.constant != height {
            hudHeight?.constant = height
            if let panel = controlsPanel {
                let top = panel.frame.maxY
                panel.setContentSize(NSSize(width: width, height: height))
                panel.setFrameOrigin(NSPoint(x: panel.frame.minX, y: top - panel.frame.height))
            }
        }
    }
    @objc private func selectExperiment(_ sender: NSPopUpButton) { changeMode(SimulationMode.allCases[sender.indexOfSelectedItem]) }
    @objc private func selectExperimentMenu(_ sender: NSMenuItem) { changeMode(SimulationMode.allCases[sender.tag]) }
    private func changeMode(_ mode: SimulationMode) {
        mouseHeld = false; rebaseDrag = false; renderer.clearInput(); renderer.selectMode(mode); refreshControls()
    }
    @objc private func singleStep(_ sender: Any?) { renderer.requestSingleStep() }
    @objc private func restart(_ sender: Any?) { mouseHeld = false; renderer.restartCurrentSimulation(); refreshControls() }
    @objc private func changeAdjustment(_ sender: NSPopUpButton) {
        guard let lesson = renderer.state.mode.experiment else { return }
        renderer.setExperimentAdjustment(lesson.choices[sender.indexOfSelectedItem]); refreshControls()
    }
    @objc private func changeOverlay(_ sender: NSButton) {
        renderer.setDisplayOptions(DisplayOptions(arrows: overlayButtons[0].state == .on, particles: overlayButtons[1].state == .on, trails: overlayButtons[2].state == .on)); refreshControls()
    }
    @objc private func toggleAbout(_ sender: Any?) { aboutText.isHidden.toggle(); updateControlLayout() }
    private func refreshTransport() {
        let state = renderer.state
        stepLabel.stringValue = state.status
        pauseButton.title = state.userPaused ? (state.mode.experiment != nil && state.stepCount == 0 ? "Run" : "Resume") : "Pause"
        pauseButton.setAccessibilityLabel(state.userPaused ? "Resume simulation" : "Pause simulation")
        pauseButton.isEnabled = !state.complete
        stepButton.isEnabled = state.canStep
        restartButton.title = state.mode == .freePlay ? "Reset fluid" : "Restart experiment"
    }

    @objc private func selectField(_ sender: NSButton) {
        guard let field = DisplayField(rawValue: sender.tag) else { return }
        renderer.selectField(field)
        refreshControls()
    }

    @objc private func togglePause(_ sender: NSButton) { changePauseState() }

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

    private func refreshControls() {
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
        experimentSelector.selectItem(at: SimulationMode.allCases.firstIndex(of: state.mode)!)
        lessonGroup.isHidden = state.mode == .freePlay
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
        renderer.nextSlab()
        refreshControls()
    }

    private func changePauseState() {
        renderer.togglePause()
        if mouseHeld { rebaseDrag = true }
        refreshControls()
    }
}

private final class ColourLegendView: NSView {
    var field: DisplayField = .density { didSet { needsDisplay = true } }
    override func draw(_ dirtyRect: NSRect) {
        let colors = field.palette.map { NSColor(srgbRed: CGFloat($0.x), green: CGFloat($0.y), blue: CGFloat($0.z), alpha: 1) }
        NSGradient(colors: colors)?.draw(in: bounds, angle: 0)
        NSColor.labelColor.setStroke(); NSBezierPath(rect: bounds.insetBy(dx: 0.5, dy: 0.5)).stroke()
    }
}
