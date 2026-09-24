# Roadmap: FluidDynamicsMetal Modernization

## Overview

Bring the existing two-platform simulation onto current Apple platforms without rewriting its visual behavior. Start with a usable Mac build, restore iOS parity, make shared state robust and verifiable, then progressively deliver discoverable controls and live tuning on both apps.

## Phases

- [ ] **Phase 1: Modern Mac baseline** - A working macOS 26 / Apple Silicon fluid app establishes a visual reference.
- [ ] **Phase 2: Modern iOS parity** - Both apps build and support familiar fluid interaction on current SDKs.
- [ ] **Phase 3: Reliable simulation state** - Pausing, resizing, and shared state changes work and have automated coverage.
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
**Plans:** 1 plan
- [ ] 01-01-PLAN.md — Build the Apple Silicon Mac fluid slice and record its visual baseline.

### Phase 2: Modern iOS parity
**Goal:** The iOS 26 app joins the working Mac build with the same familiar fluid interaction.
**Mode:** mvp
**Depends on:** Phase 1
**Requirements:** PLAT-02, PLAT-03, SIM-01
**Success Criteria** (what must be TRUE):
  1. Both app schemes build under a current Xcode toolchain without Swift 4 compatibility settings or local deployment-target overrides.
  2. Users can drag to stir and deposit density on Mac and iOS at the default settings.
  3. Both apps remain usable with their existing platform input methods.
**Plans:** TBD

### Phase 3: Reliable simulation state
**Goal:** Fluid interaction survives common lifecycle changes with automated checks of controllable state.
**Mode:** mvp
**Depends on:** Phase 2
**Requirements:** SIM-02, SIM-03, VER-01
**Success Criteria** (what must be TRUE):
  1. A user can resize the Mac window or rotate/resize the iOS view and keep interacting with visible fluid.
  2. A user can pause and resume without breaking the displayed field or later input.
  3. Developers can run automated checks covering state transitions, parameter bounds, and defaults/reset behavior.
**Plans:** TBD

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
| 1. Modern Mac baseline | 0/1 | Planned | - |
| 2. Modern iOS parity | 0/TBD | Not started | - |
| 3. Reliable simulation state | 0/TBD | Not started | - |
| 4. Discoverable visualization | 0/TBD | Not started | - |
| 5. Live fluid tuning | 0/TBD | Not started | - |
| 6. Quality, reset, and accessibility | 0/TBD | Not started | - |
