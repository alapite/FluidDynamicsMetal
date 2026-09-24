"""Phase 2 effective build-setting checks for both application schemes.

Run with: python3 -m unittest -v test_phase02_settings
"""

import json
import subprocess
import unittest


class Phase02SettingsTests(unittest.TestCase):
    def test_both_schemes_target_current_swift_and_os(self):
        schemes = (
            ("FluidDynamicsMetaliOS", "generic/platform=iOS Simulator", "IPHONEOS_DEPLOYMENT_TARGET"),
            ("FluidDynamicsMetalOSX", "platform=macOS", "MACOSX_DEPLOYMENT_TARGET"),
        )
        for scheme, destination, deployment_key in schemes:
            for configuration in ("Debug", "Release"):
                with self.subTest(scheme=scheme, configuration=configuration):
                    result = subprocess.run(
                        ("xcodebuild", "-project", "FluidDynamicsMetal.xcodeproj",
                         "-scheme", scheme, "-configuration", configuration,
                         "-destination", destination, "CODE_SIGNING_ALLOWED=NO",
                         "-showBuildSettings", "-json"),
                        check=True, capture_output=True, text=True,
                    )
                    targets = json.loads(result.stdout)
                    settings = next(item["buildSettings"] for item in targets
                                    if item["target"] == scheme)
                    self.assertEqual(settings["SWIFT_VERSION"], "5.0")
                    self.assertEqual(settings[deployment_key], "26.0")
                    if scheme == "FluidDynamicsMetaliOS":
                        self.assertEqual(settings["TARGETED_DEVICE_FAMILY"], "1,2")


if __name__ == "__main__":
    unittest.main()
