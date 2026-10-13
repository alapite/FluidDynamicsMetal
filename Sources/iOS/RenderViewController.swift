//
//  RenderViewController.swift
//  FluidDynamicsMetal
//
//  Created by Andrei-Sergiu Pițiș on 19/08/2017.
//  Copyright © 2017 Andrei-Sergiu Pițiș. All rights reserved.
//

import UIKit
import MetalKit


class RenderViewController: UIViewController, UIGestureRecognizerDelegate {

    var renderer: Renderer!
    private let experimentSelector = UIButton(type: .system)
    private let stepButton = UIButton(type: .system)
    private let restartButton = UIButton(type: .system)
    private let stepLabel = UILabel()
    private let lessonStack = UIStackView()
    private let question = UILabel()
    private let notice = UILabel()
    private let adjustmentLabel = UILabel()
    private let adjustmentSelector = UIButton(type: .system)
    private let colourLegend = ColourLegendView()
    private let canvasAccessibility = UIView()
    private let legend = UILabel()
    private let explanation = UILabel()
    private let aboutButton = UIButton(type: .system)
    private let aboutText = UILabel()
    private var overlaySwitches: [UISwitch] = []
    private let bodyStack = UIStackView()
    private let pinnedStack = UIStackView()
    private let transport = UIStackView()
    private var lastComplete = false
    private var touchOrder: [UITouch] = []
    private var positions: [UITouch: CGPoint] = [:]
    private var previousPositions: [UITouch: CGPoint] = [:]
    private var startPositions: [UITouch: CGPoint] = [:]
    private var activeTouches: Set<UITouch> = []
    private var pendingHolds: [UITouch: DispatchWorkItem] = [:]
    private var lastCanvasSize: CGSize = .zero
    private let hud = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
    private let caption = UILabel()
    private let fieldStack = UIStackView()
    private let controlsScroll = UIScrollView()
    private let pauseButton = UIButton(type: .system)
    private let tuningButton = UIButton(type: .system)
    private let tuningStack = UIStackView()
    private var tuningSliders: [TuningControl: UISlider] = [:]
    private var tuningValues: [TuningControl: UILabel] = [:]
    private var isTuningExpanded = false
    private var fieldButtons: [DisplayField: UIButton] = [:]
    private var hudWidth: NSLayoutConstraint?
    private var hudHeight: NSLayoutConstraint?
    var metalView: MTKView {
        return view as! MTKView
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        renderer = Renderer(metalView: metalView)
        metalView.delegate = renderer

        metalView.isMultipleTouchEnabled = true

        installControls()
        renderer.stateDidChange = { [weak self] in self?.refreshTransport() }

        let doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(doubleTap))
        doubleTapGesture.numberOfTapsRequired = 2
        doubleTapGesture.numberOfTouchesRequired = 1
        doubleTapGesture.delegate = self
        view.addGestureRecognizer(doubleTapGesture)

        let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(changeSource))
        gestureRecognizer.numberOfTapsRequired = 2
        gestureRecognizer.numberOfTouchesRequired = 2
        gestureRecognizer.delegate = self
        view.addGestureRecognizer(gestureRecognizer)

        // A two-finger shortcut takes precedence over a one-finger double tap.
        doubleTapGesture.require(toFail: gestureRecognizer)
        let singleTapGesture = UITapGestureRecognizer(target: self, action: #selector(singleTap(_:)))
        singleTapGesture.delegate = self
        singleTapGesture.require(toFail: doubleTapGesture)
        singleTapGesture.require(toFail: gestureRecognizer)
        view.addGestureRecognizer(singleTapGesture)

        NotificationCenter.default.addObserver(self, selector: #selector(willResignActive), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(didBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateAppearance), name: UIAccessibility.reduceTransparencyStatusDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateTextSize), name: UIContentSizeCategory.didChangeNotification, object: nil)
    }

    private func label(_ label: UILabel, _ text: String, style: UIFont.TextStyle = .subheadline) {
        label.text = text; label.font = .preferredFont(forTextStyle: style)
        label.adjustsFontForContentSizeCategory = true; label.numberOfLines = 0
    }
    private func configureButton(_ button: UIButton, title: String, id: String, action: Selector? = nil) {
        var configuration = UIButton.Configuration.filled()
        configuration.baseBackgroundColor = .secondarySystemBackground
        configuration.baseForegroundColor = .tintColor
        configuration.cornerStyle = .medium
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)
        configuration.titleLineBreakMode = .byWordWrapping
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { [weak button] attributes in
            var attributes = attributes
            attributes.font = UIFont.preferredFont(forTextStyle: .subheadline, compatibleWith: button?.traitCollection)
            return attributes
        }
        button.configuration = configuration
        button.setTitle(title, for: .normal)
        button.titleLabel?.adjustsFontForContentSizeCategory = true; button.titleLabel?.numberOfLines = 0
        button.accessibilityIdentifier = id
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        if let action { button.addTarget(self, action: action, for: .touchUpInside) }
    }
    private func installControls() {
        hud.translatesAutoresizingMaskIntoConstraints = false; hud.layer.cornerRadius = 12; hud.clipsToBounds = true
        hud.accessibilityIdentifier = "simulationControls"
        canvasAccessibility.isUserInteractionEnabled = false
        canvasAccessibility.isAccessibilityElement = true
        canvasAccessibility.accessibilityIdentifier = "lessonCanvas"
        canvasAccessibility.accessibilityLabel = "Fluid experiment canvas"
        canvasAccessibility.accessibilityTraits = .image
        metalView.addSubview(canvasAccessibility)
        metalView.addSubview(hud)
        for stack in [pinnedStack, bodyStack, lessonStack, fieldStack, tuningStack] { stack.axis = .vertical; stack.spacing = 8 }
        // Keep transport usable within the reserved area; explanatory text in the
        // scroll view retains the full accessibility text-size range.
        pinnedStack.maximumContentSizeCategory = .extraExtraExtraLarge
        configureButton(experimentSelector, title: "Free Play", id: "experimentSelector")
        experimentSelector.accessibilityLabel = "Experiments"; experimentSelector.showsMenuAsPrimaryAction = true
        configureButton(pauseButton, title: "Pause", id: "transport.pause", action: #selector(pauseFromHUD(_:)))
        configureButton(stepButton, title: "Step", id: "transport.step", action: #selector(singleStep))
        configureButton(restartButton, title: "Reset fluid", id: "transport.restart", action: #selector(restart))
        transport.axis = .horizontal; transport.spacing = 8; transport.distribution = .fillEqually
        transport.addArrangedSubview(pauseButton); transport.addArrangedSubview(stepButton); transport.addArrangedSubview(restartButton)
        label(stepLabel, "Step 0", style: .caption1); stepLabel.accessibilityIdentifier = "stepCount"
        for view in [experimentSelector, transport, stepLabel] { pinnedStack.addArrangedSubview(view) }
        label(question, "", style: .headline); question.accessibilityIdentifier = "lesson.question"
        label(notice, ""); label(adjustmentLabel, "")
        let noticeHeading = UILabel(); label(noticeHeading, "What to notice", style: .headline)
        let hint = UILabel(); label(hint, LearningCopy.adjustment, style: .caption1)
        configureButton(adjustmentSelector, title: "", id: "experimentAdjustment"); adjustmentSelector.showsMenuAsPrimaryAction = true
        for view in [question, noticeHeading, notice, adjustmentLabel, adjustmentSelector, hint] { lessonStack.addArrangedSubview(view) }
        bodyStack.addArrangedSubview(lessonStack)
        label(caption, "View", style: .caption1); bodyStack.addArrangedSubview(caption)
        for field in DisplayField.allCases {
            let button = UIButton(type: .system); button.tag = field.rawValue
            configureButton(button, title: field.title, id: "field.\(field.rawValue)", action: #selector(selectField(_:)))
            fieldButtons[field] = button
        }
        for fields in [[DisplayField.density, .pressure], [.velocity, .vorticity]] {
            let row = UIStackView(arrangedSubviews: fields.compactMap { fieldButtons[$0] }); row.distribution = .fillEqually; row.spacing = 8; fieldStack.addArrangedSubview(row)
        }
        bodyStack.addArrangedSubview(fieldStack)
        label(explanation, "", style: .caption1); label(legend, "", style: .caption1); legend.accessibilityIdentifier = "fieldLegend"
        bodyStack.addArrangedSubview(explanation); bodyStack.addArrangedSubview(colourLegend); bodyStack.addArrangedSubview(legend)
        colourLegend.heightAnchor.constraint(equalToConstant: 12).isActive = true
        for (index, title) in ["Velocity arrows", "Particles", "Trails"].enumerated() {
            let name = UILabel(); label(name, title)
            let toggle = UISwitch(); toggle.tag = index; toggle.accessibilityLabel = title; toggle.accessibilityIdentifier = "overlay.\(index)"
            toggle.addTarget(self, action: #selector(changeOverlay), for: .valueChanged); overlaySwitches.append(toggle)
            let row = UIStackView(arrangedSubviews: [name, toggle]); row.alignment = .center; row.spacing = 8
            row.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true; bodyStack.addArrangedSubview(row)
        }
        let trailsHint = UILabel(); label(trailsHint, LearningCopy.trails, style: .caption1); bodyStack.addArrangedSubview(trailsHint)
        configureButton(tuningButton, title: "Show Tuning", id: "tuning.toggle", action: #selector(toggleTuning(_:)))
        bodyStack.addArrangedSubview(tuningButton)
        for control in TuningControl.allCases {
            let name = UILabel(); label(name, control.title)
            let value = UILabel(); label(value, ""); value.textAlignment = .right; value.setContentCompressionResistancePriority(.required, for: .horizontal)
            tuningValues[control] = value
            let heading = UIStackView(arrangedSubviews: [name, value]); heading.spacing = 4
            let slider = UISlider(); slider.tag = control.rawValue; slider.isContinuous = true
            slider.accessibilityLabel = control.title; slider.accessibilityIdentifier = "tuning.\(control.identifier)"
            slider.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
            slider.addTarget(self, action: #selector(changeTuning(_:)), for: .valueChanged); tuningSliders[control] = slider
            let row = UIStackView(arrangedSubviews: [heading, slider]); row.axis = .vertical; row.spacing = 8; tuningStack.addArrangedSubview(row)
        }
        let fadingHint = UILabel(); label(fadingHint, LearningCopy.fading, style: .caption1); tuningStack.addArrangedSubview(fadingHint)
        tuningStack.isHidden = true; bodyStack.addArrangedSubview(tuningStack)
        configureButton(aboutButton, title: "About this simulation", id: "about.toggle", action: #selector(toggleAbout))
        label(aboutText, LearningCopy.about, style: .caption1); aboutText.isHidden = true
        bodyStack.addArrangedSubview(aboutButton); bodyStack.addArrangedSubview(aboutText)
        for view in [pinnedStack, bodyStack, controlsScroll] { view.translatesAutoresizingMaskIntoConstraints = false }
        controlsScroll.addSubview(bodyStack); hud.contentView.addSubview(pinnedStack); hud.contentView.addSubview(controlsScroll)
        hudWidth = hud.widthAnchor.constraint(equalToConstant: 340); hudHeight = hud.heightAnchor.constraint(equalToConstant: 380)
        let safe = metalView.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            hud.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -16),
            hud.bottomAnchor.constraint(equalTo: safe.bottomAnchor, constant: -16), hudWidth!, hudHeight!,
            pinnedStack.leadingAnchor.constraint(equalTo: hud.contentView.leadingAnchor, constant: 12),
            pinnedStack.trailingAnchor.constraint(equalTo: hud.contentView.trailingAnchor, constant: -12),
            pinnedStack.topAnchor.constraint(equalTo: hud.contentView.topAnchor, constant: 12),
            controlsScroll.topAnchor.constraint(equalTo: pinnedStack.bottomAnchor, constant: 8),
            controlsScroll.leadingAnchor.constraint(equalTo: hud.contentView.leadingAnchor, constant: 12),
            controlsScroll.trailingAnchor.constraint(equalTo: hud.contentView.trailingAnchor, constant: -12),
            controlsScroll.bottomAnchor.constraint(equalTo: hud.contentView.bottomAnchor, constant: -12),
            bodyStack.leadingAnchor.constraint(equalTo: controlsScroll.contentLayoutGuide.leadingAnchor),
            bodyStack.trailingAnchor.constraint(equalTo: controlsScroll.contentLayoutGuide.trailingAnchor),
            bodyStack.topAnchor.constraint(equalTo: controlsScroll.contentLayoutGuide.topAnchor),
            bodyStack.bottomAnchor.constraint(equalTo: controlsScroll.contentLayoutGuide.bottomAnchor),
            bodyStack.widthAnchor.constraint(equalTo: controlsScroll.frameLayoutGuide.widthAnchor)
        ])
        controlsScroll.accessibilityIdentifier = "controlsBody"
        updateAppearance(); refreshControls()
    }
    private func fieldTitle(_ field: DisplayField) -> String { field.title }

    @objc private func updateAppearance() {
        hud.effect = UIAccessibility.isReduceTransparencyEnabled ? nil : UIBlurEffect(style: .systemMaterial)
        hud.backgroundColor = UIAccessibility.isReduceTransparencyEnabled ? .systemBackground : .clear
    }

    @objc private func updateTextSize() { refreshControls() }

    private func updateControlLayout() {
        guard renderer != nil else { return }
        let safe = metalView.safeAreaLayoutGuide.layoutFrame
        guard safe.width > 32, safe.height > 32 else { return }
        let lesson = renderer.state.mode.experiment != nil
        let landscape = safe.width > safe.height
        let width: CGFloat
        if lesson {
            width = landscape ? min(safe.width * 0.6, max(safe.width * 0.4, 280)) - 24 : safe.width - 32
        } else { width = min(360, safe.width - 32) }
        hudWidth?.constant = width
        let pinnedHeight = pinnedStack.systemLayoutSizeFitting(CGSize(width: width - 24, height: UIView.layoutFittingCompressedSize.height), withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel).height
        let height: CGFloat
        if lesson {
            height = landscape ? safe.height - 32 : min(safe.height * 0.6, max(safe.height * 0.4, pinnedHeight + 72))
        } else { height = min(safe.height - 32, max(pinnedHeight + 100, safe.height * 0.65)) }
        hudHeight?.constant = height
        if lesson {
            let available = landscape
                ? CGRect(x: safe.minX, y: safe.minY, width: max(1, safe.width - width - 32), height: safe.height)
                : CGRect(x: safe.minX, y: safe.minY, width: safe.width, height: max(1, safe.height - height - 32))
            let side = min(available.width, available.height)
            canvasAccessibility.frame = CGRect(x: available.midX - side / 2, y: available.midY - side / 2, width: side, height: side)
            canvasAccessibility.isHidden = false
            if renderer.lessonAvailableRect != available { renderer.lessonAvailableRect = available }
        } else { canvasAccessibility.isHidden = true; if renderer.lessonAvailableRect != nil { renderer.lessonAvailableRect = nil } }
    }
    @objc private func singleStep() { renderer.requestSingleStep() }
    @objc private func restart() { clearTouches(); renderer.restartCurrentSimulation(); refreshControls() }
    @objc private func changeOverlay() {
        renderer.setDisplayOptions(DisplayOptions(arrows: overlaySwitches[0].isOn, particles: overlaySwitches[1].isOn, trails: overlaySwitches[2].isOn)); refreshControls()
    }
    @objc private func toggleAbout() { aboutText.isHidden.toggle(); updateControlLayout() }
    private func refreshTransport() {
        let state = renderer.state
        if stepLabel.text != state.status { stepLabel.text = state.status }
        let title = state.userPaused ? (state.mode.experiment != nil && state.stepCount == 0 ? "Run" : "Resume") : "Pause"
        if pauseButton.title(for: .normal) != title {
            pauseButton.setTitle(title, for: .normal)
        }
        let pauseLabel = state.userPaused ? "Resume simulation" : "Pause simulation"
        if pauseButton.accessibilityLabel != pauseLabel { pauseButton.accessibilityLabel = pauseLabel }
        if pauseButton.isEnabled == state.complete { pauseButton.isEnabled = !state.complete }
        if stepButton.isEnabled != state.canStep { stepButton.isEnabled = state.canStep }
        let restartTitle = state.mode == .freePlay ? "Reset fluid" : "Restart experiment"
        if restartButton.title(for: .normal) != restartTitle { restartButton.setTitle(restartTitle, for: .normal) }
        if lastComplete != state.complete { lastComplete = state.complete; updateControlLayout() }
    }

    private func refreshControls() {
        for (field, button) in fieldButtons {
            let selected = renderer.state.field == field
            button.setTitle(selected ? "✓ \(fieldTitle(field))" : fieldTitle(field), for: .normal)
            button.titleLabel?.font = UIFont.preferredFont(forTextStyle: .subheadline).withWeight(selected ? .semibold : .regular)
            button.layer.borderWidth = selected ? 2 : 0
            button.layer.borderColor = view.tintColor.cgColor
            button.tintColor = selected ? view.tintColor : .label
            button.accessibilityLabel = fieldTitle(field)
            button.accessibilityValue = selected ? "Selected" : "Not selected"
        }
        refreshTransport()
        let state = renderer.state
        experimentSelector.setTitle(state.mode.title + " ▾", for: .normal)
        experimentSelector.menu = UIMenu(title: "Experiments", children: SimulationMode.allCases.map { mode in
            UIAction(title: mode.title, state: mode == state.mode ? .on : .off) { [weak self] _ in
                guard let self else { return }; self.clearTouches(); self.renderer.selectMode(mode); self.refreshControls()
            }
        })
        lessonStack.isHidden = state.mode == .freePlay
        if let lesson = state.mode.experiment {
            question.text = lesson.question; notice.text = lesson.notice; adjustmentLabel.text = lesson.adjustmentTitle
            adjustmentSelector.setTitle(state.adjustment!.title + " ▾", for: .normal); adjustmentSelector.accessibilityLabel = lesson.adjustmentTitle
            adjustmentSelector.menu = UIMenu(children: lesson.choices.map { adjustment in
                UIAction(title: adjustment.title, state: adjustment == state.adjustment ? .on : .off) { [weak self] _ in
                    self?.clearTouches(); self?.renderer.setExperimentAdjustment(adjustment); self?.refreshControls()
                }
            })
        }
        colourLegend.field = state.field
        explanation.text = state.field.explanation; legend.text = state.field.legend + "\n" + state.field.scaleNote
        for (toggle, value) in zip(overlaySwitches, [state.displayOptions.arrows, state.displayOptions.particles, state.displayOptions.trails]) { toggle.isOn = value }
        overlaySwitches[2].isEnabled = state.displayOptions.particles
        tuningButton.isHidden = state.mode != .freePlay; tuningStack.isHidden = state.mode != .freePlay || !isTuningExpanded
        refreshTuningValues()
        updateControlLayout()
    }

    @objc private func toggleTuning(_ sender: UIButton) {
        isTuningExpanded.toggle()
        tuningStack.isHidden = !isTuningExpanded
        tuningButton.setTitle(isTuningExpanded ? "Hide Tuning" : "Show Tuning", for: .normal)
        refreshControls()
    }

    @objc private func changeTuning(_ sender: UISlider) {
        guard let control = TuningControl(rawValue: sender.tag) else { return }
        renderer.setTuningPosition(sender.value, for: control)
        refreshTuningValues()
    }

    private func refreshTuningValues() {
        for control in TuningControl.allCases {
            let position = renderer.state.tuning.position(for: control)
            tuningSliders[control]?.value = position
            let value = "\(Int((position * 100).rounded()))%"
            tuningValues[control]?.text = value
            tuningSliders[control]?.accessibilityValue = value
        }
    }

    @objc private func selectField(_ sender: UIButton) {
        guard let field = DisplayField(rawValue: sender.tag) else { return }
        renderer.selectField(field)
        refreshControls()
    }

    @objc private func pauseFromHUD(_ sender: UIButton) {
        cancelPendingHolds()
        clearTouches()
        renderer.togglePause()
        refreshControls()
    }

    private func isHUDTouch(_ touch: UITouch) -> Bool {
        var touchedView = touch.view
        while let candidate = touchedView {
            if candidate === hud { return true }
            touchedView = candidate.superview
        }
        return hud.bounds.contains(touch.location(in: hud))
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        return !isHUDTouch(touch)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateControlLayout()
        guard renderer != nil, metalView.bounds.size != lastCanvasSize else { return }
        lastCanvasSize = metalView.bounds.size
        cancelPendingHolds()
        for touch in touchOrder {
            let location = touch.location(in: metalView)
            positions[touch] = location
            previousPositions[touch] = location
            startPositions[touch] = location
        }
        renderer.clearInput()
        // A continuing contact starts with zero displacement at its new location.
        submitTouches()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()

        print("Got Memory Warning")
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard renderer.state.acceptsInput else { return }
        for touch in touches where !isHUDTouch(touch) {
            if positions[touch] == nil {
                touchOrder.append(touch)
            }
            let location = touch.location(in: metalView)
            positions[touch] = location
            previousPositions[touch] = location
            startPositions[touch] = location
            let hold = DispatchWorkItem { [weak self, weak touch] in
                guard let self = self, let touch = touch, self.positions[touch] != nil, self.renderer.state.acceptsInput else { return }
                self.pendingHolds.removeValue(forKey: touch)
                self.activeTouches.insert(touch)
                self.submitTouches()
            }
            pendingHolds[touch] = hold
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: hold)
        }
        submitTouches()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard renderer.state.acceptsInput else { return }
        for touch in touches where positions[touch] != nil {
            let location = touch.location(in: metalView)
            let start = startPositions[touch] ?? location
            if !activeTouches.contains(touch) && hypot(location.x - start.x, location.y - start.y) >= 3 {
                pendingHolds.removeValue(forKey: touch)?.cancel()
                activeTouches.insert(touch)
                previousPositions[touch] = start
            } else if activeTouches.contains(touch) {
                previousPositions[touch] = positions[touch]
            }
            positions[touch] = location
        }
        submitTouches()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        removeTouches(touches)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        removeTouches(touches)
    }

    private func removeTouches(_ touches: Set<UITouch>) {
        for touch in touches {
            pendingHolds.removeValue(forKey: touch)?.cancel()
            activeTouches.remove(touch)
            startPositions.removeValue(forKey: touch)
            positions.removeValue(forKey: touch)
            previousPositions.removeValue(forKey: touch)
        }
        touchOrder.removeAll { touches.contains($0) }
        submitTouches()
    }

    private func submitTouches() {
        guard renderer.state.acceptsInput else { renderer.clearInput(); return }
        let contacts = touchOrder.compactMap { touch -> FluidContact? in
            guard activeTouches.contains(touch) else { return nil }
            guard let location = positions[touch] else { return nil }
            let previous = previousPositions[touch] ?? location
            return FluidContact(position: SIMD2<Float>(Float(location.x), Float(location.y)),
                                impulse: SIMD2<Float>(Float(location.x - previous.x), Float(location.y - previous.y)))
        }
        renderer.updateTouchInteraction(contacts: contacts, in: metalView)
    }

    @objc func changeSource() {
        guard !renderer.state.inactive else { return }
        cancelPendingHolds()
        renderer.nextSlab()
        refreshControls()
    }

    @objc final func doubleTap() {
        guard !renderer.state.inactive else { return }
        cancelPendingHolds()
        clearTouches()
        renderer.togglePause()
        refreshControls()
    }

    @objc private func singleTap(_ recognizer: UITapGestureRecognizer) {
        guard renderer.state.acceptsInput else { return }
        let point = recognizer.location(in: metalView)
        guard !hud.bounds.contains(recognizer.location(in: hud)) else { return }
        renderer.enqueueTap(at: SIMD2<Float>(Float(point.x), Float(point.y)), in: metalView)
    }

    private func cancelPendingHolds() {
        for hold in pendingHolds.values { hold.cancel() }
        pendingHolds.removeAll()
    }

    private func clearTouches() {
        cancelPendingHolds()
        touchOrder.removeAll()
        positions.removeAll()
        previousPositions.removeAll()
        startPositions.removeAll()
        activeTouches.removeAll()
        renderer.clearInput()
    }

    @objc final func willResignActive() {
        clearTouches()
        renderer.resignActive()
    }

    @objc final func didBecomeActive() {
        renderer.becomeActive()
        refreshControls()
    }
}

private extension UIFont {
    func withWeight(_ weight: UIFont.Weight) -> UIFont {
        return UIFont.systemFont(ofSize: pointSize, weight: weight)
    }
}

private final class ColourLegendView: UIView {
    override class var layerClass: AnyClass { CAGradientLayer.self }
    var field: DisplayField = .density { didSet { update() } }
    private func update() {
        guard let gradient = layer as? CAGradientLayer else { return }
        gradient.colors = field.palette.map { UIColor(red: CGFloat($0.x), green: CGFloat($0.y), blue: CGFloat($0.z), alpha: 1).cgColor }
        gradient.startPoint = CGPoint(x: 0, y: 0.5); gradient.endPoint = CGPoint(x: 1, y: 0.5)
        layer.borderWidth = 1; layer.borderColor = UIColor.label.cgColor
    }
    override func layoutSubviews() { super.layoutSubviews(); update() }
}
