---
phase: 05-live-fluid-tuning
verified: 2026-09-25
status: passed
score: 3/3 phase goal criteria supported within approved available-host scope
---

# Phase 5 — Live Fluid Tuning Verification

**Goal:** Users can shape the fluid's response on both platforms while it runs.

## Goal Achievement

| Phase criterion | Status | Evidence |
|-----------------|--------|----------|
| Both apps provide bounded Force and Dye controls with immediate, independent effects | PASS on available hosts | `SimulationTuning.setPosition` maps 0...1 to bounded solver values; both platform HUD slider actions call `Renderer.setTuningPosition`. `Renderer.draw(in:)` snapshots the state per running frame and applies independent contact vector/scalar impulses including subsequent batches. State tests check endpoints/defaults/non-finite input; RG16F readback distinguishes zero Force from zero Dye; the user approved next-movement and tap behavior on Mac/iPhone/iPad. |
| Both apps provide bounded Swirl and Fade controls affecting already-present fluid | PASS on available hosts | A matching aligned `StaticData`/`BufferData` tuning vector supplies retention to both velocity and density advection and swirl to vorticity confinement each running frame. GPU readback shows changed retained values and non-contact curl. UI tests confirm labels and percentage readouts; the user approved ongoing-fluid and pause/resume behavior on all three available hosts. |
| Default control values preserve the familiar original simulation | PASS on available hosts | Shared state retains force 1, dye 0.8, swirl 0.4 and retention 0.998; the displayed positions are 50%, 40%, 20%, 17%. The original 150 radius and 40 pressure iterations remain. The user approved the recognizable blue-on-black starting appearance on Mac/iPhone/iPad against the Phase 1 baseline. |

## Requirements and Artifacts

| Requirement | Plans and evidence | Result |
|-------------|--------------------|--------|
| CTRL-02 | `05-01`, `05-02`, `05-03` PLAN/SUMMARY frontmatter; shared Force/Dye mapping, contact packing, Mac/iOS native controls, numeric GPU splats, user-approved input checks | PASS |
| CTRL-03 | Same three PLAN/SUMMARY references; shared Swirl mapping, Metal confinement uniform, stored-vorticity GPU readback, user-approved ongoing-fluid checks | PASS |
| CTRL-04 | Same three PLAN/SUMMARY references; inverse piecewise Fade mapping, original 0.998 detent, both-field Metal advection readback, user-approved rightward fade checks | PASS |

All three plans have a committed SUMMARY with `## Self-Check: PASSED`; all three requirement IDs appear in each PLAN frontmatter and are accounted for here. A visible reset and quality control remain Phase 6 work.

## Automated and Regression Checks

- Fresh after the code-review attempt was reverted: Mac `xcodebuild test -quiet -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetalOSX -configuration Debug -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO`: **13/13 passed** (8 shared state, 5 HUD UI). The result bundle `Test-FluidDynamicsMetalOSX-2026.09.25_21-04-41-+0100.xcresult` reports 0 failures.
- Fresh Mac Debug `default.metallib`: `python3 -m unittest test_phase05_metal.py` **1/1 passed**; `05-TUNING-VERIFICATION.md` records actual numeric RG16F results.
- iPhone 17 Pro/iOS 26.4: `xcodebuild test -quiet -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetaliOS -configuration Debug -destination 'platform=iOS Simulator,id=8393A81F-69D4-439E-AF8E-ED7665022800' CODE_SIGNING_ALLOWED=NO`: **6/6 HUD UI cases passed**; generic iOS Simulator Debug and Mac Debug builds succeeded without deployment overrides. The iPhone result bundle is `Test-FluidDynamicsMetaliOS-2026.09.25_20-30-16-+0100.xcresult`.
- Prior-phase regression command `python3 -m unittest -v test_phase02_settings test_phase02_bundle test_phase02_metal test_phase03_metal`: **5/5 passed** after Phase 5; includes iPhone and iPad app-bundle launch checks and previous Metal behavior.
- `gsd-sdk query verify.schema-drift 05`: `drift_detected: false`. The structural drift query emitted a non-blocking legacy-map warning (`last_mapped_commit: null`), listing historical project files rather than a phase blocker.

## Human Evidence and Follow-ups

The user answered the Phase 5 checkpoint on 2026-09-25: “Approved. All of checklist items pass on all of the target devices.” `05-TUNING-VERIFICATION.md` attributes that approval separately to Mac macOS 27, iPhone 17 Pro/iOS 26.4 simulator and iPad Pro M5/iOS 26.4 simulator across defaults, Force/Dye, Swirl/Fade, pause, disclosure, compact scrolling and outside-HUD input. This is a user-reported observation, not an inference from builds or pixel tests.

The iPad **UI automation** timed out twice without a usable result despite simulator app launch and the user's live iPad approval. Physical iOS two-finger/concurrent touches and Phase 1 macOS 26 runtime remain NOT TESTED non-blocking follow-ups per the existing user decision. `05-REVIEW.md` contains two advisory Mac keyboard/compact-layout warnings and one GPU-test coverage note; in particular, the Mac focused-Space verification used earlier user-owned uncommitted working-tree changes excluded from Phase 5 commits. None is represented as clean-checkout keyboard sign-off.

## Verification Metadata

Goal-backward inspection of PLAN/SUMMARY frontmatter and implementation paths, fresh Mac state/HUD and GPU checks, prior-phase regression, iPhone HUD checks, the separately user-approved available-host observation matrix and explicit outstanding coverage. Verified inline because the typed `gsd-verifier` agent is unavailable in this runtime.
