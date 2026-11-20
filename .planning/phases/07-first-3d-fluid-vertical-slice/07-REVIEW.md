---
phase: 07-first-3d-fluid-vertical-slice
reviewed: 2026-11-20T19:45:00Z
depth: standard
files_reviewed: 23
files_reviewed_list:
  - docs/3d-numerical-contract.md
  - Sources/iOS/RenderViewController.swift
  - Sources/macOS/RenderViewController.swift
  - Sources/Shared/ExperimentRecipes3D.swift
  - Sources/Shared/FieldVisualization3D.swift
  - Sources/Shared/FluidSimulation3D.swift
  - Sources/Shared/PressureProjection3D.swift
  - Sources/Shared/Renderer.swift
  - Sources/Shared/Shaders3D.metal
  - Sources/Shared/SimulationState.swift
  - Sources/Shared/SimulationTypes3D.swift
  - Sources/Shared/VolumeField3D.swift
  - Tests/Integration/fluid3d_float32_pcg_diagnostic.swift
  - Tests/Integration/fluid3d_pressure_precision_diagnostic.py
  - Tests/Integration/fluid3d_reference.swift
  - Tests/Integration/test_educational_release.py
  - Tests/Integration/test_fluid3d_reference.py
  - Tests/Integration/test_fluid3d.py
  - Tests/Integration/test_fluid3d.swift
  - Tests/Integration/test_renderer_correctness.py
  - Tests/UI/iOS/HUDUITests.swift
  - Tests/UI/macOS/HUDUITests.swift
  - Tests/Unit/SimulationStateTests.swift
findings:
  critical: 0
  warning: 5
  info: 12
  total: 17
  necessity: 2
status: issues_found
---

# Phase 7: Code Review Report

**Reviewed:** 2026-11-20T19:45:00Z
**Depth:** standard
**Files Reviewed:** 23
**Status:** issues_found

## Summary

I reviewed the current master state of the 3D vertical slice. That includes the Phase 8 inspection work and the 2026-11-20 solver changes: the indirect-dispatch iteration gate, the pressure warm start, the fused PCG passes and two-deep frame pipelining. No structural (fallow) findings were supplied. I read `necessity-review.md` and applied it.

I traced the solver and renderer by hand rather than relying on the passing tests:
- The PCG state-lane routing across the fused kernels and their finalize operations.
- The gate and indirect-dispatch argument layout.
- Warm-start initialisation against the failure latch.
- The compensated `pressureAdd` error-free transforms.
- Reflection and fold logic in `sampleLattice`.
- The step, restore and swap ordering in `FluidSimulation3D`.
- The semaphore, mailbox and generation bookkeeping in `Renderer`, including every early-return path after `semaphore.wait`.

I found no provable correctness, data-loss or security defect in the shipped GPU or renderer logic. Specifically:
- The lane routing is consistent (lane 6 is shared by the dot and next-rho reads, lane 8 by the direction mean).
- All fused kernels are bounds-checked against partial threadgroups.
- The failure latch is read after the step's finalize pass.
- Every `semaphore.wait` path is matched by a commit or a signal.

The real problems are drift and maintainability:
- The preregistered numerical contract no longer describes the production solver.
- The production advection kernels are not the ones the oracle tests exercise.
- Several branches and files are dead or redundant after the fusion work.
- A few cross-language constants are duplicated with no ABI check.

## Warnings

### WR-01: Numerical contract still states a zero initial guess; production warm-starts and uses extra stop criteria not in the contract

**File:** `docs/3d-numerical-contract.md:54` (also `Sources/Shared/FluidSimulation3D.swift:25-28,134-140`, `Sources/Shared/PressureProjection3D.swift:964-979`, `Sources/Shared/Shaders3D.metal:770-774,836-864,976`)
**Issue:**
- The contract says "`q=0` as the initial guess". The immutable preregistered prefix is hash-pinned, and the appended amendments (precision, identity/storage rounding) only cover the compensated pressure storage.
- The production step has since been changed to warm-start PCG from the previous step's normalised pressure (`hasStepPressure`, `fluid3DInitializePCGFieldsWarm`).
- It also gates PCG on an internal stop target `min(1e-5·h²/dt, 1e-6)` and on a 0.1× recursive-residual margin before spending a true-residual check. Neither appears in the contract.
- The contract header ("no kernel was run", "q=0") and the verification docs therefore describe an algorithm that is not what ships.
- Per-step acceptance gates are unchanged, but only step 1 is compared elementwise to the independent oracle (`resetAndFinite`, `test_fluid3d.swift:4577-4581`). Steps 2-600 are checked only against the residual and divergence gates. That is sufficient for the stated gates, but it means the warm-start path has no independent-reference equivalence evidence and no recorded amendment.

**Fix:** Append a dated "Approved solver-performance amendment" after the `END PREREGISTERED CONTRACT` marker. It should record:
- that steps after the first warm-start from the retained zero-mean `qHigh+qLow`;
- the internal stop target and the 0.1× check margin;
- the indirect-gate semantics;
- that the acceptance gates and the 320 cap are unchanged.

Do not edit the pinned prefix. Add a test that runs N steps from a seeded state with and without warm start and compares the projected velocity within the Float32 tolerance policy.

### WR-02: Production advection kernels (`*Guarded`) are not the code the advection and full-volume oracle tests run

**File:** `Sources/Shared/Shaders3D.metal:497-541` vs `1488-1523`; `Sources/Shared/FluidSimulation3D.swift:195-264`; `Tests/Integration/test_fluid3d.swift:4469,6098`
**Issue:**
- `encodeAdvection`, `fluid3DAdvectVelocity` and `fluid3DAdvectDye` have no caller in `Sources/`; only `test_fluid3d.swift:4469` and `:6098` use them.
- The app's `encodeStep` instead runs the near-duplicate `fluid3DAdvectVelocityGuarded` and `fluid3DAdvectDyeGuarded`.
- The "full-volume unequal-axis transport" and asymmetric-advection oracle comparisons therefore validate a test-only path. The production kernels get only the single-step reference comparison on one asymmetric fixture, plus acceptance-gate soak runs.
- A future edit to one copy (RK2 clamping, offsets, dye clamp) would silently diverge from the other with no failing test.

**Fix:** Make one implementation authoritative. Either:
- drive the oracle fixtures through `encodeStep` (or a test hook that runs only the guarded transport with the latch at 0), or
- delete the unguarded kernels and `encodeAdvection`, and have the guarded kernels share a single `inline` sampling body.

### WR-03: Hidden `gatingIteration` mode flag leaves unreachable gated branches in `PressureProjection3D` after the fusion

**File:** `Sources/Shared/PressureProjection3D.swift:207,472-481,751-756,1250-1264,1286-1293`; loop at `1022-1100`
**Issue:**
- After the fused rewrite, the PCG loop calls only `encodeFusedPartial`, `encodeFusedFinal`, `encodePCGTrace` and three `encodeStateKernel` calls, all with `cellExtent`.
- `encodePartialReduction` and `encodeFinalReduction` are reached only via `encodeReduction`, `encodeDotReduction` and `encodeWallFluxReduction`. Those are never called while `gatingIteration == true`, so their `if gatingIteration { … }` branches, including the `groupCount == cellReductionGroupCount` guard, are dead.
- The `.single` branch of `gatedKind` via `encodeStateKernel` is likewise unreachable.
- A mutable instance flag that silently changes dispatch mode in four helpers is a regression hazard. A future call to `encodeReduction` inside the loop would take an untested path.

**Fix:** Remove the dead gated branches in `encodePartialReduction`, `encodeFinalReduction` and `gatedKind`. Replace the `gatingIteration` flag with an explicit parameter (or a distinct `encodeGated…` API) so the compiler enforces which helpers are gate-aware.

### WR-04: Spatial reference export subprocess depends on the working directory

**File:** `Tests/Integration/test_fluid3d.py:1936-1953`
**Issue:**
- For `SPATIAL_FIXTURES` the harness runs `python -m unittest Tests.Integration.test_inspection3d_reference` using a repo-relative module path.
- That `subprocess.run` passes no `cwd=ROOT`, unlike every other subprocess in the file (`_capture`, `run_benchmark`).
- Run from any directory other than the repo root, it fails with an import error that is reported as "CPU reference export failed", obscuring the cause.

**Fix:** Pass `cwd=ROOT` (and `env` with `PYTHONPATH=ROOT` if the namespace package is relied on) at line 1951.

### WR-05: Necessity (already-defended-elsewhere): `DepthAttachmentRetention` duplicates Metal's default retained references

**File:** `Sources/Shared/FieldVisualization3D.swift:36-42,409-414`
**Category:** necessity
**Issue:**
- The comment says the completed-handler retention keeps the depth attachment alive "when a resize replaces the cached attachment while this command remains in flight".
- All command buffers come from `MetalDevice.newCommandBuffer()`, which is `commandQueue.makeCommandBuffer()` (`Sources/Shared/MetalDevice.swift:82`).
- That call creates a retained-references buffer: every resource bound to an encoder is retained until the command completes.
- No call to `makeCommandBufferWithUnretainedReferences` exists anywhere in `Sources/` or `Tests/` (searched), so the guarded state cannot occur.
- The helper class, the extra completed handler and the per-frame allocation are redundant.

**Fix:** Delete `DepthAttachmentRetention` and the completed handler. Record the invariant ("command buffers are retained-reference") in the `depthAttachment(width:height:)` doc comment. If unretained buffers are ever adopted, add the retention back then.

## Info

### IN-01: Necessity (impossible-state guard): `modeTransitionInProgress` is never observable as `true`

**File:** `Sources/macOS/RenderViewController.swift:106,420-429,1009-1021,1026-1036,1050-1061,1070-1073`
**Category:** necessity
**Issue:**
- The flag is set and cleared inside one synchronous main-thread call (`changeMode` 1011-1019, `restart` 1029-1035).
- `renderer.selectMode` and `restartCurrentSimulation` block with `waitUntilCompleted` and never spin the run loop, so no event handler, menu validation or redraw can run while it is true.
- The disabled-controls state set by the interleaved `refreshTransport()` is reverted before AppKit can draw it.
- This rests on judgement about AppKit re-entrancy rather than a proof, hence Info.

**Fix:** Drop the flag and its checks, or move the mode change off the main thread if the disabled state is meant to be user-visible.

### IN-02: Write-only scratch store in the fused preconditioner-dot pass

**File:** `Sources/Shared/PressureProjection3D.swift:1077-1080`; `Sources/Shared/Shaders3D.metal:1300-1327`
**Issue:**
- `fluid3DPCGProjectPreconditionerDot` is bound to `searchDirection.pong` as `initialDirection` and writes the projected value every iteration.
- `searchDirection.pong` is never read anywhere in `PressureProjection3D.swift`; the real search direction lives in `.ping`.
- This is a leftover from sharing the kernel with the initial-direction setup. It costs a full-grid write per iteration and misleads readers about data flow.

**Fix:** Split a variant without the `initialDirection` output, or bind a dedicated scratch texture with a comment.

### IN-03: Test-only and unused production API ships in the app

**File:** `Sources/Shared/FieldVisualization3D.swift:175-251` with `Sources/Shared/Shaders3D.metal:57-111`; `Sources/Shared/SimulationState.swift:40-42`
**Issue:**
- `encodeSlice`, the legacy `pipeline`/`vertices`/`indices`, `fluid3DVertex`/`fluid3DFixedSlice` and `fluid3DSampleCentralXY` are used only by the test harness (`test_fluid3d.swift:363,3875,4061`).
- `fluid3DSampleCentralXY` and `fluid3DSampleSpatial` are the same trilinear code, and the palette mapping is duplicated in both fragment shaders.
- `SimulationMode.macModes` and the `allCases` compatibility list have no callers since iOS moved to `twoDimensionalModes`.

**Fix:** Share one sampler and one palette function in Metal. Move test-only presentation into the test target or mark it clearly. Delete `macModes` and `allCases` if no consumer remains.

### IN-04: Cross-language constants duplicated with no ABI or consistency check

**File:** `Sources/Shared/Shaders3D.metal:331,439,763,1004,1021,1468-1470` vs `PressureProjection3D.swift:41`, `TracerSystem3D.swift:40`, `SimulationTypes3D.swift:179`, `Renderer.swift:423-427,749-753`
**Issue:**
- The 320 iteration/restart cap is hard-coded in Metal twice, against Swift `maximumIterations`.
- The tracer count 512 is hard-coded three times in Metal against `TracerSystem3D.count`.
- The state lane count 19 is hard-coded in `fluid3DInitializeSolverState`, against `Fluid3DPCGState.laneCount`.
- The 1e-5/2e-5 acceptance thresholds appear in the shader's finalize kernel and again in two Swift re-checks in `Renderer`. The Swift copies in `Renderer` omit the shader's 1000× reduction gate and are duplicated verbatim between `transitionTo3D` and `stepCompletionFailure`.
- `abiIsValid` verifies Swift-side layout only. Changing a constant on one side silently stops trace capture, or silently clamps tracer work.

**Fix:** Pass these as uniforms/function constants, or add a round-trip ABI kernel and test that asserts Metal's values equal Swift's. Factor the Swift acceptance predicate into one helper on `Fluid3DProjectionDiagnostics`.

### IN-05: File-scope `#pragma clang fp` changes numerics for every kernel below it

**File:** `Sources/Shared/Shaders3D.metal:689-690`
**Issue:**
- `reassociate(off)` and `contract(off)` are applied without a push/pop.
- They affect all ~1000 lines that follow (all fused PCG, reductions, gauge normalisation, guarded advection), not just `pressureAdd`, and are silent about it.
- Reordering kernels in the file changes optimisation behaviour and could break the "fused partials are bit-identical to separate passes" claim.

**Fix:** Scope the pragma to the compensated helpers if that is the intent, or document that the remainder of the file is deliberately compiled this way.

### IN-06: Silent early returns followed by presenting an unrendered drawable

**File:** `Sources/Shared/Renderer.swift:556`; `Sources/Shared/FieldVisualization3D.swift:292`
**Issue:**
- `render` returns when `spatialViewport` is nil, and `encodeInspection` returns when the viewport has zero width or height. Neither encodes a render pass.
- `draw(in:)` treats this as success and calls `command.present(currentDrawable)` on a drawable that was never rendered to, so its contents are undefined.
- It is a rare layout-transient state, but the failure mode is a garbage frame rather than a skipped one.

**Fix:** Have `render` return a Bool (or throw a dedicated "deferred" case) and skip `present` when nothing was encoded.

### IN-07: `restartCurrentSimulation` hard-codes the 3D mode

**File:** `Sources/Shared/Renderer.swift:237`
**Issue:**
- It calls `transitionTo3D(.dyeAdvection3D, intent: .restart)` instead of `state.mode`.
- The published `requestedMode` and any failure alert are therefore wrong the moment a second 3D mode exists. Only one exists today, so there is no current misbehaviour.

**Fix:** Use `state.mode`.

### IN-08: `StatusSlot.diagnostics()` can trap, or map a NaN failure code to `.none`, on a corrupt status buffer

**File:** `Sources/Shared/PressureProjection3D.swift:88-110`
**Issue:**
- It runs on the Metal completion thread on every step, reading GPU-written shared memory.
- `Int(max(0, state.control.x.rounded()))` and the `options.w` equivalent trap for ±inf or values above `Int.max`.
- `max(0, NaN)` returns 0 in Swift, so a NaN `control.y` decodes as `Fluid3DProjectionFailure.none`. The Renderer's `converged` check currently catches that downstream, but the decoder itself is unsound.
- It is not reachable from today's kernels (the lanes are only incremented), so this is a robustness rather than a correctness defect.

**Fix:** Decode through a helper that returns a distinct `.finalAcceptanceFailed`/"malformed status" when a lane is non-finite or out of range.

### IN-09: Stale CPU "replay" diagnostic and misleading test text

**File:** `Tests/Integration/fluid3d_float32_pcg_diagnostic.swift:1-2`; `Tests/Integration/test_fluid3d.swift:5256-5302`
**Issue:**
- The file claims to replay "the production Float32 PCG arithmetic". Production now uses compensated hi/lo pressure, a fused pass structure, a gate and an optional warm start. The replay uses plain Float32 `q`, a zero guess and an unfused sequence, so its GPU-vs-CPU trace comparison cannot be expected to match.
- It runs only under `FLUID3D_TRACE=1`, asserts nothing, and is included in the evidence source hash inventory.
- At `test_fluid3d.swift:5256` the failure message still refers to "Padded dispatches", a design that no longer exists.
- The body of the `if` at `:5258-5302` is not indented.

**Fix:** Update the diagnostic to the compensated/fused arithmetic, or relabel it as a historical single-Float32 analysis and remove it from the hashed inventory. Fix the message and indentation.

### IN-10: Hand-maintained Swift source lists and an evidence invariant that no longer matches the live pipeline

**File:** `Tests/Integration/test_renderer_correctness.py:30-35`, `Tests/Integration/test_educational_release.py:24-29`, `Tests/Integration/test_fluid3d.py:29-51,204`; `Sources/Shared/Renderer.swift:131`
**Issue:**
- Four harnesses each carry their own list of `Sources/Shared/*.swift` files. Adding or renaming a Shared file means editing all of them, and the failure surfaces as an opaque `swiftc` error.
- `validate_benchmark_manifest` requires `inFlightLimit == 3` and the Phase 7 verification doc says "three-command in-flight limit". The renderer now pipelines running 3D frames two deep. The benchmark remains a valid solver baseline but no longer represents the live submission policy.

**Fix:** Derive the source list once (a shared helper, or a glob over `Sources/Shared` minus platform files). Note the production two-deep policy in the verification doc, or add a two-deep benchmark mode.

### IN-11: Weak or fragile test assertions

**File:** `Tests/Integration/test_fluid3d.py:1614-1629`; `Tests/UI/macOS/HUDUITests.swift:927`
**Issue:**
- The "read-only solver status" check only matches literal-index writes (`state\[\d+\]…=`). A write such as `state[uniforms.grid.y] = …` or `state[lane]` is invisible to it.
- The `device const float4 *state` requirement already makes any write a Metal compile error, so the regex adds no protection.
- The macOS UI test asserts `hiddenAfterRestart == hiddenPixels`, comparing cyan-pixel counts across different plane, depth and camera states. It passes only because both are 0, and would fail for a legitimate colour-boundary pixel.

**Fix:** Drop the redundant regex, or parse the kernel body properly. Compare the hidden-tracer count to 0 explicitly.

### IN-12: Minor lifecycle and debug artefacts

**File:** `Sources/macOS/RenderViewController.swift:183`; `Sources/iOS/RenderViewController.swift:385`
**Issue:**
- `viewDidAppear` calls `addObserver(self, selector: #selector(canvasBecameMain), …)` on every appearance without removal, so repeated appearances stack duplicate registrations. The handler is idempotent via `panelConfigured`, so this is harmless but wasteful.
- `didReceiveMemoryWarning` still contains `print("Got Memory Warning")`, a pre-existing debug artefact in a changed file.

**Fix:** Register the observer once (in `viewDidLoad`, or guard with a flag), and remove the `print` or route it through `os_log`.

---

_Reviewed: 2026-11-20T19:45:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
