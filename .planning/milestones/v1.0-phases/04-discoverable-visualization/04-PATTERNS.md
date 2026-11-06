# Phase 4 — Existing Integration Patterns

**Mapped:** 2026-09-25

## Shared state and presentation

| Role | Source | Reuse for this phase |
|------|--------|----------------------|
| Field and pause source of truth | `Shared/SimulationState.swift` (`DisplayField`, `field`, `userPaused`, `inactive`, `shouldAdvance`, `nextField()`) | Add direct selection without a second controller-owned field or pause state; retain enum order. |
| Paused presentation | `Shared/Renderer.swift` (`nextSlab()`, `togglePause()`, `draw(in:)`) | Direct selection uses the same paused-and-active `metalView?.draw()` condition as `nextSlab()`. `draw(in:)` already presents a stored slab without solver steps when paused. |
| Executable state checks | `FluidDynamicsMetalStateTests/SimulationStateTests.swift` | Add cases for out-of-order direct selection, repeat selection, paused selection, inactivity and existing cycle continuity in the production state test target. |

## Platform-native controls

| Role | Source | Reuse for this phase |
|------|--------|----------------------|
| Mac host and input | `FluidDynamicsMetalOSX/RenderViewController.swift` | Controller owns storyboard root `MTKView`, renderer, local Space/S key monitor and canvas drag. Place a compact `NSVisualEffectView` subview above the canvas; refresh selected button and pause label after any controller mutation. Prevent Space from reaching both the monitor and a focused HUD button. |
| iOS host and input | `FluidDynamicsMetaliOS/RenderViewController.swift` | Controller owns storyboard root `MTKView`, one-/two-finger double-tap recognizers, delayed tap/hold and concurrent touch bookkeeping. Place a compact `UIVisualEffectView` subview above the canvas; reject recognizer touches originating inside HUD bounds and keep HUD touches out of the fluid contact set. Refresh controls after button and gesture actions and foreground return. |
| Canvas and source wiring | Both `Base.lproj/Main.storyboard` files; `FluidDynamicsMetal.xcodeproj/project.pbxproj` | Keep the existing full-bleed root `MTKView` and existing target source membership. Controller-local UI avoids new source-list entries or viewport resizing. |

## Constraints to retain

- `.planning/phases/04-discoverable-visualization/04-UI-SPEC.md` specifies exact labels, native material/opaque accessibility fallback, trailing anchors, adaptive layout and minimum hit heights; it is the source of truth for both HUDs.
- `.planning/phases/04-discoverable-visualization/04-CONTEXT.md` locks D-01–D-07, including shortcut parity and uninterrupted canvas interaction outside the compact HUD.
- `.planning/phases/04-discoverable-visualization/04-VALIDATION.md` separates XCTest/build evidence from live Mac/iOS visual and input observations.
