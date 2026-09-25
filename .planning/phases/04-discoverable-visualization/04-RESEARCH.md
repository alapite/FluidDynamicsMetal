# Phase 4: Discoverable visualization — Research

**Researched:** 2026-09-25
**Requirements:** CTRL-01
**Sources:** Current Swift controllers, shared renderer/state, storyboards, Phase 2–3 context and verification, Phase 4 decisions, and project guidance. Research performed inline because the configured `gsd-phase-researcher` agent is unavailable in this runtime.

## Planning conclusion

Keep the storyboard-owned `MTKView` as the full-bleed root on both platforms. Add a compact native view hierarchy above it in each platform controller, pinned to the upper trailing Mac corner and lower trailing iOS safe area respectively. Put the exact four `DisplayField` names and a state-dependent Pause/Resume action in those overlays. Add a direct field-selection API to the shared state/renderer; make both visible controls and existing shortcuts read and mutate the same renderer state, and preserve the renderer's paused, presentation-only redraw path. An actual UI design contract is required before the planner can specify spacing, material, active styling, compact layout, and reduced-transparency behavior.

## Current implementation evidence

- `Shared/SimulationState.swift` defines the ordered `.density`, `.pressure`, `.velocity`, `.vorticity` enum, the `field`/`userPaused`/`inactive` state and `shouldAdvance`. Only `nextField()` exists, so selecting a named field currently requires repeated cycling; its tests already execute in `FluidDynamicsMetalStateTests/SimulationStateTests.swift`.
- `Shared/Renderer.swift` owns the state and the `MTKView`. `nextSlab()` cycles and explicitly calls `metalView.draw()` only when user-paused and active; `togglePause()` clears input and sets `metalView.isPaused = !state.shouldAdvance`. `draw(in:)` presents the selected stored slab without any solver pass when paused. A direct `selectField(_:)` should trigger the same redraw condition; it must not call a solver pass or reset textures. Avoid rendering when inactive.
- Mac `RenderViewController` forwards Space to `togglePause()` and S to `nextSlab()` via a local `NSEvent` key-down monitor, and forwards pointer strokes to the canvas. iOS controller forwards one-finger double tap to pause, two-finger double tap to cycle, and single taps/drags to dye/force; its recognizers are attached to the root `MTKView`. Both controllers currently have no state-presentation hook: refresh the overlay after each mutation path (buttons, keys/gestures, and foreground return) from `renderer.state`, not from a separate Boolean/index cache.
- Both `Main.storyboard` files make the controller's root view an `MTKView`; Mac's is full-window and iOS's has multiple touches enabled. Overlay subviews can be added programmatically without replacing the root view, rebinding the renderer, or resizing the simulation to a smaller viewport. New platform-specific source files would need explicit `project.pbxproj` target membership; small local view construction in each existing controller avoids project wiring.
- iOS root-view gesture recognizers can receive touches that begin inside descendant controls. Plan a gesture-recognizer delegate or equivalent hit-test guard for the *actual* HUD bounds so its taps never trigger canvas double-/single-tap actions or delayed dye, while touches outside still reach existing canvas input. Verify touch-move and multi-touch as well as simple taps. On Mac, the existing local key monitor handles events regardless of responder; test that activating focused buttons with Space does not produce a duplicate pause and that S/Space still work while the canvas/window is focused.
- Phase 3's accepted resize-pipeline failure risk `AR-03-01` is not a new Phase 4 dependency. Phase 1 macOS 26 runtime and physical iOS two-finger gesture observations are likewise outstanding follow-up checks, not grounds to discard the named controls.

## Recommended implementation seams

1. **Shared state:** Add `SimulationState.selectField(_ field: DisplayField)` (optionally idempotent when already selected); preserve `nextField()`'s order and `userPaused`/`inactive`. Test selecting each field directly while running and paused, and changing field during inactivity without accidentally resuming.
2. **Shared renderer:** Add `Renderer.selectField(_:)` that applies the state selection and immediately redraws only when `!state.shouldAdvance && !state.inactive`, exactly as `nextSlab()` does. Keep `nextSlab()` and `togglePause()` callable from the old shortcuts; do not touch shader entry points, uniform layout, constants or resize behavior.
3. **Native HUDs:** Mac uses compact labeled AppKit buttons in an `NSVisualEffectView` (or a UI-SPEC-approved native material equivalent); iOS uses labeled UIKit buttons in a `UIVisualEffectView` and safe-area constraints. Ensure a legible opaque system-color fallback under Reduce Transparency. Avoid a full-screen intercepting wrapper: the `MTKView` remains the canvas, with the HUD's interactive hit area constrained to the compact group. Use selection state and clear Pause/Resume label to indicate renderer state, including when a shortcut updates it.
4. **Layout and input:** Anchor to the trailing corner with platform-appropriate margin, provide a narrow-window/compact-device arrangement without horizontal clipping, and keep other canvas regions touchable/draggable. Filter iOS root recognizers for touches inside the HUD; do not change gesture priority outside it. Keep Mac overlay/button focus from turning a single Space activation into two pause toggles.

## Validation Architecture

| Layer | Command / evidence | Scope |
|-------|--------------------|-------|
| Shared state | `xcodebuild test -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetalOSX -configuration Debug -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO` | Direct named selection of all four fields, pause and legacy field cycle unchanged |
| Platform integration | Build `FluidDynamicsMetalOSX` for `platform=macOS,arch=arm64` and `FluidDynamicsMetaliOS` for an available iOS 26 simulator with `CODE_SIGNING_ALLOWED=NO` | Both overlays/controllers compile against the same renderer API |
| Visual/input observation | Launch Mac and iPhone/iPad simulator builds: select all four names, observe selection indication and frozen-frame switch while paused, exercise Space/S and both double-tap gestures where reproducible, drag outside HUD, tap inside HUD, resize/rotate and check safe areas and Reduce Transparency | Actual legibility, hit-testing, paused redraw and shortcut synchronization (a build alone cannot establish these) |

The existing production-state XCTest target is the Wave 0 test infrastructure. Plan small new state tests for the direct-selection contract, rather than a second state implementation or a test that only mirrors a control callback. UI hit-testing and appearance require a live observation checkpoint; record simulator-inaccessible physical multi-touch as NOT TESTED.

## Planning constraints and open choices

- `04-CONTEXT.md` D-01–D-07 are locked, including always-visible group, native material with opaque accessibility fallback, platform-specific trailing corners, exact four labels, immediate paused presentation, and no input interception outside the group.
- `CTRL-07` comprehensive keyboard/accessibility delivery belongs to Phase 6, but newly introduced controls must be labeled and usable now. Live tuning, resolution and reset belong to Phases 5–6.
- Specify visual dimensions, narrow-layout wrapping, state styling and contrast in `04-UI-SPEC.md` before planning; the plan-phase UI safety gate will otherwise stop on this frontend phase.
