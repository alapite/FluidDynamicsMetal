# Modernization Pitfalls

**Date:** 2026-09-24

| Pitfall | Early signal | Mitigation / phase |
|---------|--------------|--------------------|
| Build fails before Swift migration due to 10.13 target or missing Metal Toolchain | `xcodebuild` rejects `MACOSX_DEPLOYMENT_TARGET` or cannot execute `metal` | Set agreed deployment targets; install toolchain before judging code errors, in first phase (`FluidDynamicsMetal.xcodeproj/project.pbxproj`). |
| Swift/Metal uniform structures diverge | Fluid forces or dimensions appear wrong despite successful build | Keep `StaticData` in `Shared/Renderer.swift` aligned with `BufferData` in `Shared/Shaders.metal`; check size/layout and exercise input while migrating settings. |
| SwiftUI bridge recreates renderer or loses touch/mouse updates | Fluid resets while changing controls; drag feels broken | Give renderer stable lifecycle and explicit platform input adapters; test resizing, pause, and multi-touch (`RenderViewController.swift` files). |
| Work moves shader constants without preserving defaults | Fluid fades, spins, or responds differently | Capture before/after visual and input baseline, preserve 40 pressure passes and key constants until parity is confirmed (`Shared/Renderer.swift`, `Shared/Shaders.metal`). |
| Only one target builds | Shared code migrates for Mac but fails on iOS (or vice versa) | Build both schemes after shared changes; both compile `Shared/` independently (`FluidDynamicsMetal.xcodeproj/project.pbxproj`). |
| GPU resources are force-unwrapped or pipeline errors only printed | Blank display/crash on device | Make failure paths visible and test startup/resize/pause; see `Shared/MetalDevice.swift` and `Shared/RenderShader.swift`. |

## Sources

- Repository code and `.planning/codebase/ARCHITECTURE.md` (2026-09-24).
- [Apple: MTKView drawing and drawables](https://developer.apple.com/documentation/metalkit/mtkview.md).
