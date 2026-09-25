---
phase: 5
slug: live-fluid-tuning
status: approved
shadcn_initialized: false
preset: none
created: 2026-09-25
reviewed_at: 2026-09-25T18:45:28Z
---

# Phase 5 — UI Design Contract

> Native macOS and iOS live-tuning contract. Phase 5 context decisions D-01–D-10 and the Phase 4 field/pause UI contract are binding. Applies to CTRL-02, CTRL-03 and CTRL-04.

## Design System

| Property | Value |
|----------|-------|
| Tool / preset / component library | None; extend the existing AppKit/UIKit HUD with native buttons, labels and continuous sliders |
| Icon library | None required; disclosure may use a native chevron alongside visible text, never as its only label |
| Font | Platform system font (SF) using native control/caption text styles and system metrics |
| Focal point | Full-bleed, interactive Metal fluid canvas; compact floating HUD is the secondary control surface |

**Composition:** Extend the *same* rounded, material-backed field/pause HUD from Phase 4. Keep the upper-trailing Mac and lower-trailing iOS safe-area anchors, 16 pt outer inset, four named field choices and Pause/Resume. Place a full-width `Show Tuning` / `Hide Tuning` disclosure after Pause/Resume in reading order. On a fresh launch the section is closed; opening it reveals Force, Dye, Swirl and Fade in that order. Only the actual HUD bounds intercept canvas input. No new panel, toolbar, modal, presets, persistence, quality control or visible reset action. Source: `05-CONTEXT.md` D-01–D-03; `04-UI-SPEC.md`.

## Layout and Spacing Scale

All authored layout spacing uses points from the existing four-point grid. Native safe-area insets, system text metrics, slider geometry, scrollbar width and focus-ring geometry are system-managed exceptions.

| Token | Value | Usage |
|-------|-------|-------|
| xs | 4 pt | Label-to-percentage gap, disclosure indicator gap |
| sm | 8 pt | Field/button gaps, label-to-slider gap, separation between tuning rows |
| md | 16 pt | HUD inner padding, canvas-to-HUD edge inset, gap between View and Tuning groups |
| lg | 24 pt | Reserved separation if another HUD group is introduced later |
| xl | 32 pt | Combined left/right HUD padding; combined top/bottom safe-area allowance |
| 2xl | 48 pt | Reserved large-layout token, not added to this compact HUD |
| 3xl | 64 pt | Reserved page-level token, not added to this compact HUD |

**Disclosure and rows:** Disclosure height is at least 28 pt on Mac and 44 pt on iOS; use the same native button affordance as Pause/Resume, with a visible expanded/collapsed indicator in addition to the text. Each tuning row contains a full, untruncated name and a right-aligned integer percentage on one line, then a full-width native slider beneath. Use 8 pt between the label line and slider and between adjacent rows. Slider rows grow to fit native control metrics; the iOS row provides at least 44 pt of operable slider height. Do not use a slider's track tint as the only indication of its current value.

**Bounds and overflow:** The HUD width is at most the available Mac content width or iOS safe-area width minus 32 pt, normally no more than 320 pt when expanded; preserve at least 192 pt when available. Its height never exceeds the available content/safe-area height minus 32 pt. Reflow the Phase 4 field buttons using their existing two-/one-column (and iOS wide-landscape four-column) rules rather than truncating any name. At ordinary heights, keep field choices, Pause/Resume and the disclosure visible above the tuning rows; scroll the overflowing tuning content *inside* the HUD. At short heights or large text, switch to **one** bounded vertical scroll region containing field choices → Pause/Resume → disclosure → tuning rows in that order, rather than nesting a field scroll inside a tuning scroll. Keep `View: {active field}` visible outside that region whenever the field buttons can scroll offscreen. All controls must remain reachable within the HUD, even in a minimum-size Mac window or compact iPhone landscape. Preserve the Mac 320 × 240 pt content minimum from Phase 4; do not force the window larger solely to show tuning. Expansion must not move the HUD anchor or turn its container into a full-screen hit target. Source: `05-CONTEXT.md` D-02–D-03; `04-UI-SPEC.md`.

## Typography

Use **two semantic text sizes per platform**, with **regular and semibold** as the only authored weights. Do not fix a pixel size: platform-native text styles determine point size and line height as the user changes display settings.

| Role | macOS | iOS | Weight / line height |
|------|-------|-----|----------------------|
| Control body | System control font | Preferred `.subheadline` | Regular for labels and values; system control/subheadline line height |
| Group caption / helper | System small-label font | Preferred `.caption1` | Regular for hint, semibold for group caption; system caption line height |

Use semibold for the currently selected field, the Tuning disclosure and the active `View: …` summary. Let native controls adapt to Mac legibility settings and iOS Dynamic Type/Bold Text; allow labels to wrap vertically at accessibility sizes, without clipping or introducing a third/fourth custom font size. The percentage must remain text, not an icon or color-only marker. Source: `04-UI-SPEC.md` typography and Phase 5 percentage decision D-08.

## Color and Visual States

The 60/30/10 hierarchy is **relative visual priority**, not a request to recolor the renderer: dominant canvas (at least 60% of visible area), secondary native HUD surface (at most about 30%), accent affordances (at most about 10%). The HUD becomes taller while expanded but stays narrow and floating.

| Role | Native value | Usage |
|------|--------------|-------|
| Dominant (60%+) | Existing shader-rendered fluid over black | Canvas remains the visual anchor; preserve original blue-on-black density appearance |
| Secondary (up to 30%) | `NSVisualEffectView` HUD material / `UIVisualEffectView` system material | One compact, rounded control surface, in both light and dark appearance |
| Foreground | `labelColor` / `secondaryLabelColor` on Mac; `.label` / `.secondaryLabel` on iOS | Names, percentages and subtle fade hint on the HUD |
| Accent (up to 10%) | User's system accent / native tint | **Only** selected field emphasis, the native slider filled tracks/thumbs, and keyboard focus indicators |
| Opaque fallback | `windowBackgroundColor` on Mac / `.systemBackground` on iOS | Replace translucent HUD surface when Reduce Transparency is enabled |
| Destructive | Not used | No destructive actions in Phase 5 |

Use the native enabled/pressed/focus states for disclosure and sliders; do not add a second decorative accent or shader-derived tint. The field retains its Phase 4 checkmark/outline and semibold selection cue. The disclosure conveys its state through its changing label and indicator, not tint alone. Keep percentage text and slider position in sync over all displayed fields and while paused. Prefer native instantaneous changes over ornamental animation; if any expansion transition is added, respect Reduce Motion. Source: `04-UI-SPEC.md` color and selection contract.

## Copywriting Contract

| Element | Exact visible copy | Meaning |
|---------|--------------------|---------|
| Primary disclosure CTA, closed | `Show Tuning` | Open the four controls; initial state on every launch |
| Primary disclosure CTA, open | `Hide Tuning` | Close the controls without resetting values |
| Field choices and pause | `Density`, `Pressure`, `Velocity`, `Vorticity`; `Pause` / `Resume` | Retain Phase 4 names and action-dependent pause label |
| Slider names, in order | `Force`, `Dye`, `Swirl`, `Fade` | Use identical user-facing names on both platforms |
| Value format | `{integer}%`, rounded from slider position (e.g. `Force 50%`) | Display 0–100% while the thumb moves; no raw solver constants |
| Fade helper | `Higher Fade = faster fade` | Display under Fade when expanded; explain slider direction |
| Fade accessibility hint | `Higher values fade dye and motion faster. Zero percent is the slowest available fade.` | Prevent interpreting 0% as zero decay |
| Tuning accessibility group label | `Fluid tuning` | Group four independently adjustable values |
| Slider accessibility label/value | `Force` / `50%`, `Dye` / `40%`, `Swirl` / `20%`, `Fade` / `17%` at defaults | Refresh values continuously; native adjustable slider semantics |
| Empty state / error state / destructive confirmation | Not applicable | The fluid canvas is always present, changes clamp to bounded values, and this phase has no loading, destructive or confirmable action |

No `Submit`, `Save` or transient success banner: adjusting a slider is the action and the fluid/percentage is its feedback. Keep existing field selection and Pause/Resume accessibility names. Source: `05-CONTEXT.md` D-08–D-10 and Phase 4 copy.

## Value and Interaction Contract

**One shared user-facing range:** Each continuous native slider has position `p` from 0 to 1, formatted as `round(100 × p)%`. Force, Dye and Swirl map to their existing bounded shared-state ranges with `value = 2p`. Their original defaults therefore display **Force 50%, Dye 40%, Swirl 20%**. Do not imply the percentage is an absolute physical unit or show the stored constant in the HUD.

**Fade mapping (locked for both platforms):** Rightward motion always fades both dye and motion faster. Set the 0% endpoint to retention **0.9995**, the 17% detent to the exact original retention **0.998**, and the 100% endpoint to retention **0.9905**. Interpolate linearly on each side of the 17% detent: for `0 ≤ p ≤ 0.17`, `retention = 0.9995 − 0.0015 × p / 0.17`; for `0.17 < p ≤ 1`, `retention = 0.998 − 0.0075 × (p − 0.17) / 0.83`. The inverse maps the exact original 0.998 to `p = 0.17`. Do not quantize the *underlying* value to integer-percent steps while dragging; round only its visible readout. The range deliberately spans both sides of the original near-full-retention behavior; 0% still has gentle fade. The shared `SimulationTuning` retains its broader safety bounds. Source: `05-CONTEXT.md` D-09–D-10 and `05-RESEARCH.md` §Recommended implementation seams; exact detent/range are Phase 5 design defaults.

**Behavior and state:** Apply changed Force or Dye to the next movement of an existing stroke and to later strokes, never retroactively to deposited fluid. At Force 0% dye can still be deposited; at Dye 0% stirring still works. A single tap outside the HUD deposits dye if Dye is above zero. Swirl changes affect already-moving fluid on the next running frames, without new input; Swirl 0% removes additional curl but not stirring. Fade changes affect dye and velocity already in the simulation as well as subsequent input on the next running frames. Paused adjustments update the controls/state but do not advance a paused frame, apply queued strokes or alter its image until resuming. Read the current shared tuning state to refresh controls; do not keep a second solver-value cache. Source: `05-CONTEXT.md` D-04–D-07 and `05-RESEARCH.md`.

**Input and focus:** Opening Tuning remains in effect through all canvas interactions, field changes, pause/resume, resizing and foreground return until the user presses Hide Tuning; a fresh launch starts closed and with original values. Slider dragging, scrolling and taps/clicks originating inside the actual HUD never become fluid contacts or trigger one-/two-finger iOS canvas shortcuts. Outside its bounds, canvas dragging and single-tap dye and the existing shortcuts continue to work. Mac Tab/Shift-Tab follows View choices → Pause/Resume → disclosure → Force → Dye → Swirl → Fade when open, skipping hidden controls when closed; native arrow keys adjust the focused slider, and Space activates a focused button once rather than toggling simulation pause. iOS sliders expose native adjustable values and the same reading order. Preserve the currently selected field summary in constrained scrolling. Source: `04-UI-SPEC.md` interaction contract and `05-CONTEXT.md` D-01–D-05.

## Registry Safety

| Registry | Blocks used | Safety gate |
|----------|-------------|-------------|
| shadcn / third-party | None | Not applicable — native AppKit/UIKit controls only; no remote blocks |

`workflow.ui_safety_gate` is enabled. No third-party registry or downloaded UI code is part of this contract.

## Checker Sign-Off

- [x] Dimension 1 Copywriting: PASS — specific Show/Hide Tuning actions, live values, directional Fade help; no empty/error/destructive states in this canvas phase
- [x] Dimension 2 Visuals: PASS — fluid remains the focal point, one anchored HUD and explicit compact/scroll hierarchy
- [x] Dimension 3 Color: PASS — 60/30/10 priorities, semantic native surfaces and an enumerated accent-only list
- [x] Dimension 4 Typography: PASS — two semantic sizes per platform, two weights and native body line height
- [x] Dimension 5 Spacing: PASS — standard four-point scale, native-metric exceptions and bounded control sizes
- [x] Dimension 6 Registry Safety: PASS — no third-party or registry blocks; native AppKit/UIKit only

**Approval:** approved 2026-09-25 (six-dimension inline review; typed GSD UI agent types unavailable in this runtime)
