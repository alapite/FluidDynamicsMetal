"""Fast direct-source production inspection math checks (no Metal/Xcode run)."""
from pathlib import Path
import subprocess
import time
import unittest

ROOT = Path(__file__).resolve().parents[2]


class InspectionState3DChecks(unittest.TestCase):
    def test_camera_and_slice_state(self):
        sources = [ROOT / "Sources/Shared/InspectionState3D.swift", ROOT / "Sources/Shared/Camera3D.swift"]
        for source in sources:
            self.assertTrue(source.is_file(), f"production inspection value/math missing: {source.name}")
        directory = ROOT / ".build/inspection3d-state"
        directory.mkdir(parents=True, exist_ok=True)
        executable = directory / "checks"
        started = time.perf_counter()
        result = subprocess.run(["swiftc", "-O", "-parse-as-library", *map(str, sources), str(ROOT / "Tests/Integration/test_inspection3d_state.swift"), "-o", str(executable)], capture_output=True, text=True, timeout=180)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        compile_seconds = time.perf_counter()-started
        started = time.perf_counter()
        result = subprocess.run([str(executable)], capture_output=True, text=True, timeout=30)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("PASS production inspection", result.stdout)
        print(result.stdout.strip())
        print(f"compile={compile_seconds:.3f}s run={time.perf_counter()-started:.3f}s")
