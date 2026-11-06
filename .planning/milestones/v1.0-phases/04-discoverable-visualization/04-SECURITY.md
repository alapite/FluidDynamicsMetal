---
phase: 4
slug: discoverable-visualization
status: verified
threats_open: 0
asvs_level: 1
created: 2026-09-25
---

# Phase 4 — Security

> Verification of the local integrity and evidence risks identified in the three plan-time `<threat_model>` blocks. Those blocks describe threats in prose rather than assigning STRIDE IDs; the IDs below identify their individual mitigation paths. None of the three summaries has a `## Threat Flags` entry.

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| Local Mac input → HUD/canvas → renderer | HUD actions and canvas drags share a full-size Metal view; focused keyboard shortcuts also reach the controller. | Mouse locations, key events, selected field, pause state |
| Local iOS input → HUD/recognizers/touch bookkeeping → renderer | A compact overlay shares the canvas with ancestor tap recognizers and concurrent touches. | Touch origin, tap/hold positions, fluid contacts, pause state |
| Renderer state → Metal presentation | Direct field selection while paused must present stored textures without advancing the solver. | Selected slab, pause/activity state, GPU drawing commands |
| Build and observation records → phase sign-off | Build success cannot establish live hit-testing or frozen redraw. | Test/build results, user approval, untested variants |

No network, account, or persisted external-input boundary was added in Phase 4.

---

## Threat Register

| Threat ID | Category | Component | Disposition | Mitigation | Status |
|-----------|----------|-----------|-------------|------------|--------|
| T-04-01 | Tampering (integrity) | Mac HUD and canvas pointer routing | mitigate | `FluidDynamicsMetalOSX/RenderViewController.swift:64-72,225-254` installs only a compact HUD above the full-size canvas, excludes HUD mouse-down from `mouseHeld` and fluid updates, and retains canvas drag handling outside it. `04-HUD-VERIFICATION.md:22-32` records user approval of the core Mac input flow without claiming separate resize observations. | closed |
| T-04-02 | Tampering (integrity) | Mac focused Space / field and pause actions | mitigate | `FluidDynamicsMetalOSX/RenderViewController.swift:42-55,187-209,257-277` leaves Space on a focused HUD button to the native control, routes other Space/S events once, and refreshes buttons from renderer state. `Shared/SimulationState.swift:33-49`, `Shared/Renderer.swift:106-120,348-363` preserve pause on direct selection and present the selected slab without solver work while paused. `FluidDynamicsMetalStateTests/SimulationStateTests.swift:21-44` exercises direct and paused selection; the Mac core flow was user-approved in `04-HUD-VERIFICATION.md:26-29`. | closed |
| T-04-03 | Tampering (integrity) | iOS HUD taps and ancestor canvas recognizers | mitigate | `FluidDynamicsMetaliOS/RenderViewController.swift:48-66,230-241,360-365` sets a per-touch delegate on all three canvas tap recognizers, rejects HUD-origin touches by ancestry or HUD bounds, and guards dye enqueue from HUD-origin taps. `04-HUD-VERIFICATION.md:34-60` records core tap/drag approval on both simulators; physical two-finger interactions remain NOT TESTED. | closed |
| T-04-04 | Tampering (integrity) | iOS held-contact bookkeeping and pause | mitigate | `FluidDynamicsMetaliOS/RenderViewController.swift:217-228,274-342,367-390` excludes HUD touches from contact/hold tracking, clears outstanding touches on HUD pause, and keeps outside contacts eligible for fluid input. `Shared/Renderer.swift:111-120,133-167,348-363` rejects paused input and renders a paused field without advancing. `04-HUD-VERIFICATION.md:38-60` records core iPhone/iPad approval; simultaneous physical HUD-plus-canvas contact remains NOT TESTED. | closed |
| T-04-05 | Repudiation | Phase verification and sign-off | mitigate | `04-HUD-VERIFICATION.md:10-62` distinguishes six executed state tests, two successful builds and app launches from the user's broad Mac/iPhone/iPad approval; it explicitly marks unreported appearance, layout and physical multitouch variants NOT TESTED. `04-VALIDATION.md:57-78` retains those evidence limits in sign-off, so compilation is not presented as live interaction proof. | closed |

*Status: open · closed. Disposition: mitigate (implementation required) · accept (documented risk) · transfer (third-party).*

---

## Accepted Risks Log

No accepted Phase 4 risks. Phase 3's AR-03-01 remains attributed to Phase 3; the unreported Phase 4 settings and physical-device checks remain NOT TESTED in `04-HUD-VERIFICATION.md`, not reclassified as verified or accepted risks.

---

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-09-25 | 5 | 5 | 0 | Inline plan-time mitigation audit (configured security auditor unavailable) |

## Security Audit 2026-09-25

| Metric | Count |
|--------|-------|
| Threats found | 5 |
| Closed by verified mitigation | 5 |
| Open | 0 |

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log (none for Phase 4)
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-09-25; evidence limitations remain documented in `04-HUD-VERIFICATION.md`.
