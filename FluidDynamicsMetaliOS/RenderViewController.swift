//
//  RenderViewController.swift
//  FluidDynamicsMetal
//
//  Created by Andrei-Sergiu Pițiș on 19/08/2017.
//  Copyright © 2017 Andrei-Sergiu Pițiș. All rights reserved.
//

import UIKit
import MetalKit

let MaxBuffers = 3

class RenderViewController: UIViewController, UIGestureRecognizerDelegate {

    var renderer: Renderer!
    private var touchOrder: [UITouch] = []
    private var positions: [UITouch: CGPoint] = [:]
    private var previousPositions: [UITouch: CGPoint] = [:]
    private var startPositions: [UITouch: CGPoint] = [:]
    private var activeTouches: Set<UITouch> = []
    private var pendingHolds: [UITouch: DispatchWorkItem] = [:]
    private var lastCanvasSize: CGSize = .zero
    private let hud = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
    private let caption = UILabel()
    private let activeSummary = UILabel()
    private let fieldStack = UIStackView()
    private let fieldScroll = UIScrollView()
    private let pauseButton = UIButton(type: .system)
    private var fieldButtons: [DisplayField: UIButton] = [:]
    private var hudWidth: NSLayoutConstraint?
    private var hudHeight: NSLayoutConstraint?
    private var fieldColumns = 0
    var metalView: MTKView {
        return view as! MTKView
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        renderer = Renderer(metalView: metalView)
        metalView.delegate = renderer

        metalView.isMultipleTouchEnabled = true

        installControls()

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

    private func installControls() {
        hud.translatesAutoresizingMaskIntoConstraints = false
        hud.layer.cornerRadius = 12
        hud.clipsToBounds = true
        metalView.addSubview(hud)

        caption.text = "View"
        caption.font = .preferredFont(forTextStyle: .caption1)
        caption.adjustsFontForContentSizeCategory = true
        caption.textColor = .secondaryLabel
        activeSummary.font = .preferredFont(forTextStyle: .caption1)
        activeSummary.adjustsFontForContentSizeCategory = true
        activeSummary.textColor = .label
        activeSummary.isHidden = true

        fieldStack.axis = .vertical
        fieldStack.spacing = 8
        fieldStack.isAccessibilityElement = false
        fieldStack.accessibilityLabel = "Display field"
        for field in DisplayField.allCases {
            let button = UIButton(type: .system)
            button.tag = field.rawValue
            button.titleLabel?.font = .preferredFont(forTextStyle: .subheadline)
            button.titleLabel?.adjustsFontForContentSizeCategory = true
            button.titleLabel?.numberOfLines = 0
            button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
            button.backgroundColor = .secondarySystemBackground
            button.layer.cornerRadius = 8
            button.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
            button.addTarget(self, action: #selector(selectField(_:)), for: .touchUpInside)
            fieldButtons[field] = button
        }
        fieldScroll.translatesAutoresizingMaskIntoConstraints = false
        fieldScroll.addSubview(fieldStack)
        fieldStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            fieldStack.leadingAnchor.constraint(equalTo: fieldScroll.contentLayoutGuide.leadingAnchor),
            fieldStack.trailingAnchor.constraint(equalTo: fieldScroll.contentLayoutGuide.trailingAnchor),
            fieldStack.topAnchor.constraint(equalTo: fieldScroll.contentLayoutGuide.topAnchor),
            fieldStack.bottomAnchor.constraint(equalTo: fieldScroll.contentLayoutGuide.bottomAnchor),
            fieldStack.widthAnchor.constraint(equalTo: fieldScroll.frameLayoutGuide.widthAnchor)
        ])

        pauseButton.titleLabel?.font = .preferredFont(forTextStyle: .subheadline)
        pauseButton.titleLabel?.adjustsFontForContentSizeCategory = true
        pauseButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        pauseButton.addTarget(self, action: #selector(pauseFromHUD(_:)), for: .touchUpInside)

        let content = UIStackView(arrangedSubviews: [caption, activeSummary, fieldScroll, pauseButton])
        content.axis = .vertical
        content.spacing = 8
        content.translatesAutoresizingMaskIntoConstraints = false
        hud.contentView.addSubview(content)
        hudWidth = hud.widthAnchor.constraint(equalToConstant: 300)
        hudHeight = hud.heightAnchor.constraint(equalToConstant: 208)
        let safe = metalView.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            hud.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -16),
            hud.bottomAnchor.constraint(equalTo: safe.bottomAnchor, constant: -16),
            hud.leadingAnchor.constraint(greaterThanOrEqualTo: safe.leadingAnchor, constant: 16),
            hud.topAnchor.constraint(greaterThanOrEqualTo: safe.topAnchor, constant: 16),
            hudWidth!, hudHeight!,
            content.leadingAnchor.constraint(equalTo: hud.contentView.leadingAnchor, constant: 16),
            content.trailingAnchor.constraint(equalTo: hud.contentView.trailingAnchor, constant: -16),
            content.topAnchor.constraint(equalTo: hud.contentView.topAnchor, constant: 16),
            content.bottomAnchor.constraint(equalTo: hud.contentView.bottomAnchor, constant: -16)
        ])
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
        hud.effect = UIAccessibility.isReduceTransparencyEnabled ? nil : UIBlurEffect(style: .systemMaterial)
        hud.backgroundColor = UIAccessibility.isReduceTransparencyEnabled ? .systemBackground : .clear
    }

    @objc private func updateTextSize() {
        caption.font = .preferredFont(forTextStyle: .caption1)
        activeSummary.font = .preferredFont(forTextStyle: .caption1)
        refreshControls()
    }

    private func updateControlLayout() {
        let safe = metalView.safeAreaLayoutGuide.layoutFrame
        guard safe.width > 32, safe.height > 32 else { return }
        let width = safe.width - 32
        let height = safe.height - 32
        let font = UIFont.preferredFont(forTextStyle: .subheadline)
        let buttonWidth = DisplayField.allCases.map {
            ("✓ \(fieldTitle($0))" as NSString).size(withAttributes: [.font: font]).width + 32
        }.max() ?? 120
        let columns = width >= 4 * buttonWidth + 24 + 32 && height < 280 ? 4 : (width >= 2 * buttonWidth + 8 + 32 ? 2 : 1)
        if columns != fieldColumns {
            fieldColumns = columns
            for row in fieldStack.arrangedSubviews { fieldStack.removeArrangedSubview(row); row.removeFromSuperview() }
            let fields = DisplayField.allCases
            for index in stride(from: 0, to: fields.count, by: columns) {
                let row = UIStackView(arrangedSubviews: Array(fields[index..<min(index + columns, fields.count)]).compactMap { fieldButtons[$0] })
                row.axis = .horizontal
                row.distribution = .fillEqually
                row.spacing = 8
                fieldStack.addArrangedSubview(row)
            }
        }
        let fieldHeight = CGFloat((4 + columns - 1) / columns) * max(44, font.lineHeight + 16) + CGFloat((4 + columns - 1) / columns - 1) * 8
        let compactHeight = height < fieldHeight + 44 + 32 + 16 + caption.intrinsicContentSize.height
        let needsScroll = height < fieldHeight + 44 + 32 + (compactHeight ? 8 : 16) + (compactHeight ? 0 : caption.intrinsicContentSize.height)
        caption.isHidden = compactHeight
        activeSummary.isHidden = !needsScroll
        activeSummary.text = "View: \(fieldTitle(renderer.state.field))"
        fieldScroll.isScrollEnabled = needsScroll
        let desiredWidth = CGFloat(columns) * buttonWidth + CGFloat(columns - 1) * 8 + 32
        let newWidth = min(width, max(desiredWidth, 192))
        let newHeight = min(height, fieldHeight + 44 + 32 + (compactHeight ? 8 : 16) + (compactHeight ? 0 : caption.intrinsicContentSize.height) + (needsScroll ? activeSummary.intrinsicContentSize.height + 8 : 0))
        if hudWidth?.constant != newWidth { hudWidth?.constant = newWidth }
        if hudHeight?.constant != newHeight { hudHeight?.constant = newHeight }
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
        pauseButton.setTitle(renderer.state.userPaused ? "Resume" : "Pause", for: .normal)
        pauseButton.accessibilityLabel = renderer.state.userPaused ? "Resume simulation" : "Pause simulation"
        updateControlLayout()
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
        guard renderer.state.shouldAdvance else { return }
        for touch in touches where !isHUDTouch(touch) {
            if positions[touch] == nil {
                touchOrder.append(touch)
            }
            let location = touch.location(in: metalView)
            positions[touch] = location
            previousPositions[touch] = location
            startPositions[touch] = location
            let hold = DispatchWorkItem { [weak self, weak touch] in
                guard let self = self, let touch = touch, self.positions[touch] != nil, self.renderer.state.shouldAdvance else { return }
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
        guard renderer.state.shouldAdvance else { return }
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
        guard renderer.state.shouldAdvance else { renderer.clearInput(); return }
        let contacts = touchOrder.compactMap { touch -> FluidContact? in
            guard activeTouches.contains(touch) else { return nil }
            guard let location = positions[touch] else { return nil }
            let previous = previousPositions[touch] ?? location
            return FluidContact(position: float2(Float(location.x), Float(location.y)),
                                impulse: float2(Float(location.x - previous.x), Float(location.y - previous.y)))
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
        guard renderer.state.shouldAdvance else { return }
        let point = recognizer.location(in: metalView)
        guard !hud.bounds.contains(recognizer.location(in: hud)) else { return }
        renderer.enqueueTap(at: float2(Float(point.x), Float(point.y)), in: metalView)
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
