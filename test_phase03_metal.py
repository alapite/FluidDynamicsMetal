"""Offscreen RG16F resize regression against the freshly built Mac metallib."""
import json
import subprocess
import unittest
from pathlib import Path


class Phase03MetalTests(unittest.TestCase):
    def test_resample_retains_edges_center_and_scales_velocity(self):
        settings = subprocess.run(("xcodebuild", "-project", "FluidDynamicsMetal.xcodeproj", "-scheme", "FluidDynamicsMetalOSX", "-configuration", "Debug", "-destination", "platform=macOS,arch=arm64", "CODE_SIGNING_ALLOWED=NO", "-showBuildSettings", "-json"), capture_output=True, text=True, check=True)
        target = next(x["buildSettings"] for x in json.loads(settings.stdout) if x["target"] == "FluidDynamicsMetalOSX")
        library = Path(target["TARGET_BUILD_DIR"]) / target["WRAPPER_NAME"] / "Contents/Resources/default.metallib"
        self.assertTrue(library.is_file(), "Build the Mac Debug scheme first")
        result = subprocess.run(("xcrun", "swift", "-swift-version", "6", "test_phase03_metal.swift", str(library)), capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("PASS: RG16F full-canvas resample both aspect directions, five fields", result.stdout)


if __name__ == "__main__":
    unittest.main()
