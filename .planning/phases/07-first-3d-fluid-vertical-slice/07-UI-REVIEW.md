---
phase: "07"
slug: first-3d-fluid-vertical-slice
type: ui-review
audited: 2026-11-20
method: code-only (native AppKit/Metal; no screenshots, interaction_capture false)
baseline: 07-UI-SPEC.md
overall_score: 14/24
---

# Phase 07 — UI Review

Audited the current `Sources/macOS/RenderViewController.swift` (with string greps of other `Sources/macOS` and `Sources/Shared` files) against the Phase 7 UI-SPEC. The code includes the Phase 8 spatial-inspection changes, so several findings are **legitimate supersessions by Phase 8** rather than defects. Their remedy is a Phase 8 UI-SPEC addendum that formally supersedes the Phase 7 strings and visuals. No screenshots were captured, and runtime-only behaviour was not exercised. That covers S/Space handling and the Tab order.

## Pillar Scores

| Pillar | Score | Key finding |
|---|---|---|
| 1. Copywriting | 2/4 | Note, slice descriptor and a11y labels drifted from contract; "Preparing 3D lesson…" status absent |
| 2. Visuals | 2/4 | "No canvas overlays" violated by the orientation guide, tracers and camera/slice controls (Phase 8 supersession) |
| 3. Color | 3/4 | Amber palette is shared between the shader and the native legend; panel is not `.hudWindow` material |
| 4. Typography | 3/4 | 11/13/17 pt and 400/600 match; 13 pt semibold Slice/Camera headings add an unspecified role |
| 5. Spacing | 3/4 | 8/16/4 tokens and 16/12 pt shell insets respected; nested inspection stacks use flat 8 pt gaps |
| 6. Experience Design | 3/4 | Transactional fallback, NSAlert copy and pinned transport are good; interaction model superseded |

## Top Fixes

1. **Reconcile the contract with the shipped copy.**
   - `threeDNote` (line ~50) now mentions tracers, says "slice" instead of "cross-section", and drops the "Dye can move…" wording.
   - The descriptor reads "XY slice · Z depth: 50%" instead of "halfway through Z" (lines ~47 and ~889).
   - Fix with a Phase 8 UI-SPEC addendum.
2. **Implement or formally drop the "Preparing 3D lesson…" status.** The spec required it only if the UI yields during preparation. No such string exists. If preparation is synchronous, record that and close the item.
3. **Restore the `.hudWindow` material or amend the contract.** The panel uses an opaque `windowBackgroundColor` (line ~297). This is visually safe and satisfies the reduced-transparency fallback, but it departs from "preserve existing material".
4. **Align the accessibility label and help text.**
   - The canvas label (line ~891) describes depth, tracers and orbit/scroll.
   - The canvas now accepts drag and scroll, which contradicts "read-only, no camera".
   - The Restart help text differs from the spec.
5. **Re-check Tab order.**
   - The spec's order was Experiments → Run → Step → Restart → body. The code now sets `restartButton.nextKeyView = inspectionPlaneControl`.
   - This is plausibly right for the new controls.
   - Confirm that static text adds no tab stops.
6. **Confirm hidden 2D content is unreachable in 3D.** The field buttons and About text sit under `twoDBodyStack.isHidden`. `lessonGroup.isHidden` is set (line ~1184).

## Detailed Findings

### Copywriting (2/4)
- WARNING: the `threeDNote` text differs from the contract (see fix 1). It keeps "Steps count solver advances".
- WARNING: the descriptor reads "XY slice · Z depth: 50%", and its accessibility label reads "XY slice, Z depth 50 percent" (line ~523). Both were superseded by Phase 8's adjustable depth.
- PASS: "3D Dye Advection", "Dye concentration", "Less dye → More dye" and the legend accessibility label all match.
- PASS: the failure copy matches (lines ~1130–1133). "Continue in 2D" is the default button, and Escape is handled.
- INFO: an extra "Couldn't continue 3D Dye Advection" variant covers failures in an active session (line ~1126). It is reasonable.
- PASS: Run/Step and "Reset fluid"/"Restart experiment" titles follow the spec rules.

### Visuals (2/4)
- SUPERSEDED (Phase 8):
  - A 64×64 `OrientationGuide3DView` overlay sits at 16 pt insets (lines ~463–466), where the spec said no overlays, axes or camera.
  - The body also gained slice, tracer and camera stacks (lines ~639–770).
- PASS: the colour legend is excluded from accessibility, and the design stays icon-free.
- WARNING: the canvas, the tracers and a long scrolling body of controls now compete for focus. The spec's body was a short, tertiary note.

### Color (3/4)
- PASS: the legend draws `FieldVisualization3D.paletteStops` with explicit sRGB stops (lines ~1401–1412). The 2D legend keeps `field.palette`.
- PASS: `NSColor.labelColor` is used for the outline and the note, and there is no hardcoded hex.
- WARNING: the pale-cyan tracers add a second data colour. Verify its contrast against the amber palette.
- WARNING: the panel does not use the `.hudWindow` material (fix 3).

### Typography (3/4)
- PASS: 17 pt semibold heading, 11 pt regular descriptor and legend, 11 pt semibold "Dye concentration", and a 13 pt regular note with 1.5 line height (lines ~518–537).
- WARNING: `sliceHeading` and `cameraHeading` use 13 pt semibold (lines ~650 and ~652), a role the spec did not include.
- WARNING: the other multiline fields have no line-height rule.

### Spacing (3/4)
- PASS: the body uses 16 pt spacing, the intro 8 pt and the legend 4 pt (lines ~515–517). The shell insets are 16 and 12 pt (lines ~620–626).
- WARNING: the nested inspection stacks use 8 pt for every gap, which flattens the heading/control/group hierarchy.
- PASS: the panel width is clamped to `min(368, max(240, availableWidth - 16))` with the Restart-wrap logic, and starts at 248 as the spec expects.

### Experience Design (3/4)
- PASS: `modeTransitionInProgress` disables the selector, Run, Step and Restart (lines ~1054–1059). `presentThreeDModeFailure` restores 2D before showing the alert.
- PASS: ⌘P, ⌘→ and ⌘R are preserved. Both menus use 2D/3D mode groups.
- SUPERSEDED (Phase 8): the canvas now handles drag, scroll and tracking areas (lines ~1228–1330 and ~1362), where the spec said it was read-only.
- WARNING: there is no "Preparing 3D lesson…" status (fix 2).
- NOT VERIFIED: S/Space handling and the `nextKeyView` order need a runtime check.

## Notes

- **Registry audit:** skipped. The UI is native AppKit with no `components.json`.
- **Scope:** this review rests on the contract and the code. The auditor did not read the SUMMARY, PLAN or CONTEXT files in full.
- **Not a human review:** this does not replace the pending manual visual and accessibility review recorded in 07-09.
