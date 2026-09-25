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

class RenderViewController: UIViewController {

    var renderer: Renderer!
    private var touchOrder: [UITouch] = []
    private var positions: [UITouch: CGPoint] = [:]
    private var previousPositions: [UITouch: CGPoint] = [:]
    private var startPositions: [UITouch: CGPoint] = [:]
    private var activeTouches: Set<UITouch> = []
    private var pendingHolds: [UITouch: DispatchWorkItem] = [:]
    var metalView: MTKView {
        return view as! MTKView
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        renderer = Renderer(metalView: metalView)
        metalView.delegate = renderer

        metalView.isMultipleTouchEnabled = true

        let doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(doubleTap))
        doubleTapGesture.numberOfTapsRequired = 2
        doubleTapGesture.numberOfTouchesRequired = 1
        view.addGestureRecognizer(doubleTapGesture)

        let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(changeSource))
        gestureRecognizer.numberOfTapsRequired = 2
        gestureRecognizer.numberOfTouchesRequired = 2
        view.addGestureRecognizer(gestureRecognizer)

        // A two-finger shortcut takes precedence over a one-finger double tap.
        doubleTapGesture.require(toFail: gestureRecognizer)
        let singleTapGesture = UITapGestureRecognizer(target: self, action: #selector(singleTap(_:)))
        singleTapGesture.require(toFail: doubleTapGesture)
        singleTapGesture.require(toFail: gestureRecognizer)
        view.addGestureRecognizer(singleTapGesture)

        NotificationCenter.default.addObserver(self, selector: #selector(willResignActive), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(didBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()

        print("Got Memory Warning")
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard renderer.state.shouldAdvance else { return }
        for touch in touches {
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
    }

    @objc final func doubleTap() {
        guard !renderer.state.inactive else { return }
        cancelPendingHolds()
        clearTouches()
        renderer.togglePause()
    }

    @objc private func singleTap(_ recognizer: UITapGestureRecognizer) {
        guard renderer.state.shouldAdvance else { return }
        let point = recognizer.location(in: metalView)
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
    }
}
