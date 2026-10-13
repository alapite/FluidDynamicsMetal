import MetalKit

@MainActor
final class Renderer: NSObject, MTKViewDelegate {
    static let MaxBuffers = 3
    nonisolated static let ContactCapacity = 10
    nonisolated static let ScreenScaleAdjustment: Float = 1
    private let semaphore = DispatchSemaphore(value: MaxBuffers)
    private let metal: MetalDevice
    private weak var metalView: MTKView?
    private(set) var simulation: FluidSimulation!
    private(set) var state = SimulationState()
    var stateDidChange: (() -> Void)?
    /// Point-space rectangle available to a lesson; iOS reserves controls outside this area.
    var lessonAvailableRect: CGRect? { didSet { redrawIfPaused() } }
    private var mouseInput = MouseInputState()
    private var touchContacts: [FluidContact] = []
    private var pendingTapContacts: [FluidContact] = []
    private var touchRadius: Float?
    private var stepDrainScheduled = false
    private let visualization: FieldVisualization

    init(metalView: MTKView, metal: MetalDevice = .sharedInstance) {
        self.metal = metal
        visualization = FieldVisualization(metal: metal)
        super.init()
        self.metalView = metalView
        metalView.device = metal.device
        metalView.colorPixelFormat = .bgra8Unorm
        metalView.framebufferOnly = true
        metalView.preferredFramesPerSecond = 60
        replaceSimulation(reset: true)
    }
    func nextSlab() { state.nextField(); redrawIfPaused(); stateDidChange?() }
    func selectField(_ field: DisplayField) { state.selectField(field); redrawIfPaused(); stateDidChange?() }
    func setDisplayOptions(_ options: DisplayOptions) { state.setDisplayOptions(options); redrawIfPaused(); stateDidChange?() }
    func togglePause() { state.togglePause(); clearInput(); updateScheduling(); stateDidChange?() }
    func setTuningPosition(_ position: Float, for control: TuningControl) {
        guard state.mode == .freePlay else { return }
        state.tuning.setPosition(position, for: control)
    }
    func selectMode(_ mode: SimulationMode) { state.selectMode(mode); replaceSimulation(reset: true); stateDidChange?() }
    func setExperimentAdjustment(_ adjustment: ExperimentAdjustment) {
        guard state.setExperimentAdjustment(adjustment) else { return }
        replaceSimulation(reset: true); stateDidChange?()
    }
    func restartCurrentSimulation() { state.beginReset(); replaceSimulation(reset: true); stateDidChange?() }
    func requestSingleStep() {
        guard state.requestSingleStep() else { return }
        scheduleStepDrain()
    }
    private func scheduleStepDrain() {
        guard !stepDrainScheduled, state.pendingSteps > 0 else { return }
        stepDrainScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.stepDrainScheduled = false
            if self.state.pendingSteps > 0, let view = self.metalView { self.draw(in: view) }
            self.scheduleStepDrain()
        }
    }
    func resignActive() { state.resignActive(); clearInput(); updateScheduling(); stateDidChange?() }
    func becomeActive() { state.becomeActive(); updateScheduling(); redrawIfPaused(); stateDidChange?() }
    private func updateScheduling() { metalView?.isPaused = !state.shouldAdvance }
    private func redrawIfPaused() {
        guard !state.shouldAdvance, !state.inactive, !state.resetting, simulation != nil else { return }
        metalView?.draw()
    }
    func clearInput() { mouseInput.clear(); touchContacts.removeAll(); pendingTapContacts.removeAll(); touchRadius = nil }
    func updateMouseInteraction(position: SIMD2<Float>?, in view: MTKView) {
        guard state.acceptsInput else { clearInput(); return }
        touchContacts = []; touchRadius = nil; mouseInput.update(position: position)
    }
    func updateTouchInteraction(contacts: [FluidContact], in view: MTKView) {
        guard state.acceptsInput else { clearInput(); return }
        mouseInput.clear(); touchContacts = contacts
        let scale = Float(max(1, min(view.bounds.width, view.bounds.height)) / 375)
        touchRadius = 150 * scale * scale
    }
    func enqueueTap(at position: SIMD2<Float>, in view: MTKView) {
        guard state.acceptsInput else { return }
        pendingTapContacts.append(FluidContact(position: position, impulse: .zero))
        let scale = Float(max(1, min(view.bounds.width, view.bounds.height)) / 375)
        touchRadius = 150 * scale * scale
    }
    private func replaceSimulation(reset: Bool) {
        guard let view = metalView else { return }
        let width = state.mode.experiment == nil ? max(1, Int(view.bounds.width)) : ExperimentRecipes.gridSize
        let height = state.mode.experiment == nil ? max(1, Int(view.bounds.height)) : ExperimentRecipes.gridSize
        if !reset, simulation?.width == width, simulation?.height == height { return }
        for _ in 0..<Self.MaxBuffers { semaphore.wait() }
        let old = simulation
        let next = FluidSimulation(width: width, height: height, metal: metal)
        let command = metal.newCommandBuffer()
        if !reset, let old { next.encodeResample(from: old, command: command) }
        else { next.encodeReset(command: command, mode: state.mode, adjustment: state.adjustment) }
        command.commit(); command.waitUntilCompleted()
        precondition(command.status == .completed, "Fluid resource replacement failed: \(String(describing: command.error))")
        simulation = next
        clearInput()
        state.finishReset()
        for _ in 0..<Self.MaxBuffers { semaphore.signal() }
        updateScheduling(); redrawIfPaused()
    }
    func viewport(in view: MTKView) -> MTLViewport {
        let scaleX = view.drawableSize.width / max(1, view.bounds.width)
        let scaleY = view.drawableSize.height / max(1, view.bounds.height)
        var rect = view.bounds
        if state.mode.experiment != nil {
            let available = lessonAvailableRect ?? view.bounds
            let side = max(1, min(available.width, available.height))
            rect = CGRect(x: available.midX - side / 2, y: available.midY - side / 2, width: side, height: side)
        }
        return MTLViewport(originX: rect.minX * scaleX, originY: rect.minY * scaleY,
                           width: rect.width * scaleX, height: rect.height * scaleY, znear: 0, zfar: 1)
    }
    private func render(command: MTLCommandBuffer, drawable: CAMetalDrawable, view: MTKView) {
        let viewport = viewport(in: view)
        visualization.encodeField(command: command, simulation: simulation, destination: drawable.texture, viewport: viewport, field: state.field)
        let scale = Float(view.drawableSize.width / max(1, view.bounds.width))
        let pointSize = SIMD2<Float>(Float(viewport.width) / scale, Float(viewport.height) / scale)
        if state.displayOptions.particles {
            simulation.particles.encodeDisplay(command: command, destination: drawable.texture, viewport: viewport, pointSize: pointSize, trails: state.displayOptions.trails)
        }
        if state.displayOptions.arrows || state.field == .velocity {
            visualization.encodeArrows(command: command, simulation: simulation, destination: drawable.texture, viewport: viewport,
                                       pointSize: SIMD2<Float>(Float(viewport.width) / scale, Float(viewport.height) / scale))
        }
    }

    func draw(in view: MTKView) {
        guard !state.inactive, !state.resetting, simulation != nil else { return }
        semaphore.wait()
        let command = metal.newCommandBuffer()
        command.addCompletedHandler { [semaphore] _ in semaphore.signal() }
        let step = state.stepCount
        if state.consumeStep() {
            var contacts = touchContacts + pendingTapContacts; pendingTapContacts.removeAll()
            if let mouse = mouseInput.contactForFrame() { contacts = [mouse] }
            simulation.encodeStep(command: command, tuning: state.tuning, contacts: contacts, radius: touchRadius,
                                  mode: state.mode, adjustment: state.adjustment, step: step)
        } else { clearInput() }
        if let drawable = view.currentDrawable {
            render(command: command, drawable: drawable, view: view); command.present(drawable)
        }
        command.commit()
        updateScheduling()
        // Live counters refresh at 10 Hz; paused steps/completion notify immediately.
        if state.stepCount != step && (!state.shouldAdvance || state.stepCount % 6 == 0) { stateDidChange?() }
    }
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        guard view.bounds.width.isFinite, view.bounds.height.isFinite, view.bounds.width > 0, view.bounds.height > 0 else { return }
        if state.mode == .freePlay { replaceSimulation(reset: false) }
        redrawIfPaused()
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


}
