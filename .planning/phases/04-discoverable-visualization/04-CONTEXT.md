# Phase 4: Discoverable visualization - Context

**Gathered:** 2026-09-25
**Status:** Ready for planning

<domain>
## Phase Boundary

Add visible, named field-selection and pause/resume controls to both apps while keeping the interactive fluid canvas central. Keep existing Mac keyboard and iOS touch shortcuts. This phase does not add live tuning, resolution or reset controls (Phases 5–6), and does not redesign the simulation.

</domain>

<decisions>
## Implementation Decisions

### Floating control placement
- **D-01:** Use a compact floating group over the fluid on both platforms, rather than a toolbar or side panel. Preserve as much interactive canvas as possible.
- **D-02:** Keep the group visible while stirring and when idle; do not make finding it depend on hover or a reveal gesture.
- **D-03:** Anchor it near the upper trailing corner on Mac and lower trailing corner on iPhone/iPad, adapting to window size and device safe areas without clipping controls.
- **D-04:** Use a native system-material surface with clearly legible labels and an opaque fallback when reduced transparency is requested.

### Field and pause behavior
- **D-05:** Show Density, Pressure, Velocity and Vorticity by name and clearly highlight the active field; show an on-screen Pause/Resume action with a label that reflects the current state. Use the shared renderer state as the source of truth, including when shortcuts change it.
- **D-06:** The Mac Space/S keys and iOS one-finger/two-finger double-tap shortcuts remain available. A control click or tap must update the same state as the corresponding shortcut; a field change while paused presents immediately without a solver step.
- **D-07:** Pointer or touch input within the group activates only its controls; interaction elsewhere on the canvas still stirs fluid. Keep the group readable and operable across Mac resizing and iPhone/iPad layouts.

### Agent's Discretion
Choose the concrete native controls, adaptive wrapping/spacing, view hierarchy and state-notification mechanism. Favor accessible labeled controls and avoid changing solver constants or the existing field order.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Scope and continuity
- `.planning/ROADMAP.md` §Phase 4 — CTRL-01 and the three success criteria; Phases 5–6 own tuning, resolution and reset.
- `.planning/REQUIREMENTS.md` — CTRL-01; CTRL-07 belongs to Phase 6, but the new controls must remain understandable and operable.
- `.planning/PROJECT.md` — native controls, interactive canvas and visual-parity constraints.
- `.planning/phases/02-modern-ios-parity/02-CONTEXT.md` — existing gestures, default field and canvas continuity.
- `.planning/phases/03-reliable-simulation-state/03-CONTEXT.md` — immediate paused field redraw, input clearing, resize and lifecycle behavior.
- `.planning/phases/03-reliable-simulation-state/03-SECURITY.md` — accepted local GPU resample failure risk AR-03-01; it is documented and non-blocking, not verified as fixed.
- `.planning/phases/01-modern-mac-baseline/01-BASELINE.md` — default appearance and Mac Space/S shortcuts.
- `README.md` §Usage — current controls that the new UI supplements.

### Integration
- `.planning/codebase/STRUCTURE.md` — controllers, storyboards and Xcode target wiring; check current source as this map predates Phase 3.
- `.planning/codebase/ARCHITECTURE.md` — shared renderer and platform controller boundaries; check current source as this map predates Phase 3.

No external specs or ADRs were supplied for Phase 4.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Shared/SimulationState.swift`: ordered `DisplayField`, `userPaused`, `inactive` and effective `shouldAdvance` state.
- `Shared/Renderer.swift`: `state`, `nextSlab()`, `togglePause()` and paused presentation-only draw path; the current field API cycles rather than directly selects.
- Both platform `RenderViewController.swift` files already install the renderer and own input/shortcut forwarding.

### Established Patterns
- iOS uses one-finger double tap for pause and two-finger double tap for next field; Mac uses Space and S. Keep these paths synchronized with the on-screen selection.
- Both apps use a storyboard-backed full-canvas `MTKView`; overlay controls must not intercept strokes outside their actual bounds or reset the renderer on layout changes.

### Integration Points
- `FluidDynamicsMetaliOS/Base.lproj/Main.storyboard` and `FluidDynamicsMetalOSX/Base.lproj/Main.storyboard`: existing canvas hosting and possible overlay integration.
- `FluidDynamicsMetaliOS/RenderViewController.swift` and `FluidDynamicsMetalOSX/RenderViewController.swift`: platform-native controls and state presentation.
- `Shared/Renderer.swift` and `Shared/SimulationState.swift`: common direct field-selection/state API so all controls and shortcuts agree, including paused redraw.
- `FluidDynamicsMetal.xcodeproj/project.pbxproj`: register any new source files in the correct app targets.

</code_context>

<specifics>
## Specific Ideas

The approved design is a small always-visible grouped HUD: all four field names plus Pause/Resume, clear active-field emphasis, system material over the fluid, upper trailing on Mac and lower trailing on iPhone/iPad. It must leave the canvas interactive outside the controls and follow shared state even when users invoke legacy shortcuts. Verify both app builds, shared state transitions and observable paused switching; avoid treating already-completed Phase 3 validation as a new prerequisite.

</specifics>

<deferred>
## Deferred Ideas

Phase 5 owns live fluid tuning. Phase 6 owns resolution, reset and comprehensive accessibility verification. Phase 1 macOS 26 runtime and Phase 2/3 physical two-finger observations remain explicitly deferred to milestone/device follow-up. Phase 3 resize pipeline WR-01/AR-03-01 is an accepted residual risk, not a Phase 4 gate.

</deferred>

---

*Phase: 4-discoverable-visualization*
*Context gathered: 2026-09-25*
