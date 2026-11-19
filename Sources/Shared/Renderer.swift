import Foundation
import MetalKit

@MainActor
struct Renderer3DSessionFactory {
    let makeSimulation: (MetalDevice) throws -> FluidSimulation3D
    let makeVisualization: (MetalDevice) throws -> FieldVisualization3D
    let makeTracers: (MetalDevice) throws -> TracerSystem3D
    let encodeReset: (FluidSimulation3D, MTLCommandBuffer) throws -> PressureProjection3D.StatusSlot
    let encodeTracerReset: (TracerSystem3D, MTLCommandBuffer) throws -> Void
    let encodeTracerAdvance: (
        TracerSystem3D,
        FluidSimulation3D,
        MTLCommandBuffer,
        PressureProjection3D.StatusSlot
    ) throws -> Void

    init(
        makeSimulation: @escaping (MetalDevice) throws -> FluidSimulation3D = { try FluidSimulation3D(metal: $0) },
        makeVisualization: @escaping (MetalDevice) throws -> FieldVisualization3D = { try FieldVisualization3D(metal: $0) },
        makeTracers: @escaping (MetalDevice) throws -> TracerSystem3D = { try TracerSystem3D(metal: $0) },
        encodeReset: @escaping (FluidSimulation3D, MTLCommandBuffer) throws -> PressureProjection3D.StatusSlot = {
            try $0.encodeReset(command: $1)
        },
        encodeTracerReset: @escaping (TracerSystem3D, MTLCommandBuffer) throws -> Void = {
            try $0.encodeReset(command: $1)
        },
        encodeTracerAdvance: @escaping (
            TracerSystem3D,
            FluidSimulation3D,
            MTLCommandBuffer,
            PressureProjection3D.StatusSlot
        ) throws -> Void = {
            try $0.encodeAdvance(command: $2, simulation: $1, status: $3)
        }
    ) {
        self.makeSimulation = makeSimulation
        self.makeVisualization = makeVisualization
        self.makeTracers = makeTracers
        self.encodeReset = encodeReset
        self.encodeTracerReset = encodeTracerReset
        self.encodeTracerAdvance = encodeTracerAdvance
    }
}

enum RendererModeFailureContext: Equatable {
    case preparation
    case activeSession
}

struct RendererModeOutcome: Equatable {
    let requestedMode: SimulationMode
    let committedMode: SimulationMode
    let errorMessage: String?
    let failureContext: RendererModeFailureContext?
    var succeeded: Bool { errorMessage == nil }
}

private struct RendererModeFailure: LocalizedError {
    let stage: String
    let reason: String
    var errorDescription: String? { "\(stage): \(reason)" }
}

private enum Renderer3DTransitionIntent {
    case selection
    case restart
}

private struct Renderer3DStepCompletion: Sendable {
    let generation: Int
    let failureMessage: String?
    let status: PressureProjection3D.StatusSlot
}

private final class Renderer3DCompletionMailbox: @unchecked Sendable {
    private let lock = NSLock()
    private var records: [Renderer3DStepCompletion] = []

    func enqueue(_ completion: Renderer3DStepCompletion) {
        lock.lock()
        records.append(completion)
        lock.unlock()
    }

    func takeAll() -> [Renderer3DStepCompletion] {
        lock.lock()
        defer { lock.unlock() }
        let result = records
        records.removeAll(keepingCapacity: true)
        return result
    }
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
    private(set) var tracers3D: TracerSystem3D?
    private(set) var latestCompleted3DStatus: PressureProjection3D.StatusSlot?
    private(set) var reset3DStatus: PressureProjection3D.StatusSlot?
    private var submitted3DStatuses: [(Int, PressureProjection3D.StatusSlot)] = []
    private(set) var state = SimulationState()
    private(set) var encoded3DStepCount = 0
    private(set) var completed3DStepCount = 0
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
    private var drawingQueuedStep = false
    private var inspectionRedrawPending = false
    private var inspectionRedrawScheduled = false
    private var interactive3DFrameInFlight = false
    private var sessionGeneration = 0
    private let visualization: FieldVisualization
    private let threeDFactory: Renderer3DSessionFactory
    private let completionMailbox = Renderer3DCompletionMailbox()

    /// Current ownership, including every submitted slot before callback drain.
    /// This never reads GPU memory or waits; harnesses order their own staging.
    var diagnostic3DStatuses: [(String, PressureProjection3D.StatusSlot)] {
        var result: [(String, PressureProjection3D.StatusSlot)] = []
        if let reset3DStatus { result.append(("status/reset", reset3DStatus)) }
        if let latestCompleted3DStatus, latestCompleted3DStatus !== reset3DStatus {
            result.append(("status/latest", latestCompleted3DStatus))
        }
        result += submitted3DStatuses.map { ("status/submitted-\($0.0)", $0.1) }
        return result
    }

    var diagnostic3DEvolutionMetadata: [String: String] {
        ["mode": state.mode.title, "steps": "\(state.stepCount)",
         "encoded": "\(encoded3DStepCount)", "completed": "\(completed3DStepCount)",
         "pending": "\(state.pendingSteps)", "paused": "\(state.userPaused)",
         "inactive": "\(state.inactive)", "resetting": "\(state.resetting)",
         "complete": "\(state.complete)", "drainScheduled": "\(stepDrainScheduled)",
         "sessionGeneration": "\(sessionGeneration)",
         "mouseInput": String(describing: mouseInput),
         "touchCount": "\(touchContacts.count)", "tapCount": "\(pendingTapContacts.count)",
         "touchRadius": String(describing: touchRadius),
         "failure": "\(lastModeOutcome?.errorMessage != nil)",
         "statusRoles": diagnostic3DStatuses.map(\.0).joined(separator: ",")]
    }

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
    func setInspection3D(_ inspection: InspectionState3D) {
        let previous = state.inspection3D
        state.setInspection3D(inspection)
        guard state.inspection3D != previous else { return }
        requestInspectionRedraw()
        stateDidChange?()
    }
    func resetCamera3D() {
        var inspection = state.inspection3D
        inspection.resetCamera()
        setInspection3D(inspection)
    }
    func centreSlice3D() {
        var inspection = state.inspection3D
        inspection.centreSlice()
        setInspection3D(inspection)
    }
    func togglePause() {
        state.togglePause()
        clearInput()
        updateScheduling()
        if state.mode.is3D { requestInspectionRedraw() }
        stateDidChange?()
    }
    func setTuningPosition(_ position: Float, for control: TuningControl) {
        guard state.mode == .freePlay else { return }
        state.tuning.setPosition(position, for: control)
    }
    func selectMode(_ mode: SimulationMode) {
        if mode.is3D {
            transitionTo3D(mode, intent: .selection)
            return
        }
        cancelStepDrain()
        clearInput()
        state.cancelPendingSteps()
        state.selectMode(mode)
        replaceSimulation(reset: true)
        simulation3D = nil
        visualization3D = nil
        tracers3D = nil
        latestCompleted3DStatus = nil
        reset3DStatus = nil
        submitted3DStatuses.removeAll()
        encoded3DStepCount = 0
        completed3DStepCount = 0
        publishModeOutcome(requested: mode, error: nil)
        stateDidChange?()
    }
    func setExperimentAdjustment(_ adjustment: ExperimentAdjustment) {
        guard state.setExperimentAdjustment(adjustment) else { return }
        replaceSimulation(reset: true); stateDidChange?()
    }
    func restartCurrentSimulation() {
        if state.mode.is3D {
            transitionTo3D(.dyeAdvection3D, intent: .restart)
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
            if self.state.pendingSteps > 0, let view = self.metalView {
                if self.state.mode.is3D, view.delegate === self, view.isPaused {
                    self.drawingQueuedStep = true
                    view.draw()
                    self.drawingQueuedStep = false
                } else {
                    self.draw(in: view)
                }
            }
            self.scheduleStepDrain()
        }
    }
    private func cancelStepDrain() {
        sessionGeneration &+= 1
        stepDrainScheduled = false
    }
    func resignActive() {
        state.resignActive()
        clearInput()
        if state.mode.is3D {
            withAllBuffersDrained {}
            processCompleted3DSteps()
        }
        updateScheduling()
        stateDidChange?()
    }
    func becomeActive() { state.becomeActive(); updateScheduling(); redrawIfPaused(); stateDidChange?() }
    private func updateScheduling() { metalView?.isPaused = !state.shouldAdvance }

    private func requestInspectionRedraw() {
        guard !state.shouldAdvance, !state.inactive, !state.resetting else { return }
        inspectionRedrawPending = true
        scheduleInspectionRedraw()
    }

    private func scheduleInspectionRedraw() {
        guard inspectionRedrawPending, !inspectionRedrawScheduled, !interactive3DFrameInFlight else { return }
        inspectionRedrawScheduled = true
        RunLoop.main.perform(inModes: [.common]) { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.inspectionRedrawScheduled = false
                guard self.inspectionRedrawPending, !self.interactive3DFrameInFlight else { return }
                self.inspectionRedrawPending = false
                guard self.state.mode.is3D, !self.state.shouldAdvance, let view = self.metalView else { return }
                if view.delegate === self {
                    // MTKView retires its current drawable at the end of draw().
                    view.draw()
                } else {
                    self.drawPresentationOnly(in: view)
                }
            }
        }
    }
    private func redrawIfPaused() {
        guard !state.shouldAdvance, !state.inactive, !state.resetting,
              state.mode.is3D
                ? simulation3D != nil && visualization3D != nil && tracers3D != nil
                : simulation != nil,
              let view = metalView else { return }
        if state.mode.is3D, view.delegate === self {
            requestInspectionRedraw()
        } else {
            drawPresentationOnly(in: view)
        }
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

    private func transitionTo3D(_ mode: SimulationMode, intent: Renderer3DTransitionIntent) {
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
                let candidateTracers: TracerSystem3D
                do { candidateTracers = try threeDFactory.makeTracers(metal) }
                catch { throw RendererModeFailure(stage: "3D tracer resources", reason: Self.message(for: error)) }
                let drawableSize = metalView.flatMap { Self.drawablePixelSize(for: $0) }
                do {
                    try candidateVisualization.prepareInspection(
                        width: drawableSize?.width ?? 0,
                        height: drawableSize?.height ?? 0
                    )
                } catch {
                    throw RendererModeFailure(
                        stage: "3D presentation depth",
                        reason: Self.message(for: error)
                    )
                }

                let command = metal.newCommandBuffer()
                let status: PressureProjection3D.StatusSlot
                do { status = try threeDFactory.encodeReset(candidate, command) }
                catch { throw RendererModeFailure(stage: "3D initial reset encoding", reason: Self.message(for: error)) }
                do { try threeDFactory.encodeTracerReset(candidateTracers, command) }
                catch {
                    throw RendererModeFailure(
                        stage: "3D initial tracer reset encoding",
                        reason: Self.message(for: error)
                    )
                }
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

                var candidateState = state
                switch intent {
                case .selection:
                    candidateState.selectMode(mode)
                case .restart:
                    candidateState.beginReset()
                }
                candidateState.finishReset()
                simulation3D = candidate
                visualization3D = candidateVisualization
                tracers3D = candidateTracers
                latestCompleted3DStatus = status
                reset3DStatus = status
                submitted3DStatuses.removeAll()
                state = candidateState
                encoded3DStepCount = 0
                completed3DStepCount = 0
            } catch {
                if wasAlready3D { restoreUsableTwoDState() }
                state.cancelPendingSteps()
                failureMessage = Self.message(for: error)
            }
        }
        publishModeOutcome(
            requested: mode,
            error: failureMessage,
            failureContext: failureMessage == nil ? nil : .preparation
        )
        updateScheduling()
        redrawIfPaused()
        stateDidChange?()
    }

    private func restoreUsableTwoDState() {
        guard let view = metalView else { return }
        let wasInactive = state.inactive
        var recovered = state
        recovered.selectMode(.freePlay)
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
        tracers3D = nil
        latestCompleted3DStatus = nil
        reset3DStatus = nil
        submitted3DStatuses.removeAll()
        recovered.finishReset()
        if wasInactive { recovered.resignActive() }
        state = recovered
        encoded3DStepCount = 0
        completed3DStepCount = 0
    }

    private func publishModeOutcome(
        requested: SimulationMode,
        error: String?,
        failureContext: RendererModeFailureContext? = nil
    ) {
        let outcome = RendererModeOutcome(
            requestedMode: requested,
            committedMode: state.mode,
            errorMessage: error,
            failureContext: failureContext
        )
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
    private func spatialViewport(
        in view: MTKView,
        drawable: CAMetalDrawable
    ) -> (viewport: MTLViewport, pointScale: Float)? {
        let bounds = view.bounds
        let width = drawable.texture.width
        let height = drawable.texture.height
        guard width > 0, height > 0,
              bounds.width.isFinite, bounds.height.isFinite,
              bounds.width > 0, bounds.height > 0 else { return nil }
        let pointScale = Double(width) / Double(bounds.width)
        guard pointScale.isFinite, pointScale > 0 else { return nil }
        return (
            MTLViewport(
                originX: 0,
                originY: 0,
                width: Double(width),
                height: Double(height),
                znear: 0,
                zfar: 1
            ),
            Float(pointScale)
        )
    }
    private func render(command: MTLCommandBuffer, drawable: CAMetalDrawable, view: MTKView) throws {
        if state.mode.is3D {
            guard let simulation3D, let visualization3D, let tracers3D else {
                throw RendererModeFailure(stage: "3D presentation", reason: "active 3D resources are unavailable")
            }
            guard let spatialViewport = spatialViewport(in: view, drawable: drawable) else { return }
            do {
                try visualization3D.encodeInspection(
                    command: command,
                    simulation: simulation3D,
                    tracers: tracers3D,
                    destination: drawable.texture,
                    viewport: spatialViewport.viewport,
                    inspection: state.inspection3D,
                    pointScale: spatialViewport.pointScale,
                    increaseContrast: false
                )
            } catch {
                throw RendererModeFailure(
                    stage: "3D presentation",
                    reason: "\(Self.message(for: error)) "
                        + "(drawable=\(drawable.texture.width)x\(drawable.texture.height), "
                        + "viewDrawable=\(view.drawableSize), bounds=\(view.bounds), "
                        + "viewport=\(spatialViewport.viewport.originX),\(spatialViewport.viewport.originY),"
                        + "\(spatialViewport.viewport.width)x\(spatialViewport.viewport.height))"
                )
            }
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
        // The live display loop may skip a tick while the GPU is busy. Explicit
        // draws and queued single steps continue to submit each accepted step.
        let interactive3D = state.mode.is3D && view.delegate === self && !drawingQueuedStep
        draw(in: view, presentationOnly: interactive3D && !state.shouldAdvance, interactive3D: interactive3D)
    }

    func drawPresentationOnly(in view: MTKView) {
        draw(in: view, presentationOnly: true)
    }

    private func draw(in view: MTKView, presentationOnly: Bool, interactive3D: Bool = false) {
        guard !state.inactive, !state.resetting,
              state.mode.is3D
                ? simulation3D != nil && visualization3D != nil && tracers3D != nil
                : simulation != nil else { return }
        if interactive3D {
            guard !interactive3DFrameInFlight else { return }
            guard semaphore.wait(timeout: .now()) == .success else {
                if presentationOnly { inspectionRedrawPending = true }
                return
            }
        } else {
            semaphore.wait()
        }
        let drawable: CAMetalDrawable?
        if presentationOnly {
            guard let currentDrawable = view.currentDrawable else {
                semaphore.signal()
                return
            }
            drawable = currentDrawable
        } else {
            drawable = nil
        }
        let command = metal.newCommandBuffer()
        if interactive3D {
            interactive3DFrameInFlight = true
            command.addCompletedHandler { [weak self] _ in
                RunLoop.main.perform(inModes: [.common]) { [weak self] in
                    MainActor.assumeIsolated {
                        self?.interactive3DFrameInFlight = false
                        self?.scheduleInspectionRedraw()
                    }
                }
            }
        }
        let step = state.stepCount
        var threeDStatus: PressureProjection3D.StatusSlot?
        if presentationOnly {
            // Presentation-only frames deliberately preserve pending work and
            // do not advance simulation or tracer state.
        } else if state.mode.is3D {
            let eligible = state.shouldAdvance || (state.canStep && state.pendingSteps > 0)
            if eligible {
                do {
                    guard let simulation3D else {
                        throw RendererModeFailure(stage: "3D advance", reason: "active 3D simulation is unavailable")
                    }
                    guard let tracers3D else {
                        throw RendererModeFailure(stage: "3D tracer advance", reason: "active 3D tracers are unavailable")
                    }
                    let status = try simulation3D.encodeStep(command: command)
                    threeDStatus = status
                    try threeDFactory.encodeTracerAdvance(
                        tracers3D,
                        simulation3D,
                        command,
                        status
                    )
                } catch {
                    registerCommandCompletion(command, threeDStatus: threeDStatus, generation: sessionGeneration)
                    command.commit()
                    failActiveThreeDSession(error)
                    return
                }
                guard state.consumeStep() else {
                    registerCommandCompletion(command, threeDStatus: threeDStatus, generation: sessionGeneration)
                    command.commit()
                    failActiveThreeDSession(RendererModeFailure(
                        stage: "3D advance",
                        reason: "simulation state rejected a step after its GPU commands were encoded"
                    ))
                    return
                }
                encoded3DStepCount += 1
            } else {
                clearInput()
            }
        } else if state.consumeStep() {
            var contacts = touchContacts + pendingTapContacts; pendingTapContacts.removeAll()
            if let mouse = mouseInput.contactForFrame() { contacts = [mouse] }
            simulation.encodeStep(command: command, tuning: state.tuning, contacts: contacts, radius: touchRadius,
                                  mode: state.mode, adjustment: state.adjustment, step: step)
        } else {
            clearInput()
        }
        let currentDrawable = drawable ?? view.currentDrawable
        if let currentDrawable {
            do {
                try render(command: command, drawable: currentDrawable, view: view)
                command.present(currentDrawable)
            } catch {
                registerCommandCompletion(command, threeDStatus: threeDStatus, generation: sessionGeneration)
                command.commit()
                failActiveThreeDSession(error)
                return
            }
        }
        registerCommandCompletion(command, threeDStatus: threeDStatus, generation: sessionGeneration)
        command.commit()
        if !presentationOnly { updateScheduling() }
        // Live counters refresh at 10 Hz; paused steps/completion notify immediately.
        if !presentationOnly, state.stepCount != step,
           (!state.shouldAdvance || state.stepCount % 6 == 0) { stateDidChange?() }
    }

    private func registerCommandCompletion(
        _ command: MTLCommandBuffer,
        threeDStatus: PressureProjection3D.StatusSlot?,
        generation: Int
    ) {
        guard let threeDStatus else {
            command.addCompletedHandler { [semaphore] _ in semaphore.signal() }
            return
        }
        let mailbox = completionMailbox
        submitted3DStatuses.append((encoded3DStepCount, threeDStatus))
        command.addCompletedHandler { [weak self, semaphore] completedCommand in
            let failureMessage = Self.stepCompletionFailure(command: completedCommand, status: threeDStatus)
            mailbox.enqueue(Renderer3DStepCompletion(
                generation: generation,
                failureMessage: failureMessage,
                status: threeDStatus
            ))
            semaphore.signal()
            DispatchQueue.main.async { [weak self] in self?.processCompleted3DSteps() }
        }
    }

    nonisolated private static func stepCompletionFailure(
        command: MTLCommandBuffer,
        status: PressureProjection3D.StatusSlot
    ) -> String? {
        guard command.status == .completed else {
            return "3D step command failed: \(command.error.map(String.init(describing:)) ?? "command did not complete")"
        }
        let diagnostics = status.diagnostics()
        guard diagnostics.failure == .none, diagnostics.converged, !diagnostics.capHit,
              diagnostics.trueResidualDTInf.isFinite, diagnostics.trueResidualDTInf <= 1e-5,
              diagnostics.projectedDivergenceDTInf.isFinite, diagnostics.projectedDivergenceDTInf <= 1e-5,
              diagnostics.identityDTError.isFinite, diagnostics.identityDTError <= 2e-5,
              diagnostics.maximumWallNormalValue == 0 else {
            return "3D step projection failed: \(diagnostics.failure); converged=\(diagnostics.converged), "
                + "capHit=\(diagnostics.capHit), residual=\(diagnostics.trueResidualDTInf), "
                + "divergence=\(diagnostics.projectedDivergenceDTInf), identity=\(diagnostics.identityDTError), "
                + "wall=\(diagnostics.maximumWallNormalValue)"
        }
        return nil
    }

    private func processCompleted3DSteps() {
        for completion in completionMailbox.takeAll() where completion.generation == sessionGeneration {
            submitted3DStatuses.removeAll { $0.1 === completion.status }
            if let failureMessage = completion.failureMessage {
                failActiveThreeDSession(message: failureMessage)
                return
            }
            latestCompleted3DStatus = completion.status
            completed3DStepCount += 1
        }
        scheduleInspectionRedraw()
    }

    private func failActiveThreeDSession(_ error: Error) {
        failActiveThreeDSession(message: Self.message(for: error))
    }

    private func failActiveThreeDSession(message: String) {
        let requested = state.mode
        cancelStepDrain()
        clearInput()
        state.cancelPendingSteps()
        withAllBuffersDrained {
            restoreUsableTwoDState()
        }
        publishModeOutcome(
            requested: requested,
            error: message,
            failureContext: .activeSession
        )
        updateScheduling()
        redrawIfPaused()
        stateDidChange?()
    }
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        guard view.bounds.width.isFinite, view.bounds.height.isFinite, view.bounds.width > 0, view.bounds.height > 0 else { return }
        if state.mode == .freePlay { replaceSimulation(reset: false) }
        if state.mode.is3D, let visualization3D,
           let drawableSize = Self.drawablePixelSize(size) {
            do {
                try visualization3D.prepareInspection(width: drawableSize.width, height: drawableSize.height)
            } catch {
                failActiveThreeDSession(RendererModeFailure(
                    stage: "3D presentation depth",
                    reason: Self.message(for: error)
                ))
                return
            }
        }
        redrawIfPaused()
    }
    private static func drawablePixelSize(_ size: CGSize) -> (width: Int, height: Int)? {
        guard size.width.isFinite, size.height.isFinite,
              size.width > 0, size.height > 0,
              size.width < CGFloat(Int.max), size.height < CGFloat(Int.max) else { return nil }
        let width = Int(size.width.rounded(.down))
        let height = Int(size.height.rounded(.down))
        guard width > 0, height > 0 else { return nil }
        return (width, height)
    }
    private static func drawablePixelSize(for view: MTKView) -> (width: Int, height: Int)? {
        if let drawable = view.currentDrawable,
           drawable.texture.width > 0, drawable.texture.height > 0 {
            return (drawable.texture.width, drawable.texture.height)
        }
        return drawablePixelSize(view.drawableSize)
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
