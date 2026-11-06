---
phase: 7
slug: first-3d-fluid-vertical-slice
status: approved
shadcn_initialized: false
preset: none
created: 2026-11-06
reviewed_at: "2026-11-06T20:31:35Z"
review_mode: inline
---

# Phase 7 — UI Design Contract

> Native Mac visual and interaction contract for **First 3D Fluid Vertical Slice**. Produced inline using the GSD UI-researcher role. Design-contract review is separate from implementation, screenshot, runtime, accessibility and numerical verification.

## Scope and Authority

Implement the Mac-only **3D Dye Advection** entry, one fixed central XY dye section, existing transport/step counter, mode-specific panel content and safe failure recovery. Retain the existing 2D experience and iOS-only-2D mode list. This document specifies presentation, not the solver algorithm.

Sources of authority, in order:

1. `.planning/phases/07-first-3d-fluid-vertical-slice/07-CONTEXT.md`, especially D-01–17; `.planning/REQUIREMENTS.md` and `.planning/ROADMAP.md` §Phase 7.
2. The user's UI-phase confirmation on 2026-11-06: heading → slice descriptor → concentration legend → always-visible factual note; preserve the existing panel and pinned transport.
3. Current `Sources/macOS/RenderViewController.swift`, `Sources/Shared/{SimulationState,Renderer}.swift`, `README.md` and `Tests/UI/macOS/HUDUITests.swift` for established native behavior.
4. `07-RESEARCH.md` for integration constraints and the proposed midpoint convention. Numerical recommendations are not passing evidence; finalize the numerical contract in implementation planning.

**Do not add:** dimension switch, new window/sidebar/toolbar, camera/orbit/zoom, slice-axis or depth controls, 3D particles/trails, field switching, injection, speed selector, prediction exercise, volume rendering, resolution control or performance badge. Phases 8–10 retain their roadmap ownership. Reusing existing Restart/completion machinery does not establish Phase 9 acceptance.

## Design System

| Property | Value |
|---|---|
| Tool | Manual native AppKit design system; no web UI tooling |
| Preset | Not applicable |
| Component library | AppKit: existing `NSPanel`, `NSVisualEffectView`, `NSStackView`, `NSScrollView`, `NSPopUpButton`, `NSMenu`, `NSButton`, `NSTextField`; native `NSAlert` for initialization failure |
| Rendering | Existing `MTKView`; additional read-only 3D fixed-slice presentation path |
| Icon library | No new icons or icon-only actions; retain native control/window glyphs |
| Font | macOS system font; existing native control font metrics; no downloaded/custom font |
| Theme | System Light/Dark appearance, semantic label/surface/accent colors, opaque reduced-transparency fallback |
| Measurement units | AppKit points for UI layout and type; drawable pixels only for Metal viewport and image fixtures |
| Source | Existing AppKit implementation and D-11/D-15; no React/Vite/shadcn stack detected in the relevant app sources |

The shadcn initialization and registry-vetting branches are **not applicable** to this native stack. Do not install a package or run a shadcn initializer. Native menus, focus rings and control states remain system-rendered, not web-styled imitations.

## Visual Hierarchy and Layout

**Primary focal point:** the single warm amber dye patch and its evolving cross-section on the black canvas. **Secondary:** pinned mode selection and transport. **Tertiary:** short orientation, legend and factual explanation in the movable controls panel. Do not place identity, steps or orientation overlays on the canvas.

### Preserve the existing shell

- Keep the separate movable **Simulation Controls** utility panel, title bar/close behavior, `.hudWindow` material, frame autosave name `SimulationControls`, full-screen auxiliary behavior and View-menu reopening command.
- Preserve the current content-width target of **368 pt**, screen-bounded height calculation, pinned controls and vertical body scroll. Do not copy the constructor's obsolete 248 pt initial width as the final target; `updateControlLayout()` sets 368 pt.
- Preserve the canvas window's existing **320×240 pt** minimum and independent resizing. Do not reserve a sidebar in the canvas or resize the canvas when choosing a mode or opening the panel.
- Preserve the existing shell's 16 pt horizontal insets and 12 pt vertical/scroll separation metrics. These are inherited native-layout exceptions, not new tokens and not a request to retune 2D controls.
- If the available screen bounds require a narrower panel, constrain it to the screen's visible width, retain native minimum control sizes, wrap text, and place Restart below Run/Step when the transport row no longer fits. Keep mode selection, Run/Step and step count outside the body scroll; Restart remains pinned when wrapped. No horizontal text clipping or hidden transport action.
- Closing/reopening, moving or scrolling the panel must not reset the lesson or change pause, fields, pending steps or the numerical grid. Restore the selected mode and current step from renderer state.

### Content order in 3D

Pinned area, unchanged in purpose:

1. Experiment pop-up showing **3D Dye Advection**.
2. Existing transport: **Run/Pause/Resume**, **Step**, **Restart experiment**.
3. **Step {n}** counter.

Scrollable body, newly populated for 3D:

1. **3D Dye Advection** heading.
2. **XY slice · halfway through Z** descriptor.
3. **Dye concentration** label, amber gradient bar and **Less dye → More dye** legend.
4. Always-expanded factual note from the Copywriting Contract.

All body text wraps to panel content width; no ellipsized lesson heading, descriptor, note or legend labels. At normal panel size the factual note is visible without opening a disclosure; on a constrained screen it remains scroll-reachable. Do not put it behind **About this simulation**.

Hide the entire 2D lesson question/adjustment section, **View** heading and field buttons, old field explanation/legend, overlay checkboxes and trails explanation, Tuning disclosure/sliders, and the old two-dimensional About disclosure/text in 3D. Reuse the legend view with an explicit 3D palette or provide an equivalent native legend; never show both old and new legends. Hidden sections occupy no layout space and leave no focusable descendants. On return to 2D restore its mode-appropriate sections, session preferences and existing copy rather than leaving 3D content behind.

## Navigation Contract

Both the Mac experiment pop-up and the experiment portion of the **Simulation** menu show the same flat grouping, order and active identity:

| Row | Display title | Selectable | Existing shortcut |
|---|---|---|---|
| Group heading | 2D | No | None |
| Mode | Free Play | Yes | ⌘1 |
| Mode | Dye carried by a flow | Yes | ⌘2 |
| Mode | Two interacting vortices | Yes | ⌘3 |
| Mode | Stretching dye by stirring | Yes | ⌘4 |
| Separator | Native separator | No | None |
| Group heading | 3D | No | None |
| Mode | 3D Dye Advection | Yes | None |

- Use native nonactionable section/header rows: headings have no action, shortcut or selected checkmark and cannot commit a mode by pointer or keyboard. Ensure menu auto-enabling cannot turn headers into actions. A native header presentation may be used where available; do not imitate a selectable disabled lesson.
- Keep one experiment selector. No nested dimension chooser and no redundant `2D` prefixes on existing titles.
- Bind selectable rows to explicit mode identity, not `indexOfSelectedItem` into `SimulationMode.allCases` or offsets derived from header positions. Both menus update from the **committed** renderer mode; exactly one selectable mode is active. Existing ⌘1–4 meanings do not shift.
- Selecting 3D successfully always seeds the lesson and opens paused at **Step 0**, including reselection. Selecting a 2D lesson retains its established reset/default behavior. Selecting Free Play creates a fresh running canvas and restores Free Play's session preferences. Clear stale drag/tap/step work on transitions.
- iOS selector content and interaction remain 2D-only; neither group headings for 3D nor the new lesson appear there.

## Fixed-Slice Presentation

- Display one face-on central **XY** cross-section of the genuine 64³ volume. Sample world `z=0.5`; for cell-centred dye this interpolates equally between zero-based Z planes **31 and 32**. It is neither a maximum/average projection nor a single arbitrarily chosen middle voxel plane.
- Present X increasing rightwards and Y upwards. Resolve texture/screen Y conversion once in the 3D presentation path and verify with an asymmetric fixture. Do not change the established 2D orientation.
- Centre a square viewport with side equal to the smaller available canvas dimension, converted to drawable pixels. Remaining canvas is black. Resize changes presentation only, never the fixed grid, seed or step count.
- Seed appearance: one compact smooth off-centre patch intersecting this plane and visibly nonblank at step 0. Motion should read as contained rolling/tumbling flow with dye passing through the plane; numerical fixtures, not this image, establish actual three-dimensional evolution.
- No canvas heading, cube outline, grid, border, axes, arrows, camera controls, visual tracers, fake depth shading or decorative motion. The palette is the only new visual encoding.
- A valid later black slice is not automatically a resource failure: dye can leave the plane. Do not move the slice, replenish the blob, brighten by normalizing each frame or insert an unverified “all dye has left” message.

## Spacing Scale

New 3D content uses the declared standard scale, in AppKit points rather than CSS pixels:

| Token | Value | Usage |
|---|---|---|
| xs | 4 pt | Concentration label/bar/legend sub-gaps; existing transport inter-button spacing |
| sm | 8 pt | Heading-to-descriptor, related body rows, wrapped transport rows |
| md | 16 pt | Gap before legend group and before factual note; existing horizontal shell inset |
| lg | 24 pt | Reserved; not required by this compact body |
| xl | 32 pt | Reserved; not required by this phase |
| 2xl | 48 pt | Reserved; not required by this phase |
| 3xl | 64 pt | Reserved; not required by this phase |

Use 8 pt between heading and descriptor, 16 pt before the concentration group, 4 pt within that group, and 16 pt before the note. No new arbitrary padding values or empty spacer sections.

**Native inheritance exceptions:** existing 12 pt panel top/bottom/scroll separation is retained to avoid a 2D shell restyle. The existing 12 pt legend-bar height and 28 pt minimum transport height are component dimensions, not spacing tokens. AppKit's own menu insets, native control interiors, focus rings, hairline legend outline and title-bar chrome are platform-managed and excluded from the authored spacing grid. These exceptions are explicit; do not silently replace them with web defaults.

## Typography

Three authored size roles and exactly two weights for the new 3D body; keep native control/menu/title-bar typography platform-managed. Values are native baseline point sizes, not a site-wide restyle.

| Role | Size | Weight | Line Height | Usage |
|---|---|---|---|---|
| Caption / label | 11 pt (`NSFont.smallSystemFontSize` baseline) | Regular 400; semibold 600 only for “Dye concentration” label | Natural native line height; multiline minimum 1.2× | Slice descriptor, concentration label and legend endpoints |
| Body / counter | 13 pt (`NSFont.systemFontSize` baseline) | Regular 400 | Multiline factual note minimum 1.5× | Factual note; existing step counter remains native regular |
| Heading | 17 pt (system baseline + 4 pt) | Semibold 600 | Multiline minimum 1.2× | “3D Dye Advection” body heading only |
| Display | No separate size | Not applicable | Not applicable | No display typography or canvas lettering |

Use named native text roles/tokens backed by the system font, not a bundled font. Set wrapping paragraph metrics for the note without clipping glyphs; native single-line controls retain intrinsic metrics. Do not force all 2D text to these sizes. Keep existing labels' native accessibility appearance behavior; use semantic colors and allow fitting height to grow with text/accessibility metrics instead of shrinking text to fit. No third authored weight, light-grey ultra-small instructional text or animated counter emphasis.

## Color

### Native chrome and emphasis

The **60/30/10** hierarchy applies to the **controls chrome**, not measured percentages of fluid pixels: 60% dominant quiet native surface, 30% secondary content/control regions, and at most 10% interactive accent emphasis. Keep the existing native material; do not manufacture colored panels to force an area ratio.

| Role | Value | Usage |
|---|---|---|
| Dominant (60%) | Existing `.hudWindow` material; `NSColor.windowBackgroundColor` opaque fallback | Controls-panel surface in system Light/Dark appearance |
| Secondary (30%) | Native control surfaces; `NSColor.labelColor` / `secondaryLabelColor` | Text/control hierarchy; use primary label color when secondary text is insufficient in Increase Contrast |
| Accent (≤10%) | System `NSColor.controlAccentColor` / native focus and selection rendering | Reserved for native keyboard focus, active menu selection and the active Run/Pause/Resume transport control's system pressed/highlight state; preserved 2D selected-field treatment |
| Destructive / error | Native alert warning icon and standard button styling; `NSColor.systemRed` only if a destructive action is later explicitly introduced | No red Restart button, red dye legend or custom danger surface in this phase |
| Simulation canvas | `#000000` | Black empty concentration and square-viewport letterbox/background |

Do not tint every button, heading, panel or note amber. **Amber is scalar data**, not a second interactive accent or error color. The existing 2D blue dye palette stays unchanged. Never communicate pause, selection or failure by color alone: use labels, checkmarks, native enablement and error copy.

### Fixed 3D concentration palette

| Normalized concentration | sRGB-encoded RGB / hex | Meaning |
|---|---|---|
| 0.0 | `(0, 0, 0)` / `#000000` | No dye |
| 0.5 | `(237/255, 139/255, 35/255)` / `#ED8B23` | Intermediate concentration, warm orange/amber |
| 1.0 | `(1, 241/255, 214/255)` / `#FFF1D6` | High concentration, pale cream |

Use `t=clamp(concentration,0,1)` and piecewise linear interpolation of these encoded channel values, stop at 0.5. Shader and panel legend share these stops and positions; make the legend's interpolation explicit rather than relying on unspecified color-space blending. Do not apply an extra gamma transform in only one path. Keep native UI text outside this data transfer function. Verify numeric output in the selected render-target format and visually inspect the managed-display result before acceptance.

Scale is fixed across steps, pause/resume and resize; no frame-maximum normalization or exposure animation. Higher concentrations clip to the top color without changing the underlying field. A nonfinite value is an encoder/numerical error to detect, not a color to silently disguise. Brightness means local concentration, not substance identity, opacity of a full volume or physical calibration.

## Copywriting Contract

### Visible copy

| Element | Exact copy / rule |
|---|---|
| Panel title | **Simulation Controls** — unchanged |
| Selector accessibility label | **Experiments** — unchanged |
| Group headings | **2D**, **3D** |
| New selector/menu entry and body heading | **3D Dye Advection** |
| Slice descriptor | **XY slice · halfway through Z** |
| Concentration label | **Dye concentration** |
| Concentration legend | **Less dye → More dye** |
| Primary transport CTA at paused step 0 | **Run**; preserve this established compact transport label rather than inventing a new CTA |
| While running | **Pause** |
| Paused after advancement | **Resume** |
| Single-step CTA | **Step** |
| Existing reset CTA in 3D | **Restart experiment** |
| Counter | **Step {n}** — decimal logical step count; no seconds, frame count, progress bar or “{n}/600” teaching treatment |
| Factual note | **This is a cross-section of dye carried by an evolving 3D flow. Brighter areas contain more dye. Dye can move out of this fixed plane. There is no explicit dye fading, but numerical advection can smooth the dye. Steps count solver advances, not seconds.** |
| Transient preparation status, only if UI yields during initialization | **Preparing 3D lesson…** |
| View-menu panel action | **Show Simulation Controls** / **Hide Simulation Controls** — preserve ⌥⌘K |

Run, Pause, Resume and Step intentionally retain the user's established transport vocabulary (D-11/D-12/D-16). Their surrounding lesson identity and explicit accessibility labels remove ambiguity; do not flag these context-locked single-word controls as generic submission CTAs.

### Empty, error and destructive/reset states

| State | Copy / action |
|---|---|
| Step-zero 3D | Not an empty state: render the seeded amber patch paused at Step 0. No “no data” card or blank success screen. Run or Step is the next action. |
| Valid later empty cross-section | Keep the black slice and always-visible factual note. No additional heading/body or blocking card; the note already explains out-of-plane transport. Do not assert the cause from pixels alone. |
| Free Play empty state | Preserve the empty running 2D canvas and existing instructions; do not add a new modal or onboarding overlay. |
| Initialization error heading | **Couldn’t open 3D Dye Advection** |
| Initialization error body when prior 2D mode retained | **The 3D simulation could not be prepared. Your 2D simulation is still available. Continue in 2D, or choose 3D Dye Advection again to retry.** |
| Initialization error body when fresh Free Play restored | **The 3D simulation could not be prepared. Free Play has been restored. Continue in 2D, or choose 3D Dye Advection again to retry.** |
| Error action | **Continue in 2D** — single safe acknowledgement button, default Return action; Escape acknowledges the same already-restored safe state. Do not label it “OK”. |
| Error details | Local diagnostics identify failed resource/pipeline/command; do not dump stack traces, file paths or an unverified diagnosis into the main learner-facing copy. |
| Restart/reset confirmation approach | Existing immediate reseed; **no confirmation dialog**, matching established simulation transport. It clears transient simulation progress, not a saved user document. No destructive-red styling or new delete action. |

Keep Restart as the existing convenience to reseed paused at Step 0 and clear pending steps/input; do not add new speed/view preferences or claim complete replay/repeatability acceptance here. This contract adds no 3D-specific completion screen. If existing lesson-cap machinery is deliberately reused, retain its existing “Experiment complete. Restart to compare.” fallback and Run/Step disablement without treating it as Phase 9 completion verification; the full 600-step teaching/comparison flow is still Phase 9 work.

## Interaction and State Contract

| State / event | Visible state and allowed behavior |
|---|---|
| Launch | Existing running Free Play, original 2D controls/preferences-at-launch; no automatic 3D entry |
| Preparing 3D | Keep prior usable 2D selection/image until construction/reset succeeds. Serialize transitions; disable duplicate transport/selection actions only while busy. If preparation yields to the UI, show the factual preparation status in the panel, not fake animated fluid or a blank 3D success state. |
| Successful entry | Commit selected 3D identity, refresh whole panel/menu, show seeded fixed slice, **Run**, enabled **Step**, **Step 0**; no hidden field/adjustment state leak |
| Run / Pause / Resume | Same shared state as menu and canvas Space. Counter changes only for accepted logical solver advances; update text without decorative animation. |
| Paused Step | One accepted action queues one logical advance; remain paused. Rapid accepted actions advance exactly that many times, even without a drawable. A redraw, resize or focus change adds no step. |
| Inactive / minimized | Stop advancement, clear pending input/step work and preserve manual pause intent. Existing panel hiding/minimize routing remains. No catch-up work on return. |
| Return from inactivity | Refresh presentation and counter without a synthetic catch-up step. If previously running, resume on ordinary subsequent scheduling; if manually paused, remain paused. |
| Panel close/reopen/move/scroll | No numerical/reset/transport change; mode identity, counter and copy stay synchronized |
| 3D→2D | Restore the selected 2D mode's established defaults/preferences and control visibility; clear stale input/pending advances; retain original field/overlay behavior there |
| Construction/reset failure | Restore/retain a usable 2D image, mode and corresponding panel/menu **before** presenting the native alert; never strand the selector/checkmark on unusable 3D. Re-enable actions after safe rollback. |

Do not use only the current `refreshTransport()` callback for committed mode/fallback changes: those need full mode-specific content/menu refresh. Observe renderer/state outcomes rather than optimistic selector state. Rendering and panel refresh cannot change the numerical grid, field values or step counter.

## Keyboard, Pointer and Accessibility

- Keep **⌘P** Run/Pause/Resume, **⌘→** Step, **⌘R** reset/restart, **⌘1–4** the same 2D modes and **⌥⌘K** panel visibility. No new 3D direct shortcut is required.
- With canvas/noncontrol focus, **Space** toggles transport exactly once and **S** is a complete no-op in 3D, including hidden field state. In 2D the existing field cycle remains intact.
- Focused native buttons, pop-up menus and text views consume their own keyboard events first. Space on a focused button activates that button once, not also the canvas pause command; Space opens/operates a focused pop-up according to AppKit. Do not capture normal native letter navigation as a simulation command.
- Native Tab/Shift-Tab order: Experiments → Run/Pause/Resume → Step → Restart → scrollable body. Static heading/descriptor/note are readable to accessibility navigation, not extra keyboard tab stops. Headers and hidden 2D controls are not actionable focus targets. Preserve native visible focus rings and enabled/disabled states.
- Keep stable accessibility identifiers: `experimentSelector`, `transport.pause`, `transport.step`, `transport.restart`, `stepCount` and window identifier `simulationControls`. New static 3D identifiers: `lesson3d.heading`, `lesson3d.slice`, `lesson3d.concentration`, `lesson3d.legend`, `lesson3d.note`, optional `lesson3d.preparing`.
- Preserve existing transport accessibility labels **Resume simulation** (paused, including the visible Run state) and **Pause simulation** (running) for 2D/test continuity. Add/help text for 3D Step **Advance the 3D simulation by one step** and Restart **Return the 3D experiment to step 0** without replacing stable identifiers. The visible step count remains accessibility-readable; do not announce every running step as an interrupting live notification.
- Expose descriptor as **XY slice, halfway through Z** and legend as **Dye concentration, less dye to more dye**. Treat the gradient as a single labelled nonactionable visualization or hide its decorative child from accessibility so it is not read twice. Expose the mode's selected state/checkmark and nonactionable group context without inventing button roles for headings.
- Treat the canvas as one read-only visualization in 3D with accessible description **Fixed XY cross-section of 3D dye concentration**. Pointer clicks/drags/scrolls there inject nothing and do not change the view; no orbit/grab-hand affordance yet. Controls/menu interaction never injects fluid on return to 2D.
- Light/Dark, Increase Contrast, reduced transparency and native keyboard access must remain usable. Use the existing opaque surface fallback; strengthen text/legend outline with semantic label color for Increase Contrast. Outline the legend bar, not the canvas. No decorative motion; Reduce Motion does not silently change solver advancement or turn Run into a different simulation.

## Registry Safety

| Registry / source | Blocks Used | Safety Gate |
|---|---|---|
| Apple AppKit/MetalKit SDK | Existing native controls, panel/menu and MTKView; new content uses the same SDK | Native SDK stack verified from current imports/source, 2026-11-06; no third-party registry blocks |
| Third-party component registries | None | Not applicable — no registry fetched or included |

`shadcn_initialized: false` denotes non-applicability, **not** a missing design system. There are no third-party block sources to vet, no network assets, no downloaded fonts and no authorization to add such dependencies during execution.

## Verification Handoff

These are acceptance checks to implement/run later, **not results of this UI-spec workflow**:

1. **Navigation:** Mac pop-up and Simulation menu have the exact grouped titles; headings/separator cannot select; each committed mode/checkmark agrees; ⌘1–4 mappings remain unchanged; iOS lists only established modes.
2. **Initial appearance:** 3D entry shows a nonblank single amber patch and Step 0 paused, correct square viewport and fixed descriptor/legend/note; no forbidden 2D sections, camera affordances or canvas overlays.
3. **Transport/focus:** Run/Pause/Resume and Step through panel/menu/keyboard use one shared state; S changes nothing in 3D; focused-button/pop-up Space is consumed once. Test rapid Step queues, paused redraw, nil drawable and activity transitions through production state/renderer, not just UI polling.
4. **Palette/slice:** Synthetic empty/constant/asymmetric volumes prove known palette stops, fixed scale across steps, 31/32 midpoint interpolation and X/Y orientation. Compare numeric shader output and native legend; capture Light/Dark results. Preserve 2D blue screenshots/fixtures separately.
5. **Failure/recovery:** Inject allocation, named-pipeline and initial-reset failures; verify native problem/recovery copy, safe default acknowledgement, usable 2D canvas/selection, re-enabled controls and no stale input or semaphore deadlock.
6. **Panel/layout:** At normal and smallest canvas sizes, constrained screen height/width, panel close/reopen and resize, no clipped transport/copy or inaccessible body content; no lesson reset or solver resize. Test both native appearance variants and accessibility settings; record manual-only coverage honestly.
7. **Regression:** Both no-override app builds and applicable existing state/HUD/GPU tests after shared changes. Extend `Tests/UI/macOS/HUDUITests.swift`; verify numerical/scheduling assertions through the new production harness described by `07-RESEARCH.md` / `07-VALIDATION.md`.

The previously observed missing active Metal Toolchain remains an execution prerequisite to recheck before builds/GPU acceptance. This document adds no implementation, measured frame-rate, numerical-convergence or actual-macOS-26 verification claim. The single slice cannot prove SIM-05 or VER-03 by appearance alone.

## Decision Coverage

| Context decision | Contract location |
|---|---|
| D-01, D-02 | Navigation Contract: native nonselectable grouping, preserved titles and ⌘1–4 |
| D-03 | Visual Hierarchy: body heading, no canvas identity |
| D-04, D-06 | Fixed-Slice Presentation: central XY, exact midpoint, panel-only orientation |
| D-05 | Color: fixed warm scalar transfer function; original 2D palette preserved |
| D-07, D-08, D-09, D-10 | Fixed-Slice Presentation and factual note; actual flow/seed/window evidence remains numerical implementation work |
| D-11 | Existing panel/pinned transport and mode-specific hidden/restored body sections |
| D-12 | Keyboard, Pointer and Accessibility: S no-op, focused-control Space, preserved commands |
| D-13 | Exact always-expanded factual note and no inherited two-dimensional About copy |
| D-14 | Native error copy, transactional fallback and injected-failure acceptance |
| D-15 | Scope, Navigation, state transitions and both-target regression handoff |
| D-16 | Transport/inactivity state table and logical-step/focus verification |
| D-17 | Verification Handoff and research/validation references; no UI-based proof or Phase 10 fps gate |

## Checker Sign-Off

- [x] Dimension 1 Copywriting: PASS — specific lesson/orientation/concentration copy, explained valid-empty state, actionable initialization error and explicit immediate-reset policy. Existing Run/Pause/Resume/Step vocabulary is retained per context, not treated as a generic submission CTA.
- [x] Dimension 2 Visuals: PASS — canvas focal point, pinned transport hierarchy, exact body order, no new icon-only action, explicit hidden/restored sections and failure state.
- [x] Dimension 3 Color: PASS — native semantic chrome, explicit 60/30/10 hierarchy/accent reservations, scalar amber distinguished from interactive accent, fixed palette/scale and preserved 2D blue.
- [x] Dimension 4 Typography: PASS — three authored sizes (11/13/17 pt), two weights (400/600), line-height rules and native-control inheritance. AppKit probe confirmed system/small baseline sizes 13/11 on this host.
- [x] Dimension 5 Spacing: FLAG (non-blocking) — new content uses 4/8/16/24/32/48/64 pt tokens. Retained 12 pt native shell gaps are outside the standard token set but explicitly justified by preserving the existing shared panel, not silently introduced 3D styling.
- [x] Dimension 6 Registry Safety: PASS — manual native design system declared; registry section present, no third-party blocks, fonts or assets introduced. shadcn gate is inapplicable to this stack.

**Recommendation S-01:** During implementation review, confirm the inherited 12 pt gaps stay confined to existing shell geometry and do not become arbitrary new 3D spacing tokens. Do not normalize the old 2D shell merely to satisfy a web token rubric.

**Approval:** Approved 2026-11-06 after a distinct, read-only inline checker pass: five PASS, one non-blocking FLAG, zero BLOCK. The researcher/orchestrator applied this sign-off after review; no independent-agent review or implemented-UI verification claimed. No blocking revision loop was required.

**Artifact evidence:** Structural checks found all 14 required contract sections, all 17 D-IDs and the seven standard new spacing tokens; Markdown has balanced fences and no trailing whitespace. Computed sRGB relative luminance at the three chosen stops is 0.0000 → 0.3659 → 0.8903. This checks the specified colors, not actual shader/legend output, display contrast or readability of a running lesson.
