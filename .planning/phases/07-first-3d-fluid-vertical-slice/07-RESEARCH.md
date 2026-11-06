# Phase 7: First 3D Fluid Vertical Slice — Research

**Researched:** 2026-11-06
**Domain:** Staggered-grid 3D fluid evolution, Metal compute, native Mac integration, production-kernel verification
**Confidence:** HIGH for inspected integration points and numerical references; MEDIUM for the proposed implementation; unmeasured for convergence cost and lesson visibility
**Execution:** Inline research and inline source review; no independent-agent verification.

<user_constraints>
## User Constraints (from CONTEXT.md)

The following decisions and discretion text are copied verbatim from `07-CONTEXT.md`. [VERIFIED: 07-CONTEXT.md]

### Selecting the 3D lesson
- **D-01:** Extend the current Mac experiment selector with nonselectable **2D** and **3D** group headings; retain one selector rather than adding a dimension switch. Keep Free Play and the three existing 2D lessons in the 2D group and place **3D Dye Advection** in the 3D group.
- **D-02:** Preserve the existing Free Play and 2D lesson titles. Do not add redundant dimension prefixes to every entry. Mirror the same grouping and active selection in the existing Mac experiment menu; no new 3D keyboard shortcut is required, and existing 2D shortcuts must retain their meaning.
- **D-03:** While selected, show **3D Dye Advection** as a controls-panel heading with a short fixed-slice descriptor. Do not add a persistent 3D identity label on the canvas.

### First fixed-slice appearance
- **D-04:** Present one fixed **central XY cross-section**, viewed straight on and fitted as a square like the existing lessons. This is a sample of the 3D volume, not a projection, flattened volume, or extruded 2D simulation. No angled plane, wireframe cube, or interactive camera in Phase 7.
- **D-05:** Give 3D dye a distinct **warm amber concentration palette**: black through orange/amber to pale cream as concentration increases. Preserve the existing blue palette in 2D. The colours represent concentration, not different substances.
- **D-06:** Put orientation and depth information in the controls panel: **“XY slice · halfway through Z”**, with a dye-concentration legend. Do not overlay canvas axes, grids, borders, or axis arrows for orientation. The numerical sampling convention for the midpoint of an even-sized grid must be defined in planning, consistent with this description.

### Starting flow and dye
- **D-07:** Target a smooth, contained **rolling/tumbling circulation** that carries dye across and through the slice. This is the desired visual character, not a prescribed velocity formula or a substitute for proving genuine evolving, depth-varying three-component velocity.
- **D-08:** Seed **one compact, smooth 3D dye blob**, slightly off centre, intersecting the central slice and visibly nonblank at step 0. Do not use two patches or a stripe for this first lesson.
- **D-09:** Prioritise **readable early transport**. Research and validate a flow/seed configuration with an observable early motion window that also supports the later speed-comparison lesson. Genuine thinning or disappearance as dye leaves the section is acceptable and must be briefly explained. Do not replenish dye, move the fixed plane, or fake motion to maintain visibility.
- **D-10:** Use **no explicit dye fading/decay** in this experiment. Transport out of the slice and numerical smoothing can still change the visible image; do not present either as deliberate fading. This does not lock an unmeasured velocity-damping setting.

### Minimal 3D control surface
- **D-11:** Reuse the current native **Simulation Controls** panel, experiment navigation, transport controls, and visible step counter. Hide unsupported 2D field-selection buttons, 2D arrows/particles/trails, and Free Play tuning while 3D is selected; restore the established controls on return to 2D. Do not show disabled placeholder sections advertising unsupported views.
- **D-12:** In this dye-only 3D mode, **S is a no-op**: it must not cycle a hidden field or change numerical state. **Space retains Run/Pause**, respecting normal keyboard focus and activation of native controls. Existing 2D shortcuts and menu transport remain intact.
- **D-13:** Show a **short factual note** in the panel, rather than only labels or a collapsed About disclosure. Explain that the image is a cross-section of evolving 3D dye, brightness means concentration, dye can leave the plane, and steps are not seconds. Keep prediction exercises and initial-speed comparisons for Phase 9. Describe numerical smoothing honestly where relevant; do not reuse the current “two-dimensional” About text unchanged for 3D.
- **D-14:** If 3D GPU-resource initialisation fails, present a clear native error and retain or restore a **usable 2D mode**. Never silently replace the lesson with fake 3D animation, report success, or leave an unexplained blank canvas. Do not remain stranded on an unusable 3D selection.

### Carried-forward scope and behaviour
- **D-15:** Mac-only exposure, fixed 64³ grid, preserved 2D solver behaviour and both-target builds are already approved. Keep launch and 2D selection/reset behaviour established by the current educational release: launch into running Free Play; returning to Free Play creates a fresh running canvas and restores its session preferences; selecting a 2D lesson resets it with its established defaults. Clear stale input and pending advances across mode transitions. Freehand injection remains disabled in the scripted 3D lesson.
- **D-16:** Entry to 3D is paused at step 0. Each accepted paused Step action consumes exactly one logical solver step, independently of presentation callbacks. Inactivity advances nothing and does not create catch-up work; preserve the prior manual running/paused intent on return. Do not count rendered frames or wall-clock seconds as lesson steps.
- **D-17:** Numerical acceptance is an explicit pre-implementation planning task: define grid locations, units, timestep and pass order, interpolation, all six boundary faces, precision, compatible divergence/gradient/pressure operators, fixtures, and tolerances. Evaluate staggered MAC operators; do not inherit the 2D 40-iteration pressure loop as a correctness claim. Check pressure residual **and** post-projection divergence, three-axis advection/nonplanar transport, all boundaries, and finite values through the production encoder. Establish a measured early performance baseline without trading away numerical correctness. The milestone 30 fps acceptance gate remains in Phase 10.

### Agent's Discretion / Research and Planning Responsibilities

The user selected concrete choices for all discussed questions; no selected preference is delegated away. Research and planning choose the numerical scheme, storage and Swift/Metal ABI, compatible boundary conditions, initial-flow formula, exact seed extent/location, timestep, pressure convergence strategy, fixture values and acceptance tolerances. These remain unresolved technical work, not locked implementation choices or reasons to ask the user numerical-method questions again.

Choose exact amber stops/scaling, concise final copy, panel layout, native group-heading/menu mechanics, state representation and mode routing, and a safe 2D failure fallback consistent with the decisions above. Keep grouped heading rows separate from selectable modes: current index-based selector/menu routing cannot be carried over unchanged. Do not silently equate the new 3D speed scale, pressure settings, or tolerances with existing 2D constants. Preserve later-phase ownership while making the minimal transport coherent; reuse of existing restart/completion machinery does not establish Phase 9 acceptance.

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope. Existing roadmap boundaries remain: Phase 8 owns camera, movable slices and passive 3D tracers; Phase 9 owns the full comparative teaching/restart/completion/repeatability contract; Phase 10 owns volume presentation and final measured quality. Mobile 3D, injection, other 3D fields, trails and higher resolutions remain outside this milestone. Actual macOS 26 runtime and physical-device multitouch remain NOT TESTED until exercised.
</user_constraints>

## Summary

Use a separate `FluidSimulation3D` production encoder with face-centred MAC velocity, cell-centred scalar dye and pressure, and float32 storage. Bridson/Müller-Fischer explain both the compatible staggered derivatives and why collocated central differences admit unwanted null modes; GPU Gems explicitly calls its collocated example pedagogical and identifies MAC as more robust. Do not copy that example's central-derivative/Jacobi combination or change the established 2D solver. [CITED: S1 §§2.4, 4.1–4.3; S2 §30.2.3] [VERIFIED: Sources/Shared/FluidSimulation.swift:87–110]

Preserve the existing state/renderer ownership and no-drawable stepping architecture, but replace implicit `mode.experiment != nil` classification with explicit dimensional and lesson capabilities. Introduce Mac-only mode lists and stable menu identity rather than assigning headings positional mode indices. Build the 3D resources transactionally so an allocation, pipeline, or reset-command failure cannot destroy the working 2D fallback. [VERIFIED: Sources/Shared/SimulationState.swift:34–39,140–200; Sources/Shared/Renderer.swift:42–66,86–154; Sources/macOS/RenderViewController.swift:353–438; Sources/iOS/RenderViewController.swift:283–290]

**Primary recommendation:** Make numerical-contract/reference-fixture definition the first implementation task, then connect the real encoder to fixed-slice rendering and transport before expanding verification. The values below are explicit research recommendations to preregister and validate, not measurements or assertions that a solver already passes. [PROPOSED: technical discretion under D-17]

<phase_requirements>
## Phase Requirements

| ID | Required capability | Research support |
|---|---|---|
| SIM-04 | Select 3D dye advection on Mac | Stable mode identity, grouped native selector/menu, transactional entry |
| SIM-05 | Genuine evolving 64³ velocity and nonplanar dye transport | MAC contract, velocity self-advection/projection, asymmetric depth and transport fixtures |
| SIM-06 | Safe return to established 2D modes | Explicit mode routing, preserved Free Play session preferences, pending-input cancellation |
| LES-01 | Paused step-zero entry and Run/Pause/Resume counter | Existing transport pattern extended beyond 2D `experiment` identity |
| LES-02 | Exactly one logical step per accepted paused action | Queued steps and production renderer exercised without drawable |
| LES-06 | Inactivity freeze and no catch-up | Separate user pause/inactivity, cancel queued work, controlled post-reactivation callback |
| VER-03 | Production numerical fixtures with declared references/tolerances | Independent CPU Double oracle, compatible operators, all-face/finite checks, real metallib |

Requirement ownership comes from ROADMAP §Phase 7 and REQUIREMENTS traceability; `init.plan-phase 07` returned `phase_req_ids: null`, so downstream planning must pass these seven IDs explicitly. `roadmap.get-phase 7` resolves correctly; its zero-padded `07` lookup did not. Use canonical phase number `7` for roadmap queries and padded `07` for artifact names. [VERIFIED: workflow query outputs, .planning/ROADMAP.md:25–38, .planning/REQUIREMENTS.md]
</phase_requirements>

## Project Constraints (from AGENTS.md)

- Keep production code under `Sources/{Shared,macOS,iOS}`, XCTest under `Tests/Unit` and `Tests/UI/{macOS,iOS}`, and offscreen checks under `Tests/Integration`. Keep project-relative group, plist and entitlement paths valid. [VERIFIED: AGENTS.md]
- Retain `FluidDynamicsMetal.xcodeproj`, exact schemes `FluidDynamicsMetalOSX` and `FluidDynamicsMetaliOS`, Swift 6 language mode, Swift 6.2+ toolchain, macOS/iOS 26 minimums and Apple Silicon Mac. No package or build-setting override. [VERIFIED: AGENTS.md]
- Shared files compile directly into both apps; register new sources in both app targets and in the Mac state-test target when it compiles dependent production files. The Python harnesses also enumerate Swift sources explicitly. [VERIFIED: AGENTS.md; project.pbxproj PBXBuildFile entries; Tests/Integration/test_educational_release.py:24–30]
- Keep old Swift/Metal ABI, literal entry points and 2D pass ordering unchanged. Prefer a new `Shaders3D.metal` and separate 3D uniform structs. [VERIFIED: AGENTS.md; Sources/Shared/FluidSimulation.swift] [PROPOSED: file separation]
- Verify both no-override builds, applicable Mac state/HUD tests and integration regressions. Historical passes are not current evidence. Do not close actual-macOS-26 or physical mobile coverage gaps using this host. [VERIFIED: AGENTS.md; REQUIREMENTS Acceptance Conventions]

## Standard Stack

| Technology | Baseline / observed version | Use |
|---|---|---|
| Swift / simd | Swift 6 language mode; installed compiler 6.4.2 | State, seed/reference construction, GPU orchestration |
| Metal / MetalKit | OS 26 baseline; Xcode 27.2 installed | 3D compute fields, fixed XY slice, existing MTKView |
| AppKit | OS SDK | Existing movable controls panel, native selection/menu/error |
| XCTest / XCUITest | Xcode project targets | Shared state and Mac controls regression |
| Python unittest + Swift harness | Python 3.14.7 installed | Compile production Swift, load built app's actual metallib, assert GPU readback |

No third-party package or scene engine is required by this design. Versions above are observed tool output or repository constraints, not registry versions. This is AppKit/UIKit, not a SwiftUI rewrite. [VERIFIED: xcodebuild -version; xcrun swift --version; python3 --version; AGENTS.md; both controllers]

## Numerical Contract Recommendation — Define Before Kernels

The planner must create an initial task writing `docs/3d-numerical-contract.md` and independent CPU reference fixtures before implementing 3D kernels. Include the following concrete contract, or document and reference-test any technical revision before GPU acceptance. This task must not ask the user to choose numerical methods again. [PROPOSED: D-17 implementation gate]

### Coordinates, storage and precision

- Unit cube `[0,1]³`, right-handed mathematical axes; X right and Y up in the face-on XY image, Z identifies depth. Convert display Y exactly once; do not inherit downward-positive 2D texture conventions accidentally. Grid size `N=64`, spacing `h=1/64`. Dye and pressure at `((i+.5)h,(j+.5)h,(k+.5)h)`, each dimension 64. [PROPOSED]
- Face textures: `u` is `65×64×64` at `(ih,(j+.5)h,(k+.5)h)`; `v` is `64×65×64` at `((i+.5)h,jh,(k+.5)h)`; `w` is `64×64×65` at `((i+.5)h,(j+.5)h,kh)`. Separate scalar `.type3D` / `.r32Float` ping/pong textures; cell-centred dye and solver scalars also float32. Distinct face extents require distinct dispatch dimensions. MAC locations follow S1; exact storage is proposed and must pass device/Metal validation. [CITED: S1 §2.4; S3] [PROPOSED]
- Initial fixed numerical `dt=1/60` in dimensionless simulation-time units; one logical Step executes one `dt`, not elapsed physical seconds or a display-frame delta. Velocity units are domain lengths per simulation-time unit, independently of the 2D cells-per-step choices. Initially no explicit dye decay, no added vorticity force, and velocity retention `1`; revisit damping only with recorded numerical and visibility evidence. [PROPOSED]
- Swift uniforms use 16-byte vectors such as `SIMD4<UInt32>` / `SIMD4<Float>` matched by `uint4` / `float4`, with explicit size/stride/offset assertions and an asymmetric kernel round-trip fixture. Do not append a padded `SIMD3` to old `StaticData`. [PROPOSED; VERIFIED: existing cross-language contract in AGENTS.md]

### Advection and all six walls

- Reconstruct each velocity component at its own staggered location with its own trilinear coordinates. Use midpoint/RK2 characteristic backtracing, then trilinear interpolation of the transported component/scalar. All three new velocity components read the same old velocity state; do not swap u before v/w finish. This avoids an unintended sequential component update. Trilinear MAC reconstruction and semi-Lagrangian tracing are established in S1; RK2 and exact scheduling are proposed here. [CITED: S1 §§2.4, 3.2] [PROPOSED]
- Fixed, impermeable free-slip box: `u(0,j,k)=u(64,j,k)=0`; `v(i,0,k)=v(i,64,k)=0`; `w(i,j,0)=w(i,j,64)=0`. Enforce before divergence and after projection, including edge/corner intersections. No periodic wrapping, open boundaries, obstacles or free surface. [CITED: S1 §4.1; S2 §30.2.4] [PROPOSED: selected boundary policy]
- Backtraces are bounded to the cube. Define sampling with odd reflection of a wall-normal velocity component and even reflection of tangential components across each wall; dye uses even/zero-normal-derivative extension. Apply reflections per axis at edges/corners, and require exact wall-face zeros. Implement these semantics explicitly, not accidentally by using one clamp sampler for all component layouts. Test individual wall-adjacent samples against the CPU oracle. [PROPOSED]
- One logical step: self-advect all velocity components → enforce normal boundaries → compute divergence → solve compatible pressure correction → subtract its face gradient → enforce boundaries → advect dye using the newly projected velocity. Swap only completed field generations. Reset seeds and projects initial velocity without incrementing the step counter; initialize both sides of every ping/pong and all pressure/reduction scratch. No dye replenishment or time-varying prescribed velocity. [PROPOSED]

### Compatible projection and convergence

Let `D` be outward face-flux difference divided by `h`, and `Gq` on an interior X face be `(q[i,j,k]-q[i-1,j,k])/h`, with the analogous Y/Z forms. Set wall-normal `Gq=0`, consistent with already enforced zero wall velocity. Use pressure-correction potential `q=dt*p/rho`, not undocumented physical pressure. [CITED: S1 §§4.1–4.3] [PROPOSED: q scaling]

Define `A=-h²DG` and `b=-h²D(u*)`. Then each row is `neighborCount*qCenter - sum(qInteriorNeighbors)` with neighbor count 6 inside, 5 on one face, 4 on edges, 3 on corners. Solve `Aq=b`; update `uNew=u*-Gq`. Constants form the expected Neumann nullspace. For true residual `r=b-Aq`, the compatible identity is `D(uNew)=-r/h²`, apart from floating-point roundoff. These formulas are algebraic consequences of the stated operators and must also be independently tested; do not measure only an iterative solver's recursive residual. [DERIVED: stated D/G composition; CITED: S1 §4.3]

Use matrix-free preconditioned conjugate gradient as the correctness-first candidate, with diagonal/Jacobi preconditioning and GPU reductions. Start `q=0` each step. Work in the zero-mean subspace: check RHS compatibility, remove only roundoff-scale mean, project preconditioned/search vectors as needed, and normalize q's mean. A large mean/flux discrepancy is a boundary failure, not something to hide by subtracting it. Guard zero RHS, zero denominators, nonfinite reductions and iteration exhaustion. S1 supports PCG and explicitly discusses the singular closed-box case; its MIC preconditioner is not a Metal performance recommendation. [CITED: S1 §4.3.2–4.3.4] [PROPOSED: diagonal preconditioner and GPU strategy]

Encode a bounded maximum initially proposed as `256` PCG iterations with GPU convergence/status scalars and guarded no-op iterations after convergence; do not introduce CPU readback/wait in each live step. This cap is **not** acceptance: pre-implementation CPU fixtures must establish feasibility, and production GPU fixtures must prove both residual and divergence thresholds. Record iteration counts, true residual, status and timings. Increase/restructure the solve if necessary without silently relaxing correctness. GPU dispatch overhead may make this candidate expensive; geometric multigrid is a follow-up technical alternative if measurements warrant it, not a second solver to build upfront. [PROPOSED; CITED: S1 iteration-limit discussion]

### Preregistered reference fixtures and candidate tolerances

Write final metric definitions and justified tolerances into `docs/3d-numerical-contract.md` before kernel implementation; the following are starting acceptance recommendations, **not passing results**. Use a CPU Double oracle with independent loops, not a second invocation of GPU code or screenshot-only agreement. Test small asymmetric grids as well as production 64³. [PROPOSED]

| Fixture | Reference / assertion | Proposed acceptance |
|---|---|---|
| ABI and scalar indexing | Index ramp `i+100*j+10000*k`, distinct component constants, all volume planes | Exact integers within float32 exact range; exact extents/offsets |
| Zero field / uniform dye | Entire production reset and step | No NaN/Inf, exact wall zeros; dye preserved within absolute `2e-6`; no explicit decay |
| Three-axis advection | Compact interior scalar, separate ±X/±Y/±Z and combined unequal velocities; CPU RK2/trilinear result | Elementwise `abs(error) <= 2e-5 + 2e-4*abs(reference)`; bounded scalar; boundaries checked separately |
| Discrete operator identity | Independently compute `-h²DGq` and neighbor-count A, including faces/edges/corners, constant and alternating pressure fixtures | CPU Double absolute `1e-10` on normalized fixtures; GPU float32 absolute `2e-5 + 2e-4*abs(reference)` |
| Manufactured projection | `q=cos(pi*x)*cos(2*pi*y)*cos(3*pi*z)` at cell centres; construct face `Gq`, plus an independently divergence-free field | Projected velocity agrees with CPU solution at above float32 tolerance; q comparisons remove mean |
| Low/high-frequency projection | Separate smooth, alternating and asymmetric deterministic face fields, wall-normal values zeroed first | Both `dt*normInf(DuNew) <= 1e-5` and `dt*normInf(r)/h² <= 1e-5`; for input `dt*normInf(Du*) >= 1e-3`, divergence reduction at least `1000×` |
| All six boundaries | Independently excite near each wall and its edges/corners; projection plus advection | Wall-normal face values exactly zero after enforcement; reflected samples match CPU tolerance; all wall-adjacent cells included in divergence norm |
| Real 3D evolution | Production recipe at steps 0/1/24/48/72; snapshot u/v/w and scalar volume | All components change through actual advection/projection, depth dependence exceeds roundoff, and out-of-plane transport is measured, not inferred from one image |
| Fixed slice midpoint | Asymmetric scalar with known Z ramp and X/Y landmarks | Sample at world `z=.5`; interpolate equally between cell planes 31 and 32, never silently choose plane 32; screen orientation matches labels |

For projection also report L2 norms, max wall flux, RHS mean, cap hits and residual/divergence identity error. Check **every** evolution field and scratch/reduction status for finiteness after reset, one step and a sustained run; a 600-step finite soak may be useful numerical stress coverage but does not establish Phase 9 lesson completion/repeatability. Reject NaNs explicitly before tolerance comparisons. [PROPOSED]

If reference fixtures show a proposed threshold or budget is unattainable, investigate scale, boundary, precision, reduction drift and convergence before editing the contract. Document any change with CPU/reference justification before new GPU acceptance results; do not tune a threshold to an observed defective result. [PROPOSED: validation discipline]

## Starting Flow and Early Observation Window

Research recommends sampling the curl of a smooth vector potential with different spatial frequencies, not extruding one 2D vortex. Candidate `f=sin²(pi*x)*sin²(pi*y)*sin²(pi*z)` and `A=(0.7*f, f*sin²(pi*y), 0.6*f*sin²(pi*z))`; compute its analytic curl on the appropriate faces, set normal wall values to zero, then run the production projection at reset. Normalize candidate seed to maximum vector speed `0.12` domain lengths per simulation-time unit. This is an initial condition only: every subsequent velocity is self-advected/projected, not reevaluated from A. The selected formula's teaching quality remains unmeasured. [PROPOSED]

Candidate dye is one compact smooth radial bump centred `(0.42,0.48,0.52)`, radius `0.12`, peak `1`: with `s=length(x-center)/radius`, use `exp(1-1/(1-s²))` for `s<1`, otherwise zero. It geometrically intersects `z=.5`; verify nonblank sampling and visible transport in the production renderer. Start with no added velocity damping rather than importing 2D constants. [PROPOSED]

Capture steps `0,24,48,72` under a fixed concentration transfer function. Before accepting this configuration, preregister an early window/metric using CPU/reference trajectories and then confirm with GPU fields and captures: finite volume mass/centroid/spread, change in slice image, Z displacement and trajectories not confined to a single plane. Test-only probe trajectories may use readback of evolving production fields; they are not Phase 8's user-visible tracer feature. Compare internal seed scales `0.5,1,1.5` only to assess future Phase 9 feasibility, not to expose controls or claim speed-ordering acceptance now. Exact observation point, nonplanarity/visibility thresholds and final seed calibration remain a required evidence-producing implementation task; no readable window has been demonstrated in this research run. [PROPOSED; VERIFIED: no 3D implementation exists in inspected source]

If the candidate loses visible signal too early, adjust seed/flow within D-07–10 and rerun a preregistered comparison. Investigate limited higher-order advection only if first-order interpolation fails to retain a usable window; validate a limiter before adoption. Never fix visibility with decay reversal, injection, camera motion, a moving slice or per-frame normalization that conceals concentration loss. Numerical advection smoothing is a known limitation, not explicit fading. [CITED: S1 §3; S2 Improving Detail] [PROPOSED: experiment calibration protocol]

## Architecture Patterns

### Proposed file responsibilities

| File / area | Responsibility and closest current analog |
|---|---|
| `Sources/Shared/FluidSimulation3D.swift` | Throwing resource/pipeline initialization, encodeReset/encodeStep, field ownership; analog `FluidSimulation.swift` |
| `Sources/Shared/VolumeField3D.swift` | Explicit face/cell dimensions, private textures, staging, ping/pong; analog `Slab.swift`, not its 2D format |
| `Sources/Shared/SimulationTypes3D.swift` | Separate grid/uniform ABI, solver configuration, status; do not mutate 2D StaticData |
| `Sources/Shared/ExperimentRecipes3D.swift` | Pure deterministic volume seed; analog `ExperimentRecipes.swift` |
| `Sources/Shared/FieldVisualization3D.swift` | Read-only fixed XY slice and amber palette; analog `FieldVisualization.swift` |
| `Sources/Shared/Shaders3D.metal` | Separate compute entry points, sampling/operators/reductions and fixed-slice shader |
| `SimulationState.swift`, `Renderer.swift` | Explicit capabilities, dimension routing, transport, safe transactional entry/return |
| `Sources/macOS/RenderViewController.swift` | Native group headings/menu identity, panel copy/legend, hidden 2D sections, error presentation |
| `Sources/iOS/RenderViewController.swift` | Explicit 2D-only available modes; no 3D UI |
| `Tests/Integration/test_fluid3d.py` / `.swift` | Compile production sources, actual built metallib, fixture upload/readback, numerical/scheduler evidence |
| `Tests/Integration/test_fluid3d_reference.py` | Independent CPU Double contract checks before GPU code |
| `Tests/Unit/SimulationStateTests.swift`, `Tests/UI/macOS/HUDUITests.swift` | State/selector/menu/focus/transport/fallback coverage |
| `docs/3d-numerical-contract.md`, `docs/3d-phase7-verification.md` | Preregistered contract and actual results/limitations respectively |

Names are recommendations for downstream planning, not created implementation files. Read live analogs; old `.planning/codebase/` maps predate current source layout, toolchain and tests. [PROPOSED; VERIFIED: current source and historical maps]

### Explicit mode capabilities, not optional-2D-ID inference

Add a distinct 3D mode (for example `.dyeAdvection3D`), `isLesson`/dimension or equivalent explicit switches, and separate `twoDimensionalModes` / Mac availability lists. Preserve old 2D enum identities and Command-1–4 mapping. Audit `complete`, reset, `requestSingleStep`, resource size, viewport, Run label, and field/overlay setters: currently a mode with `experiment == nil` falls into Free Play behavior in several places. S/field-selection must return without even a hidden-state mutation in 3D. [PROPOSED; VERIFIED: SimulationState.swift:155–194; Renderer.swift:34–47,88–89,109; both controllers]

Group headings are disabled, nonselectable menu items, not modes. Use represented identity or a dedicated selectable-item mapping; update active selection/checkmark from the committed renderer mode. Exact native styling and final copy must be supplied by `07-UI-SPEC.md`, absent at this run's UI gate. [PROPOSED; VERIFIED: Mac positional selector/menu handlers; .planning/config.json UI gates]

### Transactional resource replacement and transport

Prepare/validate the new 3D simulation and visualization using the injected `MetalDevice` instance. Drain/retire in-flight resources using the existing semaphore pattern; always release semaphore slots on every error path. Seed/reset, inspect completed command status, and only then commit 3D mode/state and notify controls. On failure retain the previous usable 2D mode or restore fresh running Free Play with saved session preferences, clear input/pending work, and present a native error. Add injectable allocation/pipeline/reset failures for tests. `ComputeShader` currently prints errors, and its class factory uses the singleton: do not reuse its silent-failure path for this contract or accidentally ignore the harness's explicit library. [PROPOSED; VERIFIED: Renderer.swift:86–104; ComputeShader.swift:43–53; MetalDevice.swift:60–62,123–138]

Step acceptance must be coupled to successful step encoding; do not consume the logical counter and then silently skip a missing pipeline. Keep no-drawable encoding, pending-step draining and inactivity cancellation. A paused present/resize/panel reopen must encode no step. On reactivation preserve userPaused; a running simulation may advance at the next ordinary callback, but not extra elapsed-time work. GPU command failure is an error, not successful advancement. [PROPOSED; VERIFIED: Renderer.draw(in:), scheduleStepDrain; SimulationState.consumeStep/resignActive/becomeActive]

### Metal resources and sampling

Private persistent textures plus explicit staging/blits fit the existing architecture; CPU fixture readback is allowed after command completion, not in the live loop. Include depth and bytes-per-image in 3D copies; existing harness helpers hardcode depth 1 and Float16 RG pairs and cannot be reused unchanged. Use the instance compute-pipeline cache, tracked resources and serial dispatches or separate encoders with documented dependencies. Reduction kernels must not read/write conflicting state across threadgroups without a pass boundary. [CITED: S4–S6; VERIFIED: test_educational_release.swift:27–46; MetalDevice.swift:123–138] [PROPOSED: dependency policy]

Derive legal threadgroup counts from each pipeline's limits and use each texture's actual extents. Query and validate r32Float 3D use on the actual device with Metal validation; this research did not execute a format probe. ABI/format failures must be errors, not a fallback to fake animation. [CITED: S3–S5] [PROPOSED]

## Don't Hand-Roll

| Problem | Use instead |
|---|---|
| New scene framework, window or controls toolkit | Existing MTKView, AppKit NSPanel, native menu and transport |
| A toy test-only GPU fluid solver | The same new production encoder and freshly built app metallib |
| Custom elapsed-time/catch-up scheduler | Existing logical-step queue and manual-pause/inactivity separation |
| A universal 2D/3D solver rewrite | Separate dimension-specific encoders and uniforms; preserve 2D reference |
| Approximate pressure method justified by appearance | Published compatible MAC operators, standard PCG algorithm, independent fixtures |

These are project-specific recommendations grounded in the existing integration points and selected numerical references, not a claim that a ready-made external Metal fluid solver was evaluated. [PROPOSED; VERIFIED: listed source analogs; CITED: S1]

## Code Examples

Existing production patterns to preserve:

```swift
// Sources/Shared/MetalDevice.swift — use the injected instance/library.
let pipeline = try metal.createComputePipeline(computeFunctionName: name)

// Sources/Shared/Renderer.swift — evolution does not require a drawable.
// The 3D branch must preserve this separation while handling encode failures.
if state.consumeStep() {
    simulation.encodeStep(command: command, tuning: state.tuning,
                          mode: state.mode, adjustment: state.adjustment, step: step)
}
if let drawable = view.currentDrawable {
    render(command: command, drawable: drawable, view: view)
    command.present(drawable)
}
```

The renderer excerpt omits existing contact arguments for brevity; it is an architectural excerpt, not proposed replacement code. [VERIFIED: MetalDevice.swift:123; Renderer.swift:136–145]

```swift
// Apple S5: adapt grid extents to each 3D output, respecting pipeline limits.
let grid = MTLSize(width: output.width, height: output.height, depth: output.depth)
encoder.dispatchThreads(grid, threadsPerThreadgroup: legalGroupSize)
```

The ordinary `MTLComputeCommandEncoder` API is intended; Context7 returned some Metal 4 argument-table examples and even a generated REST-shaped snippet. Those are not implementation guidance for this project; direct Apple symbol/article pages were used to disambiguate. [CITED: S5; VERIFIED: Context7 responses in this run]

## Common Pitfalls

1. **Residual converges but the fluid is still divergent:** incompatible D/G/A, stale field generations, wrong h scaling or wall enforcement. Check the true residual identity and post-projection divergence including boundary cells independently. [CITED: S1 §4.3; DERIVED: contract above]
2. **One component or far-Z planes are missing:** assuming equal face dimensions, wrong SIMD padding, depth-1 upload/readback or early component swap. Use asymmetric volume/ABI/axis fixtures. [VERIFIED: old harness 2D helpers; PROPOSED: fixture mitigation]
3. **3D takes the Free Play path:** `experiment == nil` misclassification changes grid, input, pause and viewport. Audit all callers and keep iOS's selector explicitly 2D-only. [VERIFIED: current state/renderer/controllers]
4. **Blank failure looks successful:** swallowed pipeline/texture failures or state committed before reset completion. Use throwing construction, native error and tested usable 2D recovery. [VERIFIED: ComputeShader error behavior; PROPOSED: recovery]
5. **Beautiful slice mistaken for 3D evidence:** a single XY frame cannot establish depth-varying self-evolution. Inspect full production fields and nonplanar transport. [VERIFIED: REQUIREMENTS SIM-05 acceptance; PROPOSED: fixtures]
6. **Visibility kept alive artificially:** no explicit decay does not eliminate interpolation smoothing or dye leaving the fixed plane. Measure and explain, rather than replenishing dye. [CITED: S1 §3; VERIFIED: D-09/10/13]
7. **Offscreen GPU milliseconds advertised as frame rate:** report command-buffer cost and host completion cost separately; actual presentation pacing needs a displayed run. [CITED: S6; VERIFIED: REQUIREMENTS performance convention]

## Early Performance Baseline

Plan two separately reset, identical-seed configurations: solver-only and solver-plus-fixed-slice at explicitly allocated `1280×720` output pixels with a centred square viewport. Start with `60` warm-up advances then `240` measured advances. Record per-step completed-command GPU time, host encode/submit/completion time, median/p95/max and resource inventory including solver scratch, staging and any retained 2D resources. A synchronized offscreen test is not presentation pacing. Add a displayed run with completion-based GPU timing and measured frame intervals if available; report mode and sample protocol separately. Readback, captures and Metal validation should be outside the timed segment; report validation-enabled correctness and validation-disabled timing as different runs. [PROPOSED; CITED: S6; VERIFIED: REQUIREMENTS performance convention]

Record actual Mac model/GPU, OS/build, Xcode/compiler, configuration, simulation grid, output pixels, in-flight count, dt, solver cap/tolerance, iteration/cap-hit counts, explicit retention and display settings. Available host: MacBook Pro `Mac15,6`, M3 Pro with 18 GPU cores and 36 GB memory, macOS 27.0 (`26A428`), Xcode 27.2 (`27B52`), Swift 6.4.2. Do not record hardware serial/UUID identifiers in evidence. These are environment observations, **not performance results**. [VERIFIED: system_profiler, sw_vers, toolchain probes]

Phase 7 has no 30 fps pass/fail gate: record a baseline after correctness, investigate excessive cost without weakening numerical acceptance, and retain Phase 10 ownership of the integrated slice/tracer and volume/tracer 30 fps contract. [VERIFIED: ROADMAP Phase 7/10; D-17]

## Validation Architecture

### Test Framework

| Property | Value |
|---|---|
| Existing framework | XCTest/XCUITest targets; Python unittest launching compiled production Swift GPU checks |
| Configuration | `FluidDynamicsMetal.xcodeproj`, shared app schemes; no Swift package |
| Proposed quick contract command | `python3 -m unittest Tests.Integration.test_fluid3d_reference` — MISSING until first implementation task |
| Proposed 3D GPU command | `python3 -m unittest Tests.Integration.test_fluid3d` — MISSING; requires fresh Mac build and working Metal Toolchain |
| Existing full integration | `python3 -m unittest discover -s Tests/Integration` after both builds; simulator-dependent cases require available destinations |

Existing tests and harness wiring were inspected; neither new 3D test exists yet. Timing estimates for new commands have not been measured. The existing report's 71.26-second full discovery is historical, not a latency promise for this phase. [VERIFIED: Tests tree, test_educational_release.py, docs/educational-release-verification.md]

### Phase Requirements → Test Map

| Req ID | Behavior / checks | Layer | Command / planned addition |
|---|---|---|---|
| SIM-04 | Group headings nonselectable; 3D selection/checkmark/entry; native failure recovery | Mac UI + production integration | Mac scheme test; extend `Tests/UI/macOS/HUDUITests.swift`; new `test_fluid3d` |
| SIM-05 | 64³ and staggered extents; all components evolve; depth variation and nonplanar transport; fixed-slice fixtures | CPU oracle + production GPU | New `test_fluid3d_reference` and `test_fluid3d` |
| SIM-06 | 3D→each 2D mode, saved Free Play preferences, clear queued actions/contacts, injected initialization failure | State + renderer + UI | Mac scheme test; new `test_fluid3d`; old `test_educational_release` |
| LES-01 | Paused step 0, Run/Pause/Resume counter; no step during presentation-only callbacks | State + renderer + UI | Mac scheme test; new `test_fluid3d` |
| LES-02 | One action→one encoded logical step; rapid queued actions and nil drawable; no extra redraw steps | State + renderer | Mac scheme test; new `test_fluid3d` |
| LES-06 | Running and paused inactivity, queue cancellation, unchanged full state while inactive; no catch-up on return | State + production renderer | Mac scheme test; new `test_fluid3d` |
| VER-03 | CPU fixtures, true residual and post-divergence, all axes/faces, finite fields/status | Independent CPU + actual production GPU | New `test_fluid3d_reference` and `test_fluid3d` |

### Sampling Rate

- Every numerical change: independent CPU contract checks and focused production GPU fixture after a fresh metallib build. CPU-only success does not establish VER-03. [PROPOSED]
- Every shared state/routing change: Mac state tests plus relevant production renderer checks, both no-override app builds. [PROPOSED; VERIFIED: AGENTS.md regression constraint]
- Every UI change: focused Mac HUD tests, then complete applicable Mac suite. Run iOS HUD checks after shared-mode/UI filtering changes using a currently available simulator. [PROPOSED]
- Each implementation wave and final phase gate: applicable full existing integration regressions and both builds; retain logs, artifacts and unavailable-check reasons. Never insert placeholder test commands as passing evidence. [PROPOSED]

### Wave 0 Gaps

- `docs/3d-numerical-contract.md` with final reference fixtures, scales, metrics and tolerances before kernels.
- `Tests/Integration/test_fluid3d_reference.py` independent CPU oracle and operator/fixture self-checks.
- `Tests/Integration/test_fluid3d.py` and `.swift` compiling the production 3D sources, loading the just-built metallib, uploading/reading depth correctly and exposing focused fixture selection.
- State/HUD additions for 3D, failure-injection seams, and source memberships/source lists for all app/test/harness consumers.
- Install/activate the missing Metal Toolchain before accepting any fresh app build or GPU result. No new test framework installation is proposed.

These are planning inputs, not completed tests or assigned plan/task IDs. `07-VALIDATION.md` remains draft until executable plans supply actual task mapping. [PROPOSED; VERIFIED: absent files and active-toolchain probe]

## Security Domain

Security enforcement is absent in config, therefore enabled by workflow default. This is a local GPU/numerical feature, not a web authentication system. Apply ASVS-style input/resource/error checks where relevant; authentication, server sessions/access control and cryptography are not introduced by this phase. Do not invent network threats or new security dependencies. [VERIFIED: .planning/config.json; phase scope; inspected controllers/encoder]

| Threat / trust boundary | Required mitigation and proof |
|---|---|
| UI selection/dispatch coordinates → GPU resources | Fixed supported grid, checked extents/strides, legal threadgroups, bounds guards and asymmetric fixtures; no selectable header interpreted as a mode |
| Unavailable pipeline/allocation/reset → app state | Typed errors, deterministic injected failure, usable 2D restoration, balanced synchronization slots and native explanation |
| Invalid values/solver breakdown → subsequent frames | Finite-value/denominator/status checks; nonconvergence is surfaced as failure, not reported as a successful numerical fixture |
| GPU completion callback → actor-isolated app | Follow MainActor ownership; capture only safe completion data and hop explicitly for UI/state updates; do not mutate actor state from arbitrary completion threads |
| Evidence output → repository | Deterministic local artifact directory; report model/tool versions, not hardware serial/UUID, credentials or unrelated user paths |

These mitigations should become per-plan `<threat_model>` entries and verification references when plans are created. Severity/blocking decisions must be assessed by that plan review, not claimed resolved by research. [PROPOSED]

## Environment Availability

| Dependency | Observed availability | Consequence / fallback |
|---|---|---|
| Xcode / Swift | Xcode 27.2; Swift 6.4.2, arm64 | Meets repository minimum; retain Swift 6 mode |
| Python | 3.14.7 | unittest driver available |
| Apple Silicon / GPU | M3 Pro, 18 GPU cores; system reports Metal 4 support | Candidate numerical/performance host; no production 3D run performed |
| Active Xcode Metal compiler | `xcrun --find metal` locates shim, but `xcrun metal --version` fails: missing Metal Toolchain | Fresh Metal build/GPU validation blocked until `xcodebuild -downloadComponent MetalToolchain` succeeds; not run by this research |
| Actual macOS 26 runtime | Current host is macOS 27.0 | NOT TESTED; newer-host evidence cannot close this gap |
| iOS simulator destinations / physical device | Not audited during this research | Discover via `xcrun simctl list devices available` before iOS tests; physical multitouch remains NOT TESTED |
| Named GSD agents / Repowise index | init reports agents unavailable; Repowise reports no index | Research performed inline and source inspected directly; neither blocks planning artifacts |

Environment probes are fresh observations; historical notes about an installed Xcode 27.0 Metal Toolchain do not establish availability under active Xcode 27.2. [VERIFIED: tool output; STATE.md historical environment]

## Open Questions and Implementation Gates

1. **Numerical reference feasibility:** Run/lock the CPU contract before GPU implementation; verify PCG gauge/preconditioning/cap and tolerances. No solve was benchmarked here. [PROPOSED]
2. **Readable initial flow and future comparison window:** Candidate recipe/seed and snapshots above need actual production-kernel evidence. Do not promise that steps 24/48/72 already show usable ordering or sustained visibility. [PROPOSED]
3. **Actual device formats and ABI:** Validate allocation, all 3D extents, interpolation, staging alignment and named entry points on the selected GPU after the toolchain is repaired. [PROPOSED]
4. **UI contract missing:** `07-UI-SPEC.md` does not exist and both UI flags are enabled. Manual plan-phase must stop at workflow §5.6 before pattern mapping/planner/checker; next action is `/gsd-ui-phase 7`, then `/gsd-plan-phase 7`. [VERIFIED: phase directory; config; workflow gate]
5. **Execution environment:** Missing active Metal Toolchain blocks builds and GPU evidence, not writing research or plans. Installation is a separately visible prerequisite; no toolchain download was attempted. [VERIFIED: xcrun metal failure]

## Assumptions Log

No unverified factual claim is intentionally treated as a locked decision. `[PROPOSED]` values/algorithms are research recommendations within the explicitly delegated technical discretion, not measured results or additional user preferences. They require the stated reference/production checks. No `[ASSUMED]` compliance, API-support or performance claims are used. [VERIFIED: source/provenance review of this artifact]

## Sources

- **S1:** Bridson / Müller-Fischer, *Fluid Simulation*, SIGGRAPH 2007 course notes, https://www.cs.ubc.ca/~rbridson/fluidsimulation/fluids_notes.pdf — downloaded and text-extracted in this session; reviewed §2.4 (MAC and interpolation), §3 advection material, §§4.1–4.3 (operators, closed-domain nullspace, PCG, residual). Historical numerical reference, not a Metal benchmark. Course index: https://www.cs.ubc.ca/~rbridson/fluidsimulation/.
- **S2:** Crane/Llamas/Tariq, GPU Gems 3 Chapter 30, https://developer.nvidia.com/gpugems/gpugems3/part-v-physics-simulation/chapter-30-real-time-simulation-and-rendering-3d-fluids — retrieved 2026-11-06; MAC caveat, semi-Lagrangian smoothing, boundary treatment and limited higher-order advection. Historical implementation; do not port its illustrative collocated stencils as acceptance.
- **S3:** Apple, https://developer.apple.com/documentation/metal/mtltexturetype/type3d.md — 3D texture type, retrieved 2026-11-06. Exact proposed format/usage combinations still need actual-device verification.
- **S4:** Context7 `/websites/developer_apple_metal`, queried 2026-11-06 for private texture storage, 3D staging/readback and compute; cross-checked direct Apple pages because mixed Metal/Metal 4 and autogenerated snippets were returned. Private storage source: https://developer.apple.com/documentation/metal/setting-resource-storage-modes.
- **S5:** Apple, https://developer.apple.com/documentation/metal/calculating-threadgroup-and-grid-sizes.md — pipeline limits, grid dispatch and defensive bounds, retrieved 2026-11-06.
- **S6:** Apple, https://developer.apple.com/documentation/metal/mtlcommandbuffer/gpuendtime.md — completed-command timing semantics, retrieved 2026-11-06.
- **Local primary evidence:** `AGENTS.md`, `README.md`, `docs/educational-release-verification.md`, `.planning/{PROJECT,ROADMAP,REQUIREMENTS,STATE}.md`, current phase context/config; current production state, renderer, Mac/iOS controllers, GPU wrappers, field visualization, project memberships, state/HUD tests and educational GPU harness.
- **Historical context only:** archived Phase 3/4/5 context and `.planning/codebase/{STACK,ARCHITECTURE,STRUCTURE}.md` were read; current paths, native Mac panel, language/deployment settings and available tests supersede stale descriptions.

## Inline Review and Metadata

Reviewed against all D-01–17 and seven owned requirements: preserves 2D/iOS, explicitly defines the even-grid midpoint, keeps display separate from evolution, includes pressure nullspace/true-residual/divergence/all-face coverage, records initialization recovery and fresh toolchain failure, and leaves Phases 8–10 ownership intact. Proposed algorithms/tolerances and lesson quality are not reported as verified. Numerical-reference checks, GPU probes, builds, UI tests and measurements have **not** been run by this research. [VERIFIED: inline artifact/source review]

**Confidence:** HIGH source-grounded integration and referenced MAC mathematics; MEDIUM implementation strategy; LOW/unmeasured seed visibility, solver budget and performance. Recheck local source/toolchain availability when execution starts; revisit API guidance if planning is delayed beyond 30 days.
