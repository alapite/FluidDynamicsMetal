---
phase: 01-modern-mac-baseline
verified: 2026-09-24T19:20:00Z
status: human_needed
score: 2/3 must-haves verified
---

# Phase 1: Modern Mac baseline Verification Report

**Phase goal:** People can launch and stir the familiar fluid on an Apple Silicon Mac running macOS 26.
**Status:** human_needed — actual macOS 26 runtime has not been tested.

## Goal Achievement

| Truth | Status | Evidence |
|-------|--------|----------|
| Arm64 Mac app builds without a deployment override, with macOS 26 minimum | ✓ VERIFIED (build) | Fresh `./build-macos.sh` exited 0; `lipo -archs` returned `arm64`, `LSMinimumSystemVersion` returned `26.0`, and `default.metallib` is present. |
| Fluid responds to drag, pause and field switching | ✓ VERIFIED on macOS 27 | User confirmed moving/fading blue density, Space pause/resume and four S presses; `01-BASELINE.md` records the host and results. |
| macOS 26 host launches and displays responding fluid | ? UNCERTAIN | Current host is macOS 27. No launch or drag test on an actual macOS 26 installation yet. |
| Default visual/interaction reference exists | ✓ VERIFIED | `01-BASELINE.md` links the tracked original GIF and lists code-backed defaults and observed results. |

**Score:** 2/3 phase-level success criteria verified; the macOS 26 launch criterion needs human verification.

## Required Artifacts and Wiring

- `FluidDynamicsMetal.xcodeproj/project.pbxproj`: Mac Debug and Release use macOS 26 and Swift 5.
- `build-macos.sh`: builds arm64 Debug app without an override and copies the built bundle to the root.
- `FluidDynamicsMetalOSX/RenderViewController.swift`: mouse events pass interaction points to `Renderer.updateInteraction`.
- `Shared/Renderer.swift` and `Shared/Shaders.metal`: force and scalar shaders are present and linked by name; bundled Metal library exists.
- `01-BASELINE.md`: contains build, launch, interaction, and untested-runtime evidence.

## Requirements Coverage

| Requirement | Status | Remaining check |
|-------------|--------|-----------------|
| PLAT-01 | ? NEEDS HUMAN | Launch and drag on an actual Apple Silicon macOS 26 system, physical or virtual with a usable Metal device. |

## Human Verification Required

### 1. Actual macOS 26 launch and fluid interaction

**Test:** On an Apple Silicon macOS 26 system, confirm the guest/host has a usable Metal device, open the built app, drag across the canvas, and observe moving/fading blue density.

**Expected:** The app launches, renders the fluid, and responds to a drag on macOS 26. Record the exact OS version, physical/VM environment, and observed outcome in `01-BASELINE.md`.

**Why human:** A macOS 27 build and visual pass cannot demonstrate compatibility with a macOS 26 runtime. The current host does not run macOS 26.

## Gaps Summary

No code failure observed. Phase sign-off remains pending the macOS 26 runtime check, deferred to milestone closeout by the user on 2026-09-24. Do not mark PLAT-01 or Phase 1 complete yet; subsequent phase work may proceed under this explicit deferral.

## Verification Metadata

**Approach:** Goal-backward review of plan, build outputs, user observation, and requirement PLAT-01.
**Automated checks:** Debug build and bundle checks passed; no test target exists.
**Human checks:** macOS 27 interaction passed; macOS 26 runtime check pending.

---
*Verified: 2026-09-24*
