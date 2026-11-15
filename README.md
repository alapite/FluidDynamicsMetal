# FluidDynamicsMetal

[![CI](https://github.com/alapite/FluidDynamicsMetal/actions/workflows/ci.yml/badge.svg?branch=master)](https://github.com/alapite/FluidDynamicsMetal/actions/workflows/ci.yml)

Interactive Metal fluid simulation for **macOS 26 on Apple Silicon** and **iOS/iPadOS 26**. The Xcode project requires Swift 6.2 or later, uses Swift 6 language mode with complete concurrency checking, and has separate Mac and iOS app schemes.

![fluiddynamics](https://github.com/andreipitis/FluidDynamicsMetal/blob/master/FluidDynamicsMetal.gif?raw=true)

## Project layout

```text
Sources/
  Shared/       Simulation state, renderer, Metal helpers and shaders
  macOS/        Mac app code, storyboards, assets and configuration
  iOS/          iPhone/iPad app code, storyboards, assets and configuration
Tests/
  Unit/         Simulation state and renderer contact tests
  UI/macOS/     Mac HUD tests
  UI/iOS/       iPhone/iPad HUD tests
  Integration/  Python build/bundle checks and Swift GPU harnesses
```

The Xcode project and `build-macos.sh` remain at the repository root. Shared sources compile directly into both app targets. Existing scheme and target names are unchanged.

## Build and run

Open `FluidDynamicsMetal.xcodeproj` with Xcode 26 or later (Swift 6.2+). Install Xcode's Metal Toolchain if the build reports it missing: `xcodebuild -downloadComponent MetalToolchain`. From the project root, build both existing schemes without Swift-version or deployment-target overrides:

```bash
xcodebuild -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetalOSX -configuration Debug -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO build
xcodebuild -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetaliOS -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

All app and test targets use `SWIFT_VERSION = 6.0`, the Xcode setting for Swift 6 language mode; the compiler version comes from the selected Xcode toolchain. Rendering resources are explicitly isolated to `MainActor`, including the MetalKit delegate conformance. The Mac event monitor uses Swift 6.2 isolated teardown, and GPU completion captures only its thread-safe semaphore.

For a reusable Mac app at the project root, run `./build-macos.sh`, then `open -a "$(pwd)/FluidDynamicsMetalOSX.app"`. The script builds into ignored `.build/` and copies the app to `FluidDynamicsMetalOSX.app`.

Run `./build-macos.sh clean` to remove `.build/` and the copied app, or `./build-macos.sh rebuild` to clean and then build again. Cleanup is limited to those two paths in this checkout; Xcode's global DerivedData is preserved. Use `./build-macos.sh --help` for usage.

For iPhone or iPad, select the **`FluidDynamicsMetaliOS`** scheme in Xcode and choose an available **iOS 26** iPhone or iPad simulator as the run destination. Discover current destinations with `xcrun simctl list devices available`; avoid copying a device ID from a prior machine. For command-line UI tests, substitute that device's ID:

```bash
xcodebuild test -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetaliOS -configuration Debug -destination 'platform=iOS Simulator,id=<chosen-id>' CODE_SIGNING_ALLOWED=NO
```

Mac state and HUD tests run with:

```bash
xcodebuild test -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetalOSX -configuration Debug -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO
python3 -m unittest discover -s Tests/Integration -p 'test_*metal.py'
python3 -m unittest -v Tests.Integration.test_renderer_correctness
```

Run the Metal regression check after a fresh Mac Debug build. An arm64 build on a newer Mac does **not** establish that the app launches on macOS 26; see the pending [macOS 26 runtime check](.planning/phases/01-modern-mac-baseline/01-HUMAN-UAT.md).

Run build-setting checks with `python3 -m unittest Tests.Integration.test_phase02_settings`. To include bundle installation and launch checks on iPhone and iPad simulators, build both Debug schemes first, then run `python3 -m unittest discover -s Tests/Integration`. Integration checks locate the project and Swift harnesses relative to their own files; they can also be run directly from another working directory.

## Learning with the simulation

Launch opens an empty, running **Free Play** dye canvas with Tuning collapsed. Drag on the canvas to add dye and motion. Choose **Experiments** to explore:

- **Dye carried by a flow:** predict where a patch travels, then compare the three initial speeds after the same number of steps.
- **Two interacting vortices:** compare same and opposite rotation.
- **Stretching dye by stirring:** compare gentle, normal, and strong stirring of a narrow stripe.

Each of the three existing 2D lessons opens paused at **Step 0**, with its question and explanation visible. **Run**, **Pause/Resume**, and **Step** let you inspect its progress. These 2D lessons stop at 600 steps. **Restart experiment** preserves the adjustment and display choices, resets everything, and pauses. Changing the adjustment also restarts. Freehand injection is disabled in lessons; canvas pause and field-cycle gestures remain available.

**Reset fluid** clears Free Play fluid, particles, trails, and pending input while preserving tuning, views, and the pause choice. Returning from a lesson creates an empty running Free Play canvas and restores this session's Free Play preferences. Settings reset at launch; the Mac panel position remains persistent.

| View | Reading the image |
|---|---|
| Dye concentration | Black → blue → pale cyan means less → more dye. |
| Velocity | Dark purple → teal → yellow means slower → faster; arrows show direction. |
| Vorticity | Orange means clockwise; grey zero; blue anticlockwise. |
| Pressure | Blue is below the spatial mean; grey average; orange above it, in simulation units. |

Speed, curl, and pressure colour scales adjust to each frame. They are qualitative views, not calibrated measurements. Optional **Velocity arrows** can appear on every field. **Particles** are passive markers; **Trails** show their recent paths. Hiding particles also hides trails, but markers and history continue evolving.

Free Play tuning defaults are **Force 50%, Dye 40%, Swirl enhancement 20%, Dye fading 17%, Motion damping 17%**. The last two controls are independent: 0% retains 1.0 per step, 17% retains 0.998, and 100% retains 0.9905. Zero disables explicit decay, though numerical advection still smooths details.

These are two-dimensional qualitative demonstrations using the existing solver and 40 pressure iterations. The counter measures steps, not physical time. Repeatability means matching settings and step counts on the same implementation and device; playback duration depends on render callbacks and GPU load. Physical viscosity, calibrated units, obstacles, and replay remain deferred.

### Mac 3D dye-advection preview

On Mac, the Experiments selector and Simulation menu group the established modes under **2D** and the current preview under **3D**. Choose **3D Dye Advection** from either; it opens seeded, paused at **Step 0**. Use **Run**, **Pause/Resume**, **Step**, and **Restart experiment** to inspect the flow. The 3D lesson is not assigned a direct ⌘1–4 shortcut; those shortcuts retain their established 2D meanings.

The initial slightly angled view shows an **XY cross-section at Z depth 50%** inside a subdued wireframe cube, with a corner X/Y/Z orientation guide. The genuine 64³ simulation keeps its fixed grid when the window changes size. Black means no dye; amber through pale cream means increasing local dye concentration. This is a cut through the fluid, not a projection of the whole volume. There is no explicit dye fading or per-frame brightness adjustment: dye may move out of the plane, and numerical advection can smooth it. A step is one solver advance, not a second or display frame.

The separate **Simulation Controls** panel provides native inspection controls:

| Control | Effect |
|---|---|
| **Plane: XY / XZ / YZ** | Select one two-sided sheet fixed in world space. The depth label becomes Z / Y / X respectively. Changing plane preserves the camera and the one shared depth percentage. |
| **Depth** | Move continuously from 0% to 100% along that plane's depth axis. At 50%, cell planes 31 and 32 contribute equally. Display rounding does not snap the sample. |
| **Centre Slice** | Set only depth to 50%; retain plane, camera, visibility and experiment progress. |
| **Show Tracers** | Show/hide 512 sparse pale-cyan passive dots. They follow the three-component flow on every logical step, even while hidden or without a drawable; re-showing never reseeds or catches up. |
| **Horizontal Orbit / Elevation / Zoom** | Inspect from different directions without changing the simulation, including while paused. The upright camera has no pan/roll; a sheet can legitimately become thin edge-on. |
| **Reset Camera** | Restore the initial 25° horizontal orbit, 18° elevation and fitted 100% zoom only; retain slice, visibility, progress and pending steps. |

Plain primary **canvas drag orbits**; **mouse wheel/two-finger scroll zooms**. These are additional routes, not requirements: use Tab/Shift-Tab (with Full Keyboard Access as needed), segment arrow selection and the labelled sliders. Focused slider arrows adjust depth by 1 percentage point, horizontal orbit by 5°, elevation by 3°, and zoom by 5 percentage points. Orbit is bounded to −180°…180° in the slider (canvas dragging wraps), elevation to ±75°, and zoom to 50%…150%. Plane changes never auto-face the camera.

Dots do not deposit dye or exert force and have no trails/speed colours. The slice is **opaque even where black**: markers behind its footprint are hidden, not visible as X-ray dots. Orbiting to the opposite side changes which dots are hidden. Cube edges are orientation overlays, not opaque container walls.

**Restart experiment** resets complete fluid/tracer evolution, clears pending work/input and returns paused to Step 0 while retaining camera, plane, shared depth and tracer visibility. Selecting/reselecting the 3D lesson instead restores initial inspection defaults. Inspection edits and resize do not advance or reset the experiment.

In 3D, 2D-only field views, overlays, and tuning controls are hidden and restored on return to 2D. **S** does nothing and canvas-focused **Space** toggles Run/Pause; focused native controls keep their normal keyboard actions. Space on a focused checkbox/button operates that control once, not transport as well. Panel-originated drag/scroll never orbits/zooms the canvas; camera gestures never activate transport or inject dye/force. The corner guide is noninteractive and passes pointer input through to the canvas. If preparation or an active 3D resource update fails, a native message offers **Continue in 2D** and retry after safe recovery. Returning to 2D restores the existing controls; returning to Free Play creates a fresh running canvas with this session's Free Play preferences.

This is the scoped spatial-inspection preview. **3D speed comparison, full 600-step teaching/completion and all-speed repeatability qualification remain Phase 9 work; transparent volume rendering and integrated performance qualification remain Phase 10 work.** iPhone and iPad remain 2D-only with their established controls/input. Human review is not implied by tests or screenshots: the [Phase 8 verification report](docs/3d-phase8-verification.md) retains the mandatory unchecked visual/accessibility/input checklist. The historical [Phase 7 verification report](docs/3d-phase7-verification.md) and its six pending user-facing requirements are unchanged.

After a fresh Mac Debug build, run the 3D reference/production checks and baseline with:

```bash
python3 -m unittest Tests.Integration.test_fluid3d_reference Tests.Integration.test_fluid3d
python3 -m unittest Tests.Integration.test_inspection3d_reference Tests.Integration.test_inspection3d_state
python3 Tests/Integration/test_fluid3d.py --verify-inspection-evidence .build/inspection3d-evidence
```

The Phase 8 checker requires current source/metallib/contracts/oracle identities, complete spatial/state/failure evidence, and passing builds/full Mac/full integration/iPhone+iPad HUD results with real logs/result bundles. Missing evidence is an error, not a skip. Schema unit tests use explicitly synthetic in-memory fixtures; those are not acceptance runs. The evidence index documents exact commands, durations, inventories and real captures.

The separate historical solver/fixed-slice baseline can still be run with:

```bash
python3 Tests/Integration/test_fluid3d.py --benchmark
python3 Tests/Integration/test_fluid3d.py --check-evidence
```

That legacy checker/benchmark retains its own namespace and workload labels; historical passing evidence is not a fresh Phase 8 result. Add `--quick` to the legacy check to inspect required files, schema, and hashes only, not assert a new numerical PASS. Both fixed-slice baseline timings and new offscreen spatial images are **not displayed FPS**. Displayed frame pacing remains **NOT MEASURED**; the later 30 fps qualification is not part of this preview. Actual macOS 26 runtime and physical iPhone/iPad multitouch remain **NOT TESTED**.

## Controls and manual checks

On Mac, the floating **Simulation Controls** panel can move, close, and reopen with **⌥⌘K** or the View menu. The **Simulation** menu exposes **⌘P** pause/resume, **⌘→** single-step, **⌘R** reset/restart, and **⌘1–4** for the same 2D modes as before. With the canvas focused, **Space** toggles pause; **S** cycles fields in 2D and is a no-op in 3D. Focused controls consume their own keys normally.

On iPhone/iPad, Free Play keeps an overlay HUD. Lessons reserve controls below the square canvas in portrait and beside it in landscape. The selector and transport stay pinned; scroll the body for explanations, views, overlays, and tuning. One-finger double tap outside the HUD pauses; two-finger double tap cycles fields. Single taps and drags add dye only in Free Play.

For each platform:

1. Check the initial empty canvas and tuning defaults. Inject dye, pause, change all four views and overlays, and confirm the step counter remains unchanged. Step once, then reset; tuning and presentation choices must remain.
2. Select each lesson. Predict its behaviour, run, pause, step, change an adjustment, and restart. Verify step zero, the 600-step completion message, and disabled Run/Step at completion. Return to Free Play and check restored preferences.
3. Confirm HUD interactions do not inject fluid. On Mac, test all menu shortcuts, focused-control Space handling, panel movement/closing/reopening, and a paused window resize.
4. On **both iPhone and iPad**, repeat in portrait and landscape, including accessibility text sizes, VoiceOver, increased contrast, and reduced transparency. Controls must not cover the square; all body controls must be scroll-reachable.
5. On physical iPhone/iPad hardware, check concurrent touches and the two-finger shortcut. Simulator results alone do not establish physical multitouch behaviour.

See [educational release verification](docs/educational-release-verification.md) for actual environments, measurements, results, and unavailable coverage. macOS 27 testing does not establish macOS 26 runtime behaviour. Mark unavailable hardware checks **NOT TESTED**.

The production GPU harness loads the freshly built Mac Metal library, writes lesson captures at steps 0/120/240/600 and hardware timings under `.build/educational-evidence`, and compares floating-point state with relative `1e-3` plus absolute `1e-4` tolerance:

```bash
python3 -m unittest Tests.Integration.test_educational_release
python3 -m unittest discover -s Tests/Integration
```

## Understanding the simulation

Read [Equations and real-time approximations](docs/fluid-dynamics.pdf) for a self-contained explanation based on the actual Swift renderer and Metal shaders. It covers the fluid equations, grid and frame sequence, advection, input forces, fading, vorticity confinement, pressure projection, boundary handling, GPU representation, and numerical limitations. It also explains how the controls and displayed fields relate to the equations.

The editable [LaTeX source](docs/fluid-dynamics.tex) is included. Rebuild the PDF from the repository root with a LaTeX distribution and `latexmk`:

```bash
latexmk -pdf -interaction=nonstopmode -halt-on-error -outdir=docs docs/fluid-dynamics.tex
```

Optional background reading: [GPU Gems, Chapter 38, on NVIDIA's current site](https://developer.nvidia.com/gpugems/gpugems/part-vi-beyond-triangles/chapter-38-fast-fluid-dynamics-simulation-gpu). The local document describes this project's implementation where it differs from the general treatment.
