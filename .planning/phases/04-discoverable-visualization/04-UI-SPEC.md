---
phase: 4
slug: discoverable-visualization
status: approved
shadcn_initialized: false
preset: none
created: 2026-09-25
---

# Phase 4 — UI Design Contract

> Visual and interaction contract for the native macOS and iOS fluid-canvas controls. Phase 4 context decisions D-01–D-07 are binding.

## Design System

| Property | Value |
|----------|-------|
| Tool / preset / component library | None; native AppKit and UIKit controls, no web design system |
| Icon library | None; all five actions have visible text labels |
| Font | Platform system font (SF), semantic native text styles; follows system legibility settings |
| Canvas | Existing full-bleed `MTKView`; preserve the blue-on-black density default and all shader visualizations |

**Composition:** One small, always-visible floating HUD containing a “View” group with four named field choices and a separate Pause/Resume action. It sits *over* the canvas, never in a sidebar or a resized rendering viewport. Use an `NSVisualEffectView` material on Mac and a `UIVisualEffectView` system material on iOS, with platform-native buttons inside. Do not introduce icons in place of field names. No tuning, quality, reset, presets or export controls in this phase.

## Layout and Spacing Scale

All authored spacing and minimum control dimensions use points in multiples of 4; native text metrics and safe-area insets come from the system.

| Token | Value | Usage |
|-------|-------|-------|
| xs | 4 pt | Selection outline inset / tight text-to-indicator gap |
| sm | 8 pt | Gaps between field buttons and between View and Pause rows |
| md | 16 pt | HUD inner padding; outer inset from trailing and top/bottom safe edge |
| lg | 24 pt | Minimum visual separation from surrounding non-HUD elements, if introduced later |

**Placement:** Pin the HUD to the upper trailing corner of the Mac content area and the lower trailing corner of the iOS safe area, each with a 16 pt inset. Align to the trailing edge in both left-to-right and right-to-left layouts. Respect iPhone home indicator, cutouts, iPad multitasking and Mac window resizing; do not overlap window chrome. The overlay's hit area is the actual rounded HUD and controls, not a full-screen wrapper.

**Arrangement:** Prefer two rows of two fields in enum order (Density, Pressure / Velocity, Vorticity), then one full-width Pause/Resume button. Keep the View caption above the four choices. On sufficiently wide, short layouts (e.g. iPhone landscape), use one row of four fields with Pause/Resume on a second row if the names fit at the current text size. In compact height, omit the redundant visible View caption (retain the accessibility group label) and use 8 pt vertical inner padding. If neither horizontal arrangement fits, retain two columns with intrinsic-height buttons; for larger accessibility text use a single column when needed. Layout selection must use available safe-area width/height and measured text, not a fixed device model. Keep all four names and the pause action visible without clipping, horizontal scrolling, truncation or a disclosure menu at standard text sizes. For extreme accessibility text where all five controls cannot physically fit, allow bounded vertical scrolling *inside the HUD only*, with Pause/Resume and the active field announcement remaining visible and all four field choices reachable. HUD width must never exceed safe-area width minus 32 pt; its height must remain within safe-area height minus 32 pt. Set a minimum Mac content size of 320 × 240 pt at standard text sizes and grow that minimum if larger text requires it; verify compact iPhone/iPad landscape and Mac minimum-window layouts.

| Element | macOS minimum | iOS minimum |
|---------|---------------|-------------|
| Field and pause button hit height | 28 pt | 44 pt |
| Field button width | Intrinsic text + padding; no clipped labels | Intrinsic text + padding; no clipped labels |
| HUD corner radius | 12 pt | 12 pt |

Let button heights and widths grow with system text settings. Use native focus rings and hover/pressed feedback, not invisible hover-only controls. Exceptions to the 4 pt scale: platform-provided safe-area insets, native text line heights, material effects and focus-ring geometry.

## Typography

| Role | Native style | Weight / line height | Usage |
|------|--------------|----------------------|-------|
| Group caption | macOS system small label / iOS `.caption1` | Semibold / system default | “View” above fields when height permits |
| Field labels | macOS system control font / iOS `.subheadline` preferred font | Regular unselected, semibold selected / system default | Four full field names |
| Pause action | macOS system control font / iOS `.subheadline` preferred font | Semibold / system default | “Pause” or “Resume” |

Use the platform's system font metrics rather than fixed pixel sizes or line heights. Honor iOS Dynamic Type and Mac text-size/Bold Text settings; allow intrinsic vertical growth and preserve complete words. No large heading or display type is needed over the fluid.

## Color and Visual States

| Role | Native value | Usage |
|------|--------------|-------|
| Dominant canvas | Existing shader-rendered fluid on black | The majority of the screen; do not recolor or dim the fluid |
| Secondary surface | macOS HUD material / iOS system material | Small rounded floating HUD; adapt to light and dark appearance |
| Foreground | `labelColor` / `secondaryLabelColor` on Mac, `.label` / `.secondaryLabel` on iOS | Readable field names and group caption on top of live fluid |
| Accent | System accent/tint color | **Only** the active field's selection fill/outline and optional focus affordance; respect user's Mac accent color |
| Opaque fallback | `windowBackgroundColor` (Mac) / `.systemBackground` (iOS) | HUD when Reduce Transparency is enabled; keep foreground semantic |
| Destructive | Not used | No destructive action in Phase 4 |

**Active field:** Exactly one choice is selected. Combine a persistent system-accent selection treatment (native selected state or bordered fill) with a visible outline/checkmark and semibold label, so selection is legible without relying on color alone; unselected choices remain clearly actionable. If an accessibility-size HUD must scroll, pin a compact “View: {active field}” text summary above the choices so the selected field stays identifiable. Do not use the simulation's dark blue as a UI selection color. Keep Pause/Resume visually distinct from the four mutually exclusive fields; its label indicates the *next* action rather than looking selected. Verify readability over dark-blue density and other rapidly varying fields in both appearances, Increase Contrast and Reduce Transparency; if material alone loses legibility, use the semantic opaque fallback. No motion or animation is needed for state changes.

## Copywriting Contract

| Element | Exact visible copy | State/meaning |
|---------|--------------------|---------------|
| Group caption | `View` | Introduces field choices |
| Extreme-text active summary | `View: Density` / `View: Pressure` / `View: Velocity` / `View: Vorticity` | Only when a scrolling HUD must keep the selected field visible |
| Field choices | `Density`, `Pressure`, `Velocity`, `Vorticity` | Enum order; default selected: Density |
| Pause action while running | `Pause` | Stops advancement; leaves visible field intact |
| Pause action while user-paused | `Resume` | Continues the fluid from stored state |
| Accessibility group label | `Display field` | Names the group for assistive technology |
| Accessibility choice value | `Selected` / `Not selected` | Exposes the active field without color dependence |
| Accessibility pause label | `Pause simulation` / `Resume simulation` | Matches the action and current user-pause state |
| Empty state / error / destructive confirmation | Not applicable | The existing canvas remains present and field switching is non-destructive |

Keep these labels identical across Mac and iOS. Do not replace them with technical slab or shader terminology, or substitute an icon-only picker. Native control state should update after a field click/tap, Space/S on Mac, one-/two-finger double taps on iOS, and app foreground return; read `renderer.state`, never maintain a separate selection/pause cache.

## Interaction Contract

- Selecting a name shows that field directly, without cycling through intermediate views. It updates the one selected choice. While user-paused and active, show the chosen stored field immediately without advancing the solver; selecting the already-active field is harmless. During inactivity do not force a draw or resume.
- Pause/Resume invokes the same shared renderer state transition as Space and the one-finger iOS double tap. Keep Mac S and the two-finger iOS double tap cycling the existing field order, then refresh the visible selection. Preserve paused state, stored fluid and the ability to stir after resuming.
- On iOS, a touch that begins inside the actual HUD must not deposit dye, enter the ongoing fluid-contact set, or trigger canvas single/double-tap shortcuts; a touch outside continues to stir or use existing shortcuts, even while another finger uses a control. On Mac, button clicks must not begin a fluid drag; an existing key-down monitor must not double-toggle pause when Space activates a focused button.
- Field buttons remain keyboard-focusable on Mac and accessible as labeled native buttons on both platforms. Keep reading order View → Density → Pressure → Velocity → Vorticity → Pause/Resume; keyboard focus visits the five actionable buttons in that order. Full accessibility and shortcut audit is Phase 6, but new controls must expose meaningful labels now.

## Registry Safety

| Registry | Blocks used | Safety gate |
|----------|-------------|-------------|
| shadcn / third-party | None | Not applicable; native AppKit/UIKit only |

`workflow.ui_safety_gate` is enabled; no remote registry, downloaded block or third-party UI code is used in this phase.

## Checker Sign-Off

- [x] Dimension 1 Copywriting: PASS — exact native control labels and state-dependent action copy
- [x] Dimension 2 Visuals: PASS — always-visible platform placement, canvas priority and input boundaries
- [x] Dimension 3 Color: PASS — semantic system colors, non-color selection cues and opaque fallback
- [x] Dimension 4 Typography: PASS — system text styles, intrinsic growth and large-text layouts
- [x] Dimension 5 Spacing: PASS — 4 pt tokens, minimum hit sizes, safe-area and compact rules
- [x] Dimension 6 Registry Safety: PASS — no third-party or registry components

**Approval:** approved 2026-09-25 (six-dimension inline review; typed GSD UI checker unavailable in this runtime)
