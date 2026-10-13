# First educational release of FluidDynamicsMetal

## 1. Purpose and release scope

Build an approachable visual learning experience for curious learners on **Mac, iPhone, and iPad**. A learner should be able to choose an experiment, predict its behaviour, advance it, inspect the fluid through different views, and restart with one controlled change.

This document defines the intended implementation and acceptance criteria. It does not authorize starting implementation.

### Agreed product decisions

| Area | Decision |
|---|---|
| Launch experience | Open the existing Free Play canvas. |
| Guided experiments | Use the existing fluid solver with deterministic initial states and scripted forces. |
| Lesson interaction | Disable freehand dye and force input; expose one experiment-specific adjustment. |
| Lesson canvas | Use a fixed square simulation grid, fitted without distortion into the available space. |
| Tracers | Include passive particles and optional short history trails. |
| Supporting controls | Include reset/restart, single-step, and separate dye fading from motion damping. |
| Platforms | Deliver equivalent capabilities through the existing native Mac and iOS interfaces. |

**Included:** readable field views and legends, velocity arrows, passive tracers, reset and single-step, three guided experiments, concise educational explanations, and supporting tests.

**Deferred:** slow motion, recorded replay, simultaneous field views, comparisons between separate simulations, particle emitters, streamlines, obstacles, physical viscosity, calibrated physical units, and replacement of the pressure solver.

### Scientific and timing boundaries

The lessons are qualitative demonstrations using the existing two-dimensional solver. Preserve its advection, confinement, boundary treatment, and 40 pressure iterations. Do not describe the results as quantitatively validated physical predictions.

Retain one simulation step per advancing render callback, targeting 60 callbacks per second. Display a **step count**, not elapsed physical time. Repeatability means the same preset, parameters, and number of steps on the same implementation and device. Do not promise identical floating-point results across devices or identical playback duration under different GPU loads.

## 2. User experience and behaviour

### Free Play

Preserve the current launch behaviour: an empty, running dye canvas with tuning collapsed.

Add:

- An **Experiments** selector containing Free Play and the three lessons.
- **Reset fluid**, which clears all fluid fields, reseeds particles, clears trails and pending input, and resets the step count.
- **Step**, enabled only while paused and active.
- **Velocity arrows**, **Particles**, and **Trails** display controls.
- Separate **Dye fading** and **Motion damping** tuning controls.

Reset fluid preserves the selected field, display options, tuning values, and running/paused choice. It does not restore tuning defaults.

### Entering and restarting a lesson

Selecting a lesson:

1. Clears active gestures, pending contacts, and pending steps.
2. Creates its fixed grid and initial fields.
3. Applies its prescribed tuning and default adjustment.
4. Seeds particles and clears history.
5. Selects the lesson’s default display.
6. Opens the lesson explanation and leaves the simulation paused at step zero.

Provide **Run**, **Pause/Resume**, **Step**, and **Restart experiment**.

Each lesson runs for **600 steps**, then pauses with “Experiment complete. Restart to compare.” Run and Step are disabled at completion; changing views and overlays remains available.

Restart restores the same initial state using the **currently selected lesson adjustment**, preserves field and overlay choices, and pauses at step zero. Changing a lesson adjustment immediately performs this same restart. State this beside the adjustment: “Changing this restarts the experiment.”

Switching to another lesson uses that lesson’s default adjustment and display settings. Returning to Free Play creates an empty running canvas and restores the session’s Free Play tuning and display preferences. Previous fluid contents are not retained.

Session settings are not persisted across launches. Preserve the existing Mac panel-position persistence.

### Educational presentation

Each lesson includes:

- A one-sentence question to consider before running.
- A short “What to notice” explanation.
- One adjustment.
- A brief model limitation where relevant.

Keep implementation terminology out of the main lesson instructions. Put the shared explanation that these are two-dimensional qualitative simulations in an expandable **About this simulation** section.

Use these field names:

| Internal field | User-facing name | Explanation |
|---|---|---|
| Density | Dye concentration | “Dye marks material carried by the flow.” |
| Velocity | Velocity | “Arrows show direction; colour shows speed.” |
| Vorticity | Vorticity | “Colour distinguishes local clockwise and anticlockwise rotation.” |
| Pressure | Pressure | “Shows the pressure correction relative to its spatial average, in simulation units.” |

Keep existing `DisplayField` raw values and field-cycle order. Change labels and explanations rather than renumbering cases.

### Native layouts

**Mac:** extend the existing floating Simulation Controls panel. Preserve its movement, closing, reopening, and autosaved position. Use a pinned experiment selector and transport row, with the remaining controls in a scrollable body. Size from actual content rather than hardcoded assumptions about four tuning rows.

Add discoverable Simulation menu commands for pause/resume, step, reset/restart, and selecting experiments. Use Command-P for pause/resume, Command-Right Arrow for step, Command-R for reset/restart, and Command-1 through Command-4 for Free Play and the three lessons. Retain existing Space and S canvas shortcuts and Option-Command-K for the panel.

**iPhone/iPad:** retain an overlay HUD in Free Play. In lessons, reserve space for controls below the square canvas in portrait and beside it in landscape. Use a pinned experiment selector and transport row with a scrollable body. Allocate approximately 40% of the available height or width to controls, increasing up to 60% when needed for the pinned controls’ intrinsic size.

Fit the lesson square into the remaining safe-area rectangle. Letterboxing must not affect simulation geometry. No lesson controls may cover the square.

On both platforms:

- Keep field switching, legends, overlays, and explanations available while paused.
- Give controls stable accessibility identifiers independent of their visible text.
- Preserve keyboard focus and scroll position during state refreshes.
- Support Dynamic Type on iOS, VoiceOver labels, increased contrast, and reduced transparency.
- Keep canvas pause and field-cycle gestures available in lessons, but suppress dye/force input there.
- Generalize Mac Space handling so focused new controls do not also trigger canvas pause.

## 3. Simulation, visualization, and lesson specification

### Shared state and interfaces

Extend the shared state model with:

- `SimulationMode`: Free Play or a specified experiment.
- `ExperimentID`: advection, interacting vortices, dye stretching.
- A typed adjustment for each experiment.
- Step count and lesson completion state.
- Display options for arrows, particles, and trails.
- Separate dye and velocity retention values.

Keep explanatory text, field metadata, experiment defaults, and adjustment choices in shared data so both interfaces present the same content.

Provide renderer commands equivalent to:

```swift
selectMode(_ mode: SimulationMode)
setExperimentAdjustment(_ adjustment: ExperimentAdjustment)
restartCurrentSimulation()
requestSingleStep()
setDisplayOptions(_ options: DisplayOptions)
```

Preserve the existing field-selection, pause, and tuning entry points where practical. Renderer state remains read-only to controllers.

Extract GPU evolution into a shared simulation component callable by both the renderer and offscreen integration tests. Its responsibilities are:

- Resetting or seeding fields.
- Encoding exactly one simulation step.
- Maintaining particle state and derived fields.
- Providing textures and buffers to visualization.

The view-facing renderer remains responsible for presentation, lifecycle, viewport mapping, and scheduling.

### Step, pause, and reset semantics

Separate **encoding a simulation step** from **encoding a display frame**.

- A normal running callback encodes one step.
- A paused redraw encodes no step.
- Each accepted Step command encodes exactly one step and remains paused.
- Reject Step while running, inactive, resetting, or complete.
- Queue rapid Step commands without combining or losing them.
- Cancel queued steps on reset, mode change, pause-to-run transition, or inactivity.
- Never advance hidden simulation time when returning from inactivity.
- A step must work without requiring a drawable; presentation can follow when one becomes available.

Reset all ping and pong fields, including pressure and intermediate quantities. Reset particle positions, history, script phase, counters, and pending input. Warm-started pressure from the previous experiment must not survive.

Preserve the existing in-flight semaphore discipline. Drain outstanding commands before replacing resources, and avoid blocking GPU waits in the normal frame loop.

### Grid and resize behaviour

Lessons use a **256 × 256** grid regardless of device, window size, orientation, or display scale.

Resizing during a lesson changes only its viewport. It must not resample fields, reseed particles, restart the lesson, or advance a step.

Free Play retains its current grid-sizing and field-resampling behaviour. Store particle positions and trail samples in normalized domain coordinates so they follow Free Play resizing without resets.

### Independent fading and damping

Replace the single effective retention parameter with:

- `dyeRetention`
- `velocityRetention`

Free Play defaults both to **0.998**, preserving the existing default behaviour. Keep Force and Dye defaults unchanged. Rename the Swirl label to **Swirl enhancement**.

For both fading sliders, use the same normalized mapping:

- 0% → retention 1.0
- 17% → retention 0.998
- 100% → retention 0.9905
- Linear interpolation between these anchors.

Zero means no explicit fading or damping. Explain that numerical advection can still smooth the fields.

Preserve the 208-byte Swift/Metal simulation-uniform layout by assigning:

- `tuning.x`: dye retention
- `tuning.y`: swirl enhancement
- `tuning.z`: velocity retention
- `tuning.w`: reserved

Keep the existing dye-advection entry point and add a velocity-advection entry point using the appropriate retention channel. Share their advection implementation. Update all production callers and GPU test fixtures together.

Lesson tuning is fixed: both retentions are 1.0, swirl enhancement is zero, no user dye injection, and 40 pressure iterations.

### Field visualization

Implement dedicated display mappings rather than reusing the current vector mapping for scalar fields.

| Field | Mapping and legend |
|---|---|
| Dye | Black through blue to pale cyan; use `c / (1 + c)` for nonnegative concentration. Legend: Less dye → More dye. |
| Velocity | Speed magnitude with a dark-purple → teal → yellow sequential palette. Legend: Slower → Faster. Always include direction arrows. |
| Vorticity | Orange for clockwise, neutral light grey for zero, blue for anticlockwise. |
| Pressure | Blue below the current spatial mean, neutral light grey at the mean, orange above it. Legend: Lower → Average → Higher. |

For speed, pressure, and vorticity, normalize against the current field’s maximum magnitude, with a small denominator floor of `1e-5`. Pressure normalization uses deviations from the current mean. Label these legends **“Colour scale adjusts to this frame.”**

Use GPU reductions with float32 accumulation for pressure statistics and field maxima. Keep the reduction results on the GPU and use them in the same command buffer as rendering. Qualitative native legends avoid per-frame numeric readback.

Recompute vorticity from the **final projected velocity** for display. Retain the earlier vorticity computation used by confinement separately in the step sequence.

Account for the texture’s downward-positive vertical coordinate: verify the displayed clockwise/anticlockwise sign with a synthetic rotating field.

Velocity arrows:

- Sample the final velocity.
- Use approximately 32-point spacing, with no more than 32 arrow positions per axis.
- Use fixed-length direction arrows; colour supplies speed magnitude.
- Suppress arrows where speed is below `1e-5`.
- Draw contrasting outlines so arrows remain visible over every field.
- Allow arrows over dye, pressure, and vorticity through the overlay toggle.

Changing any visualization option must not modify fluid or particle evolution.

### Passive particles and trails

Use **256 particles**, seeded on a deterministic 16 × 16 lattice spanning normalized coordinates 0.1 through 0.9 on each axis. There is no random seed or placement tool in this release.

Store positions as float32 normalized coordinates in GPU buffers. Advance particles with midpoint integration using the same advecting velocity field used by the dye during that step. Convert grid-cell velocity to normalized displacement explicitly.

Particles:

- Do not inject dye or forces.
- Continue advancing when hidden so display toggles do not change their trajectories.
- Clamp to the interior sampling region at boundaries; do not wrap or respawn.
- Remain finite, with invalid coordinates treated as a regression failure.

Keep a GPU ring buffer containing the last **64 positions per particle**. Draw chronological trail segments, fading older segments, without connecting the ring’s newest sample to its oldest. Reset clears all history.

Render particle markers with a dark outline and light centre. Render trails beneath markers and arrows above both. Clip every overlay to the simulation viewport.

Free Play defaults: particles off, trails off, optional arrows off. Lessons default: particles on, trails off, optional arrows on. Turning particles off hides trails; disabling Trails does not discard history.

Describe trails as “recent paths followed by marker particles.” Do not call them streamlines. The distinction follows the [MIT flow-visualization explanation](https://web.mit.edu/fluids-modules/www/potential_flows/LecturesHTML/lec02/tutorial/).

### Deterministic experiment construction

Use normalized coordinates with origin at the top-left. Generate initial fields in shared code, without wall-clock input or randomness.

For vortex templates, define:

```text
G(x, y; cx, cy, σ) =
    exp(-((x-cx)² + (y-cy)²) / (2σ²))

B(t) =
    smoothstep(0, 0.08, t) × smoothstep(0, 0.08, 1-t)

ψ(x, y) =
    B(x) × B(y) × sum(signed Gaussian vortex terms)

velocity =
    (centralDifferenceY(ψ), -centralDifferenceX(ψ))
```

Use grid-cell differences, zero the outer two velocity-cell rows and columns, then normalize the complete template to its specified maximum speed. These are initial or forcing templates; they do not replace subsequent solver evolution.

Store recipe constants centrally and cover them with tests.

| Lesson | Initial state and adjustment | Default view |
|---|---|---|
| **Dye carried by a flow** | One vortex at `(0.5, 0.5)`, σ `0.22`. One dye Gaussian at `(0.7, 0.5)`, σ `0.035`, peak `1`. Adjustment: initial flow speed `0.5`, `1.0`, or `1.5` grid cells per step; default `1.0`. | Dye concentration |
| **Two interacting vortices** | Two vortex terms at `(0.35, 0.5)` and `(0.65, 0.5)`, σ `0.10`; normalize their combined velocity to maximum speed `1.0`. Adjustment: same or opposite rotation; default same. Left term stays positive; right term changes sign. Seed dye Gaussians at `(0.35, 0.6)` and `(0.65, 0.6)`, σ `0.03`, peak `1`. | Vorticity |
| **Stretching dye by stirring** | Start with zero velocity and a dye stripe covering `x = 0.48…0.52`, `y = 0.2…0.8`, peak `1`, with a two-cell smooth edge. Apply the scripted stirring sequence below. Adjustment: gentle, normal, strong, multiplying force by `0.5`, `1.0`, `1.5`; default normal. | Dye concentration |

For the stretching lesson:

- Steps 0–119 apply the clockwise template centred at `(0.4, 0.5)`, σ `0.16`.
- Steps 120–239 apply the anticlockwise template centred at `(0.6, 0.5)`, σ `0.16`.
- Normalize each template to unit maximum magnitude.
- During each 120-step phase, multiply it by
  `0.04 × strength × sin²(π × (phaseStep + 0.5) / 120)`.
- Add this as a velocity impulse at the existing force stage.
- Steps 240–599 apply no further force or dye.

Use this lesson copy:

| Lesson | Question | What to notice |
|---|---|---|
| Advection | “Where will this patch of dye travel?” | “The flow carries the dye. Change the starting speed and compare its position after the same number of steps.” |
| Vortices | “How does reversing one vortex change their motion?” | “Compare the movement of the rotating regions when they turn in the same direction and in opposite directions.” |
| Stretching | “How can a narrow stripe spread through the fluid?” | “Stirring stretches and folds the stripe. Stronger stirring changes its shape more quickly. The solver also smooths fine details; this is not a measurement of molecular diffusion.” |

Treat the listed numerical constants as specified implementation defaults. Validate the observable lessons rather than assuming their visual success from the formulas alone. A failed demonstration is a release issue to resolve, not a reason to weaken its learning claim.

### Rendering infrastructure

The existing render wrapper uses `.dontCare` load actions, which would discard an already-rendered field during a separate overlay pass.

Add dedicated overlay pipeline support with:

- `.load` for an existing colour attachment.
- Explicit alpha blending.
- The same viewport and clipping as the base field.
- Cached pipeline states.

Keep overlay pipeline configuration distinct from the existing name-and-pixel-format cache key, or extend the key to include all relevant blend configuration.

New compute pipeline creation must fail with useful function-name context. Do not rely on the existing unused compute wrapper’s silent failure behaviour.

## 4. Implementation sequence and agent handoffs

Work in the following order. Each handoff must state what changed, which checks passed, and any unresolved acceptance failures. Parallel work is optional only after shared interfaces are fixed; this document does not request spawning agents.

| Stage | Responsibility | Required result |
|---|---|---|
| 1. State and step control | Shared state, renderer scheduling, reset lifecycle, independent retention, Xcode target membership | Exact single-step semantics and complete reset; existing Free Play regression checks pass. |
| 2. Experiment engine | Fixed lesson grid, viewport mapping, shared recipes, adjustment behaviour, scripted forces | All three lessons can run offscreen for a specified step count and restart reproducibly. |
| 3. Visualization | Field mappings, statistics reductions, final-velocity vorticity, arrow rendering, overlay pipelines | Synthetic fields produce correct colours, signs, directions, and compositing. |
| 4. Particles | GPU particle integration, history ring, marker/trail rendering | Tracers follow controlled fields and cannot change fluid results. |
| 5. Native interfaces | Mac and iOS controllers, shared copy, menus, accessibility, lesson layout | The full learning workflow works on Mac, iPhone, and iPad. |
| 6. Verification and documentation | Automated regressions, visual acceptance, performance observations, user documentation | Release criteria below are satisfied or explicitly recorded as unverified. |

The main existing implementation anchors are `Sources/Shared/Renderer.swift`, `Sources/Shared/Shaders.metal`, and `Sources/Shared/SimulationState.swift`.

Place new simulation, experiment, visualization, and particle helpers under the existing Shared group. Add shared sources to both application targets and to the Mac test target where required. Keep AppKit and UIKit out of shared simulation and recipe code.

Update standalone Swift harness compilation lists when shared dependencies change. Do not create a Swift package or a separate shared framework.

Preserve unrelated working-tree changes, including existing planning configuration edits and review documents.

## 5. Verification and definition of done

### State and lifecycle tests

Extend unit coverage to verify:

- One accepted Step advances exactly once and stays paused.
- Rapid Step requests are neither lost nor duplicated.
- Inactivity prevents advancement and preserves the user’s pause choice.
- Reset and mode changes clear queued steps and all pending input.
- Lesson selection, adjustment changes, restart, and completion follow the specified state transitions.
- Restart preserves the current lesson adjustment and presentation settings.
- Returning to Free Play restores its session preferences.
- Dye fading affects only dye retention; motion damping affects only velocity retention.
- Slider endpoints, the 17% default, and non-finite inputs are handled correctly.
- Swift/Metal uniform offsets remain aligned.

### GPU and simulation tests

Use the production step encoder through the existing Python/Swift GPU-harness approach. Tests must load the freshly built application’s Metal library.

Required cases:

- **Complete reset:** poison every field and particle/history buffer, reset, and verify the prescribed initial state.
- **Reproducibility:** run a lesson for 120 steps, restart with the same adjustment, and compare the resulting fields and particles after another 120 steps.
- **Scheduling equivalence:** 120 manual steps and 120 running steps produce matching results on the same device.
- **Display isolation:** toggling fields and overlays leaves fluid results unchanged.
- **Viewport isolation:** resizing and rotating a lesson viewport does not change simulation state.
- **Retention isolation:** dye-only fading preserves velocity in a controlled fixture; velocity-only damping preserves dye when transport is disabled in that fixture.
- **Zero fields:** produce finite neutral displays, stationary particles, and no arrows.
- **Uniform velocity:** arrows point correctly and particles move by the expected grid-to-normalized displacement.
- **Known rotation:** opposite rotating fixtures produce opposite labelled vorticity colours.
- **Pressure offset:** adding a constant to pressure does not change its mean-relative visualization.
- **Final vorticity:** displayed vorticity matches a reference curl of the final velocity.
- **History ordering:** trails remain chronological before and after ring-buffer wrap, and reset creates no stray segments.
- **Compositing:** overlay passes preserve the underlying field image.

Use exact equality for integer state and deterministic seed data. For GPU floating-point comparisons, use a documented tolerance appropriate to the stored format; start with relative `1e-3` and absolute `1e-4`. Do not replace state comparisons with screenshots.

### Lesson acceptance

Capture each lesson at steps 0, 120, 240, and 600.

- **Advection:** the dye visibly moves around the circulation; the faster initial setting moves it farther during the early observation interval.
- **Vortices:** reversing the second vortex changes the pair’s evolution; both rotation directions are correctly identifiable.
- **Stretching:** the stripe develops visible curvature and elongation during the scripted forcing, with a clear difference between gentle and strong settings.
- No lesson produces NaNs, invalid particles, unexplained discontinuities, or a blank canvas.
- Restart reproduces the same observation sequence on the tested device.

Include offscreen measurements supporting these observations, such as dye-centroid displacement, vortex-region movement, and elongation of a seeded material line. Numerical seed tests alone do not establish educational success.

### UI and platform checks

Update existing HUD tests for the new labels and tuning controls. Add coverage for choosing every lesson, running, pausing, stepping, restarting, changing its adjustment, toggling overlays, completion, and returning to Free Play.

Verify:

- The Mac controls panel reopens without changing simulation state.
- All commands are reachable by keyboard and focused controls do not trigger canvas shortcuts.
- iPhone and iPad layouts work in portrait and landscape, including large text.
- Lesson controls do not cover the square canvas.
- Free Play retains mouse, touch, tap, and pause behaviour.
- HUD interactions do not inject fluid.
- Paused field and overlay changes redraw without incrementing the step count.

Run the existing build and regression commands:

```bash
xcodebuild -project FluidDynamicsMetal.xcodeproj \
  -scheme FluidDynamicsMetalOSX -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  CODE_SIGNING_ALLOWED=NO build

xcodebuild -project FluidDynamicsMetal.xcodeproj \
  -scheme FluidDynamicsMetaliOS -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build

xcodebuild test -project FluidDynamicsMetal.xcodeproj \
  -scheme FluidDynamicsMetalOSX -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  CODE_SIGNING_ALLOWED=NO

python3 -m unittest discover -s Tests/Integration
```

Discover current simulator IDs using `xcrun simctl list devices available`, then run the iOS scheme’s tests on both an available iPhone and iPad simulator.

Both apps retain Swift 6 language mode, require Swift 6.2+/Xcode 26+, and target macOS/iOS 26+. Do not override deployment targets to make checks pass.

### Performance and documentation

Target 60 frames per second for the fixed lesson grid. Record frame/GPU timings with overlays off and with all overlays on, using identified hardware. Verify bounded resource allocation and no per-frame synchronous GPU readback. Investigate sustained lesson performance below 30 frames per second on tested supported hardware.

Update the README’s controls and manual checks. Update the editable equations document for the changed retention semantics, final-vorticity display, fixed lesson grid, and particle integration. Explain step-based repeatability and the unchanged solver limitations.

Record actual test environments. A newer macOS host does not verify macOS 26 runtime behaviour, and simulator testing does not establish physical-device multitouch behaviour. Mark unavailable checks **NOT TESTED**.

The release is complete when the three lessons satisfy their observable learning goals, automated checks pass, and the native workflow has been visually reviewed on Mac, iPhone, and iPad with any remaining hardware coverage gaps explicitly recorded.
