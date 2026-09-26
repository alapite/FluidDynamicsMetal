"""Exercise production renderer helpers against the freshly built Mac shaders."""
import json
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]


class RendererCorrectnessTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        settings = subprocess.run(
            ["xcodebuild", "-project", str(ROOT / "FluidDynamicsMetal.xcodeproj"),
             "-scheme", "FluidDynamicsMetalOSX", "-configuration", "Debug",
             "-destination", "platform=macOS,arch=arm64", "CODE_SIGNING_ALLOWED=NO",
             "-showBuildSettings", "-json"], capture_output=True, text=True, check=True)
        target = next(item["buildSettings"] for item in json.loads(settings.stdout)
                      if item["target"] == "FluidDynamicsMetalOSX")
        cls.library = Path(target["TARGET_BUILD_DIR"]) / target["WRAPPER_NAME"] / "Contents/Resources/default.metallib"
        if not cls.library.is_file():
            raise AssertionError("Build the Mac Debug scheme before running GPU checks")
        cls.directory = tempfile.TemporaryDirectory(prefix="fluid-correctness-")
        cls.addClassCleanup(cls.directory.cleanup)
        cls.executable = Path(cls.directory.name) / "renderer-check"
        sources = [ROOT / "Sources/Shared" / name for name in
                   ["MetalDevice.swift", "RenderShader.swift", "Slab.swift",
                    "SimulationState.swift", "Renderer.swift"]]
        subprocess.run(
            ["xcrun", "swiftc", "-swift-version", "6", "-parse-as-library",
             *map(str, sources), str(Path(__file__).with_suffix(".swift")),
             "-o", str(cls.executable)], check=True, capture_output=True, text=True)

    def run_check(self, mode):
        return subprocess.run([str(self.executable), str(self.library), mode],
                              capture_output=True, text=True, timeout=60)

    def test_initial_fields_are_cleared_and_remain_zero_without_input(self):
        result = self.run_check("initialization")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("PASS: initialization", result.stdout)

    def test_pipeline_factory_preserves_missing_function_errors(self):
        result = self.run_check("factory-errors")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("PASS: factory-errors", result.stdout)

    def test_pipeline_cache_separates_names_and_formats(self):
        result = self.run_check("cache")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("PASS: cache", result.stdout)

    def test_mouse_origin_injects_one_splat_and_release_stops_dye(self):
        result = self.run_check("mouse-origin")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("PASS: mouse-origin", result.stdout)

    def test_shader_wrapper_fails_immediately_with_context(self):
        for mode, vertex, fragment in [("missing-vertex", "missingVertex", "advect"),
                                       ("missing-fragment", "vertexShader", "missingFragment")]:
            with self.subTest(mode=mode):
                result = self.run_check(mode)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("Metal render pipeline initialization failed", result.stderr)
                self.assertIn(f"vertex: {vertex}", result.stderr)
                self.assertIn(f"fragment: {fragment}", result.stderr)
                self.assertIn("pixel format: 65", result.stderr)  # MTLPixelFormat.rg16Float
                self.assertIn("failedToCreateFunction", result.stderr)


if __name__ == "__main__":
    unittest.main()
