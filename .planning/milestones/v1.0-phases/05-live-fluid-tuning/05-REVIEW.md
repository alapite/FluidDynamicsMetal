---
phase: 05-live-fluid-tuning
status: issues_found
depth: standard
files_reviewed: 10
findings:
  critical: 0
  warning: 2
  info: 1
  total: 3
reviewed: 2026-09-25
---

# Phase 05 — Code Review

Reviewed Phase 5's committed changes to `Shared/SimulationState.swift`, `Shared/Renderer.swift`, `Shared/Shaders.metal`, both platform controllers and HUD test files, the state tests, and the Phase 5 Metal harness. Compared committed content with the three pre-existing, uncommitted workspace changes; the user's approved observation reflects the working tree. The review is advisory and does not change the user's non-blocking coverage decision.

## Findings

### WR-01 — Mac keyboard verification depends on uncommitted earlier work

**Location:** `FluidDynamicsMetalOSX/RenderViewController.swift`, focused-button Space branch; `FluidDynamicsMetalOSXUITests/HUDUITests.swift`.

The working tree already had an uncommitted change that calls `performClick(nil)` and swallows Space on focused field/Pause buttons. Phase 5's committed change adds `tuningButton` to that branch, but the committed baseline branch instead returns the event to AppKit. The user-approved keyboard behavior and the 13-test Mac result were obtained against the working tree, not a clean checkout of Phase 5 commits. The earlier focused-field UI test is also uncommitted. Check focused Space and Tuning keyboard reachability on a clean checkout before relying on this as a regression guarantee; integrate the earlier edit separately if intended. Phase 6's keyboard/accessibility verification is an appropriate follow-up.

### WR-02 — Compact Mac active-field summary shares vertical space with the scroll area

**Location:** `FluidDynamicsMetalOSX/RenderViewController.swift`, `installControls` constraints and `updateControlLayout`.

When `scrolling` is true, `activeSummary` is shown at HUD top +8 but `controlsScroll` still begins at HUD top +16. The summary label and the first scroll row can occupy overlapping vertical space; the scroll view is also added after the summary and may cover its text. Reserve a separate header height for the summary while compact or place it inside a pinned header. The user approved the tested compact layout; this finding is a constraint-level risk for other system text sizes and window geometries.

### IN-01 — GPU harness bypasses Renderer contact packing

**Location:** `test_phase05_metal.swift` / `Shared/Renderer.swift`.

The harness writes manually constructed uniform bytes and directly encodes the fragment passes. It proves shader numeric effects and the Swift/Metal field layout, but not the `writeContacts` force/dye scaling and extra-batch logic independently of the app. User-approved live input checks cover the full path today; a future renderer-level test could guard its contact packing during subsequent tuning changes.

## Outcome

No critical findings. Existing Mac state/HUD, iPhone HUD, and RG16F GPU test evidence remains valid for the tested working tree. Findings above are advisory; iPad UI automation timeout and physical-only multitouch stay separately documented in `05-TUNING-VERIFICATION.md`.
