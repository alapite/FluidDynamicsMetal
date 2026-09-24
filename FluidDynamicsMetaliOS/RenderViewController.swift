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
        for touch in touches {
            if positions[touch] == nil {
                touchOrder.append(touch)
            }
            let location = touch.location(in: metalView)
            positions[touch] = location
            previousPositions[touch] = location
        }
        submitTouches()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches where positions[touch] != nil {
            previousPositions[touch] = positions[touch]
            positions[touch] = touch.location(in: metalView)
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
            positions.removeValue(forKey: touch)
            previousPositions.removeValue(forKey: touch)
        }
        touchOrder.removeAll { touches.contains($0) }
        submitTouches()
    }

    private func submitTouches() {
        let contacts = touchOrder.compactMap { touch -> FluidContact? in
            guard let location = positions[touch] else { return nil }
            let previous = previousPositions[touch] ?? location
            return FluidContact(position: float2(Float(location.x), Float(location.y)),
                                impulse: float2(Float(location.x - previous.x), Float(location.y - previous.y)))
        }
        renderer.updateTouchInteraction(contacts: contacts, in: metalView)
    }

    @objc func changeSource() {
        renderer.nextSlab()
    }

    @objc final func doubleTap() {
        metalView.isPaused = !metalView.isPaused
    }

    @objc final func willResignActive() {
        metalView.isPaused = true
    }

    @objc final func didBecomeActive() {
        metalView.isPaused = false
    }
}
