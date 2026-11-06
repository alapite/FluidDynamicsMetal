---
phase: 01-modern-mac-baseline
plan: 01
subsystem: macos
tags: [appkit, metal, apple-silicon, macos26]
requires: []
provides:
  - Arm64 Mac build with macOS 26 minimum and bundled Metal library
  - Reproducible fluid appearance and interaction reference
affects: [modern-ios-parity, reliable-simulation-state]
tech-stack:
  added: []
  patterns: ["Build and copy the Mac app with ./build-macos.sh"]
key-files:
  created: [build-macos.sh, .planning/phases/01-modern-mac-baseline/01-BASELINE.md]
  modified: [FluidDynamicsMetal.xcodeproj/project.pbxproj, README.md, .gitignore, .planning/phases/01-modern-mac-baseline/01-VALIDATION.md]
key-decisions:
  - "Preserve the existing renderer and shader defaults while updating the Mac target to Swift 5 and macOS 26."
  - "Keep actual macOS 26 runtime compatibility unverified until tested on a macOS 26 host."
patterns-established:
  - "Record build, bundle, and user-observed interaction evidence separately from untested runtime claims."
requirements-completed: [PLAT-01]
duration: recovery closeout of work committed earlier on 2026-09-24
completed: 2026-09-24
---

# Phase 1 Plan 01: Modern Mac baseline Summary

**Apple Silicon Mac app builds without a deployment-target override and has a documented blue-fluid baseline with user-confirmed drag, pause, and field cycling on macOS 27.**

## Performance

- **Duration:** Recovered a previously committed build and completed its manual checkpoint on 2026-09-24; original execution duration not recorded.
- **Started:** Prior to commit `7dd175a` on 2026-09-24; exact time not recorded.
- **Completed:** 2026-09-24
- **Tasks:** 3/3 plan tasks addressed; macOS 26 host verification remains pending.
- **Files modified:** 5 build/baseline files in the original commit; baseline and validation evidence updated at closeout.

## Accomplishments

- Mac target Debug and Release settings use Swift 5 and macOS 26; previous Debug and Release builds succeeded on an Apple Silicon macOS 27 host.
- Fresh `./build-macos.sh` succeeds; the root app has an arm64 executable, `LSMinimumSystemVersion = 26.0`, and `default.metallib`.
- User visually confirmed drag produces moving/fading blue density, Space pauses/resumes, and S cycles pressure → velocity → vorticity → density in the opened app on macOS 27.
- `01-BASELINE.md` links the original GIF and distinguishes observed behavior from the still-untested macOS 26 runtime.

## Task Commits

1. **Task 1: Deliver a runnable Apple Silicon Mac fluid slice** — `7dd175a` (original combined build-baseline commit).
2. **Task 2: Publish a reproducible default-look reference** — `7dd175a` (same original commit).
3. **Task 3: Confirm live fluid at phase closeout** — user-confirmed macOS 27 interaction; documented in this closeout commit.

The original commit predated this recovery and combined Tasks 1–2 rather than committing them separately. The missing summary is being repaired instead of replaying the committed implementation.

## Files Created/Modified

- `FluidDynamicsMetal.xcodeproj/project.pbxproj` — Mac deployment target and Swift language mode.
- `build-macos.sh` — repeatable arm64 Debug build and root app copy.
- `.gitignore` — ignores local build output and app bundle.
- `README.md` — Mac build instructions.
- `01-BASELINE.md` — defaults, build evidence, and observed interaction results.
- `01-VALIDATION.md` — remaining macOS 26 runtime check.

## Decisions Made

- Left the iOS target unchanged for Phase 2.
- Retained `NOT TESTED` for macOS 26 runtime; building against a 26.0 minimum on macOS 27 is not a runtime test on macOS 26.

## Deviations from Plan

- Tasks 1–2 were committed together in `7dd175a`, before a summary was created. Closeout recovered the existing implementation rather than re-executing or reverting it.
- Manual interaction verification was deferred to phase closeout and is now recorded from the user's observation.

## Issues Encountered

- No macOS 26 host was available for runtime sign-off. The phase goal remains subject to that human verification.
- Screenshot capture was unavailable; the optional screenshot is not required and the tracked GIF remains the reference.

## User Setup Required

Metal Toolchain already installed on this host. To confirm macOS 26 compatibility, launch this build on an Apple Silicon macOS 26 system (physical or virtual with a usable Metal device) and record the OS version and drag outcome.

## Next Phase Readiness

- The reproducible Mac build and visual reference are available for iOS parity work.
- Phase 1 should not be marked fully verified until macOS 26 launch and drag are observed.

## Self-Check: PASSED

- Fresh Mac Debug build and bundle checks passed; user confirmed the three live interaction checks on macOS 27.
- macOS 26 runtime sign-off remains explicitly pending for the phase-level verifier.

---
*Phase: 01-modern-mac-baseline*
*Completed: 2026-09-24*
