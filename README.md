# FluidDynamicsMetal

Interactive Metal fluid simulation for **macOS 26 on Apple Silicon** and **iOS/iPadOS 26**. The Xcode project uses Swift 5 and has separate Mac and iOS app schemes.

![fluiddynamics](https://github.com/andreipitis/FluidDynamicsMetal/blob/master/FluidDynamicsMetal.gif?raw=true)

## Build and run

Open `FluidDynamicsMetal.xcodeproj` with current Xcode. Install Xcode's Metal Toolchain if the build reports it missing: `xcodebuild -downloadComponent MetalToolchain`. From the project root, build both existing schemes without Swift-version or deployment-target overrides:

```bash
xcodebuild -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetalOSX -configuration Debug -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO build
xcodebuild -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetaliOS -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

For a reusable Mac app at the project root, run `./build-macos.sh`, then `open -a "$(pwd)/FluidDynamicsMetalOSX.app"`. The script builds into ignored `.build/` and copies the app to `FluidDynamicsMetalOSX.app`.

For iPhone or iPad, select the **`FluidDynamicsMetaliOS`** scheme in Xcode and choose an available **iOS 26** iPhone or iPad simulator as the run destination. Discover current destinations with `xcrun simctl list devices available`; avoid copying a device ID from a prior machine. For command-line UI tests, substitute that device's ID:

```bash
xcodebuild test -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetaliOS -configuration Debug -destination 'platform=iOS Simulator,id=<chosen-id>' CODE_SIGNING_ALLOWED=NO
```

Mac state and HUD tests run with:

```bash
xcodebuild test -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetalOSX -configuration Debug -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO
python3 -m unittest test_phase05_metal.py
```

Run the Metal regression check after a fresh Mac Debug build. An arm64 build on a newer Mac does **not** establish that the app launches on macOS 26; see the pending [macOS 26 runtime check](.planning/phases/01-modern-mac-baseline/01-HUMAN-UAT.md).

## Manual compatibility checklist

Record the actual host, OS version, simulator/device, and results separately for each platform in [Phase 6 compatibility verification](.planning/phases/06-platform-compatibility-closeout/06-COMPATIBILITY-VERIFICATION.md). A build, install, or process launch alone does not prove visual fluid interaction. On each platform:

### Mac (Apple Silicon)

1. Launch `FluidDynamicsMetalOSX.app` on the Mac being checked. Confirm a **blue-on-black Density** canvas and a closed **Show Tuning** disclosure. Open Tuning and check **Force 50%, Dye 40%, Swirl 20%, Fade 17%**; close it again.
2. Drag with the mouse **outside the HUD**. Confirm blue density is deposited, swirls, and fades.
3. Click **Pause** and confirm motion stops; choose **Pressure**, **Velocity**, **Vorticity**, then **Density** using the named buttons, including a change while paused. Click **Resume**, confirm motion continues, and drag again. **Space** toggles pause/resume and **S** cycles the four fields when canvas/window focus is appropriate; focused HUD controls may consume Space.
4. Open **Tuning**, change one slider (for example, set Dye to 0% and drag to stir without depositing, or increase Fade for faster fading), and observe the existing effect. Quit and relaunch; confirm the four starting percentages return and Tuning starts closed. There is no in-app reset action.

### iPhone (iOS 26)

1. Run `FluidDynamicsMetaliOS` on an iOS 26 iPhone simulator or device. Confirm blue-on-black **Density**, **Show Tuning** closed, and on opening it **Force 50%, Dye 40%, Swirl 20%, Fade 17%**.
2. Swipe/drag **outside the HUD** to add and stir blue density; release and observe it swirl and fade.
3. Tap **Pause**, then select **Pressure**, **Velocity**, **Vorticity**, and **Density** on-screen, including a field change while paused. Tap **Resume**, check the fluid continues, and drag again. A one-finger double tap outside the HUD also toggles pause/resume.
4. Open **Tuning**; move one slider and check its effect on subsequent input or existing fluid (for example Dye 0% or higher Fade). Quit and relaunch to confirm the four default percentages and closed disclosure.

### iPad (iPadOS 26)

1. Run `FluidDynamicsMetaliOS` on an iPadOS 26 iPad simulator or device. Check blue-on-black **Density**, the closed **Show Tuning** disclosure, then open it to confirm **Force 50%, Dye 40%, Swirl 20%, Fade 17%**.
2. Drag across the canvas **outside the HUD** to stir/deposit density, then release and observe its motion/fade.
3. Use on-screen **Pause** and **Resume**; select **Pressure**, **Velocity**, **Vorticity**, and **Density**, changing at least one field while paused; resume and drag again. A one-finger double tap outside the HUD also toggles pause/resume.
4. Open **Tuning**, vary one slider and observe the existing effect, then quit/relaunch and confirm the four default values and closed disclosure. Scroll inside the HUD if a compact layout hides a control.

On iPhone and iPad, a **two-finger double tap outside the HUD** cycles the displayed field. Xcode 27 Device Hub does not provide the needed two-finger touch simulation here: check that shortcut and concurrent touches on a physical device when available, and record **NOT TESTED** otherwise. Single taps outside the HUD can add dye. Input inside the HUD operates controls rather than stirring the canvas.

The four sliders adjust live Force, Dye, Swirl, and Fade without editing shaders. Simulation resolution/quality, an in-app reset control, and further accessibility work are deferred; parameters without UI controls still live in source.

## Understanding the simulation

Background reading: [GPU Gems, Chapter 38](https://developer.download.nvidia.com/books/HTML/gpugems/gpugems_ch38.html) and [Philip Rideout's fluid simulation article](http://prideout.net/blog/?p=58).
