"""Phase 2 built-app and simulator smoke checks.

Run after the iOS Debug build: python3 -m unittest Tests.Integration.test_phase02_bundle
The simulator test installs the current build on an available iOS 26 iPhone
and iPad, and launches it. It does not assert visual or touch behavior.
"""

import json
import plistlib
import subprocess
import unittest
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[2]


PROJECT = str(PROJECT_ROOT / "FluidDynamicsMetal.xcodeproj")
SCHEME = "FluidDynamicsMetaliOS"
BUNDLE_ID = "ro.andreisergiupitis.FluidDynamicsMetaliOS"


def run(*command):
    return subprocess.run(command, check=True, capture_output=True, text=True).stdout


def built_app():
    settings = json.loads(run(
        "xcodebuild", "-project", PROJECT, "-scheme", SCHEME,
        "-configuration", "Debug", "-destination", "generic/platform=iOS Simulator",
        "CODE_SIGNING_ALLOWED=NO", "-showBuildSettings", "-json",
    ))
    ios = next(item["buildSettings"] for item in settings if item["target"] == SCHEME)
    return Path(ios["TARGET_BUILD_DIR"]) / ios["WRAPPER_NAME"]


class Phase02BundleTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = built_app()

    def test_installable_metal_bundle_targets_ios_26(self):
        self.assertTrue(self.app.is_dir(), "Build the iOS Debug scheme first")
        with (self.app / "Info.plist").open("rb") as info:
            metadata = plistlib.load(info)
        self.assertEqual(metadata["MinimumOSVersion"], "26.0")
        self.assertEqual(metadata["CFBundleIdentifier"], BUNDLE_ID)
        self.assertIn("metal", metadata["UIRequiredDeviceCapabilities"])
        self.assertEqual(set(metadata["UIDeviceFamily"]), {1, 2})
        self.assertTrue((self.app / "default.metallib").is_file())

    def test_fresh_bundle_launches_on_iphone_and_ipad(self):
        self.assertTrue(self.app.is_dir(), "Build the iOS Debug scheme first")
        devices = json.loads(run("xcrun", "simctl", "list", "devices", "available", "-j"))["devices"]
        ios26 = [device for runtime, members in devices.items() if "iOS-26" in runtime
                 for device in members]
        for family in ("iPhone", "iPad"):
            with self.subTest(family=family):
                device = next((device for device in ios26 if device["name"].startswith(family)), None)
                self.assertIsNotNone(device, "An iOS 26 {} simulator is required".format(family))
                udid = device["udid"]
                if device["state"] != "Booted":
                    run("xcrun", "simctl", "boot", udid)
                run("xcrun", "simctl", "bootstatus", udid, "-b")
                run("xcrun", "simctl", "install", udid, str(self.app))
                result = run("xcrun", "simctl", "launch", udid, BUNDLE_ID)
                self.assertIn(BUNDLE_ID + ":", result)


if __name__ == "__main__":
    unittest.main()
