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
