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
    private let fieldScroll = NSScrollView()
    private let pauseButton = NSButton(title: "Pause", target: nil, action: nil)
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
               self.fieldButtons.values.contains(where: { $0 === button }) || button === self.pauseButton {
                return $0
            }
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

        fieldScroll.drawsBackground = false
        fieldScroll.hasVerticalScroller = true
        fieldScroll.autohidesScrollers = true
        fieldScroll.documentView = fieldGroup
        fieldScroll.translatesAutoresizingMaskIntoConstraints = false

        pauseButton.target = self
        pauseButton.action = #selector(togglePause(_:))
        pauseButton.bezelStyle = .rounded
        pauseButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 28).isActive = true

        let content = NSStackView(views: [caption, activeSummary, fieldScroll, pauseButton])
        content.orientation = .vertical
        content.alignment = .leading
        content.spacing = 8
        content.translatesAutoresizingMaskIntoConstraints = false
        hud.addSubview(content)
        hudWidth = hud.widthAnchor.constraint(equalToConstant: 248)
        hudHeight = hud.heightAnchor.constraint(equalToConstant: 168)
        NSLayoutConstraint.activate([
            hud.trailingAnchor.constraint(equalTo: metalView.trailingAnchor, constant: -16),
            hud.topAnchor.constraint(equalTo: metalView.topAnchor, constant: 16),
            hud.leadingAnchor.constraint(greaterThanOrEqualTo: metalView.leadingAnchor, constant: 16),
            hud.bottomAnchor.constraint(lessThanOrEqualTo: metalView.bottomAnchor, constant: -16),
            hudWidth!, hudHeight!,
            content.leadingAnchor.constraint(equalTo: hud.leadingAnchor, constant: 16),
            content.trailingAnchor.constraint(equalTo: hud.trailingAnchor, constant: -16),
            content.topAnchor.constraint(equalTo: hud.topAnchor, constant: 16),
            content.bottomAnchor.constraint(equalTo: hud.bottomAnchor, constant: -16),
            fieldScroll.widthAnchor.constraint(equalTo: content.widthAnchor),
            pauseButton.widthAnchor.constraint(equalTo: content.widthAnchor)
        ])
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
        let scrolling = oneColumn && availableHeight < 260
        activeSummary.isHidden = !scrolling
        caption.isHidden = scrolling
        hudWidth?.constant = min(availableWidth, max(oneColumn ? buttonWidth + 32 : twoColumnWidth, 192))
        let wantedHeight: CGFloat = oneColumn ? 252 : 160
        hudHeight?.constant = min(availableHeight, wantedHeight)
        fieldScroll.hasVerticalScroller = scrolling
        fieldGroup.frame.size.width = max(1, (hudWidth?.constant ?? 248) - 32)
        fieldGroup.layoutSubtreeIfNeeded()
        fieldGroup.frame.size.height = max(fieldGroup.fittingSize.height, fieldScroll.bounds.height)
    }

    @objc private func selectField(_ sender: NSButton) {
        guard let field = DisplayField(rawValue: sender.tag) else { return }
        renderer.selectField(field)
        refreshControls()
    }

    @objc private func togglePause(_ sender: NSButton) { changePauseState() }

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
        mouseHeld = true
        rebaseDrag = false
        guard renderer.state.shouldAdvance else { return }
        let point = metalView.convert(event.locationInWindow, from: nil)

        let position = float2(Float(point.x), Float(metalView.bounds.height - point.y))
        let tuple = FloatTuple(position, float2(), float2(), float2(), float2())
        renderer.updateInteraction(points: tuple, in: metalView)
    }

    override func mouseDragged(with event: NSEvent) {
        guard renderer.state.shouldAdvance else { return }
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
