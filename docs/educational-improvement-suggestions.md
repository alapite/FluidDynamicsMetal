# Suggestions for improving FluidDynamicsMetal as a visual guide

These suggestions focus on curious learners who want to understand fluid dynamics through exploration. The strongest opportunities are clearer field visualizations and repeatable guided experiments that connect visible patterns with the behaviour of the fluid.

Status: ideas for consideration, recorded on 8 October 2026. These are not an approved implementation plan or a commitment to begin development. The ordering below reflects suggested priority.

## Make the field views readable

The existing field selector provides a useful foundation, but its colour mappings are difficult to interpret without knowing the shaders. Velocity currently maps its components to colour channels, pressure rendering discards the sign, and vorticity uses the vector colour shader despite being a scalar.

Suggested improvements:

- Show velocity direction with arrows over a speed heatmap, optionally overlaid on the dye.
- Give vorticity a diverging colour map that distinguishes clockwise and anticlockwise rotation.
- Display pressure with a signed scale relative to a reference value.
- Add a small legend and one sentence explaining what each field reveals, using colour palettes that remain distinguishable for users with colour vision differences.

These relatively contained changes would make the existing simulation much more informative without requiring new fluid phenomena.

## Add guided experiments

Offer a small collection of experiments with repeatable starting states. Each should include a short explanation of what to notice and one useful adjustment, so the learner can connect a change in input with a change in behaviour.

| Experiment | Learning opportunity |
| --- | --- |
| A dye patch carried by a flow | Advection: fluid motion transports material. |
| Two interacting vortices | How rotating regions influence one another. |
| A stripe or grid of dye stretched by stirring | Stretching and folding during mixing. |
| Identical initial flow with Swirl off and on | How numerical swirl enhancement changes the result. |

Include a **Restart experiment** action. Reproducing an observation should not require relaunching the app or repeating a gesture exactly. For the mixing example, distinguish the visible stretching of dye from diffusion; the current solver does not provide a separately controlled physical dye-diffusion model.

## Let people follow the fluid

Add passive tracer particles with optional trails, plus a tool that continuously releases particles from a fixed point. Instantaneous streamlines would be a useful later addition.

These tools expose three different ways to describe a flow:

- **Streamlines** follow the direction of the velocity field at a particular instant.
- **Pathlines** record the trajectory of an individual particle over time.
- **Streaklines** connect particles that have passed through the same release point.

The distinction is particularly useful in changing flows, where these lines can differ. A learner could pause the simulation and compare where the flow points now with where particles have already travelled. The [MIT flow-visualization tutorial](https://web.mit.edu/fluids-modules/www/potential_flows/LecturesHTML/lec02/tutorial/) provides an educational reference for this comparison.

## Make controlled comparisons easy

Add single-step, slow motion, and repeatable replay alongside the existing pause control. A synchronized comparison view could initially show dye and vorticity from the same simulation side by side. Comparing two separate simulations with different parameter settings would be a later extension.

Separate **dye fading** from **motion damping**. The current Fade control affects both dye and velocity, so changing how long the dye remains visible also changes the motion being studied.

Stable simulation timing independent of rendering speed would underpin reliable replay and comparisons. The current solver advances in frame-based steps, so timing deserves attention before presenting experiments as quantitatively comparable across devices.

## Explain the model through the controls

Use short explanations beside the relevant controls, with optional deeper reading drawn from the existing [equations and approximations source](fluid-dynamics.tex).

| Current label or field | Suggested presentation | Reason |
| --- | --- | --- |
| Density | Dye concentration | The colour represents transported dye, not changes in fluid mass density. |
| Swirl | Swirl enhancement | The control numerically reinforces existing rotation. |
| Pressure | Pressure, with an explanation of its simulation units | The stored field is a pressure correction rather than calibrated pressure in pascals. |
| Fade | Separate dye fading and motion damping controls | Visibility and fluid motion should be independently adjustable for experiments. |

Recompute displayed vorticity from the final velocity so both views describe the same simulation stage. Currently, the stored vorticity is computed before swirl enhancement and pressure projection.

Keep the default explanations intuitive, with equations available on demand. The aim is to help a learner interpret an observation at the moment they make it.

## Expand to obstacles and physical viscosity

Flow around a cylinder, through a narrowing channel, or past a barrier would provide recognizable experiments. A cylinder wake could become a signature demonstration.

This is a larger solver extension. It would require solid boundaries, suitable inflow and outflow conditions, explicit viscosity, and validation of the resulting behaviour. The existing Fade and Swirl controls cannot substitute for physical viscosity, and adding a visible obstacle alone would not establish a reliable wake demonstration.

The [GPU Gems fluid simulation chapter](https://developer.nvidia.com/gpugems/gpugems/part-vi-beyond-triangles/chapter-38-fast-fluid-dynamics-simulation-gpu) describes viscosity and boundary handling as distinct parts of a fluid solver. These capabilities would support a later set of experiments once the visualization and learning tools are established.

## Suggested first release

A focused first release could combine readable field views, reset and single-step controls, tracer particles, and three guided experiments: dye advection, interacting vortices, and dye stretching through stirring.

The intended learning cycle is simple: predict what will happen, run the experiment, inspect the flow, and repeat with one change. Obstacles, physical viscosity, and comparisons between separate simulations would remain later possibilities.
