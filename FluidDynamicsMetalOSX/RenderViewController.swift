//
//  RenderViewController.swift
//  FluidDynamicsMetalOSX
//
//  Created by Andrei-Sergiu Pițiș on 16/12/2017.
//  Copyright © 2017 Andrei-Sergiu Pițiș. All rights reserved.
//

import AppKit
import MetalKit

class RenderViewController: NSViewController {
    var renderer: Renderer!
    private var mouseHeld = false
    private var rebaseDrag = false
    private var lastCanvasSize: CGSize = .zero
    private let hud = NSVisualEffectView()
    private let opaqueSurface = NSView()
    private let caption = NSTextField(labelWithString: "View")
    private let activeSummary = NSTextField(labelWithString: "")
    private let fieldGroup = NSStackView()
    private let controlsScroll = NSScrollView()
    private let pauseButton = NSButton(title: "Pause", target: nil, action: nil)
    private let tuningButton = NSButton(title: "Show Tuning", target: nil, action: nil)
    private let tuningGroup = NSStackView()
    private var tuningSliders: [TuningControl: NSSlider] = [:]
    private var tuningValues: [TuningControl: NSTextField] = [:]
    private var isTuningExpanded = false
    private var fieldButtons: [DisplayField: NSButton] = [:]
    private var hudWidth: NSLayoutConstraint?
    private var hudHeight: NSLayoutConstraint?
    private var usingOneColumn = false
    var metalView: MTKView {
        return view as! MTKView
    }

    var eventMonitor: Any?

    override func viewDidLoad() {
        super.viewDidLoad()

        renderer = Renderer(metalView: metalView)
        metalView.delegate = renderer

        installControls()

        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) {
            guard $0.window == self.view.window else { return $0 }
            // A focused native button owns Space. The monitor owns it elsewhere.
            if $0.keyCode == 0x31,
               let button = $0.window?.firstResponder as? NSButton,
               self.fieldButtons.values.contains(where: { $0 === button }) || button === self.pauseButton || button === self.tuningButton {
                return $0
            }
            if $0.window?.firstResponder is NSSlider { return $0 }
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
        updateControlLayout()
    }

    private func installControls() {
        hud.translatesAutoresizingMaskIntoConstraints = false
        hud.material = .hudWindow
        hud.blendingMode = .withinWindow
        hud.state = .active
        hud.wantsLayer = true
        hud.layer?.cornerRadius = 12
        hud.layer?.masksToBounds = true
        metalView.addSubview(hud)

        opaqueSurface.translatesAutoresizingMaskIntoConstraints = false
        opaqueSurface.wantsLayer = true
        hud.addSubview(opaqueSurface)
        NSLayoutConstraint.activate([
            opaqueSurface.leadingAnchor.constraint(equalTo: hud.leadingAnchor),
            opaqueSurface.trailingAnchor.constraint(equalTo: hud.trailingAnchor),
            opaqueSurface.topAnchor.constraint(equalTo: hud.topAnchor),
            opaqueSurface.bottomAnchor.constraint(equalTo: hud.bottomAnchor)
        ])

        caption.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        caption.textColor = .secondaryLabelColor
        activeSummary.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize, weight: .semibold)
        activeSummary.textColor = .labelColor
        activeSummary.isHidden = true
        fieldGroup.orientation = .vertical
        fieldGroup.spacing = 8
        fieldGroup.setAccessibilityLabel("Display field")
        for field in DisplayField.allCases {
            let button = NSButton(title: fieldTitle(field), target: self, action: #selector(selectField(_:)))
            button.tag = field.rawValue
            button.bezelStyle = .rounded
            button.setButtonType(.toggle)
            button.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
            button.contentTintColor = .labelColor
            button.heightAnchor.constraint(greaterThanOrEqualToConstant: 28).isActive = true
            button.setContentHuggingPriority(.defaultHigh, for: .horizontal)
            fieldButtons[field] = button
        }

        pauseButton.target = self
        pauseButton.action = #selector(togglePause(_:))
        pauseButton.bezelStyle = .rounded
        pauseButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 28).isActive = true

        tuningButton.target = self
        tuningButton.action = #selector(toggleTuning(_:))
        tuningButton.bezelStyle = .rounded
        tuningButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 28).isActive = true
        tuningGroup.orientation = .vertical
        tuningGroup.spacing = 8
        tuningGroup.setAccessibilityLabel("Fluid tuning")
        for control in TuningControl.allCases {
            let label = NSTextField(labelWithString: control.title)
            label.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
            let value = NSTextField(labelWithString: "")
            value.alignment = .right
            tuningValues[control] = value
            let heading = NSStackView(views: [label, value])
            heading.orientation = .horizontal
            heading.distribution = .fill
            let slider = NSSlider(value: 0, minValue: 0, maxValue: 1, target: self, action: #selector(changeTuning(_:)))
            slider.isContinuous = true
            slider.tag = control.rawValue
            slider.setAccessibilityLabel(control.title)
            tuningSliders[control] = slider
            let row = NSStackView(views: [heading, slider])
            row.orientation = .vertical
            row.spacing = 8
            tuningGroup.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: tuningGroup.widthAnchor).isActive = true
        }
        let fadeHint = NSTextField(labelWithString: "Higher Fade = faster fade")
        fadeHint.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        fadeHint.textColor = .secondaryLabelColor
        tuningGroup.addArrangedSubview(fadeHint)
        tuningGroup.isHidden = true

        let content = NSStackView(views: [caption, fieldGroup, pauseButton, tuningButton, tuningGroup])
        content.orientation = .vertical
        content.alignment = .leading
        content.spacing = 8
        content.translatesAutoresizingMaskIntoConstraints = false
        controlsScroll.drawsBackground = false
        controlsScroll.hasVerticalScroller = true
        controlsScroll.autohidesScrollers = true
        controlsScroll.translatesAutoresizingMaskIntoConstraints = false
        controlsScroll.documentView = content
        hud.addSubview(activeSummary)
        hud.addSubview(controlsScroll)
        activeSummary.translatesAutoresizingMaskIntoConstraints = false
        hudWidth = hud.widthAnchor.constraint(equalToConstant: 248)
        hudHeight = hud.heightAnchor.constraint(equalToConstant: 168)
        NSLayoutConstraint.activate([
            hud.trailingAnchor.constraint(equalTo: metalView.trailingAnchor, constant: -16),
            hud.topAnchor.constraint(equalTo: metalView.topAnchor, constant: 16),
            hud.leadingAnchor.constraint(greaterThanOrEqualTo: metalView.leadingAnchor, constant: 16),
            hud.bottomAnchor.constraint(lessThanOrEqualTo: metalView.bottomAnchor, constant: -16),
            hudWidth!, hudHeight!,
            activeSummary.leadingAnchor.constraint(equalTo: hud.leadingAnchor, constant: 16),
            activeSummary.topAnchor.constraint(equalTo: hud.topAnchor, constant: 8),
            controlsScroll.leadingAnchor.constraint(equalTo: hud.leadingAnchor, constant: 16),
            controlsScroll.trailingAnchor.constraint(equalTo: hud.trailingAnchor, constant: -16),
            controlsScroll.topAnchor.constraint(equalTo: hud.topAnchor, constant: 16),
            controlsScroll.bottomAnchor.constraint(equalTo: hud.bottomAnchor, constant: -16),
            content.widthAnchor.constraint(equalTo: controlsScroll.contentView.widthAnchor),
            fieldGroup.widthAnchor.constraint(equalTo: content.widthAnchor),
            pauseButton.widthAnchor.constraint(equalTo: content.widthAnchor)
        ])
        tuningButton.widthAnchor.constraint(equalTo: content.widthAnchor).isActive = true
        tuningGroup.widthAnchor.constraint(equalTo: content.widthAnchor).isActive = true
        NotificationCenter.default.addObserver(self, selector: #selector(updateAppearance), name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil)
        updateAppearance()
        refreshControls()
    }

    private func fieldTitle(_ field: DisplayField) -> String {
        switch field {
        case .density: return "Density"
        case .pressure: return "Pressure"
        case .velocity: return "Velocity"
        case .vorticity: return "Vorticity"
        }
    }

    @objc private func updateAppearance() {
        opaqueSurface.isHidden = !NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
        opaqueSurface.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
    }

    private func updateControlLayout() {
        guard view.bounds.width > 0, view.bounds.height > 0 else { return }
        let availableWidth = max(1, view.bounds.width - 32)
        let availableHeight = max(1, view.bounds.height - 32)
        let buttonWidth = fieldButtons.values.map { $0.intrinsicContentSize.width + 8 }.max() ?? 96
        let twoColumnWidth = buttonWidth * 2 + 8 + 32
        let oneColumn = twoColumnWidth > availableWidth
        if oneColumn != usingOneColumn || fieldGroup.arrangedSubviews.isEmpty {
            usingOneColumn = oneColumn
            for row in fieldGroup.arrangedSubviews { fieldGroup.removeArrangedSubview(row); row.removeFromSuperview() }
            let fields = DisplayField.allCases
            for index in stride(from: 0, to: fields.count, by: oneColumn ? 1 : 2) {
                let row = NSStackView(views: Array(fields[index..<min(index + (oneColumn ? 1 : 2), fields.count)]).compactMap { fieldButtons[$0] })
                row.orientation = .horizontal
                row.distribution = .fillEqually
                row.spacing = 8
                fieldGroup.addArrangedSubview(row)
                row.widthAnchor.constraint(equalTo: fieldGroup.widthAnchor).isActive = true
            }
        }
        let scrolling = availableHeight < (isTuningExpanded ? 440 : oneColumn ? 284 : 176)
        activeSummary.isHidden = !scrolling
        caption.isHidden = scrolling
        hudWidth?.constant = min(320, availableWidth, max(oneColumn ? buttonWidth + 32 : twoColumnWidth, 192))
        let wantedHeight: CGFloat = (oneColumn ? 252 : 160) + 36 + (isTuningExpanded ? 260 : 0)
        hudHeight?.constant = min(availableHeight, wantedHeight)
        fieldGroup.frame.size.width = max(1, (hudWidth?.constant ?? 248) - 32)
        fieldGroup.layoutSubtreeIfNeeded()
        controlsScroll.contentView.scroll(to: .zero)
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
        activeSummary.stringValue = "View: \(fieldTitle(renderer.state.field))"
        pauseButton.title = renderer.state.userPaused ? "Resume" : "Pause"
        pauseButton.setAccessibilityLabel(renderer.state.userPaused ? "Resume simulation" : "Pause simulation")
        refreshTuningValues()
        updateControlLayout()
    }

    deinit {
        NSEvent.removeMonitor(eventMonitor as Any)
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
        let hudPoint = hud.convert(event.locationInWindow, from: nil)
        guard !hud.bounds.contains(hudPoint) else { return }
        mouseHeld = true
        rebaseDrag = false
        guard renderer.state.shouldAdvance else { return }
        let point = metalView.convert(event.locationInWindow, from: nil)

        let position = float2(Float(point.x), Float(metalView.bounds.height - point.y))
        let tuple = FloatTuple(position, float2(), float2(), float2(), float2())
        renderer.updateInteraction(points: tuple, in: metalView)
    }

    override func mouseDragged(with event: NSEvent) {
        guard mouseHeld, renderer.state.shouldAdvance else { return }
        let point = metalView.convert(event.locationInWindow, from: nil)

        let position = float2(Float(point.x), Float(metalView.bounds.height - point.y))
        let tuple = FloatTuple(position, float2(), float2(), float2(), float2())
        if rebaseDrag {
            renderer.clearInput()
            rebaseDrag = false
        }
        renderer.updateInteraction(points: tuple, in: metalView)
    }

    override func mouseUp(with event: NSEvent) {
        mouseHeld = false
        rebaseDrag = false
        renderer.updateInteraction(points: nil, in: metalView)
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
