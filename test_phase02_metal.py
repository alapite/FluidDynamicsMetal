"""Run offscreen GPU behavior checks against the freshly built shared Mac metallib.

Run after the macOS Debug build: python3 -m unittest -v test_phase02_metal
"""

import json
import subprocess
import unittest
from pathlib import Path


class Phase02MetalTests(unittest.TestCase):
    def test_shared_shader_applies_last_contact_and_clears_released_input(self):
        settings = subprocess.run(
            ("xcodebuild", "-project", "FluidDynamicsMetal.xcodeproj", "-scheme",
             "FluidDynamicsMetalOSX", "-configuration", "Debug", "-destination",
             "platform=macOS,arch=arm64", "CODE_SIGNING_ALLOWED=NO",
             "-showBuildSettings", "-json"),
            check=True, capture_output=True, text=True,
        )
        target = next(item["buildSettings"] for item in json.loads(settings.stdout)
                      if item["target"] == "FluidDynamicsMetalOSX")
        library = (Path(target["TARGET_BUILD_DIR"]) / target["WRAPPER_NAME"] /
                   "Contents/Resources/default.metallib")
        self.assertTrue(library.is_file(), "Build the Mac Debug scheme first")
        result = subprocess.run(
            ("xcrun", "swift", "test_phase02_metal.swift", str(library)),
            capture_output=True, text=True,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("PASS: Metal tenth-slot dye/force and empty-input release", result.stdout)


if __name__ == "__main__":
    unittest.main()
