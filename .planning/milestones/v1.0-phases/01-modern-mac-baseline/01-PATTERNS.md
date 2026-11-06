# Phase 1 — Existing Code Patterns

**Mapped:** 2026-09-24
**Scope:** Mac target settings and runnable fluid baseline.

| Planned file / role | Existing analog | Data flow / constraint |
|---------------------|-----------------|------------------------|
| `FluidDynamicsMetal.xcodeproj/project.pbxproj` — Mac build settings | Mac target Debug `75D520A51FE5539E003525F9` and Release `75D520A61FE5539E003525F9` configurations | Set `MACOSX_DEPLOYMENT_TARGET` and `SWIFT_VERSION` in both Mac configurations; project/iOS configurations have separate settings. |
| `01-BASELINE.md` — default visual reference | `README.md` and tracked `FluidDynamicsMetal.gif` | Document mouse drag, Space, S and default density; supplement original GIF with observed build/OS/runtime evidence. |
| `FluidDynamicsMetalOSX/RenderViewController.swift` — input/launch analog | Existing `viewDidLoad`, `mouseDown`, `mouseDragged`, `mouseUp`, `keyDown` | Storyboard `MTKView` → `Renderer` delegate → positions/density impulse; preserve input event path. |
| `Shared/Renderer.swift` and `Shared/Shaders.metal` — behavior source of truth | `StaticData` and `BufferData`, `draw(in:)`, `visualizeScalar` | Maintain matching uniform layout, shader names and 40 pressure steps; only edit if actual build diagnostics require it. |

No new framework, service, storage layer, or source-level UI component is planned for this phase.
