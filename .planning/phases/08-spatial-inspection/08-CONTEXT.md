# Phase 8: Spatial Inspection - Context

**Gathered:** 2026-11-13
**Status:** Ready for planning

<domain>
## Phase Boundary

Extend the Mac-only 64³ 3D dye-advection lesson with orbit/zoom/reset camera controls, spatial orientation cues, one movable XY/XZ/YZ dye cross-section, and independently visible passive 3D tracers. Inspection must work while paused and must not change the experiment: camera, slice, visibility and window-size changes preserve complete evolution-dependent state at equal logical step counts. New controls are labelled, native and keyboard-operable; camera/control gestures never inject fluid or trigger each other's actions.

Phase 8 owns INS-01/02/03/04 and CTRL-08. Phase 9 retains ownership of speed comparison, complete 600-step teaching/completion and full restart-repeatability qualification. Phase 10 retains volume rendering, slice/volume selection and integrated measured release quality. Recheck restart preservation as these inspection choices are added without claiming later-phase acceptance.

</domain>

<decisions>
## Implementation Decisions

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

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.** Live source, current milestone requirements and the numerical contract supersede stale historical maps.

### Scope, acceptance and inherited decisions
- `.planning/ROADMAP.md` §Phase 8 — five owned requirements, observable success criteria and planning focus; §§Phases 9–10 — later-phase boundaries.
- `.planning/REQUIREMENTS.md` — INS-01/02/03/04, CTRL-08 and Acceptance Conventions covering presentation independence, full state, restart preservation, regression and coverage honesty.
- `.planning/PROJECT.md` — Mac-first fixed 64³ foundation, preserved 2D experience and approved milestone constraints.
- `AGENTS.md` — source/target layout, Xcode schemes and Swift/toolchain baseline, build/test commands and limits on runtime claims.
- `.planning/phases/07-first-3d-fluid-vertical-slice/07-CONTEXT.md` — current amber dye, native panel, no injection, transport, recovery and phase boundaries. This Phase 8 context explicitly supersedes its fixed face-on-only/no-guides presentation restrictions, not its solver/state safeguards.

### Numerical and delivered UI contracts
- `docs/3d-numerical-contract.md` — world `[0,1]³`, cell-centred dye and staggered u/v/w layout, reflected walls, step/pass definitions, pressure/precision amendments and fixed-slice midpoint/orientation conventions. Existing numerical gates remain binding.
- `.planning/phases/07-first-3d-fluid-vertical-slice/07-UI-SPEC.md` — delivered Mac 3D panel, transport, native focus/semantics, copy and amber concentration legend; extend its patterns rather than retaining obsolete fixed-slice descriptions literally.
- `docs/3d-phase7-verification.md` — delivered solver/fixed-slice evidence, offscreen-only timing and explicitly unperformed manual checklist. Historical fixed-slice/no-guides checklist items describe Phase 7, not new Phase 8 acceptance.
- `README.md` — current Mac lesson usage, Simulation Controls panel, keyboard/menu behaviour, builds and separate platform verification instructions.

### Historical continuity and architecture background
- `.planning/milestones/v1.0-phases/04-discoverable-visualization/04-CONTEXT.md` — native labelled control, paused-presentation and input-isolation preferences. Its historical floating Mac HUD location is superseded by the delivered separate controls panel.
- `.planning/milestones/v1.0-phases/05-live-fluid-tuning/05-CONTEXT.md` — existing native continuous-slider and bounded-value continuity; do not introduce Free Play tuning into scripted 3D or carry over obsolete combined Fade semantics.
- `.planning/codebase/STACK.md` — historical stack map only; its 2026-09-24 language/deployment versions, paths and test availability are stale.
- `.planning/codebase/ARCHITECTURE.md` — historical controller/renderer/Metal contracts; current separate 2D/3D evolution and presentation responsibilities must be read from live source.
- `.planning/codebase/STRUCTURE.md` — historical target ownership map; use current `Sources/{macOS,iOS,Shared}` and `Tests/` paths from live source and `AGENTS.md`.

No external spec or ADR was supplied during this discussion. No phase SPEC.md exists; approved requirements are in `.planning/REQUIREMENTS.md`. No matching pending todos or packaged/raw spike/sketch findings were found.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Sources/macOS/RenderViewController.swift`: separate native NSPanel, pinned selector/transport/counter, scrolling 3D body, continuous NSSlider patterns, labelled controls/accessibility identifiers, keyboard handling and existing mode/lifecycle routing. The 3D body currently contains a fixed-slice descriptor/legend/note, not camera or slice widgets.
- `Sources/Shared/FieldVisualization3D.swift`: read-only fixed central XY render pass, square fitting, fixed amber transfer function, destination validation and palette shared with the panel legend. It currently has no orbit transforms, arbitrary axis/depth selection, depth attachment or 3D markers; these are actual new work.
- `Sources/Shared/FluidSimulation3D.swift`: production fixed-grid u/v/w/dye storage, deterministic reset, guarded step encoding, diagnostic fields and pressure status. Its view-independent evolution supplies tracer sampling and complete-state checks, not a new visualization-driven solver path.
- `Sources/Shared/SimulationTypes3D.swift`, `Sources/Shared/VolumeField3D.swift`, `Sources/Shared/Shaders3D.metal`: fixed 64³ configuration, separate 3D Swift/Metal ABI, staggered volume fields and production sampling kernels. Keep new inspection uniforms separate from established numerical and 2D ABI contracts.
- `Sources/Shared/ParticleSystem.swift`: existing 2D reset/advance/display separation is a useful pattern, **not** an existing 3D tracer implementation. Its 2D positions, packed velocity sampling and trails cannot simply satisfy three-component 3D tracing.
- `Tests/Integration/test_fluid3d.py`, `Tests/Integration/test_fluid3d.swift`, `Tests/Integration/fluid3d_reference.swift`: production-metallib GPU harness, reference fixtures, readback, slice orientation/palette tests and renderer presentation/step checks. Extend these with asymmetric multi-axis slices, tracer evolution/occlusion and presentation-independence cases rather than a toy implementation.

### Established Patterns
- `Sources/Shared/Renderer.swift` owns transactional 3D initialization/restart, generation-fenced completion diagnostics, safe 2D recovery, exact encode-before-consume stepping and presentation routing. It can advance with no drawable; paused redraw must not consume a step. Preserve these properties when adding tracer reset/advance and camera redraws.
- `Sources/Shared/SimulationState.swift` is the shared source of truth for mode, pause/inactivity, pending steps and capabilities. Its current display options are 2D-specific; add deliberately separated 3D inspection state instead of reviving hidden 2D particles/field controls.
- Current Mac mouse-down/drag forwarding is guarded by `shouldAdvance`; camera gestures must work paused and require explicit 3D routing before that 2D injection guard. Add scroll zoom without turning panel scroll events into camera zoom.
- Shared sources compile directly into both Xcode targets, not a package. Mac-only feature exposure must not break iOS compilation or expose 3D controls there. Window/drawable sizes do not define the fixed production grid.

### Integration Points
- `Sources/macOS/RenderViewController.swift`: native inspection section, dynamic slice/depth/canvas accessibility text, keyboard camera operation, Show Tracers, Reset Camera, Centre Slice and exclusive pointer/scroll/focus routing.
- `Sources/Shared/SimulationState.swift`, `Sources/Shared/Renderer.swift`: inspection mutation/redraw APIs, preserved restart choices, deterministic tracer reset/step scheduling independent of visibility/drawables and numerical-state protection.
- `Sources/Shared/FieldVisualization3D.swift`, `Sources/Shared/Shaders3D.metal` and new camera/tracer components as justified by planning: spatially consistent two-sided planes, cube/axis cues and depth-occluded markers. Final decomposition is not locked here.
- `FluidDynamicsMetal.xcodeproj/project.pbxproj`, `Tests/Unit/`, `Tests/UI/macOS/`, `Tests/Integration/`: appropriate source membership, native keyboard/focus/gesture and state coverage, production GPU fixtures and both-target regression builds. `Sources/iOS/RenderViewController.swift` remains 2D-only.

</code_context>

<specifics>
## Specific Ideas

Enter **3D Dye Advection** paused at **Step 0**, looking slightly down at the central amber XY sheet inside a subdued wireframe cube. Sparse pale-cyan dots reveal motion throughout the volume, with a small corner X/Y/Z guide. Drag to orbit and scroll to zoom, even while paused. Select XZ and move `Y depth` to 30%; changing to YZ keeps 30% but names `X depth`, without rotating the camera. **Centre Slice** returns only the depth to 50%; **Reset Camera** returns only the view. Behind-sheet tracers are hidden honestly, and hidden tracers keep their correct step-based positions. **Restart** resets the fluid and marker trajectories but keeps the chosen inspection view.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope. Existing boundaries remain: Phase 9 owns speed-comparison teaching and full restart-repeatability/completion qualification; Phase 10 owns volume rendering, volume/tracer compositing and final measured performance. Mobile 3D, freehand injection, additional fields, trails, arbitrary oblique/multiple slices, higher resolutions and cinematic rendering remain outside this phase.

Phase 7's six user-facing requirements remain pending manual acceptance; this context does not reopen or claim to complete their review. Actual macOS 26 runtime and physical mobile multitouch remain NOT TESTED until exercised. Displayed frame pacing remains NOT MEASURED.

</deferred>

---

*Phase: 08-spatial-inspection*
*Context gathered: 2026-11-13*
