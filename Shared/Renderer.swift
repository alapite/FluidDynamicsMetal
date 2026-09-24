//
//  Renderer.swift
//  FluidDynamicsMetal
//
//  Created by Andrei-Sergiu Pițiș on 20/12/2017.
//  Copyright © 2017 Andrei-Sergiu Pițiș. All rights reserved.
//

import MetalKit

typealias FloatTuple = (float2, float2, float2, float2, float2)
typealias ContactTuple = (float2, float2, float2, float2, float2, float2, float2, float2, float2, float2)

struct FluidContact {
    let position: float2
    let impulse: float2
}

struct StaticData {
    var positions: ContactTuple
    var impulses: ContactTuple

    var impulseScalar: float2
    var offsets: float2
    
    var screenSize: float2
    var inkRadius: simd_float1
}

struct VertexData {
    let position: float2
    let texCoord: float2
}

class Renderer: NSObject {
    static let MaxBuffers = 3
    static let ContactCapacity = 10

    //Adjust this to reduce or increase the size of the slab textures. Reasonable values are in the range [0.5, 3.0]
    static let ScreenScaleAdjustment: Float = 1.0

    //Vertex and index data
    static let vertexData: [VertexData] = [
        VertexData(position: float2(x: -1.0, y: -1.0), texCoord: float2(x: 0.0, y: 1.0)),
        VertexData(position: float2(x: 1.0, y: -1.0), texCoord: float2(x: 1.0, y: 1.0)),
        VertexData(position: float2(x: -1.0, y: 1.0), texCoord: float2(x: 0.0, y: 0.0)),
        VertexData(position: float2(x: 1.0, y: 1.0), texCoord: float2(x: 1.0, y: 0.0)),
        ]

    static let indices: [UInt16] = [2, 1, 0, 1, 2, 3]

    //Vertex and Index Metal buffers
    private let vertData = MetalDevice.sharedInstance.buffer(array: Renderer.vertexData, storageMode: [.storageModeShared])
    private let indexData = MetalDevice.sharedInstance.buffer(array: Renderer.indices, storageMode: [.storageModeShared])

    //Shaders
    private let applyForceVectorShader: RenderShader = RenderShader(fragmentShader: "applyForceVector", vertexShader: "vertexShader", pixelFormat: .rg16Float)
    private let applyForceScalarShader: RenderShader = RenderShader(fragmentShader: "applyForceScalar", vertexShader: "vertexShader", pixelFormat: .rg16Float)
    private let advectShader: RenderShader = RenderShader(fragmentShader: "advect", vertexShader: "vertexShader", pixelFormat: .rg16Float)
    private let divergenceShader: RenderShader = RenderShader(fragmentShader: "divergence", vertexShader: "vertexShader", pixelFormat: .rg16Float)
    private let jacobiShader: RenderShader = RenderShader(fragmentShader: "jacobi", vertexShader: "vertexShader", pixelFormat: .rg16Float)
    private let vorticityShader: RenderShader = RenderShader(fragmentShader: "vorticity", vertexShader: "vertexShader", pixelFormat: .rg16Float)
    private let vorticityConfinementShader: RenderShader = RenderShader(fragmentShader: "vorticityConfinement", vertexShader: "vertexShader", pixelFormat: .rg16Float)
    private let gradientShader: RenderShader = RenderShader(fragmentShader: "gradient", vertexShader: "vertexShader", pixelFormat: .rg16Float)

    private let renderVector: RenderShader = RenderShader(fragmentShader: "visualizeVector", vertexShader: "vertexShader")
    private let renderScalar: RenderShader = RenderShader(fragmentShader: "visualizeScalar", vertexShader: "vertexShader")

    //Touch or Mouse positions
    private var positions: FloatTuple?
    private var directions: FloatTuple?
    private var touchContacts: [FluidContact] = []
    private var touchRadius: Float?

    //Surfaces
    private var velocity: Slab!
    private var density: Slab!
    private var velocityDivergence: Slab!
    private var velocityVorticity: Slab!
    private var pressure: Slab!

    //Inflight buffers
    private var uniformsBuffers: [MTLBuffer] = []
    private var avaliableBufferIndex: Int = 0

    private let semaphore = DispatchSemaphore(value: MaxBuffers)

    //Index of the displayed slab
    private var currentIndex = 0

    init(metalView: MTKView) {
        super.init()
        metalView.device = MetalDevice.sharedInstance.device
        metalView.colorPixelFormat = .bgra8Unorm
        metalView.framebufferOnly = true
        metalView.preferredFramesPerSecond = 60

        mtkView(metalView, drawableSizeWillChange: metalView.drawableSize)
    }

    func nextSlab() {
        currentIndex = (currentIndex + 1) % 4
    }

    func updateInteraction(points: FloatTuple?, in view: MTKView) {
        touchContacts = []
        touchRadius = nil
        positions = points
        if points == nil { directions = nil }
    }

    func updateTouchInteraction(contacts: [FluidContact], in view: MTKView) {
        positions = nil
        directions = nil
        touchContacts = contacts
        let shortSide = max(1, min(view.bounds.width, view.bounds.height))
        let scale = Float(shortSide / 375)
        touchRadius = 150 * scale * scale
    }

    private final func initSurfaces(width: Int, height: Int) {
        velocity = Slab(width: width, height: height, format: .rg16Float, name: "Velocity")
        density = Slab(width: width, height: height, format: .rg16Float, name: "Density")
        velocityDivergence = Slab(width: width, height: height, format: .rg16Float, name: "Divergence")
        velocityVorticity = Slab(width: width, height: height, format: .rg16Float, name: "Vorticity")
        pressure = Slab(width: width, height: height, format: .rg16Float, name: "Pressure")
    }

    private final func initBuffers(width: Int, height: Int) {
        let bufferSize = MemoryLayout<StaticData>.stride

        var staticData = StaticData(positions: (float2(), float2(), float2(), float2(), float2(), float2(), float2(), float2(), float2(), float2()),
                                    impulses: (float2(), float2(), float2(), float2(), float2(), float2(), float2(), float2(), float2(), float2()),
                                    impulseScalar: float2(),
                                    offsets: float2(1.0/Float(width), 1.0/Float(height)),
                                    screenSize: float2(Float(width), Float(height)),
                                    inkRadius: 150 / Renderer.ScreenScaleAdjustment)

        uniformsBuffers.removeAll()
        for _ in 0..<Renderer.MaxBuffers {
            let buffer = MetalDevice.sharedInstance.device.makeBuffer(bytes: &staticData, length: bufferSize, options: .storageModeShared)!

            uniformsBuffers.append(buffer)
        }
    }

    private final func writeContacts(_ contacts: [FluidContact], to data: inout StaticData) {
        data.positions = (float2(), float2(), float2(), float2(), float2(), float2(), float2(), float2(), float2(), float2())
        data.impulses = (float2(), float2(), float2(), float2(), float2(), float2(), float2(), float2(), float2(), float2())
        data.impulseScalar = contacts.isEmpty ? float2() : float2(0.8, 0.0)
        withUnsafeMutableBytes(of: &data.positions) { bytes in
            let slots = bytes.bindMemory(to: float2.self)
            for (index, contact) in contacts.prefix(Renderer.ContactCapacity).enumerated() {
                slots[index] = contact.position / Renderer.ScreenScaleAdjustment
            }
        }
        withUnsafeMutableBytes(of: &data.impulses) { bytes in
            let slots = bytes.bindMemory(to: float2.self)
            for (index, contact) in contacts.prefix(Renderer.ContactCapacity).enumerated() {
                slots[index] = contact.impulse / Renderer.ScreenScaleAdjustment
            }
        }
        data.inkRadius = touchRadius ?? 150 / Renderer.ScreenScaleAdjustment
    }

    private final func nextBuffer(contacts: [FluidContact]) -> MTLBuffer {
        let buffer = uniformsBuffers[avaliableBufferIndex]
        let bufferData = buffer.contents().bindMemory(to: StaticData.self, capacity: 1)
        writeContacts(contacts, to: &bufferData.pointee)

        avaliableBufferIndex = (avaliableBufferIndex + 1) % Renderer.MaxBuffers
        return buffer
    }

    private final func drawSlab() -> Slab {
        switch currentIndex {
        case 1:
            return pressure
        case 2:
            return velocity
        case 3:
            return velocityVorticity
        default:
            return density
        }
    }
}

//Fluid dynamics step methods
extension Renderer {
    private final func advect(commandBuffer: MTLCommandBuffer, dataBuffer: MTLBuffer, velocity: Slab, source: Slab, destination: Slab) {
        advectShader.calculateWithCommandBuffer(buffer: commandBuffer, indices: indexData, count: Renderer.indices.count, texture: destination.pong) { (commandEncoder) in
            commandEncoder.setVertexBuffer(self.vertData, offset: 0, index: 0)
            commandEncoder.setFragmentTexture(velocity.ping, index: 0)
            commandEncoder.setFragmentTexture(source.ping, index: 1)

            commandEncoder.setFragmentBuffer(dataBuffer, offset: 0, index: 0)
        }

        destination.swap()
    }

    private final func applyForceVector(commandBuffer: MTLCommandBuffer, dataBuffer: MTLBuffer, destination: Slab) {
        applyForceVectorShader.calculateWithCommandBuffer(buffer: commandBuffer, indices: indexData, count: Renderer.indices.count, texture: destination.pong) { (commandEncoder) in
            commandEncoder.setVertexBuffer(self.vertData, offset: 0, index: 0)
            commandEncoder.setFragmentTexture(destination.ping, index: 0)

            commandEncoder.setFragmentBuffer(dataBuffer, offset: 0, index: 0)
        }

        destination.swap()
    }

    private final func applyForceScalar(commandBuffer: MTLCommandBuffer, dataBuffer: MTLBuffer, destination: Slab) {
        applyForceScalarShader.calculateWithCommandBuffer(buffer: commandBuffer, indices: indexData, count: Renderer.indices.count, texture: destination.pong) { (commandEncoder) in
            commandEncoder.setVertexBuffer(self.vertData, offset: 0, index: 0)
            commandEncoder.setFragmentTexture(destination.ping, index: 0)

            commandEncoder.setFragmentBuffer(dataBuffer, offset: 0, index: 0)
        }

        destination.swap()
    }

    private final func computeDivergence(commandBuffer: MTLCommandBuffer, dataBuffer: MTLBuffer, velocity: Slab, destination: Slab) {
        divergenceShader.calculateWithCommandBuffer(buffer: commandBuffer, indices: indexData, count: Renderer.indices.count, texture: destination.pong) { (commandEncoder) in
            commandEncoder.setVertexBuffer(self.vertData, offset: 0, index: 0)
            commandEncoder.setFragmentTexture(velocity.ping, index: 0)

            commandEncoder.setFragmentBuffer(dataBuffer, offset: 0, index: 0)
        }

        destination.swap()
    }

    private final func computePressure(commandBuffer: MTLCommandBuffer, dataBuffer: MTLBuffer, x: Slab, b: Slab, destination: Slab) {
        jacobiShader.calculateWithCommandBuffer(buffer: commandBuffer, indices: indexData, count: Renderer.indices.count, texture: destination.pong) { (commandEncoder) in
            commandEncoder.setVertexBuffer(self.vertData, offset: 0, index: 0)
            commandEncoder.setFragmentTexture(x.ping, index: 0)
            commandEncoder.setFragmentTexture(b.ping, index: 1)

            commandEncoder.setFragmentBuffer(dataBuffer, offset: 0, index: 0)
        }

        destination.swap()
    }

    private final func computeVorticity(commandBuffer: MTLCommandBuffer, dataBuffer: MTLBuffer, velocity: Slab, destination: Slab) {
        vorticityShader.calculateWithCommandBuffer(buffer: commandBuffer, indices: indexData, count: Renderer.indices.count, texture: destination.pong) { (commandEncoder) in
            commandEncoder.setVertexBuffer(self.vertData, offset: 0, index: 0)
            commandEncoder.setFragmentTexture(velocity.ping, index: 0)

            commandEncoder.setFragmentBuffer(dataBuffer, offset: 0, index: 0)
        }

        destination.swap()
    }

    private final func computeVorticityConfinement(commandBuffer: MTLCommandBuffer, dataBuffer: MTLBuffer, velocity: Slab, vorticity: Slab, destination: Slab) {
        vorticityConfinementShader.calculateWithCommandBuffer(buffer: commandBuffer, indices: indexData, count: Renderer.indices.count, texture: destination.pong) { (commandEncoder) in
            commandEncoder.setVertexBuffer(self.vertData, offset: 0, index: 0)
            commandEncoder.setFragmentTexture(velocity.ping, index: 0)
            commandEncoder.setFragmentTexture(vorticity.ping, index: 1)

            commandEncoder.setFragmentBuffer(dataBuffer, offset: 0, index: 0)
        }

        destination.swap()
    }

    private final func subtractGradient(commandBuffer: MTLCommandBuffer, dataBuffer: MTLBuffer, p: Slab, w: Slab, destination: Slab) {
        gradientShader.calculateWithCommandBuffer(buffer: commandBuffer, indices: indexData, count: Renderer.indices.count, texture: destination.pong) { (commandEncoder) in
            commandEncoder.setVertexBuffer(self.vertData, offset: 0, index: 0)
            commandEncoder.setFragmentTexture(p.ping, index: 0)
            commandEncoder.setFragmentTexture(w.ping, index: 1)

            commandEncoder.setFragmentBuffer(dataBuffer, offset: 0, index: 0)
        }

        destination.swap()
    }

    private final func render(commandBuffer: MTLCommandBuffer, destination: MTLTexture) {
        if currentIndex >= 2 {
            renderVector.calculateWithCommandBuffer(buffer: commandBuffer, indices: indexData, count: Renderer.indices.count, texture: destination) { (commandEncoder) in
                commandEncoder.setVertexBuffer(self.vertData, offset: 0, index: 0)
                commandEncoder.setFragmentTexture(self.drawSlab().ping, index: 0)
            }
        } else {
            renderScalar.calculateWithCommandBuffer(buffer: commandBuffer, indices: indexData, count: Renderer.indices.count, texture: destination) { (commandEncoder) in
                commandEncoder.setVertexBuffer(self.vertData, offset: 0, index: 0)
                commandEncoder.setFragmentTexture(self.drawSlab().ping, index: 0)
            }
        }
    }
}

extension Renderer: MTKViewDelegate {
    func draw(in view: MTKView) {
        semaphore.wait()
        let commandBuffer = MetalDevice.sharedInstance.newCommandBuffer()

        var contacts = touchContacts
        if let points = positions {
            let previous = directions ?? points
            let current = [points.0, points.1, points.2, points.3, points.4]
            let prior = [previous.0, previous.1, previous.2, previous.3, previous.4]
            contacts = current.enumerated().filter { $0.element.x != 0 || $0.element.y != 0 }.map {
                FluidContact(position: $0.element, impulse: $0.element - prior[$0.offset])
            }
        }
        let dataBuffer = nextBuffer(contacts: Array(contacts.prefix(Renderer.ContactCapacity)))

        commandBuffer.addCompletedHandler({ (commandBuffer) in
            self.semaphore.signal()
        })

        advect(commandBuffer: commandBuffer, dataBuffer: dataBuffer, velocity: velocity, source: velocity, destination: velocity)
        advect(commandBuffer: commandBuffer, dataBuffer: dataBuffer, velocity: velocity, source: density, destination: density)

        if !contacts.isEmpty {
            for start in stride(from: 0, to: contacts.count, by: Renderer.ContactCapacity) {
                let forceBuffer: MTLBuffer
                if start == 0 {
                    forceBuffer = dataBuffer
                } else {
                    var data = dataBuffer.contents().bindMemory(to: StaticData.self, capacity: 1).pointee
                    writeContacts(Array(contacts[start..<min(start + Renderer.ContactCapacity, contacts.count)]), to: &data)
                    forceBuffer = MetalDevice.sharedInstance.device.makeBuffer(bytes: &data, length: MemoryLayout<StaticData>.stride, options: .storageModeShared)!
                }
                applyForceVector(commandBuffer: commandBuffer, dataBuffer: forceBuffer, destination: velocity)
                applyForceScalar(commandBuffer: commandBuffer, dataBuffer: forceBuffer, destination: density)
            }
        }

        computeVorticity(commandBuffer: commandBuffer, dataBuffer: dataBuffer, velocity: velocity, destination: velocityVorticity)
        computeVorticityConfinement(commandBuffer: commandBuffer, dataBuffer: dataBuffer, velocity: velocity, vorticity: velocityVorticity, destination: velocity)

        computeDivergence(commandBuffer: commandBuffer, dataBuffer: dataBuffer, velocity: velocity, destination: velocityDivergence)

        for _ in 0..<40 {
            computePressure(commandBuffer: commandBuffer, dataBuffer: dataBuffer, x: pressure, b: velocityDivergence, destination: pressure)
        }

        subtractGradient(commandBuffer: commandBuffer, dataBuffer: dataBuffer, p: pressure, w: velocity, destination: velocity)

        if let drawable = view.currentDrawable {

            let nextTexture = drawable.texture
            render(commandBuffer: commandBuffer, destination: nextTexture)

            commandBuffer.present(drawable)
        }

        commandBuffer.commit()

        directions = positions
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        let width = Int(Float(view.bounds.width) / Renderer.ScreenScaleAdjustment)
        let height = Int(Float(view.bounds.height) / Renderer.ScreenScaleAdjustment)

        initSurfaces(width: width, height: height)
        initBuffers(width: width, height: height)
    }
}
