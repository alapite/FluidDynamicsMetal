//
//  Renderer.swift
//  FluidDynamicsMetal
//
//  Created by Andrei-Sergiu Pițiș on 20/12/2017.
//  Copyright © 2017 Andrei-Sergiu Pițiș. All rights reserved.
//

import MetalKit

typealias ContactTuple = (SIMD2<Float>, SIMD2<Float>, SIMD2<Float>, SIMD2<Float>, SIMD2<Float>, SIMD2<Float>, SIMD2<Float>, SIMD2<Float>, SIMD2<Float>, SIMD2<Float>)

struct FluidContact {
    let position: SIMD2<Float>
    let impulse: SIMD2<Float>
}

struct MouseInputState {
    private var position: SIMD2<Float>?
    private var previousFramePosition: SIMD2<Float>?

    mutating func update(position: SIMD2<Float>?) {
        self.position = position
        if position == nil { previousFramePosition = nil }
    }

    mutating func clear() {
        position = nil
        previousFramePosition = nil
    }

    mutating func contactForFrame() -> FluidContact? {
        guard let position else { return nil }
        let impulse = position - (previousFramePosition ?? position)
        previousFramePosition = position
        return FluidContact(position: position, impulse: impulse)
    }
}

// GPU ABI: matches BufferData in Shaders.metal (208-byte stride, 16-byte alignment).
// RendererContactTests locks member offsets and the packed ten-contact tuples.
struct StaticData {
    var positions: ContactTuple
    var impulses: ContactTuple

    var impulseScalar: SIMD2<Float>
    var offsets: SIMD2<Float>
    
    var screenSize: SIMD2<Float>
    var inkRadius: simd_float1
    var tuning: simd_float4
}

struct VertexData: BitwiseCopyable {
    let position: SIMD2<Float>
    let texCoord: SIMD2<Float>
}

@MainActor
class Renderer: NSObject {
    static let MaxBuffers = 3
    nonisolated static let ContactCapacity = 10

    //Adjust this to reduce or increase the size of the slab textures. Reasonable values are in the range [0.5, 3.0]
    nonisolated static let ScreenScaleAdjustment: Float = 1.0

    //Vertex and index data
    static let vertexData: [VertexData] = [
        VertexData(position: SIMD2<Float>(x: -1.0, y: -1.0), texCoord: SIMD2<Float>(x: 0.0, y: 1.0)),
        VertexData(position: SIMD2<Float>(x: 1.0, y: -1.0), texCoord: SIMD2<Float>(x: 1.0, y: 1.0)),
        VertexData(position: SIMD2<Float>(x: -1.0, y: 1.0), texCoord: SIMD2<Float>(x: 0.0, y: 0.0)),
        VertexData(position: SIMD2<Float>(x: 1.0, y: 1.0), texCoord: SIMD2<Float>(x: 1.0, y: 0.0)),
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
    private let resampleShader: RenderShader = RenderShader(fragmentShader: "resampleField", vertexShader: "vertexShader", pixelFormat: .rg16Float)

    private let renderVector: RenderShader = RenderShader(fragmentShader: "visualizeVector", vertexShader: "vertexShader")
    private let renderScalar: RenderShader = RenderShader(fragmentShader: "visualizeScalar", vertexShader: "vertexShader")

    //Touch or Mouse positions
    private var mouseInput = MouseInputState()
    private var touchContacts: [FluidContact] = []
    private var pendingTapContacts: [FluidContact] = []
    private var touchRadius: Float?

    //Surfaces
    private var velocity: Slab!
    private var density: Slab!
    private var velocityDivergence: Slab!
    private var velocityVorticity: Slab!
    private var pressure: Slab!
    private var gridWidth = 0
    private var gridHeight = 0

    //Inflight buffers
    private var uniformsBuffers: [MTLBuffer] = []
    private var avaliableBufferIndex: Int = 0

    private let semaphore = DispatchSemaphore(value: MaxBuffers)

    private(set) var state = SimulationState()
    private weak var metalView: MTKView?

    init(metalView: MTKView) {
        super.init()
        self.metalView = metalView
        metalView.device = MetalDevice.sharedInstance.device
        metalView.colorPixelFormat = .bgra8Unorm
        metalView.framebufferOnly = true
        metalView.preferredFramesPerSecond = 60

        mtkView(metalView, drawableSizeWillChange: metalView.drawableSize)
    }

    func nextSlab() {
        state.nextField()
        if !state.shouldAdvance && !state.inactive { metalView?.draw() }
    }

    func selectField(_ field: DisplayField) {
        state.selectField(field)
        if !state.shouldAdvance && !state.inactive { metalView?.draw() }
    }

    func togglePause() {
        state.togglePause()
        clearInput()
        metalView?.isPaused = !state.shouldAdvance
    }

    func setTuningPosition(_ position: Float, for control: TuningControl) {
        state.tuning.setPosition(position, for: control)
    }

    func resignActive() {
        state.resignActive()
        clearInput()
        metalView?.isPaused = true
    }

    func becomeActive() {
        state.becomeActive()
        metalView?.isPaused = !state.shouldAdvance
        if !state.shouldAdvance { metalView?.draw() }
    }

    func clearInput() {
        mouseInput.clear()
        touchContacts.removeAll()
        pendingTapContacts.removeAll()
        touchRadius = nil
    }

    func updateMouseInteraction(position: SIMD2<Float>?, in view: MTKView) {
        guard state.shouldAdvance else { clearInput(); return }
        touchContacts = []
        touchRadius = nil
        mouseInput.update(position: position)
    }

    func updateTouchInteraction(contacts: [FluidContact], in view: MTKView) {
        guard state.shouldAdvance else { clearInput(); return }
        mouseInput.clear()
        touchContacts = contacts
        let shortSide = max(1, min(view.bounds.width, view.bounds.height))
        let scale = Float(shortSide / 375)
        touchRadius = 150 * scale * scale
    }

    func enqueueTap(at position: SIMD2<Float>, in view: MTKView) {
        guard state.shouldAdvance else { return }
        // Keep the splat until draw consumes it; recognizer callbacks can precede the next frame.
        pendingTapContacts.append(FluidContact(position: position, impulse: SIMD2<Float>()))
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

        var staticData = StaticData(positions: (SIMD2<Float>(), SIMD2<Float>(), SIMD2<Float>(), SIMD2<Float>(), SIMD2<Float>(), SIMD2<Float>(), SIMD2<Float>(), SIMD2<Float>(), SIMD2<Float>(), SIMD2<Float>()),
                                    impulses: (SIMD2<Float>(), SIMD2<Float>(), SIMD2<Float>(), SIMD2<Float>(), SIMD2<Float>(), SIMD2<Float>(), SIMD2<Float>(), SIMD2<Float>(), SIMD2<Float>(), SIMD2<Float>()),
                                    impulseScalar: SIMD2<Float>(),
                                    offsets: SIMD2<Float>(1.0/Float(width), 1.0/Float(height)),
                                    screenSize: SIMD2<Float>(Float(width), Float(height)),
                                     inkRadius: 150 / Renderer.ScreenScaleAdjustment,
                                     tuning: simd_float4(state.tuning.retention, state.tuning.swirl, 0, 0))

        uniformsBuffers.removeAll()
        for _ in 0..<Renderer.MaxBuffers {
            let buffer = MetalDevice.sharedInstance.device.makeBuffer(bytes: &staticData, length: bufferSize, options: .storageModeShared)!

            uniformsBuffers.append(buffer)
        }
    }

    nonisolated static func contactBatches(_ contacts: [FluidContact]) -> [[FluidContact]] {
        return stride(from: 0, to: contacts.count, by: ContactCapacity).map {
            Array(contacts[$0..<min($0 + ContactCapacity, contacts.count)])
        }
    }

    nonisolated static func writeContacts(_ contacts: [FluidContact], tuning: SimulationTuning, radius: Float, to data: inout StaticData) {
        data.positions = (SIMD2<Float>(), SIMD2<Float>(), SIMD2<Float>(), SIMD2<Float>(), SIMD2<Float>(), SIMD2<Float>(), SIMD2<Float>(), SIMD2<Float>(), SIMD2<Float>(), SIMD2<Float>())
        data.impulses = (SIMD2<Float>(), SIMD2<Float>(), SIMD2<Float>(), SIMD2<Float>(), SIMD2<Float>(), SIMD2<Float>(), SIMD2<Float>(), SIMD2<Float>(), SIMD2<Float>(), SIMD2<Float>())
        data.impulseScalar = contacts.isEmpty ? SIMD2<Float>() : SIMD2<Float>(tuning.dye, 0.0)
        withUnsafeMutableBytes(of: &data.positions) { bytes in
            let slots = bytes.bindMemory(to: SIMD2<Float>.self)
            for (index, contact) in contacts.prefix(Renderer.ContactCapacity).enumerated() {
                // Zero is the shader's unused-slot sentinel; preserve a contact at the origin.
                let position = contact.position.x == 0 && contact.position.y == 0 ? SIMD2<Float>(0.01, 0.01) : contact.position
                slots[index] = position / Renderer.ScreenScaleAdjustment
            }
        }
        withUnsafeMutableBytes(of: &data.impulses) { bytes in
            let slots = bytes.bindMemory(to: SIMD2<Float>.self)
            for (index, contact) in contacts.prefix(Renderer.ContactCapacity).enumerated() {
                slots[index] = contact.impulse * tuning.force / Renderer.ScreenScaleAdjustment
            }
        }
        data.inkRadius = radius
    }

    private final func nextBuffer(contacts: [FluidContact], tuning: SimulationTuning) -> MTLBuffer {
        let buffer = uniformsBuffers[avaliableBufferIndex]
        let bufferData = buffer.contents().bindMemory(to: StaticData.self, capacity: 1)
        bufferData.pointee.tuning = simd_float4(tuning.retention, tuning.swirl, 0, 0)
        Renderer.writeContacts(contacts, tuning: tuning,
                               radius: touchRadius ?? 150 / Renderer.ScreenScaleAdjustment,
                               to: &bufferData.pointee)

        avaliableBufferIndex = (avaliableBufferIndex + 1) % Renderer.MaxBuffers
        return buffer
    }

    private final func drawSlab() -> Slab {
        switch state.field {
        case .pressure:
            return pressure
        case .velocity:
            return velocity
        case .vorticity:
            return velocityVorticity
        case .density:
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
        if state.field == .velocity || state.field == .vorticity {
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

// Rendering and input share the main actor; GPU completion only signals the semaphore.
extension Renderer: @MainActor MTKViewDelegate {
    func draw(in view: MTKView) {
        semaphore.wait()
        let commandBuffer = MetalDevice.sharedInstance.newCommandBuffer()

        // Metal invokes completion handlers off the main actor. Capture only the
        // thread-safe semaphore so GPU completion never accesses renderer state.
        commandBuffer.addCompletedHandler { [semaphore] _ in semaphore.signal() }

        guard state.shouldAdvance else {
            clearInput()
            if let drawable = view.currentDrawable, density != nil {
                render(commandBuffer: commandBuffer, destination: drawable.texture)
                commandBuffer.present(drawable)
            }
            commandBuffer.commit()
            return
        }

        let tuning = state.tuning
        var contacts = touchContacts
        contacts.append(contentsOf: pendingTapContacts)
        pendingTapContacts.removeAll()
        if let contact = mouseInput.contactForFrame() {
            contacts = [contact]
        }
        let batches = Renderer.contactBatches(contacts)
        let dataBuffer = nextBuffer(contacts: batches.first ?? [], tuning: tuning)

        advect(commandBuffer: commandBuffer, dataBuffer: dataBuffer, velocity: velocity, source: velocity, destination: velocity)
        advect(commandBuffer: commandBuffer, dataBuffer: dataBuffer, velocity: velocity, source: density, destination: density)

        if !batches.isEmpty {
            for (batchIndex, batch) in batches.enumerated() {
                let forceBuffer: MTLBuffer
                if batchIndex == 0 {
                    forceBuffer = dataBuffer
                } else {
                    var data = dataBuffer.contents().bindMemory(to: StaticData.self, capacity: 1).pointee
                    Renderer.writeContacts(batch, tuning: tuning,
                                           radius: touchRadius ?? 150 / Renderer.ScreenScaleAdjustment,
                                           to: &data)
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

    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        guard view.bounds.width.isFinite, view.bounds.height.isFinite,
              view.bounds.width > 0, view.bounds.height > 0 else { return }
        let width = Int(Float(view.bounds.width) / Renderer.ScreenScaleAdjustment)
        let height = Int(Float(view.bounds.height) / Renderer.ScreenScaleAdjustment)
        guard width > 0, height > 0, width != gridWidth || height != gridHeight else { return }

        // Draw completion returns each permit; taking all three keeps both texture and
        // uniform-buffer replacement off any frame still in flight on the serial queue.
        for _ in 0..<Renderer.MaxBuffers { semaphore.wait() }
        do {
        defer { for _ in 0..<Renderer.MaxBuffers { semaphore.signal() } }

        let newVelocity = Slab(width: width, height: height, format: .rg16Float, name: "Velocity")
        let newDensity = Slab(width: width, height: height, format: .rg16Float, name: "Density")
        let newDivergence = Slab(width: width, height: height, format: .rg16Float, name: "Divergence")
        let newVorticity = Slab(width: width, height: height, format: .rg16Float, name: "Vorticity")
        let newPressure = Slab(width: width, height: height, format: .rg16Float, name: "Pressure")

        if gridWidth > 0, let oldVelocity = velocity {
            let command = MetalDevice.sharedInstance.newCommandBuffer()
            let pairs: [(Slab, Slab, SIMD2<Float>)] = [
                (oldVelocity, newVelocity, SIMD2<Float>(Float(width) / Float(gridWidth), Float(height) / Float(gridHeight))),
                (density, newDensity, SIMD2<Float>(1, 1)),
                (velocityDivergence, newDivergence, SIMD2<Float>(1, 1)),
                (velocityVorticity, newVorticity, SIMD2<Float>(1, 1)),
                (pressure, newPressure, SIMD2<Float>(1, 1))
            ]
            for (source, destination, scale) in pairs {
                var factors = scale
                resampleShader.calculateWithCommandBuffer(buffer: command, indices: indexData, count: Renderer.indices.count, texture: destination.ping) { encoder in
                    encoder.setVertexBuffer(self.vertData, offset: 0, index: 0)
                    encoder.setFragmentTexture(source.ping, index: 0)
                    encoder.setFragmentBytes(&factors, length: MemoryLayout<SIMD2<Float>>.stride, index: 0)
                }
            }
            command.commit()
            command.waitUntilCompleted()
            guard command.status == .completed else {
                print("Fluid resize failed: \(command.error?.localizedDescription ?? "unknown GPU error")")
                return
            }
        } else {
            let command = MetalDevice.sharedInstance.newCommandBuffer()
            command.label = "Initialize fluid fields"
            Slab.clearInitialFields([newVelocity.ping, newDensity.ping, newDivergence.ping,
                                     newVorticity.ping, newPressure.ping], commandBuffer: command)
            command.commit()
            command.waitUntilCompleted()
            guard command.status == .completed else {
                fatalError("Fluid initialization failed: \(command.error?.localizedDescription ?? "unknown GPU error")")
            }
        }
        velocity = newVelocity
        density = newDensity
        velocityDivergence = newDivergence
        velocityVorticity = newVorticity
        pressure = newPressure
        gridWidth = width
        gridHeight = height
        clearInput()
        initBuffers(width: width, height: height)
        }
        if !state.shouldAdvance && !state.inactive { view.draw() }
    }
}
