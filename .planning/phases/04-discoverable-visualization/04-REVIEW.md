---
phase: 04-discoverable-visualization
status: issues_found
depth: standard
files_reviewed: 5
findings:
  critical: 0
  warning: 1
  info: 0
  total: 1
reviewed: 2026-09-25
---

# Phase 4 — Code Review

Reviewed `Shared/SimulationState.swift`, `Shared/Renderer.swift`, `FluidDynamicsMetalStateTests/SimulationStateTests.swift`, and both platform `RenderViewController.swift` files. The Mac state suite and both scheme builds pass; the user approved normal Mac, iPhone and iPad interaction. This review is advisory.

### WR-01 — Mac HUD height does not adapt when large text remains in two columns

**Severity:** Warning  
**Location:** `FluidDynamicsMetalOSX/RenderViewController.swift:155-185`

`updateControlLayout()` computes column count from the buttons' intrinsic **width**, but keeps a two-column HUD at a fixed height of 160 points and only enables scrolling when it switches to one column. If text grows vertically without exceeding the two-column width threshold, the caption, two field rows and pause button can exceed the HUD height. Also, the accessibility display-options notification only calls `updateAppearance()`, so installed Mac button fonts/measurements are not refreshed when display settings change. A narrow/large-text or Bold Text check is needed before claiming that variant. The user's approved core flow does not include a specific large-text observation; it remains NOT TESTED in `04-HUD-VERIFICATION.md`.

**Suggested follow-up:** Size the Mac HUD from measured row heights, enable bounded internal scrolling whenever field content exceeds available height, and recalculate layout on text/display-option changes. Re-check compact and accessibility text settings.

## Reviewed behavior

- Shared direct selection preserves pause/inactive state and invokes the renderer's existing paused, solver-free draw guard.
- Both HUDs use `renderer.state` as the display source of truth; iOS filters HUD-origin touches individually on the three canvas recognizers.
- No new external data, network or persistence boundary was added.
