# Regenerate the Free Play preview and experiment artwork

Build the Mac Debug target with its Metal toolchain. The capture tool loads the app's compiled `default.metallib` and runs the production solver and presentation encoders offscreen. Run it from the repository root on a Mac with Metal access.

```bash
xcodebuild -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetalOSX \
  -configuration Debug -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath .build/presentation-assets-build CODE_SIGNING_ALLOWED=NO build

xcrun swiftc -swift-version 6 -parse-as-library -O \
  Sources/Shared/{Camera3D,ExperimentRecipes,ExperimentRecipes3D,FieldVisualization,FieldVisualization3D,FluidSimulation,FluidSimulation3D,InspectionState3D,MetalDevice,ParticleSystem,PressureProjection3D,RenderShader,Renderer,SimulationState,SimulationTypes,SimulationTypes3D,Slab,TracerSystem3D,VolumeField3D}.swift \
  Tests/Integration/capture_presentation_assets.swift \
  -o .build/presentation-assets-build/capture-presentation-assets

.build/presentation-assets-build/capture-presentation-assets \
  .build/presentation-assets-build/Build/Products/Debug/FluidDynamicsMetalOSX.app/Contents/Resources/default.metallib \
  .
```

The generator checks the clip’s duration, frame rate, dimensions, and lack of audio. It decodes sample frames, including the last frame, for review. It keeps clean 512-pixel captures under `.build/presentation-asset-evidence`. It also replaces the artwork in the shared and Mac asset catalogs and the bundled `Sources/Shared/FreePlayPreview.mp4`. The first asset bootstrap can use `default.metallib` from a Mac build that predates asset resource membership if the new bundle files have yet to be generated.

| Artwork | Production capture | Thumbnail framing |
|---|---|---|
| Free Play | Two scripted contact arcs in a 512 × 512 simulation with default tuning and the dye field. H.264 at 30 fps, two solver steps per frame, 120 frames, silent. The still is the final frame before compression. | Color threshold around the final dye. |
| Dye carried by a flow | Normal speed, dye concentration, step 240. | Color threshold around the transported patch. |
| Two interacting vortices | Opposite rotation, signed vorticity, step 120. | Saturation threshold includes both opposing regions. |
| Stretching dye by stirring | Normal stirring, dye concentration, step 240. | Color threshold around the folded stripe. |
| 3D Dye Advection | Seeded step 0, XY plane at 50%, yaw 25°, elevation 18°, zoom 100%, default tracers. | Brightness threshold includes the cube and slice. |

The 2D lesson thumbnails show the fields with overlays off. Thumbnail crops center the visible bounds in a square, adding 15% of the longer dimension to each edge where the canvas allows. Each 96-pixel master preserves the crop's proportions for a nominal 32-point menu image.
