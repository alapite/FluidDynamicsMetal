"""Independent CPU Double reference gates for the preregistered 3D contract.

These tests compile the standalone Swift oracle in a scoped temporary directory.
They do not import Metal or treat a production/GPU implementation as reference.
"""

import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import time
import unittest


ROOT = Path(__file__).resolve().parents[2]
SWIFT_SOURCE = ROOT / "Tests/Integration/fluid3d_reference.swift"
CONTRACT = ROOT / "docs/3d-numerical-contract.md"


class ReferenceContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.build_directory = None
        cls.runner = None
        cls.compile_output = ""
        if not SWIFT_SOURCE.is_file():
            return
        cls.build_directory = Path(tempfile.mkdtemp(prefix="fluid3d-reference-"))
        executable = cls.build_directory / "fluid3d-reference"
        result = subprocess.run(
            ["swiftc", "-swift-version", "6", "-O", "-parse-as-library",
             str(SWIFT_SOURCE), "-o", str(executable)],
            capture_output=True,
            text=True,
            timeout=180,
        )
        cls.compile_output = result.stdout + result.stderr
        if result.returncode == 0:
            cls.runner = executable

    @classmethod
    def tearDownClass(cls):
        if cls.build_directory is not None:
            shutil.rmtree(cls.build_directory)

    def require_oracle(self):
        self.assertTrue(
            SWIFT_SOURCE.is_file(),
            f"independent Swift CPU oracle is missing: {SWIFT_SOURCE.relative_to(ROOT)}",
        )
        self.assertIsNotNone(self.runner, self.compile_output)

    def run_reference(self, operation, timeout):
        self.require_oracle()
        started = time.perf_counter()
        result = subprocess.run(
            [str(self.runner), "--check-contract", str(CONTRACT), operation],
            capture_output=True,
            text=True,
            timeout=timeout,
        )
        elapsed = time.perf_counter() - started
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        try:
            payload = json.loads(result.stdout)
        except json.JSONDecodeError as error:
            self.fail(f"oracle did not return JSON: {error}\n{result.stdout}\n{result.stderr}")
        self.assertTrue(payload.get("finite", False), payload)
        return payload, elapsed

    def test_quick_contract(self):
        """Asymmetric operators, direct solve, advection, and reflections agree."""
        result, elapsed = self.run_reference("--quick-contract", timeout=180)
        self.assertEqual(result["grid"], [8, 7, 6])
        self.assertLessEqual(result["dg_stencil_max_abs_error"], 1e-10)
        self.assertLessEqual(result["affine_interpolation_max_abs_error"], 1e-10)
        self.assertLessEqual(result["affine_face_interpolation_max_abs_error"], 1e-10)
        self.assertEqual(result["midpoint_planes"], [3, 4])
        self.assertLessEqual(result["midpoint_slice_max_abs_error"], 1e-10)
        self.assertLessEqual(result["midpoint_landmark_max_abs_error"], 1e-10)
        self.assertLessEqual(result["direct_solve_pressure_max_abs_error"], 1e-6)
        self.assertLessEqual(result["direct_solve_true_residual_max_abs"], 1e-10)
        self.assertLessEqual(result["direct_solve_stencil_crosscheck_max_abs_error"], 1e-10)
        self.assertGreaterEqual(result["advection_cases"], 8)
        self.assertLessEqual(result["advection_max_abs_error"], 1e-10)
        self.assertLessEqual(result["component_advection_max_abs_error"], 1e-10)
        self.assertGreaterEqual(result["reflection_cases"], 26)
        self.assertLessEqual(result["reflection_max_abs_error"], 1e-10)
        self.assertTrue(result["constant_pressure_is_null"])
        self.assertTrue(result["alternating_pressure_is_nonzero"])
        self.assertTrue(result["nan_rejected"])
        print(f"PASS: quick 3D CPU contract ({elapsed:.3f}s)")

    def test_reference_feasibility(self):
        """Every locked full-grid pressure family converges within the cap."""
        result, elapsed = self.run_reference("--reference-feasibility", timeout=1800)
        self.assertEqual(result["grid"], [64, 64, 64])
        self.assertEqual(result["iteration_cap"], 320)
        fixtures = {fixture["name"]: fixture for fixture in result["fixtures"]}
        expected = {
            "zero_rhs",
            "constant_pressure",
            "alternating_pressure",
            "manufactured_cosine",
            "mixed_frequency_asymmetric",
            "wall_edge_corner",
            "divergence_free",
        }
        self.assertTrue(expected.issubset(fixtures), sorted(fixtures))
        for name in sorted(expected):
            fixture = fixtures[name]
            with self.subTest(fixture=name):
                self.assertTrue(fixture["finite"], fixture)
                self.assertTrue(fixture["converged"], fixture)
                self.assertFalse(fixture["cap_hit"], fixture)
                self.assertLessEqual(fixture["iterations"], 320)
                self.assertLessEqual(fixture["true_residual_dt_inf"], 1e-5, fixture)
                self.assertLessEqual(fixture["projected_divergence_dt_inf"], 1e-5, fixture)
                self.assertLessEqual(fixture["identity_dt_inf_error"], 1e-10, fixture)
                if fixture["input_divergence_dt_inf"] >= 1e-3:
                    self.assertGreaterEqual(fixture["divergence_reduction"], 1000.0, fixture)
        trajectory = result["reference_trajectory"]
        self.assertGreaterEqual(trajectory["centroid_z_displacement_cells"], 0.5)
        self.assertGreaterEqual(trajectory["plane_rms_arc_ratio"], 0.01)
        self.assertTrue(trajectory["finite"], trajectory)
        print(f"PASS: full 64^3 CPU feasibility ({elapsed:.3f}s)")


def export_reference(destination, check_contract):
    """Compile in a scoped temporary directory and export deterministic oracle data."""
    if not SWIFT_SOURCE.is_file():
        raise RuntimeError(f"missing independent Swift CPU oracle: {SWIFT_SOURCE}")
    with tempfile.TemporaryDirectory(prefix="fluid3d-reference-export-") as build_dir:
        executable = Path(build_dir) / "fluid3d-reference"
        compile_result = subprocess.run(
            ["swiftc", "-swift-version", "6", "-O", "-parse-as-library",
             str(SWIFT_SOURCE), "-o", str(executable)],
            capture_output=True,
            text=True,
            timeout=180,
        )
        if compile_result.returncode != 0:
            raise RuntimeError(compile_result.stdout + compile_result.stderr)
        if check_contract:
            checked = subprocess.run(
                [str(executable), "--check-contract", str(CONTRACT)],
                capture_output=True,
                text=True,
                timeout=60,
            )
            if checked.returncode != 0:
                raise RuntimeError(checked.stdout + checked.stderr)
            print(checked.stdout, end="")
        output = Path(destination)
        output.mkdir(parents=True, exist_ok=True)
        exported = subprocess.run(
            [str(executable), "--export", str(output), "--contract", str(CONTRACT)],
            capture_output=True,
            text=True,
            timeout=1800,
        )
        if exported.returncode != 0:
            raise RuntimeError(exported.stdout + exported.stderr)
        print(exported.stdout, end="")


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--export", metavar="DIRECTORY")
    parser.add_argument("--check-contract", action="store_true")
    args = parser.parse_args()
    if args.export:
        export_reference(args.export, args.check_contract)
    elif args.check_contract:
        export_reference(Path(tempfile.mkdtemp(prefix="fluid3d-contract-check-")), True)
    else:
        unittest.main()
