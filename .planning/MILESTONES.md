# Project Milestones: FluidDynamicsMetal Modernization

## v1.0 Modernization (Closed: 2026-09-25)

**Delivered:** Reproducible Swift 5 Metal apps for Apple Silicon Mac and iOS/iPadOS, with native pause, named-field selection and live Force/Dye/Swirl/Fade tuning; available-host build and interaction instructions.

**Implementation:** 6 phases, 14/14 plans, 24 tasks. The Phase 1 implementation plan completed; its macOS 26 runtime verification did not.

**Key accomplishments:**

- Mac arm64 build with macOS 26 minimum, reusable root app, and documented blue-fluid baseline observed on macOS 27.
- iOS 26 simulator builds and iPhone/iPad touch interaction, with shared state and GPU regression checks.
- Native Mac/iOS pause and four named field controls, followed by live tuning of Force, Dye, Swirl and Fade.
- Separate Mac/iPhone/iPad build and manual checklists with attributed outcomes and explicit NOT TESTED cases.

**Known deferred items at close:** 3 open artifacts in the 2026-09-25 `audit-open` report (Phase 1 UAT and verification, Phase 2 partial UAT); see `.planning/STATE.md` Deferred Items. **PLAT-01 is unverified:** actual macOS 26 launch/drag remains NOT TESTED and was explicitly deferred beyond v1.0 by the user to prioritize other work. Physical-device two-finger/concurrent-touch checks remain non-blocking NOT TESTED. Phase 6 iPhone/iPad UI automation timed out, independently of user-approved manual walkthroughs. 11/12 v1 requirements were verified; PLAT-01 was not silently checked off.

**Archive:** [roadmap](milestones/v1.0-ROADMAP.md) · [requirements](milestones/v1.0-REQUIREMENTS.md). Phase histories remain in `.planning/phases/` for follow-up.
