---
phase: 5
slug: live-fluid-tuning
status: verified
threats_open: 0
asvs_level: 1
created: 2026-09-25
---

# Phase 5 — Security

> Verification of the local integrity and availability risks described in the three Phase 5 plan-time `<threat_model>` blocks. Threat IDs and STRIDE categories below normalize those prose registers; none were assigned in the plans. The phase summaries contain no additional `Threat Flags` entries.

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| Canvas ↔ native HUD | Mac pointer and iOS touches/gestures must be routed to the actual HUD or to fluid input, not both. | Local pointer/touch events and slider positions |
| UI/shared state ↔ Metal commands | Bounded tuning state is sampled for a running frame and written to its available uniform buffer. | Local Force/Dye impulses, Fade retention, Swirl coefficient |
| Automated evidence ↔ human sign-off | GPU and UI results must be distinguished from observed app behavior before phase approval. | Test results and attributed observations |

---

## Threat Register

| Threat ID | Category | Component | Disposition | Mitigation | Status |
|-----------|----------|-----------|-------------|------------|--------|
| T-05-01 | Tampering (input integrity) | Mac HUD/canvas | mitigate | `FluidDynamicsMetalOSX/RenderViewController.swift:295-305` excludes HUD-origin mouse-down events from contacts; HUD bounds are constrained in `:163-170` and `:202-231`. User-approved Mac HUD isolation is recorded in `05-TUNING-VERIFICATION.md:38-39`. | closed |
| T-05-02 | Tampering (frame integrity) | Shared state/uniform buffers | mitigate | `Shared/SimulationState.swift:20-39,45-63` bounds positions and solver values; `Shared/Renderer.swift:182-229,355-405` snapshots tuning once per running frame, writes only the selected available buffer, and uses the same snapshot for extra contact batches. `:362-370` bypasses solver passes when paused; `:435-480` waits for in-flight frames before replacing buffers on resize. Matched shader layout/use: `Shared/Shaders.metal:58-69,142-152,224-253`. Production shader readback passed again on 2026-09-25 (`python3 -m unittest test_phase05_metal.py`). | closed |
| T-05-03 | Tampering (input integrity) | iOS HUD/gestures | mitigate | `FluidDynamicsMetaliOS/RenderViewController.swift:316-327,360-379,446-451` excludes HUD-origin touches from raw contacts and all canvas recognizers, including tap enqueue. The iPhone HUD/outside double-tap tests and separately attributed iPhone/iPad observations appear in `05-TUNING-VERIFICATION.md:18,27-40`. | closed |
| T-05-04 | Denial of service (control availability) | Compact iOS HUD | mitigate | `FluidDynamicsMetaliOS/RenderViewController.swift:167-197,222-260` installs one scroll view for the whole control stack, bounds the expanded HUD to the safe area, and keeps an active-field summary when scrolling; `FluidDynamicsMetaliOSUITests/HUDUITests.swift:83-99` checks Fade and Pause reachability in iPhone landscape. User-approved iPhone/iPad compact-layout observations are in `05-TUNING-VERIFICATION.md:38`. | closed |
| T-05-05 | Tampering (verification integrity) | Phase sign-off | mitigate | `05-03-PLAN.md:58-85` requires numeric GPU checks, separate platform observations, and a blocking human checkpoint. `05-TUNING-VERIFICATION.md:10-44` separates executed tests, numeric readback, user-approved live results and NOT TESTED iPad UI automation/physical multitouch; `05-VALIDATION.md:38-48,70-79` retains those distinctions. | closed |

*Status: open · closed. Disposition: mitigate (implementation required) · accept (documented risk) · transfer (third-party).*

---

## Accepted Risks Log

No accepted risks. The iPad UI-test timeout and physical-device multitouch remain explicitly NOT TESTED follow-ups in the phase verification record; they have not been relabeled as tested or accepted security risks.

---

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-09-25 | 5 | 5 | 0 | OpenCode inline verification of plan-time threats, source and phase evidence |

## Security Audit 2026-09-25

| Metric | Count |
|--------|-------|
| Threats found | 5 |
| Closed | 5 |
| Open | 0 |

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log (none)
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-09-25
