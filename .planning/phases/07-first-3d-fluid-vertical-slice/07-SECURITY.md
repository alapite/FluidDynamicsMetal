---
phase: "07"
slug: "first-3d-fluid-vertical-slice"
status: verified
# threats_open = count of OPEN threats at or above workflow.security_block_on severity (the blocking gate)
threats_open: 0
asvs_level: 1
created: "2026-11-20"
---

# Phase 07 — Security

> Per-phase security contract: threat register, accepted risks, and audit trail.
> This is a local, offline Metal simulator: no network, credentials or user data. Threats here are
> integrity (tampering), availability (GPU/resource failure) and repudiation (unsupported evidence
> claims) of the numerical and UI behaviour, as registered at plan time.

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| CPU oracle → contract/fixtures | Independent Double reference defines acceptance before kernels | Reference fields, tolerances, contract hash (non-sensitive) |
| Swift encoder → Metal kernels | Shapes, strides, uniforms and buffers handed to GPU | Simulation fields and solver status (non-sensitive) |
| Mode request → active resource/state commit | Entering/leaving 3D replaces GPU resource bundle | App state |
| GPU completion thread → MainActor UI/state | Async per-submission status returns to actor-isolated state | Solver status, generation tokens |
| Lifecycle callback → scheduled work | Minimize/deactivate/return gating step advancement | App state |
| Test results → evidence report | Recorded build/test/benchmark claims | Hashes, timings, host model/OS versions (no serials/UUIDs) |

---

## Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation | Status |
|-----------|----------|-----------|----------|-------------|------------|--------|
| T-07-01 | T | Numerical oracle | high | mitigate | Independent Double oracle; `test_quick_contract`, `test_reference_feasibility` | closed |
| T-07-02 | R | Contract/evidence | medium | mitigate | Contract hash, CPU-only labelling, `--check-contract` | closed |
| T-07-03 | T,D | VolumeField3D / ABI | high | mitigate | Checked shapes/strides/extents; `test_storage_and_abi` | closed |
| T-07-04 | T | Advection / walls | high | mitigate | Explicit reflection, old-generation reads; `test_advection_and_boundaries` | closed |
| T-07-05 | R | Harness/library | medium | mitigate | Fresh build, source/metallib hashes, production encoder only | closed |
| T-07-06 | T | D/G/A and nullspace | high | mitigate | Gauge/mean checks, manufactured fixtures; `test_operators`, `test_projection` | closed |
| T-07-07 | D,T | PCG/reductions | high | mitigate | Bounded iterations, true residual, failure latch, per-command status; `test_projection` negative cases (still green after 2026-11 solver fusion/gating) | closed |
| T-07-08 | T | Field generations | high | mitigate | Explicit pass order, full reset; `test_reset_and_finite` | closed |
| T-07-09 | T | Fixed slice/palette | medium | mitigate | Read-only fields, fixed scale; `test_slice_and_palette` | closed |
| T-07-10 | R,T | Claim of genuine 3D | high | mitigate | Full u/v/w/depth/nonplanarity metrics; `test_evolution_and_visibility` | closed |
| T-07-11 | T | SimulationState | high | mitigate | Explicit capabilities, guarded actions; Mac state tests | closed |
| T-07-12 | T | Mobile availability | medium | mitigate | iOS 2D-only list; `testExperimentMenuRemainsTwoDOnly` | closed |
| T-07-13 | D,T | Resource replacement | high | mitigate | Transactional bundle, forced failure/retry; `test_transitions_and_failures` | closed |
| T-07-14 | T | Step/lifecycle routing | high | mitigate | Encode-before-consume, inactivity fence; `test_renderer_steps_and_inactivity` | closed |
| T-07-15 | T,D | Async status/actor boundary | high | mitigate | Per-submission status, MainActor hop, generation tokens, fault latch; delayed-completion fixtures | closed |
| T-07-16 | T | Mode-row mapping | high | mitigate | Explicit identities, preserved shortcuts; `testThreeDGroupedNavigationAndTransport` | closed |
| T-07-17 | T,D | Focus/hidden controls | medium | mitigate | Guarded S, hidden groups removed from focus; `testThreeDPanelFocusAndReturn` | closed |
| T-07-18 | I,R | Error surface | medium | mitigate | Restore 2D before alert, local diagnostics only; `testThreeDInitializationFailureRestoresTwoD` | closed |
| T-07-19 | R | Results/performance | high | mitigate | Hashes/config/protocol, GPU vs display distinguished; `test_evidence_schema`, `--check-evidence` | closed |
| T-07-20 | I | Host metadata | low | mitigate | Model/versions only; grep of verification doc/evidence found no serial/UUID | closed |
| T-07-21 | R | Compatibility claims | medium | mitigate | PASS/FAIL/NOT TESTED/PENDING kept distinct in report | closed |
| T-07-22 | R | Visual closeout | medium | mitigate | 07-09 records manual review as NOT PERFORMED; no inferred approval | closed |

*Status: open · closed · open — below high threshold (non-blocking)*
*Severity: critical > high > medium > low — only open threats at or above workflow.security_block_on count toward threats_open*
*Disposition: mitigate (implementation required) · accept (documented risk) · transfer (third-party)*

---

## Accepted Risks Log

No accepted risks.

---

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-11-20 | 22 | 22 | 0 | gsd-secure-phase (L1, orchestrator; auditor skipped per short-circuit rule) |

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-11-20
