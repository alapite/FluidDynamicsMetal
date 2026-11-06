# Requirements: FluidDynamicsMetal

**Milestone:** v1.1 — 3D Teaching Foundation
**Defined:** 2026-11-06
**Approved:** 2026-11-06
**Core Value:** People can interact with a responsive, visually familiar fluid simulation on both supported platforms and adjust it without editing source code.

## v1.1 Requirements

### 3D Simulation and Integration

- [ ] **SIM-04**: Users can select the 3D dye-advection lesson from the Mac app.
- [ ] **SIM-05**: Users can observe dye evolving in a genuine 64³ fluid simulation, with depth-varying velocity and nonplanar transport.
- [ ] **SIM-06**: Users can return from 3D to the existing 2D modes with their established selection/reset behaviour and no stale input.

### Lesson Playback

- [ ] **LES-01**: Users enter the 3D lesson paused at step 0 and can Run/Pause/Resume with a visible step count.
- [ ] **LES-02**: Users can advance exactly one logical step per Step action while paused.
- [ ] **LES-03**: Users can restart at step 0 with the current speed and inspection choices preserved.
- [ ] **LES-04**: Users can select slow/normal/fast initial speeds; changing speed restarts the lesson.
- [ ] **LES-05**: Users see the lesson stop automatically at step 600; inspection remains available and further advancement requires restarting.
- [ ] **LES-06**: Users can leave the app inactive without simulation advancement and return without catch-up steps.

### Spatial Inspection

- [ ] **INS-01**: Users can orbit, zoom, and reset the camera, with orientation cues.
- [ ] **INS-02**: Users can inspect dye on an XY, XZ, or YZ cross-section and move its depth.
- [ ] **INS-03**: Users can show or hide passive 3D tracers that continue evolving with simulation steps while hidden.
- [ ] **INS-04**: Users can change camera, slice, visibility, and window size without altering the simulated result at equal step counts.
- [ ] **INS-05**: Users can view the dye as a basic transparent volume from different camera angles.
- [ ] **INS-06**: Users can select slice or volume presentation and independently toggle tracers.
- [ ] **CTRL-08**: Users can operate the new controls through labelled native Mac controls with keyboard access; control and camera gestures do not inject fluid.

### Educational Content

- [ ] **EDU-01**: Users can see a prediction question and explanation for the 3D advection lesson.
- [ ] **EDU-02**: Users can observe and verify the intended slow/normal/fast transport ordering at a documented equal-step comparison point.
- [ ] **EDU-03**: Users can understand that dye represents concentration, steps are not calibrated physical time, and numerical smoothing affects the result.

### Verification and Performance

- [ ] **VER-03**: Developers can run production-kernel checks for three-axis advection, pressure projection, boundaries, and finite field values, against documented reference fixtures and tolerances.
- [ ] **VER-04**: Developers can reproduce complete fluid and tracer state after restart at equal step counts on the same device, within documented floating-point tolerances.
- [ ] **VER-05**: Users get a measured 30 fps floor at 64³ and 1280×720 output on a named available Apple Silicon reference Mac, covering slices/tracers and volume/tracers; developers record GPU timing, frame pacing, and resource use. Sixty fps remains a goal.
- [ ] **VER-06**: Developers retain both app builds and the existing 2D regression coverage, with documented Mac 3D usage and verification results.

## Acceptance Conventions

- **Simulation scope:** True evolving three-component velocity plus passive dye in a fixed volume. An extruded 2D field, prescribed animation, or camera-only depth effect cannot satisfy SIM-05.
- **Coordinates and boundaries:** Phase 7 planning must define grid locations, units, time step, interpolation, the pressure operator, and all six boundary faces before implementation. Document numerical fixtures and acceptance tolerances before judging results; validate post-projection divergence as well as solver residual. Do not inherit 40 pressure iterations as a correctness guarantee.
- **State:** Same-device repeatability is tolerance-based. Include all evolution-dependent fields and tracer buffers, not just a screenshot or dye texture. Camera/inspection state is separate from numerical evolution. Restart clears pending steps/input and returns paused; view settings are preserved. LES-03 is extended and rechecked as later phases introduce new inspection controls.
- **Lesson:** Exactly 600 logical steps, not 600 rendered frames or physical seconds. Changing the initial-speed choice restarts with that choice. Validate the transport-ordering claim at a specified early comparison point or justified metric, not an arbitrary late centroid snapshot after circulation.
- **Inspection:** One axis-aligned movable dye slice is sufficient; arbitrary oblique cuts and simultaneous multi-pane comparison are deferred. A selected slice or volume can be accompanied by tracers. Volume opacity is a visualization setting, not a change to dye concentration. Freehand dye/force injection is disabled in this scripted lesson.
- **Performance:** Benchmark both slice-plus-tracer and volume-plus-tracer presentations using the same production solver at 64³ and an explicitly configured 1280×720 drawable/output in pixels. Record the actual Mac model/GPU, OS, Xcode, build configuration, warm-up, run length, display mode, and measurement protocol. Require sustained measured presentation at least 30 fps over the declared steady-state run; record frame-interval distribution and GPU timings separately. GPU time alone or preferredFramesPerSecond does not establish this requirement. Define the benchmark protocol during phase planning before acceptance. Larger windows may use a bounded internal rendering resolution while preserving control readability; record any such scaling.
- **Regression:** Both no-override app builds and existing applicable state/HUD/GPU tests remain part of verification after shared changes. Numerical checks accompany the first solver slice; later phases rerun relevant checks for their changes. VER-06 has a single ownership phase, but regression preservation is a milestone-wide constraint.
- **Coverage honesty:** Existing macOS 26 runtime and physical mobile multitouch checks remain NOT TESTED until actually exercised. A newer host cannot establish macOS 26 behaviour. Historical passing checks are evidence of the baseline, not new verification.

## Future Requirements

- **LESSON-3D-02:** 3D interacting-vortex lesson after the foundation proves usable.
- **LESSON-3D-03:** 3D dye-stretching/stirring lesson.
- **MOBILE-3D-01:** iPad/iPhone 3D controls and real-device performance qualification.
- **INPUT-3D-01:** Freehand 3D dye/force injection with explicit depth selection.
- **INS-07:** 3D pressure, velocity, and vorticity field inspection and associated legends.
- **INS-08:** Tracer trails, streamlines, or advanced slice arrangements.
- **CTRL-05:** Bounded simulation resolution/quality controls, carried forward from v1.0; benchmark higher 3D resolutions before exposure.
- **CTRL-06:** Restore tuning defaults in-app; distinguish this from the already delivered fluid reset action.
- **CTRL-07:** Broader cross-platform accessibility improvements, carried forward from v1.0; v1.1's new native controls are covered by CTRL-08.
- **PRESET-01:** Save and recall named tuning presets.
- **EXPORT-01:** Export still images or recordings.

## Out of Scope

| Feature | Reason |
|---------|--------|
| Mobile 3D delivery and additional 3D lessons | User selected the focused Mac foundation |
| Changes to the established 2D solver | Retain an existing working reference alongside the new solver |
| Free-surface water, fire, buoyancy, obstacles | Different physics and visualization scope |
| Scientific calibration, physical-time claims, cross-device bitwise replay | Qualitative, step-based teaching contract |
| Cinematic lighting, scattering, mesh extraction, sparse grids | Basic dye-volume rendering suffices for this milestone |
| Intel Mac and pre-26 OS support | Existing product compatibility baseline |

## Traceability

Every v1.1 requirement maps to exactly one delivery phase. Later phases extend and rerun relevant earlier checks without duplicating requirement ownership.

| Requirement | Phase | Status |
|-------------|-------|--------|
| SIM-04 | Phase 7 | Pending |
| SIM-05 | Phase 7 | Pending |
| SIM-06 | Phase 7 | Pending |
| LES-01 | Phase 7 | Pending |
| LES-02 | Phase 7 | Pending |
| LES-03 | Phase 9 | Pending |
| LES-04 | Phase 9 | Pending |
| LES-05 | Phase 9 | Pending |
| LES-06 | Phase 7 | Pending |
| INS-01 | Phase 8 | Pending |
| INS-02 | Phase 8 | Pending |
| INS-03 | Phase 8 | Pending |
| INS-04 | Phase 8 | Pending |
| INS-05 | Phase 10 | Pending |
| INS-06 | Phase 10 | Pending |
| CTRL-08 | Phase 8 | Pending |
| EDU-01 | Phase 9 | Pending |
| EDU-02 | Phase 9 | Pending |
| EDU-03 | Phase 9 | Pending |
| VER-03 | Phase 7 | Pending |
| VER-04 | Phase 9 | Pending |
| VER-05 | Phase 10 | Pending |
| VER-06 | Phase 10 | Pending |

**Coverage:** 23 requirements; 23 mapped, 0 unmapped. All remain pending implementation.

---
*Requirements approved: 2026-11-06. Implementation has not started.*
