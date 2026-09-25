# Project Retrospective

## Milestone: v1.0 — Modernization

**Closed:** 2026-09-25
**Phases:** 6 | **Plans:** 14 | **Tasks:** 24

### What Was Built

- Apple Silicon Mac and iOS/iPadOS Swift 5 Metal builds with shared fluid behavior.
- Mac and iOS HUDs for pause, named display fields and live Force/Dye/Swirl/Fade tuning.
- State, GPU and HUD tests plus host-attributed manual build/interaction instructions.

### What Worked

- Keeping build, bundle, launch, automation and user observation evidence separate prevented macOS 27 results from being mistaken for a macOS 26 runtime check.
- Production-state and offscreen Metal checks covered the solver's defaults and tuning without redesigning its appearance.

### What Was Inefficient

- Simulator UI automation timed out on iPad and in both Phase 6 iOS runs; incomplete result bundles could not verify the suites.
- The Mac focused-Space fix initially remained uncommitted after validation; it was later verified and committed as `aae6958`.
- An overly specific focused-Pause manual check was treated as a possible milestone concern despite the user's repeated confirmation of the actual behavior. It was not a closeout gate.

### Patterns and Lessons

1. Commit validated fixes with their regression tests before using working-tree results as clean-checkout evidence.
2. Keep deferred host/device verification visible and NOT TESTED, while allowing explicitly approved milestone closure when other work has priority.

### Cost Observations

Model mix and session totals were not recorded. Mac tests complete quickly on the available host; simulator UI timeout budgets dominate verification latency.

---

## Cross-Milestone Trends

| Milestone | Phases | Key change |
|-----------|--------|------------|
| v1.0 | 6 | Host-attributed verification with explicit deferral of unavailable macOS 26 runtime coverage. |
