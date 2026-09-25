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
    var metalView: MTKView {
        return view as! MTKView
    }

    var eventMonitor: Any?

    override func viewDidLoad() {
        super.viewDidLoad()

        renderer = Renderer(metalView: metalView)
        metalView.delegate = renderer

        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) {
            self.keyDown(with: $0)
            return $0
        }
    }

    deinit {
        NSEvent.removeMonitor(eventMonitor as Any)
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
    }

    private func changePauseState() {
        renderer.togglePause()
        if mouseHeld { rebaseDrag = true }
    }
}
