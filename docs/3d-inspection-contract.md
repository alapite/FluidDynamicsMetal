# 3D Inspection Contract

Preregistered Phase 8 foundation, before production inspection outputs. This
document fixes expectations, not a GPU/UI PASS. The immutable Phase 7 numerical
contract is unchanged: complete-file SHA-256
`5fdc33b839d7f135a828ac9e6e3c3b4e7adba03d5341771ddbed4b13767951a8`,
prefix SHA-256 `a7768571a996d5b9520aff5095100bb52fb67f96560f99633d081c04a3a9e01b`.
The standalone oracle and Python checker pin the entire UTF-8 inspection document.
Any amendment requires review and explicit repinning before accepting results.

## Coordinates and slices (D-07, D-09–12)

World is [0,1]³: +X right, +Y up, +Z into the front reference view.
Column vectors use a left-handed view, `clip = projection * view * world`.
NDC Y remains up; exactly one top-left raster conversion occurs at viewport
mapping: `(x,y) = ((ndc.x+1)*width/2, (1-ndc.y)*height/2)`.
Never flip texture UVs again or auto-face/cull the backside of the sheet.

Plane raw values are XY=0, XZ=1, YZ=2. Sheet-local `(s,t)` maps to
XY(s,t,d), XZ(s,d,t), YZ(d,t,s), with one continuous shared `d=percentage/100`.
Default is XY, d=0.5, tracers on. Finite depth clamps 0…1, NaN/Inf edits
are ignored. Plane changes preserve depth and camera. Centre Slice changes
only depth to 0.5. UI rounding never quantizes stored depth.
Sample cell-centred dye by trilinear interpolation at
`clamp(world * dimensions - 0.5, 0, dimensions - 1)`.
On 64³, 50% averages depth planes 31/32 equally; endpoints extend nearest
centres. Independent fixtures use `C=.1+.2*x+.3*y+.4*z` and unequal
landmark ramp `7*x+19*y+43*z` at s=.23,t=.67 and d=0/.3/.5/1.
The sheet is opaque even when black; never maximum/average project the volume.

## Camera and guides (D-01–08)

Orbit about centre (.5,.5,.5), no roll/pan/inertia. Defaults yaw=25°,
elevation=18°, zoom=100%. Slider yaw clamps −180…180 (keep +180 at the
thumb); gesture yaw wraps across the seam. Elevation clamps ±75°; zoom
clamps 50…150%. All setters ignore nonfinite edits, including gesture deltas.
Reset Camera changes camera only. Invalid/zero/nonfinite viewport defers frame
construction without mutating stored state; reject nonrepresentable matrices.

For full viewport aspect a=width/height, r=sqrt(3)/2,
alpha=atan(tan(20°)*min(1,a)), fittedDistance=1.10*r/sin(alpha),
distance=max(r+0.10,fittedDistance/(zoom/100)). Camera offset is
distance*(sin(yaw)*cos(elevation),sin(elevation),-cos(yaw)*cos(elevation)).
Forward points from eye to centre, right=normalize(cross(worldUp,forward)),
up=cross(forward,right). Vertical FOV=40°, near=0.05,
far=distance+r+1; Metal depth is 0…1, near→0 and far→1.
Projection is column-vector projection*view; X scale=cot(20°)/a,
Y scale=cot(20°), zClip=far/(far-near)*zView-near*far/(far-near),
wClip=zView. A 100% fit encloses all eight cube corners for every usable
aspect; resize/backing scale changes fit, not stored pose or experiment.
Guide axes use rotation-only `(dot(axis,right),dot(axis,up),dot(axis,forward))`,
not translation, perspective divide or zoom. Preserve projected foreshortening.

Plain drag: rightward yaw/upward elevation +0.30° per AppKit point.
Positive normalized zoom input: magnification*=exp(delta/240) for precise
scroll, exp(delta/12) for discrete wheel; direction normalized once, horizontal
scroll ignored. Slider keyboard increments yaw5°, elevation3°, zoom5 points.
These future event/UI integrations are not delivered by the foundation types.

Always draw all 12 cube edges as a guide-only overlay, 1 pt #666666,
including back edges. Bottom-left hit-transparent guide: 16 pt inset, 64×64 pt,
positive-axis nominal length20 pt, stroke1 pt, labels11 pt #A6A6A6; separate
overlapping labels without changing axis directions. Increase Contrast:
cube #A6A6A6, guide #D9D9D9. Guide never receives focus. No Guides toggle,
walls, floor, grid or decorative lighting. The guide-only overlay is not
permission for X-ray markers. AppKit points convert once to drawable pixels.

## Passive tracers (D-13–16)

Exactly 512 seeds, k outermost, j next, i fastest, on 8³ lattice:
`float4((i+.5)/8,(j+.5)/8,(k+.5)/8,1)`. SIMD4 lane w=1 exactly.
For logical n→n+1 use newly projected V[n+1], never V[n] or dye's negative
backtrace: `m=clamp(p+dt/2*V[n+1](p),0,1)`,
`pNext=clamp(p+dt*V[n+1](m),0,1)`, dt=1/60.
Reconstruct u/v/w on their staggered MAC lattices using production reflected
interpolation: fold positions modulo2 into the cube, odd normal/even tangential
parity, exact exterior normal-face zeros, reflected tangential ghost centres.
Clamp midpoint/final position, no reseeding, feedback, dye deposit or force.
Only accepted logical steps advance, once even hidden or without drawable;
failed projection/session latch blocks advancement. Paused redraw advances none.
Independent Double oracle imports no production or Metal, covers ±XYZ, unequal
combined signs, affine MAC reconstruction and all wall/edge/corner reflections.

Draw constant #B8F2FF unlit discs, 3 pt diameter converted once for backing
scale, no trails/glow/speed encoding/size attenuation. Sheet and discs share
worldToClip and depth32Float cleared1, lessEqual depth test; opaque sheet writes
depth including black regions. Disc outside fragments discard without blocking
depth; no backface culling on sheet. Behind-sheet markers inside footprint are
hidden, outside-footprint markers eligible; opposite-side orbit reverses
occlusion. Visibility changes drawing only; hidden advancement is identical.

## Finite-first acceptance and complete inventory (D-19, D-21)

Reject nonfinite values before any tolerance arithmetic. GPU/oracle tolerance:
`2e-5 + 2e-4*abs(reference)`; palette ±1 UNORM code (non-sRGB encoded-channel
piecewise-linear black/#ED8B23/#FFF1D6 at concentration0/.5/1).
Same-device equal-step fluid/tracer absolute tolerance `2e-6`; exact seeds,
discrete flags, normal-wall zeros. Paused evolution resources must be
byte-identical, not merely approximately equal. Do not relax the 320 pressure
cap, either 1e-5 projection gate, 1000x reduction or Phase 7 identity amendments.

Read-only, queue-ordered snapshots enumerate names, shapes, byte lengths, data,
generation roles and counters for **every** evolution allocation:

- Both ping/pong generations of u, v, w, dye and transported u/v/w.
- Divergence; compensated pressure high/low and both generations; all pressure
  RHS/residual/preconditioned residual/search/operator/scratch generations.
- Entire reduction workspace (not merely its finite summary).
- Simulation failure latch AND projection standalone failure latch.
- Every retained status slot, its ownership metadata and optional iteration
  trace allocation when enabled, not just the latest scalar success flag.
- Every tracer position ping/pong and scratch buffer, seed/count/lane schema.
- Fixed grid/h/dt/solver configuration; simulation/session generation roles,
  encoded/consumed/completed logical steps, pending accepted steps/input,
  pause intent, inactivity/cap/failure flags and renderer diagnostic counters.

Match inventory against actual allocation names/lengths; missing or extra
evolution resources fail. No silently omitted inaccessible/private resources.
Presentation depth/color/vertex/uniform resources are separately classified,
never mistaken for numerical evidence. Process-local allocation addresses and
session tokens are retained exactly within paused comparisons, but unrelated
fresh sessions need not have identical addresses/tokens. Equal-step comparisons
require semantic configuration/generation roles/counters/status, with explicit
normalization only of process-local identity, never numerical/discrete state.

Preregister independent paired runs at steps0/1/24/48: all plane/depth values,
front/back/edge-on camera, 50/100/150% zoom, 320×240 points, wide/tall canvases,
1×/2× backing scales, varying render counts, visible/hidden/alternating markers,
nil drawable and zero viewport. Paused batches compare complete before/after
bytes and demonstrate positive image/matrix changes. No drawable/zero viewport
is not resource failure and never suppresses accepted evolution.

Inject initial/active tracer allocation/reset/encode, depth/pipeline allocation,
projection failure and delayed/stale completion failures. Candidate entry/reset
must validate before publishing; failed active presentation safely restores
usable 2D Free Play before actionable alert, never fake-success 3D. Restart
resets complete evolution/pending work to paused step0 but preserves inspection.
Reset Camera and Centre Slice preserve every experiment field, pending step,
counter, latch and tracer; foundation values own no evolution resources.

## Evidence limits

Foundation oracle/state/matrix tests do not complete INS-01/02/03/04 or CTRL-08.
Production GPU, routing, native controls and human review remain later plans.
No FPS claim: displayed pacing NOT MEASURED; actual macOS26 and physical-device
multitouch NOT TESTED. Phase 7 unperformed manual acceptance stays pending.
Preserve the established 2D solver, shader names and Swift/Metal ABI unchanged.
