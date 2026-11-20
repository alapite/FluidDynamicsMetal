---
phase: 07
review: 07-REVIEW.md
titles: json
findings:
  - id: WR-01
    severity: warning
    disposition: open
    title: "Numerical contract still states a zero initial guess; production warm-starts and uses extra stop criteria not in the contract"
  - id: WR-02
    severity: warning
    disposition: open
    title: "Production advection kernels (`*Guarded`) are not the code the advection and full-volume oracle tests run"
  - id: WR-03
    severity: warning
    disposition: open
    title: "Hidden `gatingIteration` mode flag leaves unreachable gated branches in `PressureProjection3D` after the fusion"
  - id: WR-04
    severity: warning
    disposition: open
    title: "Spatial reference export subprocess depends on the working directory"
  - id: WR-05
    severity: warning
    disposition: open
    title: "Necessity (already-defended-elsewhere): `DepthAttachmentRetention` duplicates Metal's default retained references"
  - id: IN-01
    severity: info
    disposition: open
    title: "Necessity (impossible-state guard): `modeTransitionInProgress` is never observable as `true`"
  - id: IN-02
    severity: info
    disposition: open
    title: "Write-only scratch store in the fused preconditioner-dot pass"
  - id: IN-03
    severity: info
    disposition: open
    title: "Test-only and unused production API ships in the app"
  - id: IN-04
    severity: info
    disposition: open
    title: "Cross-language constants duplicated with no ABI or consistency check"
  - id: IN-05
    severity: info
    disposition: open
    title: "File-scope `#pragma clang fp` changes numerics for every kernel below it"
  - id: IN-06
    severity: info
    disposition: open
    title: "Silent early returns followed by presenting an unrendered drawable"
  - id: IN-07
    severity: info
    disposition: open
    title: "`restartCurrentSimulation` hard-codes the 3D mode"
  - id: IN-08
    severity: info
    disposition: open
    title: "`StatusSlot.diagnostics()` can trap, or map a NaN failure code to `.none`, on a corrupt status buffer"
  - id: IN-09
    severity: info
    disposition: open
    title: "Stale CPU \"replay\" diagnostic and misleading test text"
  - id: IN-10
    severity: info
    disposition: open
    title: "Hand-maintained Swift source lists and an evidence invariant that no longer matches the live pipeline"
  - id: IN-11
    severity: info
    disposition: open
    title: "Weak or fragile test assertions"
  - id: IN-12
    severity: info
    disposition: open
    title: "Minor lifecycle and debug artefacts"
open: 17
total: 17
recorded: 2026-11-20T19:39:40.182Z
---

# Phase 07: Code Review Disposition

| Finding | Severity | Disposition | Source |
|---------|----------|-------------|--------|
| WR-01 | warning | open | - |
| WR-02 | warning | open | - |
| WR-03 | warning | open | - |
| WR-04 | warning | open | - |
| WR-05 | warning | open | - |
| IN-01 | info | open | - |
| IN-02 | info | open | - |
| IN-03 | info | open | - |
| IN-04 | info | open | - |
| IN-05 | info | open | - |
| IN-06 | info | open | - |
| IN-07 | info | open | - |
| IN-08 | info | open | - |
| IN-09 | info | open | - |
| IN-10 | info | open | - |
| IN-11 | info | open | - |
| IN-12 | info | open | - |

Dispositions: `open` (recorded, not yet triaged), `fixed`, `skipped`, `deferred`.
Set `deferred` by hand and put the reason in the Source cell; both are preserved. A `|` in the reason is kept as prose and escaped on the next run.
Re-running the gate keeps every row it can. A row the current review no longer reports is kept and its Source cell flagged, so a finding does not leave this record silently. ONE exception: when a finding id is REUSED by a different finding, the earlier decision cannot keep a row — the id is taken — and it is dropped. A RECORDED decision (anything but `open`) is named on the console when that happens; a row still at `open` is replaced silently, because `open` records no decision to lose.
