# Phase 5: Live fluid tuning - Context

**Gathered:** 2026-09-25
**Status:** Ready for planning

<domain>
## Phase Boundary

Let users on Mac, iPhone and iPad adjust stirring force, dye intensity, swirl strength and fluid fade while the simulation runs, without editing source. Changes must be bounded, immediately observable, and retain the familiar original behavior at defaults. Preserve the Phase 4 field/pause HUD and existing gestures. Resolution/quality, an in-app reset action, complete accessibility sign-off and final verification documentation belong to Phase 6; do not redesign the solver or add presets/persistence.

</domain>

<decisions>
## Implementation Decisions

### Tuning controls placement
- **D-01:** Add a labeled Tuning expand/collapse control inside the existing floating field/pause HUD on both platforms; do not create a second panel. The tuning section starts closed on a fresh launch.
- **D-02:** Once opened, tuning stays open through canvas interaction until the user closes it. Retain the existing Mac upper-trailing and iOS lower-trailing positions, and keep canvas interaction available outside the actual HUD bounds.
- **D-03:** When space is tight on iPhone or in a small Mac window, constrain the expanded HUD and scroll *inside* it so all controls remain reachable without relocating the HUD or replacing the field/pause controls.

### Force and dye feel
- **D-04:** Changes to Force or Dye take effect on the next movement of a stroke already in progress, and on subsequent strokes; they affect new input only, not fluid already deposited or set in motion.
- **D-05:** Force and Dye are independent. Zero Force still permits dye deposition without adding motion (existing flow may carry the dye); zero Dye still permits stirring without adding dye. Preserve single-tap dye behavior when Dye is above zero and existing clean double-tap shortcuts.

### Swirl and fade feel
- **D-06:** Changing Swirl affects ongoing fluid motion on the next running frames, even without fresh input. Zero Swirl disables additional curling but does not prevent stirring or other motion.
- **D-07:** Changing Fade affects dye already visible and future dye, *and* the decay of existing/future motion, on the next running frames. Follow the existing shared advection-decay character at the default value; do not retroactively alter a paused simulation step.

### Values and feedback
- **D-08:** Present four continuous, live sliders labeled Force, Dye, Swirl and Fade. Display a 0–100% value for each user-facing range as the thumb moves; do not expose raw solver constants in the HUD.
- **D-09:** Moving Fade to the right (higher displayed percentage) makes dye and motion disappear sooner. Internally the existing retention value runs in the opposite direction; keep the label/slider behavior intuitive.
- **D-10:** Give Fade a useful adjustment range on both sides of the original near-full-retention default. The displayed percentage represents this chosen user range, *not* a literal linear mapping across raw retention 0–1. Keep the original default look unchanged.

### Agent's Discretion
Choose native slider styling, exact labels/help text beyond the four names, practical user-facing mappings and endpoints (within the already bounded shared state), default markers if useful, layout/scroll mechanics, and state-to-renderer wiring. Preserve the recorded behaviors and original default constants. Boundaries and default/reset state checks already exist; a visible reset control is reserved for Phase 6.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Scope and locked continuity
- `.planning/ROADMAP.md` §Phase 5 — CTRL-02/03/04 and observable live tuning; §Phase 6 — quality, reset, accessibility and final verification boundaries.
- `.planning/REQUIREMENTS.md` — CTRL-02/03/04, no between-launch tuning persistence, and later-phase CTRL-05/06/07.
- `.planning/PROJECT.md` — both-platform native controls and recognizable fluid behavior constraints.
- `.planning/phases/04-discoverable-visualization/04-CONTEXT.md` — fixed HUD placement, visibility, input isolation and field/pause behavior.
- `.planning/phases/03-reliable-simulation-state/03-CONTEXT.md` — pause/resize/lifecycle and tuning-state defaults/bounds/reset contract; paused input is discarded.
- `.planning/phases/02-modern-ios-parity/02-CONTEXT.md` — touch and tap shortcuts, dark-blue density default and iPhone/iPad stroke proportionality.
- `.planning/phases/01-modern-mac-baseline/01-BASELINE.md` — original values (dye impulse 0.8, swirl 0.4, retention 0.998), look and Mac interaction baseline.
- `README.md` §Usage — documented mouse/touch/key interactions to preserve.

### Integration background
- `.planning/codebase/ARCHITECTURE.md` — two controllers and shared renderer/shader contracts; verify details against current source because this map predates Phases 3–4.
- `.planning/codebase/STRUCTURE.md` — target and file ownership; likewise verify against current source.

No external specs or ADRs were supplied for Phase 5.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Shared/SimulationState.swift`: shared `SimulationTuning` with force/dye/swirl/retention defaults and bounds, plus state-level reset; tests from Phase 3 already exercise its contract. Its current values are not yet used by the renderer.
- `FluidDynamicsMetalOSX/RenderViewController.swift` and `FluidDynamicsMetaliOS/RenderViewController.swift`: existing native, adaptive, material-backed field/pause HUDs with accessibility labels and per-platform input exclusion; extend these surfaces.
- `Shared/Renderer.swift` and `Shared/Shaders.metal`: original solver and visual behavior for default parity.

### Established Patterns
- Both storyboard-backed `MTKView`s host the HUD over the canvas; only interaction inside the HUD is excluded from stirring. Mac uses Space/S, iOS uses one-/two-finger double taps.
- `Renderer.draw(in:)` applies contacts, advection, vorticity and pressure passes every running frame; a paused frame renders without advancing. `StaticData` in Swift and `BufferData` in Metal have matched layouts and must remain aligned.
- Current source still hard-codes scalar dye impulse `0.8` and contact radius in `Shared/Renderer.swift`, and advection retention `0.998` and curl `0.4` in `Shared/Shaders.metal`. `SimulationTuning` already carries the original defaults, with bounds force 0–2, dye 0–2, swirl 0–2, retention 0–1; user-facing Fade is the inverse of retention and should have a practical range around its default. Radius and pressure iterations are not Phase 5 controls.

### Integration Points
- `Shared/SimulationState.swift` / `Shared/Renderer.swift`: bounded tuning state to contact impulses and per-frame simulation behavior, on both app targets.
- `Shared/Shaders.metal`: advection fade and confinement curl constants; retain default behavior and matching uniform/shader contracts.
- Both platform `RenderViewController.swift` files: add four native controls to the existing HUD and maintain input hit-testing, resize adaptation, and pause/field controls.
- `FluidDynamicsMetal.xcodeproj/project.pbxproj`: register any new source files with both appropriate app targets.

</code_context>

<specifics>
## Specific Ideas

Start compact: open Tuning from the existing HUD, adjust while watching the fluid, then close it when more canvas is wanted. Force and Dye separately control strokes, while Swirl and Fade change already-running fluid. Higher Fade % means a shorter-lived effect; a percentage is a friendly control position, not the raw shader number.

</specifics>

<deferred>
## Deferred Ideas

No new feature ideas arose. Phase 6 still owns resolution/quality, visible reset and full accessibility/final-verification work. Phase 1 macOS 26 runtime and physical-device multitouch checks remain documented non-blocking follow-ups under the prior roadmap/state decisions.

</deferred>

---

*Phase: 5-live-fluid-tuning*
*Context gathered: 2026-09-25*
