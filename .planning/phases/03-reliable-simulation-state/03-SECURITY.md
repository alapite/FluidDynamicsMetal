---
phase: 3
slug: reliable-simulation-state
status: verified
threats_open: 0
asvs_level: 1
created: 2026-09-25
---

# Phase 3 — Security

> Retroactive STRIDE review of the completed simulation-state phase. The three plans contain prose `<threat_model>` blocks but no threat IDs or formal STRIDE register; their summaries contain no `## Threat Flags` entries. This register was constructed from the implemented local input, simulation, resize, and verification paths.

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| OS input/lifecycle → controllers → renderer | Local mouse/touch events, view geometry, and app activity control solver input and drawing. | Coordinates, impulses, touch identity, pause/activity state |
| Renderer → Metal command queue/shaders | CPU-owned textures and uniforms are used asynchronously by GPU passes and replaced on resize. | RG16F fields, grid dimensions, contact uniforms |
| Build/test output → phase verification | Automated and human observations support claims about completed behavior. | Test results, simulator/host observations, untested cases |

No network, account, or persisted user-input boundary is introduced by this phase.

---

## Threat Register

| Threat ID | Category | Component | Disposition | Mitigation | Status |
|-----------|----------|-----------|-------------|------------|--------|
| T-03-01 | Tampering (integrity) | Simulation tuning | mitigate | `Shared/SimulationState.swift:8-30` clamps finite values and replaces non-finite floating values with defaults; `FluidDynamicsMetalStateTests/SimulationStateTests.swift:52-98` checks bounds, fallbacks and reset. Tuning is state-only in this phase, not a live GPU control. | closed |
| T-03-02 | Tampering (integrity) | Paused/inactive input and solver | mitigate | `Shared/Renderer.swift:110-159,343-358` clears pending contacts/taps, rejects input while inactive/paused, and renders without solver passes; `FluidDynamicsMetaliOS/RenderViewController.swift:164-199` clears held touches and delayed holds on pause/inactivity; `Shared/SimulationState.swift:33-48` preserves manual pause across lifecycle changes. State tests and the host-separated observations in `03-STATE-VERIFICATION.md` support these paths. | closed |
| T-03-03 | Tampering (integrity) | Resize and held pointer/touch input | mitigate | `Shared/Renderer.swift:415-420,465-468` rejects non-finite/zero view dimensions and clears old contacts on successful migration; Mac `RenderViewController.swift:39-69` and iOS `RenderViewController.swift:65-79` rebase held positions after layout. Mac and simulator resize/held-input observations are recorded in `03-STATE-VERIFICATION.md:26-36`. | closed |
| T-03-04 | Denial of service / Tampering (integrity) | In-flight Metal textures and uniforms | accept | `Shared/Renderer.swift:422-467` drains in-flight permits and checks command completion; `Shared/Shaders.metal:48-54` provides clamped resampling. However, `Shared/RenderShader.swift:54-73,85-97` silently skips a pass if pipeline/encoder creation fails, and a completed command does not prove any passes encoded. See accepted risk AR-03-01 and `03-REVIEW.md` WR-01. | closed (accepted risk) |
| T-03-05 | Repudiation | Phase verification claims | mitigate | `03-STATE-VERIFICATION.md:11-39` separates executable tests, GPU readback, user-observed Mac/simulator behavior, and NOT TESTED iOS two-finger/physical-device behavior. `03-VALIDATION.md:55-63` records the evidence limits; no unobserved device result is reported as a pass. | closed |

*Status: open · closed. Disposition: mitigate (implementation required) · accept (documented risk) · transfer (third-party).*

---

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|-------------|------|
| AR-03-01 | T-03-04 | If Metal resample pipeline/encoder creation fails, `RenderShader` can skip encoding while the empty command completes; `Renderer` then publishes replacement textures, potentially losing fluid state on resize. This is a local GPU failure path; the user explicitly accepted the residual integrity/availability risk during this audit. WR-01 in `03-REVIEW.md` tracks the missing encoded-pass check. Acceptance does not verify the failure path or fix it. | User (explicit security-gate decision) | 2026-09-25 |

The untested physical two-finger gesture and macOS 26 runtime cases remain explicitly NOT TESTED in `03-STATE-VERIFICATION.md`; this audit does not reclassify them as verified behavior.

---

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-09-25 | 5 | 5 | 0 | Inline retroactive STRIDE audit (configured auditor unavailable) |
| 2026-09-25 | 5 | 5 (4 mitigated, 1 accepted) | 0 | Inline mitigation re-audit; AR-03-01 accepted by user |

## Security Audit 2026-09-25

| Metric | Count |
|--------|-------|
| Threats found | 5 |
| Closed | 5 |
| Open | 0 |

## Security Re-audit 2026-09-25

| Metric | Count |
|--------|-------|
| Threats found | 5 |
| Closed by verified mitigation | 4 |
| Closed by accepted risk | 1 |
| Open | 0 |

`T-03-04` was reopened during mitigation verification because the encoder-failure path is not protected by the command-completion check, then closed by explicit user risk acceptance (AR-03-01). The original audit above records its earlier classification; no implementation fix or failure-injection test was performed in this re-audit.

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log (AR-03-01)
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified with user-accepted risk AR-03-01 on 2026-09-25
