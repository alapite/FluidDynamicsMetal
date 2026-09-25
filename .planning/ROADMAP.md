# Roadmap: FluidDynamicsMetal Modernization

## Overview

Bring the existing two-platform simulation onto current Apple platforms without rewriting its visual behavior. Start with a usable Mac build, restore iOS parity, make shared state robust and verifiable, then progressively deliver discoverable controls and live tuning on both apps.

## Phases

- [ ] **Phase 1: Modern Mac baseline** - A working macOS 26 / Apple Silicon fluid app establishes a visual reference. (plans complete; macOS 26 runtime verification deferred to milestone closeout by user)
- [x] **Phase 2: Modern iOS parity** - Both apps build and support familiar fluid interaction on current SDKs. (completed 2026-09-24)
- [x] **Phase 3: Reliable simulation state** - Pausing, resizing, and shared state changes work and have automated coverage. (completed 2026-09-25)
- [ ] **Phase 4: Discoverable visualization** - Both apps expose native pause and named field-selection controls.
- [ ] **Phase 5: Live fluid tuning** - Both apps expose input, dye, swirl, and fade controls without source edits.
- [ ] **Phase 6: Quality, reset, and accessibility** - Resolution and reset controls, accessible interactions, and complete verification finish the experience.

## Phase Details

### Phase 1: Modern Mac baseline
**Goal:** People can launch and stir the familiar fluid on an Apple Silicon Mac running macOS 26.
**Mode:** mvp
**Depends on:** Nothing (first phase)
**Requirements:** PLAT-01
**Success Criteria** (what must be TRUE):
  1. The macOS app builds for Apple Silicon and launches on macOS 26 without a deployment-target override.
  2. Mouse dragging produces the familiar density and motion in the Metal canvas.
  3. A reference of the existing default look and interactions is available for later parity checks.
**Plans:** 1/1 plans complete
- [x] 01-01-PLAN.md — Build the Apple Silicon Mac fluid slice and record its visual baseline.

### Phase 2: Modern iOS parity
**Goal:** The iOS 26 app joins the working Mac build with the same familiar fluid interaction.
**Mode:** mvp
**Depends on:** Phase 1
**Requirements:** PLAT-02, PLAT-03, SIM-01
**Success Criteria** (what must be TRUE):
  1. Both app schemes build under a current Xcode toolchain without Swift 4 compatibility settings or local deployment-target overrides.
  2. Users can drag to stir and deposit density on Mac and iOS at the default settings.
  3. Both apps remain usable with their existing platform input methods.
**Plans:** 3/3 plans complete
- [x] 02-01-PLAN.md — Launch an iOS 26 fluid tracer and build both schemes without compatibility overrides (Wave 1).
- [x] 02-02-PLAN.md — Add independent multi-touch stirring, clean tap shortcuts, and proportional iPad input (Wave 2; depends on Wave 1).
- [x] 02-03-PLAN.md — Launch on iPhone/iPad simulators and record observed Mac/iOS parity (Wave 3; depends on Waves 1–2).

### Phase 3: Reliable simulation state
**Goal:** Fluid interaction survives common lifecycle changes with automated checks of controllable state.
**Mode:** mvp
**Depends on:** Phase 2
**Requirements:** SIM-02, SIM-03, VER-01
**Success Criteria** (what must be TRUE):
  1. A user can resize the Mac window or rotate/resize the iOS view and keep interacting with visible fluid.
  2. A user can pause and resume without breaking the displayed field or later input.
  3. Developers can run automated checks covering state transitions, parameter bounds, and defaults/reset behavior.
**Plans:** 3/3 plans complete
**Wave 1**
- [x] 03-01-PLAN.md — Shared pause/field/lifecycle state and executable bounds/default/reset checks (Wave 1).
**Wave 2** *(blocked on Wave 1 completion)*
- [x] 03-02-PLAN.md — Preserve all GPU fields through resize/rotation and rebase held input (Wave 2; depends on Wave 1).
**Wave 3** *(blocked on Wave 2 completion)*
- [x] 03-03-PLAN.md — Run both-app verification and observe resized, paused and returned fluid (Wave 3; depends on Waves 1–2).

### Phase 4: Discoverable visualization
**Goal:** Users can clearly see and switch the simulation view on either platform.
**Mode:** mvp
**Depends on:** Phase 3
**Requirements:** CTRL-01
**Success Criteria** (what must be TRUE):
  1. Both apps show named controls for density, pressure, velocity, and vorticity and indicate the active field.
  2. The fluid remains the central, interactive canvas while switching fields.
  3. Both apps expose an on-screen pause/resume control without removing existing interaction.
**Plans:** TBD
**UI hint:** yes

### Phase 5: Live fluid tuning
**Goal:** Users can shape the fluid's response on both platforms while it runs.
**Mode:** mvp
**Depends on:** Phase 4
**Requirements:** CTRL-02, CTRL-03, CTRL-04
**Success Criteria** (what must be TRUE):
  1. Both apps offer bounded controls for stirring force and added dye/density intensity with immediate, observable effects.
  2. Both apps offer bounded swirl strength and fade/dissipation controls with immediate, observable effects.
  3. At default control values, the fluid still resembles the original simulation.
**Plans:** TBD
**UI hint:** yes

### Phase 6: Quality, reset, and accessibility
**Goal:** Users can tune quality safely, restore a known starting state, and operate the finished controls natively.
**Mode:** mvp
**Depends on:** Phase 5
**Requirements:** CTRL-05, CTRL-06, CTRL-07, VER-02
**Success Criteria** (what must be TRUE):
  1. A bounded resolution control changes simulation quality without breaking drawing, resizing, or interaction.
  2. A user can restore default tuning, and relaunching either app starts with those defaults.
  3. Mac users can operate controls by keyboard and pointer; iOS users can use touch; controls have meaningful accessibility labels.
  4. Developers can follow documented build and manual verification steps on both platforms, including dragging, pause/resume, field selection, and tuning.
**Plans:** TBD
**UI hint:** yes

## Progress

**Execution Order:** Phases execute in numeric order, 1 → 2 → 3 → 4 → 5 → 6.

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Modern Mac baseline | 1/1 | Implementation complete; runtime UAT deferred | - |
| 2. Modern iOS parity | 3/3 | Complete   | 2026-09-24 |
| 3. Reliable simulation state | 3/3 | Complete   | 2026-09-25 |
| 4. Discoverable visualization | 0/TBD | Not started | - |
| 5. Live fluid tuning | 0/TBD | Not started | - |
| 6. Quality, reset, and accessibility | 0/TBD | Not started | - |

## Milestone Closeout Checks

- [ ] Complete the deferred Phase 1 macOS 26 runtime launch/drag test on a physical Apple Silicon Mac or a macOS 26 VM with a usable Metal device. See `01-BASELINE.md` for the resumable `curl -C -` restore-image download and verification instructions. Resolve `01-HUMAN-UAT.md`, then re-verify PLAT-01 and mark Phase 1 complete. This check was explicitly deferred on 2026-09-24 to allow Phase 2 discussion/planning and later work to proceed.
