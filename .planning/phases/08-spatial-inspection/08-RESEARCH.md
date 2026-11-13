# Phase 8: Spatial Inspection - Research

**Researched:** 2026-11-13
**Domain:** Native AppKit inspection, Metal spatial rendering, deterministic MAC-grid tracers
**Confidence:** HIGH for inspected integration points; MEDIUM for proposed rendering/interaction parameters pending implementation and visual validation
**Execution:** Research performed inline; no independent research agent ran.

<user_constraints>
## User Constraints (from CONTEXT.md)

The following decisions, discretion and deferred scope are copied verbatim from `08-CONTEXT.md`. [VERIFIED: 08-CONTEXT.md]

### Camera feel and recovery
- **D-01:** Open the 3D lesson with a **slightly angled, modest three-quarter view**, making the slice's spatial placement apparent while retaining a readable dye pattern. This deliberately extends Phase 7's face-on-only presentation; it does not change the initial fluid state or central XY slice.
- **D-02:** **Plain canvas drag orbits around the fixed volume centre; mouse wheel/two-finger scroll zooms.** No modifier is required. Do not add camera panning. Route these interactions only to 3D inspection; established 2D input remains intact.
- **D-03:** Use an **upright orbit**: horizontal circulation, bounded vertical tilt, and no roll or upside-down tumbling. Bound zoom to keep the camera outside the volume and provide useful recovery. Exact angles, sensitivities, distance limits and projection are planning/visual-validation choices.
- **D-04:** **Reset Camera** restores only the initial slightly angled orientation and fitted zoom. It does not reset the selected slice plane, depth, tracer visibility, playback intent, step count or numerical state. Keep this distinct from restarting the experiment and from Centre Slice.

### Spatial orientation cues
- **D-05:** Draw a **thin, subdued wireframe cube** around the simulation volume, with the selected slice positioned inside it. No solid walls or floor grid. Phase 7's no-canvas-guides restriction was scoped to its fixed face-on slice and is superseded here for the cube and axis guide only.
- **D-06:** Place a **small noninteractive X/Y/Z orientation guide in a canvas corner**, rotating consistently with the camera. Keep the active plane and depth-axis description in the controls panel. Do not replace the guide with labels scattered over the cube.
- **D-07:** Render the selected dye plane **from both sides**, with geometrically consistent world orientation. It remains a fixed plane in space, never a camera-facing billboard. Becoming thin when viewed edge-on is acceptable; do not secretly reorient it or move the camera to compensate.
- **D-08:** The cube and axis guide are **always visible and subdued** in this 3D inspection presentation. Do not add a Guides toggle. Keep them subordinate to the dye and markers.

### Slice selection and depth
- **D-09:** Use **native XY/XZ/YZ segmented buttons**, a **continuous depth slider**, and an **axis-labelled percentage readout**, e.g. `Z depth: 50%` for XY. Do not expose raw grid indices. Initial entry retains the existing central XY section at 50%.
- **D-10:** Maintain **one shared depth percentage across plane changes**. XY at 30% through Z becomes XZ at 30% through Y, or YZ at 30% through X. Do not remember separate values for each plane or reset depth on every plane change.
- **D-11:** A plane or depth change **preserves the camera**. Do not automatically face the newly selected plane. Inspection updates must display while paused without consuming a solver or tracer step.
- **D-12:** Provide a labelled native **Centre Slice** action that sets only depth to **50%**. Preserve the selected plane, camera, tracer visibility and all experiment state.

### Tracer appearance and defaults
- **D-13:** Seed a **sparse, deterministic, repeatable set of passive markers throughout the whole volume**, rather than clustering them only around the initial dye. Their purpose is to reveal the flow even where there is little dye; they neither deposit concentration nor exert force.
- **D-14:** Tracers are **visible on initial entry**, with one native **Show Tracers** checkbox. Visibility affects drawing only: marker positions continue evolving on every logical simulation step while hidden, and re-showing them reveals the correct equal-step positions without reseeding or catch-up work.
- **D-15:** Use **small, sparse pale-cyan dots** that contrast with the existing amber/cream dye. No trails, velocity arrows or speed-colour scale. Exact count, dot size and cyan value remain visual/performance-validation choices; do not turn them into new user-facing quality settings.
- **D-16:** Use **depth occlusion by the opaque slice sheet**: where the plane covers a marker behind it, that marker is hidden; orbiting can reveal it. The slice remains an opaque cut sheet even in low-concentration black regions. Do not use X-ray markers, dim through-plane markers or equal-brightness always-on-top drawing. This is the slice/tracer policy; Phase 10 must separately define compositing with a transparent volume.

### Carried-forward state, controls and scope
- **D-17:** Extend the current separate native **Simulation Controls** panel, not a new floating in-canvas HUD. Keep the established grouped experiment selector, transport and step count, concentration legend, factual 3D note and amber dye palette. Present the new inspection controls only where supported; retain the 2D controls and input behaviour on return.
- **D-18:** **Restart preserves camera, slice plane, shared depth percentage and tracer visibility**, while returning paused to step 0 and resetting all evolution-dependent fluid/tracer state and pending input/steps. Initial visibility/defaults do not override retained choices during Restart. Recheck this extension now; complete speed-choice and repeatability acceptance remains Phase 9 work.
- **D-19:** Keep camera/inspection state separate from numerical evolution. Moving the camera or slice, toggling tracers, resetting the camera, centring the slice or resizing must not reseed, change the 64³ grid, consume logical steps, or alter complete fluid/tracer state at equal step counts. Tracer advancement must depend on logical steps, never drawable availability, render frequency or visibility.
- **D-20:** Native inspection controls, including camera operation, need **labels and keyboard access**; gestures are an additional route, not the only route. Preserve normal control focus/activation and existing Space transport behaviour; S remains a no-op in dye-only 3D. Freehand fluid injection remains disabled. Control interaction must not orbit/zoom, and camera gestures must not activate transport or controls.
- **D-21:** Preserve both app builds and applicable existing 2D/state/HUD/GPU regressions. The Phase 7 numerical contract, solver acceptance and fixed production resolution are not relaxed by this presentation work. Phase 7's unperformed manual visual/accessibility/interaction review remains pending, actual macOS 26 runtime and physical-device multitouch remain NOT TESTED, and displayed frame pacing remains NOT MEASURED; this discussion supplies no new verification evidence.

### Agent's Discretion / Research and Planning Responsibilities

The user chose a concrete option for all sixteen substantive questions; none of those preferences is delegated away. Research/planning selects the exact initial camera pose, projection, bounded orbit/zoom mapping, keyboard-accessible native camera controls and their increments, native panel grouping/layout, focus/event routing, corner-guide position and styling, marker count/size, deterministic spatial distribution, integration/interpolation and wall handling, render/depth-resource design, and inspection-state representation. Do not ask the user to choose numerical algorithms or Swift/Metal architecture.

Define consistent world/texture/screen conventions for every plane and camera direction, including increasing-depth direction, endpoint sampling and the percentage mapping. Preserve the contracted central XY sample at world Z=0.5 (equal interpolation of cell planes 31 and 32). Use asymmetric fixtures to establish axis/position correctness; do not infer correctness from a symmetric blob. Tracers must sample the same production three-component velocity field with a documented logical-step relationship and no feedback to the fluid. Define predetermined tolerances and readback coverage for complete fluid and tracer state under presentation variations, not screenshot-only comparisons. Keep new resources and failure paths compatible with transactional 3D entry/restart and usable 2D recovery.

The brief factual note may be updated to explain movable cross-sections, dye leaving the plane, passive markers and opaque-sheet occlusion. Do not add the Phase 9 prediction/speed lesson or imply that steps are physical seconds. Choose remaining nonessential presentation details consistently with the current Mac app; do not add persistence or extra inspection capabilities merely to resolve incidental choices.

### Deferred Ideas

None — discussion stayed within phase scope. Existing boundaries remain: Phase 9 owns speed-comparison teaching and full restart-repeatability/completion qualification; Phase 10 owns volume rendering, volume/tracer compositing and final measured performance. Mobile 3D, freehand injection, additional fields, trails, arbitrary oblique/multiple slices, higher resolutions and cinematic rendering remain outside this phase.

Phase 7's six user-facing requirements remain pending manual acceptance; this context does not reopen or claim to complete their review. Actual macOS 26 runtime and physical mobile multitouch remain NOT TESTED until exercised. Displayed frame pacing remains NOT MEASURED.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Requirement | Research support |
|---|---|---|
| INS-01 | Orbit, zoom and reset camera with orientation cues | Bounded camera value state; shared transform for sheet/cube/guide; paused redraw and keyboard controls |
| INS-02 | Movable XY/XZ/YZ dye section | Explicit plane-to-world mapping and cell-centred sampling, endpoint and asymmetric fixtures |
| INS-03 | Independently visible passive 3D tracers evolving while hidden | Deterministic volume seeding, forward RK2 of production MAC velocity, step-path scheduling and GPU guards |
| INS-04 | Presentation variations preserve equal-step simulated state | Complete resource inventory, paired runs, byte-preserving paused draws and tolerance-based equal-step readback |
| CTRL-08 | Labelled native keyboard controls and gesture isolation | Existing AppKit panel/responder patterns, canvas hit routing, native focus and negative input fixtures |

Descriptions are summarized from `.planning/REQUIREMENTS.md`; ownership remains Phase 8 only. [VERIFIED: .planning/REQUIREMENTS.md]
</phase_requirements>

## Summary

The baseline has a genuine evolving 64³ solver and a read-only fixed central XY renderer, not a camera or 3D tracer implementation. `FieldVisualization3D` supplies clip-space 2D vertices and no depth attachment; the new work is spatial geometry, transforms and depth-correct composition. Keep the numerical ABI and existing solver passes unchanged. [VERIFIED: Sources/Shared/FieldVisualization3D.swift; Sources/Shared/SimulationTypes3D.swift; Sources/Shared/FluidSimulation3D.swift]

`Renderer.draw(in:)` already encodes a logical solver step before acquiring a drawable and calls `consumeStep()` only after successful encoding. `transitionTo3D` constructs candidate resources and validates reset before committing the mode, with generation-fenced diagnostics and 2D recovery. Preserve these patterns when introducing tracers and depth resources. [VERIFIED: Sources/Shared/Renderer.swift:225-292,369-426]

**Primary recommendation (design proposal):** Introduce pure 3D inspection/camera values, a separate session-owned `TracerSystem3D`, and a depth-equipped `FieldVisualization3D`. Advance tracers immediately after a successful solver-step encoding, using that step's newly projected velocity and GPU status guard, independently of visibility/drawables. Validate a thin camera-plus-slice end-to-end path before adding tracers and broader presentation variations. Exact UI layout/copy and visual constants must be captured in the missing `08-UI-SPEC.md` before executable planning.

## Project Constraints (from AGENTS.md)

- Keep app/shared sources under `Sources/{macOS,iOS,Shared}` and tests under `Tests/Unit`, `Tests/UI/{macOS,iOS}`, `Tests/Integration`; align Xcode membership and project-relative settings. Shared sources compile directly into both app targets, not a package. [VERIFIED: AGENTS.md]
- Keep Swift 6 language mode, Swift 6.2+/Xcode 26+ tooling and minimum macOS/iOS 26, Apple Silicon Mac; do not introduce deployment/version overrides. Use exact schemes `FluidDynamicsMetalOSX` and `FluidDynamicsMetaliOS`. [VERIFIED: AGENTS.md]
- Preserve existing 2D shader entry names and Swift `StaticData` / Metal `BufferData` layout. Use separate inspection uniforms with asserted alignment/stride and round-trip tests. [VERIFIED: AGENTS.md; Sources/Shared/SimulationTypes3D.swift]
- Preserve fixed production 64³, logical steps, existing state/HUD/integration checks, both app builds and platform-specific manual coverage. Actual macOS 26 runtime and physical multitouch cannot be inferred from this host. [VERIFIED: AGENTS.md; 08-CONTEXT.md D-19/D-21]
- No local `.agents/` or `.opencode/` skill directory was found during this research; global native Mac/context7 guidance was used. [VERIFIED: directory discovery in this session]

## Standard Stack

| Component | Baseline / observed tool version | Purpose |
|---|---|---|
| Swift / simd | Swift 6 language mode; active Swift 6.4.2 | Value state, camera matrices, shared Swift/Metal layout |
| AppKit | macOS 26 deployment; active macOS 27.0 host | Existing panel, segmented control, continuous sliders, checkbox/buttons, accessibility and focus |
| Metal / MetalKit | Active Xcode 27.2 (27B52); Metal compiler 32023.922 | Existing compute solver, new read-only spatial render/depth pass and tracer compute |
| XCTest / Python unittest | Existing Xcode targets and Python wrappers | State/HUD assertions and production-metallib fixtures |

Baseline constraints are repository-verified; active versions were verified with `xcodebuild -version`, `xcrun swift --version`, `xcrun metal --version`, `sw_vers -productVersion`. These commands do not prove an app build, GPU test or runtime acceptance. [VERIFIED: AGENTS.md; tool output 2026-11-13]

**Installation:** No new library, scene engine, package manager, asset registry or downloaded font is recommended. Retain the existing AppKit/Metal stack. This is an architectural recommendation, not a claim that other engines are unavailable.

## Architecture Patterns

### 1. Pure inspection state, independent evolution resources

**Design proposal:** Add a compact `InspectionState3D` value (plane, one normalized depth, camera yaw/pitch/zoom, show-tracers). Keep it separate from `DisplayOptions` (2D arrows/particles/trails), `ExperimentAdjustment`, solver grid and tracer positions. Mutators validate finite values, clamp depth/tilt/zoom, wrap yaw and request presentation refresh only. Test Reset Camera, Centre Slice and Restart as three distinct operations.

Initial entry uses defaults; Restart preserves all inspection choices and resets fluid/tracers/pending work. Avoid resetting defaults indirectly through `candidateState.selectMode(mode)` on Restart: that method is currently also used for initial entry. Extend the transaction explicitly so these routes stay distinguishable. Existing state setters reject 2D field/overlay changes in 3D; do not revive them for tracers. [VERIFIED: Sources/Shared/SimulationState.swift:151-226; Sources/Shared/Renderer.swift:137-138,225-292]

**Suggested files, not committed implementation:** `Sources/Shared/InspectionState3D.swift`, `Sources/Shared/Camera3D.swift`, `Sources/Shared/TracerSystem3D.swift`, existing state/renderer/visualization/shaders; optional `Sources/macOS/OrientationGuide3DView.swift`. Update `FluidDynamicsMetal.xcodeproj/project.pbxproj` and every standalone Swift compilation list affected by new Renderer/state dependencies. Lists exist in `test_fluid3d.py`, `test_renderer_correctness.py`, and `test_educational_release.py`. [VERIFIED: Tests/Integration/*.py source-list searches]

### 2. Freeze world-to-sheet-to-screen conventions before kernels

The numerical domain is `[0,1]³`: X right, Y up, Z into the volume in the front XY reference view; dye is cell-centred and x-fastest. The current fixed slice clamps `world*extent-0.5`, giving equal cell planes 31/32 at depth 0.5. [VERIFIED: docs/3d-numerical-contract.md; Sources/Shared/Shaders3D.metal:37-64]

**Recommended mapping (design proposal):** For sheet-local `(s,t)` in `[0,1]²` and depth `d`, use the following world coordinates. Changing camera never changes this mapping.

| Plane | World position | Sheet horizontal / vertical | Depth axis / positive direction |
|---|---|---|---|
| XY | `(s,t,d)` | +X / +Y | +Z, into the front reference volume |
| XZ | `(s,d,t)` | +X / +Z | +Y, upward in world space |
| YZ | `(d,t,s)` | +Z / +Y | +X, rightward in world space |

Use continuous `d=percentage/100`, bounded `[0,1]`, not `round(d*63)` or a slice index. Sample concentration at `clamp(world*dimensions-0.5,0,dimensions-1)`. Thus endpoints extend the nearest centre plane, while 50% interpolates 31/32 on the depth axis. A backside view is naturally mirrored by the camera; do not independently flip UVs or billboard the sheet. Cull no face of the sheet. These are proposed extensions of the verified midpoint convention and require asymmetric fixtures before acceptance.

### 3. Upright orbit and a shared transform

**Design proposal:** Centre at `(0.5,0.5,0.5)`; start from a camera on the negative-Z side, modest positive yaw and elevation. A useful initial candidate is yaw 25°, elevation 18°, perspective vertical FOV 40°, elevation bounded ±75°, no roll/pan. Validate framing rather than treating these numbers as user-locked or measured. Build a left-handed view basis with forward toward the centre, right `normalize(cross(worldUp,forward))`, up `cross(forward,right)`; map clip depth to Metal's `[0,1]` convention. Keep the matrix convention explicit (column-vector `projection * view * world`) and validate signed axis directions using CPU projections and GPU image landmarks.

Fit the cube's bounding sphere (`sqrt(3)/2`) against the narrower viewport half-angle with a margin, then store a bounded relative zoom. Enforce an absolute camera distance greater than the bounding radius plus the near clip distance; use a positive near plane and far plane enclosing the cube at maximum zoom-out. Reset Camera recomputes fitted zoom for the current viewport but alters no slice/evolution state. Choose final sensitivities, margins and min/max zoom in UI-SPEC/planning, with narrow/tall/Retina fixtures. This fitting derivation is a recommendation requiring tests, not observed visual evidence.

One transform must drive dye sheet, cube and markers. The corner guide uses the rotational part, not camera translation/zoom; a small noninteractive AppKit overlay can draw the projected axes and native X/Y/Z labels without adding a Metal font atlas. Its hit-testing must pass through to the canvas and it must never obscure panel controls. Let UI-SPEC settle corner, bounds and styling.

### 4. Opaque sheet depth, not draw-order tricks

Metal provides `MTLDepthStencilDescriptor`, depth compare/write state, pipeline depth-attachment format, and render-pass depth clear. Apple's documentation describes `.less` as a common compare operation and clear depth defaults to 1.0. [CITED: https://developer.apple.com/documentation/metal/mtldepthstencildescriptor; https://developer.apple.com/documentation/metal/mtlrenderpipelinedescriptor/depthattachmentpixelformat; https://developer.apple.com/documentation/metal/mtlrenderpassdepthattachmentdescriptor/cleardepth]

**Design proposal:** Use `.depth32Float`, matching output dimensions/sample count, clear depth 1, sheet depth test/write enabled, `.lessEqual` for the declared coplanar policy, culling `.none`, opaque alpha 1 even for black concentration. Draw markers with depth test enabled against that attachment; use small instanced camera-facing disc quads whose transparent outside fragments discard and do not write depth. Do not compare normalized depth to world Z. Guides remain independently visible/subdued; decide cube back-edge treatment in the design contract rather than deriving it from tracer occlusion.

Current `MetalDevice.createRenderPipeline` and `RenderPipelineKey` have no depth-format argument/key. Either build dedicated throwing 3D pipelines locally or extend the helper with a default `.invalid` depth format included in the key, preserving 2D call behavior. Never reuse a depth-less pipeline by an incomplete cache key. Allocate depth resources with checked failure paths; resize replaces only presentation attachments, never the simulation or tracer seed. [VERIFIED: Sources/Shared/MetalDevice.swift:16-20,85-120; Sources/Shared/FieldVisualization3D.swift]

### 5. Tracers: forward RK2, new projected velocity, no feedback

The production shader already reconstructs each of u/v/w on its own staggered lattice with reflected boundary parity through `sampleVelocity`. Dye advection samples the newly projected velocity; `FluidSimulation3D.encodeStep` swaps its generations before returning, so its current `u.ping/v.ping/w.ping` are the new generation. [VERIFIED: Sources/Shared/Shaders3D.metal:130-208; Sources/Shared/FluidSimulation3D.swift:110-135]

**Design proposal:** Give `TracerSystem3D` a deterministic fixed-count buffer of aligned `float4` / `SIMD4<Float>` positions, fourth lane initialized to a fixed value, no trails or mutable random generator. Start with 512 evenly stratified cell-centre seeds on an 8×8×8 lattice `(i+0.5,j+0.5,k+0.5)/8`; validate sparsity visually before fixing count in UI-SPEC. This evenly covers the full volume without concentration dependence. Keep the count a compile-time internal choice, not a user quality setting.

For logical advance `n→n+1`, after the solver has produced projected velocity `V[n+1]`, advance each marker with forward midpoint RK2: `m=clamp(p+dt/2*V[n+1](p),0,1)`, `pNext=clamp(p+dt*V[n+1](m),0,1)`, using the production MAC sampling helper. Use the same `dt=1/60`. Do not use the backtrace sign used by semi-Lagrangian dye sampling. Clamping, reflection parity and forward direction require explicit wall/edge/corner and ±axis fixtures; do not respawn markers at walls.

Encode reset/advance through throwing methods, before `consumeStep()` and outside the drawable/visibility branches. Feed the solver's returned status buffer to the tracer kernel so a failed or prior-session-failed projection does not advance markers. `StatusSlot.buffer` is currently `fileprivate`: add a narrow encoder-binding method or scoped internal read-only accessor rather than assuming cross-file access already exists. Bind status read-only; do not mutate solver diagnostics or fields. All encoding failures must unwind through existing session recovery. Extend `Renderer3DSessionFactory` with tracer construction/reset fault-injection hooks and validate candidates before publishing a 3D session. Failed restart restores usable 2D, just as current failed restart does. [VERIFIED: Sources/Shared/Renderer.swift:5-24,225-292,369-426; Sources/Shared/PressureProjection3D.swift:46-60]

`ParticleSystem` provides reset/advance/display separation but is only float2 with packed 2D velocity and trail history; it cannot supply 3D positions or MAC sampling unchanged. Do not copy its fatal-error allocation policy into transactional 3D entry. [VERIFIED: Sources/Shared/ParticleSystem.swift]

### 6. Native panel, focus and exclusive input routing

Current mouse forwarding is behind `shouldAdvance`; a 3D camera branch must run before that guard so inspection works paused. Current controller has no scroll-zoom handler. AppKit supplies responder `scrollWheel(with:)`, `scrollingDeltaY`, precise-delta detection and first-responder queries; default scroll handling forwards to the next responder. [VERIFIED: Sources/macOS/RenderViewController.swift:771-807; CITED: https://developer.apple.com/documentation/appkit/nsresponder/scrollwheel(with:); https://developer.apple.com/documentation/appkit/nsevent; https://developer.apple.com/documentation/appkit/nswindow/firstresponder]

**Design proposal:** Begin camera drags only for events originating on the canvas window and inside its interactive region; track that ownership through drag/up, clear on deactivation/mode switch, and never convert panel coordinates into camera actions. Scope scroll interception to the canvas, not the panel's scrolling body. Normalize wheel and precise trackpad deltas, reject nonfinite input and bound zoom. Preserve existing 2D injection guards and pointer continuity on return.

Use native segmented plane controls, a continuous 0–100 depth slider with axis-labelled percentage, Show Tracers, Centre Slice and Reset Camera. Provide labelled native camera alternatives (e.g. horizontal orbit/elevation/zoom sliders) with keyboard increments; gestures alone do not satisfy CTRL-08. Final labels, order, increments and accessibility IDs belong in UI-SPEC. Existing local keyboard monitoring gives focused controls first chance and special-cases button Space; extend its regression tests rather than swallowing arrow/Space events globally. [VERIFIED: Sources/macOS/RenderViewController.swift:115-129; 08-CONTEXT.md D-09/D-20]

### 7. Complete-state preservation needs broader evidence

Existing `scanSimulation` reads both generations of diagnostic textures, including transported velocity and pressure scratch. It stages and finite-checks the reduction workspace but **does not return its values in the compared dictionary**. The other `encodeSimulationSnapshot`/hash helper does include workspace bytes and supplied status lanes. The simulation's private failure latch is not exposed by either inventory, and there are no tracer buffers yet. A passing old `requireMatchingFields` assertion therefore cannot alone establish Phase 8 complete-resource preservation. [VERIFIED: Tests/Integration/test_fluid3d.swift:886-895,1477-1531,2196-2233; Sources/Shared/FluidSimulation3D.swift:14-24,59-63]

**Design proposal:** Add a scoped read-only diagnostic inventory for simulation/session latches and tracer buffers; snapshot all diagnostic texture generations, pressure high/low and scratch, workspace, retained status, failure latches, tracer positions/any scratch, fixed configuration, generation roles and logical counters. Record byte counts and names so missing resources fail. Use queue-ordered GPU readback; do not read private memory directly or hold a CPU copy as proof of GPU state.

For paused presentation-only batches require byte-for-byte unchanged evolution resources, status/latches and step counters before/after, with positive image changes for camera/slice operations. For separately reset equal-step runs, retain the existing absolute `2e-6` field tolerance, finite-first checks and exact discrete state/wall zeros; recommend `2e-6` absolute world-coordinate tracer tolerance on the same device. Compare steps 0/1/24/48 under visible, hidden, alternating visibility, nil drawable and changing render-count/viewport conditions. Freeze these tolerances and inventory in a new inspection contract before collecting outputs; do not modify the immutable Phase 7 contract prefix or relax its projection gates. This is a proposed acceptance protocol, not passing evidence.

## Don't Hand-Roll

| Problem | Use | Avoid |
|---|---|---|
| Occlusion | Metal depth attachment/state with common view projection | Z sorting, dimming or X-ray overlays |
| Three-component velocity interpolation | Production `sampleVelocity` helper with independent CPU oracle | Packed 2D texture lookup or prescribed swirl |
| Native control behavior | AppKit buttons, segmented controls, sliders and responder focus | Custom pixel-drawn panel widgets/global key swallowing |
| Solver and step accounting | Existing `FluidSimulation3D` and renderer transaction/scheduler | New solver path inside the visualization or per-render tracer updates |
| Labels on corner axes | Native text drawing in a hit-transparent guide if chosen | New font/scene-engine dependency |

These are architecture recommendations grounded in the inspected stack, not claims of measured implementation success.

## Common Pitfalls

1. **Changing a slice index instead of a world depth:** breaks 31/32 midpoint and depth endpoints. Verify affine asymmetric volumes at 0/30/50/100%, all three planes and both sides. [VERIFIED: existing midpoint sampler; recommended test extension]
2. **A second Y/Z flip or right-handed matrix pasted into a left-handed world:** can make one view plausible while XZ/YZ or the guide disagrees. Use labelled asymmetric landmarks and CPU-projected positions, not the symmetric lesson blob. [VERIFIED: numerical-contract axes; design risk]
3. **Transparent black sheet regions:** black concentration still writes opaque color/depth, so behind-sheet dots must disappear there too. [VERIFIED: 08-CONTEXT.md D-16]
4. **CPU-generation swaps confused with GPU timing:** bind the actual new velocity textures and immutable per-submission uniforms/status. Three commands can be in flight; do not overwrite a shared CPU-visible camera/tracer uniform block still in use. [VERIFIED: Renderer semaphore/completion path; FluidSimulation3D.encodeStep; design risk]
5. **Reset overwrites inspection defaults:** initial selection and Restart currently share the 3D transition method. Add explicit retention tests. [VERIFIED: Renderer.restartCurrentSimulation/transitionTo3D]
6. **A test executable stops compiling after adding a shared file:** standalone Python drivers enumerate source files manually, independently of Xcode. Update all three lists and evidence inventories. [VERIFIED: integration source-list searches]
7. **New render path breaks historical evidence semantics:** Phase 7 benchmark schema explicitly says `solverAndFixedSlice`, centered square, no tracers. Retain an explicit legacy fixture configuration or version new evidence separately; do not silently relabel spatial/tracer work as that old measured workload. Historical evidence hashes become stale after implementation changes and must not be presented as fresh Phase 8 results. [VERIFIED: Tests/Integration/test_fluid3d.py validate_benchmark_manifest; docs/3d-phase7-verification.md]

## Code Examples

These existing call shapes are verified patterns, not implementation instructions to copy without the surrounding guards:

```swift
// Sources/Shared/Renderer.swift:383-399 — successful encoding precedes step consumption.
threeDStatus = try simulation3D.encodeStep(command: command)
// New tracer encoding belongs here, including status guard, before consumeStep.
guard state.consumeStep() else { /* existing session failure path */ return }
```

```swift
// Sources/Shared/FieldVisualization3D.swift:130-131 — presentation reads production dye.
encoder.setVertexBuffer(vertices, offset: 0, index: 0)
encoder.setFragmentTexture(simulation.dye.ping, index: 0)
```

```swift
// Apple Metal depth-state API; proposed configuration, not a tested render pass.
let descriptor = MTLDepthStencilDescriptor()
descriptor.depthCompareFunction = .lessEqual
descriptor.isDepthWriteEnabled = true
```

[VERIFIED: cited source snippets; CITED: https://developer.apple.com/documentation/metal/mtldepthstencildescriptor]

## Validation Architecture

### Test infrastructure and feedback

| Property | Value |
|---|---|
| Framework | Existing XCTest state/HUD targets plus Python unittest compiling Swift against production metallib |
| Config | `FluidDynamicsMetal.xcodeproj/xcshareddata/xcschemes/FluidDynamicsMetalOSX.xcscheme`; integration drivers enumerate sources |
| Existing quick command | `python3 -m unittest Tests.Integration.test_fluid3d.Fluid3DTests.test_evidence_schema Tests.Integration.test_fluid3d.Fluid3DTests.test_volume_kernels_read_only_solver_status` |
| Focused state command | `xcodebuild test -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetalOSX -configuration Debug -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO -only-testing:FluidDynamicsMetalStateTests` |
| Full suite | Both app builds, full Mac state/HUD tests, `python3 -m unittest discover -s Tests/Integration`, applicable iPhone/iPad HUD regressions |

Commands and test names above exist in the current repository. Quick checks do **not** cover new inspection behavior yet. Xcode/GPU execution latency is not measured in this research; the historical full integration run took 572 s, so do not promise the full suite in 30 s. [VERIFIED: Tests/Integration/test_fluid3d.py; scheme; docs/3d-phase7-verification.md]

### Requirement-to-test map (proposed additions)

| ID | Required assertions | Location / type | Executable entry point to add |
|---|---|---|---|
| INS-01 | Camera bounds, fit, reset-only semantics, guide/cube alignment, paused orbit/zoom | State/CPU math + Mac HUD + production image fixture | `Fluid3DTests.test_spatial_slices` and new state/HUD cases |
| INS-02 | XY/XZ/YZ mapping, shared percentage, 31/32 midpoint, endpoints, two-sided sheet | Production GPU + independent asymmetric reference | `Fluid3DTests.test_spatial_slices` |
| INS-03 | Deterministic full-volume seeds, ±XYZ/combined RK2, wall handling, no feedback, hidden advancement | Production tracer kernel + independent CPU reference | `Fluid3DTests.test_tracer_evolution` |
| INS-04 | Full inventory, no-op presentation, equal-step variants, nil drawable, restart retention/fault recovery | Production renderer/GPU readback + state tests | `Fluid3DTests.test_inspection_independence` |
| CTRL-08 | Native keyboard control coverage, focus/Space, panel scroll/drag exclusion, 2D input preservation | Mac HUD + production state/contact assertions | New `HUDUITests` cases, `SimulationStateTests` and renderer fixtures |

Proposed methods are **MISSING**, not runnable acceptance commands yet. Planner must schedule their implementation alongside production behavior, register their fixture selectors in Swift/Python and add their files to compilation/evidence inventories.

### Preregistered checks recommended before implementation acceptance

- **Slices:** scalar `C=0.1+0.2*x+0.3*y+0.4*z` with additional unequal landmarks; independently compute expected trilinear concentrations. Use `2e-5 + 2e-4*abs(reference)` field tolerance and existing ±1 UNORM-code palette tolerance, reject nonfinite values first. Sample away from raster edges; include front/back and orthogonal camera fixtures. [VERIFIED: numerical contract tolerances; existing assertRGB; proposed fixture]
- **Occlusion:** place known cyan markers on both sides of a sheet, in black and dyed regions, plus outside its footprint. Check front-visible/back-hidden, reversed visibility after opposite-side orbit, and visibility outside the sheet; edge-on must not trigger billboard reorientation. [VERIFIED: D-07/D-16; proposed fixture]
- **Tracers:** independent Double forward-RK2 reference, ±axis/unequal combined fields, staggered affine sampling, walls/edges/corners and at least 48 production logical steps. Use existing GPU-vs-oracle formula above; separate same-device equal-step tolerance `2e-6`. Exact seeds/count/lane values must agree after reset; no dye deposit or velocity change when tracing. [VERIFIED: existing sampler and tolerances; proposed coverage]
- **State:** compare complete buffers/textures/status/latches as described above, including nil drawable and paused redraws. Reject inventory mismatch rather than passing only u/v/w/dye. [VERIFIED: discovered inventory gap; proposed extension]
- **Native:** keyboard-only traverse and operate every new action, control-focused Space once, canvas Space once, S no-op, panel scrolling without camera change, canvas drag/scroll without fluid injection/transport. Automated identifiers do not substitute for actual VoiceOver/readability evaluation. [VERIFIED: D-20; current keyboard monitor; proposed tests]

### Sampling rate and Wave 0 gaps

Run focused checks after each meaningful task; after each wave build affected targets and run the relevant production fixtures; run the complete regression matrix before phase verification. Write failing behavioral tests before implementation and add fast camera/state fixtures early. No three consecutive tasks should lack automated feedback. This is a proposed execution policy, not a report of tests performed.

- Missing pure inspection/camera tests and state representation.
- Missing multi-axis spatial render, depth-occlusion, tracer and complete-state production fixtures/independent expected data.
- Missing native keyboard/gesture-isolation coverage and injected tracer/depth-allocation failures.
- Missing `08-UI-SPEC.md`; manual plan-phase UI gate must stop before planner dispatch until it exists or the operator explicitly reruns with `--skip-ui`.
- Preserve existing numerical feasibility/projection/finite tests; do not use a screenshot in their place.

## Security Domain

Security enforcement defaults enabled because `.planning/config.json` does not disable it. This phase's identified surfaces are local native events, numerical uniforms and GPU allocations; the scoped requirements add no network endpoint, authentication/session store, imported file or cryptographic protocol. This is a scope assessment, not a whole-application security audit. [VERIFIED: .planning/config.json; 08-CONTEXT.md; inspected implementation]

**Applicable control families:** input validation and resource handling apply; web authentication, session management, authorization and cryptographic controls are not introduced by this scoped feature. Do not apply obsolete ASVS version-specific control IDs to a native app without selecting a standard version. Each later PLAN must include a threat-model block under the workflow's default enforcement. [VERIFIED: plan-phase.md §5.55; design recommendation]

| Threat candidate | Mitigation to plan | Verification |
|---|---|---|
| Nonfinite/unbounded depth or camera data causes invalid matrices/GPU work | Finite checks, bounded values, positive viewport/depth extents | NaN/Inf and boundary state/math tests |
| Resize churn or unchecked allocation makes 3D unusable | Reuse bounded presentation attachments; checked allocations; transaction/fallback | Repeated resize + injected depth/tracer/pipeline failures |
| Cross-window event routing mutates experiment or camera | Explicit canvas ownership; native focus first; no injection in 3D | Negative gesture/focus tests and full-state comparisons |
| Stale/in-flight uniforms or status corrupt later sessions | Per-submission constants, GPU guards, generation fencing, drained transitions | Three queued steps/faults and stale-completion fixtures |

Threats above are design risks requiring implementation checks, not confirmed exploitable defects or completed mitigations.

## Environment Availability

| Dependency | Observed availability | Limit |
|---|---|---|
| Xcode / Swift | Xcode 27.2 / Swift 6.4.2 available | No build performed during research |
| Metal toolchain | Compiler 32023.922 available | Production GPU fixtures still must execute after implementation |
| Host | macOS 27.0 arm64 tool target | Does not verify macOS 26 runtime behavior |
| GSD named agents | Init reports `agents_installed: false` | Inline researcher/planner/checker permitted by runtime policy |
| Repowise index | Missing | Direct file reads/search used; optional user command `repowise init --yes` |

[VERIFIED: environment/version/init/Repowise tool output 2026-11-13]

## State of the Art and Superseded Guidance

Phase 7's fixed face-on/no-guides wording was a delivery boundary, not a permanent architectural restriction. Phase 8 D-01/D-05/D-06 explicitly supersede those presentation restrictions only; midpoint, amber palette, solver, native panel, transactional recovery and coverage honesty remain binding. Existing historical benchmark/manual checklist wording must remain attributable to Phase 7 rather than being rewritten as if it described new observations. [VERIFIED: 08-CONTEXT.md; 07-UI-SPEC.md; docs/3d-phase7-verification.md]

## Assumptions Log

No external factual claim is intentionally left as `[ASSUMED]`. Source-backed observations are distinguished from **design proposals**, which remain subject to the UI design contract, executable planning and implementation verification. No new user numerical-method decision is needed; the context delegates those technical choices to research/planning. Visual constants and usability are not yet validated.

## Open Questions / Planning Risks

1. **UI contract missing:** stop at the manual UI gate after saving research/validation. Next command is `/gsd-ui-phase 8`, then `/gsd-plan-phase 8` to reuse this research. Do not synthesize an approved UI-SPEC as an unrequested side effect.
2. **Visual constants:** final camera limits/sensitivities, guide styling, cube back edges, marker count/size/cyan and keyboard increments need explicit design-contract values and later visual checks. Research supplies candidates, not passing observations.
3. **Performance:** historical solver/slice timings are not 30-fps evidence; the heavy baseline makes a small tracer kernel preferable, but no frame-rate estimate is justified here. Preserve numerical gates and leave integrated measured qualification to Phase 10. [VERIFIED: docs/3d-phase7-verification.md]
4. **Coverage debt:** Phase 7 manual review, macOS 26 runtime, physical multitouch and displayed pacing retain their recorded pending/NOT TESTED/NOT MEASURED status. This research closes none of them. [VERIFIED: .planning/REQUIREMENTS.md; docs/3d-phase7-verification.md]

## Sources

### Primary — HIGH confidence for inspected facts

- `08-CONTEXT.md`, `.planning/{REQUIREMENTS,STATE,PROJECT,ROADMAP}.md`, `AGENTS.md` — scope, decisions, requirements and constraints.
- `docs/3d-numerical-contract.md` — coordinates, interpolation, step order, ABI, tolerances and approved amendments.
- `Sources/Shared/{FieldVisualization3D,FluidSimulation3D,SimulationTypes3D,SimulationState,Renderer,MetalDevice,ParticleSystem,PressureProjection3D}.swift`, `Sources/Shared/Shaders3D.metal` — current integration and resource behavior.
- `Sources/macOS/RenderViewController.swift` — native panel, focus, event and lifecycle routes.
- `Tests/Integration/{test_fluid3d.py,test_fluid3d.swift,test_renderer_correctness.py,test_educational_release.py}`, `Tests/Unit/SimulationStateTests.swift`, Mac shared Xcode scheme — existing fixtures/source membership and comparison gaps.
- `.planning/phases/07-first-3d-fluid-vertical-slice/{07-CONTEXT,07-UI-SPEC}.md`, `docs/3d-phase7-verification.md`, `README.md` — inherited UI and historical evidence, not new runtime results.
- Context7 `/websites/developer_apple_metal` — focused depth-state, depth format and clear-depth API lookup; official Apple URLs cited above. Context7 mixed some Metal 4 references into results; recommendations here use the existing classic Metal command encoder, not a migration to Metal 4.
- https://developer.apple.com/documentation/metal/mtlrendercommandencoder/setviewports(_:) — viewport origin is top-left, positive Y downward, default near/far 0/1; retrieved through the focused Context7 coordinate lookup. Account for this conversion once rather than changing world/texture conventions.
- Context7 `/websites/developer_apple_appkit` — responder scroll, NSEvent deltas and first-responder APIs; official Apple URLs cited above.

### Confidence and review

Stack/integration observations: HIGH (live source and available toolchain). Architecture proposals: MEDIUM until math/GPU/transaction tests. Visual choices: MEDIUM as design candidates, no visual acceptance. A distinct inline review checked scope, D-01–21 preservation, all five requirements, source attribution, failure paths, complete-state gaps and separation of proposals from evidence. No build, unit/HUD/GPU run, benchmark or human acceptance was performed.

**Valid until:** 2026-12-13, or sooner if these source files, context or numerical contracts change.
