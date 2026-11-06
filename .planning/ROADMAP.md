# Roadmap: FluidDynamicsMetal

## Milestones

- [x] **v1.0 Modernization** — Phases 1–6, 14/14 implementation plans complete (closed 2026-09-25). [Full roadmap](milestones/v1.0-ROADMAP.md) · [requirement outcomes](milestones/v1.0-REQUIREMENTS.md). PLAT-01 actual macOS 26 runtime remains NOT TESTED and explicitly deferred beyond this milestone.
- [ ] **v1.1 3D Teaching Foundation** — Phases 7–10, 23 approved requirements. Mac-first 64³ dye-advection lesson, spatial inspection, and basic volume rendering. Roadmap approved 2026-11-06.

The post-v1.0 educational release (`07703e2`, documented 2026-10-13) established the current Swift 6 / three-lesson 2D baseline outside the GSD phase sequence. See `docs/educational-release-verification.md`. Phase numbering continues from the last GSD phase, 6.

## v1.1 — 3D Teaching Foundation

**Goal:** Let learners explore a genuine three-dimensional dye-advection experiment on Mac, with clear views into the fluid and measured numerical/performance behaviour.

**Scope:** One deterministic lesson, fixed 64³ volume, Mac delivery, focused dye inspection, and a 30 fps floor at 1280×720 on a named available Apple Silicon reference Mac. Other 3D lessons, mobile 3D, freehand injection, additional field views, and trails are deferred.

## Phases

- [ ] **Phase 7: First 3D Fluid Vertical Slice** — Select and step a real 3D fluid on Mac through a basic slice, backed by numerical checks.
- [ ] **Phase 8: Spatial Inspection** — Explore depth using camera controls, movable slices, and passive tracers without changing the experiment.
- [ ] **Phase 9: Repeatable 3D Advection Lesson** — Compare initial speeds through an explained, restartable 600-step lesson.
- [ ] **Phase 10: Volume View and Measured Release Quality** — View the dye volume and meet the measured performance and regression contract.

## Phase Details

### Phase 7: First 3D Fluid Vertical Slice

**Goal**: Users can select a genuine evolving 3D fluid on Mac, inspect its initial behaviour through a basic slice, and control its advancement with numerical evidence supporting the result.
**Depends on**: Current educational release baseline (first phase of v1.1)
**Requirements**: SIM-04, SIM-05, SIM-06, LES-01, LES-02, LES-06, VER-03
**Success Criteria** (what must be TRUE):

1. A Mac user can select the 3D dye-advection lesson and see a nonblank fixed slice of a 64³ volume whose depth-varying velocity transports dye nonplanarly; production GPU evidence distinguishes it from an extruded 2D simulation.
2. Entry is paused at step 0; Run/Pause/Resume updates a visible step counter, and each paused Step action advances exactly once.
3. App inactivity freezes evolution and reactivation introduces no catch-up steps; switching back to 2D restores the established mode-selection/reset behaviour without stale input.
4. The production encoder passes documented three-axis advection, compatible projection, all-six-face boundary, and finite-value fixtures. Reference results and tolerances are defined before acceptance; both pressure residual and post-projection divergence are measured.

**Plans**: 9 plans in 8 waves

Plans:
**Wave 1**

- [ ] 07-01-PLAN.md — Preregister the numerical contract and prove independent CPU reference feasibility.
- [ ] 07-05-PLAN.md — Define explicit 3D state/transport capabilities and preserve mobile 2D-only availability.

**Wave 2** *(blocked on Wave 1 completion)*

- [ ] 07-02-PLAN.md — Verify production 3D storage, ABI, all-axis advection and boundary sampling.

**Wave 3** *(blocked on Wave 2 completion)*

- [ ] 07-03-PLAN.md — Complete compatible GPU projection and production reset/step with finite-state checks.

**Wave 4** *(blocked on Wave 3 completion)*

- [ ] 07-04-PLAN.md — Validate the fixed amber XY slice and readable genuine-3D seed/early window.

**Wave 5** *(blocked on Wave 4 completion)*

- [ ] 07-06-PLAN.md — Integrate transactional renderer routing, exact steps, inactivity and usable 2D rollback.

**Wave 6** *(blocked on Wave 5 completion)*

- [ ] 07-07-PLAN.md — Expose native grouped navigation, panel/copy/legend, focus and recovery UI.

**Wave 7** *(blocked on Wave 6 completion)*

- [ ] 07-08-PLAN.md — Record fresh numerical/regression evidence, early performance baseline and scoped usage.

**Wave 8** *(blocked on Wave 7 completion)*

- [ ] 07-09-PLAN.md — Prepare the verified app and complete an explicit human visual/interaction checkpoint.

**Cross-cutting constraints:**

- The established 2D solver and its Swift/Metal ABI remain unchanged.

**UI hint**: yes

Planning focus: define grid locations, units, time-step/order, interpolation, boundary conditions, precision, and pressure acceptance before kernel implementation. Evaluate staggered MAC operators rather than porting inconsistent stencils. Include minimal Mac entry/display/transport and offscreen verification in this vertical slice. Establish a performance baseline early. Existing 2D regressions and both-target builds remain constraints throughout.

### Phase 8: Spatial Inspection

**Goal**: Users can understand spatial motion through camera, slice, and tracer controls while inspecting exactly the same simulated experiment.
**Depends on**: Phase 7
**Requirements**: INS-01, INS-02, INS-03, INS-04, CTRL-08
**Success Criteria** (what must be TRUE):

1. Users can orbit, zoom, and reset the camera with visible orientation cues, including while paused.
2. Users can choose XY, XZ, or YZ dye slices and move their depth; asymmetric volume fixtures confirm axis labels and sampled positions agree.
3. Passive markers move through the same 3D velocity field as the dye, can be hidden/shown, and retain their correct equal-step positions while hidden.
4. Camera, slice, visibility, and resize changes preserve the 64³ grid and complete simulated state at equal step counts, verified against a presentation-independent reference run.
5. Labelled native controls are keyboard-operable, and control/camera gestures are isolated from fluid injection and from each other's actions.

**Plans**: TBD
**UI hint**: yes

Planning focus: coherent world/texture/screen conventions, bounds and camera recovery, readable slice orientation/depth, deterministic tracer seeding/advection, and event routing. Keep the native interface consistent with existing Mac patterns. Recheck restart preservation when new inspection choices are introduced.

### Phase 9: Repeatable 3D Advection Lesson

**Goal**: Users can predict, observe, and repeat a meaningful comparison of three initial speeds through a complete 3D teaching lesson.
**Depends on**: Phase 8
**Requirements**: LES-03, LES-04, LES-05, EDU-01, EDU-02, EDU-03, VER-04
**Success Criteria** (what must be TRUE):

1. Users can select slow/normal/fast initial speeds; each change restarts paused at step 0, and Restart retains the current speed and inspection choices while clearing all evolution-dependent state and pending steps/input.
2. The lesson stops exactly at step 600 with a completion message; Run and Step cannot advance further, but inspection and restart remain available.
3. A prediction question and explanation identify the observed 3D transport, and a documented equal-step comparison demonstrates the intended speed ordering while dye remains visible.
4. Lesson text correctly explains concentration, step-based progression, and numerical smoothing, without claiming calibrated physical time or a free-surface water model.
5. Production GPU checks reproduce complete fluid and tracer state after restart at specified equal step counts on the same device, within predetermined tolerances for all three speed choices.

**Plans**: TBD
**UI hint**: yes

Planning focus: choose and validate an early comparison window or justified transport metric so circulation does not reverse the teaching claim. Capture representative lesson states and distinguish numerical diffusion from explicit decay. Calibrate speeds/seed parameters using numerical and visual evidence, not camera motion.

### Phase 10: Volume View and Measured Release Quality

**Goal**: Users can choose an understandable transparent volume view and run the integrated 3D lesson at the measured baseline performance while the existing apps retain their behaviour.
**Depends on**: Phase 9
**Requirements**: INS-05, INS-06, VER-05, VER-06
**Success Criteria** (what must be TRUE):

1. Users can view the dye as a transparent volume from different camera angles; empty, constant, and asymmetric fixtures verify sampling/compositing, and the view remains readable for the lesson's nonuniform dye.
2. Users can choose slice or volume presentation and independently toggle tracers; switching while paused preserves state, restart retains the choices, and marker visibility/depth has an explicit, visually checked compositing policy.
3. At 64³ and an explicitly configured 1280×720 output, both slices-plus-tracers and volume-plus-tracers sustain measured presentation of at least 30 fps on a named available Apple Silicon reference Mac. The report includes frame-interval distribution, GPU timing, resource usage, configuration, warm-up and sample protocol; 60 fps is a goal.
4. Both no-override app builds and applicable existing 2D state/HUD/GPU regression checks pass, and documented Mac 3D usage/manual verification covers mode transitions, inspection, lesson comparison, restart, and completion. Any unavailable runtime/hardware checks are explicitly recorded.

**Plans**: TBD
**UI hint**: yes

Planning focus: bounded ray-box sampling, sample-distance-aware opacity, tracer compositing, and drawable-size-independent simulation. Define benchmark conditions before optimizing; do not trade away numerical/lesson acceptance to meet frame rate. Regression preservation is ongoing work from Phase 7; this phase owns the final integrated evidence and usage documentation.

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 7. First 3D Fluid Vertical Slice | 0/9 | Planned | — |
| 8. Spatial Inspection | 0/TBD | Not started | — |
| 9. Repeatable 3D Advection Lesson | 0/TBD | Not started | — |
| 10. Volume View and Measured Release Quality | 0/TBD | Not started | — |

## Coverage and Review

- 23/23 approved v1.1 requirements map to exactly one phase: Phase 7 (7), Phase 8 (5), Phase 9 (7), Phase 10 (4).
- Dependency order is sequential; every phase delivers an observable capability. Numerical checks accompany the solver; presentation-independence and repeatability checks accompany the relevant features.
- Inline review checked approved scope, current-code integration, requirement ownership, 2–5 observable success criteria per phase, and numerical/performance research findings. This is an inline review, not independent-agent verification.
- Phase 7 has nine executable plans with inline checking, all seven owned requirements and D-01–17 mapped. Execution starts with independent numerical references and state-capability work; no implementation or runtime acceptance is implied by planning completion.

## Deferred Verification

- When prioritized, test Mac launch and drag on an actual macOS 26 Apple Silicon host or Metal-capable guest; update [Phase 1 UAT](milestones/v1.0-phases/01-modern-mac-baseline/01-HUMAN-UAT.md) and verify PLAT-01. This does not block v1.0 closure (user decision, 2026-09-25).
- Physical iOS two-finger/concurrent-touch checks remain NOT TESTED and non-blocking; see [Phase 2 UAT](milestones/v1.0-phases/02-modern-ios-parity/02-HUMAN-UAT.md).
