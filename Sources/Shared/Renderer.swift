import MetalKit

@MainActor
struct Renderer3DSessionFactory {
    let makeSimulation: (MetalDevice) throws -> FluidSimulation3D
    let makeVisualization: (MetalDevice) throws -> FieldVisualization3D
    let encodeReset: (FluidSimulation3D, MTLCommandBuffer) throws -> PressureProjection3D.StatusSlot

    init(
        makeSimulation: @escaping (MetalDevice) throws -> FluidSimulation3D = { try FluidSimulation3D(metal: $0) },
        makeVisualization: @escaping (MetalDevice) throws -> FieldVisualization3D = { try FieldVisualization3D(metal: $0) },
        encodeReset: @escaping (FluidSimulation3D, MTLCommandBuffer) throws -> PressureProjection3D.StatusSlot = {
            try $0.encodeReset(command: $1)
        }
    ) {
        self.makeSimulation = makeSimulation
        self.makeVisualization = makeVisualization
        self.encodeReset = encodeReset
    }
}

struct RendererModeOutcome: Equatable {
    let requestedMode: SimulationMode
    let committedMode: SimulationMode
    let errorMessage: String?
    var succeeded: Bool { errorMessage == nil }
}

private struct RendererModeFailure: LocalizedError {
    let stage: String
    let reason: String
    var errorDescription: String? { "\(stage): \(reason)" }
}

@MainActor
final class Renderer: NSObject, MTKViewDelegate {
    static let MaxBuffers = 3
    nonisolated static let ContactCapacity = 10
    nonisolated static let ScreenScaleAdjustment: Float = 1
    private let semaphore = DispatchSemaphore(value: MaxBuffers)
    private let metal: MetalDevice
    private weak var metalView: MTKView?
    private(set) var simulation: FluidSimulation!
    private(set) var simulation3D: FluidSimulation3D?
    private(set) var visualization3D: FieldVisualization3D?
    private(set) var state = SimulationState()
    var stateDidChange: (() -> Void)?
    private(set) var lastModeOutcome: RendererModeOutcome?
    var modeOutcomeDidChange: ((RendererModeOutcome) -> Void)?
    /// Point-space rectangle available to a lesson; iOS reserves controls outside this area.
    var lessonAvailableRect: CGRect? { didSet { redrawIfPaused() } }
    private var mouseInput = MouseInputState()
    private var touchContacts: [FluidContact] = []
    private var pendingTapContacts: [FluidContact] = []
    private var touchRadius: Float?
    private var stepDrainScheduled = false
    private var sessionGeneration = 0
    private let visualization: FieldVisualization
    private let threeDFactory: Renderer3DSessionFactory
    private var twoDRecoveryState: SimulationState?

    init(
        metalView: MTKView,
        metal: MetalDevice = .sharedInstance,
        threeDFactory: Renderer3DSessionFactory = Renderer3DSessionFactory()
    ) {
        self.metal = metal
        self.threeDFactory = threeDFactory
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
    func selectMode(_ mode: SimulationMode) {
        if mode.is3D {
            transitionTo3D(mode)
            return
        }
        cancelStepDrain()
        clearInput()
        state.cancelPendingSteps()
        state.selectMode(mode)
        replaceSimulation(reset: true)
        simulation3D = nil
        visualization3D = nil
        twoDRecoveryState = nil
        publishModeOutcome(requested: mode, error: nil)
        stateDidChange?()
    }
    func setExperimentAdjustment(_ adjustment: ExperimentAdjustment) {
        guard state.setExperimentAdjustment(adjustment) else { return }
        replaceSimulation(reset: true); stateDidChange?()
    }
    func restartCurrentSimulation() {
        if state.mode.is3D {
            transitionTo3D(.dyeAdvection3D)
            return
        }
        cancelStepDrain()
        clearInput()
        state.beginReset()
        replaceSimulation(reset: true)
        stateDidChange?()
    }
    func requestSingleStep() {
        guard state.requestSingleStep() else { return }
        scheduleStepDrain()
    }
    private func scheduleStepDrain() {
        guard !stepDrainScheduled, state.pendingSteps > 0 else { return }
        stepDrainScheduled = true
        let generation = sessionGeneration
        DispatchQueue.main.async { [weak self] in
            guard let self, self.sessionGeneration == generation else { return }
            self.stepDrainScheduled = false
            if self.state.pendingSteps > 0, let view = self.metalView { self.draw(in: view) }
            self.scheduleStepDrain()
        }
    }
    private func cancelStepDrain() {
        sessionGeneration &+= 1
        stepDrainScheduled = false
    }
    func resignActive() { state.resignActive(); clearInput(); updateScheduling(); stateDidChange?() }
    func becomeActive() { state.becomeActive(); updateScheduling(); redrawIfPaused(); stateDidChange?() }
    private func updateScheduling() { metalView?.isPaused = !state.shouldAdvance }
    private func redrawIfPaused() {
        guard !state.shouldAdvance, !state.inactive, !state.resetting,
              state.mode.is3D ? simulation3D != nil && visualization3D != nil : simulation != nil else { return }
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
    private func withAllBuffersDrained<T>(_ body: () -> T) -> T {
        for _ in 0..<Self.MaxBuffers { semaphore.wait() }
        defer { for _ in 0..<Self.MaxBuffers { semaphore.signal() } }
        return body()
    }
    private func replaceSimulation(reset: Bool) {
        guard let view = metalView else { return }
        let width = state.mode.experiment == nil ? max(1, Int(view.bounds.width)) : ExperimentRecipes.gridSize
        let height = state.mode.experiment == nil ? max(1, Int(view.bounds.height)) : ExperimentRecipes.gridSize
        if !reset, simulation?.width == width, simulation?.height == height { return }
        withAllBuffersDrained {
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
        }
        updateScheduling(); redrawIfPaused()
    }

    private func transitionTo3D(_ mode: SimulationMode) {
        let wasAlready3D = state.mode.is3D
        cancelStepDrain()
        clearInput()
        state.cancelPendingSteps()
        var failureMessage: String?
        withAllBuffersDrained {
            do {
                let candidate: FluidSimulation3D
                do { candidate = try threeDFactory.makeSimulation(metal) }
                catch { throw RendererModeFailure(stage: "3D resources", reason: Self.message(for: error)) }
                guard candidate.configuration == .production else {
                    throw RendererModeFailure(
                        stage: "3D resources",
                        reason: "expected fixed production grid 64x64x64, got "
                            + "\(candidate.configuration.nx)x\(candidate.configuration.ny)x\(candidate.configuration.nz)"
                    )
                }

                let candidateVisualization: FieldVisualization3D
                do { candidateVisualization = try threeDFactory.makeVisualization(metal) }
                catch { throw RendererModeFailure(stage: "3D presentation pipeline", reason: Self.message(for: error)) }

                let command = metal.newCommandBuffer()
                let status: PressureProjection3D.StatusSlot
                do { status = try threeDFactory.encodeReset(candidate, command) }
                catch { throw RendererModeFailure(stage: "3D initial reset encoding", reason: Self.message(for: error)) }
                command.commit()
                command.waitUntilCompleted()
                guard command.status == .completed else {
                    throw RendererModeFailure(
                        stage: "3D initial reset command",
                        reason: command.error.map(String.init(describing:)) ?? "command did not complete"
                    )
                }
                let diagnostics = status.diagnostics()
                guard diagnostics.failure == .none, diagnostics.converged, !diagnostics.capHit,
                      diagnostics.trueResidualDTInf.isFinite, diagnostics.trueResidualDTInf <= 1e-5,
                      diagnostics.projectedDivergenceDTInf.isFinite, diagnostics.projectedDivergenceDTInf <= 1e-5,
                      diagnostics.identityDTError.isFinite, diagnostics.identityDTError <= 2e-5,
                      diagnostics.maximumWallNormalValue == 0 else {
                    throw RendererModeFailure(
                        stage: "3D initial reset projection",
                        reason: "\(diagnostics.failure); converged=\(diagnostics.converged), capHit=\(diagnostics.capHit), "
                            + "residual=\(diagnostics.trueResidualDTInf), divergence=\(diagnostics.projectedDivergenceDTInf), "
                            + "identity=\(diagnostics.identityDTError), wall=\(diagnostics.maximumWallNormalValue)"
                    )
                }

                if !wasAlready3D { twoDRecoveryState = state }
                var candidateState = state
                candidateState.selectMode(mode)
                candidateState.finishReset()
                simulation3D = candidate
                visualization3D = candidateVisualization
                state = candidateState
            } catch {
                if wasAlready3D { restoreUsableTwoDState() }
                state.cancelPendingSteps()
                failureMessage = Self.message(for: error)
            }
        }
        publishModeOutcome(requested: mode, error: failureMessage)
        updateScheduling()
        redrawIfPaused()
        stateDidChange?()
    }

    private func restoreUsableTwoDState() {
        guard let view = metalView else { return }
        var recovered = twoDRecoveryState ?? SimulationState()
        recovered.beginReset()
        let width = recovered.mode.experiment == nil ? max(1, Int(view.bounds.width)) : ExperimentRecipes.gridSize
        let height = recovered.mode.experiment == nil ? max(1, Int(view.bounds.height)) : ExperimentRecipes.gridSize
        let next = FluidSimulation(width: width, height: height, metal: metal)
        let command = metal.newCommandBuffer()
        next.encodeReset(command: command, mode: recovered.mode, adjustment: recovered.adjustment)
        command.commit(); command.waitUntilCompleted()
        precondition(command.status == .completed, "2D recovery reset failed: \(String(describing: command.error))")
        simulation = next
        simulation3D = nil
        visualization3D = nil
        recovered.finishReset()
        state = recovered
        twoDRecoveryState = nil
    }

    private func publishModeOutcome(requested: SimulationMode, error: String?) {
        let outcome = RendererModeOutcome(requestedMode: requested, committedMode: state.mode, errorMessage: error)
        lastModeOutcome = outcome
        modeOutcomeDidChange?(outcome)
    }

    private static func message(for error: Error) -> String {
        if let localized = error as? LocalizedError, let description = localized.errorDescription { return description }
        return String(describing: error)
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
    private func render(command: MTLCommandBuffer, drawable: CAMetalDrawable, view: MTKView) throws {
        if state.mode.is3D {
            guard let simulation3D, let visualization3D else {
                throw RendererModeFailure(stage: "3D presentation", reason: "active 3D resources are unavailable")
            }
            try visualization3D.encodeSlice(
                command: command,
                simulation: simulation3D,
                destination: drawable.texture,
                viewport: viewport(in: view)
            )
            return
        }
        renderTwoD(command: command, drawable: drawable, view: view)
    }
    private func renderTwoD(command: MTLCommandBuffer, drawable: CAMetalDrawable, view: MTKView) {
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
        guard !state.inactive, !state.resetting,
              state.mode.is3D ? simulation3D != nil && visualization3D != nil : simulation != nil else { return }
        semaphore.wait()
        let command = metal.newCommandBuffer()
        command.addCompletedHandler { [semaphore] _ in semaphore.signal() }
        let step = state.stepCount
        if state.consumeStep() {
            if state.mode.is3D {
                do {
                    guard let simulation3D else {
                        throw RendererModeFailure(stage: "3D advance", reason: "active 3D simulation is unavailable")
                    }
                    _ = try simulation3D.encodeStep(command: command)
                } catch {
                    command.commit()
                    failActiveThreeDSession(error)
                    return
                }
            } else {
                var contacts = touchContacts + pendingTapContacts; pendingTapContacts.removeAll()
                if let mouse = mouseInput.contactForFrame() { contacts = [mouse] }
                simulation.encodeStep(command: command, tuning: state.tuning, contacts: contacts, radius: touchRadius,
                                      mode: state.mode, adjustment: state.adjustment, step: step)
            }
        } else { clearInput() }
        if let drawable = view.currentDrawable {
            do {
                try render(command: command, drawable: drawable, view: view)
                command.present(drawable)
            } catch {
                command.commit()
                failActiveThreeDSession(error)
                return
            }
        }
        command.commit()
        updateScheduling()
        // Live counters refresh at 10 Hz; paused steps/completion notify immediately.
        if state.stepCount != step && (!state.shouldAdvance || state.stepCount % 6 == 0) { stateDidChange?() }
    }
    private func failActiveThreeDSession(_ error: Error) {
        let requested = state.mode
        cancelStepDrain()
        clearInput()
        state.cancelPendingSteps()
        withAllBuffersDrained {
            restoreUsableTwoDState()
        }
        publishModeOutcome(requested: requested, error: Self.message(for: error))
        updateScheduling()
        redrawIfPaused()
        stateDidChange?()
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
