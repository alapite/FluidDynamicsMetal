# Phase 7 — Source-Grounded Pattern Map

Mapped 2026-11-06 inline from live source. This is implementation guidance, not execution evidence. Historical `.planning/codebase/` paths, compiler settings and renderer ownership are superseded by `AGENTS.md` and current source.

## Evolution, Storage and ABI

| Planned artifact | Role / flow | Closest analog | Reuse / difference |
|---|---|---|---|
| `SimulationTypes3D.swift` | Immutable grid/configuration and Swift/Metal uniform contract | `SimulationTypes.swift` | Separate 16-byte lanes; do not change `StaticData` / `BufferData` |
| `VolumeField3D.swift` | Private cell/face textures, staging and generation swaps | `Slab.swift` | Float32 scalar 3D extents differ per velocity component; old RG16F/depth-1 helpers do not apply |
| `FluidSimulation3D.swift` | Reset → self-advection → compatible projection → dye advection | `FluidSimulation.swift` | Caller serializes mutation; no drawable/time source; throwing construction rather than force unwrap/silent pipeline failure |
| `PressureProjection3D.swift` | Matrix-free closed-box MAC projection and diagnostics | `FluidSimulation.swift` pressure section | New D/G/A and PCG, not the existing 40-Jacobi loop |
| `Shaders3D.metal` | Compute sampling, operators, reductions and slice rendering | `Shaders.metal` | Separate names prefixed `fluid3D`; old entry points and 2D pass order unchanged |
| `ExperimentRecipes3D.swift` | Deterministic initial curl/compact dye seed | `ExperimentRecipes.swift` | Genuine depth variation; initialization only, never reevaluate prescribed velocity each step |

Current encoder shape (`Sources/Shared/FluidSimulation.swift`):

```swift
@MainActor
final class FluidSimulation {
    func encodeReset(command: MTLCommandBuffer, mode: SimulationMode, adjustment: ExperimentAdjustment?)
    func encodeStep(command: MTLCommandBuffer, tuning: SimulationTuning, contacts: [FluidContact] = [],
                    radius: Float? = nil, mode: SimulationMode = .freePlay,
                    adjustment: ExperimentAdjustment? = nil, step: Int)
}
```

Signatures above omit bodies. New encoders follow the ownership boundary, not the old numerical discretization. Use the injected instance and its explicit library (`MetalDevice.swift:123–138`):

```swift
let pipeline = try metal.createComputePipeline(computeFunctionName: name)
```

Do not call the class factory, which selects the singleton, or `ComputeShader`'s printing-only error path.

## State and Renderer Integration

`SimulationState.swift:34–39` currently defines only `.freePlay` and `.experiment(ExperimentID)`; `experiment == nil` therefore accidentally means Free Play in several consumers. Add explicit `isLesson`, `is3D`, fixed-grid/capability checks and platform lists before connecting the new mode. Keep `ExperimentID` for the three existing 2D lessons.

Current scheduling (`Renderer.swift:48–64,131–149`):

```swift
func requestSingleStep() {
    guard state.requestSingleStep() else { return }
    scheduleStepDrain()
}
// Evolution is independent of currentDrawable:
if state.consumeStep() {
    simulation.encodeStep(command: command, tuning: state.tuning, contacts: contacts,
                          radius: touchRadius, mode: state.mode, adjustment: state.adjustment, step: step)
}
if let drawable = view.currentDrawable {
    render(command: command, drawable: drawable, view: view)
    command.present(drawable)
}
```

Preserve nil-drawable advances, queued steps and inactivity cancellation. For 3D, establish eligibility before encoding and consume only after successful encoding. Resource transition commits must wait for successful reset, unlike today's optimistic `selectMode` mutation. Balance every acquired semaphore slot, including failures. Use a transition-generation token to ignore stale completion notifications. Compact completion status inspection is not permission for synchronous full-field readback in live frames.

## Fixed-Slice Presentation

`FieldVisualization.swift:48–70` uses a `.clear` render pass, black background, explicit viewport/scissor and a read-only field texture. `FieldVisualization3D.swift` uses the same destination/viewport ownership but its own pipeline/geometry and central-Z sampling. It must not instantiate or mutate the 2D simulation just to get a quad. Y orientation differs from old texture coordinates and needs an asymmetric fixture.

## Native Mac / iOS

`Sources/macOS/RenderViewController.swift:251–260` pins the experiment selector, transport and step label outside the body scroll. `updateControlLayout()` targets 368 pt, not the constructor's 248 pt. Preserve the movable `NSPanel` and panel reopening behavior.

The following **must not** be copied after inserting heading rows:

```swift
changeMode(SimulationMode.allCases[sender.indexOfSelectedItem])
changeMode(SimulationMode.allCases[sender.tag])
```

Use explicit mode identity for each selectable item in both menus. Nonactionable headers/separators have no mode. Preserve Command-1–4. `stateDidChange` currently calls only `refreshTransport()`; committed mode/fallback transitions also require full `refreshControls()`/menu refresh, without rebuilding the whole panel at 10 Hz.

`Sources/iOS/RenderViewController.swift:284` must enumerate an explicit 2D-only mode list. No AppKit imports in shared sources and no new mobile 3D entry.

## Tests and Build Wiring

| Planned / modified artifact | Analog / important dependency |
|---|---|
| `test_fluid3d_reference.py`, `fluid3d_reference.swift` | Python unittest driver + independent CPU Double math; no Metal imports or calls; quick asymmetric grids and opt-in/exported full-grid reference work |
| `test_fluid3d.py`, `test_fluid3d.swift` | `test_educational_release.py` / `.swift`: compile actual production sources, find fresh app `default.metallib` using build settings, injected `MetalDevice`, validation-on correctness, structured local artifacts |
| `SimulationStateTests.swift` | Test actual Foundation state directly; exact integer transitions and preference restoration |
| `Tests/UI/macOS/HUDUITests.swift` | Stable accessibility identifiers, canvas/focused-control Space routing, screenshot attachments, menu shortcuts |
| `Tests/UI/iOS/HUDUITests.swift` | Preserve existing mobile lesson/gesture layout; assert new mode is absent |
| `project.pbxproj` | Explicit PBXFileReference / PBXBuildFile / Sources entries; shared Swift in both apps and relevant state-test dependencies, Metal in both app libraries |
| Existing Python renderer consumers | `test_educational_release.py:24–26` and `test_renderer_correctness.py:30–32` enumerate production Swift sources and must include new renderer dependencies |
| `docs/3d-numerical-contract.md`, `docs/3d-phase7-verification.md` | Preregister references separately from actual measured outcomes; preserve historical release report |

The old GPU helpers assume depth 1 and RG16F. New fixture transfers require checked row/image strides, all volume planes, and float32 readback. Missing compiler/device/metallib must fail visibly, never create a fake passing 3D fixture.

## Dependency / Scope Notes

Numerical contract/reference feasibility precedes kernels; storage/advection precede projection; verified evolution precedes slice/seed calibration and renderer integration; committed renderer mode precedes native selection/fallback UI; complete implementation precedes timing and final human review. These are real data/source dependencies, not opportunities to parallelize edits to `Shaders3D.metal` or `project.pbxproj`.

No new scene framework, package, camera, user-visible tracers, speed controls, volume rendering or Phase 10 fps gate belongs in Phase 7.
