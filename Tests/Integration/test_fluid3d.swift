import Foundation
import Metal
import simd

private enum Fluid3DHarnessError: Error, CustomStringConvertible {
    case usage(String)
    case assertion(String)
    case commandBuffer(String)
    case library(String)

    var description: String {
        switch self {
        case .usage(let message), .assertion(let message), .commandBuffer(let message), .library(let message):
            return message
        }
    }
}

@main
@MainActor
private struct Fluid3DChecks {
    private struct ProjectionFields {
        let u: VolumeField3D
        let v: VolumeField3D
        let w: VolumeField3D
    }

    private struct ProjectionReadback {
        let diagnostics: Fluid3DProjectionDiagnostics
        let u: [Float]
        let v: [Float]
        let w: [Float]
        // Reconstruct both Float32 pressure parts in Double. Rounding the
        // readback back to Float would hide the representation being tested.
        let pressure: [Double]
        let divergence: [Float]
        let trueResidual: [Float]
        let identityError: [Float]
    }

    static func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        guard condition() else { throw Fluid3DHarnessError.assertion(message) }
    }

    static func command(_ metal: MetalDevice, _ encode: (MTLCommandBuffer) throws -> Void) throws {
        let buffer = metal.newCommandBuffer()
        try encode(buffer)
        buffer.commit()
        buffer.waitUntilCompleted()
        guard buffer.status == .completed else {
            throw Fluid3DHarnessError.commandBuffer("Metal command failed: \(String(describing: buffer.error))")
        }
    }

    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        guard arguments.count == 3 else {
            throw Fluid3DHarnessError.usage(
                "usage: test_fluid3d <fresh-default.metallib> <reference-directory> <fixture>"
            )
        }
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw Fluid3DHarnessError.library("Metal device unavailable; production GPU tests cannot run")
        }
        let libraryURL = URL(fileURLWithPath: arguments[0])
        let library: MTLLibrary
        do {
            library = try device.makeLibrary(URL: libraryURL)
        } catch {
            throw Fluid3DHarnessError.library(
                "Could not load production metallib at \(libraryURL.path): \(error)"
            )
        }
        let metal = MetalDevice(device: device, library: library)
        let fixture = arguments[2]
        guard fixture == "storage-abi" || fixture == "advection-boundaries"
                || fixture == "slice-palette"
                || fixture == "evolution-visibility"
                || fixture == "operators" || fixture == "projection" || fixture == "reset-finite" else {
            throw Fluid3DHarnessError.usage("unknown fixture selector: \(fixture)")
        }
        let result: [String: Any]
        if fixture == "slice-palette" {
            result = try sliceAndPalette(
                device: device,
                metal: metal,
                referenceDirectory: URL(fileURLWithPath: arguments[1], isDirectory: true)
            )
        } else if fixture == "evolution-visibility" {
            result = try evolutionAndVisibility(
                device: device,
                metal: metal,
                referenceDirectory: URL(fileURLWithPath: arguments[1], isDirectory: true)
            )
        } else if fixture == "storage-abi" {
            result = try storageAndABI(device: device, metal: metal)
        } else if fixture == "advection-boundaries" {
            result = try advectionAndBoundaries(
                device: device,
                metal: metal,
                referenceDirectory: URL(fileURLWithPath: arguments[1], isDirectory: true)
            )
        } else if fixture == "operators" {
            result = try operatorFixture(
                device: device,
                metal: metal,
                referenceDirectory: URL(fileURLWithPath: arguments[1], isDirectory: true)
            )
        } else if fixture == "reset-finite" {
            result = try resetAndFinite(metal: metal, referenceDirectory: URL(fileURLWithPath: arguments[1]))
        } else {
            result = try projectionFixture(
                device: device,
                metal: metal,
                referenceDirectory: URL(fileURLWithPath: arguments[1], isDirectory: true)
            )
        }
        try emit(result)
    }

    private struct SliceImage {
        let width: Int
        let height: Int
        let pixels: [UInt8]
    }

    private struct EncodedSimulationSnapshot {
        let fields: [(String, VolumeField3D, MTLBuffer)]
        let workspace: MTLBuffer
    }

    private struct VelocitySnapshot {
        let u: [Float]
        let v: [Float]
        let w: [Float]
    }

    private struct EvolutionObservation {
        let step: Int
        let fields: [String: [Float]]
        let slice: [Float]
        let image: SliceImage
        let diagnostics: Fluid3DProjectionDiagnostics
        let statusLanes: [Float]
        let volumeStatistics: [String: Any]
        let stateCapture: [String: Any]
        let sliceCapture: String
    }

    private static func sliceAndPalette(
        device: MTLDevice,
        metal: MetalDevice,
        referenceDirectory: URL
    ) throws -> [String: Any] {
        let visualization = try FieldVisualization3D(metal: metal)
        let simulation = try FluidSimulation3D(metal: metal)
        let evidenceDirectory = referenceDirectory.deletingLastPathComponent()
            .appendingPathComponent("fluid3d-evidence", isDirectory: true)
        try FileManager.default.createDirectory(
            at: evidenceDirectory, withIntermediateDirectories: true
        )
        let originalConfiguration = simulation.configuration
        var resetStatus: PressureProjection3D.StatusSlot!

        try reset(metal: metal, simulation: simulation, dye: paletteAndOrientationDye()) {
            resetStatus = $0
        }
        try require(resetStatus.diagnostics().converged, "Synthetic slice reset projection failed")
        let paletteCapture = try verifyReadOnlyPresentation(
            visualization: visualization,
            simulation: simulation,
            status: resetStatus,
            sizes: [(96, 64)]
        )
        let landmarks = paletteCapture.images[0]
        let xOffset = 16
        let paletteSamples: [(String, Int, SIMD3<Int>)] = [
            ("zero", 6, SIMD3<Int>(0, 0, 0)),
            ("quarter", 17, SIMD3<Int>(119, 70, 18)),
            ("middle", 28, SIMD3<Int>(237, 139, 35)),
            ("three-quarters", 39, SIMD3<Int>(246, 190, 125)),
            ("one", 50, SIMD3<Int>(255, 241, 214)),
        ]
        for (name, cellX, expected) in paletteSamples {
            try assertRGB(
                landmarks,
                x: xOffset + cellX,
                y: 63 - 8,
                expected: expected,
                label: "palette stop \(name)"
            )
        }
        try assertRGB(landmarks, x: xOffset + 12, y: 63 - 12,
                      expected: SIMD3<Int>(237, 139, 35), label: "lower-left landmark")
        try assertRGB(landmarks, x: xOffset + 52, y: 63 - 52,
                      expected: SIMD3<Int>(255, 241, 214), label: "upper-right landmark")
        try assertRGB(landmarks, x: xOffset + 12, y: 63 - 52,
                      expected: SIMD3<Int>(0, 0, 0), label: "opposite upper-left landmark")
        try assertRGB(landmarks, x: xOffset + 52, y: 63 - 12,
                      expected: SIMD3<Int>(0, 0, 0), label: "opposite lower-right landmark")
        try assertRGB(landmarks, x: 4, y: 32, expected: SIMD3<Int>(0, 0, 0), label: "left letterbox")
        try assertRGB(landmarks, x: 90, y: 32, expected: SIMD3<Int>(0, 0, 0), label: "right letterbox")
        let palettePath = evidenceDirectory.appendingPathComponent("slice-palette-stops-orientation.ppm")
        try writePPM(landmarks, to: palettePath)

        try reset(metal: metal, simulation: simulation, dye: zRampDye()) {
            resetStatus = $0
        }
        try require(resetStatus.diagnostics().converged, "Z-ramp reset projection failed")
        let midpointCapture = try verifyReadOnlyPresentation(
            visualization: visualization,
            simulation: simulation,
            status: resetStatus,
            sizes: [(96, 64)]
        )
        try assertRGB(midpointCapture.images[0], x: 48, y: 32,
                      expected: SIMD3<Int>(237, 139, 35), label: "equal Z=0.5 midpoint of planes 31/32")
        let midpointPath = evidenceDirectory.appendingPathComponent("slice-palette-midpoint-z-31-32.ppm")
        try writePPM(midpointCapture.images[0], to: midpointPath)

        try reset(metal: metal, simulation: simulation, dye: constantDye(0.5)) {
            resetStatus = $0
        }
        try require(resetStatus.diagnostics().converged, "Uniform palette-invariance reset failed")
        let sizes = [(64, 64), (96, 64), (48, 48)]
        let stepZeroCapture = try verifyReadOnlyPresentation(
            visualization: visualization,
            simulation: simulation,
            status: resetStatus,
            sizes: sizes
        )
        for image in stepZeroCapture.images {
            try assertRGB(image, x: image.width / 2, y: image.height / 2,
                          expected: SIMD3<Int>(237, 139, 35), label: "step-zero fixed palette/viewport")
        }
        let stepZeroPath = evidenceDirectory.appendingPathComponent("slice-palette-step-0.ppm")
        try writePPM(stepZeroCapture.images[0], to: stepZeroPath)

        var stepStatus: PressureProjection3D.StatusSlot!
        try command(metal) { stepStatus = try simulation.encodeStep(command: $0) }
        try require(stepStatus.diagnostics().failure == .none && stepStatus.diagnostics().converged,
                    "Uniform one-step palette fixture failed projection")
        let stepOneCapture = try verifyReadOnlyPresentation(
            visualization: visualization,
            simulation: simulation,
            status: stepStatus,
            sizes: sizes
        )
        for image in stepOneCapture.images {
            try assertRGB(image, x: image.width / 2, y: image.height / 2,
                          expected: SIMD3<Int>(237, 139, 35), label: "step-one fixed palette/viewport")
        }
        let stepOnePath = evidenceDirectory.appendingPathComponent("slice-palette-step-1.ppm")
        try writePPM(stepOneCapture.images[1], to: stepOnePath)

        try reset(metal: metal, simulation: simulation, dye: Array(repeating: 0, count: 64 * 64 * 64)) {
            resetStatus = $0
        }
        try require(resetStatus.diagnostics().converged, "Clamped-palette fixture reset failed")
        try command(metal) {
            try simulation.dye.encodeUpload(
                Array(repeating: 1.25, count: 64 * 64 * 64),
                to: simulation.dye.ping,
                command: $0
            )
        }
        let clampedCapture = try verifyReadOnlyPresentation(
            visualization: visualization,
            simulation: simulation,
            status: resetStatus,
            sizes: [(64, 64)]
        )
        try assertRGB(clampedCapture.images[0], x: 32, y: 32,
                      expected: SIMD3<Int>(255, 241, 214), label: "concentration clamps at the cream stop")
        let clampPath = evidenceDirectory.appendingPathComponent("slice-palette-concentration-clamp.ppm")
        try writePPM(clampedCapture.images[0], to: clampPath)

        try require(simulation.configuration == originalConfiguration,
                    "Presentation changed the fixed simulation grid/configuration")
        let manifestURL = referenceDirectory.appendingPathComponent("manifest.json")
        let manifest = try JSONSerialization.jsonObject(with: Data(contentsOf: manifestURL)) as! [String: Any]
        return [
            "passed": true,
            "fixture": "slice-palette",
            "device": device.name,
            "grid": [64, 64, 64],
            "sampleWorldZ": 0.5,
            "sampledPlanes": [31, 32],
            "sampleWeights": [0.5, 0.5],
            "orientation": ["x": "right", "y": "up"],
            "destinationPixelFormat": "bgra8Unorm; encoded palette channels stored without an additional sRGB transform",
            "paletteStops": [
                ["concentration": 0.0, "rgb": [0, 0, 0]],
                ["concentration": 0.5, "rgb": [237, 139, 35]],
                ["concentration": 1.0, "rgb": [255, 241, 214]],
            ],
            "viewportSizes": sizes.map { [$0.0, $0.1] },
            "paletteInvariantAtSteps": [0, 1],
            "renderingReadOnly": true,
            "resourceHashes": [paletteCapture.resourceHash, midpointCapture.resourceHash,
                               stepZeroCapture.resourceHash, stepOneCapture.resourceHash,
                               clampedCapture.resourceHash],
            "captures": [palettePath.lastPathComponent, midpointPath.lastPathComponent,
                         stepZeroPath.lastPathComponent, stepOnePath.lastPathComponent,
                         clampPath.lastPathComponent],
            "contractHash": manifest["contractHash"] ?? "unknown",
            "finite": true,
        ]
    }

    private static func evolutionAndVisibility(
        device: MTLDevice,
        metal: MetalDevice,
        referenceDirectory: URL
    ) throws -> [String: Any] {
        let visualization = try FieldVisualization3D(metal: metal)
        let simulation = try FluidSimulation3D(metal: metal)
        let grid = simulation.configuration
        try require(grid == .production, "Lesson recipe must use the fixed production 64-cubed grid")
        let evidenceDirectory = referenceDirectory.deletingLastPathComponent()
            .appendingPathComponent("fluid3d-evidence", isDirectory: true)
        try FileManager.default.createDirectory(
            at: evidenceDirectory, withIntermediateDirectories: true
        )

        var initialStatus: PressureProjection3D.StatusSlot!
        try command(metal) { initialStatus = try simulation.encodeReset(command: $0) }
        let initialDiagnostics = initialStatus.diagnostics()
        try require(initialDiagnostics.failure == .none && initialDiagnostics.converged && !initialDiagnostics.capHit,
                    "Default lesson reset did not pass the production projection gate: \(initialDiagnostics.failure)")
        let initialFields = try scanSimulation(simulation)
        let initialDye = initialFields["dye/ping"]!
        let initialPeak = initialDye.max() ?? 0
        try require(initialPeak >= 0.5,
                    "Production reset recipe must start with a visible compact dye blob; peak=\(initialPeak)")

        let supportCount = initialDye.filter { $0 >= 0.001 }.count
        try require(supportCount > 0 && supportCount < initialDye.count / 10,
                    "Step-zero dye support is not one compact seed: support=\(supportCount)")
        let initialStats = volumeStatistics(initialDye, nx: grid.nx, ny: grid.ny, nz: grid.nz)
        let initialCentroid = initialStats["centroid"] as! [Double]
        try require(abs(initialCentroid[0] - 0.42) < 0.02
                    && abs(initialCentroid[1] - 0.48) < 0.02
                    && abs(initialCentroid[2] - 0.52) < 0.02,
                    "Step-zero dye is not centred on the approved off-centre blob: \(initialCentroid)")
        try require(connectedComponents(initialDye, nx: grid.nx, ny: grid.ny, nz: grid.nz,
                                       threshold: 0.001) == 1,
                    "Step-zero dye must contain exactly one compact connected blob")

        var observations: [Int: EvolutionObservation] = [:]
        let firstVelocity = velocitySnapshot(from: initialFields)
        let initialSpeedMaximum = cellCenteredSpeedMaximum(firstVelocity, nx: grid.nx, ny: grid.ny, nz: grid.nz)
        try require(initialSpeedMaximum.isFinite && initialSpeedMaximum > 0,
                    "Reset recipe has no finite three-component transport velocity")
        var probePaths = makeDyeSeededProbePaths(center: SIMD3<Double>(0.42, 0.48, 0.52))
        let probeStarts = probePaths.map { $0[0] }
        for start in probeStarts {
            try require(sampleCellCentered(initialDye, nx: grid.nx, ny: grid.ny, nz: grid.nz,
                                           position: start) >= 0.5,
                        "Independent probe was not seeded inside visible dye")
        }

        let stepZeroImage = try captureSlice(
            visualization: visualization,
            simulation: simulation,
            step: 0,
            directory: evidenceDirectory
        )
        let stepZeroSlice = centralSlice(initialDye, nx: grid.nx, ny: grid.ny, nz: grid.nz)
        try compareSliceImage(stepZeroImage, concentrations: stepZeroSlice)
        let stepZeroState = try saveEvolutionState(
            fields: initialFields,
            status: initialStatus.diagnosticStateValues(),
            step: 0,
            directory: evidenceDirectory
        )
        observations[0] = EvolutionObservation(
            step: 0,
            fields: initialFields,
            slice: stepZeroSlice,
            image: stepZeroImage,
            diagnostics: initialDiagnostics,
            statusLanes: initialStatus.diagnosticStateValues(),
            volumeStatistics: initialStats,
            stateCapture: stepZeroState,
            sliceCapture: "recipe-step-000.ppm"
        )

        var activeVelocity = firstVelocity
        var maximumIterations = initialDiagnostics.iterations
        var statusSummaries: [[String: Any]] = [[
            "step": 0,
            "iterations": initialDiagnostics.iterations,
            "failure": initialDiagnostics.failure.description,
            "converged": initialDiagnostics.converged,
            "trueResidualDTInf": initialDiagnostics.trueResidualDTInf,
            "projectedDivergenceDTInf": initialDiagnostics.projectedDivergenceDTInf,
        ]]
        let observationSteps: Set<Int> = [1, 24, 48, 72]
        for step in 1...72 {
            advanceProbePaths(&probePaths, with: activeVelocity, grid: grid)
            let buffer = metal.newCommandBuffer()
            let status = try simulation.encodeStep(command: buffer)
            buffer.commit()
            buffer.waitUntilCompleted()
            try require(buffer.status == .completed,
                        "Production advance \(step) command failed: \(String(describing: buffer.error))")
            let diagnostics = status.diagnostics()
            try require(diagnostics.failure == .none && diagnostics.converged && !diagnostics.capHit,
                        "Production step \(step) failed projection acceptance: \(diagnostics.failure)")
            try require(diagnostics.trueResidualDTInf <= 1e-5
                        && diagnostics.projectedDivergenceDTInf <= 1e-5
                        && diagnostics.identityDTError <= 2e-5
                        && diagnostics.maximumWallNormalValue == 0,
                        "Production step \(step) violated the preregistered pressure/wall gate: "
                        + "residual=\(diagnostics.trueResidualDTInf), "
                        + "divergence=\(diagnostics.projectedDivergenceDTInf), "
                        + "identity=\(diagnostics.identityDTError) (GPU limit 2e-5), "
                        + "wall=\(diagnostics.maximumWallNormalValue)")
            maximumIterations = max(maximumIterations, diagnostics.iterations)
            statusSummaries.append([
                "step": step,
                "iterations": diagnostics.iterations,
                "failure": diagnostics.failure.description,
                "converged": diagnostics.converged,
                "trueResidualDTInf": diagnostics.trueResidualDTInf,
                "projectedDivergenceDTInf": diagnostics.projectedDivergenceDTInf,
                "identityDTError": diagnostics.identityDTError,
                "maximumWallNormalValue": diagnostics.maximumWallNormalValue,
            ])

            if observationSteps.contains(step) {
                let fields = try scanSimulation(simulation)
                let dye = fields["dye/ping"]!
                let image = try captureSlice(
                    visualization: visualization,
                    simulation: simulation,
                    step: step,
                    directory: evidenceDirectory
                )
                let slice = centralSlice(dye, nx: grid.nx, ny: grid.ny, nz: grid.nz)
                try compareSliceImage(image, concentrations: slice)
                let statistics = volumeStatistics(dye, nx: grid.nx, ny: grid.ny, nz: grid.nz)
                let stateCapture = try saveEvolutionState(
                    fields: fields,
                    status: status.diagnosticStateValues(),
                    step: step,
                    directory: evidenceDirectory
                )
                observations[step] = EvolutionObservation(
                    step: step,
                    fields: fields,
                    slice: slice,
                    image: image,
                    diagnostics: diagnostics,
                    statusLanes: status.diagnosticStateValues(),
                    volumeStatistics: statistics,
                    stateCapture: stateCapture,
                    sliceCapture: String(format: "recipe-step-%03d.ppm", step)
                )
                activeVelocity = velocitySnapshot(from: fields)
            } else {
                activeVelocity = try readActiveVelocity(simulation)
            }
        }

        let stepZero = observations[0]!
        let stepOne = observations[1]!
        let step24 = observations[24]!
        let step48 = observations[48]!
        let step72 = observations[72]!
        let peak0 = stepZero.slice.max() ?? 0
        let peak24 = step24.slice.max() ?? 0
        let peak48 = step48.slice.max() ?? 0
        let visible24 = step24.slice.filter { $0 >= 0.02 }.count
        let visible48 = step48.slice.filter { $0 >= 0.02 }.count
        let sliceRMS48 = rmsDifference(stepZero.slice, step48.slice)
        try require(peak0 >= 0.5, "Step-zero central slice peak is below 0.5: \(peak0)")
        try require(peak24 >= 0.05 && visible24 >= 8,
                    "Step-24 fixed slice misses preregistered visibility: peak=\(peak24), count=\(visible24)")
        try require(peak48 >= 0.05 && visible48 >= 8,
                    "Step-48 fixed slice misses preregistered visibility: peak=\(peak48), count=\(visible48)")
        try require(sliceRMS48 >= 0.005,
                    "Step-48 fixed slice did not change enough from step zero: RMS=\(sliceRMS48)")

        let velocity72 = velocitySnapshot(from: step72.fields)
        let velocityChanges = [
            "u": maximumAbsoluteDifference(firstVelocity.u, velocity72.u),
            "v": maximumAbsoluteDifference(firstVelocity.v, velocity72.v),
            "w": maximumAbsoluteDifference(firstVelocity.w, velocity72.w),
        ]
        let velocityChangeRatios = velocityChanges.mapValues { $0 / initialSpeedMaximum }
        for component in ["u", "v", "w"] {
            try require(velocityChangeRatios[component, default: 0] >= 1e-4,
                        "Production \(component) did not genuinely evolve: normalized change=\(velocityChangeRatios[component, default: 0])")
        }
        let depthVariation = maximumCellCenteredDepthVariation(velocity72, nx: grid.nx, ny: grid.ny, nz: grid.nz)
        let depthVariationRatio = depthVariation / initialSpeedMaximum
        try require(depthVariationRatio >= 1e-3,
                    "Production velocity is too depth-independent: normalized variation=\(depthVariationRatio)")

        let probeMetrics = probePaths.map { probeMetric(points: $0, grid: grid) }
        let maximumProbeZTravelCells = probeMetrics.map { $0.zTravelCells }.max() ?? 0
        let maximumProbePlaneRatio = probeMetrics.map { $0.planeRMSArcRatio }.max() ?? 0
        try require(maximumProbeZTravelCells >= 0.5,
                    "No dye-seeded production-field trajectory crossed half a cell in Z: \(maximumProbeZTravelCells) cells")

        let referenceManifest = try JSONSerialization.jsonObject(
            with: Data(contentsOf: referenceDirectory.appendingPathComponent("manifest.json"))
        ) as! [String: Any]
        guard let analyticTrajectory = referenceManifest["referenceTrajectory"] as? [String: Any],
              let referencePlaneRatio = analyticTrajectory["plane_rms_arc_ratio"] as? Double,
              let referenceZTravel = analyticTrajectory["centroid_z_displacement_cells"] as? Double,
              analyticTrajectory["finite"] as? Bool == true else {
            throw Fluid3DHarnessError.assertion("CPU reference omitted finite nonplanar trajectory evidence")
        }
        try require(referencePlaneRatio >= 0.01 && referenceZTravel >= 0.5,
                    "Independent CPU nonplanar reference missed its preregistered threshold: \(analyticTrajectory)")

        let asymmetricTransport = try runAsymmetricFullVolumeTransport(
            metal: metal,
            referenceDirectory: referenceDirectory
        )
        let recipe = [
            "grid": [grid.nx, grid.ny, grid.nz],
            "h": grid.h,
            "dt": grid.dt,
            "vectorPotential": "A=(0.7*f, f*sin^2(pi*y), 0.6*f*sin^2(pi*z)); f=sin^2(pi*x)sin^2(pi*y)sin^2(pi*z)",
            "seedMaximumVectorSpeed": 0.12,
            "blobCenter": [0.42, 0.48, 0.52],
            "blobRadius": 0.12,
            "blobPeak": 1.0,
            "dyeDecayPerStep": 0.0,
            "velocityReseedAfterReset": false,
        ] as [String: Any]
        return [
            "passed": true,
            "fixture": "evolution-visibility",
            "device": device.name,
            "os": ProcessInfo.processInfo.operatingSystemVersionString,
            "recipe": recipe,
            "step0Blob": [
                "peak": initialPeak,
                "supportAtLeast0_001": supportCount,
                "connectedComponents": 1,
                "centroid": initialCentroid,
                "volumeStatistics": initialStats,
                "resetVectorSpeedMaximum": initialSpeedMaximum,
            ],
            "observations": [stepZero, stepOne, step24, step48, step72].map { observation in
                [
                    "step": observation.step,
                    "slicePeak": observation.slice.max() ?? 0,
                    "sliceCountAtLeast0_02": observation.slice.filter { $0 >= 0.02 }.count,
                    "sliceRMSFromStep0": rmsDifference(stepZero.slice, observation.slice),
                    "volumeStatistics": observation.volumeStatistics,
                    "projection": projectionSummary(observation.diagnostics),
                    "statusLanes": observation.statusLanes,
                    "stateCapture": observation.stateCapture,
                    "sliceCapture": observation.sliceCapture,
                ] as [String: Any]
            },
            "visibilityGates": [
                "step0PeakMinimum": 0.5,
                "step24PeakMinimum": 0.05,
                "step24CountAtLeast0_02Minimum": 8,
                "step48PeakMinimum": 0.05,
                "step48CountAtLeast0_02Minimum": 8,
                "step48RMSFromStep0Minimum": 0.005,
                "observedStep48RMSFromStep0": sliceRMS48,
            ],
            "velocityChangeMaxAbsolute": velocityChanges,
            "velocityChangeNormalizedByResetSpeed": velocityChangeRatios,
            "depthVariationMaxAbsolute": depthVariation,
            "depthVariationNormalizedByResetSpeed": depthVariationRatio,
            "dyeSeededProbePaths": probeMetrics.map(\.json),
            "maximumProbeZTravelCells": maximumProbeZTravelCells,
            "maximumObservedProbePlaneRMSArcRatio": maximumProbePlaneRatio,
            "analyticReferenceTrajectory": analyticTrajectory,
            "minimumAnalyticReferencePlaneRMSArcRatio": 0.01,
            "independentFullVolumeUnequalAxisTransport": asymmetricTransport,
            "projectionStatuses": statusSummaries,
            "maximumProjectionIterations": maximumIterations,
            "finite": true,
            "captures": [stepZero, stepOne, step24, step48, step72].flatMap {
                [$0.sliceCapture, $0.stateCapture["file"] as! String]
            },
        ]
    }

    private static func reset(
        metal: MetalDevice,
        simulation: FluidSimulation3D,
        dye: [Float],
        status: (PressureProjection3D.StatusSlot) -> Void
    ) throws {
        var result: PressureProjection3D.StatusSlot!
        let seed = Fluid3DInitialState(
            u: Array(repeating: 0, count: simulation.u.width * simulation.u.height * simulation.u.depth),
            v: Array(repeating: 0, count: simulation.v.width * simulation.v.height * simulation.v.depth),
            w: Array(repeating: 0, count: simulation.w.width * simulation.w.height * simulation.w.depth),
            dye: dye
        )
        try command(metal) { result = try simulation.encodeReset(command: $0, initialState: seed) }
        status(result)
    }

    private static func constantDye(_ value: Float) -> [Float] {
        Array(repeating: value, count: 64 * 64 * 64)
    }

    private static func paletteAndOrientationDye() -> [Float] {
        let n = 64
        var dye = Array(repeating: Float.zero, count: n * n * n)
        let patches: [(Int, Int, Float)] = [
            (6, 8, 0), (17, 8, 0.25), (28, 8, 0.5), (39, 8, 0.75), (50, 8, 1),
            (12, 12, 0.5), (52, 52, 1),
        ]
        for k in 0..<n {
            for (centerX, centerY, value) in patches {
                for j in (centerY - 1)...(centerY + 1) {
                    for i in (centerX - 1)...(centerX + 1) {
                        dye[(k * n + j) * n + i] = value
                    }
                }
            }
        }
        return dye
    }

    private static func zRampDye() -> [Float] {
        let n = 64
        var dye = Array(repeating: Float.zero, count: n * n * n)
        for k in 0..<n {
            let value = Float(k) / Float(n - 1)
            let start = k * n * n
            for index in start..<(start + n * n) { dye[index] = value }
        }
        return dye
    }

    private static func verifyReadOnlyPresentation(
        visualization: FieldVisualization3D,
        simulation: FluidSimulation3D,
        status: PressureProjection3D.StatusSlot,
        sizes: [(Int, Int)]
    ) throws -> (images: [SliceImage], resourceHash: String) {
        let configurationBefore = simulation.configuration
        let command = simulation.metal.newCommandBuffer()
        let statusBefore = status.diagnosticStateValues()
        let before = try encodeSimulationSnapshot(simulation, command: command)
        var destinations: [(Int, Int, MTLTexture)] = []
        for (width, height) in sizes {
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: FieldVisualization3D.destinationPixelFormat,
                width: width,
                height: height,
                mipmapped: false
            )
            descriptor.storageMode = .shared
            descriptor.usage = [.renderTarget]
            guard let destination = simulation.metal.device.makeTexture(descriptor: descriptor) else {
                throw Fluid3DHarnessError.library("Unable to allocate a synthetic slice render target")
            }
            destinations.append((width, height, destination))
            try visualization.encodeSlice(
                command: command,
                simulation: simulation,
                destination: destination,
                viewport: MTLViewport(originX: 0, originY: 0, width: Double(width), height: Double(height), znear: 0, zfar: 1)
            )
        }
        let after = try encodeSimulationSnapshot(simulation, command: command)
        command.commit()
        command.waitUntilCompleted()
        try require(command.status == .completed, "Read-only slice presentation command failed")
        try require(simulation.configuration == configurationBefore,
                    "Slice presentation changed grid dimensions, spacing, or timestep")

        let beforeHash = try hashSimulationSnapshot(before, status: statusBefore, configuration: configurationBefore)
        let afterHash = try hashSimulationSnapshot(after, status: status.diagnosticStateValues(), configuration: simulation.configuration)
        try require(beforeHash == afterHash,
                    "Slice rendering mutated solver fields, scratch, reductions, status, or grid: \(beforeHash) != \(afterHash)")

        let images = try destinations.map { width, height, texture -> SliceImage in
            var pixels = Array(repeating: UInt8.zero, count: width * height * 4)
            pixels.withUnsafeMutableBytes { bytes in
                texture.getBytes(
                    bytes.baseAddress!,
                    bytesPerRow: width * 4,
                    from: MTLRegionMake2D(0, 0, width, height),
                    mipmapLevel: 0
                )
            }
            return SliceImage(width: width, height: height, pixels: pixels)
        }
        return (images, beforeHash)
    }

    private static func encodeSimulationSnapshot(
        _ simulation: FluidSimulation3D,
        command: MTLCommandBuffer
    ) throws -> EncodedSimulationSnapshot {
        var fields: [(String, VolumeField3D, MTLBuffer)] = []
        for (name, field) in simulation.diagnosticFields {
            for (generation, texture) in [("ping", field.ping), ("pong", field.pong)] {
                fields.append(("\(name)/\(generation)", field,
                               try field.encodeReadback(from: texture, command: command)))
            }
        }
        let workspace = simulation.projection.diagnosticReductionWorkspace
        guard let workspaceReadback = simulation.metal.device.makeBuffer(
            length: workspace.length, options: .storageModeShared
        ), let blit = command.makeBlitCommandEncoder() else {
            throw Fluid3DHarnessError.assertion("Could not stage complete solver-resource snapshot")
        }
        blit.copy(from: workspace, sourceOffset: 0, to: workspaceReadback,
                  destinationOffset: 0, size: workspace.length)
        blit.endEncoding()
        return EncodedSimulationSnapshot(fields: fields, workspace: workspaceReadback)
    }

    private static func hashSimulationSnapshot(
        _ snapshot: EncodedSimulationSnapshot,
        status: [Float],
        configuration: FluidSimulation3DConfiguration
    ) throws -> String {
        var hash: UInt64 = 0xcbf29ce484222325
        func feed(_ byte: UInt8) {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        func feedWord(_ input: UInt32) {
            var word = input
            for _ in 0..<4 {
                feed(UInt8(truncatingIfNeeded: word))
                word >>= 8
            }
        }
        feedWord(UInt32(configuration.nx)); feedWord(UInt32(configuration.ny)); feedWord(UInt32(configuration.nz))
        feedWord(configuration.h.bitPattern); feedWord(configuration.dt.bitPattern)
        for (name, field, buffer) in snapshot.fields {
            for byte in name.utf8 { feed(byte) }
            feed(0)
            let values = try field.decodeReadback(buffer)
            feedWord(UInt32(values.count))
            for value in values { feedWord(value.bitPattern) }
        }
        let workspaceBytes = snapshot.workspace.contents().assumingMemoryBound(to: UInt8.self)
        feedWord(UInt32(snapshot.workspace.length))
        for index in 0..<snapshot.workspace.length { feed(workspaceBytes[index]) }
        for value in status { feedWord(value.bitPattern) }
        return String(format: "%016llx", hash)
    }

    private static func assertRGB(
        _ image: SliceImage,
        x: Int,
        y: Int,
        expected: SIMD3<Int>,
        label: String
    ) throws {
        try require(x >= 0 && x < image.width && y >= 0 && y < image.height,
                    "\(label) sample (\(x),\(y)) is outside the render target")
        let offset = (y * image.width + x) * 4
        let actual = SIMD3<Int>(Int(image.pixels[offset + 2]), Int(image.pixels[offset + 1]), Int(image.pixels[offset]))
        let withinQuantization = zip([actual.x, actual.y, actual.z], [expected.x, expected.y, expected.z])
            .allSatisfy { abs($0.0 - $0.1) <= 1 }
        try require(withinQuantization,
                    "\(label) RGB mismatch at (\(x),\(y)): actual=\(actual), expected=\(expected) ±1 UNORM code")
        try require(image.pixels[offset + 3] == 255, "\(label) alpha must remain opaque")
    }

    private static func writePPM(_ image: SliceImage, to url: URL) throws {
        var output = Data("P6\n\(image.width) \(image.height)\n255\n".utf8)
        output.reserveCapacity(output.count + image.width * image.height * 3)
        for y in 0..<image.height {
            for x in 0..<image.width {
                let offset = (y * image.width + x) * 4
                output.append(contentsOf: [image.pixels[offset + 2], image.pixels[offset + 1], image.pixels[offset]])
            }
        }
        try output.write(to: url, options: .atomic)
    }

    private struct ProbeMetric {
        let zTravelCells: Double
        let planeRMSArcRatio: Double
        let points: [[Double]]

        var json: [String: Any] {
            [
                "zTravelCells": zTravelCells,
                "planeRMSArcRatio": planeRMSArcRatio,
                "points": points,
            ]
        }
    }

    private static func projectionSummary(_ value: Fluid3DProjectionDiagnostics) -> [String: Any] {
        [
            "iterations": value.iterations,
            "failure": value.failure.description,
            "converged": value.converged,
            "capHit": value.capHit,
            "inputDivergenceDTInf": value.inputDivergenceDTInf,
            "projectedDivergenceDTInf": value.projectedDivergenceDTInf,
            "trueResidualDTInf": value.trueResidualDTInf,
            "identityDTError": value.identityDTError,
            "maximumWallNormalValue": value.maximumWallNormalValue,
        ]
    }

    private static func velocitySnapshot(from fields: [String: [Float]]) -> VelocitySnapshot {
        VelocitySnapshot(u: fields["u/ping"]!, v: fields["v/ping"]!, w: fields["w/ping"]!)
    }

    private static func readActiveVelocity(_ simulation: FluidSimulation3D) throws -> VelocitySnapshot {
        let command = simulation.metal.newCommandBuffer()
        let uReadback = try simulation.u.encodeReadback(from: simulation.u.ping, command: command)
        let vReadback = try simulation.v.encodeReadback(from: simulation.v.ping, command: command)
        let wReadback = try simulation.w.encodeReadback(from: simulation.w.ping, command: command)
        command.commit()
        command.waitUntilCompleted()
        try require(command.status == .completed, "Velocity probe readback failed")
        return VelocitySnapshot(
            u: try simulation.u.decodeReadback(uReadback),
            v: try simulation.v.decodeReadback(vReadback),
            w: try simulation.w.decodeReadback(wReadback)
        )
    }

    private static func captureSlice(
        visualization: FieldVisualization3D,
        simulation: FluidSimulation3D,
        step: Int,
        directory: URL
    ) throws -> SliceImage {
        let size = 64
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: FieldVisualization3D.destinationPixelFormat,
            width: size,
            height: size,
            mipmapped: false
        )
        descriptor.storageMode = .shared
        descriptor.usage = [.renderTarget]
        guard let destination = simulation.metal.device.makeTexture(descriptor: descriptor) else {
            throw Fluid3DHarnessError.library("Unable to allocate a lesson slice capture")
        }
        let command = simulation.metal.newCommandBuffer()
        try visualization.encodeSlice(
            command: command,
            simulation: simulation,
            destination: destination,
            viewport: MTLViewport(originX: 0, originY: 0, width: 64, height: 64, znear: 0, zfar: 1)
        )
        command.commit()
        command.waitUntilCompleted()
        try require(command.status == .completed, "Step-\(step) slice render failed")
        var pixels = Array(repeating: UInt8.zero, count: size * size * 4)
        pixels.withUnsafeMutableBytes { bytes in
            destination.getBytes(
                bytes.baseAddress!,
                bytesPerRow: size * 4,
                from: MTLRegionMake2D(0, 0, size, size),
                mipmapLevel: 0
            )
        }
        let image = SliceImage(width: size, height: size, pixels: pixels)
        let filename = String(format: "recipe-step-%03d.ppm", step)
        try writePPM(image, to: directory.appendingPathComponent(filename))
        return image
    }

    private static func compareSliceImage(_ image: SliceImage, concentrations: [Float]) throws {
        try require(image.width == 64 && image.height == 64 && concentrations.count == 64 * 64,
                    "Production slice is not the fixed 64x64 central image")
        for row in 0..<image.height {
            for x in 0..<image.width {
                let expectedColor = FieldVisualization3D.encodedColor(
                    for: concentrations[row * image.width + x]
                )
                let pixel = (row * image.width + x) * 4
                let actual = [Int(image.pixels[pixel + 2]), Int(image.pixels[pixel + 1]), Int(image.pixels[pixel])]
                let expected = [expectedColor.x, expectedColor.y, expectedColor.z].map {
                    Int(($0 * 255).rounded())
                }
                try require(zip(actual, expected).allSatisfy { abs($0.0 - $0.1) <= 1 },
                            "Step slice differs from the CPU central-plane sample at (\(x),\(row))")
                try require(image.pixels[pixel + 3] == 255, "Step slice alpha is not opaque")
            }
        }
    }

    private static func centralSlice(
        _ dye: [Float], nx: Int, ny: Int, nz: Int
    ) -> [Float] {
        let lower = nz / 2 - 1
        let upper = nz / 2
        var values = Array(repeating: Float.zero, count: nx * ny)
        for row in 0..<ny {
            let y = ny - 1 - row
            for x in 0..<nx {
                let first = dye[(lower * ny + y) * nx + x]
                let second = dye[(upper * ny + y) * nx + x]
                values[row * nx + x] = (first + second) * 0.5
            }
        }
        return values
    }

    private static func volumeStatistics(
        _ dye: [Float], nx: Int, ny: Int, nz: Int
    ) -> [String: Any] {
        var mass = 0.0
        var xMoment = 0.0
        var yMoment = 0.0
        var zMoment = 0.0
        for k in 0..<nz {
            for j in 0..<ny {
                for i in 0..<nx {
                    let value = Double(dye[(k * ny + j) * nx + i])
                    mass += value
                    xMoment += value * (Double(i) + 0.5) / Double(nx)
                    yMoment += value * (Double(j) + 0.5) / Double(ny)
                    zMoment += value * (Double(k) + 0.5) / Double(nz)
                }
            }
        }
        guard mass.isFinite, mass > 0 else {
            return ["mass": mass, "centroid": [Double.nan, Double.nan, Double.nan],
                    "spreadRMS": Double.nan, "finite": false]
        }
        let centroid = [xMoment / mass, yMoment / mass, zMoment / mass]
        var variance = 0.0
        for k in 0..<nz {
            for j in 0..<ny {
                for i in 0..<nx {
                    let value = Double(dye[(k * ny + j) * nx + i])
                    let dx = (Double(i) + 0.5) / Double(nx) - centroid[0]
                    let dy = (Double(j) + 0.5) / Double(ny) - centroid[1]
                    let dz = (Double(k) + 0.5) / Double(nz) - centroid[2]
                    variance += value * (dx * dx + dy * dy + dz * dz)
                }
            }
        }
        let spread = sqrt(variance / mass)
        return ["mass": mass, "centroid": centroid, "spreadRMS": spread,
                "finite": centroid.allSatisfy(\.isFinite) && spread.isFinite]
    }

    private static func connectedComponents(
        _ dye: [Float], nx: Int, ny: Int, nz: Int, threshold: Float
    ) -> Int {
        var visited = Array(repeating: false, count: dye.count)
        var components = 0
        var queue: [Int] = []
        for start in dye.indices where dye[start] >= threshold && !visited[start] {
            components += 1
            visited[start] = true
            queue.removeAll(keepingCapacity: true)
            queue.append(start)
            var cursor = 0
            while cursor < queue.count {
                let index = queue[cursor]
                cursor += 1
                let x = index % nx
                let y = (index / nx) % ny
                let z = index / (nx * ny)
                let neighbours = [
                    x > 0 ? index - 1 : -1,
                    x + 1 < nx ? index + 1 : -1,
                    y > 0 ? index - nx : -1,
                    y + 1 < ny ? index + nx : -1,
                    z > 0 ? index - nx * ny : -1,
                    z + 1 < nz ? index + nx * ny : -1,
                ]
                for neighbour in neighbours where neighbour >= 0 {
                    if !visited[neighbour] && dye[neighbour] >= threshold {
                        visited[neighbour] = true
                        queue.append(neighbour)
                    }
                }
            }
        }
        return components
    }

    private static func cellCenteredVelocity(
        _ velocity: VelocitySnapshot, nx: Int, ny: Int, nz: Int
    ) -> [SIMD3<Float>] {
        var result = Array(repeating: SIMD3<Float>.zero, count: nx * ny * nz)
        for k in 0..<nz {
            for j in 0..<ny {
                for i in 0..<nx {
                    let cell = (k * ny + j) * nx + i
                    let u0 = (k * ny + j) * (nx + 1) + i
                    let v0 = (k * (ny + 1) + j) * nx + i
                    let w0 = (k * ny + j) * nx + i
                    result[cell] = SIMD3<Float>(
                        0.5 * (velocity.u[u0] + velocity.u[u0 + 1]),
                        0.5 * (velocity.v[v0] + velocity.v[v0 + nx]),
                        0.5 * (velocity.w[w0] + velocity.w[w0 + nx * ny])
                    )
                }
            }
        }
        return result
    }

    private static func cellCenteredSpeedMaximum(
        _ velocity: VelocitySnapshot, nx: Int, ny: Int, nz: Int
    ) -> Double {
        cellCenteredVelocity(velocity, nx: nx, ny: ny, nz: nz)
            .map { sqrt(Double($0.x * $0.x + $0.y * $0.y + $0.z * $0.z)) }
            .max() ?? 0
    }

    private static func maximumCellCenteredDepthVariation(
        _ velocity: VelocitySnapshot, nx: Int, ny: Int, nz: Int
    ) -> Double {
        let centers = cellCenteredVelocity(velocity, nx: nx, ny: ny, nz: nz)
        var maximum = 0.0
        for j in 0..<ny {
            for i in 0..<nx {
                let first = centers[(j * nx) + i]
                for k in 1..<nz {
                    let value = centers[(k * ny + j) * nx + i]
                    maximum = max(maximum,
                                  Double(abs(value.x - first.x)),
                                  Double(abs(value.y - first.y)),
                                  Double(abs(value.z - first.z)))
                }
            }
        }
        return maximum
    }

    private static func maximumAbsoluteDifference(_ lhs: [Float], _ rhs: [Float]) -> Double {
        guard lhs.count == rhs.count else { return .infinity }
        return zip(lhs, rhs).reduce(0.0) { max($0, abs(Double($1.0 - $1.1))) }
    }

    private static func rmsDifference(_ lhs: [Float], _ rhs: [Float]) -> Double {
        guard lhs.count == rhs.count, !lhs.isEmpty else { return .infinity }
        let sum = zip(lhs, rhs).reduce(0.0) { partial, pair in
            let difference = Double(pair.0 - pair.1)
            return partial + difference * difference
        }
        return sqrt(sum / Double(lhs.count))
    }

    private static func makeDyeSeededProbePaths(center: SIMD3<Double>) -> [[SIMD3<Double>]] {
        let offset = 0.04
        return [
            center,
            center + SIMD3<Double>(offset, 0, 0),
            center - SIMD3<Double>(offset, 0, 0),
            center + SIMD3<Double>(0, offset, 0),
            center - SIMD3<Double>(0, offset, 0),
            center + SIMD3<Double>(0, 0, offset),
            center - SIMD3<Double>(0, 0, offset),
        ].map { [$0] }
    }

    private static func advanceProbePaths(_ paths: inout [[SIMD3<Double>]], with velocity: VelocitySnapshot,
                                         grid: FluidSimulation3DConfiguration) {
        for index in paths.indices {
            let point = paths[index].last!
            let first = sampleVelocity(velocity, nx: grid.nx, ny: grid.ny, nz: grid.nz, position: point)
            let midpoint = point + first * (0.5 * Double(grid.dt))
            let second = sampleVelocity(velocity, nx: grid.nx, ny: grid.ny, nz: grid.nz, position: midpoint)
            let next = point + second * Double(grid.dt)
            paths[index].append(next)
        }
    }

    private static func sampleVelocity(
        _ velocity: VelocitySnapshot, nx: Int, ny: Int, nz: Int, position: SIMD3<Double>
    ) -> SIMD3<Double> {
        let u = trilinear(velocity.u, width: nx + 1, height: ny, depth: nz,
                          coordinate: SIMD3<Double>(position.x * Double(nx),
                                                    position.y * Double(ny) - 0.5,
                                                    position.z * Double(nz) - 0.5))
        let v = trilinear(velocity.v, width: nx, height: ny + 1, depth: nz,
                          coordinate: SIMD3<Double>(position.x * Double(nx) - 0.5,
                                                    position.y * Double(ny),
                                                    position.z * Double(nz) - 0.5))
        let w = trilinear(velocity.w, width: nx, height: ny, depth: nz + 1,
                          coordinate: SIMD3<Double>(position.x * Double(nx) - 0.5,
                                                    position.y * Double(ny) - 0.5,
                                                    position.z * Double(nz)))
        return SIMD3<Double>(u, v, w)
    }

    private static func sampleCellCentered(
        _ field: [Float], nx: Int, ny: Int, nz: Int, position: SIMD3<Double>
    ) -> Double {
        trilinear(field, width: nx, height: ny, depth: nz,
                  coordinate: SIMD3<Double>(position.x * Double(nx) - 0.5,
                                            position.y * Double(ny) - 0.5,
                                            position.z * Double(nz) - 0.5))
    }

    private static func trilinear(
        _ values: [Float], width: Int, height: Int, depth: Int, coordinate: SIMD3<Double>
    ) -> Double {
        let x = min(Double(width - 1), max(0, coordinate.x))
        let y = min(Double(height - 1), max(0, coordinate.y))
        let z = min(Double(depth - 1), max(0, coordinate.z))
        let x0 = Int(floor(x)); let x1 = min(x0 + 1, width - 1); let fx = x - Double(x0)
        let y0 = Int(floor(y)); let y1 = min(y0 + 1, height - 1); let fy = y - Double(y0)
        let z0 = Int(floor(z)); let z1 = min(z0 + 1, depth - 1); let fz = z - Double(z0)
        func at(_ i: Int, _ j: Int, _ k: Int) -> Double {
            Double(values[(k * height + j) * width + i])
        }
        let c00 = at(x0, y0, z0) * (1 - fx) + at(x1, y0, z0) * fx
        let c10 = at(x0, y1, z0) * (1 - fx) + at(x1, y1, z0) * fx
        let c01 = at(x0, y0, z1) * (1 - fx) + at(x1, y0, z1) * fx
        let c11 = at(x0, y1, z1) * (1 - fx) + at(x1, y1, z1) * fx
        let c0 = c00 * (1 - fy) + c10 * fy
        let c1 = c01 * (1 - fy) + c11 * fy
        return c0 * (1 - fz) + c1 * fz
    }

    private static func probeMetric(
        points: [SIMD3<Double>], grid: FluidSimulation3DConfiguration
    ) -> ProbeMetric {
        let first = points.first!
        let last = points.last!
        let zTravel = abs(last.z - first.z) / Double(grid.h)
        var arcLength = 0.0
        for index in 1..<points.count { arcLength += vectorLength(points[index] - points[index - 1]) }
        let center = points.reduce(SIMD3<Double>.zero, +) / Double(points.count)
        var covariance = Array(repeating: Array(repeating: 0.0, count: 3), count: 3)
        for point in points {
            let delta = point - center
            for row in 0..<3 {
                for column in 0..<3 { covariance[row][column] += delta[row] * delta[column] / Double(points.count) }
            }
        }
        let planeRMS = sqrt(smallestEigenvalue(covariance))
        return ProbeMetric(
            zTravelCells: zTravel,
            planeRMSArcRatio: arcLength > 0 ? planeRMS / arcLength : 0,
            points: points.map { [$0.x, $0.y, $0.z] }
        )
    }

    private static func vectorLength(_ value: SIMD3<Double>) -> Double {
        sqrt(value.x * value.x + value.y * value.y + value.z * value.z)
    }

    private static func smallestEigenvalue(_ matrix: [[Double]]) -> Double {
        var a = matrix
        for _ in 0..<48 {
            var p = 0
            var q = 1
            var largest = abs(a[0][1])
            if abs(a[0][2]) > largest { p = 0; q = 2; largest = abs(a[0][2]) }
            if abs(a[1][2]) > largest { p = 1; q = 2; largest = abs(a[1][2]) }
            if largest < 1e-15 { break }
            let angle = 0.5 * atan2(2 * a[p][q], a[q][q] - a[p][p])
            let cosine = cos(angle)
            let sine = sin(angle)
            let app = cosine * cosine * a[p][p] - 2 * sine * cosine * a[p][q] + sine * sine * a[q][q]
            let aqq = sine * sine * a[p][p] + 2 * sine * cosine * a[p][q] + cosine * cosine * a[q][q]
            for row in 0..<3 where row != p && row != q {
                let arp = cosine * a[row][p] - sine * a[row][q]
                let arq = sine * a[row][p] + cosine * a[row][q]
                a[row][p] = arp; a[p][row] = arp
                a[row][q] = arq; a[q][row] = arq
            }
            a[p][p] = app
            a[q][q] = aqq
            a[p][q] = 0
            a[q][p] = 0
        }
        return max(0, min(a[0][0], min(a[1][1], a[2][2])))
    }

    private static func saveEvolutionState(
        fields: [String: [Float]], status: [Float], step: Int, directory: URL
    ) throws -> [String: Any] {
        let orderedFields = [
            ("u", fields["u/ping"]!),
            ("v", fields["v/ping"]!),
            ("w", fields["w/ping"]!),
            ("dye", fields["dye/ping"]!),
            ("q-high", fields["q-high-low/ping"]!),
            ("q-low", fields["q-high-low/pong"]!),
        ]
        var data = Data()
        for (_, values) in orderedFields {
            for value in values {
                var bits = value.bitPattern.littleEndian
                withUnsafeBytes(of: &bits) { data.append(contentsOf: $0) }
            }
        }
        let filename = String(format: "recipe-state-step-%03d.f32le", step)
        try data.write(to: directory.appendingPathComponent(filename), options: .atomic)
        return [
            "file": filename,
            "byteCount": data.count,
            "dtype": "float32-le",
            "arrayOrder": "x-fastest; u, v, w, dye, q-high, q-low",
            "shapes": [
                "u": [65, 64, 64], "v": [64, 65, 64], "w": [64, 64, 65],
                "dye": [64, 64, 64], "q-high": [64, 64, 64], "q-low": [64, 64, 64],
            ],
            "statusLanes": status,
        ]
    }

    private static func runAsymmetricFullVolumeTransport(
        metal: MetalDevice, referenceDirectory: URL
    ) throws -> [String: Any] {
        let manifest = try JSONSerialization.jsonObject(
            with: Data(contentsOf: referenceDirectory.appendingPathComponent("manifest.json"))
        ) as! [String: Any]
        guard let payloads = manifest["binaryPayloads"] as? [[String: Any]],
              let payload = payloads.first(where: { ($0["fixture"] as? String) == "full_volume_unequal_axis" }),
              let referenceSummary = manifest["fullVolumeUnequalAxis"] as? [String: Any] else {
            throw Fluid3DHarnessError.assertion("CPU reference omitted the full-volume unequal-axis fixture")
        }
        let reference = try loadProjectionPayload(payload, directory: referenceDirectory)
        guard let u = reference["u_input"], let v = reference["v_input"], let w = reference["w_input"],
              let initialDye = reference["dye_step0"] else {
            throw Fluid3DHarnessError.assertion("Full-volume unequal-axis payload omitted an input array")
        }
        let simulation = try FluidSimulation3D(metal: metal)
        let upload = metal.newCommandBuffer()
        try simulation.u.encodeUpload(u.map(Float.init), to: simulation.u.ping, command: upload)
        try simulation.v.encodeUpload(v.map(Float.init), to: simulation.v.ping, command: upload)
        try simulation.w.encodeUpload(w.map(Float.init), to: simulation.w.ping, command: upload)
        try simulation.dye.encodeUpload(initialDye.map(Float.init), to: simulation.dye.ping, command: upload)
        upload.commit()
        upload.waitUntilCompleted()
        try require(upload.status == .completed, "Full-volume unequal-axis initial upload failed")

        var observations: [Int: [String: Any]] = [:]
        let startDye = try readActiveDye(simulation)
        let startVelocity = try readActiveVelocity(simulation)
        try require([startVelocity.u, startVelocity.v, startVelocity.w]
            .allSatisfy({ $0.allSatisfy(\.isFinite) }),
                    "Full-volume unequal-axis input velocity is nonfinite")
        _ = try exactWallZeros(u: startVelocity.u, v: startVelocity.v, w: startVelocity.w,
                               nx: 64, ny: 64, nz: 64, label: "full-volume start")
        observations[0] = volumeStatistics(startDye, nx: 64, ny: 64, nz: 64).merging([
            "velocityMaximumAbsolute": [
                "u": startVelocity.u.map { abs(Double($0)) }.max() ?? 0,
                "v": startVelocity.v.map { abs(Double($0)) }.max() ?? 0,
                "w": startVelocity.w.map { abs(Double($0)) }.max() ?? 0,
            ],
            "velocityFinite": true,
            "exactWallNormals": true,
        ]) { _, newer in newer }
        for step in 1...48 {
            try command(metal) { try simulation.encodeAdvection(command: $0) }
            if step == 24 || step == 48 {
                let dye = try readActiveDye(simulation)
                let velocity = try readActiveVelocity(simulation)
                try require([velocity.u, velocity.v, velocity.w]
                    .allSatisfy({ $0.allSatisfy(\.isFinite) }),
                            "Full-volume unequal-axis velocity became nonfinite at step \(step)")
                _ = try exactWallZeros(u: velocity.u, v: velocity.v, w: velocity.w,
                                       nx: 64, ny: 64, nz: 64,
                                       label: "full-volume step \(step)")
                let stats = volumeStatistics(dye, nx: 64, ny: 64, nz: 64)
                try require(stats["finite"] as? Bool == true,
                            "Full-volume unequal-axis transport became nonfinite at step \(step)")
                observations[step] = stats.merging([
                    "velocityMaximumAbsolute": [
                        "u": velocity.u.map { abs(Double($0)) }.max() ?? 0,
                        "v": velocity.v.map { abs(Double($0)) }.max() ?? 0,
                        "w": velocity.w.map { abs(Double($0)) }.max() ?? 0,
                    ],
                    "velocityFinite": true,
                    "exactWallNormals": true,
                ]) { _, newer in newer }
            }
        }
        let end = observations[48]!
        let startCentroid = observations[0]!["centroid"] as! [Double]
        let endCentroid = end["centroid"] as! [Double]
        let zDisplacementCells = abs(endCentroid[2] - startCentroid[2]) * 64
        try require(zDisplacementCells >= 0.5,
                    "Full-volume unequal-axis transport moved dye less than half a cell in Z: \(zDisplacementCells)")
        let referenceVelocity = referenceSummary["velocity"] as! [Double]
        try require(Set(referenceVelocity).count == 3 && referenceVelocity.allSatisfy { $0 != 0 },
                    "Reference transport must exercise three unequal nonzero axes")
        return [
            "grid": [64, 64, 64],
            "referenceVelocityXYZ": referenceVelocity,
            "observations": [0, 24, 48].map { step in ["step": step, "statistics": observations[step]!] as [String: Any] },
            "centroidZDisplacementCells": zDisplacementCells,
            "minimumCentroidZDisplacementCells": 0.5,
            "cpuReference": referenceSummary,
            "finite": true,
            "massConservationClaimed": false,
        ]
    }

    private static func readActiveDye(_ simulation: FluidSimulation3D) throws -> [Float] {
        let command = simulation.metal.newCommandBuffer()
        let readback = try simulation.dye.encodeReadback(from: simulation.dye.ping, command: command)
        command.commit()
        command.waitUntilCompleted()
        try require(command.status == .completed, "Full-volume dye readback failed")
        let values = try simulation.dye.decodeReadback(readback)
        try require(values.allSatisfy(\.isFinite) && values.allSatisfy { (0...1).contains($0) },
                    "Full-volume unequal-axis dye became nonfinite or out of range")
        return values
    }

    private static func resetAndFinite(metal: MetalDevice, referenceDirectory: URL) throws -> [String: Any] {
        let simulation = try FluidSimulation3D(metal: metal)
        let cellCount = 64 * 64 * 64
        let uniform = Fluid3DInitialState(
            u: Array(repeating: 0, count: 65 * 64 * 64),
            v: Array(repeating: 0, count: 64 * 65 * 64),
            w: Array(repeating: 0, count: 64 * 64 * 65),
            dye: Array(repeating: 0.375, count: cellCount)
        )
        var resetStatus: PressureProjection3D.StatusSlot!
        try command(metal) { resetStatus = try simulation.encodeReset(command: $0, initialState: uniform) }
        try require(resetStatus.diagnostics().converged, "Uniform reset projection failed")
        try require(resetStatus.diagnosticStateValues().allSatisfy(\.isFinite), "Nonfinite reset status lane")
        try command(metal) { _ = try simulation.encodeStep(command: $0) }
        let uniformFields = try scanSimulation(simulation)
        try require(uniformFields["dye/ping"]!.allSatisfy { abs($0 - 0.375) <= 2e-6 },
                    "Uniform dye was not preserved without explicit decay")
        for field in ["u", "v", "w"] {
            try require(uniformFields["\(field)/ping"]!.allSatisfy { $0 == 0 }, "Zero velocity changed")
        }

        let referenceManifest = try JSONSerialization.jsonObject(
            with: Data(contentsOf: referenceDirectory.appendingPathComponent("step-manifest.json"))
        ) as! [String: Any]
        let reference = try loadProjectionPayload(referenceManifest, directory: referenceDirectory)
        let initial = Fluid3DInitialState(
            u: reference["u_input"]!.map(Float.init), v: reference["v_input"]!.map(Float.init),
            w: reference["w_input"]!.map(Float.init), dye: reference["dye_input"]!.map(Float.init)
        )
        try command(metal) { resetStatus = try simulation.encodeReset(command: $0, initialState: initial) }
        try require(resetStatus.diagnostics().converged, "Asymmetric reset projection failed")
        try require(resetStatus.diagnosticStateValues().allSatisfy(\.isFinite), "Nonfinite seeded reset status lane")
        let resetFields = try scanSimulation(simulation)
        for field in ["u", "v", "w", "dye"] {
            try require(resetFields["\(field)/ping"]! == resetFields["\(field)/pong"]!,
                        "Reset did not initialize both \(field) generations identically")
            try compareFloatField(resetFields["\(field)/ping"]!, reference["\(field)_reset"]!, label: "reset/\(field)")
        }
        let started = Date()
        var maximumIterations = 0
        var checks: [[String: Any]] = [["step": 0, "finite": true]]
        for step in 1...600 {
            var status: PressureProjection3D.StatusSlot!
            try command(metal) { status = try simulation.encodeStep(command: $0) }
            let result = status.diagnostics()
            try require(result.failure == .none && result.converged && !result.capHit,
                        "Step \(step) failed: \(result.failure)")
            maximumIterations = max(maximumIterations, result.iterations)
            if [1, 72, 600].contains(step) {
                try require(status.diagnosticStateValues().allSatisfy(\.isFinite), "Nonfinite status lane at step \(step)")
                let fields = try scanSimulation(simulation)
                if step == 1 {
                    for field in ["u", "v", "w", "dye"] {
                        try compareFloatField(fields["\(field)/ping"]!, reference["\(field)_step1"]!,
                                              label: "independent-one-step/\(field)")
                    }
                }
                checks.append(["step": step, "finite": true,
                               "divergenceDT": result.projectedDivergenceDTInf,
                               "residualDT": result.trueResidualDTInf])
            }
        }
        let soakSeconds = Date().timeIntervalSince(started)

        // A fresh reset must recover from failure, and a failed queued step must
        // freeze velocity/dye for all later already-encoded submissions.
        let fixtureGrid = try FluidSimulation3DConfiguration.fixture(nx: 8, ny: 7, nz: 6, h: 1)
        let failedSimulation = try FluidSimulation3D(metal: metal, configuration: fixtureGrid)
        let seedVelocity = makeInteriorProbeVelocity(nx: 8, ny: 7, nz: 6, amplitude: 0.1)
        let seed = Fluid3DInitialState(u: seedVelocity.u, v: seedVelocity.v, w: seedVelocity.w,
                                      dye: Array(repeating: 0.375, count: 8 * 7 * 6))
        try command(metal) { _ = try failedSimulation.encodeReset(command: $0, initialState: seed) }
        let beforeFailure = try scanSimulation(failedSimulation)
        let first = metal.newCommandBuffer()
        let firstStatus = try failedSimulation.encodeStep(command: first, failureInjection: .zeroSearchDenominator)
        let second = metal.newCommandBuffer()
        let secondStatus = try failedSimulation.encodeStep(command: second)
        let third = metal.newCommandBuffer()
        let thirdStatus = try failedSimulation.encodeStep(command: third)
        for buffer in [first, second, third] { buffer.commit() }
        for buffer in [first, second, third] {
            buffer.waitUntilCompleted()
            try require(buffer.status == .completed, "Queued failure fixture command failed")
        }
        try require(firstStatus.diagnostics().failure == .invalidSearchDenominator,
                    "Injected session failure was not recorded")
        try require(secondStatus.diagnostics().failure == .priorSessionFailure
                    && thirdStatus.diagnostics().failure == .priorSessionFailure,
                    "Queued submissions advanced after session failure")
        let afterFailure = try scanSimulation(failedSimulation)
        for field in ["u", "v", "w", "dye"] {
            try require(afterFailure["\(field)/ping"]! == beforeFailure["\(field)/ping"]!,
                        "Failed queued work changed committed \(field)")
        }
        try command(metal) { resetStatus = try failedSimulation.encodeReset(command: $0, initialState: seed) }
        try require(resetStatus.diagnostics().converged, "Reset failed to clear numerical failure latch")
        return ["passed": true, "fixture": "reset-finite", "device": metal.device.name,
                "snapshots": checks, "soakSteps": 600, "soakSeconds": soakSeconds,
                "maximumIterations": maximumIterations, "queuedFailureFrozen": true,
                "uniformDyePreserved": true, "oneStepReferenceMatched": true]
    }

    private static func scanSimulation(_ simulation: FluidSimulation3D) throws -> [String: [Float]] {
        let command = simulation.metal.newCommandBuffer()
        var reads: [(String, VolumeField3D, MTLBuffer)] = []
        for (name, field) in simulation.diagnosticFields {
            for (generation, texture) in [("ping", field.ping), ("pong", field.pong)] {
                reads.append(("\(name)/\(generation)", field,
                              try field.encodeReadback(from: texture, command: command)))
            }
        }
        let workspace = simulation.projection.diagnosticReductionWorkspace
        guard let workspaceReadback = simulation.metal.device.makeBuffer(length: workspace.length, options: .storageModeShared),
              let workspaceBlit = command.makeBlitCommandEncoder() else {
            throw Fluid3DHarnessError.assertion("Could not stage reduction workspace readback")
        }
        workspaceBlit.copy(from: workspace, sourceOffset: 0, to: workspaceReadback,
                           destinationOffset: 0, size: workspace.length)
        workspaceBlit.endEncoding()
        command.commit()
        command.waitUntilCompleted()
        try require(command.status == .completed, "Full-state readback failed")
        let reductionValues = workspaceReadback.contents().assumingMemoryBound(to: Float.self)
        try require((0..<(workspaceReadback.length / 4)).allSatisfy { reductionValues[$0].isFinite },
                    "Nonfinite reduction workspace value")
        var fields: [String: [Float]] = [:]
        for (name, field, buffer) in reads {
            let values = try field.decodeReadback(buffer)
            try require(values.allSatisfy(\.isFinite), "Nonfinite full-volume state: \(name)")
            fields[name] = values
        }
        let grid = simulation.configuration
        for generation in ["ping", "pong"] {
            _ = try exactWallZeros(u: fields["u/\(generation)"]!, v: fields["v/\(generation)"]!,
                                   w: fields["w/\(generation)"]!, nx: grid.nx, ny: grid.ny, nz: grid.nz,
                                   label: "all generations/\(generation)")
            try require(fields["dye/\(generation)"]!.allSatisfy { (0...1).contains($0) },
                        "Dye left bounded concentration range")
        }
        return fields
    }

    private static func operatorFixture(
        device: MTLDevice,
        metal: MetalDevice,
        referenceDirectory: URL
    ) throws -> [String: Any] {
        let requiredFunctions = [
            "fluid3DDivergence",
            "fluid3DApplyA",
            "fluid3DSubtractGradient",
            "fluid3DComputeRHS",
            "fluid3DComputeResidual",
            "fluid3DIdentityError",
            "fluid3DReduceField",
            "fluid3DFinalizeReduction",
            "fluid3DReduceWallFlux",
        ]
        let manifestURL = referenceDirectory.appendingPathComponent("manifest.json")
        guard let manifest = try JSONSerialization.jsonObject(
            with: Data(contentsOf: manifestURL)
        ) as? [String: Any],
              manifest["contractHash"] as? String == "a7768571a996d5b9520aff5095100bb52fb67f96560f99633d081c04a3a9e01b",
              let payloads = manifest["binaryPayloads"] as? [[String: Any]],
              let payload = payloads.first(where: { $0["fixture"] as? String == "asymmetric_operator_identity" }),
              let filename = payload["file"] as? String,
              let arrays = payload["arrayOrder"] as? [[String: Any]] else {
            throw Fluid3DHarnessError.assertion("CPU oracle is missing the locked asymmetric operator payload")
        }
        let payloadData = try Data(contentsOf: referenceDirectory.appendingPathComponent(filename))
        var offset = 0
        var reference: [String: [Double]] = [:]
        for descriptor in arrays {
            guard let name = descriptor["name"] as? String,
                  let shape = descriptor["shape"] as? [Int],
                  shape.count == 3 else {
                throw Fluid3DHarnessError.assertion("Malformed asymmetric operator array descriptor")
            }
            let count = shape.reduce(1, *)
            reference[name] = try decodeLittleEndianDoubles(payloadData, offsetElements: offset, count: count)
            offset += count
        }
        try require(offset * MemoryLayout<UInt64>.stride == payloadData.count,
                    "Asymmetric operator payload contains unaccounted data")
        guard let pressureReference = reference["pressure_q"],
              let dgReference = reference["A_from_DG"],
              let stencilReference = reference["A_neighbour_stencil"] else {
            throw Fluid3DHarnessError.assertion("CPU oracle omitted an asymmetric operator output")
        }
        try require(maxDifference(dgReference, stencilReference) <= 1e-10,
                    "Independent CPU -h²DG and neighbour-stencil references disagree")

        let nx = 8
        let ny = 7
        let nz = 6
        let h: Float = 1
        let configuration = try FluidSimulation3DConfiguration.fixture(nx: nx, ny: ny, nz: nz, h: h)
        let projection = try PressureProjection3D(metal: metal, configuration: configuration)
        let qField = try VolumeField3D(grid: configuration, component: .cell, metal: metal)
        let uField = try VolumeField3D(grid: configuration, component: .u, metal: metal)
        let vField = try VolumeField3D(grid: configuration, component: .v, metal: metal)
        let wField = try VolumeField3D(grid: configuration, component: .w, metal: metal)
        let fluxUField = try VolumeField3D(grid: configuration, component: .u, metal: metal)
        let fluxVField = try VolumeField3D(grid: configuration, component: .v, metal: metal)
        let fluxWField = try VolumeField3D(grid: configuration, component: .w, metal: metal)

        let constantPressure = Array(repeating: 0.125, count: nx * ny * nz)
        var alternatingPressure = Array(repeating: 0.0, count: nx * ny * nz)
        var manufacturedPressure = Array(repeating: 0.0, count: nx * ny * nz)
        for k in 0..<nz {
            for j in 0..<ny {
                for i in 0..<nx {
                    let cell = (k * ny + j) * nx + i
                    alternatingPressure[cell] = (i + j + k).isMultiple(of: 2) ? 0.125 : -0.125
                    let x = (Double(i) + 0.5) / Double(nx)
                    let y = (Double(j) + 0.5) / Double(ny)
                    let z = (Double(k) + 0.5) / Double(nz)
                    manufacturedPressure[cell] = cos(Double.pi * x)
                        * cos(2 * Double.pi * y) * cos(3 * Double.pi * z)
                }
            }
        }
        let analyticCases: [(String, [Double], VolumeField3D, VolumeField3D)] = try [
            ("constant", constantPressure,
             VolumeField3D(grid: configuration, component: .cell, metal: metal),
             VolumeField3D(grid: configuration, component: .cell, metal: metal)),
            ("alternating", alternatingPressure,
             VolumeField3D(grid: configuration, component: .cell, metal: metal),
             VolumeField3D(grid: configuration, component: .cell, metal: metal)),
            ("manufactured", manufacturedPressure,
             VolumeField3D(grid: configuration, component: .cell, metal: metal),
             VolumeField3D(grid: configuration, component: .cell, metal: metal)),
        ]

        let q = pressureReference.map(Float.init)
        let inputVelocity = makeOperatorVelocity(nx: nx, ny: ny, nz: nz)
        let expectedDivergence = cpuDivergence(
            nx: nx, ny: ny, nz: nz, h: Double(h),
            u: inputVelocity.u.map(Double.init),
            v: inputVelocity.v.map(Double.init),
            w: inputVelocity.w.map(Double.init)
        )
        let expectedRHS = expectedDivergence.map { -Double(h * h) * $0 }
        let expectedA = stencilReference
        let expectedResidual = zip(expectedRHS, expectedA).map { $0.0 - $0.1 }
        let expectedU = cpuSubtractGradient(
            nx: nx, ny: ny, nz: nz, h: Double(h), q: q.map(Double.init),
            velocity: inputVelocity.u.map(Double.init), component: .u
        )
        let expectedV = cpuSubtractGradient(
            nx: nx, ny: ny, nz: nz, h: Double(h), q: q.map(Double.init),
            velocity: inputVelocity.v.map(Double.init), component: .v
        )
        let expectedW = cpuSubtractGradient(
            nx: nx, ny: ny, nz: nz, h: Double(h), q: q.map(Double.init),
            velocity: inputVelocity.w.map(Double.init), component: .w
        )
        let expectedProjectedDivergence = cpuDivergence(
            nx: nx, ny: ny, nz: nz, h: Double(h), u: expectedU, v: expectedV, w: expectedW
        )
        let expectedIdentity = zip(expectedProjectedDivergence, expectedResidual).map { $0 + $1 / Double(h * h) }

        let cellCount = nx * ny * nz
        let rhsStats = try projection.makeReductionResult(label: "RHS statistics")
        let divergenceStats = try projection.makeReductionResult(label: "projected divergence statistics")
        let residualStats = try projection.makeReductionResult(label: "true residual statistics")
        let identityStats = try projection.makeReductionResult(label: "projection identity statistics")
        let wallStats = try projection.makeReductionResult(label: "wall flux statistics")
        let wallFluxProbeStats = try projection.makeReductionResult(label: "signed wall-flux probe statistics")
        let wallFluxProbe = makeWallFluxProbe(nx: nx, ny: ny, nz: nz)
        let expectedWallFluxProbe = Array(repeating: -1.0, count: ny * nz)
            + Array(repeating: 4.0, count: ny * nz)
            + Array(repeating: -2.0, count: nx * nz)
            + Array(repeating: 5.0, count: nx * nz)
            + Array(repeating: -3.0, count: nx * ny)
            + Array(repeating: 6.0, count: nx * ny)

        let commandBuffer = metal.newCommandBuffer()
        try qField.encodeUpload(q, to: qField.ping, command: commandBuffer)
        for (_, pressureValues, pressureField, _) in analyticCases {
            try pressureField.encodeUpload(pressureValues.map(Float.init), to: pressureField.ping, command: commandBuffer)
        }
        try uField.encodeUpload(inputVelocity.u, to: uField.ping, command: commandBuffer)
        try vField.encodeUpload(inputVelocity.v, to: vField.ping, command: commandBuffer)
        try wField.encodeUpload(inputVelocity.w, to: wField.ping, command: commandBuffer)
        try fluxUField.encodeUpload(wallFluxProbe.u, to: fluxUField.ping, command: commandBuffer)
        try fluxVField.encodeUpload(wallFluxProbe.v, to: fluxVField.ping, command: commandBuffer)
        try fluxWField.encodeUpload(wallFluxProbe.w, to: fluxWField.ping, command: commandBuffer)

        try projection.encodeDivergence(
            command: commandBuffer,
            u: uField.ping, v: vField.ping, w: wField.ping,
            output: projection.divergence.ping
        )
        try projection.encodeApplyA(
            command: commandBuffer, pressure: qField.ping, output: projection.appliedOperator.ping
        )
        for (_, _, pressureField, operatorField) in analyticCases {
            try projection.encodeApplyA(
                command: commandBuffer, pressure: pressureField.ping, output: operatorField.ping
            )
        }
        for (component, input, output) in [
            (VolumeField3D.Component.u, uField.ping, uField.pong),
            (VolumeField3D.Component.v, vField.ping, vField.pong),
            (VolumeField3D.Component.w, wField.ping, wField.pong),
        ] {
            try projection.encodeSubtractGradient(
                command: commandBuffer,
                pressure: qField.ping, input: input, output: output, component: component
            )
        }
        try projection.encodeDivergence(
            command: commandBuffer,
            u: uField.pong, v: vField.pong, w: wField.pong,
            output: projection.divergence.pong
        )
        try projection.encodeRHS(
            command: commandBuffer, divergence: projection.divergence.ping, output: projection.rhs.ping
        )
        try projection.encodeTrueResidual(
            command: commandBuffer,
            divergence: projection.divergence.ping,
            appliedOperator: projection.appliedOperator.ping,
            output: projection.trueResidual.ping
        )
        try projection.encodeIdentityError(
            command: commandBuffer,
            projectedDivergence: projection.divergence.pong,
            trueResidual: projection.trueResidual.ping,
            output: projection.identityError.ping
        )
        try projection.encodeReduction(
            command: commandBuffer, input: projection.rhs.ping, result: rhsStats
        )
        try projection.encodeReduction(
            command: commandBuffer, input: projection.divergence.pong, result: divergenceStats
        )
        try projection.encodeReduction(
            command: commandBuffer, input: projection.trueResidual.ping, result: residualStats
        )
        try projection.encodeReduction(
            command: commandBuffer, input: projection.identityError.ping, result: identityStats
        )
        try projection.encodeWallFluxReduction(
            command: commandBuffer,
            u: uField.ping, v: vField.ping, w: wField.ping,
            result: wallStats
        )
        try projection.encodeWallFluxReduction(
            command: commandBuffer,
            u: fluxUField.ping, v: fluxVField.ping, w: fluxWField.ping,
            result: wallFluxProbeStats
        )

        let divergenceInputReadback = try projection.divergence.encodeReadback(from: projection.divergence.ping, command: commandBuffer)
        let divergenceProjectedReadback = try projection.divergence.encodeReadback(from: projection.divergence.pong, command: commandBuffer)
        let rhsReadback = try projection.rhs.encodeReadback(from: projection.rhs.ping, command: commandBuffer)
        let appliedReadback = try projection.appliedOperator.encodeReadback(from: projection.appliedOperator.ping, command: commandBuffer)
        let residualReadback = try projection.trueResidual.encodeReadback(from: projection.trueResidual.ping, command: commandBuffer)
        let identityReadback = try projection.identityError.encodeReadback(from: projection.identityError.ping, command: commandBuffer)
        let uCorrectedReadback = try uField.encodeReadback(from: uField.pong, command: commandBuffer)
        let vCorrectedReadback = try vField.encodeReadback(from: vField.pong, command: commandBuffer)
        let wCorrectedReadback = try wField.encodeReadback(from: wField.pong, command: commandBuffer)
        var analyticReadbacks: [(String, MTLBuffer, VolumeField3D, [Double])] = []
        for (name, pressureValues, _, operatorField) in analyticCases {
            analyticReadbacks.append((
                name,
                try operatorField.encodeReadback(from: operatorField.ping, command: commandBuffer),
                operatorField,
                cpuApplyA(nx: nx, ny: ny, nz: nz, pressure: pressureValues.map(Float.init).map(Double.init))
            ))
        }

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        guard commandBuffer.status == .completed else {
            throw Fluid3DHarnessError.commandBuffer(
                "Operator fixture command failed: \(String(describing: commandBuffer.error))"
            )
        }

        let actualDivergence = try projection.divergence.decodeReadback(divergenceInputReadback)
        let actualProjectedDivergence = try projection.divergence.decodeReadback(divergenceProjectedReadback)
        let actualRHS = try projection.rhs.decodeReadback(rhsReadback)
        let actualA = try projection.appliedOperator.decodeReadback(appliedReadback)
        let actualResidual = try projection.trueResidual.decodeReadback(residualReadback)
        let actualIdentity = try projection.identityError.decodeReadback(identityReadback)
        let actualU = try uField.decodeReadback(uCorrectedReadback)
        let actualV = try vField.decodeReadback(vCorrectedReadback)
        let actualW = try wField.decodeReadback(wCorrectedReadback)

        try compareFloatField(actualDivergence, expectedDivergence, label: "D(u)")
        try compareFloatField(actualA, expectedA, label: "A(q)")
        try compareFloatField(actualRHS, expectedRHS, label: "-h²D(u)")
        try compareFloatField(actualResidual, expectedResidual, label: "true residual")
        try compareFloatField(actualU, expectedU, label: "u-Gx(q)")
        try compareFloatField(actualV, expectedV, label: "v-Gy(q)")
        try compareFloatField(actualW, expectedW, label: "w-Gz(q)")
        try compareFloatField(actualProjectedDivergence, expectedProjectedDivergence, label: "D(u-Gq)")
        try compareFloatField(actualIdentity, expectedIdentity, label: "D(u-Gq)+r/h²")
        for (name, buffer, field, expected) in analyticReadbacks {
            try compareFloatField(try field.decodeReadback(buffer), expected, label: "A(\(name) pressure)")
        }
        let constantOutput = try analyticReadbacks[0].2.decodeReadback(analyticReadbacks[0].1)
        let alternatingOutput = try analyticReadbacks[1].2.decodeReadback(analyticReadbacks[1].1)
        try require(constantOutput.allSatisfy { $0 == 0 }, "A constant pressure must map to exact zero")
        try require((alternatingOutput.map(abs).max() ?? 0) > 1,
                    "Alternating pressure was incorrectly treated as a null mode")

        let rhsSummary = reductionResult(rhsStats)
        let divergenceSummary = reductionResult(divergenceStats)
        let residualSummary = reductionResult(residualStats)
        let identitySummary = reductionResult(identityStats)
        let wallSummary = reductionResult(wallStats)
        let wallProbeSummary = reductionResult(wallFluxProbeStats)
        try require(rhsSummary.w == 1 && divergenceSummary.w == 1 && residualSummary.w == 1
                    && identitySummary.w == 1 && wallSummary.w == 1,
                    "Finite GPU reductions rejected a finite operator field")
        try compareReduction(rhsSummary, reference: expectedRHS, label: "RHS")
        try compareReduction(divergenceSummary, reference: expectedProjectedDivergence, label: "projected divergence")
        try compareReduction(residualSummary, reference: expectedResidual, label: "true residual")
        try compareReduction(identitySummary, reference: expectedIdentity, label: "identity error")
        try require(wallSummary.x == 0 && wallSummary.y == 0 && wallSummary.z == 0,
                    "GPU wall-flux reduction did not return zero for impermeable faces")
        try compareReduction(wallProbeSummary, reference: expectedWallFluxProbe, label: "signed wall-flux probe")
        try require(wallProbeSummary.x == 438 && wallProbeSummary.z == 6
                    && wallProbeSummary.w == 1,
                    "GPU wall-flux reduction lost face signs or boundary extents")
        try require(identitySummary.z <= 2e-5, "GPU residual/divergence identity error is too large: \(identitySummary.z)")
        try require(wallSummary.x == 0 && wallSummary.z == 0, "Closed-box net wall flux or wall maximum is nonzero")

        let nanStats = try runNonfiniteReductionFixture(
            device: device, metal: metal, h: h
        )
        try require(nanStats.w == 0, "GPU finite reduction hid a NaN behind max/min reduction")
        try require(nanStats.x.isFinite && nanStats.y.isFinite && nanStats.z.isFinite,
                    "Nonfinite reduction did not safely suppress invalid numerical outputs")

        return [
            "passed": true,
            "fixture": "operators",
            "device": device.name,
            "grid": [nx, ny, nz],
            "comparedCells": cellCount,
            "comparedFaces": actualU.count + actualV.count + actualW.count,
            "operatorMaxAbsoluteError": maxDifference(actualA.map(Double.init), expectedA),
            "analyticFixtures": ["constant", "alternating", "manufactured", "asymmetric"],
            "divergenceMaxAbsoluteError": maxDifference(actualDivergence.map(Double.init), expectedDivergence),
            "projectedDivergenceMaxAbsolute": divergenceSummary.z,
            "projectedDivergenceL2": sqrt(divergenceSummary.y),
            "trueResidualMaxAbsolute": residualSummary.z,
            "trueResidualL2": sqrt(residualSummary.y),
            "rhsMean": rhsSummary.x / Float(cellCount),
            "netWallFlux": wallSummary.x * h * h,
            "maximumWallNormalValue": wallSummary.z,
            "signedWallFluxProbe": wallProbeSummary.x,
            "identityMaxAbsolute": identitySummary.z,
            "nonfiniteAccepted": nanStats.w == 1,
            "productionPipelines": requiredFunctions,
        ]
    }

    private static func projectionFixture(
        device: MTLDevice,
        metal: MetalDevice,
        referenceDirectory: URL
    ) throws -> [String: Any] {
        try require(Fluid3DPCGState.abiIsValid, "Swift/Metal PCG state ABI layout changed")
        let manifestURL = referenceDirectory.appendingPathComponent("manifest.json")
        guard let manifest = try JSONSerialization.jsonObject(
            with: Data(contentsOf: manifestURL)
        ) as? [String: Any],
              manifest["contractHash"] as? String == "a7768571a996d5b9520aff5095100bb52fb67f96560f99633d081c04a3a9e01b",
              let fixtureSummaries = manifest["fixtures"] as? [[String: Any]],
              let binaryPayloads = manifest["binaryPayloads"] as? [[String: Any]] else {
            throw Fluid3DHarnessError.assertion("CPU oracle is missing the locked projection fixtures")
        }
        let fixtureNames = [
            "zero_rhs", "constant_pressure", "alternating_pressure", "manufactured_cosine",
            "mixed_frequency_asymmetric", "wall_edge_corner", "divergence_free",
        ]
        let summaries = Dictionary(
            uniqueKeysWithValues: fixtureSummaries.compactMap { item -> (String, [String: Any])? in
                guard let name = item["name"] as? String else { return nil }
                return (name, item)
            }
        )
        try require(Set(summaries.keys) == Set(fixtureNames), "CPU oracle's registered projection families changed")
        let payloads = Dictionary(
            uniqueKeysWithValues: binaryPayloads.compactMap { item -> (String, [String: Any])? in
                guard let name = item["fixture"] as? String else { return nil }
                return (name, item)
            }
        )
        try require(Set(payloads.keys).isSuperset(of: Set(fixtureNames)),
                    "CPU oracle omitted a binary payload for a registered projection family")

        let quickConfiguration = try FluidSimulation3DConfiguration.fixture(
            nx: 8, ny: 7, nz: 6, h: 1
        )
        let quickProjection = try PressureProjection3D(metal: metal, configuration: quickConfiguration)
        let quickFields = try makeProjectionFields(configuration: quickConfiguration, metal: metal)
        let quickStatus = try quickProjection.makeStatusSlot(label: "small PCG fixture status")
        let zeroVelocity = (
            u: Array(repeating: Float.zero, count: 9 * 7 * 6),
            v: Array(repeating: Float.zero, count: 8 * 8 * 6),
            w: Array(repeating: Float.zero, count: 8 * 7 * 7)
        )
        let zeroResult = try runProjectionCase(
            projection: quickProjection,
            fields: quickFields,
            input: zeroVelocity,
            status: quickStatus,
            iterationLimit: 2
        )
        try require(zeroResult.diagnostics.failure == .none && zeroResult.diagnostics.converged
                    && !zeroResult.diagnostics.capHit && zeroResult.diagnostics.iterations == 0,
                    "Zero RHS did not terminate successfully without a PCG division")
        try require(zeroResult.pressure.allSatisfy { $0 == 0 }, "Zero RHS did not return q=0")

        let asymPayload = payloads["asymmetric_operator_identity"]!
        let asymArrays = try loadProjectionPayload(asymPayload, directory: referenceDirectory)
        guard let asymPressure = asymArrays["pressure_q"] else {
            throw Fluid3DHarnessError.assertion("CPU oracle omitted asymmetric pressure q")
        }
        let quickInput = makePressureVelocity(
            asymPressure.map(Float.init), nx: 8, ny: 7, nz: 6, h: 1
        )
        let asymResult = try runProjectionCase(
            projection: quickProjection,
            fields: quickFields,
            input: quickInput,
            status: quickStatus
        )
        let diagnosticLine = "QUICK_PCG_DIAGNOSTICS iterations=\(asymResult.diagnostics.iterations) "
                + "failure=\(asymResult.diagnostics.failure) converged=\(asymResult.diagnostics.converged) "
                + "residualDT=\(asymResult.diagnostics.trueResidualDTInf) "
                + "divergenceDT=\(asymResult.diagnostics.projectedDivergenceDTInf)\n"
        FileHandle.standardError.write(Data(diagnosticLine.utf8))
        let asymMean = asymPressure.reduce(0, +) / Double(asymPressure.count)
        try compareFloatField(
            asymResult.pressure.map(Float.init),
            asymPressure.map { $0 - asymMean },
            label: "8x7x6 asymmetric PCG pressure"
        )
        try require(asymResult.diagnostics.failure == .none && asymResult.diagnostics.converged
                    && !asymResult.diagnostics.capHit,
                    "8x7x6 asymmetric PCG failed its direct-reference projection")
        _ = try exactWallZeros(
            u: asymResult.u, v: asymResult.v, w: asymResult.w,
            nx: 8, ny: 7, nz: 6, label: "8x7x6 asymmetric PCG"
        )

        let incompatible = makeOperatorVelocity(nx: 8, ny: 7, nz: 6)
        var incompatibleU = incompatible.u
        incompatibleU[0] = 0.1
        let incompatibleResult = try runProjectionCase(
            projection: quickProjection,
            fields: quickFields,
            input: (incompatibleU, incompatible.v, incompatible.w),
            status: quickStatus
        )
        try require(incompatibleResult.diagnostics.failure == .incompatibleRHS
                    && !incompatibleResult.diagnostics.converged,
                    "Nonzero closed-box compatibility mean was not reported as a failure")

        let denominatorFailure = try runProjectionCase(
            projection: quickProjection,
            fields: quickFields,
            input: quickInput,
            status: quickStatus,
            failureInjection: .zeroSearchDenominator
        )
        try require(denominatorFailure.diagnostics.failure == .invalidSearchDenominator
                    && !denominatorFailure.diagnostics.converged,
                    "Injected nonpositive PCG denominator was not reported")
        for injection in [Fluid3DProjectionFailureInjection.negativeSearchDenominator, .nonfiniteSearchDenominator] {
            let rejected = try runProjectionCase(projection: quickProjection, fields: quickFields,
                                                 input: quickInput, status: quickStatus, failureInjection: injection)
            try require(rejected.diagnostics.failure == .invalidSearchDenominator
                        && !rejected.diagnostics.converged,
                        "Injected negative/nonfinite PCG denominator was not rejected")
        }

        let capFailure = try runProjectionCase(
            projection: quickProjection,
            fields: quickFields,
            input: quickInput,
            status: quickStatus,
            iterationLimit: 1
        )
        try require(capFailure.diagnostics.failure == .iterationCapExceeded
                    && capFailure.diagnostics.capHit && !capFailure.diagnostics.converged
                    && capFailure.diagnostics.iterations == 1,
                    "One-iteration exhaustion was not reported as a failed solve")

        let nanInput = try makeSharedVelocityTextures(
            device: device,
            nx: 8,
            ny: 7,
            nz: 6,
            values: (Array(repeating: 0, count: 9 * 7 * 6),
                     Array(repeating: 0, count: 8 * 8 * 6),
                     Array(repeating: 0, count: 8 * 7 * 7)),
            nanUIndex: (3 * 7 + 2) * 9 + 4
        )
        let nanResult = try runProjectionTextures(
            projection: quickProjection,
            fields: quickFields,
            input: nanInput,
            status: quickStatus
        )
        try require(nanResult.diagnostics.failure == .nonfiniteInput
                    && !nanResult.diagnostics.converged,
                    "NaN velocity input was not reported as a failed projection")

        let productionConfiguration = FluidSimulation3DConfiguration.production
        let productionProjection = try PressureProjection3D(
            metal: metal, configuration: productionConfiguration
        )
        let productionFields = try makeProjectionFields(
            configuration: productionConfiguration, metal: metal
        )
        let productionSlots = try (0..<3).map {
            try productionProjection.makeStatusSlot(label: "64-cubed projection status \($0)")
        }
        let manufacturedTraceSlot = try productionProjection.makeStatusSlot(
            label: "manufactured cosine diagnostic trace",
            capturePCGTrace: true
        )
        let cellSpacing = 1.0 / 64.0
        var caseReports: [[String: Any]] = []
        var comparedValues = 0
        var maximumAbsoluteError = 0.0
        for (caseIndex, name) in fixtureNames.enumerated() {
            let payload = payloads[name]!
            let reference = try loadProjectionPayload(payload, directory: referenceDirectory)
            let requiredArrays = [
                "u_input", "v_input", "w_input", "rhs", "pressure_q",
                "u_projected", "v_projected", "w_projected",
                "divergence_projected", "true_residual",
            ]
            try require(Set(reference.keys) == Set(requiredArrays),
                        "\(name) CPU payload array set changed: \(reference.keys)")
            for values in reference.values {
                try require(values.allSatisfy(\.isFinite), "\(name) CPU reference contains NaN or infinity")
            }
            let input = (
                reference["u_input"]!.map(Float.init),
                reference["v_input"]!.map(Float.init),
                reference["w_input"]!.map(Float.init)
            )
            let started = Date()
            let status = name == "manufactured_cosine"
                ? manufacturedTraceSlot
                : productionSlots[caseIndex % productionSlots.count]
            let actual = try runProjectionCase(
                projection: productionProjection,
                fields: productionFields,
                input: input,
                status: status
            )
            let durationMilliseconds = Date().timeIntervalSince(started) * 1_000
            let diagnostics = actual.diagnostics
            let actualInput = (
                reference["u_input"]!.map(Float.init).map(Double.init),
                reference["v_input"]!.map(Float.init).map(Double.init),
                reference["w_input"]!.map(Float.init).map(Double.init)
            )
            let cpuRHSFromGPUInput = cpuDivergence(
                nx: 64, ny: 64, nz: 64, h: cellSpacing,
                u: actualInput.0, v: actualInput.1, w: actualInput.2
            ).map { -cellSpacing * cellSpacing * $0 }
            let cpuResidualFromGPUPressure = zip(
                cpuRHSFromGPUInput,
                cpuApplyA(
                    nx: 64, ny: 64, nz: 64,
                    pressure: actual.pressure
                )
            ).map { $0.0 - $0.1 }
            let cpuResidualMax = cpuResidualFromGPUPressure.map(abs).max() ?? 0
            try require(cpuResidualMax * Double(productionConfiguration.dt) / (cellSpacing * cellSpacing) <= 1e-5,
                        "\(name) independent full-volume true residual exceeds the registered gate")
            let independentDivergence = cpuDivergence(
                nx: 64, ny: 64, nz: 64, h: cellSpacing,
                u: actual.u.map(Double.init), v: actual.v.map(Double.init), w: actual.w.map(Double.init)
            )
            let independentDT = (independentDivergence.map(abs).max() ?? 0) * Double(productionConfiguration.dt)
            let inputDT = (cpuRHSFromGPUInput.map(abs).max() ?? 0)
                * Double(productionConfiguration.dt) / (cellSpacing * cellSpacing)
            try require(independentDT <= 1e-5, "\(name) independent post-readback divergence exceeds the registered gate")
            if inputDT >= 1e-3 {
                try require(independentDT == 0 || inputDT / independentDT >= 1000,
                            "\(name) independent post-readback divergence reduction is below 1000x")
            }
            let independentIdentityDT = zip(independentDivergence, cpuResidualFromGPUPressure).map {
                abs($0.0 + $0.1 / (cellSpacing * cellSpacing)) * Double(productionConfiguration.dt)
            }.max() ?? 0
            FileHandle.standardError.write(Data("INDEPENDENT_IDENTITY \(name) dtError=\(independentIdentityDT) divergenceDT=\(independentDT)\n".utf8))
            let identityReport = try verifyStoredIdentity(
                input: actualInput, output: (actual.u, actual.v, actual.w),
                pressure: actual.pressure, residual: cpuResidualFromGPUPressure,
                h: cellSpacing, dt: Double(productionConfiguration.dt), label: name
            )
            let gpuResidualMax = actual.trueResidual.map { abs(Double($0)) }.max() ?? 0
            if name == "manufactured_cosine" {
                guard let gpuTrace = status.pcgTrace(iterations: diagnostics.iterations) else {
                    throw Fluid3DHarnessError.assertion("Manufactured cosine trace buffer was unavailable")
                }
                try require(gpuTrace.count == diagnostics.iterations,
                            "GPU PCG trace omitted one or more completed iterations")
                try require(gpuTrace.last?.checkedTrueResidual == true,
                            "Padded dispatches overwrote the final genuine convergence trace record")
                if ProcessInfo.processInfo.environment["FLUID3D_TRACE"] == "1" {
                let cpuReplay = Fluid3DFloat32PCGDiagnostic.solve(
                    u: input.0, v: input.1, w: input.2,
                    h: productionConfiguration.h,
                    dt: productionConfiguration.dt,
                    iterationLimit: PressureProjection3D.maximumIterations
                )
                let traceSummary = [
                    "PCG_TRACE_SUMMARY",
                    "gpuIterations=\(gpuTrace.count)",
                    "cpuIterations=\(cpuReplay.iterations)",
                    "gpuRestarts=\(diagnostics.trueResidualRestarts)",
                    "cpuRestarts=\(cpuReplay.restarts)",
                    "gpuConverged=\(diagnostics.converged)",
                    "cpuConverged=\(cpuReplay.converged)",
                    "gpuRecursiveMax=\(diagnostics.recursiveResidualMax)",
                    "cpuRecursiveMax=\(cpuReplay.recursiveResidualMaximum)",
                    "gpuTrueResidualMax=\(gpuResidualMax)",
                    "cpuTrueResidualMax=\(cpuReplay.trueResidualMaximum)",
                ].joined(separator: " ") + "\n"
                FileHandle.standardError.write(Data(traceSummary.utf8))
                for (gpu, cpu) in zip(gpuTrace, cpuReplay.trace) {
                    let gpuTrue = gpu.trueResidualMaximum.map { String($0) } ?? "-"
                    let cpuTrue = cpu.trueResidualMaximum.map { String($0) } ?? "-"
                    let line = [
                        "PCG_TRACE",
                        "iteration=\(gpu.iteration)",
                        "gpuRecursive=\(gpu.recursiveResidualMaximum)",
                        "cpuRecursive=\(cpu.recursiveResidualMaximum)",
                        "gpuCheck=\(gpu.checkedTrueResidual)",
                        "cpuCheck=\(cpu.checkedTrueResidual)",
                        "gpuTrue=\(gpuTrue)",
                        "cpuTrue=\(cpuTrue)",
                        "gpuRestart=\(gpu.restartPending)",
                        "cpuRestart=\(cpu.restartPending)",
                        "gpuRho=\(gpu.rho)",
                        "cpuRho=\(cpu.rho)",
                        "gpuAlpha=\(gpu.alpha)",
                        "cpuAlpha=\(cpu.alpha)",
                        "gpuDenominator=\(gpu.searchDenominator)",
                        "cpuDenominator=\(cpu.searchDenominator)",
                    ].joined(separator: " ") + "\n"
                    FileHandle.standardError.write(Data(line.utf8))
                }
                }
            }
            let caseDiagnosticLine = "PROJECTION_CASE \(name) iterations=\(diagnostics.iterations) "
                + "failure=\(diagnostics.failure) converged=\(diagnostics.converged) "
                + "capHit=\(diagnostics.capHit) rhsMean=\(diagnostics.rhsMean) "
                + "restarts=\(diagnostics.trueResidualRestarts) "
                + "recursiveResidualMax=\(diagnostics.recursiveResidualMax) "
                + "rho=\(diagnostics.finalPreconditionedResidualDot) "
                + "alpha=\(diagnostics.finalAlpha) beta=\(diagnostics.finalBeta) "
                + "denominator=\(diagnostics.finalSearchDenominator) "
                + "compatibilityBound=\(diagnostics.compatibilityBound) "
                + "inputDT=\(diagnostics.inputDivergenceDTInf) "
                + "divergenceDT=\(diagnostics.projectedDivergenceDTInf) "
                + "residualDT=\(diagnostics.trueResidualDTInf) "
                + "identityDT=\(diagnostics.identityDTError) "
                + "reduction=\(diagnostics.divergenceReduction) "
                + "wall=\(diagnostics.maximumWallNormalValue) "
                + "pressureError=\(maxDifference(actual.pressure, reference["pressure_q"]!)) "
                + "cpuTrueResidualFromGPUQ=\(cpuResidualMax) "
                + "gpuTrueResidual=\(gpuResidualMax) "
                + "residualImplementationError=\(maxDifference(actual.trueResidual.map(Double.init), cpuResidualFromGPUPressure))\n"
            FileHandle.standardError.write(Data(caseDiagnosticLine.utf8))
            try require(diagnostics.failure == .none && diagnostics.converged && !diagnostics.capHit,
                        "\(name) PCG failed: \(diagnostics.failure), iterations=\(diagnostics.iterations)")
            try require(diagnostics.iterations <= PressureProjection3D.maximumIterations,
                        "\(name) exceeded the preregistered 320-iteration cap")
            try require(abs(diagnostics.rhsMean) <= diagnostics.compatibilityBound,
                        "\(name) RHS compatibility mean exceeded its Float32 roundoff bound")
            try require(diagnostics.projectedDivergenceDTInf <= 1e-5
                        && diagnostics.trueResidualDTInf <= 1e-5,
                        "\(name) missed a preregistered timestep-scaled projection threshold")
            try require(diagnostics.maximumWallNormalValue == 0,
                        "\(name) projected velocity has nonzero wall-normal flux")
            if diagnostics.inputDivergenceDTInf >= 1e-3 {
                try require(diagnostics.divergenceReduction >= 1_000,
                            "\(name) did not reduce divergence by the required 1000x")
            }

            var caseMaximumError = 0.0
            let timestep = Double(productionConfiguration.dt)
            let comparisons: [(String, [Float], [Double])] = [
                ("u_projected", actual.u, reference["u_projected"]!),
                ("v_projected", actual.v, reference["v_projected"]!),
                ("w_projected", actual.w, reference["w_projected"]!),
                ("pressure_q", actual.pressure.map(Float.init), reference["pressure_q"]!),
                (
                    "dt_divergence_projected",
                    actual.divergence.map { $0 * productionConfiguration.dt },
                    reference["divergence_projected"]!.map { $0 * timestep }
                ),
                (
                    "dt_true_residual_over_h2",
                    actual.trueResidual.map { $0 * productionConfiguration.dt / Float(cellSpacing * cellSpacing) },
                    reference["true_residual"]!.map { $0 * timestep / (cellSpacing * cellSpacing) }
                ),
            ]
            for (field, observed, expected) in comparisons {
                try compareFloatField(observed, expected, label: "\(name)/\(field)")
                caseMaximumError = max(caseMaximumError, maxDifference(observed.map(Double.init), expected))
                comparedValues += observed.count
            }
            let identityTimeScale = timestep
            let expectedIdentityDT = zip(reference["divergence_projected"]!, reference["true_residual"]!)
                .map { ($0.0 + $0.1 / pow(1.0 / 64.0, 2)) * identityTimeScale }
            try compareFloatField(
                actual.identityError.map { Float($0) * productionConfiguration.dt },
                expectedIdentityDT,
                label: "\(name)/timestep-scaled projection identity"
            )
            _ = try exactWallZeros(
                u: actual.u, v: actual.v, w: actual.w,
                nx: 64, ny: 64, nz: 64, label: name
            )
            maximumAbsoluteError = max(maximumAbsoluteError, caseMaximumError)
            caseReports.append([
                "name": name,
                "iterations": diagnostics.iterations,
                "referenceIterations": summaries[name]!["iterations"]!,
                "capHit": diagnostics.capHit,
                "inputDivergenceDTInf": diagnostics.inputDivergenceDTInf,
                "projectedDivergenceDTInf": diagnostics.projectedDivergenceDTInf,
                "trueResidualDTInf": diagnostics.trueResidualDTInf,
                "identityDTError": diagnostics.identityDTError,
                "independentDivergenceDTInf": independentDT,
                "independentTrueResidualDTInf": cpuResidualMax * timestep / (cellSpacing * cellSpacing),
                "independentDivergenceRMS": sqrt(independentDivergence.reduce(0) { $0 + $1 * $1 } / Double(independentDivergence.count)),
                "independentResidualRMS": sqrt(cpuResidualFromGPUPressure.reduce(0) { $0 + $1 * $1 } / Double(cpuResidualFromGPUPressure.count)),
                "independentStoredIdentityDT": independentIdentityDT,
                "identityPrecision": identityReport,
                "divergenceReduction": diagnostics.divergenceReduction,
                "rhsMean": diagnostics.rhsMean,
                "compatibilityBound": diagnostics.compatibilityBound,
                "maximumWallNormalValue": diagnostics.maximumWallNormalValue,
                "comparedValues": comparisons.reduce(0) { $0 + $1.1.count },
                "maxAbsoluteError": caseMaximumError,
                "durationMilliseconds": durationMilliseconds,
                "finite": true,
            ])
        }

        let slotReports = try runThreeInFlightStatusSlots(metal: metal)
        try require(comparedValues > 0, "No production PCG values were compared")
        return [
            "passed": true,
            "fixture": "projection",
            "device": device.name,
            "contractHash": manifest["contractHash"]!,
            "quickAsymmetricIterations": asymResult.diagnostics.iterations,
            "quickFailureCases": [
                ["name": "incompatible_rhs", "failure": incompatibleResult.diagnostics.failure.description],
                ["name": "zero_denominator", "failure": denominatorFailure.diagnostics.failure.description],
                ["name": "iteration_cap", "failure": capFailure.diagnostics.failure.description,
                 "iterations": capFailure.diagnostics.iterations],
                ["name": "nonfinite_input", "failure": nanResult.diagnostics.failure.description],
            ],
            "zeroRHSIterations": zeroResult.diagnostics.iterations,
            "threeInFlightStatusSlots": slotReports,
            "cases": caseReports,
            "comparedValues": comparedValues,
            "maxAbsoluteError": maximumAbsoluteError,
            "absoluteTolerance": 2e-5,
            "relativeTolerance": 2e-4,
            "cap": PressureProjection3D.maximumIterations,
            "finite": true,
        ]
    }

    private static func makeProjectionFields(
        configuration: FluidSimulation3DConfiguration,
        metal: MetalDevice
    ) throws -> ProjectionFields {
        ProjectionFields(
            u: try VolumeField3D(grid: configuration, component: .u, metal: metal),
            v: try VolumeField3D(grid: configuration, component: .v, metal: metal),
            w: try VolumeField3D(grid: configuration, component: .w, metal: metal)
        )
    }

    private static func verifyStoredIdentity(
        input: ([Double], [Double], [Double]), output: ([Float], [Float], [Float]),
        pressure: [Double], residual: [Double], h: Double, dt: Double, label: String
    ) throws -> [String: Any] {
        let inputs = [input.0, input.1, input.2]
        let outputs = [output.0, output.1, output.2]
        let components: [OperatorComponent] = [.u, .v, .w]
        var ideals: [[Double]] = []
        var budgets: [[Double]] = []
        let epsilon = Double(Float.ulpOfOne)
        let maximumPressure = pressure.map(abs).max() ?? 0
        for axis in 0..<3 {
            let ideal = cpuSubtractGradient(nx: 64, ny: 64, nz: 64, h: h, q: pressure,
                                            velocity: inputs[axis], component: components[axis])
            let budget = ideal.indices.map { face -> Double in
                let rounded = Float(ideal[face])
                let gradient = inputs[axis][face] - ideal[face]
                return 0.5 * Double(rounded.ulp)
                    + 16 * epsilon * epsilon * (abs(inputs[axis][face]) + abs(gradient))
                    + 8 * Double.ulpOfOne * (abs(inputs[axis][face]) + abs(gradient) + 2 * maximumPressure / h)
            }
            for face in ideal.indices {
                try require(ideal[face].isFinite && budget[face].isFinite
                            && abs(Double(outputs[axis][face]) - ideal[face]) <= budget[face],
                            "\(label) face gradient/storage exceeds derived rounding bound at axis \(axis), face \(face): actual=\(outputs[axis][face]) ideal=\(ideal[face]) error=\(abs(Double(outputs[axis][face]) - ideal[face])) bound=\(budget[face])")
            }
            ideals.append(ideal)
            budgets.append(budget)
        }
        let idealD = cpuDivergence(nx: 64, ny: 64, nz: 64, h: h, u: ideals[0], v: ideals[1], w: ideals[2])
        let storedD = cpuDivergence(nx: 64, ny: 64, nz: 64, h: h,
                                  u: output.0.map(Double.init), v: output.1.map(Double.init), w: output.2.map(Double.init))
        var maximumIdeal = 0.0
        var maximumBound = 0.0
        var maximumStored = 0.0
        for k in 0..<64 { for j in 0..<64 { for i in 0..<64 {
            let cell = (k * 64 + j) * 64 + i
            let ui = (k * 64 + j) * 65 + i
            let vi = (k * 65 + j) * 64 + i
            let wi = cell
            let idealError = dt * abs(idealD[cell] + residual[cell] / (h * h))
            let storedError = dt * abs(storedD[cell] + residual[cell] / (h * h))
            let sumU = budgets[0][ui] + budgets[0][ui + 1]
            let sumV = budgets[1][vi] + budgets[1][vi + 64]
            let sumW = budgets[2][wi] + budgets[2][wi + 64 * 64]
            let bound = 1e-10 + dt / h * (sumU + sumV + sumW)
            try require(idealError <= 1e-10, "\(label) independent Double identity failed")
            try require(storedError <= bound, "\(label) stored identity exceeds derived face-rounding budget")
            maximumIdeal = max(maximumIdeal, idealError)
            maximumStored = max(maximumStored, storedError)
            maximumBound = max(maximumBound, bound)
        } } }
        return ["doubleIdealDTError": maximumIdeal, "storedDTError": maximumStored,
                "maximumDerivedDTBound": maximumBound, "facewiseRoundingVerified": true]
    }

    private static func runProjectionCase(
        projection: PressureProjection3D,
        fields: ProjectionFields,
        input: (u: [Float], v: [Float], w: [Float]),
        status: PressureProjection3D.StatusSlot,
        iterationLimit: Int = PressureProjection3D.maximumIterations,
        failureInjection: Fluid3DProjectionFailureInjection = .none
    ) throws -> ProjectionReadback {
        let command = projection.metal.newCommandBuffer()
        try fields.u.encodeUpload(input.u, to: fields.u.ping, command: command)
        try fields.v.encodeUpload(input.v, to: fields.v.ping, command: command)
        try fields.w.encodeUpload(input.w, to: fields.w.ping, command: command)
        return try runProjectionTextures(
            projection: projection,
            fields: fields,
            input: (fields.u.ping, fields.v.ping, fields.w.ping),
            status: status,
            iterationLimit: iterationLimit,
            failureInjection: failureInjection,
            command: command
        )
    }

    private static func runProjectionTextures(
        projection: PressureProjection3D,
        fields: ProjectionFields,
        input: (u: MTLTexture, v: MTLTexture, w: MTLTexture),
        status: PressureProjection3D.StatusSlot,
        iterationLimit: Int = PressureProjection3D.maximumIterations,
        failureInjection: Fluid3DProjectionFailureInjection = .none,
        command suppliedCommand: MTLCommandBuffer? = nil
    ) throws -> ProjectionReadback {
        let command = suppliedCommand ?? projection.metal.newCommandBuffer()
        try projection.encodeProjection(
            command: command,
            u: input.u, v: input.v, w: input.w,
            projectedU: fields.u.pong, projectedV: fields.v.pong, projectedW: fields.w.pong,
            status: status,
            iterationLimit: iterationLimit,
            failureInjection: failureInjection
        )
        let uReadback = try fields.u.encodeReadback(from: fields.u.pong, command: command)
        let vReadback = try fields.v.encodeReadback(from: fields.v.pong, command: command)
        let wReadback = try fields.w.encodeReadback(from: fields.w.pong, command: command)
        let pressureReadback = try projection.pressure.encodeReadback(
            from: projection.pressure.ping, command: command
        )
        let pressureLowReadback = try projection.pressure.encodeReadback(
            from: projection.pressure.pong, command: command
        )
        let divergenceReadback = try projection.divergence.encodeReadback(
            from: projection.divergence.pong, command: command
        )
        let residualReadback = try projection.trueResidual.encodeReadback(
            from: projection.trueResidual.ping, command: command
        )
        let identityReadback = try projection.identityError.encodeReadback(
            from: projection.identityError.ping, command: command
        )
        command.commit()
        command.waitUntilCompleted()
        guard command.status == .completed else {
            throw Fluid3DHarnessError.commandBuffer(
                "GPU PCG projection command failed: \(String(describing: command.error))"
            )
        }
        return ProjectionReadback(
            diagnostics: status.diagnostics(),
            u: try fields.u.decodeReadback(uReadback),
            v: try fields.v.decodeReadback(vReadback),
            w: try fields.w.decodeReadback(wReadback),
            pressure: try zip(
                projection.pressure.decodeReadback(pressureReadback),
                projection.pressure.decodeReadback(pressureLowReadback)
            ).map { Double($0.0) + Double($0.1) },
            divergence: try projection.divergence.decodeReadback(divergenceReadback),
            trueResidual: try projection.trueResidual.decodeReadback(residualReadback),
            identityError: try projection.identityError.decodeReadback(identityReadback)
        )
    }

    private static func runThreeInFlightStatusSlots(metal: MetalDevice) throws -> [[String: Any]] {
        let configuration = try FluidSimulation3DConfiguration.fixture(nx: 8, ny: 7, nz: 6, h: 1)
        let projection = try PressureProjection3D(metal: metal, configuration: configuration)
        let values = [
            // A true zero RHS is the successful zero-iteration control. The
            // affine operator fixture cannot converge in a one-iteration cap.
            makeInteriorProbeVelocity(nx: 8, ny: 7, nz: 6, amplitude: 0),
            makeInteriorProbeVelocity(nx: 8, ny: 7, nz: 6, amplitude: 0.03),
            makeInteriorProbeVelocity(nx: 8, ny: 7, nz: 6, amplitude: 0.08),
        ]
        let statuses = try (0..<3).map {
            try projection.makeStatusSlot(label: "in-flight PCG status \($0)")
        }
        let fields = try (0..<3).map { _ in
            try makeProjectionFields(configuration: configuration, metal: metal)
        }
        var commands: [MTLCommandBuffer] = []
        for index in 0..<3 {
            let command = metal.newCommandBuffer()
            try fields[index].u.encodeUpload(values[index].u, to: fields[index].u.ping, command: command)
            try fields[index].v.encodeUpload(values[index].v, to: fields[index].v.ping, command: command)
            try fields[index].w.encodeUpload(values[index].w, to: fields[index].w.ping, command: command)
            try projection.encodeProjection(
                command: command,
                u: fields[index].u.ping, v: fields[index].v.ping, w: fields[index].w.ping,
                projectedU: fields[index].u.pong, projectedV: fields[index].v.pong,
                projectedW: fields[index].w.pong,
                status: statuses[index], iterationLimit: 1
            )
            commands.append(command)
        }
        for command in commands { command.commit() }
        for command in commands {
            command.waitUntilCompleted()
            guard command.status == .completed else {
                throw Fluid3DHarnessError.commandBuffer(
                    "In-flight status-slot command failed: \(String(describing: command.error))"
                )
            }
        }
        let diagnostics = statuses.map { $0.diagnostics() }
        try require(diagnostics[0].failure == .none && diagnostics[0].converged,
                    "First in-flight status slot was overwritten by a later command")
        try require(diagnostics[1].failure == .iterationCapExceeded && diagnostics[1].capHit
                    && diagnostics[2].failure == .iterationCapExceeded && diagnostics[2].capHit,
                    "Two capped in-flight solves did not retain independent failure statuses")
        try require(diagnostics[1].inputDivergenceDTInf != diagnostics[2].inputDivergenceDTInf,
                    "In-flight status slots did not retain their submission-specific diagnostics")
        return diagnostics.enumerated().map { index, item in
            [
                "slot": index,
                "iterations": item.iterations,
                "failure": item.failure.description,
                "converged": item.converged,
                "inputDivergenceDTInf": item.inputDivergenceDTInf,
            ]
        }
    }

    private static func loadProjectionPayload(
        _ payload: [String: Any],
        directory: URL
    ) throws -> [String: [Double]] {
        guard let filename = payload["file"] as? String,
              let byteCount = payload["byteCount"] as? Int,
              let descriptors = payload["arrayOrder"] as? [[String: Any]] else {
            throw Fluid3DHarnessError.assertion("Malformed projection binary payload descriptor")
        }
        let data = try Data(contentsOf: directory.appendingPathComponent(filename))
        try require(data.count == byteCount, "\(filename) payload byte count mismatch")
        var reference: [String: [Double]] = [:]
        var offset = 0
        for descriptor in descriptors {
            guard let name = descriptor["name"] as? String,
                  let shape = descriptor["shape"] as? [Int], shape.count == 3 else {
                throw Fluid3DHarnessError.assertion("Malformed array descriptor in \(filename)")
            }
            let count = shape.reduce(1, *)
            try require(!reference.keys.contains(name), "Duplicate \(name) array in \(filename)")
            reference[name] = try decodeLittleEndianDoubles(data, offsetElements: offset, count: count)
            offset += count
        }
        try require(offset * MemoryLayout<UInt64>.stride == data.count,
                    "\(filename) payload contains unaccounted data")
        return reference
    }

    private static func makePressureVelocity(
        _ pressure: [Float],
        nx: Int,
        ny: Int,
        nz: Int,
        h: Float
    ) -> (u: [Float], v: [Float], w: [Float]) {
        var velocity = makeOperatorVelocity(nx: nx, ny: ny, nz: nz)
        velocity.u = Array(repeating: 0, count: (nx + 1) * ny * nz)
        velocity.v = Array(repeating: 0, count: nx * (ny + 1) * nz)
        velocity.w = Array(repeating: 0, count: nx * ny * (nz + 1))
        for k in 0..<nz {
            for j in 0..<ny {
                for i in 1..<nx {
                    let face = (k * ny + j) * (nx + 1) + i
                    let left = (k * ny + j) * nx + i - 1
                    velocity.u[face] = (pressure[left + 1] - pressure[left]) / h
                }
            }
        }
        for k in 0..<nz {
            for j in 1..<ny {
                for i in 0..<nx {
                    let face = (k * (ny + 1) + j) * nx + i
                    let lower = (k * ny + j - 1) * nx + i
                    velocity.v[face] = (pressure[lower + nx] - pressure[lower]) / h
                }
            }
        }
        for k in 1..<nz {
            for j in 0..<ny {
                for i in 0..<nx {
                    let face = (k * ny + j) * nx + i
                    let lower = ((k - 1) * ny + j) * nx + i
                    velocity.w[face] = (pressure[lower + nx * ny] - pressure[lower]) / h
                }
            }
        }
        return velocity
    }

    private static func makeInteriorProbeVelocity(
        nx: Int,
        ny: Int,
        nz: Int,
        amplitude: Float
    ) -> (u: [Float], v: [Float], w: [Float]) {
        var result = makeOperatorVelocity(nx: nx, ny: ny, nz: nz)
        result.u = Array(repeating: 0, count: (nx + 1) * ny * nz)
        result.v = Array(repeating: 0, count: nx * (ny + 1) * nz)
        result.w = Array(repeating: 0, count: nx * ny * (nz + 1))
        result.u[(2 * ny + 3) * (nx + 1) + 2] = amplitude
        return result
    }

    private static func makeSharedVelocityTextures(
        device: MTLDevice,
        nx: Int,
        ny: Int,
        nz: Int,
        values: (u: [Float], v: [Float], w: [Float]),
        nanUIndex: Int
    ) throws -> (u: MTLTexture, v: MTLTexture, w: MTLTexture) {
        var uValues = values.u
        uValues[nanUIndex] = .nan
        return (
            try makeSharedTexture(device: device, width: nx + 1, height: ny, depth: nz, values: uValues),
            try makeSharedTexture(device: device, width: nx, height: ny + 1, depth: nz, values: values.v),
            try makeSharedTexture(device: device, width: nx, height: ny, depth: nz + 1, values: values.w)
        )
    }

    private static func makeSharedTexture(
        device: MTLDevice,
        width: Int,
        height: Int,
        depth: Int,
        values: [Float]
    ) throws -> MTLTexture {
        let descriptor = MTLTextureDescriptor()
        descriptor.textureType = .type3D
        descriptor.pixelFormat = .r32Float
        descriptor.width = width
        descriptor.height = height
        descriptor.depth = depth
        descriptor.mipmapLevelCount = 1
        descriptor.storageMode = .shared
        descriptor.usage = [.shaderRead]
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            throw Fluid3DHarnessError.library("Unable to allocate shared projection failure texture")
        }
        try require(values.count == width * height * depth, "Shared texture fixture size mismatch")
        values.withUnsafeBytes { bytes in
            texture.replace(
                region: MTLRegionMake3D(0, 0, 0, width, height, depth),
                mipmapLevel: 0,
                slice: 0,
                withBytes: bytes.baseAddress!,
                bytesPerRow: width * MemoryLayout<Float>.stride,
                bytesPerImage: width * height * MemoryLayout<Float>.stride
            )
        }
        return texture
    }

    private static func reductionResult(_ buffer: MTLBuffer) -> SIMD4<Float> {
        buffer.contents().assumingMemoryBound(to: SIMD4<Float>.self).pointee
    }

    private static func compareReduction(
        _ actual: SIMD4<Float>,
        reference values: [Double],
        label: String
    ) throws {
        try require(values.allSatisfy(\.isFinite), "\(label) CPU reduction input is nonfinite")
        let expectedSum = values.reduce(0, +)
        let expectedSquares = values.reduce(0) { $0 + $1 * $1 }
        let expectedMaximum = values.map(abs).max() ?? 0
        for (name, gpu, cpu) in [
            ("sum", actual.x, expectedSum),
            ("sum of squares", actual.y, expectedSquares),
            ("maximum absolute", actual.z, expectedMaximum),
        ] {
            let gpuValue = Double(gpu)
            let tolerance = 2e-5 + 2e-4 * abs(cpu)
            try require(gpuValue.isFinite && abs(gpuValue - cpu) <= tolerance,
                        "\(label) GPU \(name) mismatch: actual=\(gpuValue), reference=\(cpu), limit=\(tolerance)")
        }
    }

    private static func makeOperatorVelocity(
        nx: Int,
        ny: Int,
        nz: Int
    ) -> (u: [Float], v: [Float], w: [Float]) {
        var u = Array(repeating: Float.zero, count: (nx + 1) * ny * nz)
        var v = Array(repeating: Float.zero, count: nx * (ny + 1) * nz)
        var w = Array(repeating: Float.zero, count: nx * ny * (nz + 1))
        for k in 0..<nz {
            for j in 0..<ny {
                for i in 1..<nx {
                    u[(k * ny + j) * (nx + 1) + i] = Float(0.003 * Double(i) - 0.001 * Double(j) + 0.002 * Double(k))
                }
            }
        }
        for k in 0..<nz {
            for j in 1..<ny {
                for i in 0..<nx {
                    v[(k * (ny + 1) + j) * nx + i] = Float(-0.002 * Double(i) + 0.004 * Double(j) + 0.001 * Double(k))
                }
            }
        }
        for k in 1..<nz {
            for j in 0..<ny {
                for i in 0..<nx {
                    w[(k * ny + j) * nx + i] = Float(0.001 * Double(i) + 0.002 * Double(j) - 0.003 * Double(k))
                }
            }
        }
        return (u, v, w)
    }

    private static func makeWallFluxProbe(
        nx: Int,
        ny: Int,
        nz: Int
    ) -> (u: [Float], v: [Float], w: [Float]) {
        var u = Array(repeating: Float.zero, count: (nx + 1) * ny * nz)
        var v = Array(repeating: Float.zero, count: nx * (ny + 1) * nz)
        var w = Array(repeating: Float.zero, count: nx * ny * (nz + 1))

        for k in 0..<nz {
            for j in 0..<ny {
                u[(k * ny + j) * (nx + 1)] = 1
                u[(k * ny + j) * (nx + 1) + nx] = 4
            }
        }
        for k in 0..<nz {
            for i in 0..<nx {
                v[(k * (ny + 1)) * nx + i] = 2
                v[(k * (ny + 1) + ny) * nx + i] = 5
            }
        }
        for j in 0..<ny {
            for i in 0..<nx {
                w[j * nx + i] = 3
                w[(nz * ny + j) * nx + i] = 6
            }
        }
        return (u, v, w)
    }

    private static func cpuDivergence(
        nx: Int,
        ny: Int,
        nz: Int,
        h: Double,
        u: [Double],
        v: [Double],
        w: [Double]
    ) -> [Double] {
        var result = Array(repeating: 0.0, count: nx * ny * nz)
        for k in 0..<nz {
            for j in 0..<ny {
                for i in 0..<nx {
                    let cell = (k * ny + j) * nx + i
                    let ux = (k * ny + j) * (nx + 1)
                    let vy = (k * (ny + 1) + j) * nx + i
                    let wz = (k * ny + j) * nx + i
                    result[cell] = (u[ux + i + 1] - u[ux + i]
                        + v[vy + nx] - v[vy]
                        + w[wz + nx * ny] - w[wz]) / h
                }
            }
        }
        return result
    }

    private static func cpuApplyA(
        nx: Int,
        ny: Int,
        nz: Int,
        pressure: [Double]
    ) -> [Double] {
        var result = Array(repeating: 0.0, count: nx * ny * nz)
        for k in 0..<nz {
            for j in 0..<ny {
                for i in 0..<nx {
                    let center = (k * ny + j) * nx + i
                    let centerValue = pressure[center]
                    var degree = 0.0
                    var neighborSum = 0.0
                    if i > 0 { degree += 1; neighborSum += pressure[center - 1] }
                    if i + 1 < nx { degree += 1; neighborSum += pressure[center + 1] }
                    if j > 0 { degree += 1; neighborSum += pressure[center - nx] }
                    if j + 1 < ny { degree += 1; neighborSum += pressure[center + nx] }
                    if k > 0 { degree += 1; neighborSum += pressure[center - nx * ny] }
                    if k + 1 < nz { degree += 1; neighborSum += pressure[center + nx * ny] }
                    result[center] = degree * centerValue - neighborSum
                }
            }
        }
        return result
    }

    private enum OperatorComponent {
        case u
        case v
        case w
    }

    private static func cpuSubtractGradient(
        nx: Int,
        ny: Int,
        nz: Int,
        h: Double,
        q: [Double],
        velocity: [Double],
        component: OperatorComponent
    ) -> [Double] {
        var result = velocity
        switch component {
        case .u:
            for k in 0..<nz { for j in 0..<ny { for i in 1..<nx {
                let face = (k * ny + j) * (nx + 1) + i
                let left = (k * ny + j) * nx + i - 1
                result[face] -= (q[left + 1] - q[left]) / h
            } } }
        case .v:
            for k in 0..<nz { for j in 1..<ny { for i in 0..<nx {
                let face = (k * (ny + 1) + j) * nx + i
                let lower = ((k * ny + j - 1) * nx + i)
                result[face] -= (q[lower + nx] - q[lower]) / h
            } } }
        case .w:
            for k in 1..<nz { for j in 0..<ny { for i in 0..<nx {
                let face = (k * ny + j) * nx + i
                let lower = ((k - 1) * ny + j) * nx + i
                result[face] -= (q[lower + nx * ny] - q[lower]) / h
            } } }
        }
        return result
    }

    private static func compareFloatField(_ actual: [Float], _ expected: [Double], label: String) throws {
        try require(actual.count == expected.count, "\(label) element count mismatch")
        for index in expected.indices {
            let actual = Double(actual[index])
            let reference = expected[index]
            try require(actual.isFinite && reference.isFinite,
                        "\(label) has a nonfinite value at x-fastest index \(index)")
            let error = abs(actual - reference)
            let tolerance = 2e-5 + 2e-4 * abs(reference)
            try require(error <= tolerance,
                        "\(label) mismatch at x-fastest index \(index): actual=\(actual), reference=\(reference), error=\(error), limit=\(tolerance)")
        }
    }

    private static func maxDifference(_ lhs: [Double], _ rhs: [Double]) -> Double {
        guard lhs.count == rhs.count else { return .infinity }
        return zip(lhs, rhs).map { abs($0.0 - $0.1) }.max() ?? 0
    }

    private static func runNonfiniteReductionFixture(
        device: MTLDevice,
        metal: MetalDevice,
        h: Float
    ) throws -> SIMD4<Float> {
        let configuration = try FluidSimulation3DConfiguration.fixture(nx: 1, ny: 1, nz: 1, h: h)
        let projection = try PressureProjection3D(metal: metal, configuration: configuration)
        let descriptor = MTLTextureDescriptor()
        descriptor.textureType = .type3D
        descriptor.pixelFormat = .r32Float
        descriptor.width = 1
        descriptor.height = 1
        descriptor.depth = 1
        descriptor.mipmapLevelCount = 1
        descriptor.storageMode = .shared
        descriptor.usage = [.shaderRead]
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            throw Fluid3DHarnessError.library("Unable to allocate shared NaN diagnostic fixture texture")
        }
        texture.label = "3D nonfinite reduction fixture"
        var nan = Float.nan
        texture.replace(
            region: MTLRegionMake3D(0, 0, 0, 1, 1, 1),
            mipmapLevel: 0,
            slice: 0,
            withBytes: &nan,
            bytesPerRow: MemoryLayout<Float>.stride,
            bytesPerImage: MemoryLayout<Float>.stride
        )
        let result = try projection.makeReductionResult(label: "nonfinite diagnostic result")
        let command = metal.newCommandBuffer()
        try projection.encodeReduction(command: command, input: texture, result: result)
        command.commit()
        command.waitUntilCompleted()
        guard command.status == .completed else {
            throw Fluid3DHarnessError.commandBuffer(
                "Nonfinite reduction fixture command failed: \(String(describing: command.error))"
            )
        }
        return reductionResult(result)
    }

    private static func advectionAndBoundaries(
        device: MTLDevice,
        metal: MetalDevice,
        referenceDirectory: URL
    ) throws -> [String: Any] {
        let manifestURL = referenceDirectory.appendingPathComponent("advection-manifest.json")
        let manifestData = try Data(contentsOf: manifestURL)
        guard let manifest = try JSONSerialization.jsonObject(with: manifestData) as? [String: Any],
              (manifest["schemaVersion"] as? Int) == 1,
              (manifest["contractHash"] as? String) == "a7768571a996d5b9520aff5095100bb52fb67f96560f99633d081c04a3a9e01b",
              let tolerance = manifest["tolerance"] as? [String: Double],
              let absoluteTolerance = tolerance["absolute"],
              let relativeTolerance = tolerance["relative"],
              let fixtures = manifest["cases"] as? [[String: Any]] else {
            throw Fluid3DHarnessError.assertion("Invalid or mismatched advection CPU-oracle manifest")
        }

        let expectedNames: Set<String> = [
            "zero_uniform", "positive_x", "negative_x", "positive_y", "negative_y",
            "positive_z", "negative_z", "combined_xyz", "combined_xyz_mixed",
            "wall_edge_corner", "production_mixed",
        ]
        let actualNames = Set(fixtures.compactMap { $0["name"] as? String })
        try require(actualNames == expectedNames, "Advection oracle case set changed: \(actualNames)")

        var totalCompared = 0
        var maximumAbsoluteError = 0.0
        var caseReports: [[String: Any]] = []
        for fixture in fixtures {
            guard let name = fixture["name"] as? String,
                  let grid = fixture["grid"] as? [String: Any],
                  let nx = grid["nx"] as? Int,
                  let ny = grid["ny"] as? Int,
                  let nz = grid["nz"] as? Int,
                  let h = grid["h"] as? Double,
                  let dt = grid["dt"] as? Double,
                  let filename = fixture["file"] as? String,
                  let byteCount = fixture["byteCount"] as? Int,
                  let descriptors = fixture["arrays"] as? [[String: Any]] else {
                throw Fluid3DHarnessError.assertion("Malformed advection fixture in CPU-oracle manifest")
            }
            try require(grid["xFastest"] as? Bool == true, "\(name) does not declare x-fastest arrays")
            if name == "production_mixed" {
                try require(nx == 64 && ny == 64 && nz == 64, "Production fixture grid is not 64 cubed")
            } else {
                try require(nx == 8 && ny == 7 && nz == 6, "Asymmetric fixture grid changed for \(name)")
            }

            let payloadURL = referenceDirectory.appendingPathComponent(filename)
            let payload = try Data(contentsOf: payloadURL)
            try require(payload.count == byteCount, "\(name) payload byte count mismatch")
            var reference: [String: [Double]] = [:]
            for descriptor in descriptors {
                guard let fieldName = descriptor["name"] as? String,
                      let count = descriptor["elementCount"] as? Int,
                      let offsetElements = descriptor["offsetElements"] as? Int,
                      let shape = descriptor["shape"] as? [Int] else {
                    throw Fluid3DHarnessError.assertion("Malformed array descriptor in \(name)")
                }
                let shapeCount = shape.reduce(1, *)
                try require(shapeCount == count, "\(name)/\(fieldName) shape/count mismatch")
                try require(!reference.keys.contains(fieldName), "Duplicate \(fieldName) in \(name)")
                reference[fieldName] = try decodeLittleEndianDoubles(
                    payload, offsetElements: offsetElements, count: count
                )
            }
            let expectedFields: Set<String> = [
                "u_input", "v_input", "w_input", "dye_input",
                "u_advected", "v_advected", "w_advected", "dye_advected",
            ]
            try require(Set(reference.keys) == expectedFields, "\(name) array set changed: \(reference.keys)")
            for values in reference.values {
                try require(values.allSatisfy(\.isFinite), "\(name) CPU reference contains NaN or infinity")
            }

            let configuration = try FluidSimulation3DConfiguration.fixture(
                nx: nx, ny: ny, nz: nz, h: Float(h), dt: Float(dt)
            )
            let simulation = try FluidSimulation3D(metal: metal, configuration: configuration)
            // Each upload owns a blit encoder, so encode all four into one command buffer.
            let commandBuffer = metal.newCommandBuffer()
            try simulation.u.encodeUpload(reference["u_input"]!.map(Float.init),
                                          to: simulation.u.ping, command: commandBuffer)
            try simulation.v.encodeUpload(reference["v_input"]!.map(Float.init),
                                          to: simulation.v.ping, command: commandBuffer)
            try simulation.w.encodeUpload(reference["w_input"]!.map(Float.init),
                                          to: simulation.w.ping, command: commandBuffer)
            try simulation.dye.encodeUpload(reference["dye_input"]!.map(Float.init),
                                            to: simulation.dye.ping, command: commandBuffer)
            try simulation.encodeAdvection(command: commandBuffer)
            let uBuffer = try simulation.u.encodeReadback(from: simulation.u.ping, command: commandBuffer)
            let vBuffer = try simulation.v.encodeReadback(from: simulation.v.ping, command: commandBuffer)
            let wBuffer = try simulation.w.encodeReadback(from: simulation.w.ping, command: commandBuffer)
            let dyeBuffer = try simulation.dye.encodeReadback(from: simulation.dye.ping, command: commandBuffer)
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
            guard commandBuffer.status == .completed else {
                throw Fluid3DHarnessError.commandBuffer(
                    "\(name) advection command failed: \(String(describing: commandBuffer.error))"
                )
            }

            let actual: [String: [Float]] = [
                "u_advected": try simulation.u.decodeReadback(uBuffer),
                "v_advected": try simulation.v.decodeReadback(vBuffer),
                "w_advected": try simulation.w.decodeReadback(wBuffer),
                "dye_advected": try simulation.dye.decodeReadback(dyeBuffer),
            ]
            var caseMaximumError = 0.0
            for fieldName in ["u_advected", "v_advected", "w_advected", "dye_advected"] {
                let actualValues = actual[fieldName]!
                let referenceValues = reference[fieldName]!
                try require(actualValues.count == referenceValues.count,
                            "\(name)/\(fieldName) element count mismatch")
                for index in referenceValues.indices {
                    let actualValue = Double(actualValues[index])
                    let expectedValue = referenceValues[index]
                    try require(actualValue.isFinite && expectedValue.isFinite,
                                "\(name)/\(fieldName) nonfinite at x-fastest index \(index)")
                    let error = abs(actualValue - expectedValue)
                    let limit = absoluteTolerance + relativeTolerance * abs(expectedValue)
                    try require(error <= limit,
                                "\(name)/\(fieldName) mismatch at x-fastest index \(index): "
                                + "actual=\(actualValue) expected=\(expectedValue) error=\(error) limit=\(limit)")
                    caseMaximumError = max(caseMaximumError, error)
                    totalCompared += 1
                }
            }

            let wallFlux = try exactWallZeros(
                u: actual["u_advected"]!, v: actual["v_advected"]!, w: actual["w_advected"]!,
                nx: nx, ny: ny, nz: nz, label: name
            )
            let dye = actual["dye_advected"]!
            try require(dye.allSatisfy { $0 >= 0 && $0 <= 1 }, "\(name) dye escaped [0, 1]")
            if name == "zero_uniform" {
                try require(dye.allSatisfy { abs($0 - 0.375) <= 2e-6 },
                            "Zero-flow uniform dye decayed or changed")
            }
            if let expectedWall = fixture["maxWallNormalValue"] as? Double {
                try require(expectedWall == 0 && wallFlux == 0,
                            "\(name) normal wall faces are not exactly zero")
            }
            maximumAbsoluteError = max(maximumAbsoluteError, caseMaximumError)
            caseReports.append([
                "name": name,
                "grid": [nx, ny, nz],
                "comparedValues": actual.values.reduce(0) { $0 + $1.count },
                "maxAbsoluteError": caseMaximumError,
                "maxWallNormalValue": wallFlux,
                "dyeMinimum": dye.min() ?? 0,
                "dyeMaximum": dye.max() ?? 0,
                "finite": true,
            ])
        }
        totalCompared = caseReports.reduce(0) { $0 + (($1["comparedValues"] as? Int) ?? 0) }
        try require(totalCompared > 0, "No production advection values were compared")
        return [
            "passed": true,
            "fixture": "advection-boundaries",
            "device": device.name,
            "os": ProcessInfo.processInfo.operatingSystemVersionString,
            "contractHash": manifest["contractHash"]!,
            "cases": caseReports,
            "comparedValues": totalCompared,
            "maxAbsoluteError": maximumAbsoluteError,
            "absoluteTolerance": absoluteTolerance,
            "relativeTolerance": relativeTolerance,
            "finite": true,
        ]
    }

    private static func decodeLittleEndianDoubles(
        _ data: Data,
        offsetElements: Int,
        count: Int
    ) throws -> [Double] {
        let byteOffset = offsetElements.multipliedReportingOverflow(by: MemoryLayout<UInt64>.stride)
        let byteCount = count.multipliedReportingOverflow(by: MemoryLayout<UInt64>.stride)
        guard !byteOffset.overflow, !byteCount.overflow,
              byteOffset.partialValue >= 0,
              byteOffset.partialValue + byteCount.partialValue <= data.count else {
            throw Fluid3DHarnessError.assertion("CPU reference array exceeds its fixture payload")
        }
        return data.withUnsafeBytes { raw in
            (0..<count).map { index in
                let bits = UInt64(littleEndian: raw.loadUnaligned(
                    fromByteOffset: byteOffset.partialValue + index * MemoryLayout<UInt64>.stride,
                    as: UInt64.self
                ))
                return Double(bitPattern: bits)
            }
        }
    }

    private static func exactWallZeros(
        u: [Float], v: [Float], w: [Float], nx: Int, ny: Int, nz: Int, label: String
    ) throws -> Float {
        var maximum = Float.zero
        for z in 0..<nz {
            for y in 0..<ny {
                for x in [0, nx] {
                    let value = u[(z * ny + y) * (nx + 1) + x]
                    try require(value.isFinite && value == 0, "\(label) u wall face is not exactly zero")
                    maximum = max(maximum, abs(value))
                }
            }
        }
        for z in 0..<nz {
            for y in [0, ny] {
                for x in 0..<nx {
                    let value = v[(z * (ny + 1) + y) * nx + x]
                    try require(value.isFinite && value == 0, "\(label) v wall face is not exactly zero")
                    maximum = max(maximum, abs(value))
                }
            }
        }
        for z in [0, nz] {
            for y in 0..<ny {
                for x in 0..<nx {
                    let value = w[(z * ny + y) * nx + x]
                    try require(value.isFinite && value == 0, "\(label) w wall face is not exactly zero")
                    maximum = max(maximum, abs(value))
                }
            }
        }
        return maximum
    }

    private static func storageAndABI(device: MTLDevice, metal: MetalDevice) throws -> [String: Any] {
        let grid = try FluidSimulation3DConfiguration.fixture(nx: 8, ny: 7, nz: 6)
        let production = FluidSimulation3DConfiguration.production
        try require(production.nx == 64 && production.ny == 64 && production.nz == 64,
                    "Production 3D grid must remain fixed at 64 cubed")
        try expectConfigurationFailure(nx: 0, ny: 7, nz: 6, dt: 1.0 / 60.0)
        try expectConfigurationFailure(nx: 8, ny: 7, nz: 6, dt: .nan)
        try expectConfigurationFailure(nx: 8, ny: 7, nz: 6, h: Float.leastNonzeroMagnitude, dt: 1.0 / 60.0)
        try expectConfigurationFailure(nx: 8, ny: 7, nz: 6, h: .greatestFiniteMagnitude, dt: 1.0 / 60.0)
        try require(Fluid3DUniforms.abiIsValid, "Swift uniform ABI size, alignment, or offsets changed")
        try expectTextureAllocationFailure(grid: grid, metal: metal)

        let abiInput = Fluid3DUniforms(
            grid: SIMD4<UInt32>(8, 7, 6, 0x1020_3040),
            scale: SIMD4<Float>(0.125, 1.0 / 60.0, 8.0, 0.375),
            output: SIMD4<UInt32>(13, 11, 9, 0x5060_7080)
        )
        let abiResult = try gpuABIRoundTrip(abiInput, device: device, metal: metal)
        try require(abiResult == abiInput, "Swift/Metal 48-byte uniform round-trip changed a lane")

        let clearPipeline: MTLComputePipelineState
        do {
            clearPipeline = try metal.createComputePipeline(computeFunctionName: "fluid3DClear")
        } catch {
            throw Fluid3DHarnessError.library("Missing production clear pipeline fluid3DClear: \(error)")
        }
        try expectMissingPipelineFailure(metal)

        let expectedExtents: [VolumeField3D.Component: (Int, Int, Int)] = [
            .cell: (8, 7, 6),
            .u: (9, 7, 6),
            .v: (8, 8, 6),
            .w: (8, 7, 7),
        ]
        var comparedValues = 0
        var rowAlignments: [String: Int] = [:]
        for component in [VolumeField3D.Component.cell, .u, .v, .w] {
            let field = try VolumeField3D(grid: grid, component: component, metal: metal)
            let (width, height, depth) = expectedExtents[component]!
            try require(field.width == width && field.height == height && field.depth == depth,
                        "\(component.rawValue) extent mismatch: \(field.width)x\(field.height)x\(field.depth)")
            for (label, texture) in [("ping", field.ping), ("pong", field.pong)] {
                try require(texture.textureType == .type3D, "\(component.rawValue) \(label) is not a 3D texture")
                try require(texture.pixelFormat == .r32Float, "\(component.rawValue) \(label) is not r32Float")
                try require(texture.storageMode == .private, "\(component.rawValue) \(label) is not private storage")
                try require(texture.width == width && texture.height == height && texture.depth == depth,
                            "\(component.rawValue) \(label) Metal extent mismatch")
                try require(texture.usage.contains(.shaderRead) && texture.usage.contains(.shaderWrite),
                            "\(component.rawValue) \(label) usage must allow shader read/write")
            }
            let originalPing = field.ping
            let originalPong = field.pong
            field.swap()
            try require(field.ping === originalPong && field.pong === originalPing,
                        "\(component.rawValue) ping/pong swap did not exchange generations")
            field.swap()
            try require(field.ping === originalPing && field.pong === originalPong,
                        "\(component.rawValue) ping/pong swap did not restore generations")
            let layout = field.stagingLayout
            let requiredAlignment = max(4, device.minimumLinearTextureAlignment(for: .r32Float))
            try require(layout.bytesPerRow >= width * MemoryLayout<Float>.stride,
                        "\(component.rawValue) staging row is shorter than its pixels")
            try require(layout.bytesPerRow % requiredAlignment == 0,
                        "\(component.rawValue) row stride ignores device alignment \(requiredAlignment)")
            try require(layout.bytesPerImage == layout.bytesPerRow * height,
                        "\(component.rawValue) image stride omits the padded row stride")
            try require(layout.totalBytes == layout.bytesPerImage * depth,
                        "\(component.rawValue) staging allocation omits a depth plane")
            rowAlignments[component.rawValue] = layout.bytesPerRow

            let ramp = makeIndexRamp(width: width, height: height, depth: depth, component: component)
            let readbacks = try roundTrip(field: field, values: ramp, metal: metal)
            try compareExactly(readbacks.ping, ramp, label: "\(component.rawValue) ping all-plane ramp")
            try compareExactly(readbacks.pong, ramp, label: "\(component.rawValue) pong all-plane ramp")
            comparedValues += ramp.count * 2

            let cleared = try clearAndRead(field: field, pipeline: clearPipeline, metal: metal)
            try require(cleared.ping.allSatisfy { $0 == 0 } && cleared.pong.allSatisfy { $0 == 0 },
                        "\(component.rawValue) clear must cover every ping/pong voxel")
            comparedValues += cleared.ping.count + cleared.pong.count
        }

        return [
            "passed": true,
            "fixture": "storage-abi",
            "device": device.name,
            "os": ProcessInfo.processInfo.operatingSystemVersionString,
            "grid": [grid.nx, grid.ny, grid.nz],
            "productionGrid": [production.nx, production.ny, production.nz],
            "uniformStride": MemoryLayout<Fluid3DUniforms>.stride,
            "uniformAlignment": MemoryLayout<Fluid3DUniforms>.alignment,
            "uniformOffsets": [
                MemoryLayout<Fluid3DUniforms>.offset(of: \.grid)!,
                MemoryLayout<Fluid3DUniforms>.offset(of: \.scale)!,
                MemoryLayout<Fluid3DUniforms>.offset(of: \.output)!,
            ],
            "stagingBytesPerRow": rowAlignments,
            "exactComparedValues": comparedValues,
            "finite": true,
        ]
    }

    private static func gpuABIRoundTrip(
        _ input: Fluid3DUniforms,
        device: MTLDevice,
        metal: MetalDevice
    ) throws -> Fluid3DUniforms {
        var sourceValue = input
        let length = MemoryLayout<Fluid3DUniforms>.stride
        guard let source = device.makeBuffer(
            bytes: &sourceValue, length: length, options: .storageModeShared
        ), let destination = device.makeBuffer(length: length, options: .storageModeShared) else {
            throw Fluid3DHarnessError.library("Unable to allocate 48-byte ABI fixture buffers")
        }
        let pipeline: MTLComputePipelineState
        do {
            pipeline = try metal.createComputePipeline(computeFunctionName: "fluid3DABIRoundTrip")
        } catch {
            throw Fluid3DHarnessError.library("Missing production ABI pipeline fluid3DABIRoundTrip: \(error)")
        }
        try command(metal) { buffer in
            guard let encoder = buffer.makeComputeCommandEncoder() else {
                throw Fluid3DHarnessError.library("Unable to create ABI round-trip encoder")
            }
            encoder.setComputePipelineState(pipeline)
            encoder.setBuffer(source, offset: 0, index: 0)
            encoder.setBuffer(destination, offset: 0, index: 1)
            encoder.dispatchThreads(
                MTLSize(width: 1, height: 1, depth: 1),
                threadsPerThreadgroup: Fluid3DDispatch.threadsPerThreadgroup(for: pipeline)
            )
            encoder.endEncoding()
        }
        return destination.contents().assumingMemoryBound(to: Fluid3DUniforms.self).pointee
    }

    private static func expectMissingPipelineFailure(_ metal: MetalDevice) throws {
        do {
            _ = try metal.createComputePipeline(computeFunctionName: "fluid3DIntentionallyMissingFixture")
            throw Fluid3DHarnessError.assertion("Missing shader function silently created a pipeline")
        } catch let MetalDeviceError.failedToCreateFunction(name) {
            try require(name == "fluid3DIntentionallyMissingFixture",
                        "Missing pipeline error lost its function name: \(name)")
        }
    }

    private static func expectConfigurationFailure(
        nx: Int,
        ny: Int,
        nz: Int,
        h: Float = 1,
        dt: Float
    ) throws {
        do {
            _ = try FluidSimulation3DConfiguration.fixture(nx: nx, ny: ny, nz: nz, h: h, dt: dt)
            throw Fluid3DHarnessError.assertion("Invalid 3D grid/timestep configuration was accepted")
        } catch FluidSimulation3DError.invalidConfiguration {
            return
        }
    }

    private static func expectTextureAllocationFailure(
        grid: FluidSimulation3DConfiguration,
        metal: MetalDevice
    ) throws {
        do {
            _ = try VolumeField3D(
                grid: grid,
                component: .cell,
                metal: metal,
                textureFactory: { _ in nil }
            )
            throw Fluid3DHarnessError.assertion("Failed 3D allocation was replaced by a fallback field")
        } catch VolumeField3DError.textureAllocationFailed(let resource) {
            try require(resource.contains("cell"), "Allocation error lost its field name: \(resource)")
        }
    }

    private static func roundTrip(
        field: VolumeField3D,
        values: [Float],
        metal: MetalDevice
    ) throws -> (ping: [Float], pong: [Float]) {
        var pingReadback: MTLBuffer!
        var pongReadback: MTLBuffer!
        try command(metal) { commandBuffer in
            try field.encodeUpload(values, to: field.ping, command: commandBuffer)
            let blit = try field.makeBlitEncoder(command: commandBuffer, operation: "ping-to-pong fixture copy")
            blit.copy(from: field.ping, to: field.pong)
            blit.endEncoding()
            pingReadback = try field.encodeReadback(from: field.ping, command: commandBuffer)
            pongReadback = try field.encodeReadback(from: field.pong, command: commandBuffer)
        }
        return (try field.decodeReadback(pingReadback), try field.decodeReadback(pongReadback))
    }

    private static func clearAndRead(
        field: VolumeField3D,
        pipeline: MTLComputePipelineState,
        metal: MetalDevice
    ) throws -> (ping: [Float], pong: [Float]) {
        var pingReadback: MTLBuffer!
        var pongReadback: MTLBuffer!
        try command(metal) { commandBuffer in
            try field.encodeClear(command: commandBuffer, pipeline: pipeline)
            pingReadback = try field.encodeReadback(from: field.ping, command: commandBuffer)
            pongReadback = try field.encodeReadback(from: field.pong, command: commandBuffer)
        }
        return (try field.decodeReadback(pingReadback), try field.decodeReadback(pongReadback))
    }

    private static func makeIndexRamp(
        width: Int,
        height: Int,
        depth: Int,
        component: VolumeField3D.Component
    ) -> [Float] {
        var values: [Float] = []
        values.reserveCapacity(width * height * depth)
        let componentOffset = Float([.cell, .u, .v, .w].firstIndex(of: component)! * 100_000)
        for z in 0..<depth {
            for y in 0..<height {
                for x in 0..<width {
                    values.append(componentOffset + Float(x + 100 * y + 10_000 * z))
                }
            }
        }
        return values
    }

    private static func compareExactly(_ actual: [Float], _ expected: [Float], label: String) throws {
        try require(actual.count == expected.count, "\(label) element count mismatch")
        for index in expected.indices {
            try require(actual[index].isFinite && actual[index] == expected[index],
                        "\(label) mismatch at x-fastest index \(index): \(actual[index]) vs \(expected[index])")
        }
    }

    private static func emit(_ result: [String: Any]) throws {
        let data = try JSONSerialization.data(withJSONObject: result, options: [.sortedKeys])
        guard let text = String(data: data, encoding: .utf8) else {
            throw Fluid3DHarnessError.assertion("Could not encode fixture result JSON")
        }
        print("FLUID3D_RESULT=\(text)")
    }
}
