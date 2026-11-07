/// CPU replay of the production Float32 PCG arithmetic and 256-lane tree
/// reductions. This is diagnostic-only: it does not participate in acceptance.
struct Fluid3DFloat32PCGDiagnosticResult {
    let trace: [Fluid3DPCGTraceRecord]
    let iterations: Int
    let restarts: Int
    let converged: Bool
    let recursiveResidualMaximum: Float
    let trueResidualMaximum: Float
}

enum Fluid3DFloat32PCGDiagnostic {
    private static let reductionWidth = 256

    static func solve(
        u: [Float],
        v: [Float],
        w: [Float],
        nx: Int = 64,
        ny: Int = 64,
        nz: Int = 64,
        h: Float = 1.0 / 64.0,
        dt: Float = 1.0 / 60.0,
        iterationLimit: Int = 320
    ) -> Fluid3DFloat32PCGDiagnosticResult {
        let count = nx * ny * nz
        Swift.precondition(u.count == (nx + 1) * ny * nz)
        Swift.precondition(v.count == nx * (ny + 1) * nz)
        Swift.precondition(w.count == nx * ny * (nz + 1))

        var rhs = Array(repeating: Float.zero, count: count)
        let inverseH = 1 / h
        for k in 0..<nz {
            for j in 0..<ny {
                for i in 0..<nx {
                    let cell = (k * ny + j) * nx + i
                    let uBase = (k * ny + j) * (nx + 1) + i
                    let vBase = (k * (ny + 1) + j) * nx + i
                    let wBase = (k * ny + j) * nx + i
                    var flux = u[uBase + 1] - u[uBase]
                    flux += v[vBase + nx] - v[vBase]
                    flux += w[wBase + nx * ny] - w[wBase]
                    let divergence = flux * inverseH
                    rhs[cell] = -h * h * divergence
                }
            }
        }

        let rhsReduction = reduceSumAndMaximum(rhs)
        let rhsMean = rhsReduction.sum / Float(count)
        let target = min(1e-5 as Float * h * h / dt, 1e-6 as Float)
        let candidateTrigger = 0.1 as Float * target
        var pressure = Array(repeating: Float.zero, count: count)
        var residual = rhs.map { $0 - rhsMean }
        var preconditioned = precondition(residual, nx: nx, ny: ny, nz: nz)
        let initialMean = reduceSumAndMaximum(preconditioned).sum / Float(count)
        for index in preconditioned.indices { preconditioned[index] -= initialMean }
        var direction = preconditioned
        var rho = reduceDot(residual, preconditioned)
        var restarts = 0
        var converged = false
        var iterations = 0
        var trace: [Fluid3DPCGTraceRecord] = []
        trace.reserveCapacity(iterationLimit)
        var recursiveResidualMaximum: Float = residual.map(abs).max() ?? 0
        var trueResidualMaximum: Float = .infinity

        for iteration in 1...iterationLimit {
            let appliedDirection = applyA(direction, nx: nx, ny: ny, nz: nz)
            let denominator = reduceDot(direction, appliedDirection)
            guard denominator.isFinite, denominator > 0, rho.isFinite, rho > 0 else { break }
            let alpha = rho / denominator
            guard alpha.isFinite else { break }
            for index in 0..<count {
                pressure[index] += alpha * direction[index]
                residual[index] -= alpha * appliedDirection[index]
            }

            let pressureResidualSums = reducePairedSums(pressure, residual)
            let pressureMean = pressureResidualSums.first / Float(count)
            let residualMean = pressureResidualSums.second / Float(count)
            for index in 0..<count {
                pressure[index] -= pressureMean
                residual[index] -= residualMean
            }
            recursiveResidualMaximum = reduceSumAndMaximum(residual).maximum
            let checkedTrueResidual = recursiveResidualMaximum <= candidateTrigger
            var currentTrueResidualMaximum: Float?
            var restartPending = false
            let failureCode: Float = 0

            if checkedTrueResidual {
                let appliedPressure = applyA(pressure, nx: nx, ny: ny, nz: nz)
                var trueResidual = Array(repeating: Float.zero, count: count)
                for index in 0..<count { trueResidual[index] = rhs[index] - appliedPressure[index] }
                let trueReduction = reduceSumAndMaximum(trueResidual)
                trueResidualMaximum = trueReduction.maximum
                currentTrueResidualMaximum = trueResidualMaximum
                if trueResidualMaximum <= target {
                    converged = true
                } else {
                    restarts += 1
                    restartPending = true
                    let trueMean = trueReduction.sum / Float(count)
                    for index in 0..<count { residual[index] = trueResidual[index] - trueMean }
                }
            }

            trace.append(Fluid3DPCGTraceRecord(
                iteration: iteration,
                recursiveResidualMaximum: recursiveResidualMaximum,
                checkedTrueResidual: checkedTrueResidual,
                rho: rho,
                alpha: alpha,
                trueResidualMaximum: currentTrueResidualMaximum,
                restartPending: restartPending,
                failureCode: failureCode,
                searchDenominator: denominator
            ))
            iterations = iteration
            if converged { break }

            let source = residual
            preconditioned = precondition(source, nx: nx, ny: ny, nz: nz)
            let preconditionedMean = reduceSumAndMaximum(preconditioned).sum / Float(count)
            for index in 0..<count { preconditioned[index] -= preconditionedMean }
            let nextRho = reduceDot(residual, preconditioned)
            guard nextRho.isFinite, nextRho > 0 else { break }
            if restartPending {
                direction = preconditioned
            } else {
                let beta = nextRho / rho
                guard beta.isFinite else { break }
                for index in 0..<count { direction[index] = preconditioned[index] + beta * direction[index] }
                let directionMean = reduceSumAndMaximum(direction).sum / Float(count)
                for index in 0..<count { direction[index] -= directionMean }
            }
            rho = nextRho
        }

        if let finalRecord = trace.last, !finalRecord.checkedTrueResidual {
            let appliedPressure = applyA(pressure, nx: nx, ny: ny, nz: nz)
            var finalResidual = Array(repeating: Float.zero, count: count)
            for index in 0..<count { finalResidual[index] = rhs[index] - appliedPressure[index] }
            trueResidualMaximum = reduceSumAndMaximum(finalResidual).maximum
        }
        if !trueResidualMaximum.isFinite {
            let appliedPressure = applyA(pressure, nx: nx, ny: ny, nz: nz)
            var finalResidual = Array(repeating: Float.zero, count: count)
            for index in 0..<count { finalResidual[index] = rhs[index] - appliedPressure[index] }
            trueResidualMaximum = reduceSumAndMaximum(finalResidual).maximum
        }

        return Fluid3DFloat32PCGDiagnosticResult(
            trace: trace,
            iterations: iterations,
            restarts: restarts,
            converged: converged,
            recursiveResidualMaximum: recursiveResidualMaximum,
            trueResidualMaximum: trueResidualMaximum
        )
    }

    private static func precondition(_ residual: [Float], nx: Int, ny: Int, nz: Int) -> [Float] {
        var result = Array(repeating: Float.zero, count: residual.count)
        for k in 0..<nz {
            for j in 0..<ny {
                for i in 0..<nx {
                    let index = (k * ny + j) * nx + i
                    let degree = (i > 0 ? 1 : 0) + (i + 1 < nx ? 1 : 0)
                        + (j > 0 ? 1 : 0) + (j + 1 < ny ? 1 : 0)
                        + (k > 0 ? 1 : 0) + (k + 1 < nz ? 1 : 0)
                    result[index] = residual[index] / Float(degree)
                }
            }
        }
        return result
    }

    private static func applyA(_ pressure: [Float], nx: Int, ny: Int, nz: Int) -> [Float] {
        var result = Array(repeating: Float.zero, count: pressure.count)
        for k in 0..<nz {
            for j in 0..<ny {
                for i in 0..<nx {
                    let index = (k * ny + j) * nx + i
                    let center = pressure[index]
                    var sum: Float = 0
                    if i > 0 { sum += center - pressure[index - 1] }
                    if i + 1 < nx { sum += center - pressure[index + 1] }
                    if j > 0 { sum += center - pressure[index - nx] }
                    if j + 1 < ny { sum += center - pressure[index + nx] }
                    if k > 0 { sum += center - pressure[index - nx * ny] }
                    if k + 1 < nz { sum += center - pressure[index + nx * ny] }
                    result[index] = sum
                }
            }
        }
        return result
    }

    private static func reduceSumAndMaximum(_ values: [Float]) -> (sum: Float, maximum: Float) {
        let groupCount = (values.count + reductionWidth - 1) / reductionWidth
        var partialSums = Array(repeating: Float.zero, count: groupCount)
        var partialMaximums = Array(repeating: Float.zero, count: groupCount)
        var lanes = Array(repeating: (sum: Float.zero, maximum: Float.zero), count: reductionWidth)
        for group in 0..<groupCount {
            let start = group * reductionWidth
            for lane in 0..<reductionWidth {
                let index = start + lane
                lanes[lane] = index < values.count
                    ? (values[index], abs(values[index]))
                    : (0, 0)
            }
            var stride = reductionWidth / 2
            while stride > 0 {
                for lane in 0..<stride {
                    lanes[lane].sum += lanes[lane + stride].sum
                    lanes[lane].maximum = max(lanes[lane].maximum, lanes[lane + stride].maximum)
                }
                stride >>= 1
            }
            partialSums[group] = lanes[0].sum
            partialMaximums[group] = lanes[0].maximum
        }

        for lane in 0..<reductionWidth {
            var index = lane
            var sum: Float = 0
            var maximum: Float = 0
            while index < groupCount {
                sum += partialSums[index]
                maximum = max(maximum, partialMaximums[index])
                index += reductionWidth
            }
            lanes[lane] = (sum, maximum)
        }
        var stride = reductionWidth / 2
        while stride > 0 {
            for lane in 0..<stride {
                lanes[lane].sum += lanes[lane + stride].sum
                lanes[lane].maximum = max(lanes[lane].maximum, lanes[lane + stride].maximum)
            }
            stride >>= 1
        }
        return lanes[0]
    }

    private static func reducePairedSums(_ first: [Float], _ second: [Float]) -> (first: Float, second: Float) {
        Swift.precondition(first.count == second.count)
        let groupCount = (first.count + reductionWidth - 1) / reductionWidth
        var partialFirst = Array(repeating: Float.zero, count: groupCount)
        var partialSecond = Array(repeating: Float.zero, count: groupCount)
        var lanes = Array(repeating: (first: Float.zero, second: Float.zero), count: reductionWidth)
        for group in 0..<groupCount {
            let start = group * reductionWidth
            for lane in 0..<reductionWidth {
                let index = start + lane
                lanes[lane] = index < first.count ? (first[index], second[index]) : (0, 0)
            }
            var stride = reductionWidth / 2
            while stride > 0 {
                for lane in 0..<stride {
                    lanes[lane].first += lanes[lane + stride].first
                    lanes[lane].second += lanes[lane + stride].second
                }
                stride >>= 1
            }
            partialFirst[group] = lanes[0].first
            partialSecond[group] = lanes[0].second
        }
        for lane in 0..<reductionWidth {
            var index = lane
            var firstSum: Float = 0
            var secondSum: Float = 0
            while index < groupCount {
                firstSum += partialFirst[index]
                secondSum += partialSecond[index]
                index += reductionWidth
            }
            lanes[lane] = (firstSum, secondSum)
        }
        var stride = reductionWidth / 2
        while stride > 0 {
            for lane in 0..<stride {
                lanes[lane].first += lanes[lane + stride].first
                lanes[lane].second += lanes[lane + stride].second
            }
            stride >>= 1
        }
        return lanes[0]
    }

    private static func reduceDot(_ first: [Float], _ second: [Float]) -> Float {
        Swift.precondition(first.count == second.count)
        let groupCount = (first.count + reductionWidth - 1) / reductionWidth
        var partials = Array(repeating: Float.zero, count: groupCount)
        var lanes = Array(repeating: Float.zero, count: reductionWidth)
        for group in 0..<groupCount {
            let start = group * reductionWidth
            for lane in 0..<reductionWidth {
                let index = start + lane
                lanes[lane] = index < first.count ? first[index] * second[index] : 0
            }
            var stride = reductionWidth / 2
            while stride > 0 {
                for lane in 0..<stride { lanes[lane] += lanes[lane + stride] }
                stride >>= 1
            }
            partials[group] = lanes[0]
        }
        for lane in 0..<reductionWidth {
            var index = lane
            var sum: Float = 0
            while index < groupCount {
                sum += partials[index]
                index += reductionWidth
            }
            lanes[lane] = sum
        }
        var stride = reductionWidth / 2
        while stride > 0 {
            for lane in 0..<stride { lanes[lane] += lanes[lane + stride] }
            stride >>= 1
        }
        return lanes[0]
    }
}
