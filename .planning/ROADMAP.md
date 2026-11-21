# Roadmap: FluidDynamicsMetal

## Milestones

- [x] **v1.0 Modernization** — Phases 1–6, 14/14 implementation plans complete (closed 2026-09-25). [Full roadmap](milestones/v1.0-ROADMAP.md) · [requirement outcomes](milestones/v1.0-REQUIREMENTS.md). PLAT-01 actual macOS 26 runtime remains NOT TESTED and explicitly deferred beyond this milestone.
- [ ] **v1.1 3D Teaching Foundation** — Phases 7–10, 23 approved requirements. Mac-first 64³ dye-advection lesson, spatial inspection, and basic volume rendering. Roadmap approved 2026-11-06.

The post-v1.0 educational release (`07703e2`, documented 2026-10-13) established the current Swift 6 / three-lesson 2D baseline outside the GSD phase sequence. See `docs/educational-release-verification.md`. Phase numbering continues from the last GSD phase, 6.

## v1.1 — 3D Teaching Foundation

**Goal:** Let learners explore a genuine three-dimensional dye-advection experiment on Mac, with clear views into the fluid and measured numerical/performance behaviour.

**Scope:** One deterministic lesson, fixed 64³ volume, Mac delivery, focused dye inspection, and a 30 fps floor at 1280×720 on a named available Apple Silicon reference Mac. Other 3D lessons, mobile 3D, freehand injection, additional field views, and trails are deferred.

## Phases

- [ ] **Phase 7: First 3D Fluid Vertical Slice** — All 9 original plans are closed; phase-level user-facing acceptance remains incomplete, with six requirements pending manual acceptance. UAT 2026-11-20 gap closure (G-07-2, G-07-5): 4 plans (07-10 to 07-13) planned. 2026-11-21 G-07-2 re-plan after 07-12: 07-14 to 07-17 added, and 07-13 re-sequenced to run last.
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

**Plans**: 13/17 plans executed (9 original plans in 8 waves, all closed; 8 UAT gap-closure plans in 7 gap waves)

Plans:
**Wave 1**

- [x] 07-01-PLAN.md — Preregister the numerical contract and prove independent CPU reference feasibility.
- [x] 07-05-PLAN.md — Define explicit 3D state/transport capabilities and preserve mobile 2D-only availability.

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 07-02-PLAN.md — Verify production 3D storage, ABI, all-axis advection and boundary sampling.

**Wave 3** *(ready after Wave 2 completion)*

- [x] 07-03-PLAN.md — Complete compatible GPU projection and production reset/step with finite-state checks.

**Wave 4** *(blocked on Wave 3 completion)*

- [x] 07-04-PLAN.md — Validate the fixed amber XY slice and readable genuine-3D seed/early window.

**Wave 5** *(blocked on Wave 4 completion)*

- [x] 07-06-PLAN.md — Integrate transactional renderer routing, exact steps, inactivity and usable 2D rollback.

**Wave 6** *(blocked on Wave 5 completion)*

- [x] 07-07-PLAN.md — Expose native grouped navigation, panel/copy/legend, focus and recovery UI.

**Wave 7** *(blocked on Wave 6 completion)*

- [x] 07-08-PLAN.md — Record fresh numerical/regression evidence, early performance baseline and scoped usage.

**Wave 8** *(blocked on Wave 7 completion)*

- [x] 07-09-PLAN.md — Record the documentation closeout under user direction; keep the human visual/accessibility/interaction review explicitly pending.

**UAT gap closure (2026-11-20; G-07-2, G-07-5)**

**Gap Wave 1**

- [x] 07-10-PLAN.md — G-07-5: route paused 2D presentation and paused Step through MTKView.draw() (headless spy + real-window regression); panel-key Command-M minimizes the canvas.
- [x] 07-11-PLAN.md — G-07-2: preregister human-calibrated early-window gates as a dated contract amendment, recalibrate the lesson blob/speed within a bounded envelope, add the 600-step lesson-recipe check and fail-closed validation.

**Gap Wave 2** *(blocked on Gap Wave 1)*

- [x] 07-12-PLAN.md — Prepare the exact final app and obtain the user's blocking re-observation of UAT tests 2 and 5. *(Closed with issues 2026-11-21: G-07-5 passed on re-observation; G-07-2 still OPEN, so 07-13 is blocked pending replan.)*

**G-07-2 re-plan (2026-11-21; user-selected fixes: brighter low-concentration display, bigger blob, longer 3D lesson)**

**Gap Wave 3**

- [x] 07-14-PLAN.md — Fixed square-root display transfer in both 3D slice shaders, the Swift palette and the native legend, with honest copy. Adds the inspection-contract amendment and repin, and repairs the stale PHASE7_HASH.

**Gap Wave 4** *(blocked on 07-14)*

- [ ] 07-15-PLAN.md — Preregister the S1/S2/R1/E7' and lesson-length amendment plus item 8, the 2026-11-21 seed-speed decision (speed 0.17 failed E7' over 1800 steps), from the uncommitted Task 1 work, and show it RED on the 07-11 recipe. Then select a lower seed speed (grid 0.15-0.12) and a larger blob by a preregistered candidate sweep with halt rules, through the 1800-step production fixture that derives the 3D lesson length, and add fail-closed capture-level validation. *(Replanned 2026-11-21 after the Task 1 halt; E7', D-17 and the 1000x rule are unchanged.)*

**Gap Wave 5** *(blocked on 07-15)*

- [ ] 07-16-PLAN.md — Ship the evidence-derived 3D lesson length as a mode-specific limit (2D stays 600), with state, harness and UI tests, an evidence cross-check, README updates, dated UI-SPEC amendments for the display copy and lesson length, and an explicit Phase 9 handoff.

**Gap Wave 6** *(blocked on 07-16)*

- [ ] 07-17-PLAN.md — Build and identify the exact app, then obtain the user's blocking re-observation of UAT test 2: returning-dye brightness, starting patch size, run length, and early motion at the lowered seed speed. Records a machine-checkable g07_2_* approval marker set only from the user's response.

**Gap Wave 7** *(blocked on 07-17 approval, enforced by a machine-checkable gate; revised 2026-11-21)*

- [ ] 07-13-PLAN.md — Regenerate fresh Phase 7/Phase 8 evidence through one final matrix and append dated gap-closure sections to both verification reports, covering 07-10 to 07-17.

**Execution status (2026-11-13):** All nine plans are closed across eight waves. Plan 07-09 closed the documentation work, but the human visual/accessibility/native-interaction review was **not performed**; its checklist remains unchecked and this is not a human-review PASS. SIM-04, SIM-05, SIM-06, LES-01, LES-02, and LES-06 remain pending manual acceptance; VER-03 is complete from automated production-kernel evidence. Actual macOS 26 runtime and physical-device multitouch remain **NOT TESTED**; displayed frame pacing remains **NOT MEASURED**.

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

**Plans**: 9 plans in 9 waves

Plans:
**Wave 1**

- [x] 08-01-PLAN.md — Preregister inspection/oracle expectations and test pure camera/slice values.

**Wave 2** *(ready after 08-01 / Wave 1 completion)*

- [x] 08-02-PLAN.md — Verify two-sided spatial sheets, subdued cube and depth-equipped rendering.

**Wave 3** *(complete after Wave 2 completion)*

- [x] 08-03-PLAN.md — Integrate presentation-only renderer state and retained Restart choices.

**Wave 4** *(complete after Wave 3 completion)*

- [x] 08-04-PLAN.md — Deliver native camera/slice controls, guide and exclusive paused gestures.

**Wave 5** *(ready after Wave 4 completion)*

- [x] 08-05-PLAN.md — Verify deterministic passive3D tracer reset, MAC RK2 and failure guards.

**Wave 6** *(complete after Wave 5 completion)*

- [x] 08-06-PLAN.md — Integrate hidden tracer advancement, opaque-sheet occlusion and native visibility.

**Wave 7** *(complete after Wave 6 completion)*

- [x] 08-07-PLAN.md — Prove complete-state independence across presentation and step schedules.

**Wave 8** *(complete after Wave 7 completion)*

- [x] 08-08-PLAN.md — Record fresh regression evidence and accurate spatial-inspection usage.

**Wave 9** *(next — mandatory actual human-review checkpoint, not auto-approved)*

- [ ] 08-09-PLAN.md — Obtain actual human visual/accessibility/input review without assumption-based PASS claims.

**Cross-cutting constraints:**

- The established 2D solver and its Swift/Metal ABI remain unchanged.

**Planning status (2026-11-13):** Existing research/UI-SPEC reused; pattern mapping and 17-task executable validation contract created. All five owned requirements and 21 context decisions pass structural/coverage checks and distinct inline plan review after one revision. See `08-PLAN-CHECK.md`. Final human review remains a blocking execution checkpoint. No Phase 8 implementation/build/test/human acceptance is claimed by planning.

**Execution status (2026-11-15):** 08-01 / Wave 1 through 08-08 / Wave 8 complete, **8/9** plans closed; next **08-09 / Wave 9 mandatory actual human review**. Plan 08-08 adds a separate fail-closed inspection schema/CLI and fresh passing exact Mac/iOS builds, full Mac 47/47, full integration 45/45 and discovered iPhone/iPad HUD 11/11 each. Initial Mac 45/47 and iPhone 9/11 failures plus full unchanged-source retries are retained; all matrix attempts total 2,950.717 s. Complete state remains 37 reset resources, 160 negatives, 29 exact paused cases and independent shown/hidden/alternating/nil schedules at 0/1/24/48, maximum error 0. Actual evidence CLI, 14-report freshness and prepared root app-metallib match pass; see `08-08-SUMMARY.md`, its distinct inline review and `docs/3d-phase8-verification.md`. All five Phase 8 requirements remain pending. VoiceOver, physical gesture feel, actual macOS 26 and physical-device checks remain NOT TESTED; displayed pacing remains NOT MEASURED. No 08-09, phase-level verification/completion or auto-advance ran.

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
| 7. First 3D Fluid Vertical Slice | 13/17 | Gap closure in progress (G-07-5 re-observed OK; G-07-2 open after 07-12); acceptance incomplete | — (original plans closed 2026-11-13) |
| 8. Spatial Inspection | 8/9 | In Progress — next 08-09 / Wave 9 mandatory human review | — |
| 9. Repeatable 3D Advection Lesson | 0/TBD | Not started | — |
| 10. Volume View and Measured Release Quality | 0/TBD | Not started | — |

## Coverage and Review

- 23/23 approved v1.1 requirements map to exactly one phase: Phase 7 (7), Phase 8 (5), Phase 9 (7), Phase 10 (4).
- Dependency order is sequential; every phase delivers an observable capability. Numerical checks accompany the solver; presentation-independence and repeatability checks accompany the relevant features.
- Inline review checked approved scope, current-code integration, requirement ownership, 2–5 observable success criteria per phase, and numerical/performance research findings. This is an inline review, not independent-agent verification.
- Phase 7 has nine executable plans across eight waves, with all seven owned requirements and D-01–17 mapped. Execution closed all nine plans on 2026-11-13; plan closeout does not imply phase acceptance. The six user-facing requirements remain pending manual acceptance, while VER-03 is complete from automated production-kernel evidence.

## Deferred Verification

- When prioritized, test Mac launch and drag on an actual macOS 26 Apple Silicon host or Metal-capable guest; update [Phase 1 UAT](milestones/v1.0-phases/01-modern-mac-baseline/01-HUMAN-UAT.md) and verify PLAT-01. This does not block v1.0 closure (user decision, 2026-09-25).
- Physical iOS two-finger/concurrent-touch checks remain NOT TESTED and non-blocking; see [Phase 2 UAT](milestones/v1.0-phases/02-modern-ios-parity/02-HUMAN-UAT.md).
