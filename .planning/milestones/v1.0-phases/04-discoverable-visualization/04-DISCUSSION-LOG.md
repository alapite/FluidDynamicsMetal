# Phase 4: Discoverable visualization - Discussion Log

> **Audit trail only.** The implementation decisions for planning are in `04-CONTEXT.md`.

**Date:** 2026-09-25
**Phase:** 4-discoverable-visualization
**Areas discussed:** floating control layout, visibility, placement, material and approved design

---

## Floating control layout

| Option | Description | Selected |
|--------|-------------|----------|
| Native edges | Mac toolbar and compact iOS edge bar, preserving the canvas | |
| Floating controls | Small control overlay on both apps | ✓ |
| Side panel | Persistent controls beside a smaller canvas | |
| You decide | Use the recommended native layout | |

**User's choice:** Floating controls.

## Visibility

| Option | Description | Selected |
|--------|-------------|----------|
| Always visible | Compact group stays present with active-field state | ✓ |
| Auto-hide | Reveal by hover or touch after fading when idle | |
| You decide | Use always-visible behavior | |

**User's choice:** Always visible.

## Placement

| Option | Description | Selected |
|--------|-------------|----------|
| Platform corners | Upper trailing on Mac, lower trailing on iPhone/iPad | ✓ |
| Bottom on both | Same bottom-edge position on both platforms | |
| Top on both | Same top-edge position on both platforms | |
| You decide | Use platform-specific corners | |

**User's choice:** Platform corners.

## HUD style

| Option | Description | Selected |
|--------|-------------|----------|
| System material | Native translucent surface with clear active emphasis | ✓ |
| Solid surface | Opaque, high-contrast surface | |
| You decide | System material with opaque accessibility fallback | |

**User's choice:** System material. The approved design includes an opaque fallback for reduced transparency.

## Design approval

The user approved a compact always-visible floating group with four named field selections and a stateful Pause/Resume action. The same shared state backs controls and existing shortcuts; paused selection redraws without advancing the solver, and touches outside the HUD continue to stir the fluid.

## Agent's Discretion

Concrete native control types, responsive grouping and synchronization mechanism were left to planning and implementation.

## Deferred Ideas

Live tuning, resolution and reset belong to later phases. Previously deferred device-only checks and the user-accepted Phase 3 resize failure risk do not trigger another Phase 3 validation run.
