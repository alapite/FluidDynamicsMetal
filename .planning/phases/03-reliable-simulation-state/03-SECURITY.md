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
| T-03-01 | Tampering (integrity) | Simulation tuning | mitigate | `Shared/SimulationState.swift:8-30` clamps finite values and replaces non-finite floating values with defaults; `FluidDynamicsMetalStateTests/SimulationStateTests.swift:38-63` checks bounds and fallbacks. Tuning is state-only in this phase, not a live GPU control. | closed |
| T-03-02 | Tampering (integrity) | Paused/inactive input and solver | mitigate | `Shared/Renderer.swift:110-159,343-358` clears pending contacts/taps, rejects input while inactive/paused, and renders without solver passes; `FluidDynamicsMetaliOS/RenderViewController.swift:164-199` clears held touches and delayed holds on pause/inactivity; `Shared/SimulationState.swift:33-48` preserves manual pause across lifecycle changes. State tests and the host-separated observations in `03-STATE-VERIFICATION.md` support these paths. | closed |
| T-03-03 | Tampering (integrity) | Resize and held pointer/touch input | mitigate | `Shared/Renderer.swift:415-420,465-468` rejects non-finite/zero view dimensions and clears old contacts on successful migration; Mac `RenderViewController.swift:39-69` and iOS `RenderViewController.swift:65-79` rebase held positions after layout. Mac and simulator resize/held-input observations are recorded in `03-STATE-VERIFICATION.md:26-36`. | closed |
| T-03-04 | Denial of service / Tampering (integrity) | In-flight Metal textures and uniforms | mitigate | `Shared/Renderer.swift:422-467` drains all three in-flight permits, waits for the serial-queue resampling command, checks completion before publishing replacement slabs, and releases permits on exit. `Shared/Shaders.metal:48-54` samples old texture with clamped normalized UV; the offscreen readback and build results are recorded in `03-STATE-VERIFICATION.md:15-20`. | closed |
| T-03-05 | Repudiation | Phase verification claims | mitigate | `03-STATE-VERIFICATION.md:11-39` separates executable tests, GPU readback, user-observed Mac/simulator behavior, and NOT TESTED iOS two-finger/physical-device behavior. `03-VALIDATION.md:55-63` records the evidence limits; no unobserved device result is reported as a pass. | closed |

*Status: open · closed. Disposition: mitigate (implementation required) · accept (documented risk) · transfer (third-party).*

---

## Accepted Risks Log

No accepted risks. The untested physical two-finger gesture and macOS 26 runtime cases remain explicitly NOT TESTED in `03-STATE-VERIFICATION.md`; this audit does not reclassify them as verified behavior.

---

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-09-25 | 5 | 5 | 0 | Inline retroactive STRIDE audit (configured auditor unavailable) |

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
