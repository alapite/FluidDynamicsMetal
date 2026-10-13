# First educational release verification

Verified 13 October 2026. Implementation follows [the release plan](first-educational-release-plan.md).

## Implementation handoffs

| Stage | Delivered | Evidence and remaining coverage |
|---|---|---|
| State and scheduling | Independent retention, exact queued steps, inactive/reset cancellation, complete reset, session preferences | State tests and the production renderer without a drawable; original Free Play GPU regressions pass. |
| Experiment engine | Shared deterministic recipes, 256 × 256 grid, scripted stirring, restart and 600-step completion | All eight lesson adjustments run to 600; same-device restart reproduces every ping/pong field and particle/history buffer. |
| Visualization | Scalar palettes, GPU reductions, mean-relative pressure, final projected curl, outlined arrows | Zero fields, pressure offsets, synthetic clockwise/anticlockwise fields, compositing and visual captures pass. |
| Particles | 256 midpoint-integrated tracers and chronological 64-sample GPU history | Uniform-velocity displacement, wrap ordering, reset, hidden evolution and display isolation pass. |
| Native interfaces | Mac panel/menu commands and iPhone/iPad reserved lesson layouts, pinned transport and scrolling content | Native workflow and accessibility verification results below. |
| Documentation | Updated README, editable equations and rebuilt 12-page PDF | PDF rendered and visually reviewed; observable lesson evidence below. |

## Environments and automated checks

- Host: Apple M3 Pro, macOS 27.0 (26A428), Xcode 27.0 (27A266a), Swift 6 language mode.
- Simulators: iPhone 17 Pro and iPad Pro 13-inch (M5), iOS 26.4 (23E244).
- Deployment targets remain macOS/iOS 26. No deployment or language-version override was used.
- Mac Debug and generic iOS Simulator builds: **PASS**. The launchable Mac Debug app is copied to `FluidDynamicsMetalOSX.app` in the repository root.
- Full integration discovery: **PASS**, 12 tests in 71.26 seconds (`uv run --no-project python3 -m unittest discover -s Tests/Integration`), including the production GPU encoder, legacy solver/renderer regressions, build settings, bundles and simulator launches.
- Mac state/contact/HUD suite: **PASS**, 29 tests, `.build/educational-mac-verified2.xcresult`.
- iPhone HUD suite: **PASS**, nine tests, `.build/educational-iphone-verified.xcresult`; two additional visual/large-text checks pass in `.build/educational-iphone-visual.xcresult`.
- iPad HUD suite: **PASS**, ten tests, `.build/educational-ipad-release.xcresult`. This includes full-screen visual checks of every lesson in both orientations. An earlier passing run stalled during optional Xcode diagnostic collection; the final run uses `-collect-test-diagnostics never` and exits successfully.

Tests load the freshly built Mac application's Metal library and use the production `FluidSimulation` encoder. Integer state and deterministic reset data require exact equality. Floating-point comparisons require `abs(a-b) <= 1e-4 + 1e-3*abs(b)`; fields are RG16F and particles/history float32. Test-only readback and GPU waits support assertions and measurement; normal presentation does neither.

## Observable lesson acceptance

[View the capture sheet](educational-release-evidence/lesson-observations.png): every adjustment at steps 0, 120, 240 and 600, with overlays hidden to expose the material/rotation pattern. The harness also saves the same observations with arrows and particles under `.build/educational-evidence`.

| Observation | Measured evidence | Visual review |
|---|---|---|
| Faster advection moves the dye farther early | Dye-centroid displacement at step 120: slow **0.1918**, normal **0.3302**, fast **0.3973**, in normalized domain coordinates | The patch follows circulation and progressively stretches around it. |
| Reversing one vortex changes pair evolution | Dye-region centroid displacement at step 120: same **0.1545**, opposite **0.1468**; synthetic curl fixtures independently verify both labelled signs | Same-sign orange cores rotate around one another; opposite orange/blue cores travel as a pair. |
| Strong stirring elongates material lines more | Sum of lengths of the 16 vertical tracer-lattice lines at step 600: gentle **54.83**, normal **88.55**, strong **102.62** (initial sum **12.8**) | The stripe bends and folds during forcing; strong and gentle sequences visibly differ. |

All lesson fields and particle/history coordinates remained finite. None of the tested captures is blank. Same-device restart, running/manual scheduling, and changed display/viewports reproduce the state at step 120. These are qualitative numerical demonstrations, not calibrated physical measurements.

## Performance and resource review

[Raw hardware measurements](educational-release-evidence/gpu-results.txt) include every adjustment. At a 256-square offscreen target, mean GPU cost was **1.11–1.26 ms** with overlays off and **1.21–1.54 ms** with all overlays on. Mean encode/submit/completion cost was **2.78–3.09 ms** off and **2.93–3.28 ms** on, including the harness's synchronous completion wait. These measurements support the 60 Hz target on this Mac; they are not a display-refresh measurement or an iPhone hardware benchmark.

Resource review: fixed simulation textures and particle buffers are reused; reduction capacity grows only when the grid grows; shader pipelines are cached. Lesson resize changes the viewport without replacing GPU resources. Normal frames have no synchronous readback or completion wait. Resource replacement drains the existing three-command semaphore before reset/resize. No tested lesson approached a 33.3 ms GPU frame budget.

## Native visual review and limitations

[Mac controls](educational-release-evidence/mac-controls.png), [iPhone layouts](educational-release-evidence/iphone-layouts.png), and [iPad layouts](educational-release-evidence/ipad-layouts.png) were visually reviewed. iOS captures use the complete simulator screen after rotation settles; the legacy application-window screenshot API crops incorrectly in landscape.

Visual review found and fixed oversized iPhone button text at the largest accessibility setting. Pinned transport scales through the standard XXXL category to keep essential controls visible; the scrollable explanation supports the full accessibility range. Configured buttons measure wrapped titles. The existing portrait-only iPhone orientation setting was extended to both landscape orientations; tests now wait for actual rotation before asserting layout.

**NOT TESTED:** macOS 26 runtime (host runs 27); physical iPhone/iPad multitouch, two-finger shortcuts and device GPU performance; a full spoken VoiceOver traversal and manual increased-contrast/reduced-transparency settings audit. Stable accessibility labels/identifiers, Dynamic Type layout, semantic control colours, reduced-transparency handling and outlined overlays are implemented. These unavailable hardware/manual checks remain explicit release coverage gaps. Xcode also reports the existing iOS scene-lifecycle and `UIRequiresFullScreen` deprecation warnings; scene migration is outside this release plan.
