---
status: diagnosed
trigger: "3d-slice-weak-motion-and-depth (UAT 07 test 2 gap G-07-2): 3D Dye Advection slice takes ~40-50 steps to show noticeable motion; patch small and gives no convincing 3D depth impression"
created: 2026-11-20T21:20:00Z
updated: 2026-11-20T22:20:00Z
---

## Current Focus

hypothesis: CONFIRMED (multi-cause, AND-gate fired). See Resolution.root_cause.
test: production-solver scratch probe (scratchpad/probe/probe.swift) plus existing production GPU evidence.
expecting: n/a (diagnosis complete; goal find_root_cause_only)
next_action: return ROOT CAUSE FOUND to caller; no fix applied
bug_class: Bohrbug-class design/parameter deficiency (deterministic, reproduces every run; no code defect in solver/renderer)
reasoning_checkpoint:
  hypothesis: "Early motion is weak because the 0.12 seed-speed normalisation (0.128 cells/step at the single fastest cell) combines with a blob placed in the low-speed core (mass-weighted speed 0.505 of max) and a radius-0.12 blob (12.5-cell visible diameter) so 10 steps move the patch 0.44 cell; depth reads weak because the plane cuts the blob equator (dr/dz=0) while the blob drifts only 0.18 R in z, so the section footprint never changes."
  confirming_evidence:
    - "centroid drift 0.0515 cells/step measured vs 0.0545 cells/step predicted from mass-weighted mean velocity: solver transports at exactly the recipe speed (no hidden slowdown)"
    - "slice area(c>=0.1) 123 -> 123 -> 119 cells at steps 0/10/48 while peak 0.964 -> 0.807: only dimming, no footprint change"
    - "off-plane / larger-blob counterfactuals on the SAME production solver change the section footprint 102 -> 168 cells (zlow-r16) with no solver-regime change"
  falsification_test: "If a blob with an off-plane centre and the same speed did NOT change section area by >30% by step 48, the geometry hypothesis would be wrong (it did: +65%)"
  fix_rationale: "n/a (diagnose only); fix direction is recipe geometry/placement plus calibrated human-visible gates, with speed raised only outside the 1.6x-3.3x projection-gate band"
  blind_spots: "perceptual thresholds are inferred from the user's own 40-50-step report, not a controlled study; canvas pixel scale assumes a 700-1000 px viewport; the app's real-time orbit/tracer view was not exercised (user has the app open); Phase 8 tracer visibility not measured on screen"
  candidate_causes:
    - "code/config: recipe constants maximumVectorSpeed=0.12, blobCenter z=0.52, blobRadius=0.12 (confirmed)"
    - "process/data: preregistered visibility gates (RMS>=0.005, z-travel>=h/2 over 48 steps) satisfied at step 4 / step 15 while human threshold is step 35-46 (confirmed contributing)"
    - "design constraint: opaque single plane hides all other dye (inherent, not a defect; mitigated by Phase 8 tracers/camera, Phase 10 volume view)"
    - "environment: display/stepping pacing (eliminated)"
  and_gate: "yes - motion complaint needs speed AND placement AND weak gate calibration; depth complaint needs equatorial cut AND small slow blob AND single opaque sheet. No single parameter change fixes both (see Evidence on speed-only scaling)."

## Symptoms

expected: In the 3D Dye Advection lesson, the slice visibly changes shape within the first several steps, and the evolution reads as a cross-section through a tumbling 3D volume rather than a flat 2D animation.
actual: User reported: "The first thing I've noticed is that it takes many more than 5-10 steps to see noticeable movement of the dye patch - more like 40-50. The second issue is that the patch doesn't really give a convincingly 3d impression. It starts by taking relatively little of the cube volume, and during transformation it doesn't give strong depth cues to convince me that I'm not just viewing a 2d slice."
errors: None reported
reproduction: UAT Test 2. Mac app from current master: select 3D Dye Advection (paused, step 0, Z depth 50%), Step ~10 times, then Run 5-10 s (~60 steps/s; lesson completes at 600 steps).
started: Discovered during UAT 2026-11-20. Design/parameter question, not a crash.

## Eliminated

- hypothesis: Solver/renderer defect (stale texture, steps not advancing, mis-scaled dt) makes the dye slower than specified
  evidence: Probe's centroid drift 2.47 cells/48 steps (0.0515/step) matches mean-velocity prediction 0.0545 cells/step; probe step-48 slice RMS 0.0524 and peak 0.807 agree to 4 decimals with the integration fixture's evolution-visibility JSON. Mass 543.1 -> 538.3 at step 48 (-0.9%), no decay.
  timestamp: 2026-11-20T21:40:00Z

- hypothesis: Velocity damps away, so motion stalls
  evidence: Fixture velocityChange u/v/w = 0.23/0.21/0.16 of reset speed over 72 steps (evolving, not stalling); no damping term in encodeStep; blob keeps moving 19 slice-cells by step 600.
  timestamp: 2026-11-20T21:41:00Z

- hypothesis: Palette hides the early patch (low concentration invisible)
  evidence: area(c>=0.02)=141 vs area(c>=0.1)=123 cells at step 0 (only +13%); core is c~0.96 near-cream. Palette only matters late (when peak<0.1) - contributing to tail invisibility, not to the early-motion complaint.
  timestamp: 2026-11-20T21:42:00Z

- hypothesis: Display pacing, not simulation speed, causes the delay
  evidence: counter and probe use logical steps; the same 40-50-step threshold appears in step units in the probe independent of any display.
  timestamp: 2026-11-20T21:43:00Z

## Evidence

- timestamp: 2026-11-20T21:21:00Z
  checked: Sources/Shared/ExperimentRecipes3D.swift, docs/3d-numerical-contract.md, 07-RESEARCH.md
  found: maximumVectorSpeed = 0.12 domain-lengths per simulation-time unit; dt = 1/60; h = 1/64 -> peak 0.128 cells/step. blobCenter (0.42,0.48,0.52), blobRadius 0.12 (7.7 cells), compact bump exp(1-1/(1-s^2)). Research marks both numbers [PROPOSED]; "no readable window has been demonstrated in this research run"; calibration was a required evidence task.
  implication: Parameters were never tuned against a human-readable early window; the acceptance gates (RMS >= 0.005 at step 48, peak >= 0.05) are far below what a person perceives.

- timestamp: 2026-11-20T21:22:00Z
  checked: .build/fluid3d-evidence/evolution-visibility.json (production GPU run on Apple M3 Pro, current source)
  found: slice RMS vs step 0: step1 0.0013, step24 0.0294, step48 0.0524, step72 0.0693. Peak 0.964->0.882->0.807->0.771. Slice samples >=0.02: 141, 143, 157, 169, 177 of 4096. Dye centroid (0.420,0.480,0.520) -> step48 (0.4406,0.4558,0.5418) = 1.32,-1.55,1.40 cells (|d|~2.4 cells in 48 steps = 0.05 cell/step).
  implication: Centroid drifts ~0.05 cells/step; blob support diameter ~13 cells; consistent with ~40-50 steps to a visible change.

- timestamp: 2026-11-20T21:40:00Z
  checked: scratch probe (scratchpad/probe/probe.swift, compiles production Sources/Shared/*3D* + MetalDevice, runs real FluidSimulation3D on the app's default.metallib; no repo files changed). Baseline recipe, 600 production steps.
  found: global seed max speed 0.120 (=0.128 cells/step); dye-mass-weighted mean speed at the blob 0.0606 (0.065 cells/step, = 0.505 of global max); mean velocity vector at blob (0.0167,-0.0330,0.0352), |.|=0.0511 (0.0545 cells/step). Whole-volume mean speed 0.0307, median 0.0183. Slice (planes 31/32 avg): visible patch area(c>=0.1)=123 of 4096 cells (3.0%), diameter ~12.5 cells; slice shift of patch centroid 0.22/0.44/1.05/2.11 cells at steps 5/10/24/48; RMS vs step0 0.0065/0.0129/0.0294/0.0524; peak 0.964/0.931/0.882/0.807; area(c>=0.1) 123/123/123/119 (shape footprint unchanged); pixels changed >=32/255: 6/41/100/134 cells.
  implication: step 10 moves the patch 0.44 cell (~2-3 px on screen); ~2 cells (user's "noticeable") needs ~48 steps -> matches the UAT report exactly.

- timestamp: 2026-11-20T21:45:00Z
  checked: Camera3D/InspectionState3D defaults + tracer seed kernel
  found: default camera yaw 25 deg, elevation 18 deg, 40-degree vertical FOV perspective, zoom 100%: unit cube spans ~0.49 of viewport height per unit length -> blob (c>=0.1 diameter ~0.2 domain) is ~10% of canvas height (~0.7% of canvas area). Tracers are an 8x8x8 lattice over the whole cube, advected by the same slow flow (volume median 0.0195 cells/step).
  implication: depth cues from tracers/parallax suffer from the same slow-speed cause; sheet content itself is a 2D function.

- timestamp: 2026-11-20T21:50:00Z
  checked: z geometry of the recipe vs plane
  found: blobCenter z=0.52 vs plane 0.5 (offset 0.02 = 0.17 R), so plane cuts almost the equator; section radius r=R*sqrt(1-(dz/R)^2) is stationary at the equator (dr/dz=0). z-centroid moves only +1.40 cells (0.18 R) by step 48 -> disc radius changes ~1.6%. Measured: net dye mass crossing Z=0.5 plane: fraction of mass above plane 0.673 -> 0.760 (24) -> 0.810 (48) -> 0.832 (100); slice (2 cells) holds only 12.7% -> 9.6% of dye mass. 3D-vs-2D-in-plane-counterfactual slice RMS ratio ~0.54-0.58 but dominated by peak dimming (3D peak 0.807 vs 2D-advected 0.938 at step 48), i.e. reads as fading not depth.
  implication: slice content differs from a pure 2D animation, but the difference is a uniform dimming; no shape appears/disappears -> no depth read.

- timestamp: 2026-11-20T21:55:00Z
  checked: probe speed scaling x1.5..x6 (same blob), production solver, 600 steps; inputDT (pre-projection divergence) vs contract 1000x reduction rule
  found: inputDT scales ~speed^2 (baseline max 3.79e-4; x1.5 8.5e-4; x2 1.52e-3). Contract/gate (Shaders3D.metal:1468-1470) requires 1000x reduction only when inputDT >= 1e-3. Solver stops near ~1e-6 absolute, so reduction ~ inputDT/1e-6. x3 FAILED at step 164: inputDT=1.0125e-3, projectedDT=1.017e-6 -> reduction 995.3 < 1000 -> finalAcceptanceFailed latch (needs reset). x2 min reduction 1088; x2.5 min 1015; x4 min 1787; x5 min 2853. At baseline speed the reduction gate is never active (inputDT 1.1e-4..3.8e-4).
  implication: raising seed speed is NOT a free parameter: speeds > ~1.6x enter the regime where the 1000x gate is active and can trip a cliff just above 1e-3; do not loosen the gate - need an in-solver margin or choose a speed outside the band.

- timestamp: 2026-11-20T21:58:00Z
  checked: speed scaling vs 600-step visibility (same blob r=0.12)
  found: peak at step 300 / 600: x1 0.538 / 0.145; x2 0.144 / 0.046; x4 0.050 / 0.023 (area c>=0.1 = 0 from step ~200). Step-10 slice shift: x1 0.44, x2 0.87, x3 1.31, x4 1.75, x6 2.62 cells.
  implication: with this blob/flow, readable-by-step-10 (>=~2 cells) needs ~x6, and dye is invisible by step ~100-200; speed alone cannot give early motion AND 600-step visibility. Baseline itself is already marginal late (peak 0.145 at 600).

- timestamp: 2026-11-20T22:00:00Z
  checked: gate calibration - baseline CSV vs preregistered gates (docs/3d-numerical-contract.md:110-117; Tests/Integration/test_fluid3d.swift:3687-3693,3714)
  found: preregistered slice-RMS gate 0.005 is first met at step 4; z-travel gate (h/2) at step 15; the user's perceptual threshold lies at RMS 0.035-0.052 (steps 35-46; patch shift 1-2 cells). The gates are evaluated at steps 24/48, not at the 5-10-step window the UAT expects.
  implication: the recipe passed every preregistered gate while being ~10x below human visibility; D-09 "readable early transport" was never operationalised.

- timestamp: 2026-11-20T22:05:00Z
  checked: candidate recipe variants on the production solver (600 steps each; columns: scenario speed-scale, centre, radius -> rms@10, slice shift@10 cells, section area c>=0.1 @0/@48 cells, peak@10/48/300/600, area@300/600)
  found: baseline x1 (.42,.48,.52) r.12: 0.0129, 0.44, 123/119, pk 0.93/0.81/0.54/0.145, area 113/43.
         r.16 same centre: 223/218 (no footprint change); r.24: 513/506.
         zlow x1 (.42,.48,.40) r.12: section 5 -> 82 cells, peak 0.22 -> 0.59 (dye enters plane; weak start).
         zlow-r16 x1 (.42,.48,.40) r.16: 102 -> 168 cells (+65%), peak 0.58 -> 0.78 -> 0.90@100; area 173/37 @300/600; 3D-vs-2D counterfactual ratio 1.12 (vs 0.58 baseline).
         zlow-s1.6-r16: rms@10 0.019; 86 changed cells >=32/255 @10; 102 -> 196 cells.
         fast-region x1 (.68,.44,.46) r.12: mass-weighted mean |v| 0.107 (2.1x baseline) with the SAME global seed max, so no change to inputDT/projection regime; blob leaves the plane (106 -> 14 cells @48) and returns late (37 cells @600); RMS>=0.05 at step 21 instead of 46.
         x4 r.20 centre z .52: rms@10 0.044, shift 1.57; area 352 -> 307; peak 0.94/0.90/0.17/0.08; area@300 59, @600 0.
         x4 zlow (.42,.48,.38) r.20: rms@10 0.048 (= baseline step ~46), 193 changed cells @10, section 175 -> 335 cells (+91%), peak 0.76 -> 0.85; but pk@300 0.17, area@300 93, @600 35 (wisps along walls).
  implication: depth cue is fixed mainly by geometry (off-plane centre + larger radius), early motion by speed and/or flow-placement; speed-only fix kills late visibility; every variant keeps the same solver/oracle code.

- timestamp: 2026-11-20T22:10:00Z
  checked: which fixtures consume the recipe (grep) and what would need regenerating
  found: independent CPU oracle/reference fixtures (operators, projection, advection-boundaries, reset-finite 600-step soak, one-step reference) use their own reference inputs (reference["u_input"] etc.), NOT ExperimentRecipes3D, so they are unaffected by recipe constants. Recipe-dependent: test_fluid3d.swift evolution-visibility (hard-coded centroid (0.42,0.48,0.52)+-0.02 at :3551-3554, probe seeds :3564, recipe dictionary :3733-3744, support<1/10 :3547, single component :3555, peak>=0.5 :3543, visibility gates :3687-3693), benchmark seed hash (computed), and the Phase 8 production-vs-production schedule/tracer/routing fixtures (use default reset). The 600-step soak does NOT run the lesson recipe (only evolution-visibility runs it, for 72 steps); my probe ran the shipped recipe 600 steps clean (max 129 PCG iterations).
  implication: changing recipe constants = update those literals/gates, rerun full python3 Tests/Integration/test_fluid3d.py plus the Phase 8 inspection evidence CLI/reports (source+metallib hashes become stale for any Sources change, as 07-VERIFICATION warning 3 already notes). Contract prefix (hash a7768571...) is not touched; stronger/added visibility gates belong in an amendment appended after the END PREREGISTERED CONTRACT marker. No tolerance (1e-5 residual/divergence, 1000x reduction, cap 320, 1e-10 Double, 2e-5+2e-4 Float) needs loosening.

- timestamp: 2026-11-20T22:15:00Z
  checked: gate-exposure scan, speeds x1..x6 (same velocity evolution regardless of blob): min reduction over steps with inputDT>=1e-3
  found: inputDT ~ speed^2 crosses 1e-3 at ~x1.62. x1 and x1.5: gate never active. x1.75 min 1026; x2 1088; x2.25 1007; x2.5 1015; x2.75 1024; x3 995 FAIL (step 164, hard latch finalAcceptanceFailed); x3.25 1179; x3.5 1372; x3.75 1596; x4 1787; x4.5 2292; x5 2853; x6 4062. Gate code: Shaders3D.metal:1468-1470; internal stop min(1e-5 h^2/dt, 1e-6) at :774 leaves projected divergence ~1.0e-6 on every step.
  implication: 1.6x <= speed <= ~3.3x is a latent cliff where the preregistered 1000x reduction rule can fail by a few percent; safe speeds are <=1.6x or >=3.5x unless the solver is given margin (continue PCG until reduction >= ~1500x when input>=1e-3) - without loosening the gate.

- timestamp: 2026-11-20T22:18:00Z
  checked: Sources/macOS/RenderViewController.swift:50 (panel note), Sources/Shared/Shaders3D.metal fluid3DSpatialSlice, InspectionState3D defaults
  found: the sheet is opaque ("Tracers behind the opaque slice are hidden, even where the slice is black"); default camera yaw 25 deg / elevation 18 deg (Phase 8), so the user sees a small amber dot on a tilted dark sheet inside a wireframe cube. Tracers are 512 markers on an 8x8x8 lattice moving at the same slow flow (volume mean speed 0.033 cells/step, median 0.020).
  implication: the most direct 3D cue (parallax of tracers / seeing dye in front of and behind the plane) is also throttled by the speed cause and by the opaque-sheet design (inherent until the Phase 10 transparent volume view).

- timestamp: 2026-11-20T22:25:00Z
  checked: gate-safe (global scale x1.6, solver regime unchanged) candidates that move the blob into the faster part of the flow and make it cross the plane (production solver, 600 steps, max 146 PCG iterations, no projection failure)
  found: fp1 centre (0.68,0.44,0.58) r0.16: rms@5/10/24 0.018/0.033/0.060, RMS>=0.05 at step 18, 155 cells changed>=32/255 @10, section 147->190@10->229@48 cells, step-0 slice peak 0.71, then leaves plane (8 cells @300) and returns (83 @600).
         fp2 centre (0.68,0.44,0.62) r0.18: rms@10 0.039, RMS>=0.05 at step 14, 184 changed cells @10, section 106->171@10->230@24->274@48 (2.6x) and peak 0.44->0.83@10->0.91@24, empty at 300, 104 cells @600; step-0 slice peak 0.44 (< contract's 0.5 candidate gate).
         fp3 centre (0.62,0.44,0.58) r0.18: rms@10 0.027, RMS>=0.05 at 22, section 206->291@48, step-0 peak 0.78, 55 cells @300, 105 @600.
         Baseline for comparison: rms@10 0.013, RMS>=0.05 at step 46, section 123->119.
  implication: moving the blob to the faster flow region + an off-plane start so the flow carries it through the slice gives a readable-by-step-10..18 change with a real section-growth depth signature without touching the solver regime or any tolerance; trade-off is that dye leaves the plane for part of the 600-step lesson (allowed by D-09 if explained) and the step-0 slice peak must stay >= 0.5 (contract candidate gate).

## Resolution

root_cause: |
  Not a solver/renderer defect. Two uncalibrated Phase-7 recipe choices plus one inherent design limit, with weak acceptance gates letting it ship:
  (1) SLOW EARLY MOTION: ExperimentRecipes3D normalises the seed so the single fastest cell moves 0.12 domain-lengths per time unit = 0.128 cells/step (dt=1/60, h=1/64). The blob (centre (0.42,0.48,0.52)) sits near the circulation's low-speed core: mass-weighted mean speed 0.065 cells/step (0.505 of max), actual centroid drift 0.052 cells/step, versus a visible patch ~12.5 cells across (c>=0.1 area 123 of 4096 cells; sphere 0.72% of the cube, ~0.2% at full-concentration equivalent). Step 10 therefore moves the patch 0.44 cell (~2-3 px at ~5.4 px/cell in the default perspective view); the ~2-cell / RMS 0.05 change the user calls noticeable first occurs at step ~46 (RMS 0.035 at step ~35). Matches the UAT report (40-50 steps).
  (2) WEAK DEPTH CUE: the plane z=0.5 cuts the blob almost at its equator (centre z 0.52, offset 0.17 R), where the section radius r=R*sqrt(1-(dz/R)^2) is stationary, and the blob drifts only 1.4 cells (0.18 R) in z by step 48. Measured: section footprint 123 -> 119 cells, only the peak dims 0.964 -> 0.807; ~14% of dye mass crosses the plane by step 48 but the slice holds just 9.6-12.7% of the mass. So the slice behaves like a fading 2D disc, not a section through a tumbling object. This is compounded by the opaque single sheet (inherent: everything off-plane is hidden; Phase 10 volume view is the real remedy), a tiny patch (~10% of canvas height), tracers moving at the same slow speeds (median 0.020 cells/step), and a long thin comet tail that is nearly invisible under the linear black->amber palette once c<0.1.
  (3) PROCESS: the preregistered visibility gates are ~10x weaker than human visibility (slice RMS >=0.005 is met at step 4, z-travel >=h/2 at step 15, evaluated at steps 24/48) and no human-readable early window was ever calibrated (07-RESEARCH marks 0.12 and r=0.12 [PROPOSED], "no readable window demonstrated"; D-09 never operationalised).
  CONSTRAINT FOUND ON ANY FIX: raising seed speed alone cannot satisfy both early visibility and 600-step visibility (x4, r=0.12: dye gone by step ~100-200; x2: peak 0.144 at step 300), and speeds between ~1.6x and ~3.3x of the current seed enter a regime where the preregistered 1000x divergence-reduction rule is active and can fail by a few percent: x3 hard-failed at step 164 (inputDT 1.0125e-3, projected 1.017e-6, reduction 995.3 < 1000, finalAcceptanceFailed). x<=1.6 or x>=3.5 avoid it; x3.5+ has min reduction >=1372.
fix: ""
verification: ""
files_changed: []
