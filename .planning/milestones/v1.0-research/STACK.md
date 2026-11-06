# Stack Research

**Date:** 2026-09-24
**Context:** Modernizing `FluidDynamicsMetal.xcodeproj` for macOS 26 / Apple Silicon and iOS 26.

## Recommended baseline

- **Xcode / Swift:** Use an Xcode release with macOS 26 and iOS 26 SDK support, migrate `SWIFT_VERSION = 4.0` in `FluidDynamicsMetal.xcodeproj/project.pbxproj` to a current compiler mode, and address warnings deliberately. This machine has Xcode 27.0 and 27.0 SDKs; required Swift language mode should be verified during the migration. Confidence: high for SDK approach, medium for exact compiler-mode choice.
- **GPU:** Keep MetalKit's `MTKView` and the existing Metal render passes (`Shared/Renderer.swift`, `Shared/Shaders.metal`). Apple's `MTKView` documentation supports continuous timed drawing through `MTKViewDelegate` and late drawable acquisition; no need to replace the solver to modernize UI. Confidence: high.
- **UI:** Evaluate SwiftUI for native controls, embedding `MTKView` using `NSViewRepresentable` and `UIViewRepresentable` on the respective platforms; these wrappers support creation, updates, teardown, and coordinator-based communication. Keep a platform-specific input adapter for mouse/trackpad versus multitouch. Confidence: high for feasibility, medium for migration cost.
- **Tests:** Add an Xcode test target using Swift Testing for parameter validation and state transitions; use on-device/simulator builds and manual GPU checks for shader behavior. Apple's Swift Testing docs confirm Xcode-project integration. Confidence: high.

## Avoid

- A complete compute-kernel/Metal 4 rewrite just to adopt newer APIs: no evidence it is necessary to preserve the current simulation.
- Retaining deployment targets of macOS 10.13 / iOS 10.x from `FluidDynamicsMetal.xcodeproj/project.pbxproj`; they contradict the agreed compatibility baseline.
- Treating SwiftUI as a replacement for GPU drawing; use native controls around a Metal view.

## Sources

- [Apple: MTKView](https://developer.apple.com/documentation/metalkit/mtkview.md)
- [Apple: NSViewRepresentable](https://developer.apple.com/documentation/swiftui/nsviewrepresentable.md)
- [Apple: UIViewRepresentable](https://developer.apple.com/documentation/swiftui/uiviewrepresentable.md)
- [Apple: Swift Testing](https://developer.apple.com/documentation/testing.md)
- [Apple: configuring target build settings](https://developer.apple.com/documentation/xcode/configuring-the-build-settings-of-a-target.md)
