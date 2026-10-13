import Foundation
import simd

/// Pure deterministic construction, in normalized top-left coordinates.
enum ExperimentRecipes {
    static let gridSize = 256
    static let advectionCenter = SIMD2<Float>(0.5, 0.5)
    static let advectionSigma: Float = 0.22
    static let advectionDye = SIMD2<Float>(0.7, 0.5)
    static let advectionDyeSigma: Float = 0.035
    static let vortexCenters = [SIMD2<Float>(0.35, 0.5), SIMD2<Float>(0.65, 0.5)]
    static let vortexSigma: Float = 0.10
    static let vortexDyeSigma: Float = 0.03
    static let stirringCenters = [SIMD2<Float>(0.4, 0.5), SIMD2<Float>(0.6, 0.5)]
    static let stirringSigma: Float = 0.16
    static let phaseLength = 120
    static let impulse: Float = 0.04
    static func smooth(_ a: Float, _ b: Float, _ x: Float) -> Float {
        let t = min(1, max(0, (x - a) / (b - a))); return t * t * (3 - 2 * t)
    }
    static func gaussian(_ p: SIMD2<Float>, _ center: SIMD2<Float>, _ sigma: Float) -> Float {
        exp(-simd_length_squared(p - center) / (2 * sigma * sigma))
    }
    static func vortexTemplate(size: Int = gridSize, centers: [SIMD2<Float>], signs: [Float], sigma: Float, speed: Float = 1) -> [SIMD2<Float>] {
        var psi = [Float](repeating: 0, count: size * size)
        for y in 0..<size { for x in 0..<size {
            let p = (SIMD2<Float>(Float(x), Float(y)) + 0.5) / Float(size)
            let boundary = smooth(0, 0.08, p.x) * smooth(0, 0.08, 1 - p.x) * smooth(0, 0.08, p.y) * smooth(0, 0.08, 1 - p.y)
            psi[y * size + x] = boundary * zip(centers, signs).reduce(Float(0)) { $0 + $1.1 * gaussian(p, $1.0, sigma) }
        } }
        var velocity = [SIMD2<Float>](repeating: .zero, count: size * size)
        var maximum: Float = 0
        for y in 2..<(size - 2) { for x in 2..<(size - 2) {
            let i = y * size + x
            velocity[i] = SIMD2<Float>(psi[i + size] - psi[i - size], psi[i - 1] - psi[i + 1]) * 0.5
            maximum = max(maximum, simd_length(velocity[i]))
        } }
        if maximum > 0 { for i in velocity.indices { velocity[i] *= speed / maximum } }
        return velocity
    }
    static func seed(_ id: ExperimentID, adjustment: ExperimentAdjustment) -> (velocity: [SIMD2<Float>], dye: [SIMD2<Float>]) {
        let n = gridSize
        var velocity = [SIMD2<Float>](repeating: .zero, count: n * n)
        switch adjustment {
        case let .speed(speed): velocity = vortexTemplate(centers: [advectionCenter], signs: [1], sigma: advectionSigma, speed: speed.rawValue)
        case let .rotation(pair): velocity = vortexTemplate(centers: vortexCenters, signs: [1, pair == .same ? 1 : -1], sigma: vortexSigma)
        case .strength: break
        }
        var dye = [SIMD2<Float>](repeating: .zero, count: n * n)
        for y in 0..<n { for x in 0..<n {
            let p = (SIMD2<Float>(Float(x), Float(y)) + 0.5) / Float(n)
            let c: Float
            switch id {
            case .advection: c = gaussian(p, advectionDye, advectionDyeSigma)
            case .interactingVortices:
                c = vortexCenters.reduce(Float(0)) { $0 + gaussian(p, $1 + SIMD2<Float>(0, 0.1), vortexDyeSigma) }
            case .dyeStretching:
                let edge = 2 / Float(n)
                c = smooth(0.48, 0.48 + edge, p.x) * (1 - smooth(0.52 - edge, 0.52, p.x)) * smooth(0.2, 0.2 + edge, p.y) * (1 - smooth(0.8 - edge, 0.8, p.y))
            }
            dye[y * n + x] = SIMD2<Float>(c, 0)
        } }
        return (velocity, dye)
    }
    static func stirringAmplitude(step: Int, adjustment: ExperimentAdjustment?) -> Float {
        guard step >= 0, step < 2 * phaseLength, case let .strength(strength) = adjustment else { return 0 }
        let phase = Float(step % phaseLength) + 0.5
        let envelope = sin(Float.pi * phase / Float(phaseLength))
        return impulse * strength.rawValue * envelope * envelope
    }
}
