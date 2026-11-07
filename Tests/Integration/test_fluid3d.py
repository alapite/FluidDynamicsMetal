"""Production 3D Metal fixtures; GPU checks use the app's freshly built metallib.

CPU reference fixtures and versioned GPU evidence live under .build/fluid3d-reference
and .build/fluid3d-evidence. Missing hardware, compiler, library, or fixture failures
are errors; this harness never converts them into skips or fallback results.
"""

from __future__ import annotations

import hashlib
import json
import os
import re
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
CONTRACT_HASH = "a7768571a996d5b9520aff5095100bb52fb67f96560f99633d081c04a3a9e01b"
SWIFT_SOURCES = [
    "Sources/Shared/MetalDevice.swift",
    "Sources/Shared/SimulationTypes3D.swift",
    "Sources/Shared/VolumeField3D.swift",
    "Sources/Shared/FluidSimulation3D.swift",
    "Sources/Shared/PressureProjection3D.swift",
    "Tests/Integration/fluid3d_float32_pcg_diagnostic.swift",
    "Tests/Integration/test_fluid3d.swift",
]
HASHED_SOURCES = SWIFT_SOURCES[:-1] + [
    "Sources/Shared/Shaders3D.metal",
    "Tests/Integration/fluid3d_reference.swift",
    "Tests/Integration/test_fluid3d.swift",
    "Tests/Integration/test_fluid3d.py",
]


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


class Fluid3DTests(unittest.TestCase):
    def test_volume_kernels_read_only_solver_status(self):
        source = (ROOT / "Sources/Shared/Shaders3D.metal").read_text()
        for name in [
            "fluid3DProjectPressureResidual", "fluid3DProjectPreconditioner",
            "fluid3DPCGUpdate", "fluid3DProjectDirection", "fluid3DNormalizePressureGauge",
        ]:
            start = source.index("kernel void " + name + "(")
            end = source.index("\n}", start)
            body = source[start:end]
            with self.subTest(kernel=name):
                self.assertRegex(body, r"device const float4 \*state")
                self.assertNotRegex(body, r"state\[\d+\](?:\.[xyzw])?\s*(?:[+*/-]?=)")

    def test_evidence_hashes_python_driver(self):
        self.assertIn("Tests/Integration/test_fluid3d.py", HASHED_SOURCES)

    def test_storage_and_abi(self):
        self.run_production_fixture("storage-abi")

    def test_advection_and_boundaries(self):
        self.run_production_fixture("advection-boundaries")

    def test_operators(self):
        self.run_production_fixture("operators")

    def test_projection(self):
        self.run_production_fixture("projection")

    def test_reset_and_finite(self):
        self.run_production_fixture("reset-finite")

    def run_production_fixture(self, fixture: str) -> None:
        evidence_dir = ROOT / ".build/fluid3d-evidence"
        reference_dir = ROOT / ".build/fluid3d-reference"
        evidence_dir.mkdir(parents=True, exist_ok=True)
        log_path = evidence_dir / f"{fixture}.log"

        missing = [str(ROOT / source) for source in HASHED_SOURCES if not (ROOT / source).is_file()]
        self.assertFalse(missing, "Missing required production/test sources:\n" + "\n".join(missing))

        reference_command = [
            sys.executable,
            str(ROOT / "Tests/Integration/test_fluid3d_reference.py"),
            "--export",
            str(reference_dir),
            "--check-contract",
        ]
        if fixture == "advection-boundaries":
            reference_command.extend(["--advection-fixtures", str(reference_dir)])
        reference_result = subprocess.run(
            reference_command, capture_output=True, text=True, timeout=600
        )
        self.assertEqual(
            reference_result.returncode,
            0,
            "CPU reference export failed; no GPU fixture may proceed:\n"
            + reference_result.stdout
            + reference_result.stderr,
        )
        manifest_path = reference_dir / "manifest.json"
        self.assertTrue(manifest_path.is_file(), "CPU reference export omitted manifest.json")
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        self.assertEqual(manifest.get("contractHash"), CONTRACT_HASH)
        projection_fixtures = {
            "zero_rhs",
            "constant_pressure",
            "alternating_pressure",
            "manufactured_cosine",
            "mixed_frequency_asymmetric",
            "wall_edge_corner",
            "divergence_free",
        }
        if fixture == "projection":
            self.assertEqual(
                {item["name"] for item in manifest["fixtures"]},
                projection_fixtures,
                "CPU oracle omitted a registered 64³ projection family",
            )
            projection_payloads = {
                item["fixture"]: item
                for item in manifest["binaryPayloads"]
                if item["fixture"] in projection_fixtures
            }
            self.assertEqual(
                set(projection_payloads),
                projection_fixtures,
                "CPU oracle must export independent inputs and outputs for all projection families",
            )
            for name, payload in projection_payloads.items():
                path = reference_dir / payload["file"]
                self.assertTrue(path.is_file(), f"Missing CPU projection payload for {name}")
                self.assertEqual(path.stat().st_size, payload["byteCount"], name)
                self.assertEqual(sha256(path), payload["sha256"], name)
        if fixture == "reset-finite":
            step_manifest = json.loads((reference_dir / "step-manifest.json").read_text())
            self.assertEqual(step_manifest["contractHash"], CONTRACT_HASH)
            self.assertTrue(step_manifest["finite"])
            step_payload = reference_dir / step_manifest["file"]
            self.assertEqual(step_payload.stat().st_size, step_manifest["byteCount"])
            self.assertEqual(sha256(step_payload), step_manifest["sha256"])
        advection_manifest_path = reference_dir / "advection-manifest.json"
        advection_manifest = None
        if fixture == "advection-boundaries":
            self.assertTrue(advection_manifest_path.is_file(), "CPU oracle omitted advection fixtures")
            advection_manifest = json.loads(advection_manifest_path.read_text(encoding="utf-8"))
            self.assertEqual(advection_manifest.get("contractHash"), CONTRACT_HASH)
            for case in advection_manifest["cases"]:
                payload = reference_dir / case["file"]
                self.assertTrue(payload.is_file(), f"CPU oracle payload is missing: {payload.name}")
                self.assertEqual(payload.stat().st_size, case["byteCount"])
                self.assertEqual(sha256(payload), case["sha256"])

        source_paths = [ROOT / source for source in SWIFT_SOURCES]
        with tempfile.TemporaryDirectory(prefix="fluid3d-production-") as temp_dir:
            executable = Path(temp_dir) / "fluid3d-check"
            compile_command = [
                "xcrun",
                "swiftc",
                "-swift-version",
                "6",
                "-parse-as-library",
                "-O",
                *map(str, source_paths),
                "-o",
                str(executable),
            ]
            compile_result = subprocess.run(
                compile_command, capture_output=True, text=True, timeout=300
            )
            self.assertEqual(
                compile_result.returncode,
                0,
                "Production 3D Swift fixture compilation failed:\n"
                + compile_result.stdout
                + compile_result.stderr,
            )

            settings_command = [
                "xcodebuild",
                "-project",
                str(ROOT / "FluidDynamicsMetal.xcodeproj"),
                "-scheme",
                "FluidDynamicsMetalOSX",
                "-configuration",
                "Debug",
                "-destination",
                "platform=macOS,arch=arm64",
                "CODE_SIGNING_ALLOWED=NO",
                "-showBuildSettings",
                "-json",
            ]
            settings_result = subprocess.run(
                settings_command, capture_output=True, text=True, timeout=120
            )
            self.assertEqual(
                settings_result.returncode,
                0,
                "Could not resolve the built Mac app's Metal library:\n"
                + settings_result.stdout
                + settings_result.stderr,
            )
            targets = json.loads(settings_result.stdout)
            app_settings = next(
                item["buildSettings"]
                for item in targets
                if item.get("target") == "FluidDynamicsMetalOSX"
            )
            metallib = (
                Path(app_settings["TARGET_BUILD_DIR"])
                / app_settings["WRAPPER_NAME"]
                / "Contents/Resources/default.metallib"
            )
            self.assertTrue(
                metallib.is_file(),
                "Fresh Mac Debug app metallib is missing; build the app before running GPU fixtures: "
                + str(metallib),
            )
            self.assertGreaterEqual(
                metallib.stat().st_mtime_ns,
                (ROOT / "Sources/Shared/Shaders3D.metal").stat().st_mtime_ns,
                "Production metallib predates Shaders3D.metal; rebuild Mac before GPU fixtures",
            )

            toolchain_result = subprocess.run(
                ["xcrun", "metal", "--version"],
                capture_output=True,
                text=True,
                timeout=120,
            )
            self.assertEqual(
                toolchain_result.returncode,
                0,
                "Metal Toolchain is unavailable:\n"
                + toolchain_result.stdout
                + toolchain_result.stderr,
            )

            run_command = [
                str(executable),
                str(metallib),
                str(reference_dir),
                fixture,
            ]
            run_result = subprocess.run(
                run_command,
                capture_output=True,
                text=True,
                timeout=1800 if fixture == "reset-finite" else 600,
                env=dict(os.environ, MTL_DEBUG_LAYER="1"),
            )
            log_path.write_text(
                "REFERENCE EXPORT\n"
                + reference_result.stdout
                + reference_result.stderr
                + "\nSWIFT COMPILE\n"
                + compile_result.stdout
                + compile_result.stderr
                + "\nPRODUCTION FIXTURE\n"
                + run_result.stdout
                + run_result.stderr,
                encoding="utf-8",
            )
            self.assertEqual(
                run_result.returncode,
                0,
                f"Production GPU fixture {fixture} failed; see {log_path}:\n"
                + run_result.stdout
                + run_result.stderr,
            )
            result_lines = [
                line.removeprefix("FLUID3D_RESULT=")
                for line in run_result.stdout.splitlines()
                if line.startswith("FLUID3D_RESULT=")
            ]
            self.assertEqual(len(result_lines), 1, "Swift fixture must emit exactly one result object")
            result = json.loads(result_lines[0])
            self.assertTrue(result.get("passed"), f"Fixture reported failure: {result}")

            report = {
                "schemaVersion": 1,
                "fixture": fixture,
                "referenceContractSHA256": manifest["contractHash"],
                "completeContractSHA256": sha256(ROOT / "docs/3d-numerical-contract.md"),
                "stepManifestSHA256": (
                    sha256(reference_dir / "step-manifest.json") if fixture == "reset-finite" else None
                ),
                "referenceManifestSHA256": sha256(manifest_path),
                "referenceAdvectionManifestSHA256": (
                    sha256(advection_manifest_path) if advection_manifest is not None else None
                ),
                "sourceSHA256": {
                    source: sha256(ROOT / source) for source in HASHED_SOURCES
                },
                "metallibSHA256": sha256(metallib),
                "commands": {
                    "referenceExport": reference_command,
                    "swiftCompile": compile_command,
                    "buildSettings": settings_command,
                    "fixture": run_command,
                },
                "metalToolchain": (toolchain_result.stdout + toolchain_result.stderr).strip(),
                "result": result,
            }
            report_path = evidence_dir / f"{fixture}.json"
            report_path.write_text(
                json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8"
            )
            print(f"PASS: {fixture}; evidence: {report_path}")


if __name__ == "__main__":
    unittest.main()
