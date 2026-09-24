# Phase 2: Modern iOS parity - Context

**Gathered:** 2026-09-24
**Status:** Ready for planning

<domain>
## Phase Boundary

Bring the existing iOS app to iOS 26 alongside the Phase 1 Mac app: both schemes build with current Xcode without Swift 4 compatibility or local deployment-target overrides, and people can stir and add density with the existing platform inputs. Preserve the recognizable simulation, not redesign the solver. Resize/rotation resilience and pause-state robustness belong to Phase 3; named on-screen controls to Phase 4.

</domain>

<decisions>
## Implementation Decisions

### Touch stirring
- **D-01:** Every active finger can stir and add density simultaneously; this applies on iPhone and iPad.
- **D-02:** Lifting or cancelling one finger ends only that finger's input; remaining fingers continue without stuck forces.
- **D-03:** A single stationary touch adds density on touch-down, while dragging stirs promptly. A brief delay for tap-only dye is acceptable when necessary to distinguish control gestures; drag responsiveness takes priority.

### Existing gestures
- **D-04:** Retain one-finger double tap to pause/resume and two-finger double tap to cycle fields on iOS; retain Space to pause/resume and S to cycle fields on Mac.
- **D-05:** Recognized iOS double-tap shortcuts should not leave visible dye marks. If instant tap-only dye conflicts with clean shortcuts, prioritize clean shortcuts; do not delay a drag unnecessarily.

### Visual parity
- **D-06:** Start on the density field, showing dark-blue fluid on black like the Phase 1 Mac reference. Preserve the familiar swirling motion and fading character; frame-by-frame visual identity across platforms is not required.
- **D-07:** A stroke should affect a similar proportion of the visible canvas on iPhone and iPad rather than a fixed pixel footprint that feels much smaller on iPad.
- **D-08:** Keep the iOS fluid canvas full and unobstructed during this phase.

### Device sign-off
- **D-09:** Launch, fluid drag, and existing gesture checks on iOS 26 Simulator are sufficient for Phase 2 sign-off; check both simulated iPhone and iPad layouts.
- **D-10:** Rebuild the Mac scheme and use the recorded Phase 1 interaction and look as the Mac parity reference. The actual macOS 26 runtime test remains deferred to milestone closeout as previously agreed.
- **D-11:** If simulator input cannot convincingly demonstrate real multi-finger touch behavior, record that observation as unverified/device-only rather than claiming physical-device coverage or blocking simulator sign-off.

### Agent's Discretion
The concrete Swift/Metal modernization and gesture-recognition implementation are for research and planning, provided the behavior above remains intact.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Scope and parity
- `.planning/ROADMAP.md` §Phase 2 — Phase boundary, success criteria, and later-phase separation.
- `.planning/REQUIREMENTS.md` — PLAT-02, PLAT-03, SIM-01; requirements for later phases are intentionally separate.
- `.planning/PROJECT.md` — iOS 26/macOS 26 platform baselines and preserve-the-solver constraint.
- `.planning/phases/01-modern-mac-baseline/01-BASELINE.md` — Mac color, solver defaults, field order, verified Mac interactions, and deferred macOS 26 test.
- `README.md` §Usage — original iOS touch/double-tap and Mac mouse/key shortcuts; original GIF is linked here.

### Existing architecture
- `.planning/codebase/ARCHITECTURE.md` — shared simulation and platform-specific controller boundaries; note that this map predates the Phase 1 Mac target update.
- `.planning/codebase/INTEGRATIONS.md` — UIKit gesture forwarding, AppKit input, and Metal shader contracts.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Shared/Renderer.swift` and `Shared/Shaders.metal`: simulation and visualization shared by both app targets; existing blue-on-black defaults and field cycling are the parity reference.
- `Shared/Slab.swift`, `Shared/RenderShader.swift`, and `Shared/MetalDevice.swift`: existing GPU state and pipeline support.
- `build-macos.sh`: repeatable Phase 1 Mac build and bundle for cross-platform comparison.

### Established Patterns
- `FluidDynamicsMetaliOS/RenderViewController.swift` owns touch forwarding, double-tap recognizers, and activity notifications; `FluidDynamicsMetalOSX/RenderViewController.swift` owns mouse and key input. Both install shared `Renderer` as their `MTKView` delegate.
- The iOS controller currently collects only touches in each callback and clears all input on any touch end/cancellation; it will need to honor D-01/D-02. It also uses raw allocation for a five-position tuple. The exact implementation fix belongs to planning.
- Swift `StaticData` and Metal `BufferData` layouts, along with shader function names, must remain aligned across both targets.

### Integration Points
- `FluidDynamicsMetal.xcodeproj/project.pbxproj`: the iOS app's deployment and Swift settings still need modernization; the Mac target was updated in Phase 1.
- `FluidDynamicsMetaliOS/Base.lproj/Main.storyboard`: storyboard-backed full-canvas `MTKView` on iOS; `FluidDynamicsMetaliOS/RenderViewController.swift` forwards touch/gesture events into shared `Renderer.updateInteraction(points:in:)`.
- `FluidDynamicsMetalOSX/RenderViewController.swift`: established Mac input to retain during the both-scheme build.

</code_context>

<specifics>
## Specific Ideas

- A quick single tap should visibly add dye, but a recognized double-tap should not; a slight tap-only delay is an acceptable tradeoff if required.
- Compare recognizable dark-blue-on-black swirling and fade using the recorded Mac baseline and original GIF, not pixel-by-pixel screenshots.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope. Phase 1 macOS 26 runtime testing remains explicitly deferred to milestone closeout, and physical multi-touch observation is marked unverified if simulator input cannot establish it.

</deferred>

---

*Phase: 2-modern-ios-parity*
*Context gathered: 2026-09-24*
