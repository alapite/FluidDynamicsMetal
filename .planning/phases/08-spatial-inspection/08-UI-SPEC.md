---
phase: 8
slug: spatial-inspection
status: approved
shadcn_initialized: false
preset: none
created: 2026-11-13
research_mode: inline
reviewed_at: "2026-11-13T18:53:35Z"
review_mode: inline
---

# Phase 8 — UI Design Contract

> Native Mac visual and interaction contract for **Spatial Inspection**. Research performed inline using the GSD UI-researcher instructions. Contract approval is not implementation, numerical, runtime, accessibility or human visual acceptance.

## Scope and Authority

Extend **3D Dye Advection** with an upright orbit camera, zoom and camera recovery, a movable two-sided XY/XZ/YZ dye sheet, subdued orientation cues, and independently visible passive 3D tracers. Own **INS-01, INS-02, INS-03, INS-04 and CTRL-08**. Keep the simulation fixed at 64³ and preserve the existing 2D experience and both app builds.

Authority: `08-CONTEXT.md` D-01–21 → `.planning/REQUIREMENTS.md` / `.planning/ROADMAP.md` §Phase 8 → `docs/3d-numerical-contract.md` → delivered native patterns in `Sources/macOS/RenderViewController.swift` and `07-UI-SPEC.md` → `08-RESEARCH.md` for implementation proposals. Current code and context supersede historical maps. The Phase 7 fixed-face-on, fixed-square-only and no-canvas-guides restrictions are superseded here; its numerical, palette, transport, recovery and state safeguards are not.

No speed selector, prediction/comparison exercise, new completion treatment, volume view, slice/volume switch, freehand injection, other fields, trails, arrows, camera pan, arbitrary oblique/multiple slices, Guides toggle, quality settings, persistence or mobile 3D. Phases 9–10 retain their acceptance ownership. This contract does not close Phase 7's unperformed manual review.

All substantive preferences are already answered in context. Remaining layout and visual constants below are **design defaults within delegated discretion**, not observed usability/performance results. No additional user decision is required. Adopt these targets for implementation; evidence-driven changes must update this contract and corresponding fixtures, not silently change a locked preference or relax a numerical gate.

## Design System

| Property | Value |
|---|---|
| Tool | Manual native AppKit design system; no web tooling |
| Preset | Not applicable |
| Component library | Existing `NSPanel`, `NSVisualEffectView`, `NSStackView`, `NSScrollView`, `NSPopUpButton`, `NSMenu`, `NSButton`, `NSTextField`; add native `NSSegmentedControl` and continuous `NSSlider` controls |
| Rendering | Existing `MTKView`, Metal spatial presentation and depth testing; optional hit-transparent native corner-guide view |
| Icon library | No new icon-only actions; X/Y/Z are explicit text labels, not colored-only axis symbols |
| Font | macOS system font, existing native control/menu metrics; no custom/downloaded font |
| Theme | System Light/Dark and semantic native chrome; existing opaque reduced-transparency fallback |
| Units | AppKit points for authored UI and projected marker/guide sizing; drawable pixels for render attachments and image fixtures |
| Dependencies | No new package, scene engine, third-party component registry, font or network asset |

The shadcn initialization/registry-fetch gates are **not applicable**: this is AppKit/Metal, not React/Next.js/Vite. Do not initialize shadcn or mistake `shadcn_initialized: false` for a missing design system.

## Visual Hierarchy and Layout

**Primary focal point:** the warm amber/cream dye pattern on a spatially placed sheet. **Secondary:** sparse cyan markers revealing surrounding flow, then pinned experiment/transport controls. **Tertiary:** subdued cube/axis cues and grouped native inspection controls. Never brighten guides to compete with data or overlay a new floating control HUD.

### Preserve the existing shell

- Extend the separate movable **Simulation Controls** utility panel with its existing close/reopen, `.hudWindow` material, `SimulationControls` frame autosave and full-screen auxiliary behavior. Preserve **⌥⌘K** and the View-menu visibility action.
- Retain the **368 pt** target content width, existing screen-bounded sizing and pinned selector/transport/counter. Preserve the canvas window's **320×240 pt** minimum and independent resizing. Choosing a plane or opening the panel must not resize the canvas.
- Keep the existing **16 pt** horizontal insets and inherited shell vertical geometry. Constrained screens narrow the panel using existing layout logic; wrap Restart below Run/Step when needed. No horizontal scrollbar, text truncation, squeezed native controls or shrinking type to fit.
- Keep selector, transport and step count outside the scrolling body. All body sections remain expanded and vertically scroll-reachable; focus movement must reveal an offscreen control. Do not create a disclosure that conceals basic inspection or the factual note.
- Closing/reopening, moving and scrolling the panel does not reset anything. Hidden 2D descendants occupy no layout space and receive no focus. On return to 2D, remove all 3D inspection controls/guide and restore established 2D controls, preferences and input behavior.

### Exact content order

Pinned area remains **Experiments → Run/Pause/Resume, Step, Restart experiment → Step {n}**. Existing grouped 2D/3D selector and Simulation-menu identity/shortcuts stay unchanged.

Scrollable 3D body:

1. **3D Dye Advection** heading and dynamic descriptor, e.g. **XY slice · Z depth: 50%**.
2. Existing **Dye concentration** gradient and **Less dye → More dye** legend.
3. **Slice** section: **Plane** label; **XY | XZ | YZ** native segmented control; depth label/value and full-width continuous slider; **Centre Slice** button.
4. **Show Tracers** native checkbox and **Pale-cyan dots follow the flow, even while hidden.** helper text.
5. **Camera** section: horizontal orbit slider, elevation slider, zoom slider; **Reset Camera** button; gesture helper text.
6. Always-expanded factual note from the Copywriting Contract.

Slider rows use a wrapping label/value heading above a full-width slider, matching the existing tuning-row pattern without exposing Free Play tuning. At narrow width the value moves below the label rather than truncating either. Recovery buttons are separate labelled native buttons; do not concatenate them with transport or substitute ambiguous reset glyphs.

## Camera and Orientation Contract

### Initial pose, bounds and controls

Use a perspective upright orbit around world centre `(0.5,0.5,0.5)`, no roll/pan/inertia or animated auto-facing. Initial horizontal orbit is **25°**, elevation **18°**, vertical field of view **40°**, fitted zoom **100%**. Define camera offset from centre as `distance × (sin(yaw) cos(elevation), sin(elevation), -cos(yaw) cos(elevation))`; at zero yaw/elevation the camera looks into +Z with +X right and +Y up. Use one consistent transform for sheet, markers and cube; guide uses its rotation only.

Render into the available full canvas aspect ratio, not the old fixed square. For aspect `a=width/height`, bounding radius `r=sqrt(3)/2` and limiting half-angle `alpha=atan(tan(20°) × min(1,a))`, fitted distance is `1.10 × r/sin(alpha)`. Zoom magnification `m=percentage/100` gives `distance=max(r+0.10, fittedDistance/m)`; near clip **0.05**, far clip greater than `distance+r`. Resize recomputes fit without changing stored yaw/elevation/zoom percentage or any experiment state. Zero drawable size defers presentation, not evolution or inspection-state storage.

| Native control | Range / initial value | Keyboard increment | Visible value |
|---|---|---|---|
| Horizontal Orbit | −180°…180° / 25°; endpoints represent the same view | 5° per arrow-key adjustment | **Horizontal orbit: {signed rounded degrees}°** |
| Elevation | −75°…75° / 18° | 3° per arrow-key adjustment | **Elevation: {signed rounded degrees}°** |
| Zoom | 50%…150% / 100%; larger means closer | 5 percentage points per arrow-key adjustment | **Zoom: {rounded percentage}%** |

All three sliders are continuous for pointer/assistive adjustment; keyboard increments do not quantize gesture-derived state. Horizontal slider arrows stop at native endpoints; canvas orbit wraps across the equivalent ±180° seam. Do not rewrite a dragged thumb to the opposite endpoint mid-drag. Elevation/zoom clamp with no bounce, roll, pole flip or transient camera inside the cube.

**Canvas gestures:** plain primary drag owns only orbit; rightward drag increases yaw and upward drag increases elevation at **0.30° per AppKit point**. Mouse wheel/two-finger scroll owns only zoom. Normalize positive zoom-in input so it increases magnification: precise scroll uses `m *= exp(delta/240)`, discrete wheel uses `m *= exp(delta/12)`; clamp to the same range. Normalize AppKit scroll direction once and verify on mouse/trackpad so zoom-in input always means closer. Ignore horizontal scroll for camera motion. No modifier is required, no pinch-only path and no fluid injection. Use native open-hand/closed-hand orbit cursors only on the 3D canvas.

**Reset Camera** synchronously restores 25°/18°/100%, fitted to the current canvas. Preserve plane, depth, tracer visibility, playback intent, pending accepted steps, counter and complete numerical/tracer state. It is enabled even at defaults and while paused. No confirmation, easing or simulation restart.

### Always-visible subdued guides

- Draw the cube's **12 edges**, **1 pt** projected stroke, neutral **#666666** on black. Show all edges as a subdued orientation overlay, including back edges; do not depth-occlude the cube with the sheet or markers. This intentional guide-only overlay does **not** permit X-ray tracers. No solid walls, floor, grid, ticks or scattered cube labels.
- Place the noninteractive X/Y/Z guide in the **bottom-left canvas corner**, **16 pt** inset, **64×64 pt** bounds. Use projected positive-axis segments of **20 pt**, **1 pt** strokes and **11 pt** system labels. Axis segments/labels use **#A6A6A6**, neutral rather than RGB axis coloring. Labels identify axes independently of color. Preserve readable label separation when projections approach overlap; adjust label placement, never the underlying axis directions.
- Guide projection follows camera rotation, not zoom/translation. It stays fixed in the corner on resize, does not take keyboard focus, and hit-tests through to the canvas. Cube and guide appear in every usable 3D frame, even with no dye or tracers hidden; no Guides toggle. Increase Contrast raises cube edges to **#A6A6A6** and guide text/strokes to **#D9D9D9** without changing data colors.
- Becoming edge-on is legitimate. Neither sheet selection nor guide logic secretly rotates the camera. No fake perspective shading, directional lighting or decorative animation.

## Slice and Tracer Presentation

### Plane, depth and world orientation

Initial entry is **XY at 50%**, paused at **Step 0**. Keep one shared continuous depth `d=percentage/100` across all planes; **0%…100%** maps to world **0…1**, not an integer grid index. Display whole percentages rounded for readability without rounding the underlying sampling position. A focused depth slider changes by **1 percentage point** per arrow-key adjustment.

| Plane | Sheet-local `(s,t)` → world position | Local horizontal / vertical | Depth label / increasing direction |
|---|---|---|---|
| XY | `(s,t,d)` | +X / +Y | **Z depth: {p}%** / +Z into the front reference volume |
| XZ | `(s,d,t)` | +X / +Z | **Y depth: {p}%** / +Y upward in world space |
| YZ | `(d,t,s)` | +Z / +Y | **X depth: {p}%** / +X rightward in world space |

The local directions describe the sheet, not a promise of screen-right/up after orbit. Use the guide and world transform to explain the current orientation. View from the back naturally mirrors the sheet through geometry; never independently flip its UVs, billboard it or cull its back face.

Concentration sampling remains cell-centred trilinear `clamp(world × dimensions − 0.5, 0, dimensions − 1)`. At 50%, the depth-axis planes **31 and 32** contribute equally; endpoints extend the nearest centre plane. XY at 30% becomes XZ/YZ at 30%, changing only plane and depth-axis label. Plane/depth changes preserve camera and show immediately while paused without advancing fluid or markers.

**Centre Slice** sets only `d=0.5`, preserving plane, camera, tracer visibility and all experiment state, including accepted pending steps. It remains enabled at 50%. The sheet is fully opaque, including black/zero-concentration regions; no opacity control or maximum/average projection.

### Passive marker treatment

- Default **Show Tracers: on** on initial entry. Use **512** deterministic full-volume seeds on an **8×8×8** stratified lattice `(i+0.5,j+0.5,k+0.5)/8`. Count is an internal constant, not a quality control or a per-frame reseeding target.
- Render small unlit pale-cyan **#B8F2FF** filled discs with **3 pt** projected diameter, converted once for backing scale. No glow, trails, velocity arrows, speed encoding, size attenuation, hover interaction or individual marker labels. Marker shape/positions distinguish them from continuous amber dye, not color alone.
- Depth-test markers against the opaque sheet in the same camera space. A behind-sheet marker within the sheet footprint is hidden, including behind black regions; an outside-footprint marker remains eligible to draw. Orbiting to the other side reverses occlusion correctly. Discard outside-disc fragments rather than painting rectangular backgrounds or blocking depth there. Do not dim/ghost hidden markers or draw markers always on top.
- Visibility changes only drawing. All markers advance once per accepted logical simulation step using the same production three-component velocity field; hidden markers advance identically, while paused redraws advance none. No feedback to dye/velocity and no delayed catch-up or reseeding when re-shown. Numerical integration and resource safeguards follow the separately tested implementation contract, not visual plausibility.

## Spacing Scale

New authored inspection gaps use the standard scale in **AppKit points**, not CSS pixels:

| Token | Value | Usage |
|---|---|---|
| xs | 4 pt | Label/value-to-slider and label/bar/legend sub-gaps |
| sm | 8 pt | Related controls/rows; heading-to-descriptor; recovery button-to-helper |
| md | 16 pt | Between body groups; existing horizontal panel inset; guide-to-canvas inset |
| lg | 24 pt | Reserved, no extra spacer required |
| xl | 32 pt | Reserved, no extra spacer required |
| 2xl | 48 pt | Reserved, no extra spacer required |
| 3xl | 64 pt | Reserved, no extra spacer required |

Use **16 pt** between intro, legend, Slice, tracers, Camera and factual-note groups; **8 pt** between related rows and **4 pt** within slider/legend subgroups. No new off-scale gap tokens.

**Explicit inherited exceptions:** existing **12 pt** panel top/bottom and pinned-to-scroll gaps are retained, not new spacing tokens. Preserve existing screen-fit calculations and transport wrapping rather than restyling shared 2D geometry. Existing **12 pt** legend height, **28 pt** minimum transport height, native control interiors/chrome, **1 pt** guide strokes and **3 pt** marker diameter are component dimensions, not inter-element spacing. Native intrinsic metrics/focus rings are platform-managed. Do not extend the inherited shell-gap exception to new inspection groups.

## Typography

Exactly **three authored sizes** and **two authored weights** for new 3D content; native controls/menu/window typography remains platform-managed. Reuse the existing body scale rather than introducing a display size.

| Role | Baseline size | Weight | Line height | Usage |
|---|---|---|---|---|
| Caption / label | 11 pt, small-system baseline | Regular 400; semibold 600 for concentration label only | Natural native single line; multiline minimum 1.2× | Descriptor, legend endpoints, helper text, axis labels |
| Body / section / value | 13 pt, system baseline | Regular 400; semibold 600 for Slice/Camera section labels | Multiline factual note minimum 1.5×; other wrapped rows minimum 1.2× | Factual note, slider readouts, section labels; native counter remains regular |
| Heading | 17 pt, system baseline + 4 pt | Semibold 600 | Wrapped minimum 1.2× | 3D Dye Advection heading |
| Display | No additional size | Not applicable | Not applicable | No display typography |

Use named native roles backed by the system font. Allow intrinsic height to grow and honor accessibility text/weight metrics; do not clip glyphs or disable Bold Text to enforce nominal weights. Controls preserve native focus/disabled metrics. No additional authored size/weight for the guide or readouts, no ultra-small help text or animated counter emphasis. Do not restyle 2D text globally.

## Color

The **60/30/10** hierarchy describes **native controls chrome**, not a measured proportion of simulation pixels: 60% quiet dominant surface, 30% secondary text/control regions, at most 10% system interactive emphasis. Do not fabricate colored panels to force pixel ratios.

| Role | Value | Usage |
|---|---|---|
| Dominant (60%) | Existing `.hudWindow` material; `NSColor.windowBackgroundColor` opaque fallback | Simulation Controls surface in Light/Dark appearance |
| Secondary (30%) | Native control surfaces; `NSColor.labelColor` / `secondaryLabelColor` | Text hierarchy; promote secondary help to primary when Increase Contrast needs it |
| Accent (≤10%) | System `NSColor.controlAccentColor` and native focus/selection rendering | Reserved for focused-control rings, selected plane segment, checked Show Tracers indicator, active menu item, transport pressed/highlight state |
| Destructive / error | Native warning alert and standard buttons; `NSColor.systemRed` reserved for an actual destructive action, none added here | No red Restart, Centre Slice, Reset Camera or dye legend |
| Canvas / opaque empty sheet | `#000000` | Background and concentration zero, opaque even when visually matching the background |
| Dye concentration | 0: `#000000`; 0.5: `#ED8B23`; 1: `#FFF1D6` | Existing fixed amber/cream scalar palette, shared with native legend |
| Passive tracers | `#B8F2FF` | One constant data-category color, not a second interactive accent or speed scale |
| Spatial guides | Cube `#666666`; guide `#A6A6A6` | Subdued orientation only; Increase Contrast variants specified above |

Accent is **not** reserved for all interactive elements. Recovery buttons remain ordinary native buttons. Amber is concentration; cyan identifies passive markers; neither tints chrome or signals errors/selection. Axis directions are text-labelled, not additional decorative accent colors.

Preserve encoded-channel piecewise-linear dye interpolation at the 0/0.5/1 stops, clamp concentration to `[0,1]` for display, and keep the existing non-sRGB UNORM target convention unless an explicitly verified color-path amendment is planned. No per-frame normalization, adaptive exposure or extra gamma in only the legend/shader path. Nonfinite concentration is an error to detect, not silently render as empty. Native chrome adapts to Light/Dark; the scientific canvas remains black in both. Never communicate running, selected, hidden or failed state solely with color.

## Copywriting Contract

| Element | Exact copy / rule |
|---|---|
| Panel / lesson identity | **Simulation Controls** / **3D Dye Advection** — unchanged |
| Dynamic slice descriptor | **{plane} slice · {axis} depth: {p}%** |
| Primary inspection recovery CTA | **Reset Camera** |
| Slice recovery CTA | **Centre Slice** |
| Slice section / selector | **Slice** / **Plane**, segments **XY**, **XZ**, **YZ** |
| Depth readout | **Z depth: {p}%**, **Y depth: {p}%**, or **X depth: {p}%**, as mapped above |
| Tracer checkbox / helper | **Show Tracers** / **Pale-cyan dots follow the flow, even while hidden.** |
| Camera section / slider labels | **Camera** / **Horizontal Orbit**, **Elevation**, **Zoom** |
| Camera gesture helper | **Drag the canvas to orbit. Scroll to zoom. You can also use the camera sliders.** |
| Depth accessibility help | **Move the {plane} slice along {axis}. Centre Slice returns the depth to 50%.** |
| Camera reset help | **Restore the starting camera view without changing the slice or experiment.** |
| Slice centre help | **Set the current slice depth to 50% without changing its plane or the camera.** |
| Tracer help | **Show or hide passive markers. Hidden markers keep moving with simulation steps.** |
| Factual note | **This slice shows dye carried by an evolving 3D flow. Brighter areas contain more dye; dye can move out of the plane. Pale-cyan dots are passive tracers. Tracers behind the opaque slice are hidden, even where the slice is black. There is no explicit dye fading, but numerical advection can smooth the dye. Steps count solver advances, not seconds.** |
| Concentration legend | **Dye concentration** / **Less dye → More dye** — unchanged |
| Transport / counter | **Run**, **Pause**, **Resume**, **Step**, **Restart experiment** / **Step {n}** — established vocabulary, not generic submission CTAs |
| Restart accessibility help in 3D | **Return the 3D experiment to step 0. Keep the camera, slice and tracer visibility.** |
| Transient preparation, only if initialization yields to UI | **Preparing 3D lesson…** |

### Empty, error and reset states

| State | Copy and recovery |
|---|---|
| Initial step 0 | Not empty: show the seeded central amber sheet, cube/guide and initially enabled tracers. Next actions are Run, Step or inspection; no placeholder card. |
| Valid low/zero-concentration slice | Keep the opaque black sheet, guides and eligible markers. No inferred “all dye has left” status, error heading or empty-state overlay. The factual note explains that dye can leave the plane; the always-available Plane/depth/Centre Slice controls provide exploration without reseeding. |
| Edge-on sheet | Keep actual geometry and current descriptor; no “no data” treatment. Reset Camera is the explicit recovery, not automatic reorientation. |
| Tracers hidden or occluded | Keep the checkbox truthful. Do not assert that tracers are absent/stopped or show an empty-state warning. |
| Initial 3D preparation/reset failure | Heading **Couldn’t open 3D Dye Advection**. If prior 2D retained: **The 3D simulation could not be prepared. Your 2D simulation is still available. Continue in 2D, or choose 3D Dye Advection again to retry.** If fresh Free Play restored, substitute **Free Play has been restored.** for the second sentence. |
| Active 3D inspection/presentation resource failure | After safe 2D recovery, heading **Couldn’t continue 3D Dye Advection**; body **The 3D view could not be updated. Free Play has been restored. Continue in 2D, or choose 3D Dye Advection again to retry.** Do not treat temporary missing drawable/zero size as a resource failure. |
| Error acknowledgement | **Continue in 2D** — safe default Return action; Escape acknowledges the same already-restored state. Never generic “OK”. Diagnostic resource details stay in local logs, not unverified learner-facing diagnoses. |
| Restart confirmation | Existing immediate transient-progress reset, **no confirmation dialog**: no saved document is deleted. Return paused to Step 0; reset complete evolution-dependent fluid/tracer state and pending input/steps, but retain all inspection choices. No destructive-red styling. |
| Reset Camera / Centre Slice confirmation | **No confirmation dialog**; reversible presentation-only changes with exact scopes above. Neither discards experiment progress nor resets markers. |

Keep errors transactional: restore usable 2D selection, image, panel and menu before the alert. New marker/depth/pipeline failures must not leave a fake successful 3D view or permanently disabled actions. No new Phase 9 completion copy; preserve existing cap behavior without claiming its later teaching acceptance.

## Interaction and State Contract

| Event | Changes | Must preserve |
|---|---|---|
| Successful initial 3D selection/reselection | New deterministic experiment, paused Step 0; XY/50%, camera 25°/18°/100%, tracers on | Existing safe transactional entry and 2D recovery policy |
| Orbit/zoom or camera slider | Camera only; request paused presentation refresh | Plane/depth, visibility, playback intent, accepted pending steps, full evolution state |
| Reset Camera | Initial orientation and current-viewport fitted zoom | Everything except camera pose/zoom |
| Plane selection | Plane and depth-axis label; retain one shared percentage | Camera, percentage, visibility and all experiment state |
| Depth / Centre Slice | Depth only; Centre Slice sets 50% | Plane, camera, visibility and all experiment state |
| Show Tracers | Drawing visibility only | Positions/seeds/advancement schedule and all fluid state |
| Restart experiment | Reset all fluid/tracer evolution state, pending work and count; pause at Step 0 | Camera, selected plane, shared depth and tracer visibility, including hidden choice |
| Paused redraw / resize / panel operations | Presentation/layout resources only; resize updates fit | Fixed 64³ grid, seed, complete fluid/tracer buffers, counters, pending accepted steps and pause intent |
| Run / Step while tracers hidden or drawable absent | Exactly accepted logical solver advances and corresponding marker advances | Presentation independence; no render-frequency/visibility-driven evolution |
| Deactivate/minimize / mode switch | Clear active camera drag ownership and stale input; retain established inactivity/transition rules | No catch-up step, no accidental fluid impulse or control action on return |
| Return to 2D | Established mode-specific controls/input, no 3D guide/controls | Original 2D solver/ABI and established mode-selection/session-preference behavior |

Inspection is available while paused and remains available if inherited lesson-cap machinery has stopped advancement. State setters validate finite/bounded values and redraw from committed renderer state, not optimistic widget state. Do not call a general reset/clear-pending-steps routine when changing inspection. Presentation never reseeds, consumes a logical step, changes pressure/scratch/status/latches or mutates tracer positions.

## Keyboard, Pointer and Accessibility

- **Keyboard coverage:** labelled native sliders provide every camera gesture's alternative. Preserve native Tab/Shift-Tab, slider arrow adjustment and segment arrow selection. With Full Keyboard Access, focus order is Experiments → Run/Pause/Resume → Step → Restart experiment → Plane → depth → Centre Slice → Show Tracers → Horizontal Orbit → Elevation → Zoom → Reset Camera. Static text/guide is not an extra Tab stop. No new global shortcuts or menu reorganization required.
- Preserve **⌘P**, **⌘→**, **⌘R**, **⌘1–4**, **⌥⌘K** and canvas-focused **Space**. **S** stays a complete no-op in dye-only 3D. Focused controls receive normal keys first: Space operates the focused checkbox/button/segment once and never also toggles transport; arrows on sliders never orbit a second time or advance the experiment. Do not install global arrow-key camera handlers.
- **Exclusive gestures:** start orbit only in the canvas window's interactive region, own that drag until mouse-up, and clear ownership on deactivation/mode switch. Starting in the panel never becomes a canvas gesture. Panel wheel/trackpad events scroll its body, never zoom. A hit-transparent guide passes the event to the canvas once. Camera input works before/independently of the 2D `shouldAdvance` injection guard. No 3D gesture calls the fluid-injection path.
- **Native semantics:** link visible labels to sliders/segments; expose current values and units, min/max and selected plane. Depth accessibility label changes to **Z depth**, **Y depth**, or **X depth**, with percentage value. Camera labels are **Horizontal Orbit**, **Elevation**, **Zoom**, with degree/percent values matching readouts. Preserve native focus rings, enablement and checked state. Readout rounding is presentation only.
- Preserve `experimentSelector`, `transport.pause`, `transport.step`, `transport.restart`, `stepCount`, `simulationControls`, `lesson3d.heading`, `lesson3d.slice`, `lesson3d.concentration`, `lesson3d.legend`, `lesson3d.note`. Add `inspection3d.plane`, `inspection3d.depth`, `inspection3d.depthValue`, `inspection3d.centreSlice`, `inspection3d.showTracers`, `inspection3d.orbit`, `inspection3d.elevation`, `inspection3d.zoom`, `inspection3d.resetCamera`.
- Update descriptor accessibility text to **{plane} slice, {axis} depth {p} percent**. Canvas description: **3D dye concentration, {plane} slice at {axis} depth {p} percent. Tracers {shown or hidden}.** Help: **Drag to orbit and scroll to zoom, or use the labelled camera controls in Simulation Controls.** Expose the canvas as a visualization with camera interaction help, not an editable fluid surface. Do not claim every enabled tracer is visible through occlusion.
- Make the corner guide one nonactionable accessibility element labelled **3D orientation guide: X, Y and Z axes**; decorative axis children/cube lines/individual dots are not hundreds of separate elements. The concentration gradient remains a single labelled visualization without duplicate decorative-child announcements. Do not interrupt VoiceOver on every running step, scroll or drag update.
- Check Light/Dark, Increase Contrast, Reduce Transparency, Bold Text and Full Keyboard Access. Use existing opaque fallback, semantic text and specified guide variants. Reduce Motion introduces no decorative camera animation and does not alter logical stepping or disable requested direct inspection. Actual VoiceOver/readability checks remain manual acceptance work, not implied by identifiers.

## Registry Safety

| Registry / source | Blocks Used | Safety Gate |
|---|---|---|
| Apple AppKit/MetalKit SDK | Existing native panel/menu/buttons/sliders/MTKView; planned native segmented control and local guide drawing | Existing stack verified from imports/source, 2026-11-13; no third-party registry blocks |
| Third-party component registries | None | Not applicable — none fetched, declared or included |

Manual native design system is declared above. `workflow.ui_safety_gate: true` remains enabled; this is a PASS-by-no-third-party-sources case, not a disabled safety check. No permission to download UI code, fonts, icons or assets is implied.

## Verification Handoff

These are required future checks, **not results of this workflow**. Use `08-RESEARCH.md` / `08-VALIDATION.md` for production harness integration and preregister numerical/resource inventories before accepting implementation outputs.

| Requirement / concern | Checks to plan and execute |
|---|---|
| INS-01 camera / guides | CPU projections plus production image landmarks for initial pose, signs, bounds and shared transforms; mouse/trackpad and keyboard alternatives while paused; Reset Camera scopes; narrow/tall/Retina fit; guide alignment, visibility, readability and pass-through input. |
| INS-02 slices | Asymmetric affine concentration with unequal landmarks, all planes at 0/30/50/100%, midpoint 31/32 interpolation, endpoints, front/back and edge-on; shared percentage and correct dynamic axis text; no camera auto-facing. |
| INS-03 tracers | Exact 512 deterministic full-volume seeds, production velocity sampling/evolution against independent reference, visible/hidden/alternating equality, no feedback, ±axes and wall/edge/corner cases. GPU images prove front-visible/back-hidden occlusion in dyed AND black sheet regions, side reversal and outside-footprint visibility. |
| INS-04 state preservation | Complete fluid texture generations, pressure/scratch/workspace/status/latches, tracer buffers, generation roles/configuration and counters; byte-identical paused presentation batches; separately reset equal-step runs at 0/1/24/48 under varied camera/plane/depth/visibility/viewport/render counts and nil drawable. Recheck Restart retains every inspection choice while resetting evolution/pending work. |
| CTRL-08 native interaction | Keyboard-only operation of every new control, control-focused Space once, canvas Space once, S no-op, panel drag/scroll exclusion, camera gestures without transport/injection, focus autoscroll, hidden controls absent in 2D, guide hit pass-through. |
| Layout / access / failures | Normal and constrained panel width/height, 320×240 canvas, resize, close/reopen; readable wrapping and scroll reachability; Light/Dark and accessibility settings; injected tracer/depth/pipeline/reset failures with usable 2D recovery, exact actionable copy and retry. |
| Regression / scope | Both no-override Xcode app builds, applicable Mac state/HUD and integration/GPU checks, applicable iPhone/iPad HUD regressions; unchanged 2D solver/ABI/input; keep current numerical acceptance gates and fixed grid. |

Carry research's preregistered candidate tolerances into the separate implementation contract: finite-first GPU/oracle checks `2e-5 + 2e-4 × abs(reference)`, palette ±1 UNORM code, same-device equal-step fluid/tracer absolute `2e-6`, exact discrete state/seeds/wall zeros, and byte-for-byte paused evolution-resource preservation. Do not substitute screenshots or a subset of dye/velocity for complete-state evidence, fit tolerances to observed output, or alter the immutable Phase 7 numerical prefix.

Document new image fixtures separately from the historical fixed-square/fixed-slice benchmark workload. This contract supplies no app build/test run, visual capture, numerical result or measured frame-rate evidence. Phase 7's six pending user-facing requirements stay pending; actual macOS 26 and physical-device multitouch remain **NOT TESTED**, displayed pacing **NOT MEASURED**. Full speed-comparison/restart-repeatability acceptance remains Phase 9, integrated volume/compositing/performance qualification Phase 10.

## Decision Coverage

| Context decision | Contract location |
|---|---|
| D-01, D-02, D-03, D-04 | Camera and Orientation: initial three-quarter view, plain orbit/scroll, upright bounds, camera-only reset |
| D-05, D-06, D-07, D-08 | Subdued always-visible cube/corner guide; two-sided fixed-in-world sheet; no Guides toggle |
| D-09, D-10, D-11, D-12 | Slice controls/world mapping: native segments, shared continuous percentage, camera preservation, depth-only Centre Slice |
| D-13, D-14, D-15, D-16 | Passive marker treatment: deterministic full-volume seeds, initial visibility/hidden advancement, cyan dots only, opaque-sheet depth occlusion |
| D-17 | Visual Hierarchy/Design System/Copywriting: existing separate native panel, pinned transport, legend, factual note and 2D restoration |
| D-18 | State Contract and reset copy: Restart preserves all inspection choices and resets evolution paused at Step 0 |
| D-19 | State Contract and INS-04 handoff: presentation-only changes, no reseeding/steps, complete resource comparison |
| D-20 | Keyboard, Pointer and Accessibility: labelled camera alternatives, native focus, Space/S continuity, exclusive gestures and no injection |
| D-21 | Scope/Verification Handoff: preserved builds/regressions/numerical gates and explicit untested coverage |

## Checker Sign-Off

- [x] Dimension 1 Copywriting: PASS — specific Reset Camera/Centre Slice actions, exact labels/helpers and factual note, deliberate valid-empty/edge-on policies, actionable 2D recovery and explicit immediate-reset confirmation policy. Context-locked Run/Pause/Resume/Step vocabulary is preserved.
- [x] Dimension 2 Visuals: PASS — dye focal point, subordinate marker/guide hierarchy, precise panel order, no icon-only actions, native keyboard camera alternatives and explicit sheet/marker occlusion.
- [x] Dimension 3 Color: PASS — explicit 60/30/10 native-chrome hierarchy and bounded accent reservations; amber concentration and cyan marker identity are justified data semantics, not extra interactive accents. Native error/reset styling is defined.
- [x] Dimension 4 Typography: PASS — three authored sizes (11/13/17 pt), two authored weights (400/600), body/heading line heights and native-control/accessibility inheritance specified.
- [x] Dimension 5 Spacing: FLAG (non-blocking) — all new gaps use 4/8/16/24/32/48/64 pt; inherited 12 pt shell gaps remain an explicit context-aligned exception to the standard token set, consistent with the delivered Phase 7 contract and D-17's existing-panel constraint.
- [x] Dimension 6 Registry Safety: PASS — manual native design system and registry section present; safety gate enabled, no third-party blocks/fonts/assets declared or fetched.

**Recommendation S-01 (non-blocking):** Keep inherited 12 pt gaps confined to existing panel shell geometry. Do not introduce them into new inspection groups or restyle the shared 2D shell merely to satisfy a web-token rubric.

**Approval:** Approved 2026-11-13 after a distinct read-only inline checker pass against all six dimensions, locked context and research: **five PASS, one FLAG, zero BLOCK**. The researcher/orchestrator applied this sign-off after review. No blocking revision was required; no independent-agent verification or implemented-UI acceptance is claimed.

**Artifact evidence:** Structural checks passed for 14 core contract sections, all 21 context D-IDs, all five owned requirements, seven standard spacing tokens, three authored type sizes, balanced fences and absence of trailing whitespace/template placeholders. A separate design-formula sanity check covered 360 camera pose/aspect/zoom combinations, confirmed all cube corners fit at 100% zoom and near-plane clearance exceeds 0.05, checked 512 unique interior seeds and the endpoint/midpoint mapping. These inspect specified formulas only, not production camera matrices, GPU sampling, actual native layout, color readability or displayed performance.
