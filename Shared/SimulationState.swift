import Foundation

enum DisplayField: Int, CaseIterable {
    case density, pressure, velocity, vorticity
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
