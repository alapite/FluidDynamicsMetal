import Foundation

enum DisplayField: Int, CaseIterable {
    case density, pressure, velocity, vorticity
}

enum TuningControl: Int, CaseIterable {
    case force, dye, swirl, fade

    var title: String {
        switch self {
        case .force: return "Force"
        case .dye: return "Dye"
        case .swirl: return "Swirl"
        case .fade: return "Fade"
        }
    }
}

struct SimulationTuning {
    private static func bounded(_ value: Float, default fallback: Float, min lower: Float, max upper: Float) -> Float {
        guard value.isFinite else { return fallback }
        return Swift.min(upper, Swift.max(lower, value))
    }

    var force: Float = 1 {
        didSet { force = SimulationTuning.bounded(force, default: 1, min: 0, max: 2) }
    }
    var dye: Float = 0.8 {
        didSet { dye = SimulationTuning.bounded(dye, default: 0.8, min: 0, max: 2) }
    }
    var radius: Float = 150 {
        didSet { radius = SimulationTuning.bounded(radius, default: 150, min: 1, max: 400) }
    }
    var swirl: Float = 0.4 {
        didSet { swirl = SimulationTuning.bounded(swirl, default: 0.4, min: 0, max: 2) }
    }
    var retention: Float = 0.998 {
        didSet { retention = SimulationTuning.bounded(retention, default: 0.998, min: 0, max: 1) }
    }
    var pressureIterations: Int = 40 {
        didSet { pressureIterations = Swift.min(80, Swift.max(1, pressureIterations)) }
    }

    mutating func setPosition(_ position: Float, for control: TuningControl) {
        let fallback: Float
        switch control {
        case .force: fallback = 0.5
        case .dye: fallback = 0.4
        case .swirl: fallback = 0.2
        case .fade: fallback = 0.17
        }
        let p = SimulationTuning.bounded(position, default: fallback, min: 0, max: 1)
        switch control {
        case .force: force = 2 * p
        case .dye: dye = 2 * p
        case .swirl: swirl = 2 * p
        case .fade:
            retention = p == 0.17 ? 0.998 : p < 0.17
                ? 0.9995 - 0.0015 * (p / 0.17)
                : 0.998 - 0.0075 * ((p - 0.17) / 0.83)
        }
    }

    func position(for control: TuningControl) -> Float {
        switch control {
        case .force: return force / 2
        case .dye: return dye / 2
        case .swirl: return swirl / 2
        case .fade:
            let p: Float = retention >= 0.998
                ? (0.9995 - retention) * (0.17 / 0.0015)
                : 0.17 + (0.998 - retention) * (0.83 / 0.0075)
            return Swift.min(1, Swift.max(0, p))
        }
    }
}

struct SimulationState {
    private(set) var field: DisplayField = .density
    private(set) var userPaused = false
    private(set) var inactive = false
    var tuning = SimulationTuning()

    var shouldAdvance: Bool { return !userPaused && !inactive }

    mutating func nextField() {
        field = DisplayField(rawValue: (field.rawValue + 1) % DisplayField.allCases.count)!
    }

    mutating func selectField(_ field: DisplayField) { self.field = field }

    mutating func togglePause() { userPaused = !userPaused }
    mutating func resignActive() { inactive = true }
    mutating func becomeActive() { inactive = false }
    mutating func resetTuning() { tuning = SimulationTuning() }
}
