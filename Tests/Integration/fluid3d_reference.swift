import CryptoKit
import Foundation

private let expectedContractHash = "a7768571a996d5b9520aff5095100bb52fb67f96560f99633d081c04a3a9e01b"
private let projectionLimit = 1.0e-5
private let iterationLimit = 320

private enum ReferenceError: Error, CustomStringConvertible {
    case usage(String)
    case failed(String)

    var description: String {
        switch self {
        case .usage(let message), .failed(let message): return message
        }
    }
}

private struct Grid {
    let nx: Int
    let ny: Int
    let nz: Int
    let h: Double

    var cellCount: Int { nx * ny * nz }
    var cellShape: [Int] { [nx, ny, nz] }

    func cell(_ i: Int, _ j: Int, _ k: Int) -> Int {
        (k * ny + j) * nx + i
    }

    func u(_ i: Int, _ j: Int, _ k: Int) -> Int {
        (k * ny + j) * (nx + 1) + i
    }

    func v(_ i: Int, _ j: Int, _ k: Int) -> Int {
        (k * (ny + 1) + j) * nx + i
    }

    func w(_ i: Int, _ j: Int, _ k: Int) -> Int {
        (k * ny + j) * nx + i
    }

    var uCount: Int { (nx + 1) * ny * nz }
    var vCount: Int { nx * (ny + 1) * nz }
    var wCount: Int { nx * ny * (nz + 1) }
}

private struct Vector3 {
    var x: Double
    var y: Double
    var z: Double

    subscript(_ axis: Int) -> Double {
        get {
            switch axis {
            case 0: return x
            case 1: return y
            default: return z
            }
        }
        set {
            switch axis {
            case 0: x = newValue
            case 1: y = newValue
            default: z = newValue
            }
        }
    }

    var length: Double { sqrt(x * x + y * y + z * z) }

    static func + (lhs: Vector3, rhs: Vector3) -> Vector3 {
        Vector3(x: lhs.x + rhs.x, y: lhs.y + rhs.y, z: lhs.z + rhs.z)
    }

    static func - (lhs: Vector3, rhs: Vector3) -> Vector3 {
        Vector3(x: lhs.x - rhs.x, y: lhs.y - rhs.y, z: lhs.z - rhs.z)
    }

    static func * (lhs: Vector3, rhs: Double) -> Vector3 {
        Vector3(x: lhs.x * rhs, y: lhs.y * rhs, z: lhs.z * rhs)
    }
}

private struct FaceVelocity {
    var u: [Double]
    var v: [Double]
    var w: [Double]

    init(_ grid: Grid) {
        u = Array(repeating: 0, count: grid.uCount)
        v = Array(repeating: 0, count: grid.vCount)
        w = Array(repeating: 0, count: grid.wCount)
    }

    mutating func enforceWalls(_ grid: Grid) {
        for k in 0..<grid.nz {
            for j in 0..<grid.ny {
                u[grid.u(0, j, k)] = 0
                u[grid.u(grid.nx, j, k)] = 0
            }
        }
        for k in 0..<grid.nz {
            for i in 0..<grid.nx {
                v[grid.v(i, 0, k)] = 0
                v[grid.v(i, grid.ny, k)] = 0
            }
        }
        for j in 0..<grid.ny {
            for i in 0..<grid.nx {
                w[grid.w(i, j, 0)] = 0
                w[grid.w(i, j, grid.nz)] = 0
            }
        }
    }

    var allFinite: Bool { u.allSatisfy { $0.isFinite } && v.allSatisfy { $0.isFinite } && w.allSatisfy { $0.isFinite } }
    var maxAbs: Double { max(normInf(u), max(normInf(v), normInf(w))) }
}

private struct SolverResult {
    let q: [Double]
    let trueResidual: [Double]
    let iterations: Int
    let converged: Bool
    let capHit: Bool
    let finite: Bool
    let failure: String?
}

private struct ProjectionResult {
    let input: FaceVelocity
    let projected: FaceVelocity
    let rhs: [Double]
    let pressure: [Double]
    let divergence: [Double]
    let trueResidual: [Double]
    let iterations: Int
    let converged: Bool
    let capHit: Bool
    let finite: Bool
    let inputDivergenceDT: Double
    let projectedDivergenceDT: Double
    let residualDT: Double
    let identityDTError: Double
    let divergenceReduction: Double
    let pressureMeanAbs: Double
    let maxWallFlux: Double
    let expectedPressureError: Double?
    let failure: String?
}

private func index3D(_ i: Int, _ j: Int, _ k: Int, _ nx: Int, _ ny: Int) -> Int {
    (k * ny + j) * nx + i
}

private func normInf(_ values: [Double]) -> Double {
    values.reduce(0) { max($0, abs($1)) }
}

private func mean(_ values: [Double]) -> Double {
    values.reduce(0, +) / Double(values.count)
}

private func dot(_ lhs: [Double], _ rhs: [Double]) -> Double {
    var result = 0.0
    for index in lhs.indices { result += lhs[index] * rhs[index] }
    return result
}

private func allFinite(_ values: [Double]) -> Bool {
    values.allSatisfy { $0.isFinite }
}

private func within(_ actual: Double, _ expected: Double, absolute: Double, relative: Double = 0) -> Bool {
    guard actual.isFinite, expected.isFinite else { return false }
    return abs(actual - expected) <= absolute + relative * abs(expected)
}

private func subtractMean(_ values: inout [Double]) {
    let center = mean(values)
    for index in values.indices { values[index] -= center }
}

private func divergence(_ grid: Grid, _ velocity: FaceVelocity) -> [Double] {
    var result = Array(repeating: 0.0, count: grid.cellCount)
    let inverseH = 1 / grid.h
    for k in 0..<grid.nz {
        for j in 0..<grid.ny {
            for i in 0..<grid.nx {
                result[grid.cell(i, j, k)] = (
                    velocity.u[grid.u(i + 1, j, k)] - velocity.u[grid.u(i, j, k)]
                    + velocity.v[grid.v(i, j + 1, k)] - velocity.v[grid.v(i, j, k)]
                    + velocity.w[grid.w(i, j, k + 1)] - velocity.w[grid.w(i, j, k)]
                ) * inverseH
            }
        }
    }
    return result
}

private func gradient(_ grid: Grid, _ q: [Double]) -> FaceVelocity {
    var result = FaceVelocity(grid)
    let inverseH = 1 / grid.h
    if grid.nx > 1 {
        for k in 0..<grid.nz {
            for j in 0..<grid.ny {
                for i in 1..<grid.nx {
                    result.u[grid.u(i, j, k)] = (q[grid.cell(i, j, k)] - q[grid.cell(i - 1, j, k)]) * inverseH
                }
            }
        }
    }
    if grid.ny > 1 {
        for k in 0..<grid.nz {
            for j in 1..<grid.ny {
                for i in 0..<grid.nx {
                    result.v[grid.v(i, j, k)] = (q[grid.cell(i, j, k)] - q[grid.cell(i, j - 1, k)]) * inverseH
                }
            }
        }
    }
    if grid.nz > 1 {
        for k in 1..<grid.nz {
            for j in 0..<grid.ny {
                for i in 0..<grid.nx {
                    result.w[grid.w(i, j, k)] = (q[grid.cell(i, j, k)] - q[grid.cell(i, j, k - 1)]) * inverseH
                }
            }
        }
    }
    return result
}

// This is intentionally not formed by calling divergence(gradient(q)).
private func applyNeighbourStencil(_ grid: Grid, _ q: [Double]) -> [Double] {
    var result = Array(repeating: 0.0, count: grid.cellCount)
    for k in 0..<grid.nz {
        for j in 0..<grid.ny {
            for i in 0..<grid.nx {
                let center = q[grid.cell(i, j, k)]
                var degree = 0.0
                var neighbours = 0.0
                if i > 0 { degree += 1; neighbours += q[grid.cell(i - 1, j, k)] }
                if i + 1 < grid.nx { degree += 1; neighbours += q[grid.cell(i + 1, j, k)] }
                if j > 0 { degree += 1; neighbours += q[grid.cell(i, j - 1, k)] }
                if j + 1 < grid.ny { degree += 1; neighbours += q[grid.cell(i, j + 1, k)] }
                if k > 0 { degree += 1; neighbours += q[grid.cell(i, j, k - 1)] }
                if k + 1 < grid.nz { degree += 1; neighbours += q[grid.cell(i, j, k + 1)] }
                result[grid.cell(i, j, k)] = degree * center - neighbours
            }
        }
    }
    return result
}

private func applyDivergenceGradient(_ grid: Grid, _ q: [Double]) -> [Double] {
    let grad = gradient(grid, q)
    let div = divergence(grid, grad)
    return div.map { -grid.h * grid.h * $0 }
}

private func precondition(_ grid: Grid, _ residual: [Double]) -> [Double] {
    var result = Array(repeating: 0.0, count: grid.cellCount)
    for k in 0..<grid.nz {
        for j in 0..<grid.ny {
            for i in 0..<grid.nx {
                var degree = 0.0
                if i > 0 { degree += 1 }
                if i + 1 < grid.nx { degree += 1 }
                if j > 0 { degree += 1 }
                if j + 1 < grid.ny { degree += 1 }
                if k > 0 { degree += 1 }
                if k + 1 < grid.nz { degree += 1 }
                result[grid.cell(i, j, k)] = residual[grid.cell(i, j, k)] / degree
            }
        }
    }
    subtractMean(&result)
    return result
}

private func solvePCG(_ grid: Grid, _ originalRHS: [Double], targetResidual: Double, cap: Int,
                      compatibilityScale: Double = 0) -> SolverResult {
    let rhsNorm = normInf(originalRHS)
    let compatibilityLimit = 64 * Double.ulpOfOne * max(rhsNorm, max(compatibilityScale, 1e-30))
    let rhsMean = mean(originalRHS)
    guard originalRHS.count == grid.cellCount, allFinite(originalRHS) else {
        return SolverResult(q: Array(repeating: 0, count: grid.cellCount), trueResidual: originalRHS,
                            iterations: 0, converged: false, capHit: false, finite: false, failure: "nonfinite or malformed RHS")
    }
    guard abs(rhsMean) <= compatibilityLimit else {
        return SolverResult(q: Array(repeating: 0, count: grid.cellCount), trueResidual: originalRHS,
                            iterations: 0, converged: false, capHit: false, finite: false,
                            failure: "closed-box RHS compatibility mean exceeds roundoff bound")
    }

    var correctedRHS = originalRHS
    for index in correctedRHS.indices { correctedRHS[index] -= rhsMean }
    var q = Array(repeating: 0.0, count: grid.cellCount)
    var residual = correctedRHS
    var trueResidual = originalRHS
    if normInf(residual) <= targetResidual {
        return SolverResult(q: q, trueResidual: trueResidual, iterations: 0,
                            converged: normInf(trueResidual) <= targetResidual, capHit: false,
                            finite: allFinite(trueResidual), failure: nil)
    }

    var z = precondition(grid, residual)
    var direction = z
    var residualZ = dot(residual, z)
    var iteration = 0
    var restarts = 0
    var failure: String?

    while iteration < cap {
        iteration += 1
        let applied = applyNeighbourStencil(grid, direction)
        let denominator = dot(direction, applied)
        guard denominator.isFinite, denominator > 0, residualZ.isFinite, residualZ > 0 else {
            failure = "nonpositive or nonfinite PCG denominator"
            break
        }
        let alpha = residualZ / denominator
        guard alpha.isFinite else { failure = "nonfinite PCG alpha"; break }
        for index in q.indices {
            q[index] += alpha * direction[index]
            residual[index] -= alpha * applied[index]
        }
        subtractMean(&q)
        subtractMean(&residual)
        guard allFinite(q), allFinite(residual) else { failure = "nonfinite PCG iterate or residual"; break }

        if normInf(residual) <= targetResidual {
            let appliedQ = applyNeighbourStencil(grid, q)
            trueResidual = zip(originalRHS, appliedQ).map { $0.0 - $0.1 }
            if normInf(trueResidual) <= targetResidual {
                return SolverResult(q: q, trueResidual: trueResidual, iterations: iteration,
                                    converged: true, capHit: false,
                                    finite: allFinite(q) && allFinite(trueResidual), failure: nil)
            }
            // Recursive convergence was optimistic: replace with the independently recomputed true residual.
            residual = trueResidual
            subtractMean(&residual)
            z = precondition(grid, residual)
            direction = z
            residualZ = dot(residual, z)
            restarts += 1
            if !residualZ.isFinite || residualZ <= 0 || restarts > cap {
                failure = "PCG true-residual restart breakdown"
                break
            }
            continue
        }

        let nextZ = precondition(grid, residual)
        let nextResidualZ = dot(residual, nextZ)
        guard nextResidualZ.isFinite, nextResidualZ > 0 else {
            failure = "nonpositive or nonfinite preconditioned residual"
            break
        }
        let beta = nextResidualZ / residualZ
        guard beta.isFinite else { failure = "nonfinite PCG beta"; break }
        for index in direction.indices { direction[index] = nextZ[index] + beta * direction[index] }
        subtractMean(&direction)
        z = nextZ
        residualZ = nextResidualZ
    }

    let appliedQ = applyNeighbourStencil(grid, q)
    trueResidual = zip(originalRHS, appliedQ).map { $0.0 - $0.1 }
    let finite = allFinite(q) && allFinite(trueResidual)
    let converged = finite && normInf(trueResidual) <= targetResidual
    return SolverResult(q: q, trueResidual: trueResidual, iterations: iteration,
                        converged: converged, capHit: iteration >= cap && !converged,
                        finite: finite, failure: failure ?? (converged ? nil : "iteration cap reached before true-residual tolerance"))
}

private func subtractGradient(_ grid: Grid, _ velocity: FaceVelocity, _ q: [Double]) -> FaceVelocity {
    let grad = gradient(grid, q)
    var result = FaceVelocity(grid)
    for index in result.u.indices { result.u[index] = velocity.u[index] - grad.u[index] }
    for index in result.v.indices { result.v[index] = velocity.v[index] - grad.v[index] }
    for index in result.w.indices { result.w[index] = velocity.w[index] - grad.w[index] }
    result.enforceWalls(grid)
    return result
}

private func maxWallFlux(_ grid: Grid, _ velocity: FaceVelocity) -> Double {
    var result = 0.0
    for k in 0..<grid.nz {
        for j in 0..<grid.ny {
            result = max(result, abs(velocity.u[grid.u(0, j, k)]))
            result = max(result, abs(velocity.u[grid.u(grid.nx, j, k)]))
        }
    }
    for k in 0..<grid.nz {
        for i in 0..<grid.nx {
            result = max(result, abs(velocity.v[grid.v(i, 0, k)]))
            result = max(result, abs(velocity.v[grid.v(i, grid.ny, k)]))
        }
    }
    for j in 0..<grid.ny {
        for i in 0..<grid.nx {
            result = max(result, abs(velocity.w[grid.w(i, j, 0)]))
            result = max(result, abs(velocity.w[grid.w(i, j, grid.nz)]))
        }
    }
    return result
}

private func maxDifference(_ lhs: [Double], _ rhs: [Double]) -> Double {
    zip(lhs, rhs).reduce(0) { max($0, abs($1.0 - $1.1)) }
}

private func project(_ grid: Grid, _ velocity: FaceVelocity, dt: Double, cap: Int = iterationLimit,
                     expectedPressure: [Double]? = nil) -> ProjectionResult {
    let inputDivergence = divergence(grid, velocity)
    let rhs = inputDivergence.map { -grid.h * grid.h * $0 }
    let target = projectionLimit * grid.h * grid.h / dt
    let solved = solvePCG(grid, rhs, targetResidual: target, cap: cap,
                          compatibilityScale: grid.h * velocity.maxAbs)
    let corrected = subtractGradient(grid, velocity, solved.q)
    let outputDivergence = divergence(grid, corrected)
    let identity = zip(outputDivergence, solved.trueResidual).reduce(0.0) {
        max($0, abs($1.0 + $1.1 / (grid.h * grid.h)))
    }
    let inputDT = dt * normInf(inputDivergence)
    let outputDT = dt * normInf(outputDivergence)
    let residualDT = dt * normInf(solved.trueResidual) / (grid.h * grid.h)
    let reduction = outputDT > 0 ? inputDT / outputDT : (inputDT > 0 ? Double.greatestFiniteMagnitude : 1)
    let expectedError: Double?
    if let expectedPressure {
        var expected = expectedPressure
        subtractMean(&expected)
        expectedError = maxDifference(solved.q, expected)
    } else {
        expectedError = nil
    }
    let finite = solved.finite && corrected.allFinite && allFinite(outputDivergence)
        && inputDT.isFinite && outputDT.isFinite && residualDT.isFinite && identity.isFinite
    let converged = solved.converged && outputDT <= projectionLimit && residualDT <= projectionLimit
        && identity <= 1e-10 && maxWallFlux(grid, corrected) == 0
    return ProjectionResult(input: velocity, projected: corrected, rhs: rhs, pressure: solved.q,
                            divergence: outputDivergence, trueResidual: solved.trueResidual,
                            iterations: solved.iterations, converged: converged, capHit: solved.capHit,
                            finite: finite, inputDivergenceDT: inputDT, projectedDivergenceDT: outputDT,
                            residualDT: residualDT, identityDTError: dt * identity,
                            divergenceReduction: reduction, pressureMeanAbs: abs(mean(solved.q)),
                            maxWallFlux: maxWallFlux(grid, corrected), expectedPressureError: expectedError,
                            failure: solved.failure ?? (converged ? nil : "projection acceptance threshold failed"))
}

private func makeGradientVelocity(_ grid: Grid, _ q: [Double]) -> FaceVelocity {
    let result = gradient(grid, q)
    return result
}

private func makeMixedVelocity(_ grid: Grid) -> FaceVelocity {
    var result = FaceVelocity(grid)
    let pi = Double.pi
    for k in 0..<grid.nz {
        for j in 0..<grid.ny {
            for i in 0...grid.nx {
                let x = Double(i) / Double(grid.nx)
                let y = (Double(j) + 0.5) / Double(grid.ny)
                let z = (Double(k) + 0.5) / Double(grid.nz)
                result.u[grid.u(i, j, k)] = 0.11 * sin(pi * x) * cos(2 * pi * y) * cos(3 * pi * z)
                    + 0.03 * sin(3 * pi * x) * cos(pi * y) * sin(2 * pi * z)
            }
        }
    }
    for k in 0..<grid.nz {
        for j in 0...grid.ny {
            for i in 0..<grid.nx {
                let x = (Double(i) + 0.5) / Double(grid.nx)
                let y = Double(j) / Double(grid.ny)
                let z = (Double(k) + 0.5) / Double(grid.nz)
                result.v[grid.v(i, j, k)] = 0.07 * cos(2 * pi * x) * sin(pi * y) * cos(4 * pi * z)
                    + 0.02 * sin(pi * x) * sin(2 * pi * y) * cos(pi * z)
            }
        }
    }
    for k in 0...grid.nz {
        for j in 0..<grid.ny {
            for i in 0..<grid.nx {
                let x = (Double(i) + 0.5) / Double(grid.nx)
                let y = (Double(j) + 0.5) / Double(grid.ny)
                let z = Double(k) / Double(grid.nz)
                result.w[grid.w(i, j, k)] = 0.09 * cos(pi * x) * cos(2 * pi * y) * sin(pi * z)
                    + 0.025 * sin(2 * pi * x) * cos(pi * y) * sin(3 * pi * z)
            }
        }
    }
    result.enforceWalls(grid)
    return result
}

private func makeWallEdgeCornerVelocity(_ grid: Grid) -> FaceVelocity {
    var result = FaceVelocity(grid)
    for k in 0..<grid.nz {
        for j in 0..<grid.ny {
            for i in 1..<grid.nx where i == 1 || i == grid.nx - 1 || j == 0 || j == grid.ny - 1 || k == 0 || k == grid.nz - 1 {
                result.u[grid.u(i, j, k)] = 0.02 * Double(1 + i + 3 * j + 5 * k)
            }
        }
    }
    for k in 0..<grid.nz {
        for j in 1..<grid.ny {
            for i in 0..<grid.nx where j == 1 || j == grid.ny - 1 || i == 0 || i == grid.nx - 1 || k == 0 || k == grid.nz - 1 {
                result.v[grid.v(i, j, k)] = -0.015 * Double(2 + 2 * i + j + 4 * k)
            }
        }
    }
    for k in 1..<grid.nz {
        for j in 0..<grid.ny {
            for i in 0..<grid.nx where k == 1 || k == grid.nz - 1 || i == 0 || i == grid.nx - 1 || j == 0 || j == grid.ny - 1 {
                result.w[grid.w(i, j, k)] = 0.0125 * Double(3 + 4 * i + 2 * j + k)
            }
        }
    }
    result.enforceWalls(grid)
    return result
}

private func makeDiscreteDivergenceFree(_ grid: Grid) -> FaceVelocity {
    var result = FaceVelocity(grid)
    func psi(_ i: Int, _ j: Int, _ k: Int) -> Double {
        sin(Double.pi * Double(i) / Double(grid.nx))
            * sin(2 * Double.pi * Double(j) / Double(grid.ny))
            * sin(Double.pi * (Double(k) + 0.5) / Double(grid.nz))
    }
    for k in 0..<grid.nz {
        for j in 0..<grid.ny {
            for i in 0...grid.nx {
                result.u[grid.u(i, j, k)] = (psi(i, j + 1, k) - psi(i, j, k)) / grid.h
            }
        }
    }
    for k in 0..<grid.nz {
        for j in 0...grid.ny {
            for i in 0..<grid.nx {
                result.v[grid.v(i, j, k)] = -(psi(i + 1, j, k) - psi(i, j, k)) / grid.h
            }
        }
    }
    result.enforceWalls(grid)
    return result
}

private func manufacturedCosinePressure(_ grid: Grid) -> [Double] {
    var result = Array(repeating: 0.0, count: grid.cellCount)
    for k in 0..<grid.nz {
        for j in 0..<grid.ny {
            for i in 0..<grid.nx {
                let x = (Double(i) + 0.5) / Double(grid.nx)
                let y = (Double(j) + 0.5) / Double(grid.ny)
                let z = (Double(k) + 0.5) / Double(grid.nz)
                result[grid.cell(i, j, k)] = cos(Double.pi * x) * cos(2 * Double.pi * y) * cos(3 * Double.pi * z)
            }
        }
    }
    return result
}

private func alternatingPressure(_ grid: Grid) -> [Double] {
    var result = Array(repeating: 0.0, count: grid.cellCount)
    for k in 0..<grid.nz {
        for j in 0..<grid.ny {
            for i in 0..<grid.nx {
                result[grid.cell(i, j, k)] = (i + j + k).isMultiple(of: 2) ? 0.125 : -0.125
            }
        }
    }
    return result
}

private func directFixedGaugeSolve(_ grid: Grid, _ rhs: [Double]) -> [Double] {
    let fixedIndex = 0
    var variableIndex = Array(repeating: -1, count: grid.cellCount)
    var cells: [Int] = []
    for cell in 0..<grid.cellCount where cell != fixedIndex {
        variableIndex[cell] = cells.count
        cells.append(cell)
    }
    let count = cells.count
    var matrix = Array(repeating: 0.0, count: count * count)
    var values = Array(repeating: 0.0, count: count)

    for (row, cell) in cells.enumerated() {
        let i = cell % grid.nx
        let j = (cell / grid.nx) % grid.ny
        let k = cell / (grid.nx * grid.ny)
        var degree = 0.0
        var adjacent: [Int] = []
        if i > 0 { degree += 1; adjacent.append(grid.cell(i - 1, j, k)) }
        if i + 1 < grid.nx { degree += 1; adjacent.append(grid.cell(i + 1, j, k)) }
        if j > 0 { degree += 1; adjacent.append(grid.cell(i, j - 1, k)) }
        if j + 1 < grid.ny { degree += 1; adjacent.append(grid.cell(i, j + 1, k)) }
        if k > 0 { degree += 1; adjacent.append(grid.cell(i, j, k - 1)) }
        if k + 1 < grid.nz { degree += 1; adjacent.append(grid.cell(i, j, k + 1)) }
        matrix[row * count + row] = degree
        values[row] = rhs[cell]
        for neighbour in adjacent where neighbour != fixedIndex {
            matrix[row * count + variableIndex[neighbour]] = -1
        }
    }

    for column in 0..<count {
        var pivot = column
        for row in (column + 1)..<count where abs(matrix[row * count + column]) > abs(matrix[pivot * count + column]) {
            pivot = row
        }
        precondition(abs(matrix[pivot * count + column]) > 1e-14, "singular fixed-gauge direct matrix")
        if pivot != column {
            for c in column..<count { matrix.swapAt(column * count + c, pivot * count + c) }
            values.swapAt(column, pivot)
        }
        let diagonal = matrix[column * count + column]
        for row in (column + 1)..<count {
            let factor = matrix[row * count + column] / diagonal
            matrix[row * count + column] = 0
            if column + 1 < count {
                for c in (column + 1)..<count {
                    matrix[row * count + c] -= factor * matrix[column * count + c]
                }
            }
            values[row] -= factor * values[column]
        }
    }

    var solution = Array(repeating: 0.0, count: count)
    for row in stride(from: count - 1, through: 0, by: -1) {
        var value = values[row]
        if row + 1 < count {
            for column in (row + 1)..<count { value -= matrix[row * count + column] * solution[column] }
        }
        solution[row] = value / matrix[row * count + row]
    }
    var full = Array(repeating: 0.0, count: grid.cellCount)
    for (index, cell) in cells.enumerated() { full[cell] = solution[index] }
    return full
}

private func maximumAbsolute(_ values: [Double]) -> Double { normInf(values) }

private func centralSliceValue(_ grid: Grid, _ field: [Double], _ i: Int, _ j: Int) -> Double {
    precondition(grid.nz.isMultiple(of: 2), "the central even-grid slice requires an even Z extent")
    let lower = grid.nz / 2 - 1
    let upper = grid.nz / 2
    return 0.5 * (field[grid.cell(i, j, lower)] + field[grid.cell(i, j, upper)])
}

private func quickContract() throws -> [String: Any] {
    let asymmetric = Grid(nx: 8, ny: 7, nz: 6, h: 1)
    var pressure = Array(repeating: 0.0, count: asymmetric.cellCount)
    for k in 0..<asymmetric.nz {
        for j in 0..<asymmetric.ny {
            for i in 0..<asymmetric.nx {
                pressure[asymmetric.cell(i, j, k)] = 0.013 * Double(i + 2 * j + 3 * k)
                    + sin(Double(i) * 0.37 + Double(j) * 0.19 + Double(k) * 0.43)
            }
        }
    }
    let dg = applyDivergenceGradient(asymmetric, pressure)
    let stencil = applyNeighbourStencil(asymmetric, pressure)
    let dgError = maxDifference(dg, stencil)

    let constant = Array(repeating: 0.125, count: asymmetric.cellCount)
    let constantNull = normInf(applyNeighbourStencil(asymmetric, constant)) <= 1e-12
    let alternating = alternatingPressure(asymmetric)
    let alternatingNonzero = normInf(applyNeighbourStencil(asymmetric, alternating)) > 1

    let mixed = makeMixedVelocity(asymmetric)
    let rhs = divergence(asymmetric, mixed).map { -asymmetric.h * asymmetric.h * $0 }
    let pcg = solvePCG(asymmetric, rhs, targetResidual: 1e-12, cap: 512,
                       compatibilityScale: asymmetric.h * mixed.maxAbs)
    let direct = directFixedGaugeSolve(asymmetric, rhs)
    var directZeroMean = direct
    subtractMean(&directZeroMean)
    let pressureError = maxDifference(pcg.q, directZeroMean)
    let directResidual = maxDifference(applyNeighbourStencil(asymmetric, direct), rhs)

    let cube = Grid(nx: 8, ny: 8, nz: 8, h: 1.0 / 8.0)
    var affine = Array(repeating: 0.0, count: cube.cellCount)
    for k in 0..<cube.nz {
        for j in 0..<cube.ny {
            for i in 0..<cube.nx {
                let x = (Double(i) + 0.5) * cube.h
                let y = (Double(j) + 0.5) * cube.h
                let z = (Double(k) + 0.5) * cube.h
                affine[cube.cell(i, j, k)] = 0.25 + 0.12 * x + 0.08 * y + 0.05 * z
            }
        }
    }
    let samplePoint = Vector3(x: 0.31, y: 0.42, z: 0.57)
    let affineError = abs(sampleCell(cube, affine, samplePoint) - (0.25 + 0.12 * samplePoint.x + 0.08 * samplePoint.y + 0.05 * samplePoint.z))

    var affineFaces = FaceVelocity(cube)
    func affineFaceValue(_ point: Vector3) -> Double {
        0.1 + 0.07 * point.x + 0.03 * point.y + 0.04 * point.z
    }
    for k in 0..<cube.nz {
        for j in 0..<cube.ny {
            for i in 0...cube.nx {
                let point = Vector3(x: Double(i) * cube.h, y: (Double(j) + 0.5) * cube.h,
                                    z: (Double(k) + 0.5) * cube.h)
                affineFaces.u[cube.u(i, j, k)] = affineFaceValue(point)
            }
        }
    }
    for k in 0..<cube.nz {
        for j in 0...cube.ny {
            for i in 0..<cube.nx {
                let point = Vector3(x: (Double(i) + 0.5) * cube.h, y: Double(j) * cube.h,
                                    z: (Double(k) + 0.5) * cube.h)
                affineFaces.v[cube.v(i, j, k)] = affineFaceValue(point)
            }
        }
    }
    for k in 0...cube.nz {
        for j in 0..<cube.ny {
            for i in 0..<cube.nx {
                let point = Vector3(x: (Double(i) + 0.5) * cube.h, y: (Double(j) + 0.5) * cube.h,
                                    z: Double(k) * cube.h)
                affineFaces.w[cube.w(i, j, k)] = affineFaceValue(point)
            }
        }
    }
    var affineFaceError = 0.0
    for component in 0..<3 {
        affineFaceError = max(affineFaceError,
                              abs(sampleComponent(cube, affineFaces, component: component, samplePoint) - affineFaceValue(samplePoint)))
    }

    let midpointPlanes = [cube.nz / 2 - 1, cube.nz / 2]
    var midpointError = 0.0
    var midpointLandmarkError = 0.0
    var landmarks = Array(repeating: 0.0, count: cube.cellCount)
    for k in 0..<cube.nz {
        for j in 0..<cube.ny {
            for i in 0..<cube.nx {
                landmarks[cube.cell(i, j, k)] = Double(100 * i + 10 * j + k)
            }
        }
    }
    for j in 0..<cube.ny {
        for i in 0..<cube.nx {
            let x = (Double(i) + 0.5) * cube.h
            let y = (Double(j) + 0.5) * cube.h
                midpointError = max(midpointError,
                                    abs(centralSliceValue(cube, affine, i, j) - (0.25 + 0.12 * x + 0.08 * y + 0.05 * 0.5)))
                let expectedLandmark = Double(100 * i + 10 * j) + Double(midpointPlanes[0] + midpointPlanes[1]) * 0.5
                midpointLandmarkError = max(midpointLandmarkError,
                                            abs(centralSliceValue(cube, landmarks, i, j) - expectedLandmark))
        }
    }

    let axisCases: [Vector3] = [
        Vector3(x: 0.12, y: 0, z: 0), Vector3(x: -0.12, y: 0, z: 0),
        Vector3(x: 0, y: 0.12, z: 0), Vector3(x: 0, y: -0.12, z: 0),
        Vector3(x: 0, y: 0, z: 0.12), Vector3(x: 0, y: 0, z: -0.12),
        Vector3(x: 0.13, y: -0.07, z: 0.19), Vector3(x: -0.09, y: 0.16, z: -0.05),
    ]
    var advectionError = 0.0
    var componentError = 0.0
    let target = Vector3(x: 0.5, y: 0.5, z: 0.5)
    let dt = 1.0 / 60.0
    for velocityValue in axisCases {
        var velocity = constantVelocity(cube, velocityValue)
        velocity.enforceWalls(cube)
        let departure = backtrace(cube, velocity, target, dt: dt)
        let actual = advectCell(cube, affine, velocity, target, dt: dt)
        let expected = 0.25 + 0.12 * departure.x + 0.08 * departure.y + 0.05 * departure.z
        advectionError = max(advectionError, abs(actual - expected))
        for component in 0..<3 {
            let sampled = advectComponent(cube, velocity, component: component, target: target, dt: dt)
            componentError = max(componentError, abs(sampled - velocityValue[component]))
        }
    }

    var reflected = makeMixedVelocity(cube)
    reflected.enforceWalls(cube)
    var reflectionCases = 0
    var reflectionError = 0.0
    let probeValues = [-0.031, 0.37, 1.031]
    for x in probeValues {
        for y in probeValues {
            for z in probeValues {
                if x == 0.37 && y == 0.37 && z == 0.37 { continue }
                reflectionCases += 1
                let outside = Vector3(x: x, y: y, z: z)
                let folded = Vector3(x: foldCoordinate(x, length: 1).position,
                                     y: foldCoordinate(y, length: 1).position,
                                     z: foldCoordinate(z, length: 1).position)
                let signX = (x < 0 || x > 1) ? -1.0 : 1.0
                let signY = (y < 0 || y > 1) ? -1.0 : 1.0
                let signZ = (z < 0 || z > 1) ? -1.0 : 1.0
                let actual = sampleVelocity(cube, reflected, outside)
                let expected = sampleVelocity(cube, reflected, folded)
                reflectionError = max(reflectionError, abs(actual.x - signX * expected.x))
                reflectionError = max(reflectionError, abs(actual.y - signY * expected.y))
                reflectionError = max(reflectionError, abs(actual.z - signZ * expected.z))
                let scalarOutside = sampleCell(cube, affine, outside)
                let scalarInside = sampleCell(cube, affine, folded)
                reflectionError = max(reflectionError, abs(scalarOutside - scalarInside))
            }
        }
    }

    let nanRejected = !within(Double.nan, 0, absolute: 1e-10)
    let directResidualValue = normInf(zip(rhs, applyNeighbourStencil(asymmetric, direct)).map { $0.0 - $0.1 })
    let finite = allFinite(pressure) && allFinite(dg) && allFinite(stencil) && allFinite(pcg.q)
        && allFinite(direct) && allFinite(affine) && reflected.allFinite
    return [
        "finite": finite,
        "grid": asymmetric.cellShape,
        "dg_stencil_max_abs_error": dgError,
        "constant_pressure_is_null": constantNull,
        "alternating_pressure_is_nonzero": alternatingNonzero,
        "direct_solve_pressure_max_abs_error": pressureError,
        "direct_solve_true_residual_max_abs": directResidualValue,
        "direct_solve_stencil_crosscheck_max_abs_error": directResidual,
        "affine_interpolation_max_abs_error": affineError,
        "affine_face_interpolation_max_abs_error": affineFaceError,
        "midpoint_planes": midpointPlanes,
        "midpoint_slice_max_abs_error": midpointError,
        "midpoint_landmark_max_abs_error": midpointLandmarkError,
        "advection_cases": axisCases.count,
        "advection_max_abs_error": advectionError,
        "component_advection_max_abs_error": componentError,
        "reflection_cases": reflectionCases,
        "reflection_max_abs_error": reflectionError,
        "nan_rejected": nanRejected,
    ]
}

private func constantVelocity(_ grid: Grid, _ value: Vector3) -> FaceVelocity {
    var result = FaceVelocity(grid)
    result.u = Array(repeating: value.x, count: grid.uCount)
    result.v = Array(repeating: value.y, count: grid.vCount)
    result.w = Array(repeating: value.z, count: grid.wCount)
    result.enforceWalls(grid)
    return result
}

private func foldCoordinate(_ coordinate: Double, length: Double) -> (position: Double, sign: Double) {
    var folded = coordinate.truncatingRemainder(dividingBy: 2 * length)
    if folded < 0 { folded += 2 * length }
    if folded <= length { return (folded, 1) }
    return (2 * length - folded, -1)
}

private func reflectedCellIndex(_ value: Int, count: Int) -> Int {
    var index = value
    while index < 0 || index >= count {
        if index < 0 { index = -index - 1 }
        if index >= count { index = 2 * count - 1 - index }
    }
    return index
}

private func sampleLattice(_ grid: Grid, _ values: [Double], dims: [Int], offsets: [Double],
                           position: Vector3, normalAxis: Int?) -> Double {
    let lengths = [Double(grid.nx) * grid.h, Double(grid.ny) * grid.h, Double(grid.nz) * grid.h]
    var folded = position
    var parity = [1.0, 1.0, 1.0]
    for axis in 0..<3 {
        let fold = foldCoordinate(position[axis], length: lengths[axis])
        folded[axis] = fold.position
        parity[axis] = fold.sign
    }
    let coordinates = [folded.x / grid.h - offsets[0], folded.y / grid.h - offsets[1], folded.z / grid.h - offsets[2]]
    let base = coordinates.map { Int(floor($0)) }
    let fraction = zip(coordinates, base).map { $0.0 - Double($0.1) }
    var total = 0.0
    for dz in 0...1 {
        for dy in 0...1 {
            for dx in 0...1 {
                let weights = [dx == 0 ? 1 - fraction[0] : fraction[0],
                               dy == 0 ? 1 - fraction[1] : fraction[1],
                               dz == 0 ? 1 - fraction[2] : fraction[2]]
                var indices = [base[0] + dx, base[1] + dy, base[2] + dz]
                for axis in 0..<3 {
                    if axis == normalAxis {
                        indices[axis] = max(0, min(dims[axis] - 1, indices[axis]))
                    } else {
                        indices[axis] = reflectedCellIndex(indices[axis], count: dims[axis])
                    }
                }
                let index = index3D(indices[0], indices[1], indices[2], dims[0], dims[1])
                total += values[index] * weights[0] * weights[1] * weights[2]
            }
        }
    }
    if let normalAxis { total *= parity[normalAxis] }
    return total
}

private func sampleCell(_ grid: Grid, _ values: [Double], _ position: Vector3) -> Double {
    sampleLattice(grid, values, dims: [grid.nx, grid.ny, grid.nz],
                  offsets: [0.5, 0.5, 0.5], position: position, normalAxis: nil)
}

private func sampleComponent(_ grid: Grid, _ velocity: FaceVelocity, component: Int, _ position: Vector3) -> Double {
    switch component {
    case 0:
        return sampleLattice(grid, velocity.u, dims: [grid.nx + 1, grid.ny, grid.nz],
                             offsets: [0, 0.5, 0.5], position: position, normalAxis: 0)
    case 1:
        return sampleLattice(grid, velocity.v, dims: [grid.nx, grid.ny + 1, grid.nz],
                             offsets: [0.5, 0, 0.5], position: position, normalAxis: 1)
    default:
        return sampleLattice(grid, velocity.w, dims: [grid.nx, grid.ny, grid.nz + 1],
                             offsets: [0.5, 0.5, 0], position: position, normalAxis: 2)
    }
}

private func sampleVelocity(_ grid: Grid, _ velocity: FaceVelocity, _ position: Vector3) -> Vector3 {
    Vector3(x: sampleComponent(grid, velocity, component: 0, position),
            y: sampleComponent(grid, velocity, component: 1, position),
            z: sampleComponent(grid, velocity, component: 2, position))
}

private func clampToDomain(_ grid: Grid, _ position: Vector3) -> Vector3 {
    Vector3(x: min(Double(grid.nx) * grid.h, max(0, position.x)),
            y: min(Double(grid.ny) * grid.h, max(0, position.y)),
            z: min(Double(grid.nz) * grid.h, max(0, position.z)))
}

private func backtrace(_ grid: Grid, _ velocity: FaceVelocity, _ position: Vector3, dt: Double) -> Vector3 {
    let v0 = sampleVelocity(grid, velocity, position)
    let midpoint = clampToDomain(grid, position - v0 * (0.5 * dt))
    let vmid = sampleVelocity(grid, velocity, midpoint)
    return clampToDomain(grid, position - vmid * dt)
}

private func advectCell(_ grid: Grid, _ field: [Double], _ velocity: FaceVelocity,
                       _ position: Vector3, dt: Double) -> Double {
    sampleCell(grid, field, backtrace(grid, velocity, position, dt: dt))
}

private func advectComponent(_ grid: Grid, _ velocity: FaceVelocity, component: Int,
                             target: Vector3, dt: Double) -> Double {
    let departure = backtrace(grid, velocity, target, dt: dt)
    return sampleComponent(grid, velocity, component: component, departure)
}

private func maxWallValueError(_ grid: Grid, _ velocity: FaceVelocity) -> Double {
    maxWallFlux(grid, velocity)
}

private func summarize(_ name: String, _ result: ProjectionResult) -> [String: Any] {
    var summary: [String: Any] = [
        "name": name,
        "iterations": result.iterations,
        "converged": result.converged,
        "cap_hit": result.capHit,
        "finite": result.finite,
        "input_divergence_dt_inf": result.inputDivergenceDT,
        "projected_divergence_dt_inf": result.projectedDivergenceDT,
        "true_residual_dt_inf": result.residualDT,
        "identity_dt_inf_error": result.identityDTError,
        "divergence_reduction": result.divergenceReduction,
        "pressure_mean_abs": result.pressureMeanAbs,
        "max_wall_flux": result.maxWallFlux,
        "failure": result.failure ?? "none",
        "divergence_rms": sqrt(dot(result.divergence, result.divergence) / Double(result.divergence.count)),
        "true_residual_rms": sqrt(dot(result.trueResidual, result.trueResidual) / Double(result.trueResidual.count)),
    ]
    if let expectedPressureError = result.expectedPressureError {
        summary["expected_pressure_max_abs_error"] = expectedPressureError
    }
    return summary
}

private struct FullReference {
    let payload: [String: Any]
    let results: [String: ProjectionResult]
    let volume: FullVolumeFixture
}

private struct FullVolumeFixture {
    let summary: [String: Any]
    let velocity: FaceVelocity
    let transport: Vector3
    let dyeSteps: [[Double]]
}

private func fullFeasibility() throws -> FullReference {
    let grid = Grid(nx: 64, ny: 64, nz: 64, h: 1.0 / 64.0)
    let dt = 1.0 / 60.0
    var results: [String: ProjectionResult] = [:]

    var zero = FaceVelocity(grid)
    zero.enforceWalls(grid)
    results["zero_rhs"] = project(grid, zero, dt: dt)

    let constantQ = Array(repeating: 0.125, count: grid.cellCount)
    let constantNullError = normInf(applyNeighbourStencil(grid, constantQ))
    let constantVelocityField = makeGradientVelocity(grid, constantQ)
    results["constant_pressure"] = project(grid, constantVelocityField, dt: dt)

    let alternatingQ = alternatingPressure(grid)
    let alternatingInput = makeGradientVelocity(grid, alternatingQ)
    results["alternating_pressure"] = project(grid, alternatingInput, dt: dt, expectedPressure: alternatingQ)

    let cosineQ = manufacturedCosinePressure(grid)
    let cosineInput = makeGradientVelocity(grid, cosineQ)
    results["manufactured_cosine"] = project(grid, cosineInput, dt: dt, expectedPressure: cosineQ)

    let mixed = makeMixedVelocity(grid)
    results["mixed_frequency_asymmetric"] = project(grid, mixed, dt: dt)

    let boundaries = makeWallEdgeCornerVelocity(grid)
    results["wall_edge_corner"] = project(grid, boundaries, dt: dt)

    let divergenceFree = makeDiscreteDivergenceFree(grid)
    results["divergence_free"] = project(grid, divergenceFree, dt: dt)

    let summaries = results.keys.sorted().map { summarize($0, results[$0]!) }
    let translated = fullVolumeAnalyticFixture(grid, dt: dt)
    let trajectory = referenceTrajectory(dt: dt, steps: 48)
    let finite = results.values.allSatisfy { $0.finite }
        && summaries.allSatisfy { ($0["finite"] as? Bool) == true }
        && (translated.summary["finite"] as? Bool) == true
        && (trajectory["finite"] as? Bool) == true
    let allConverged = results.values.allSatisfy { $0.converged }
    let qErrorsPass = (results["alternating_pressure"]?.expectedPressureError ?? .infinity) <= 1e-6
        && (results["manufactured_cosine"]?.expectedPressureError ?? .infinity) <= 1e-6
    let constantNullPass = constantNullError <= 1e-12
    let trajectoryPass = (trajectory["centroid_z_displacement_cells"] as? Double ?? 0) >= 0.5
        && (trajectory["plane_rms_arc_ratio"] as? Double ?? 0) >= 0.01
    let passed = finite && allConverged && qErrorsPass && constantNullPass && trajectoryPass
    let payload: [String: Any] = [
        "finite": finite,
        "passed": passed,
        "grid": grid.cellShape,
        "iteration_cap": iterationLimit,
        "constant_pressure_null_max_abs": constantNullError,
        "fixtures": summaries,
        "full_volume_unequal_axis": translated.summary,
        "reference_trajectory": trajectory,
    ]
    return FullReference(payload: payload, results: results, volume: translated)
}

private func smoothBlob(_ position: Vector3, center: Vector3, radius: Double) -> Double {
    let relative = (position - center) * (1 / radius)
    let squared = relative.x * relative.x + relative.y * relative.y + relative.z * relative.z
    guard squared < 1 else { return 0 }
    return exp(1 - 1 / (1 - squared))
}

private func fullVolumeAnalyticFixture(_ grid: Grid, dt: Double) -> FullVolumeFixture {
    let initialCenter = Vector3(x: 0.42, y: 0.48, z: 0.43)
    let transport = Vector3(x: 0.071, y: -0.043, z: 0.113)
    let radius = 0.105
    var initial = Array(repeating: 0.0, count: grid.cellCount)
    var middle = Array(repeating: 0.0, count: grid.cellCount)
    var final = Array(repeating: 0.0, count: grid.cellCount)
    let steps = 48
    let middleDisplacement = transport * (Double(steps / 2) * dt)
    let displacement = transport * (Double(steps) * dt)
    for k in 0..<grid.nz {
        for j in 0..<grid.ny {
            for i in 0..<grid.nx {
                let point = Vector3(x: (Double(i) + 0.5) * grid.h,
                                    y: (Double(j) + 0.5) * grid.h,
                                    z: (Double(k) + 0.5) * grid.h)
                initial[grid.cell(i, j, k)] = smoothBlob(point, center: initialCenter, radius: radius)
                middle[grid.cell(i, j, k)] = smoothBlob(point, center: initialCenter + middleDisplacement, radius: radius)
                final[grid.cell(i, j, k)] = smoothBlob(point, center: initialCenter + displacement, radius: radius)
            }
        }
    }
    let before = volumeStatistics(grid, initial)
    let at24 = volumeStatistics(grid, middle)
    let after = volumeStatistics(grid, final)
    let xyzUnequal = transport.x != transport.y && transport.y != transport.z && transport.x != transport.z
    var velocity = FaceVelocity(grid)
    for k in 0..<grid.nz {
        for j in 0..<grid.ny {
            for i in 1..<grid.nx { velocity.u[grid.u(i, j, k)] = transport.x }
        }
    }
    for k in 0..<grid.nz {
        for j in 1..<grid.ny {
            for i in 0..<grid.nx { velocity.v[grid.v(i, j, k)] = transport.y }
        }
    }
    for k in 1..<grid.nz {
        for j in 0..<grid.ny {
            for i in 0..<grid.nx { velocity.w[grid.w(i, j, k)] = transport.z }
        }
    }
    velocity.enforceWalls(grid)
    let finite = allFinite(initial) && allFinite(middle) && allFinite(final) && velocity.allFinite
        && before.finite && at24.finite && after.finite && xyzUnequal
    let summary: [String: Any] = [
        "finite": finite,
        "shape": grid.cellShape,
        "velocity": [transport.x, transport.y, transport.z],
        "steps": steps,
        "dt": dt,
        "centroid_start": [before.centroid.x, before.centroid.y, before.centroid.z],
        "centroid_step24": [at24.centroid.x, at24.centroid.y, at24.centroid.z],
        "centroid_end": [after.centroid.x, after.centroid.y, after.centroid.z],
        "centroid_z_displacement_cells": abs(after.centroid.z - before.centroid.z) / grid.h,
        "mass_start": before.mass,
        "mass_step24": at24.mass,
        "mass_end": after.mass,
        "spread_start": before.spread,
        "spread_step24": at24.spread,
        "spread_end": after.spread,
        "analytic_reference": "compact smooth blob translated by unequal constant XYZ velocity",
    ]
    return FullVolumeFixture(summary: summary, velocity: velocity, transport: transport,
                             dyeSteps: [initial, middle, final])
}

private struct VolumeStats {
    let mass: Double
    let centroid: Vector3
    let spread: Double
    let finite: Bool
}

private func volumeStatistics(_ grid: Grid, _ field: [Double]) -> VolumeStats {
    var mass = 0.0
    var x = 0.0
    var y = 0.0
    var z = 0.0
    for k in 0..<grid.nz {
        for j in 0..<grid.ny {
            for i in 0..<grid.nx {
                let value = field[grid.cell(i, j, k)]
                let px = (Double(i) + 0.5) * grid.h
                let py = (Double(j) + 0.5) * grid.h
                let pz = (Double(k) + 0.5) * grid.h
                mass += value
                x += value * px
                y += value * py
                z += value * pz
            }
        }
    }
    guard mass.isFinite, mass > 0 else {
        return VolumeStats(mass: mass, centroid: Vector3(x: .nan, y: .nan, z: .nan), spread: .nan, finite: false)
    }
    let center = Vector3(x: x / mass, y: y / mass, z: z / mass)
    var variance = 0.0
    for k in 0..<grid.nz {
        for j in 0..<grid.ny {
            for i in 0..<grid.nx {
                let value = field[grid.cell(i, j, k)]
                let dx = (Double(i) + 0.5) * grid.h - center.x
                let dy = (Double(j) + 0.5) * grid.h - center.y
                let dz = (Double(k) + 0.5) * grid.h - center.z
                variance += value * (dx * dx + dy * dy + dz * dz)
            }
        }
    }
    let spread = sqrt(variance / mass)
    return VolumeStats(mass: mass, centroid: center, spread: spread,
                       finite: center.x.isFinite && center.y.isFinite && center.z.isFinite && spread.isFinite)
}

private func analyticCurlVelocity(_ point: Vector3) -> Vector3 {
    let x = point.x
    let y = point.y
    let z = point.z
    let scale = 0.25
    let sx = sin(Double.pi * x)
    let sy = sin(Double.pi * y)
    let sz = sin(Double.pi * z)
    let cx = cos(Double.pi * x)
    let cy = cos(Double.pi * y)
    let cz = cos(Double.pi * z)
    let u = Double.pi * sx * (cy - cz)
    let v = Double.pi * sy * (cz - cx)
    let w = Double.pi * sz * (cx - cy)
    return Vector3(x: scale * u, y: scale * v, z: scale * w)
}

private func smallestEigenvalue(_ matrix: [[Double]]) -> Double {
    var a = matrix
    for _ in 0..<48 {
        var p = 0
        var q = 1
        var largest = abs(a[0][1])
        if abs(a[0][2]) > largest { p = 0; q = 2; largest = abs(a[0][2]) }
        if abs(a[1][2]) > largest { p = 1; q = 2; largest = abs(a[1][2]) }
        if largest < 1e-15 { break }
        let angle = 0.5 * atan2(2 * a[p][q], a[q][q] - a[p][p])
        let c = cos(angle)
        let s = sin(angle)
        let app = c * c * a[p][p] - 2 * s * c * a[p][q] + s * s * a[q][q]
        let aqq = s * s * a[p][p] + 2 * s * c * a[p][q] + c * c * a[q][q]
        for r in 0..<3 where r != p && r != q {
            let arp = c * a[r][p] - s * a[r][q]
            let arq = s * a[r][p] + c * a[r][q]
            a[r][p] = arp; a[p][r] = arp
            a[r][q] = arq; a[q][r] = arq
        }
        a[p][p] = app
        a[q][q] = aqq
        a[p][q] = 0
        a[q][p] = 0
    }
    return max(0, min(a[0][0], min(a[1][1], a[2][2])))
}

private func referenceTrajectory(dt: Double, steps: Int) -> [String: Any] {
    var point = Vector3(x: 0.35, y: 0.21, z: 0.785)
    var points = [point]
    for _ in 0..<steps {
        let first = analyticCurlVelocity(point)
        let middle = point + first * (0.5 * dt)
        let second = analyticCurlVelocity(middle)
        point = point + second * dt
        points.append(point)
    }
    var arcLength = 0.0
    for index in 1..<points.count { arcLength += (points[index] - points[index - 1]).length }
    let center = Vector3(x: points.reduce(0) { $0 + $1.x } / Double(points.count),
                         y: points.reduce(0) { $0 + $1.y } / Double(points.count),
                         z: points.reduce(0) { $0 + $1.z } / Double(points.count))
    var covariance = Array(repeating: Array(repeating: 0.0, count: 3), count: 3)
    for point in points {
        let d = point - center
        for row in 0..<3 {
            for column in 0..<3 { covariance[row][column] += d[row] * d[column] / Double(points.count) }
        }
    }
    let planeRMS = sqrt(smallestEigenvalue(covariance))
    let firstPoint = points.first!
    let lastPoint = points.last!
    let finite = points.allSatisfy { $0.x.isFinite && $0.y.isFinite && $0.z.isFinite }
        && arcLength.isFinite && planeRMS.isFinite
    return [
        "finite": finite,
        "steps": steps,
        "start": [firstPoint.x, firstPoint.y, firstPoint.z],
        "end": [lastPoint.x, lastPoint.y, lastPoint.z],
        "z_displacement": abs(lastPoint.z - firstPoint.z),
        "centroid_z_displacement_cells": abs(lastPoint.z - firstPoint.z) * 64,
        "arc_length": arcLength,
        "plane_rms": planeRMS,
        "plane_rms_arc_ratio": arcLength > 0 ? planeRMS / arcLength : 0,
        "field": "analytic curl of smooth three-frequency vector potential",
    ]
}

private func sha256(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

private func checkContract(_ url: URL) throws {
    let data = try Data(contentsOf: url)
    guard let text = String(data: data, encoding: .utf8),
          let marker = text.range(of: "<!-- END PREREGISTERED CONTRACT -->") else {
        throw ReferenceError.failed("contract marker or UTF-8 document is missing")
    }
    let prefix = Data(text[..<marker.lowerBound].utf8)
    let actual = sha256(prefix)
    guard actual == expectedContractHash else {
        throw ReferenceError.failed("contract hash mismatch: expected \(expectedContractHash), got \(actual)")
    }
    guard text.contains("Preregistered contract SHA-256:** `\(expectedContractHash)`") else {
        throw ReferenceError.failed("contract's recorded hash does not match its preregistered prefix")
    }
}

private func appendLittleEndian(_ arrays: [[Double]]) -> Data {
    var words: [UInt64] = []
    words.reserveCapacity(arrays.reduce(0) { $0 + $1.count })
    for array in arrays {
        for value in array { words.append(value.bitPattern.littleEndian) }
    }
    return words.withUnsafeBufferPointer { buffer in
        Data(bytes: buffer.baseAddress!, count: buffer.count * MemoryLayout<UInt64>.size)
    }
}

private func payloadArrays(_ name: String, _ grid: Grid, _ projection: ProjectionResult) -> ([[String: Any]], [[Double]]) {
    let fields: [(String, [Int], String, [Double])] = [
        ("u_input", [grid.nx + 1, grid.ny, grid.nz], "domain-length/s", projection.input.u),
        ("v_input", [grid.nx, grid.ny + 1, grid.nz], "domain-length/s", projection.input.v),
        ("w_input", [grid.nx, grid.ny, grid.nz + 1], "domain-length/s", projection.input.w),
        ("rhs", grid.cellShape, "q-units", projection.rhs),
        ("pressure_q", grid.cellShape, "q=dt*p/rho", projection.pressure),
        ("u_projected", [grid.nx + 1, grid.ny, grid.nz], "domain-length/s", projection.projected.u),
        ("v_projected", [grid.nx, grid.ny + 1, grid.nz], "domain-length/s", projection.projected.v),
        ("w_projected", [grid.nx, grid.ny, grid.nz + 1], "domain-length/s", projection.projected.w),
        ("divergence_projected", grid.cellShape, "1/simulation-time", projection.divergence),
        ("true_residual", grid.cellShape, "q-operator-units", projection.trueResidual),
    ]
    let manifest = fields.map { field -> [String: Any] in
        ["name": field.0, "shape": field.1, "unit": field.2, "elementType": "float64-le"]
    }
    return (manifest, fields.map { $0.3 })
}

private func writeExport(_ directory: URL, _ full: FullReference) throws -> [String: Any] {
    guard (full.payload["passed"] as? Bool) == true else {
        throw ReferenceError.failed("CPU reference feasibility failed; refusing to export acceptance fixtures")
    }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let grid = Grid(nx: 64, ny: 64, nz: 64, h: 1.0 / 64.0)
    var binaryPayloads: [[String: Any]] = []
    for name in ["alternating_pressure", "manufactured_cosine", "mixed_frequency_asymmetric", "wall_edge_corner"] {
        guard let projection = full.results[name] else { continue }
        let (arrays, values) = payloadArrays(name, grid, projection)
        let data = appendLittleEndian(values)
        let filename = "reference-64-\(name).f64le"
        try data.write(to: directory.appendingPathComponent(filename), options: .atomic)
        binaryPayloads.append([
            "fixture": name,
            "file": filename,
            "dtype": "float64-le",
            "arrayOrder": arrays,
            "byteCount": data.count,
            "sha256": sha256(data),
        ])
    }

    let asym = Grid(nx: 8, ny: 7, nz: 6, h: 1)
    var q = Array(repeating: 0.0, count: asym.cellCount)
    for k in 0..<asym.nz {
        for j in 0..<asym.ny {
            for i in 0..<asym.nx {
                q[asym.cell(i, j, k)] = 0.013 * Double(i + 2 * j + 3 * k)
                    + sin(0.37 * Double(i) + 0.19 * Double(j) + 0.43 * Double(k))
            }
        }
    }
    let dg = applyDivergenceGradient(asym, q)
    let stencil = applyNeighbourStencil(asym, q)
    let asymArrays: [[String: Any]] = [
        ["name": "pressure_q", "shape": asym.cellShape, "unit": "q=dt*p/rho", "elementType": "float64-le"],
        ["name": "A_from_DG", "shape": asym.cellShape, "unit": "q-operator-units", "elementType": "float64-le"],
        ["name": "A_neighbour_stencil", "shape": asym.cellShape, "unit": "q-operator-units", "elementType": "float64-le"],
    ]
    let asymData = appendLittleEndian([q, dg, stencil])
    let asymFilename = "reference-8x7x6-operator.f64le"
    try asymData.write(to: directory.appendingPathComponent(asymFilename), options: .atomic)
    binaryPayloads.append([
        "fixture": "asymmetric_operator_identity",
        "file": asymFilename,
        "dtype": "float64-le",
        "arrayOrder": asymArrays,
        "byteCount": asymData.count,
        "sha256": sha256(asymData),
    ])

    let volumeArrays: [[String: Any]] = [
        ["name": "u_input", "shape": [grid.nx + 1, grid.ny, grid.nz], "unit": "domain-length/s", "elementType": "float64-le"],
        ["name": "v_input", "shape": [grid.nx, grid.ny + 1, grid.nz], "unit": "domain-length/s", "elementType": "float64-le"],
        ["name": "w_input", "shape": [grid.nx, grid.ny, grid.nz + 1], "unit": "domain-length/s", "elementType": "float64-le"],
        ["name": "dye_step0", "shape": grid.cellShape, "unit": "dimensionless concentration", "elementType": "float64-le"],
        ["name": "dye_step24", "shape": grid.cellShape, "unit": "dimensionless concentration", "elementType": "float64-le"],
        ["name": "dye_step48", "shape": grid.cellShape, "unit": "dimensionless concentration", "elementType": "float64-le"],
    ]
    let volumeData = appendLittleEndian([full.volume.velocity.u, full.volume.velocity.v, full.volume.velocity.w]
        + full.volume.dyeSteps)
    let volumeFilename = "reference-64-full-volume-unequal-axis.f64le"
    try volumeData.write(to: directory.appendingPathComponent(volumeFilename), options: .atomic)
    binaryPayloads.append([
        "fixture": "full_volume_unequal_axis",
        "file": volumeFilename,
        "dtype": "float64-le",
        "arrayOrder": volumeArrays,
        "byteCount": volumeData.count,
        "sha256": sha256(volumeData),
    ])

    let manifest: [String: Any] = [
        "schemaVersion": 1,
        "contractHash": expectedContractHash,
        "grid": ["cells": grid.cellShape, "u": [65, 64, 64], "v": [64, 65, 64], "w": [64, 64, 65], "xFastest": true],
        "precision": ["reference": "float64", "gpuCandidate": "float32", "binaryByteOrder": "little-endian"],
        "units": ["domain": "unit cube", "velocity": "domain-length/simulation-time", "dt": 1.0 / 60.0, "h": 1.0 / 64.0, "dye": "dimensionless concentration", "pressure": "q=dt*p/rho"],
        "uniformLaneSchema": [
            ["offset": 0, "type": "uint4", "swift": "SIMD4<UInt32>", "fields": ["gridNx", "gridNy", "gridNz", "operationID"]],
            ["offset": 16, "type": "float4", "swift": "SIMD4<Float>", "fields": ["h", "dt", "inverseH", "scalarScale"]],
            ["offset": 32, "type": "uint4", "swift": "SIMD4<UInt32>", "fields": ["outputWidth", "outputHeight", "outputDepth", "componentID"]],
            ["alignment": 16, "stride": 48],
        ],
        "fixtures": full.payload["fixtures"]!,
        "fullVolumeUnequalAxis": full.payload["full_volume_unequal_axis"]!,
        "referenceTrajectory": full.payload["reference_trajectory"]!,
        "binaryPayloads": binaryPayloads,
    ]
    let manifestData = try JSONSerialization.data(withJSONObject: manifest, options: [.sortedKeys, .prettyPrinted])
    try manifestData.write(to: directory.appendingPathComponent("manifest.json"), options: .atomic)
    return ["contractHash": expectedContractHash, "manifest": "manifest.json", "payloadCount": binaryPayloads.count,
             "manifestSHA256": sha256(manifestData), "directory": directory.path]
}

private struct AdvectionFixtureInput {
    let name: String
    let grid: Grid
    let velocity: FaceVelocity
    let dye: [Double]
}

private func makeAffineDye(_ grid: Grid) -> [Double] {
    var values = Array(repeating: 0.0, count: grid.cellCount)
    for k in 0..<grid.nz {
        for j in 0..<grid.ny {
            for i in 0..<grid.nx {
                let x = (Double(i) + 0.5) / Double(grid.nx)
                let y = (Double(j) + 0.5) / Double(grid.ny)
                let z = (Double(k) + 0.5) / Double(grid.nz)
                values[grid.cell(i, j, k)] = 0.25 + 0.22 * x + 0.16 * y + 0.12 * z
            }
        }
    }
    return values
}

private func advectFixture(_ fixture: AdvectionFixtureInput, dt: Double) -> (FaceVelocity, [Double]) {
    let grid = fixture.grid
    let velocity = fixture.velocity
    var outputVelocity = FaceVelocity(grid)
    for k in 0..<grid.nz {
        for j in 0..<grid.ny {
            for i in 0...grid.nx {
                let point = Vector3(x: Double(i) * grid.h,
                                    y: (Double(j) + 0.5) * grid.h,
                                    z: (Double(k) + 0.5) * grid.h)
                outputVelocity.u[grid.u(i, j, k)] = advectComponent(
                    grid, velocity, component: 0, target: point, dt: dt
                )
            }
        }
    }
    for k in 0..<grid.nz {
        for j in 0...grid.ny {
            for i in 0..<grid.nx {
                let point = Vector3(x: (Double(i) + 0.5) * grid.h,
                                    y: Double(j) * grid.h,
                                    z: (Double(k) + 0.5) * grid.h)
                outputVelocity.v[grid.v(i, j, k)] = advectComponent(
                    grid, velocity, component: 1, target: point, dt: dt
                )
            }
        }
    }
    for k in 0...grid.nz {
        for j in 0..<grid.ny {
            for i in 0..<grid.nx {
                let point = Vector3(x: (Double(i) + 0.5) * grid.h,
                                    y: (Double(j) + 0.5) * grid.h,
                                    z: Double(k) * grid.h)
                outputVelocity.w[grid.w(i, j, k)] = advectComponent(
                    grid, velocity, component: 2, target: point, dt: dt
                )
            }
        }
    }
    outputVelocity.enforceWalls(grid)

    var outputDye = Array(repeating: 0.0, count: grid.cellCount)
    for k in 0..<grid.nz {
        for j in 0..<grid.ny {
            for i in 0..<grid.nx {
                let point = Vector3(x: (Double(i) + 0.5) * grid.h,
                                    y: (Double(j) + 0.5) * grid.h,
                                    z: (Double(k) + 0.5) * grid.h)
                outputDye[grid.cell(i, j, k)] = advectCell(
                    grid, fixture.dye, outputVelocity, point, dt: dt
                )
            }
        }
    }
    return (outputVelocity, outputDye)
}

private func advectionFixtures() throws -> [AdvectionFixtureInput] {
    let small = Grid(nx: 8, ny: 7, nz: 6, h: 1.0 / 8.0)
    let production = Grid(nx: 64, ny: 64, nz: 64, h: 1.0 / 64.0)
    let zeroVelocity = FaceVelocity(small)
    let uniformDye = Array(repeating: 0.375, count: small.cellCount)
    var fixtures = [AdvectionFixtureInput(name: "zero_uniform", grid: small,
                                          velocity: zeroVelocity, dye: uniformDye)]

    let axisCases: [(String, Vector3)] = [
        ("positive_x", Vector3(x: 0.12, y: 0, z: 0)),
        ("negative_x", Vector3(x: -0.12, y: 0, z: 0)),
        ("positive_y", Vector3(x: 0, y: 0.12, z: 0)),
        ("negative_y", Vector3(x: 0, y: -0.12, z: 0)),
        ("positive_z", Vector3(x: 0, y: 0, z: 0.12)),
        ("negative_z", Vector3(x: 0, y: 0, z: -0.12)),
        ("combined_xyz", Vector3(x: 0.13, y: -0.07, z: 0.19)),
        ("combined_xyz_mixed", Vector3(x: -0.09, y: 0.16, z: -0.05)),
    ]
    let affineDye = makeAffineDye(small)
    for (name, value) in axisCases {
        fixtures.append(AdvectionFixtureInput(
            name: name,
            grid: small,
            velocity: constantVelocity(small, value),
            dye: affineDye
        ))
    }
    fixtures.append(AdvectionFixtureInput(
        name: "wall_edge_corner",
        grid: small,
        velocity: makeWallEdgeCornerVelocity(small),
        dye: affineDye
    ))
    fixtures.append(AdvectionFixtureInput(
        name: "production_mixed",
        grid: production,
        velocity: makeMixedVelocity(production),
        dye: makeAffineDye(production)
    ))
    return fixtures
}

private func writeAdvectionFixtures(_ directory: URL) throws -> [String: Any] {
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    var cases: [[String: Any]] = []
    let dt = 1.0 / 60.0
    for fixture in try advectionFixtures() {
        guard fixture.velocity.allFinite, allFinite(fixture.dye),
              fixture.dye.allSatisfy({ (0.0...1.0).contains($0) }) else {
            throw ReferenceError.failed("nonfinite or out-of-range input in advection fixture \(fixture.name)")
        }
        let (outputVelocity, outputDye) = advectFixture(fixture, dt: dt)
        guard outputVelocity.allFinite, allFinite(outputDye),
              outputDye.allSatisfy({ (0.0...1.0).contains($0) }) else {
            throw ReferenceError.failed("nonfinite or out-of-range output in advection fixture \(fixture.name)")
        }

        let grid = fixture.grid
        let fields: [(String, [Int], String, [Double])] = [
            ("u_input", [grid.nx + 1, grid.ny, grid.nz], "domain-length/simulation-time", fixture.velocity.u),
            ("v_input", [grid.nx, grid.ny + 1, grid.nz], "domain-length/simulation-time", fixture.velocity.v),
            ("w_input", [grid.nx, grid.ny, grid.nz + 1], "domain-length/simulation-time", fixture.velocity.w),
            ("dye_input", grid.cellShape, "dimensionless concentration", fixture.dye),
            ("u_advected", [grid.nx + 1, grid.ny, grid.nz], "domain-length/simulation-time", outputVelocity.u),
            ("v_advected", [grid.nx, grid.ny + 1, grid.nz], "domain-length/simulation-time", outputVelocity.v),
            ("w_advected", [grid.nx, grid.ny, grid.nz + 1], "domain-length/simulation-time", outputVelocity.w),
            ("dye_advected", grid.cellShape, "dimensionless concentration", outputDye),
        ]
        var offsetElements = 0
        let arrays: [[String: Any]] = fields.map { field in
            let elementCount = field.3.count
            let descriptor: [String: Any] = [
                "name": field.0,
                "shape": field.1,
                "unit": field.2,
                "elementType": "float64-le",
                "offsetElements": offsetElements,
                "elementCount": elementCount,
            ]
            offsetElements += elementCount
            return descriptor
        }
        let data = appendLittleEndian(fields.map(\.3))
        let filename = "reference-advection-\(fixture.name).f64le"
        try data.write(to: directory.appendingPathComponent(filename), options: .atomic)
        cases.append([
            "name": fixture.name,
            "grid": ["nx": grid.nx, "ny": grid.ny, "nz": grid.nz, "h": grid.h, "dt": dt, "xFastest": true],
            "file": filename,
            "byteCount": data.count,
            "sha256": sha256(data),
            "arrays": arrays,
            "maxWallNormalValue": maxWallFlux(grid, outputVelocity),
            "dyeMin": outputDye.min() ?? 0,
            "dyeMax": outputDye.max() ?? 0,
        ])
    }

    let manifest: [String: Any] = [
        "schemaVersion": 1,
        "contractHash": expectedContractHash,
        "precision": ["reference": "float64", "gpuCandidate": "float32", "binaryByteOrder": "little-endian"],
        "tolerance": ["absolute": 2e-5, "relative": 2e-4],
        "step": ["dt": dt, "velocityGeneration": "all outputs read the same old u/v/w",
                 "dyeVelocityGeneration": "advected velocity after exact wall enforcement"],
        "cases": cases,
    ]
    let data = try JSONSerialization.data(withJSONObject: manifest, options: [.sortedKeys, .prettyPrinted])
    try data.write(to: directory.appendingPathComponent("advection-manifest.json"), options: .atomic)
    return ["manifest": "advection-manifest.json", "caseCount": cases.count,
            "manifestSHA256": sha256(data), "directory": directory.path]
}

private func emitJSON(_ object: [String: Any]) throws {
    let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    guard let text = String(data: data, encoding: .utf8) else { throw ReferenceError.failed("JSON encoding failed") }
    print(text)
}

@main
private struct Fluid3DReferenceMain {
    static func main() {
        do {
            let arguments = Array(CommandLine.arguments.dropFirst())
            guard !arguments.isEmpty else {
                throw ReferenceError.usage("usage: fluid3d_reference --check-contract PATH [--quick-contract|--reference-feasibility|--export DIR --contract PATH|--advection-fixtures DIR]")
            }

            if let checkIndex = arguments.firstIndex(of: "--check-contract") {
                guard arguments.indices.contains(checkIndex + 1) else { throw ReferenceError.usage("--check-contract requires a contract path") }
                try checkContract(URL(fileURLWithPath: arguments[checkIndex + 1]))
                if !arguments.contains("--quick-contract") && !arguments.contains("--reference-feasibility")
                    && !arguments.contains("--export") && !arguments.contains("--advection-fixtures") {
                    try emitJSON(["checked": true, "contractHash": expectedContractHash, "finite": true])
                    return
                }
            }

            if arguments.contains("--quick-contract") {
                try emitJSON(try quickContract())
                return
            }

            if arguments.contains("--reference-feasibility") {
                let full = try fullFeasibility()
                try emitJSON(full.payload)
                if (full.payload["passed"] as? Bool) != true { exit(1) }
                return
            }

            if let exportIndex = arguments.firstIndex(of: "--export") {
                guard arguments.indices.contains(exportIndex + 1),
                      let contractIndex = arguments.firstIndex(of: "--contract"),
                      arguments.indices.contains(contractIndex + 1) else {
                    throw ReferenceError.usage("--export requires a directory and --contract requires a contract path")
                }
                try checkContract(URL(fileURLWithPath: arguments[contractIndex + 1]))
                let full = try fullFeasibility()
                let output = try writeExport(URL(fileURLWithPath: arguments[exportIndex + 1], isDirectory: true), full)
                try emitJSON(output)
                return
            }
            if let fixturesIndex = arguments.firstIndex(of: "--advection-fixtures") {
                guard arguments.indices.contains(fixturesIndex + 1) else {
                    throw ReferenceError.usage("--advection-fixtures requires an output directory")
                }
                let output = try writeAdvectionFixtures(URL(
                    fileURLWithPath: arguments[fixturesIndex + 1], isDirectory: true
                ))
                try emitJSON(output)
                return
            }
            throw ReferenceError.usage("unrecognized reference command")
        } catch {
            FileHandle.standardError.write(Data("fluid3d reference error: \(error)\n".utf8))
            exit(2)
        }
    }
}
