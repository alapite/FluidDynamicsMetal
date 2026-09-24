---
phase: 02
slug: modern-ios-parity
status: verified
threats_open: 0
asvs_level: 1
created: 2026-09-24
---

# Phase 2 — Security

> Per-phase security contract: threat register, accepted risks, and audit trail.

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| UIKit touch events → shared renderer → Metal uniform buffer | Local touch count, identity and coordinates are supplied by the platform and must fit each GPU submission. | Touch positions and impulses; no network, persisted content or credentials. |

## Threat Register

| Threat ID | Category | Component | Disposition | Mitigation | Status |
|-----------|----------|-----------|-------------|------------|--------|
| T-02-01 | Tampering / availability (out-of-bounds write) | iOS touch forwarding and shared Swift/Metal contact uniforms | mitigate | `RenderViewController.swift` tracks `UITouch` identities and submits a complete snapshot without raw `malloc`/`memcpy` (`70–135`). `Renderer.swift` bounds each write with `prefix(ContactCapacity)` (`156–173`), initializes ten slots (`141–146`), and batches contacts beyond ten in separate force passes (`325–346`); `Shaders.metal` declares and iterates ten slots (`50–59`, `92–104`, `118–131`). End/cancel removes affected contacts (`107–125`), and each uniform write clears positions, impulses and scalar impulse before filling active slots (`156–159`). Source-backed; physical multi-touch remains untested per `02-PARITY.md`. | closed |

The other two plan-time threat-model blocks identify no additional external threat IDs. Plan 03's evidence-integrity concern is handled by the explicit `NOT TESTED` rows for unobserved two-finger, device-only multi-touch, stroke comparison and macOS 26 runtime in `02-PARITY.md`; no unobserved result is treated as verified here. None of the three summaries contains a `## Threat Flags` entry.

## Accepted Risks Log

No accepted risks.

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-09-24 | 1 | 1 | 0 | OpenCode (source review) |

## Security Audit 2026-09-24

| Metric | Count |
|--------|-------|
| Threats found | 1 |
| Closed | 1 |
| Open | 0 |

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log (none)
- [x] `threats_open: 0` confirmed against source
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-09-24 (source-backed mitigation; device-only behavior not tested)
