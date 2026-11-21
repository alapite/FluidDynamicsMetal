# 3D Fluid Numerical Contract

**Status:** Preregistered for the first 3D kernel implementation. This contract fixes the numerical comparison before any 3D production kernel or GPU result is accepted. The CPU Double oracle is still pending at this point; no GPU PASS or measured lesson result is claimed here.

**Scope:** The fixed 64³, closed-box, dimensionless MAC-grid dye-advection experiment. This is an educational numerical contract, not calibrated physical time or scientific-grade accuracy. Changes to the established 2D solver and its Swift/Metal ABI are out of scope.

## Coordinates, Layout, Units, and Precision

- The domain is the unit cube `[0,1]³`, with X increasing right, Y increasing up, and Z increasing into the volume. `N=64`, `h=1/64`, and one logical advance uses `dt=1/60` dimensionless simulation-time units. A step is not a display frame or a physical second.
- Cell-centred dye `C` and pressure correction `q` have shape `(Nx, Ny, Nz) = (64,64,64)` and sample coordinates `((i+1/2)h,(j+1/2)h,(k+1/2)h)`. X is the fastest-varying coordinate: `index(i,j,k) = (k*Ny + j)*Nx + i`.
- Face-centred velocity uses three independent arrays, in `(x,y,z)` array order: `u: (65,64,64)` at `(i*h,(j+1/2)h,(k+1/2)h)`; `v: (64,65,64)` at `((i+1/2)h,j*h,(k+1/2)h)`; `w: (64,64,65)` at `((i+1/2)h,(j+1/2)h,k*h)`. Each array is x-fastest. Its normal coordinate includes both boundary faces.
- Velocity is in domain-lengths per simulation-time unit; divergence is per simulation-time unit; dye is a dimensionless concentration clamped to `[0,1]` for the lesson; `q=dt*p/rho` is the pressure correction scaled by timestep and density. No physical-pressure or real-time interpretation is exposed.
- The GPU candidate uses Float32 for every field, scratch value, uniform lane, and reduction input. The independent CPU oracle uses Double and independently formed loops. The first 3D compute ABI is exactly three aligned 16-byte lanes (48-byte stride): lane 0 `uint4(gridNx, gridNy, gridNz, operationID)` at byte offset 0; lane 1 `float4(h, dt, inverseH, scalarScale)` at offset 16; lane 2 `uint4(outputWidth, outputHeight, outputDepth, componentID)` at offset 32. Swift uses `SIMD4<UInt32>`, `SIMD4<Float>`, `SIMD4<UInt32>` in that order; Metal uses `uint4`, `float4`, `uint4`. Compile-time/runtime assertions must verify offsets `0/16/32`, alignment `16`, stride `48`, and an asymmetric round-trip before GPU acceptance. Do not append padded `SIMD3` or change `StaticData`, `BufferData`, or any 2D shader entry point.

## Compatible MAC Operators and Closed Walls

For cell `(i,j,k)`, with boundary face velocities included,

```text
D u = (u[i+1,j,k]-u[i,j,k] + v[i,j+1,k]-v[i,j,k]
       + w[i,j,k+1]-w[i,j,k]) / h.
```

`Gq` is defined only on interior faces: for example `Gx q[i,j,k]=(q[i,j,k]-q[i-1,j,k])/h` for `1 <= i < Nx`; analogous differences apply in Y/Z. The normal gradient on either exterior wall face is exactly zero. `D` and `G` use the same face/cell locations and this same boundary convention.

```text
A = -h² D G
b = -h² D u*
Aq = b
uNew = u* - Gq
r = b - Aq                 # recomputed true residual, not only recursive PCG residual
D uNew = -r/h²             # compatible identity, up to floating-point roundoff
```

Applying `A` independently as a neighbour stencil gives `degree*qCenter - sum(qInteriorNeighbours)`. The diagonal degree is 6 in the interior, 5 on a face, 4 on an edge, and 3 at a corner. Constants are the sole pressure gauge null mode on this connected grid. The independently looped `-h² D(Gq)` and this stencil must agree in Double to absolute `1e-10` on normalized fixtures, including all faces, edges, and corners.

All six walls are impermeable and free-slip. At every completed velocity generation, `u(0,j,k)=u(Nx,j,k)=0`, `v(i,0,k)=v(i,Ny,k)=0`, and `w(i,j,0)=w(i,j,Nz)=0` exactly. Enforce these values before divergence and after projection. No periodic wrap, inflow, open boundary, obstacle, or pressure Dirichlet condition is used.

Advection uses reflected extensions, not periodic sampling. Reflect a coordinate into `[0,1]` by folding it modulo two; each reflection across an axis changes the sign only of the velocity component normal to that wall. Tangential velocity components are even. Scalar dye is even across every face (zero normal derivative). At edges and corners, apply the three independent axis reflections compositionally; signs multiply, and wall-normal face values remain exactly zero. RK2 midpoint and departure positions are clamped component-wise to the unit cube; interpolation of a query requiring ghost values uses the just-defined reflection rule. A face component is interpolated on its own staggered lattice; dye is interpolated on the cell-centred lattice.

## Step Definition and Advection

One logical advance is ordered as follows; every output component reads the same completed old velocity generation:

1. Backtrace and trilinearly self-advect `u`, `v`, and `w` independently with midpoint RK2 using the old reconstructed MAC velocity. Do not swap any component generation until all three have been written.
2. Enforce all six normal-wall zeros.
3. Compute cell divergence, solve the compatible pressure-correction system, subtract its face gradient, then enforce the six wall zeros again.
4. Backtrace and trilinearly advect dye using this newly projected velocity. Do not add dye, decay, explicit damping, vorticity confinement, or force during this lesson.

For any transported sample at location `x`, define `V(x)` by trilinearly reconstructing each MAC component on its own lattice. `xMid = clamp(x - 0.5*dt*V(x))`; `xBack = clamp(x - dt*V(xMid))`; sample the old transported field at `xBack`. Reset initializes both ping/pong generations, all pressure/reduction/status scratch, and exact wall values. It seeds and projects the initial velocity but counts no logical step.

## Projection Solver and Failure Policy

Use zero-mean, matrix-free, diagonally preconditioned conjugate gradient (PCG), with `q=0` as the initial guess and a selected candidate cap of 320 iterations. The original 256-iteration candidate was exercised against every full-grid family; the wall/edge/corner fixture required 270 iterations, so the cap was revised to 320 before any 3D kernel work, retaining a 50-iteration margin and every preregistered residual/divergence threshold. Project vectors to zero mean where required and normalize the reported `q` gauge to zero mean. The pressure correction is not compared before removing its constant gauge.

The closed-box RHS must be compatible. Compute and report `mean(b)`, maximum absolute RHS, and a face-flux scale. Remove only a roundoff-sized compatibility mean, bounded by `64 * epsilon(working precision) * max(normInf(b), h*normInf(u*), 1e-30)`; scaling by the input face flux is necessary when a divergence-free field's true RHS is zero but independent face differences cancel to roundoff. Exceeding that bound is a flux/boundary failure, not permission to conceal a nonzero net flux. A zero RHS returns `q=0` successfully without dividing by a zero norm. A candidate convergence result is accepted only after recomputing `r=b-Aq` from the operator. If recursive residual reports convergence but the true residual does not, replace the recurrence residual with `b-Aq`, reproject, and restart PCG. Any nonfinite input, reduction, iterate, residual, or nonpositive/nonfinite search denominator fails the solve. Exhausting 320 iterations without the true-residual acceptance below fails; it is not a PASS or a silent approximate update. Report iteration count, cap hit, compatibility mean, true residual, divergence, identity error, and failure status.

Projection acceptance for each nonzero fixture is both:

```text
dt * normInf(D uNew) <= 1e-5
dt * normInf(r) / h² <= 1e-5
```

The two values must also agree through `D uNew = -r/h²` within the Double identity tolerance. If input `dt*normInf(Du*) >= 1e-3`, require at least `1000x` reduction in `normInf(Du)`; a zero/tiny RHS is handled by the zero-RHS and compatibility rules instead. Also report divergence and residual RMS/L2, maximum absolute wall-normal flux, and cap hits. NaN/Inf explicitly fails before any tolerance comparison.

## Preregistered Fixtures and Tolerances

Every fixture records array shape, x-fastest layout, units, precision, input generation and independent expected output. Small asymmetric operator/index fixtures use `8x7x6`; pressure feasibility and production-sized data use `64x64x64` cells and the corresponding staggered face shapes. No GPU results are part of this table.

| Fixture | Input and independent expected result | Acceptance |
|---|---|---|
| Index/ABI ramp | `i + 100*j + 10000*k`, component-specific constants, every plane/extent | Exact integer indexing and exact declared extents/layout; ABI integer lanes round-trip exactly. |
| Zero and uniform dye | Zero velocity/pressure, constant dye `0.375`, including a reset and one reference step | All values finite; wall normals exactly zero; dye absolute error `<=2e-6`; no explicit dye decay. |
| Pressure null/gauge | Constant `q=0.125` and a zero RHS | `Aq=0`; constant is the only expected null mode; successful zero-RHS solve returns finite zero-mean `q`. |
| Alternating pressure | `q=0.125*(-1)^(i+j+k)`; form `Gq`, then `b=Aq` independently | `Aq` is nonzero, DG equals the neighbour stencil at all boundary classes, gauge-corrected pressure and projection match the Double reference. |
| Manufactured cosine pressure | At cell centres `q=cos(pi*x) cos(2*pi*y) cos(3*pi*z)`; construct `u*=Gq` on interior faces with zero wall-normal faces | Independent projection removes the manufactured gradient; recovered `q` agrees after mean removal; residual and divergence meet both limits. |
| ±axis and unequal combined advection | Cell-centred affine dye, separate positive/negative X/Y/Z transports and one unequal three-component velocity; include staggered component sampling | RK2/trilinear results match analytic affine sampling; each component transports from the same old generation; values remain bounded. |
| Affine interpolation | Asymmetric scalar and MAC face ramps sampled at interior fractional coordinates | Trilinear sampling equals the analytic affine function to Double `1e-10`. |
| Six walls, edges, and corners | Independent samples reflected across each individual wall and every pair/triple intersection; interior near-wall face impulses with all wall-normal values zero | Normal reflection is odd, tangential/scalar reflection even, composition/signs correct; exact wall zeros; all wall-adjacent cells enter divergence norms. |
| Mixed-frequency asymmetric projection | Three unequal analytic face fields with distinct frequencies/amplitudes, zero normal wall values; plus an asymmetric-grid case | PCG agrees with an independently assembled fixed-gauge direct solve on `8x7x6`; full 64³ true residual/divergence and reduction gates pass. |
| Divergence-free field | Discrete streamfunction differences on a staggered grid, with the two transverse divergence terms formed independently | RHS compatible and zero to roundoff; projection remains finite and does not create a spurious component. |
| Full-volume unequal-axis transport | `64³` compact smooth dye blob in an interior region; unequal nonzero X/Y/Z transport and deterministic RK2 backtraces, sampled at steps 0/24/48 | All-axis state is finite; dye centroid moves through Z by at least `h/2` over the declared early window; report mass, centroid and spread without claiming semi-Lagrangian mass conservation. |
| Curved/nonplanar trajectory | Integrate independent RK2 trajectories in a smooth analytic divergence-free 3D reference field; fit a least-squares plane to the trajectory points | Report `planeRMS = sqrt(lambdaMin(covariance))`, normalized by trajectory arc length. Preregister minimum `planeRMS/arcLength >= 0.01`; CPU reference must demonstrate the positive threshold before GPU acceptance. |
| Fixed slice midpoint/orientation | Asymmetric scalar with a known Z ramp and distinct X/Y landmarks | At `z=0.5`, sample the equal average of cell planes 31 and 32 (not plane 32 alone); X is right, Y is up after one display conversion. |

### Deterministic fixture inputs

- The `8x7x6` operator pressure is `0.013*(i+2*j+3*k) + sin(0.37*i+0.19*j+0.43*k)`; its independently formed `D(Gq)` and neighbour stencil are compared elementwise. The fixed-gauge direct solve sets cell `(0,0,0)` to zero and solves the remaining graph-Laplacian system by pivoted Double elimination; compare its mean-normalized pressure with PCG.
- Full-grid alternating pressure is `0.125*(-1)^(i+j+k)`. Manufactured cosine pressure is exactly the cell-centred formula in the table. Their input velocities are formed only by interior MAC face differences, with all six exterior normal faces zero.
- The mixed-frequency projection uses the following values at the corresponding face-centre coordinates; set wall-normal faces to exact zero after evaluation:

  ```text
  u = .11 sin(pi*x) cos(2pi*y) cos(3pi*z) + .03 sin(3pi*x) cos(pi*y) sin(2pi*z)
  v = .07 cos(2pi*x) sin(pi*y) cos(4pi*z) + .02 sin(pi*x) sin(2pi*y) cos(pi*z)
  w = .09 cos(pi*x) cos(2pi*y) sin(pi*z) + .025 sin(2pi*x) cos(pi*y) sin(3pi*z)
  ```

- The wall/edge/corner projection excites every interior face one index in from its normal wall and all tangential boundary-adjacent rows. For `u`, set those faces to `.02*(1+i+3*j+5*k)`; for `v`, `-.015*(2+2*i+j+4*k)`; for `w`, `.0125*(3+4*i+2*j+k)`. Keep the exterior normal planes exactly zero. These values are stress-fixture inputs, not a claimed lesson velocity.
- The independent divergence-free face fixture starts from vertex streamfunction `psi(i,j,k)=sin(pi*i/Nx)*sin(2pi*j/Ny)*sin(pi*(k+1/2)/Nz)`. Set `u=(psi(i,j+1,k)-psi(i,j,k))/h`, `v=-(psi(i+1,j,k)-psi(i,j,k))/h`, `w=0`, then enforce exterior zeros. The two transverse divergence terms cancel by independently computed differences.
- The full-volume analytic transport check uses a compact smooth blob `exp(1-1/(1-s²))` for `s=|x-center|/radius<1`, zero otherwise, with center `(.42,.48,.43)`, radius `.105`, and constant reference velocity `(.071,-.043,.113)`. Evaluate its exact translated field at steps 0, 24 and 48 using `x-v*step*dt`. Its support stays inside the box; this is an analytic transport/centroid fixture, not the projected lesson recipe and not a mass-conservation claim for semi-Lagrangian transport.
- The independent nonplanar trajectory uses `A=(sin(pi*y)sin(pi*z), sin(pi*z)sin(pi*x), sin(pi*x)sin(pi*y))`, velocity `0.25*curl(A)`, midpoint RK2, `dt=1/60`, 48 steps, and start `(.35,.21,.785)`. Record all 49 points. This trajectory is a geometric reference for the positive best-fit-plane threshold, separate from the pressure solver and not a user-visible tracer.

Tolerance policy: Double operator identities and affine interpolation use absolute `1e-10`; Float32 GPU elementwise reference checks use `abs(error) <= 2e-5 + 2e-4*abs(reference)`; uniform-dye preservation uses absolute `2e-6`; the all-wall normal-face value is exactly zero. These values are fixed before kernels, not fit to GPU outputs. Reject nonfinite values before evaluating any expression involving a tolerance.

## Candidate Full-Volume Observation Metrics

These are CPU-reference-checked candidate gates, not observed GPU or UI promises. The production lesson uses a fixed concentration transfer function and a single compact blob; it does not replenish dye, move the slice, apply explicit decay, or normalize brightness per frame.

- The step-0 central-slice peak is at least `0.5`.
- At steps 24 and 48, the `64x64` slice peak is at least `0.05`, and at least 8 of 4096 samples are at least `0.02`.
- Step-48 versus step-0 central-slice concentration-image RMS difference is at least `0.005`.
- The maximum change in each of `u`, `v`, and `w` over the early window is at least `1e-4` times the reset vector-speed maximum. Depth dependence is at least `1e-3` times that same scale.
- Dye-seeded independent trajectories cross Z by at least `h/2` over the early window. A separate full-volume unequal-three-axis fixture reports dye mass, centroid and spread and must show centroid Z displacement of at least `h/2`.
- Nonplanarity uses the best-fit-plane RMS/arc-length metric above and the CPU-checked `0.01` positive threshold.

Internal `0.5`, `1.0`, and `1.5` seed-speed probes may inform later lesson feasibility only; they do not add a user control or establish Phase 9 speed-ordering acceptance. If a CPU reference rejects a visibility/trajectory candidate, record the derivation and revise this contract before kernels. A failed pressure-feasibility gate blocks the kernel plan until investigated; do not relax residual/divergence tolerances to fit a GPU result.

## Deterministic Reference Export

`Tests/Integration/test_fluid3d_reference.py` compiles `Tests/Integration/fluid3d_reference.swift` with the system Swift compiler in a scoped temporary directory, without importing Metal or calling production/GPU stencils. `python3 Tests/Integration/test_fluid3d_reference.py --export .build/fluid3d-reference --check-contract` validates the locked contract prefix and exports deterministic JSON/binary fixtures under `.build/fluid3d-reference`. The manifest records a schema version, contract SHA-256, dimensions, x-fastest array order, component-specific face shapes, dtype/byte order, units, fixture names, expected metrics and binary payload hashes. The Python unittest entry points are:

```sh
python3 -m unittest Tests.Integration.test_fluid3d_reference.ReferenceContractTests.test_quick_contract
python3 -m unittest Tests.Integration.test_fluid3d_reference.ReferenceContractTests.test_reference_feasibility
```

`test_quick_contract` covers the asymmetric `8x7x6` operator and direct-solve cross-check plus analytic advection/reflection identities. `test_reference_feasibility` runs every contracted pressure fixture at 64³ against the selected 320-iteration cap and the same absolute residual/divergence/reduction criteria. Both commands fail on a compilation error, assertion failure, nonfinite value, or timeout; they must not skip. Report quick-feedback and full-feasibility durations separately.

<!-- END PREREGISTERED CONTRACT -->

## Contract Integrity

### Approved precision amendment — 2026-11-07

The user explicitly approved investigating compensated high/low Float32 pressure
storage after the production cosine projection failed and a diagnostic showed
that even once-rounded analytic pressure exceeded the original residual gate.
This amendment supersedes only the single-Float32 representation of `q`: store
`q = qHigh + qLow` in two cell-centred `.r32Float` textures, with compensated
updates and consistent paired operator/gradient evaluation. Both parts are
initialized, normalized, finite-checked, and reconstructed in Double for
independent readback validation. Other fields and reductions remain Float32.
The original prefix and its hash remain an immutable historical preregistration;
the complete contract document must also be hashed in production evidence.
The 320 cap, all thresholds, fixture definitions/amplitudes, reference independence,
and required actual-GPU acceptance are unchanged. Approval permits the experiment;
it does not establish convergence or numerical acceptance.

### Approved identity/storage-rounding amendment — 2026-11-07

The user explicitly approved separating strict Double operator algebra from
Float32 velocity-storage rounding. This supersedes the sentence requiring stored
Float32 output to satisfy the Double identity tolerance without a rounding term.
It does **not** change either `1e-5` projection gate, the `1000x` reduction gate,
the 320 cap, fixture amplitudes, or the Double operator-identity limit.

Before acceptance, reconstruct `qHigh+qLow` in Double and independently evaluate
`vIdeal = vInput-Gq`. Check `D(vIdeal)+(b-Aq)/h²` with the original `1e-10`
timestep-scaled infinity limit. Independently evaluate `D(vStored)` from every
returned Float32 face and enforce both original projection/reduction gates.
For each face, define `eps=2^-23`, `g=Gq`, and the absolute storage budget

```
eFace = 0.5*ulp(Float(vIdeal)) + 16*eps²*(abs(vInput)+abs(g))
        + 8*epsDouble*(abs(vInput)+abs(g)+2*normInf(q)/h).
```

The first term bounds final round-to-nearest Float32 storage. The second is a
conservative second-order allowance for the bounded compensated add/subtract
sequence (each operation retains the first-order error in the low lane); the
production inverse spacing is the exact power of two 64. The last term bounds
the independent Double evaluator's reconstruction of two pressure parts, their
face difference/scaling, and final subtraction; `epsDouble=2^-52`. This term is
necessary under cancellation: reconstructing `qHigh+qLow` in Double is itself a
rounded operation, not an exact real sum of arbitrarily separated exponents.
Require each returned
face to be within this budget of `vIdeal` before using it in an identity budget.
At each cell require the stored identity error to be at most
`1e-10 + dt/h * sum(eFace for its six incident faces)`. These constants come from
Float32 representation and the operation sequence, not a fitted observed error.
Report both ideal-Double and stored-output identity errors and the derived bound.
The compact GPU diagnostic `2e-5` identity check is only the triangle-inequality
consequence of the two `1e-5` gates, not a substitute for this independent check.

### Human-calibrated early-window visibility amendment — 2026-11-20 (UAT G-07-2)

This amendment is appended after the marker and never edits the preregistered
prefix. It is additive: it adds gates and a recipe envelope, and it relaxes
nothing.

**1. Calibration source.** UAT test 2 on 2026-11-20. The user first noticed
motion at steps 40-50 and expected 5-10. Production probe values for the
original recipe (speed 0.12, radius 0.12, centre `(0.42, 0.48, 0.52)`) were a
slice RMS from step 0 of 0.0129 at step 10, 0.035 at about step 35 and 0.052 at
about step 46 (a 1-2 cell patch shift); 41 slice samples with at least 32/255
encoded change at step 10; and a section area (samples at least 0.1) of 123
cells at step 0 against 119 cells at step 48. The preregistered candidate gates
above were about 10x weaker than this human visibility threshold. The numeric
gates below are a calibration of those candidate gates. They do not establish
human acceptance (see item 4).

**2. Additive gates** on the production solver, the fixed palette and the Z=0.5
central slice (planes 31/32, 64x64 production captures):

- E1 (retained): the step-0 slice peak is at least `0.5`.
- E2: the slice RMS difference from step 0 at step 10 is at least `0.025`.
- E3: the slice RMS difference from step 0 at step 20 is at least `0.04`.
- E4: at step 10, at least `100` of the 4096 slice samples have an encoded 8-bit
  palette colour that differs from step 0 by at least `32` in at least one
  channel, measured on the production 64x64 captures.
- E5: the section area `A(t)` (count of slice samples at least `0.1`) satisfies
  `A(0) >= 100` and `|A(48) - A(0)| >= 0.30 * A(0)`.
- E6: the slice peak is at least `0.30` and `A(t) >= 50` at steps 10, 20, 24
  and 48.
- E7: the shipped lesson recipe is run for 600 steps. Every step is accepted
  under the unchanged projection gates with no cap hit; the maximum input
  `dt*||Du*||inf` is at most `9e-4` (at least 10% below the `1e-3` activation of
  the unchanged 1000x reduction rule); all fields are finite at steps 100-600;
  and the volume dye maximum at step 600 is at least `0.05`. The slice peak and
  area at steps 100-600 are reported, not gated, because D-09 allows dye to
  leave the section.

**3. Recipe envelope** (D-07, D-08, D-10). The vector potential, curl
construction, wall handling and bump form are unchanged; the bump peak is 1 and
there is one blob. The global speed normalisation is in `[0.12, 0.18]`: inside
the UAT's x1.6 bound, with margin because x1.62 crosses `1e-3`. The blob radius
is in `[0.16, 0.18]`. Each centre coordinate is in `[0.30, 0.70]`, the D-08
reading of "slightly off centre": central region, support at least 0.12 from
every wall. The section starts off the equator, `0.30 <= |cz - 0.5| / r <= 0.60`,
so the step-0 slice peak stays at least `0.5`.

**4. Unchanged.** Every original candidate gate, every tolerance (`1e-5`
residual and divergence, 1000x reduction, cap 320, `1e-10` Double,
`2e-5 + 2e-4` Float) and the preregistered prefix hash are unchanged. These
numeric gates operationalise "readable early transport" (D-09) but do not
establish human acceptance; human re-observation is a separate blocking
checkpoint (plan 07-12).

**5. Phase 9 solver-cliff constraint.** The projection input divergence scales
roughly with speed squared and crosses `1e-3` near x1.62 of the original seed.
Measured minimum reductions were 1026x at x1.75, 1007x at x2.25 and 995.3x at
x3, where the run hard-failed at step 164 with a `finalAcceptanceFailed` latch,
then at least 1372x from x3.5. Any Phase 9 speed must stay outside that band or
add in-solver PCG margin (for example continuing to at least 1500x when the
input is at least `1e-3`), and must never relax the rule.

### Larger-blob, square-root display and 3D lesson-length amendment — 2026-11-21 (UAT G-07-2 re-observation)

This amendment is appended after the marker and the 07-11 amendment above. It
never edits the preregistered prefix or the 07-11 amendment text. It is
additive: it adds gates, a lesson-length rule and a recipe envelope, and it
relaxes nothing.

**1. Calibration source.** The 07-12 human re-observation of UAT test 2 on
2026-11-21, quoted verbatim from `07-12-SUMMARY.md`:

> "For test 2, I do see the patch fade and come back somewhat, but the
> brightness as it returns is very low, and so it's hard to interpret what is
> going on. Part of the problem seems to be that the patch is relatively small
> to begin with. Another issue is that there are only 500 timesteps, which is
> barely enough time to see anything happening."

The 07-11 600-step measurements for the shipped recipe (speed 0.17, centre
`(0.66, 0.44, 0.59)`, radius 0.17, peak 1) were: section area `A(0)` of 156
slice samples; slice peak 0.053 and section area 0 at step 200; section area 0
at step 300; section area 90 and slice peak 0.201 at step 600; volume dye peak
0.253 at step 600. The gap-round decisions of 2026-11-21 were: (1) the returning
dye must be clearly displayed (met by the 07-14 square-root display transfer),
(2) the starting patch is larger, and (3) the 3D lesson is longer, with its
length derived from a measured fade-and-return rather than guessed.

**2. Display basis.** The display metrics below use the production 64x64
central-slice captures, rendered by the production fixed-slice shader with the
square-root transfer of the 07-14 amendment to `docs/3d-inspection-contract.md`.
For each capture pixel take the encoded sRGB channels `v = byte/255`. Linearise
with `v <= 0.04045 ? v/12.92 : ((v+0.055)/1.055)^2.4`, then
`Y = 0.2126 R + 0.7152 G + 0.0722 B`, and
`L* = 116*cbrt(Y) - 16` when `Y > 216/24389`, else `(24389/27)*Y`. `V50(t)` is
the count of the 4096 pixels with `L* >= 50`, and `Lmax(t)` is the largest
pixel `L*`. Sanity anchors: `#ED8B23` gives `L*` of about 67.0 and `#FFF1D6`
about 95.6. Gate E4 of the 07-11 amendment is evaluated on the same production
captures. Every concentration-based metric (E1-E3, E5, E6, the volume peak) is
unchanged.

**3. Additive gates** on the production solver, the fixed square-root display
and the Z=0.5 central slice:

- S1: the step-0 section area `A(0)` (samples at least `0.1`) is at least `250`
  (the 07-11 recipe had 156).
- S2: `V50(0) >= 300`.
- R1 (return visibility), evaluated at checkpoints `c` in `{0, 50, ..., 1800}`
  where the step-0 value comes from the step-0 observation. `fadeStep` is the
  smallest `c >= 50` with `V50(c) <= 0.5 * V50(0)`. If `fadeStep` exists,
  `returnStep` is the smallest `c > fadeStep` with `V50(c) >= 150` and either
  `c == 1800` or `V50(c) >= V50(c+50)`. R1 passes when `returnStep` exists,
  `returnStep + 100 <= 1800` and `Lmax(returnStep) >= 60` (the amber stop is
  `L*` of about 67). If no `fadeStep` exists, R1 passes when `V50(c) >= 150`
  for every `c <= 1200`. When R1 fails, the derived lesson length is null.
- E7' (the shipped recipe over 1800 steps): every one of the 1800 steps is
  accepted under the unchanged projection gates with no cap hit; the maximum
  input `dt*||Du*||inf` is at most `9e-4` with zero steps at or above `1e-3`, so
  the 1000x reduction rule is never active; all fields are finite at every
  50-step checkpoint; and the volume dye maximum at the derived lesson length is
  at least `0.05`. E1-E6 keep their thresholds, and the 07-11 E7 600-step check
  stays required as a subset of E7'.

**4. 3D lesson-length rule.** One 1800-step production run derives the 3D
lesson length. It is the smallest of `1200`, `1500` or `1800` that is at least
`returnStep + 100`, or `1200` when there is no `fadeStep`. This is a measured
rule, not a shipped value: plan 07-16 ships the derived number. The 2D lessons
keep 600 steps.

**5. Phase 9 handoff.** `LES-05` and Phase 9 success criterion 2 still say
"600". Phase 9 planning must reconcile them with the user. This amendment
satisfies neither.

**6. Recipe envelope.** This supersedes item 3 of the 07-11 amendment. The
vector potential, curl construction, wall handling, bump form and the single
blob are unchanged. New bounds: seed speed in `[0.12, 0.17]`; radius in
`[0.20, 0.26]`; peak in `[1.00, 1.25]`; each centre coordinate in
`[0.30, 0.70]` with `min(c - r, 1 - c - r) >= 0.06` on every axis; and
`0.30 <= |cz - 0.5| / r <= 0.60`. Speed never exceeds 0.17, which keeps it below
the x1.6-x3.3 solver-cliff band of the original 0.12 seed. A peak above 1 is
tried only after peak-1 candidates, because a large saturated core would hide
the internal gradient that shows the section changing.
Speed 0.17 itself fails E7' over 1800 steps (item 8), so the shipped speed is selected below 0.17 by the rule in item 8.

**7. Unchanged.** Every original candidate gate, every tolerance (`1e-5`
residual and divergence, the 1000x reduction rule, cap 320, `1e-10` Double,
`2e-5 + 2e-4` Float), the 07-11 E1-E7 thresholds and the preregistered prefix
hash are unchanged. The 1000x rule is never relaxed. These numeric gates
calibrate the user's words; they are not human acceptance. Plan 07-17 is the
blocking human checkpoint.

**8. Seed-speed decision and preregistered selection (2026-11-21).**

(a) RED record on the 07-11 recipe (speed 0.17, centre `(0.66, 0.44, 0.59)`,
radius 0.17, peak 1) over 1800 steps, quoted from `0715-RED.log`: 1800 of 1800
steps were accepted, with 0 projection failures, 0 cap hits and at most 144
iterations. The maximum input `dt*||Du*||inf` was `1.1625e-3`, above `9e-4`.
The 1000x reduction rule was active on 126 steps with a minimum reduction of
`1006.8x`; it never failed. All checkpoints were finite. The 600-step subset
had a maximum input of `7.608e-4` and 0 active steps, so the 07-11 600-step
evidence hid this. On the square-root display the patch faded at step 150 and
returned at best to `V50` 52 at step 650.

(b) This is blob-independent. `ExperimentRecipes3D.initialState` scales the
vector-potential velocity by the seed speed alone and the dye is passive, so
the E7' solver statistics (input divergence, iterations, reduction-rule
activity) depend on the seed speed only. No blob at speed 0.17 can pass E7'.

(c) User decision of 2026-11-21 (option 1): lower the seed speed inside
`[0.12, 0.17]`. E7', D-17, the 1000x rule and every tolerance are never
relaxed.

(d) Preregistered selection rule.

- Speed grid, in order: `0.15, 0.14, 0.13, 0.12`, all strictly below 0.17.
  Quadratic estimates from the RED run, `1.1625e-3 * (s/0.17)^2`, are
  `9.05e-4`, `7.88e-4`, `6.80e-4` and `5.79e-4`. These are estimates only; the
  1800-step measurement decides.
- Blob set, all peak 1, inside the item-6 envelope, with wall clearance of at
  least 0.10 and `|cz - 0.5| / r` between 0.45 and 0.50:
  B1 centre `(0.66, 0.44, 0.60)` radius 0.22; B2 centre `(0.66, 0.44, 0.61)`
  radius 0.24; B3 centre `(0.64, 0.44, 0.62)` radius 0.24; B4 centre
  `(0.64, 0.44, 0.62)` radius 0.26.
- Stage A (speed screen): reference blob B2 at every grid speed in grid order,
  always all four runs (A015, A014, A013, A012). A speed is admissible when its
  Stage-A run has `stepsValidated` 1800, `projectionFailures` 0, `capHits` 0,
  `maximumIterations < 320`, `maximumInputDivergenceDTInf <= 9e-4`,
  `reductionGateActiveSteps` 0, `threeDLesson.finite` true, and every 07-11 E7
  600-step solver condition passing.
- Stage B (blob batches). Let s1 be the highest admissible speed and s2 the
  next admissible one. Batch 1: B1, B3 and B4 at s1, peak 1; it always runs.
  Batch 2 runs only while the selection set is empty: the two best peak-1
  candidates at s1 (the Stage-A run included) by minimum normalized margin,
  rerun at peak 1.25. Batches 3 and 4 repeat batches 1 and 2 at s2, again only
  while the selection set is empty. Run IDs are `<blob>-<speed x100>-P<peak x100>`.
- Selection set: every candidate run, Stage A or B, whose fixture run exited 0.
  The winner has the largest minimum normalized margin over: E2 `rms10/0.025`;
  E3 `rms20/0.04`; E4 `enc10/100`; E5 `min(A0/100, relA48/0.30)`; E6 the
  minimum over steps 10, 20, 24 and 48 of `min(peak/0.30, area/50)`; S1
  `A0/250`; S2 `V50(0)/300`; R1 (on the fade path with a return,
  `min(returnDisplayVisibleArea/150, returnMaximumLightness/60)`; on the fade
  path without a return, the maximum `V50` over the checkpoints after `fadeStep`
  divided by 150, a ranking proxy only, and that candidate fails R1; on the
  no-fade path, `minimumVisibleAreaThroughNoFadeWindow/150`); and E7' as
  `9e-4 / maximumInputDivergenceDTInf`.
- Ties are broken by the smaller `derivedLessonSteps`, then the higher speed,
  then the larger `V50(0)`.
- Cap: at most 14 candidate runs (4 + 3 + 2 + 3 + 2) plus one FINAL run that
  reruns the winner.
- Halts, none of which widens anything; the human decides. HALT-A: no
  admissible speed. HALT-B: the batches are exhausted with an empty selection
  set. HALT-C (inconsistency): a later run at an already-screened speed differs
  from that speed's Stage-A run in `stepsValidated`, `projectionFailures`,
  `capHits`, `reductionGateActiveSteps` or admissibility, or in
  `maximumInputDivergenceDTInf` by more than 1e-4 relative; or the FINAL run
  does not reproduce the winner (S1, S2, `fadeStep`, `returnStep`,
  `derivedLessonSteps` and the solver integer counters identical, and the
  floating margins equal within 1e-4 relative); or a run exits non-zero without
  a `METRICS=` line and the same happens again on one unchanged rerun.
- The grid, envelope, blob set and cap are never widened during execution.

(e) E1-E6, S1, S2, R1, E7' and every tolerance keep their written thresholds
at the lower speed. In particular the E1-E6 thresholds calibrated at 0.17 are
not re-scaled.

(f) Phase 9 note. The 07-11 statement that the input crosses `1e-3` near x1.62
of the 0.12 seed was a 600-step measurement. Over 1800 steps, speed 0.17
already crosses `9e-4` and `1e-3`. Phase 9 speed choices must be measured over
the reconciled lesson length.

(g) When this item was written, no evolution-visibility run below speed 0.17
existed. The recipe-candidates directory then held only the 07-11 runs at
speeds 0.18 and 0.17 and the 07-15 RED run at 0.17.

(h) These remain numeric gates, not human acceptance. Plan 07-17 is the
blocking human checkpoint.

**9. HALT-C record and finer seed-speed grid (2026-11-21).**

(a) Item 8 record, from `0715-candidates.tsv`. Stage A at B2 over 1800 steps
(maximum input `dt*||Du*||inf`; 0 reduction-active steps, 0 cap hits and 0
projection failures in every run): 0.15 `6.691e-4`, 0.14 `5.651e-4`, 0.13
`4.449e-4`, 0.12 `3.791e-4`. Every grid speed is admissible. No run exited 0:
E2 bound every Stage-A run (margins 0.936, 0.878, 0.819, 0.760), falling with
speed. At 0.15 the batch-1 margins were B1 0.950 (E2; also fails S2 and R1),
B3 0.974 (E2 only; every other gate passes, derived lesson length 1200) and B4
0.835 (E5). Batch 2 (peak 1.25) could not run:
`FluidSimulation3D` rejects reset dye outside `0...1` and throws before any
metrics, so the run had no `METRICS=` line, which repeated on the unchanged
rerun. That is HALT-C. Every Stage-B run at 0.15 reproduced A015's solver
statistics exactly, which confirms item 8(b).

(b) User decision of 2026-11-21: add finer seed speeds between 0.15 and 0.17.
The solver, the reset-dye validation, E2 and every other gate, threshold and
tolerance are unchanged. Peak 1.25 cannot be reached on the unchanged solver,
so item 8's peak-1.25 batches are void and no candidate in this item uses a
peak other than 1. The item-6 envelope text is not edited.

(c) Estimates, not measurements. Between 0.15 and 0.17 the measured maximum
input follows roughly `s^4.4`, which gives about `8.9e-4` at 0.16, `8.3e-4` at
0.1575 and `7.7e-4` at 0.155. E2 rose almost linearly with speed in Stage A,
which puts B3's E2 margin at about 1.039, 1.023 and 1.007 at those speeds.
These estimates choose the grid only; the 1800-step measurement decides.

(d) Preregistered extension of the item-8 rule.

- Extended grid, in order: `0.16, 0.1575, 0.155`, all strictly below 0.17.
- Stage A'' (screen and candidates in one): B3 (centre `(0.64, 0.44, 0.62)`,
  radius 0.24, peak 1) at every extended speed in order, always all three runs
  (`B3-0160-P100`, `B3-0158-P100`, `B3-0155-P100`; IDs use speed x1000,
  rounded). Item 8(b) and record (a) show that the solver statistics depend on
  speed only, so B3 serves as the screen. Admissibility is the item-8 Stage-A
  condition, unchanged.
- Stage B'' runs only if the selection set is still empty after Stage A'':
  B1, B2 and B4 at the highest admissible extended speed, peak 1.
- Selection set: every run of item 8 or this item whose fixture run exited 0.
  The selection metric and ties are those of item 8, unchanged.
- Cap: at most 6 more candidate runs (3 + 3) plus one FINAL run that reruns the
  winner.
- Halts are those of item 8 (HALT-A: no admissible extended speed; HALT-B:
  Stage B'' exhausted with an empty selection set; HALT-C: as defined in item
  8). None of them widens anything; the human decides.
- The grid, the blob set and the cap are not widened during execution.

(e) These remain numeric gates, not human acceptance. Plan 07-17 is the
blocking human checkpoint.

The SHA-256 is computed over the exact UTF-8 bytes before the marker above, including the newline immediately preceding it. Results may be appended after the marker without changing the preregistered-contract hash. The reference driver pins the resulting digest and `--check-contract` fails if this prefix changes without an intentional review and test update.

**Preregistered contract SHA-256:** `a7768571a996d5b9520aff5095100bb52fb67f96560f99633d081c04a3a9e01b`

## CPU Reference Results

The initial 256-iteration candidate did not meet the unchanged `1e-5` true-residual/divergence gate for `wall_edge_corner`: at 256 iterations both metrics were `3.88010297e-5`. An isolated CPU probe at cap 512 converged that same fixture in 270 iterations at `9.5921123e-6`; the pre-kernel contract therefore selects cap 320, leaving 50 iterations of measured margin without relaxing any accuracy threshold. The divergence-free fixture also exposed that compatibility roundoff must be scaled against `h*normInf(u*)`, not only the near-zero RHS; its exact-wall/curl fixture then returned a finite zero-iteration result. The originally chosen trajectory point/scale did not meet the preregistered `0.01` plane-RMS/arc-length threshold, so the independently integrated geometric fixture was fixed to the exact start/field/scale listed above; it yields `0.01662382` and Z displacement `40.0725` cells in 48 RK2 advances. The full-volume analytic unequal-axis fixture moves its dye centroid `5.78616` cells in Z over 48 advances. No GPU kernel, GPU acceptance, or production-lesson visibility result is claimed by this plan.

The final focused unittest run passed all three gates. The quick oracle invocation took `0.022 s`; all full `64³` pressure feasibility families took `1.989 s`. These are per-operation subprocess runtimes and exclude Swift compilation and unittest setup. The table reports the independently recomputed true residual and divergence in timestep-scaled infinity norm; each remained at or below `1e-5`, every case was finite/converged, and no case hit the 320-iteration cap.

| 64³ fixture | Iterations | Input `dt*||Du*||∞` | True residual `dt*||r||∞/h²` | Projected `dt*||DuNew||∞` | Divergence reduction |
|---|---:|---:|---:|---:|---:|
| zero RHS | 0 | 0 | 0 | 0 | 1 |
| constant pressure | 0 | 0 | 0 | 0 | 1 |
| alternating pressure | 1 | 102.4 | 0 | 0 | zero projected divergence |
| manufactured cosine | 154 | 2.29551945 | 7.58125988e-6 | 7.58125992e-6 | 302788.65x |
| mixed-frequency asymmetric | 159 | 0.0159617343 | 9.43789588e-6 | 9.43789588e-6 | 1691.24x |
| wall/edge/corner | 270 | 18.4213333 | 9.59211229e-6 | 9.59211228e-6 | 1920466.82x |
| divergence-free | 0 | 9.47390314e-16 | 9.47390314e-16 | 9.47390314e-16 | 1 |

Maximum `dt`-scaled residual/divergence identity error was `1.14e-13`; maximum wall-normal flux was exactly zero. The analytic full-volume fixture remained finite and moved its dye centroid `5.78616` cells in Z after 48 steps. The independent curved trajectory had `planeRMS/arcLength = 0.01662382` against the preregistered `0.01` minimum and moved `40.0725` cells in Z.

The `--export .build/fluid3d-reference --check-contract` run passed with the unchanged contract prefix SHA-256 `a7768571a996d5b9520aff5095100bb52fb67f96560f99633d081c04a3a9e01b`. Its six binary payloads all matched their manifest byte counts and SHA-256 values. The manifest SHA-256 is `b7042898c88e3872699de8e8d3fcdc3da20cbfc8c21fe31ac7fe11e0188ec7e0`; the asymmetric `8x7x6` operator payload matches the registered pressure formula and independently agrees between `-h²DG` and the neighbor stencil (SHA-256 `2d079f132f8b44135ce939be16cea4aa4f7628829b5d02ce15d22968d7b6c5c3`). The full-volume unequal-axis payload is `reference-64-full-volume-unequal-axis.f64le` (12,681,216 bytes; SHA-256 `9059ac449e0f16bc2e67d6909448192cf4e9e1aeb6c907668eeb22cc9ba7a0b3`) and carries the three staggered velocity inputs plus dye at steps 0/24/48. No GPU result is included or implied.
