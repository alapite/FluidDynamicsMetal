"""Exercise the production Mac shaders with RG16F texture readback."""
import json
import subprocess
import unittest
from pathlib import Path


class Phase05MetalTests(unittest.TestCase):
    def test_tuning_reaches_real_metal_passes(self):
        settings = subprocess.run(("xcodebuild", "-project", "FluidDynamicsMetal.xcodeproj", "-scheme", "FluidDynamicsMetalOSX", "-configuration", "Debug", "-destination", "platform=macOS,arch=arm64", "CODE_SIGNING_ALLOWED=NO", "-showBuildSettings", "-json"), capture_output=True, text=True, check=True)
        target = next(x["buildSettings"] for x in json.loads(settings.stdout) if x["target"] == "FluidDynamicsMetalOSX")
        library = Path(target["TARGET_BUILD_DIR"]) / target["WRAPPER_NAME"] / "Contents/Resources/default.metallib"
        self.assertTrue(library.is_file(), "Build the Mac Debug scheme before the GPU test")
        result = subprocess.run(("xcrun", "swift", "-swift-version", "6", "test_phase05_metal.swift", str(library)), capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("PASS: force/dye independent; retention endpoints on both fields; swirl on stored vorticity", result.stdout)


if __name__ == "__main__":
    unittest.main()
