# 3D Fluid Numerical Contract

**Status:** Preregistered for the first 3D kernel implementation. This contract fixes the numerical comparison before any 3D production kernel or GPU result is accepted. The CPU Double oracle is still pending at this point; no GPU PASS or measured lesson result is claimed here.

**Scope:** The fixed 64³, closed-box, dimensionless MAC-grid dye-advection experiment. This is an educational numerical contract, not calibrated physical time or scientific-grade accuracy. Changes to the established 2D solver and its Swift/Metal ABI are out of scope.

## Coordinates, Layout, Units, and Precision

- The domain is the unit cube `[0,1]³`, with X increasing right, Y increasing up, and Z increasing into the volume. `N=64`, `h=1/64`, and one logical advance uses `dt=1/60` dimensionless simulation-time units. A step is not a display frame or a physical second.
- Cell-centred dye `C` and pressure correction `q` have shape `(Nx, Ny, Nz) = (64,64,64)` and sample coordinates `((i+1/2)h,(j+1/2)h,(k+1/2)h)`. X is the fastest-varying coordinate: `index(i,j,k) = (k*Ny + j)*Nx + i`.
- Face-centred velocity uses three independent arrays, in `(x,y,z)` array order: `u: (65,64,64)` at `(i*h,(j+1/2)h,(k+1/2)h)`; `v: (64,65,64)` at `((i+1/2)h,j*h,(k+1/2)h)`; `w: (64,64,65)` at `((i+1/2)h,(j+1/2)h,k*h)`. Each array is x-fastest. Its normal coordinate includes both boundary faces.
- Velocity is in domain-lengths per simulation-time unit; divergence is per simulation-time unit; dye is a dimensionless concentration clamped to `[0,1]` for the lesson; `q=dt*p/rho` is the pressure correction scaled by timestep and density. No physical-pressure or real-time interpretation is exposed.
- The GPU candidate uses Float32 for every field, scratch value, uniform lane, and reduction input. The independent CPU oracle uses Double and independently formed loops. Any Swift/Metal uniform is a separately defined, 16-byte-lane ABI; this work does not change `StaticData`, `BufferData`, or any 2D shader entry point.

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

Use zero-mean, matrix-free, diagonally preconditioned conjugate gradient (PCG), with `q=0` as the initial guess and an initial candidate cap of 256 iterations. Project vectors to zero mean where required and normalize the reported `q` gauge to zero mean. The pressure correction is not compared before removing its constant gauge.

The closed-box RHS must be compatible. Compute and report `mean(b)` and maximum absolute RHS. Remove only a roundoff-sized compatibility mean, bounded by `64 * epsilon(working precision) * max(normInf(b), 1e-30)`; exceeding that bound is a flux/boundary failure, not permission to conceal a nonzero net flux. A zero RHS returns `q=0` successfully without dividing by a zero norm. A candidate convergence result is accepted only after recomputing `r=b-Aq` from the operator. If recursive residual reports convergence but the true residual does not, replace the recurrence residual with `b-Aq`, reproject, and restart PCG. Any nonfinite input, reduction, iterate, residual, or nonpositive/nonfinite search denominator fails the solve. Exhausting 256 iterations without the true-residual acceptance below fails; it is not a PASS or a silent approximate update. Report iteration count, cap hit, compatibility mean, true residual, divergence, identity error, and failure status.

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

`test_quick_contract` covers the asymmetric `8x7x6` operator and direct-solve cross-check plus analytic advection/reflection identities. `test_reference_feasibility` runs every contracted pressure fixture at 64³ against the 256-iteration cap and the same absolute residual/divergence/reduction criteria. Both commands fail on a compilation error, assertion failure, nonfinite value, or timeout; they must not skip. Report quick-feedback and full-feasibility durations separately.

<!-- END PREREGISTERED CONTRACT -->

## Contract Integrity

The SHA-256 is computed over the exact UTF-8 bytes before the marker above, including the newline immediately preceding it. Results may be appended after the marker without changing the preregistered-contract hash. The reference driver pins the resulting digest and `--check-contract` fails if this prefix changes without an intentional review and test update.

**Preregistered contract SHA-256:** `059a73992073273dc3e044daee1a06eef20306726816c4fb48280b17a2ea5a2d`

## CPU Reference Results

Pending Task 2. This section will record actual CPU Double fixture outcomes, iteration counts, quick/full durations, and any justified pre-kernel contract revision. No GPU kernel, GPU acceptance, or lesson visibility result is claimed by this plan.
