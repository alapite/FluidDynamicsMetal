# Phase 1 — Mac default look and interaction baseline

**Captured:** 2026-09-24
**Reference:** [Original fluid animation](../../../FluidDynamicsMetal.gif) (tracked before modernization)

## Build and launch

- Build host: Apple Silicon Mac, macOS 27.0 (26A428); Xcode 27.0 (27A266a), macOS 27.0 SDK, Xcode Metal Toolchain 27A266a installed with `xcodebuild -downloadComponent MetalToolchain`.
- App minimum deployment target: macOS 26.0; executable architecture: arm64 (verified using `lipo -archs`); Mach-O `LC_BUILD_VERSION` reports `minos 26.0`, `sdk 27.0`; `Contents/Info.plist` reports `LSMinimumSystemVersion = 26.0`.
- Build command (no deployment-target override):

  ```bash
  xcodebuild -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetalOSX -configuration Debug -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO build
  ```

- To build and copy the app to the project root with reusable local build output in `.build/`, run:

  ```bash
  ./build-macos.sh
  ```

- When ready for manual testing, open the predictable root-level app with `open -a "$(pwd)/FluidDynamicsMetalOSX.app"` from the project root, or double-click `FluidDynamicsMetalOSX.app` in Finder. Direct `xcodebuild` builds remain under Xcode's DerivedData; the script copies its build into the root.
- The root bundle includes `Contents/Resources/default.metallib` and is ignored by Git along with `.build/`.

## Code-backed defaults (unchanged)

| Setting | Default | Source |
|---------|---------|--------|
| Initial displayed slab | density (`currentIndex = 0`) | `Shared/Renderer.swift` `drawSlab()` |
| Scalar visualization RGB | `(0.0, 0.06, 0.19)` (blue on black) | `Shared/Shaders.metal` `visualizeScalar` |
| `ScreenScaleAdjustment` | `1.0` | `Shared/Renderer.swift` |
| `inkRadius` | `150 / ScreenScaleAdjustment` (150 at default) | `Shared/Renderer.swift` `initBuffers` |
| Scalar impulse | `(0.8, 0.0)` | `Shared/Renderer.swift` `nextBuffer` |
| Advection fade | `0.998h` | `Shared/Shaders.metal` `advect` |
| Vorticity curl | `(0.4, 0.4)` | `Shared/Shaders.metal` `vorticityConfinement` |
| Pressure iterations | 40 per frame | `Shared/Renderer.swift` `draw(in:)` |

## Interaction reference

- Mouse-down and drag send position/impulse to `Renderer`; dragging deposits density and force, and mouse-up clears the interaction. The default field shows dark-blue swirling density on a black background in the original GIF.
- Space toggles pause. S cycles **density → pressure → velocity → vorticity → density**. These are code-backed expectations; the verification table distinguishes observed behavior.

## Observed verification

| Check | Result | Evidence / host |
|-------|--------|-----------------|
| Debug arm64 build without target override | PASS | `xcodebuild ... CODE_SIGNING_ALLOWED=NO build` returned `** BUILD SUCCEEDED **`; macOS 27 host. |
| Release arm64 build without target override | PASS | `xcodebuild -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetalOSX -configuration Release -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO build` returned `** BUILD SUCCEEDED **`; macOS 27 host. |
| Root-level app script | PASS | `./build-macos.sh` ran twice and produced `FluidDynamicsMetalOSX.app` at the project root; `lipo -archs` reported `arm64`, `LSMinimumSystemVersion` reported `26.0`, and `default.metallib` exists. |
| Launch / window created | PASS | `open -n -a ...` returned 0; `pgrep` showed the app process and CoreGraphics listed an 800×632 on-screen app window; macOS 27 host. Visual contents were not captured. |
| Drag produces moving blue density | PASS | User visually observed blue density move and fade in the app opened on the macOS 27.0 Apple Silicon host, 2026-09-24. |
| Space pauses/resumes | PASS | User pressed Space twice and observed the animation pause and resume on the macOS 27.0 host, 2026-09-24. |
| S cycles four fields | PASS | User pressed S four times and observed pressure → velocity → vorticity → density on the macOS 27.0 host, 2026-09-24. |
| macOS 26 runtime launch/drag | NOT TESTED | Current host runs macOS 27; launch and drag on an actual macOS 26 system, physical or virtual with a usable Metal device, are needed to establish this result. |
| Screenshot of running dragged density | NOT TESTED | Optional only; an agent screenshot attempt returned `could not create image from window`. Do not grant recording permissions solely for this reference. |

The original GIF above is the existing visual reference; it is not a screenshot of this build. The app itself contains no screen or audio capture code. The recording permission prompt may have been triggered by the agent's screenshot attempt; **no recording permission is needed** to open the app and test the mouse and keys. The user confirmed drag/Space/S behavior at phase closeout on macOS 27. Actual macOS 26 runtime compatibility remains untested. A macOS 26 virtual machine on Apple Silicon is a possible test host; confirm that its guest exposes a usable Metal device before using it for the fluid interaction check. Add a screenshot link only if an image already exists without prompting for permissions.
