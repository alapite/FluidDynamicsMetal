# Phase 7: First 3D Fluid Vertical Slice - Context

**Gathered:** 2026-11-06
**Status:** Ready for planning

<domain>
## Phase Boundary

Add a selectable Mac-only 3D dye-advection lesson using a genuine evolving 64³ fluid volume, visible through one fixed dye slice. Deliver paused entry at step 0, Run/Pause/Resume, exactly one logical advance per paused Step action, inactivity without advancement or catch-up, and safe transitions back to the established 2D modes. Include production-kernel numerical checks and an early performance baseline with this first visible slice.

Phase 7 owns SIM-04/05/06, LES-01/02/06, and VER-03. Phase 8 adds orbit/zoom/reset camera, movable axis-aligned slices, and passive 3D tracers. Phase 9 owns the complete restart/speed-comparison/600-step teaching and repeatability contract. Phase 10 adds volume rendering and final measured release quality. Do not pull these later capabilities into this phase merely because related 2D controls already exist.

</domain>

<decisions>
## Implementation Decisions

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

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.** Current milestone requirements and live source supersede older historical descriptions.

### Scope and acceptance
- `.planning/ROADMAP.md` §Phase 7 — phase goal, seven owned requirements, observable success criteria and numerical planning focus; §§Phases 8–10 — delivery boundaries.
- `.planning/REQUIREMENTS.md` — approved v1.1 requirements and Acceptance Conventions, especially true evolving 3D, numerical-contract definition, state separation, step semantics, regression preservation and coverage honesty.
- `.planning/PROJECT.md` — fixed 64³ Mac-first foundation, established 2D preservation, and milestone choices already approved on 2026-11-06.
- `AGENTS.md` — current source layout, Xcode schemes/toolchain, target membership, build/test commands and runtime-coverage limits.

### Existing release and behavioural continuity
- `README.md` §§Learning with the simulation, Controls and manual checks — actual current transport, reset, session preferences, keyboard/menu controls and separate movable Mac panel.
- `docs/educational-release-verification.md` — current educational-release baseline and verification protocol; historical results are not new Phase 7 evidence.
- `.planning/milestones/v1.0-phases/03-reliable-simulation-state/03-CONTEXT.md` — separation of manual pause from inactivity, no catch-up/stale input, presentation without unintended evolution.
- `.planning/milestones/v1.0-phases/04-discoverable-visualization/04-CONTEXT.md` — native labelled controls, shared state and input isolation. Its in-canvas Mac HUD location is superseded by the current separate controls panel.
- `.planning/milestones/v1.0-phases/05-live-fluid-tuning/05-CONTEXT.md` — historical bounded-tuning/2D continuity preferences. Current separate dye fading and motion damping supersede the old combined Fade description; do not apply it to the 3D lesson.

### Numerical and architecture research
- `.planning/research/SUMMARY.md` — v1.1 research synthesis, phase sequencing, unresolved numerical risks and confidence limits.
- `.planning/research/ARCHITECTURE.md` — proposed separate 3D evolution/storage/recipe/visualization responsibilities and presentation-independent encoder integration; recommendations are not implemented guarantees.
- `.planning/research/STACK.md` — retained Swift/Metal stack, 3D compute resources and early measurement guidance.
- `.planning/research/PITFALLS.md` — compatible projection, nonplanar evidence, visibility, numerical diffusion and performance pitfalls.
- `.planning/codebase/STACK.md`, `.planning/codebase/ARCHITECTURE.md`, `.planning/codebase/STRUCTURE.md` — historical codebase maps, dated 2026-09-24. Their Swift versions, deployment targets, paths, test availability and renderer responsibilities are stale; use current source, `AGENTS.md` and `README.md` as authoritative.

No additional external spec or ADR was supplied during this discussion. No phase SPEC.md exists; approved requirements remain in `.planning/REQUIREMENTS.md`.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Sources/macOS/RenderViewController.swift`: current movable `NSPanel`, selector, Simulation menu, pinned transport/step count, scrolling control body, keyboard-focus handling, and app/minimise lifecycle routing. Extend this panel rather than recreating the historical floating canvas HUD.
- `Sources/Shared/SimulationState.swift`: `SimulationMode`, deterministic lesson entry, pending-step queue, inactivity flags and manual pause, Free Play preference restoration, and step-based transport. Existing `.experiment` assumptions are 2D-specific and need explicit 3D routing.
- `Sources/Shared/Renderer.swift`: central mode changes, input clearing, resource replacement, paused redraw, scheduling, offscreen-capable step encoding and presentation separation. Currently dispatches to a 2D `FluidSimulation`; a genuine 3D path is additional work.
- `Sources/Shared/FluidSimulation.swift`: established view-independent production-encoder pattern. `Sources/Shared/ExperimentRecipes.swift` demonstrates pure deterministic seed construction, but its 256² formulas must not be extruded to claim 3D.
- `Sources/Shared/FieldVisualization.swift`, `Sources/Shared/MetalDevice.swift`, `Sources/Shared/ComputeShader.swift`: existing display/resource/compute helpers to assess for reuse without changing the 2D algorithm.
- `Tests/Integration/test_educational_release.py` and `Tests/Integration/test_educational_release.swift`: compile production Swift sources, load the built Mac app's actual Metal library, enable Metal validation, and emit numerical/visual/timing artifacts. Add analogous first-3D checks rather than a separate toy solver.

### Established Patterns
- Shared Swift/Metal sources compile directly into both Xcode app targets; there is no Swift package. Mac-only exposure must not put an unsupported 3D choice in the iOS selector or break its build/state assumptions.
- Current selectors and menu items use positional `SimulationMode.allCases` indexing/tags. Nonselectable group headings require robust mode mapping, and existing Command-1–4 selections must not shift onto headers or different lessons.
- `SimulationState.consumeStep()` counts encoded logical advances; `Renderer.draw(in:)` can encode without a drawable. Paused presentation redraws must not consume an unrequested step.
- Current lesson views use a fixed square viewport; resizing does not recreate their grid. Keep the 3D numerical grid fixed at 64³ independently of the window/drawable.
- Existing 2D lessons use 600-step completion and restart machinery. Reuse deliberately, but reserve complete 3D speed/restart/completion/repeatability validation for Phase 9.
- Swift/Metal uniform layouts and literal shader entry-point names are cross-language contracts. Separate 3D uniforms/kernels must not silently alter the established 2D ones.

### Integration Points
- `Sources/macOS/RenderViewController.swift`: grouped selector/menu, panel heading/legend/copy, mode-specific visibility, S no-op, clear failure presentation and input clearing.
- `Sources/Shared/SimulationState.swift` and `Sources/Shared/Renderer.swift`: 3D mode identity, paused entry, routing, lifecycle, pending steps, safe resource initialisation/transition and preserved 2D behaviour.
- New 3D simulation/storage/recipe/visualization code and Metal kernels, with reuse of existing utilities where appropriate; final file/component design belongs to research/planning.
- `Sources/iOS/RenderViewController.swift`: audit shared mode-enumeration changes so iOS remains 2D-only and existing interactions remain unchanged.
- `FluidDynamicsMetal.xcodeproj/project.pbxproj`, `Tests/Unit/`, `Tests/UI/macOS/`, `Tests/Integration/`: correct source membership, state/HUD navigation and transport checks, production-kernel fixtures and regression coverage.

</code_context>

<specifics>
## Specific Ideas

Open the existing experiment list, choose **3D → 3D Dye Advection**, and see an amber patch paused at **Step 0** in a face-on square. The controls panel identifies **XY slice · halfway through Z** and explains that dye may move out of the plane. Run or Step shows smooth rolling transport; the image itself stays uncluttered. Switching back to 2D restores the established controls and selection/reset behaviour. Numerical fixtures, not this single slice alone, establish that the evolution is genuinely three-dimensional.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope. Existing roadmap boundaries remain: Phase 8 owns camera, movable slices and passive 3D tracers; Phase 9 owns the full comparative teaching/restart/completion/repeatability contract; Phase 10 owns volume presentation and final measured quality. Mobile 3D, injection, other 3D fields, trails and higher resolutions remain outside this milestone. Actual macOS 26 runtime and physical-device multitouch remain NOT TESTED until exercised.

</deferred>

---

*Phase: 07-first-3d-fluid-vertical-slice*
*Context gathered: 2026-11-06*
