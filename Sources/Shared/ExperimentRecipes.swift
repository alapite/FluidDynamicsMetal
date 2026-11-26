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
        return (velocity, seedDye(id))
    }

    private static func seedDye(_ id: ExperimentID) -> [SIMD2<Float>] {
        let n = gridSize
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
        return dye
    }
    static func stirringAmplitude(step: Int, adjustment: ExperimentAdjustment?) -> Float {
        guard step >= 0, step < 2 * phaseLength, case let .strength(strength) = adjustment else { return 0 }
        let phase = Float(step % phaseLength) + 0.5
        let envelope = sin(Float.pi * phase / Float(phaseLength))
        return impulse * strength.rawValue * envelope * envelope
    }
}

/// Matches the Metal vertex buffer layout. Positions and accumulated lengths are in normalized canvas units.
struct StartingOutlineSegment {
    let start: SIMD2<Float>
    let end: SIMD2<Float>
    let startMiter: SIMD2<Float>
    let endMiter: SIMD2<Float>
    let distanceAtStart: Float
    let contourLength: Float
}

extension ExperimentRecipes {
    private static let advectionOutline = makeStartingOutline(.advection)
    private static let stretchingOutline = makeStartingOutline(.dyeStretching)

    static func startingOutline(_ lesson: ExperimentID) -> [StartingOutlineSegment] {
        switch lesson {
        case .advection: return advectionOutline
        case .dyeStretching: return stretchingOutline
        case .interactingVortices: return []
        }
    }

    private static func makeStartingOutline(_ lesson: ExperimentID) -> [StartingOutlineSegment] {
        let n = gridSize
        let dye = seedDye(lesson)
        let threshold: Float = 0.5
        var crossings: [Int: SIMD2<Float>] = [:]
        var connections: [SIMD2<Int>] = []
        // A crossing belongs to a grid edge shared by its adjacent squares. Use the
        // first cell index and edge direction as the key so paths join exactly.
        for y in 0..<(n - 1) {
            for x in 0..<(n - 1) {
                let cell = y * n + x
                let corners = [cell, cell + 1, cell + n + 1, cell + n]
                let values = corners.map { dye[$0].x }
                let inside = values.map { $0 >= threshold }
                if inside.allSatisfy({ $0 }) || inside.allSatisfy({ !$0 }) { continue }

                // Edges are top, right, bottom, left. Horizontal edges run
                // left to right and vertical edges run top to bottom.
                let first = [0, 1, 3, 0]
                let second = [1, 2, 2, 3]
                var edges: [Int] = []
                for edge in 0..<4 {
                    let a = first[edge], b = second[edge]
                    guard inside[a] != inside[b] else { continue }
                    let horizontal = edge.isMultiple(of: 2)
                    let index = corners[a]
                    let key = index * 2 + (horizontal ? 0 : 1)
                    let fraction = (threshold - values[a]) / (values[b] - values[a])
                    let origin = SIMD2<Float>(Float(index % n) + 0.5, Float(index / n) + 0.5)
                    let offset = horizontal ? SIMD2<Float>(fraction, 0) : SIMD2<Float>(0, fraction)
                    crossings[key] = (origin + offset) / Float(n)
                    edges.append(key)
                }
                if edges.count == 2 {
                    connections.append(SIMD2(edges[0], edges[1]))
                } else if edges.count == 4 {
                    // The bilinear value at the center resolves a saddle.
                    let centerInside = values.reduce(0, +) * 0.25 >= threshold
                    let neighbor = centerInside == inside[0] ? 1 : 3
                    connections.append(SIMD2(edges[0], edges[neighbor]))
                    connections.append(SIMD2(edges[2], edges[4 - neighbor]))
                }
            }
        }

        var incident: [Int: [Int]] = [:]
        for (index, connection) in connections.enumerated() {
            incident[connection.x, default: []].append(index)
            incident[connection.y, default: []].append(index)
        }
        // Walk open paths from their endpoints first, then the remaining closed loops.
        let endpoints = incident.keys.filter { incident[$0]?.count == 1 }.sorted()
        let starts = endpoints + connections.map(\.x)
        var visited: Set<Int> = []
        var result: [StartingOutlineSegment] = []
        for start in starts {
            var edge = start
            var distance: Float = 0
            var path: [(start: SIMD2<Float>, end: SIMD2<Float>, distance: Float)] = []
            while let index = incident[edge]?.first(where: { !visited.contains($0) }) {
                visited.insert(index)
                let connection = connections[index]
                let next = connection.x == edge ? connection.y : connection.x
                let a = crossings[edge]!, b = crossings[next]!
                let length = simd_distance(a, b)
                if length > 0 {
                    path.append((a, b, distance))
                    distance += length
                }
                edge = next
            }
            guard let firstSegment = path.first, let lastSegment = path.last else { continue }
            let normals = path.map {
                let direction = simd_normalize($0.end - $0.start)
                return SIMD2<Float>(-direction.y, direction.x)
            }
            let closed = firstSegment.start == lastSegment.end
            func miter(_ a: SIMD2<Float>, _ b: SIMD2<Float>) -> SIMD2<Float> {
                let bisector = a + b
                guard simd_length_squared(bisector) > 0.000001 else { return b }
                let direction = simd_normalize(bisector)
                return direction / max(0.5, simd_dot(direction, b))
            }
            // Adjacent quads share the same cross section at the join, so the
            // translucent stroke never blends over itself at each cell crossing.
            for (index, segment) in path.enumerated() {
                let normal = normals[index]
                let before = index > 0 ? normals[index - 1] : (closed ? normals[normals.count - 1] : normal)
                let after = index + 1 < normals.count ? normals[index + 1] : (closed ? normals[0] : normal)
                result.append(StartingOutlineSegment(start: segment.start, end: segment.end,
                    startMiter: miter(before, normal), endMiter: miter(normal, after),
                    distanceAtStart: segment.distance, contourLength: distance))
            }
        }
        return result
    }
}
