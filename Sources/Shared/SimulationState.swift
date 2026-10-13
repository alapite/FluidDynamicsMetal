import Foundation

enum DisplayField: Int, CaseIterable {
    case density, pressure, velocity, vorticity
    var title: String { ["Dye concentration", "Pressure", "Velocity", "Vorticity"][rawValue] }
    var explanation: String {
        ["Dye marks material carried by the flow.",
         "Shows the pressure correction relative to its spatial average, in simulation units.",
         "Arrows show direction; colour shows speed.",
         "Colour distinguishes local clockwise and anticlockwise rotation."][rawValue]
    }
    var legend: String {
        ["Less dye → More dye", "Lower → Average → Higher", "Slower → Faster",
         "Clockwise (orange) → Zero → Anticlockwise (blue)"][rawValue]
    }
    var palette: [SIMD3<Float>] {
        switch self {
        case .density: return [[0,0,0], [0.02,0.32,0.85], [0.8,1,1]]
        case .velocity: return [[0.09,0.02,0.18], [0.02,0.65,0.60], [1,0.92,0.20]]
        case .pressure: return [[0.08,0.35,0.85], [0.88,0.88,0.88], [0.95,0.38,0.06]]
        case .vorticity: return [[0.95,0.38,0.06], [0.88,0.88,0.88], [0.08,0.35,0.85]]
        }
    }
    var scaleNote: String { self == .density ? "" : "Colour scale adjusts to this frame." }
}

struct DisplayOptions: Equatable {
    var arrows = false
    var particles = false
    var trails = false
    static let lesson = DisplayOptions(arrows: true, particles: true, trails: false)
}

enum SimulationMode: Equatable {
    case freePlay, experiment(ExperimentID)
    var experiment: ExperimentID? { if case let .experiment(id) = self { return id }; return nil }
    static var allCases: [SimulationMode] { [.freePlay] + ExperimentID.allCases.map { .experiment($0) } }
    var title: String { experiment?.title ?? "Free Play" }
}

enum ExperimentID: Int, CaseIterable {
    case advection, interactingVortices, dyeStretching
    var title: String { ["Dye carried by a flow", "Two interacting vortices", "Stretching dye by stirring"][rawValue] }
    var question: String {
        ["Where will this patch of dye travel?", "How does reversing one vortex change their motion?",
         "How can a narrow stripe spread through the fluid?"][rawValue]
    }
    var notice: String {
        ["The flow carries the dye. Change the starting speed and compare its position after the same number of steps.",
         "Compare the movement of the rotating regions when they turn in the same direction and in opposite directions.",
         "Stirring stretches and folds the stripe. Stronger stirring changes its shape more quickly. The solver also smooths fine details; this is not a measurement of molecular diffusion."][rawValue]
    }
    var adjustmentTitle: String { ["Initial flow speed", "Rotation", "Stirring strength"][rawValue] }
    var choices: [ExperimentAdjustment] {
        switch self {
        case .advection: return FlowSpeed.allCases.map { .speed($0) }
        case .interactingVortices: return RotationPair.allCases.map { .rotation($0) }
        case .dyeStretching: return StirringStrength.allCases.map { .strength($0) }
        }
    }
    var defaultAdjustment: ExperimentAdjustment {
        switch self {
        case .advection: return .speed(.normal)
        case .interactingVortices: return .rotation(.same)
        case .dyeStretching: return .strength(.normal)
        }
    }
    var defaultField: DisplayField { self == .interactingVortices ? .vorticity : .density }
}
enum FlowSpeed: Float, CaseIterable { case slow = 0.5, normal = 1, fast = 1.5 }
enum RotationPair: Int, CaseIterable { case same, opposite }
enum StirringStrength: Float, CaseIterable { case gentle = 0.5, normal = 1, strong = 1.5 }
enum ExperimentAdjustment: Equatable {
    case speed(FlowSpeed), rotation(RotationPair), strength(StirringStrength)
    var title: String {
        switch self {
        case let .speed(value): return "\(value.rawValue) cells per step"
        case .rotation(.same): return "Same rotation"
        case .rotation(.opposite): return "Opposite rotation"
        case .strength(.gentle): return "Gentle"
        case .strength(.normal): return "Normal"
        case .strength(.strong): return "Strong"
        }
    }
}
enum LearningCopy {
    static let about = "These are two-dimensional qualitative simulations. Steps count solver advances, not physical time. Repeat the same settings and step count on the same device to compare. Numerical advection can smooth fields even with fading and damping set to zero. The pressure correction and boundary treatment are approximate; these are not quantitatively validated physical predictions."
    static let trails = "Trails show recent paths followed by marker particles."
    static let fading = "Zero means no explicit fading or damping. Numerical advection can still smooth the fields."
    static let adjustment = "Changing this restarts the experiment."
}

enum TuningControl: Int, CaseIterable {
    case force, dye, swirl, fade, damping
    var title: String { ["Force", "Dye", "Swirl enhancement", "Dye fading", "Motion damping"][rawValue] }
    var identifier: String { ["force", "dye", "swirl", "fade", "damping"][rawValue] }
}
struct SimulationTuning: Equatable {
    private static func bounded(_ value: Float, default fallback: Float, min lower: Float, max upper: Float) -> Float {
        value.isFinite ? Swift.min(upper, Swift.max(lower, value)) : fallback
    }
    var force: Float = 1 { didSet { force = Self.bounded(force, default: 1, min: 0, max: 2) } }
    var dye: Float = 0.8 { didSet { dye = Self.bounded(dye, default: 0.8, min: 0, max: 2) } }
    var radius: Float = 150 { didSet { radius = Self.bounded(radius, default: 150, min: 1, max: 400) } }
    var swirl: Float = 0.4 { didSet { swirl = Self.bounded(swirl, default: 0.4, min: 0, max: 2) } }
    var dyeRetention: Float = 0.998 { didSet { dyeRetention = Self.bounded(dyeRetention, default: 0.998, min: 0, max: 1) } }
    var velocityRetention: Float = 0.998 { didSet { velocityRetention = Self.bounded(velocityRetention, default: 0.998, min: 0, max: 1) } }
    // Source compatibility for older clients; production uses the independent channels.
    var retention: Float { get { dyeRetention } set { dyeRetention = newValue; velocityRetention = newValue } }
    var pressureIterations: Int = 40 { didSet { pressureIterations = Swift.min(80, Swift.max(1, pressureIterations)) } }
    static var lesson: Self {
        var result = Self(); result.dyeRetention = 1; result.velocityRetention = 1; result.swirl = 0; result.dye = 0
        return result
    }
    mutating func setPosition(_ position: Float, for control: TuningControl) {
        let defaults: [Float] = [0.5, 0.4, 0.2, 0.17, 0.17]
        let p = Self.bounded(position, default: defaults[control.rawValue], min: 0, max: 1)
        let retention: Float = p == 0.17 ? 0.998 : p < 0.17 ? 1 - 0.002 * p / 0.17 : 0.998 - 0.0075 * (p - 0.17) / 0.83
        switch control {
        case .force: force = 2 * p
        case .dye: dye = 2 * p
        case .swirl: swirl = 2 * p
        case .fade: dyeRetention = retention
        case .damping: velocityRetention = retention
        }
    }
    func position(for control: TuningControl) -> Float {
        switch control {
        case .force: return force / 2
        case .dye: return dye / 2
        case .swirl: return swirl / 2
        case .fade, .damping:
            let r = control == .fade ? dyeRetention : velocityRetention
            let p: Float = r >= 0.998 ? (1 - r) * (0.17 / 0.002) : 0.17 + (0.998 - r) * (0.83 / 0.0075)
            return Swift.min(1, Swift.max(0, p))
        }
    }
}

struct SimulationState {
    private(set) var field: DisplayField = .density
    private(set) var userPaused = false
    private(set) var inactive = false
    private(set) var mode: SimulationMode = .freePlay
    private(set) var adjustment: ExperimentAdjustment?
    private(set) var displayOptions = DisplayOptions()
    private(set) var stepCount = 0
    private(set) var pendingSteps = 0
    private(set) var resetting = false
    var tuning = SimulationTuning()
    private var freePlayTuning = SimulationTuning()
    private var freePlayField: DisplayField = .density
    private var freePlayOptions = DisplayOptions()
    static let lessonSteps = 600
    var complete: Bool { mode.experiment != nil && stepCount >= Self.lessonSteps }
    var shouldAdvance: Bool { !userPaused && !inactive && !resetting && !complete }
    var canStep: Bool { userPaused && !inactive && !resetting && !complete }
    var acceptsInput: Bool { mode == .freePlay && shouldAdvance }
    var status: String { complete ? "Experiment complete. Restart to compare." : "Step \(stepCount)" }
    mutating func nextField() { field = DisplayField(rawValue: (field.rawValue + 1) % DisplayField.allCases.count)! }
    mutating func selectField(_ field: DisplayField) { self.field = field }
    mutating func setDisplayOptions(_ options: DisplayOptions) { displayOptions = options }
    mutating func togglePause() {
        guard !complete else { return }
        userPaused.toggle()
        if !userPaused { pendingSteps = 0 }
    }
    @discardableResult mutating func requestSingleStep() -> Bool {
        guard canStep, mode.experiment == nil || pendingSteps < Self.lessonSteps - stepCount else { return false }
        pendingSteps += 1; return true
    }
    // Called once for each encoded step, independently of drawable availability.
    @discardableResult mutating func consumeStep() -> Bool {
        guard shouldAdvance || (canStep && pendingSteps > 0) else { return false }
        if userPaused { pendingSteps -= 1 }
        stepCount += 1
        if complete { userPaused = true; pendingSteps = 0 }
        return true
    }
    mutating func resignActive() { inactive = true; pendingSteps = 0 }
    mutating func becomeActive() { inactive = false }
    mutating func resetTuning() { tuning = mode == .freePlay ? SimulationTuning() : .lesson }
    mutating func beginReset() { resetting = true; pendingSteps = 0; stepCount = 0; if mode.experiment != nil { userPaused = true } }
    mutating func finishReset() { resetting = false }
    mutating func selectMode(_ mode: SimulationMode) {
        if self.mode == .freePlay { freePlayTuning = tuning; freePlayField = field; freePlayOptions = displayOptions }
        self.mode = mode
        if let lesson = mode.experiment {
            adjustment = lesson.defaultAdjustment; tuning = .lesson
            field = lesson.defaultField; displayOptions = .lesson; userPaused = true
        } else {
            adjustment = nil; tuning = freePlayTuning; field = freePlayField; displayOptions = freePlayOptions; userPaused = false
        }
        beginReset()
    }
    @discardableResult mutating func setExperimentAdjustment(_ value: ExperimentAdjustment) -> Bool {
        guard let lesson = mode.experiment, lesson.choices.contains(value) else { return false }
        adjustment = value; beginReset(); return true
    }
}
