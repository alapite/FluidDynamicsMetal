"""Production 3D Metal fixtures; GPU checks use the app's freshly built metallib.

CPU reference fixtures and versioned GPU evidence live under .build/fluid3d-reference
and .build/fluid3d-evidence. Missing hardware, compiler, library, or fixture failures
are errors; this harness never converts them into skips or fallback results.
"""

from __future__ import annotations

import argparse
import hashlib
import copy
from datetime import datetime, timezone
import json
import math
import os
import re
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
CONTRACT_HASH = "a7768571a996d5b9520aff5095100bb52fb67f96560f99633d081c04a3a9e01b"
INSPECTION_CONTRACT_HASH = "7f793d4ecfff13e7138a96e354f7597a9da9db88853c657d47a23ae09955e0c7"
SWIFT_SOURCES = [
    "Sources/Shared/MetalDevice.swift",
    "Sources/Shared/RenderShader.swift",
    "Sources/Shared/Slab.swift",
    "Sources/Shared/SimulationState.swift",
    "Sources/Shared/SimulationTypes.swift",
    "Sources/Shared/ExperimentRecipes.swift",
    "Sources/Shared/FluidSimulation.swift",
    "Sources/Shared/FieldVisualization.swift",
    "Sources/Shared/ParticleSystem.swift",
    "Sources/Shared/Renderer.swift",
    "Sources/Shared/SimulationTypes3D.swift",
    "Sources/Shared/VolumeField3D.swift",
    "Sources/Shared/ExperimentRecipes3D.swift",
    "Sources/Shared/FluidSimulation3D.swift",
    "Sources/Shared/FieldVisualization3D.swift",
    "Sources/Shared/InspectionState3D.swift",
    "Sources/Shared/Camera3D.swift",
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
SPATIAL_HASHED_SOURCES = HASHED_SOURCES + [
    "Tests/Integration/inspection3d_reference.swift",
    "Tests/Integration/test_inspection3d_reference.py",
    "docs/3d-inspection-contract.md",
]
PRODUCTION_FIXTURES = (
    "storage-abi",
    "advection-boundaries",
    "operators",
    "projection",
    "reset-finite",
    "spatial-slices",
    "slice-palette",
    "evolution-visibility",
    "transitions-and-failures",
    "renderer-steps-and-inactivity",
)
REGRESSION_MATRIX_REQUIRED = (
    "macBuild",
    "iosBuild",
    "macTests",
    "integrationTests",
    "iphoneHUD",
    "ipadHUD",
)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def validate_benchmark_manifest(manifest: object) -> list[str]:
    """Validate benchmark metadata and every measured solver/status sample."""
    errors: list[str] = []
    if not isinstance(manifest, dict):
        return ["benchmark manifest must be a JSON object"]

    def require(condition: bool, message: str) -> None:
        if not condition:
            errors.append(message)

    def is_number(value: object) -> bool:
        return isinstance(value, (int, float)) and not isinstance(value, bool)

    def finite(value: object) -> bool:
        return is_number(value) and math.isfinite(float(value))

    def positive_integer(value: object) -> bool:
        return isinstance(value, int) and not isinstance(value, bool) and value > 0

    def valid_sha(value: object) -> bool:
        return isinstance(value, str) and re.fullmatch(r"[0-9a-f]{64}", value) is not None

    require(manifest.get("schemaVersion") == 1, "unsupported benchmark schemaVersion")
    require(manifest.get("kind") == "fluid3d-benchmark", "kind must be fluid3d-benchmark")
    require(manifest.get("contractSHA256") == CONTRACT_HASH, "contract hash is stale or incorrect")
    require(valid_sha(manifest.get("metallibSHA256")), "metallib SHA-256 is missing or malformed")

    source_hashes = manifest.get("sourceSHA256")
    if not isinstance(source_hashes, dict):
        errors.append("sourceSHA256 must be an object")
    else:
        require(set(source_hashes) == set(HASHED_SOURCES), "source SHA-256 inventory is incomplete or unexpected")
        for path, digest in source_hashes.items():
            require(valid_sha(digest), f"source SHA-256 is malformed: {path}")

    environment = manifest.get("environment")
    if not isinstance(environment, dict):
        errors.append("environment metadata is missing")
    else:
        for key in ("device", "os", "xcode", "swift", "configuration"):
            require(isinstance(environment.get(key), str) and bool(environment[key].strip()),
                    f"environment.{key} is required")

    configurations = manifest.get("configurations")
    if not isinstance(configurations, dict):
        return errors + ["configurations must be an object"]
    expected_names = {"solverOnly", "solverAndFixedSlice"}
    require(set(configurations) == expected_names, "both solver-only and solver-plus-fixed-slice configurations are required")

    parity_fields = (
        "grid", "dt", "pressure", "seedSHA256", "warmupSteps", "measuredSteps",
        "inFlightLimit", "output", "viewport",
    )
    first_config = configurations.get("solverOnly")
    second_config = configurations.get("solverAndFixedSlice")
    if isinstance(first_config, dict) and isinstance(second_config, dict):
        for field in parity_fields:
            require(first_config.get(field) == second_config.get(field),
                    f"configuration parity mismatch: {field}")

    required_distributions = {
        "gpuMilliseconds": "gpuMilliseconds",
        "hostEncodeMilliseconds": "hostEncodeMilliseconds",
        "hostSubmitMilliseconds": "hostSubmitMilliseconds",
        "hostCompletionMilliseconds": "hostCompletionMilliseconds",
        "iterations": "iterations",
    }
    for key, config in configurations.items():
        if not isinstance(config, dict):
            errors.append(f"configuration {key} must be an object")
            continue
        label = f"configuration {key}"
        expected_mode = "solver-only" if key == "solverOnly" else "solver-plus-fixed-slice"
        require(config.get("mode") == expected_mode, f"{label} has the wrong mode label")
        require(config.get("grid") == [64, 64, 64], f"{label} must use the production 64^3 grid")
        require(finite(config.get("dt")) and math.isclose(float(config["dt"]), 1 / 60, rel_tol=1e-7),
                f"{label} must use contracted dt=1/60")
        pressure = config.get("pressure")
        require(isinstance(pressure, dict)
                and pressure.get("iterationCap") == 320
                and finite(pressure.get("dtInfTolerance"))
                and math.isclose(float(pressure["dtInfTolerance"]), 1e-5, rel_tol=1e-7),
                f"{label} must retain the contracted pressure cap and tolerance")
        require(valid_sha(config.get("seedSHA256")), f"{label} seed hash is missing or malformed")
        require(config.get("warmupSteps") == 60, f"{label} must record exactly 60 warm-up steps")
        require(config.get("measuredSteps") == 240, f"{label} must record exactly 240 measured steps")
        require(config.get("inFlightLimit") == 3, f"{label} must record the three-command in-flight limit")

        output = config.get("output")
        require(isinstance(output, dict)
                and output.get("allocated") is True
                and output.get("width") == 1280
                and output.get("height") == 720
                and output.get("pixelFormat") == "bgra8Unorm",
                f"{label} must allocate the 1280x720 bgra8Unorm output")
        viewport = config.get("viewport")
        require(isinstance(viewport, dict)
                and viewport.get("x") == 280
                and viewport.get("y") == 0
                and viewport.get("width") == 720
                and viewport.get("height") == 720,
                f"{label} must use the centered square 720 viewport")

        presentation = config.get("presentation")
        expected_slice = key == "solverAndFixedSlice"
        require(isinstance(presentation, dict)
                and presentation.get("kind") == "offscreen"
                and presentation.get("fixedSliceRendered") is expected_slice
                and presentation.get("displayedFPSClaim") is False
                and presentation.get("displayedFramePacing") == "NOT MEASURED"
                and presentation.get("displayedFPS") in (None, "NOT MEASURED"),
                f"{label} mislabels offscreen work as displayed frame pacing/FPS")

        validation = config.get("validation")
        require(isinstance(validation, dict)
                and validation.get("status") == "PASS"
                and validation.get("preflightFinite") is True
                and validation.get("preflightWallNormalsExactZero") is True
                and validation.get("postflightFinite") is True
                and validation.get("postflightWallNormalsExactZero") is True,
                f"{label} is missing passing pre/post numerical validation")

        inventory = config.get("resourceInventory")
        require(isinstance(inventory, dict), f"{label} resource inventory is missing")
        if isinstance(inventory, dict):
            texture_inventory = inventory.get("simulation3DTextures")
            pressure_inventory = inventory.get("pressure")
            staging_inventory = inventory.get("readbackStaging")
            retained_2d = inventory.get("retained2D")
            output_inventory = inventory.get("output")
            require(isinstance(texture_inventory, dict)
                    and positive_integer(texture_inventory.get("pingPongTextureCount"))
                    and positive_integer(texture_inventory.get("allocatedBytes")),
                    f"{label} 3D ping/pong texture inventory is incomplete")
            require(isinstance(pressure_inventory, dict)
                    and positive_integer(pressure_inventory.get("reductionWorkspaceBytes"))
                    and positive_integer(pressure_inventory.get("statusSlotBytes")),
                    f"{label} pressure/reduction/status inventory is incomplete")
            require(isinstance(staging_inventory, dict)
                    and positive_integer(staging_inventory.get("transientBytes")),
                    f"{label} readback staging inventory is incomplete")
            require(isinstance(retained_2d, dict)
                    and positive_integer(retained_2d.get("textureCount"))
                    and positive_integer(retained_2d.get("allocatedBytes")),
                    f"{label} retained 2D resource inventory is incomplete")
            require(isinstance(output_inventory, dict)
                    and output_inventory.get("allocated") is True
                    and positive_integer(output_inventory.get("allocatedBytes")),
                    f"{label} output texture allocation is missing")

        samples = config.get("samples")
        if not isinstance(samples, list):
            errors.append(f"{label} samples must be an array")
            continue
        require(len(samples) == 240, f"{label} must contain exactly 240 measured samples")
        sample_values: dict[str, list[float]] = {name: [] for name in required_distributions}
        cap_hits = 0
        for index, sample in enumerate(samples):
            if not isinstance(sample, dict):
                errors.append(f"{label} sample {index} must be an object")
                continue
            sample_label = f"{label} sample {index}"
            for field in ("gpuMilliseconds", "hostEncodeMilliseconds", "hostSubmitMilliseconds",
                          "hostCompletionMilliseconds"):
                value = sample.get(field)
                require(finite(value) and float(value) > 0,
                        f"{sample_label} has missing, nonfinite, or nonpositive {field}")
                if finite(value):
                    sample_values[field].append(float(value))
            require(sample.get("finite") is True, f"{sample_label} is not marked finite")
            projection = sample.get("projection")
            if not isinstance(projection, dict):
                errors.append(f"{sample_label} projection status is missing")
                continue
            require(projection.get("failure") == "none", f"{sample_label} reports solver failure")
            require(projection.get("converged") is True, f"{sample_label} did not converge")
            cap_hit = projection.get("capHit")
            require(cap_hit is False, f"{sample_label} hit the pressure iteration cap")
            cap_hits += int(cap_hit is True)
            iterations = projection.get("iterations")
            require(isinstance(iterations, int) and not isinstance(iterations, bool)
                    and 0 <= iterations <= 320,
                    f"{sample_label} has invalid pressure iteration count")
            if isinstance(iterations, int) and not isinstance(iterations, bool):
                sample_values["iterations"].append(float(iterations))
            for field, limit in (("trueResidualDTInf", 1e-5),
                                 ("projectedDivergenceDTInf", 1e-5),
                                 ("identityDTError", 2e-5)):
                value = projection.get(field)
                require(finite(value) and 0 <= float(value) <= limit,
                        f"{sample_label} has invalid or out-of-contract {field}")
                if finite(value):
                    sample_values.setdefault(field, []).append(float(value))
            wall = projection.get("maximumWallNormalValue")
            require(finite(wall) and float(wall) == 0,
                    f"{sample_label} has nonzero or nonfinite wall-normal flux")

        distributions = config.get("distributions")
        if not isinstance(distributions, dict):
            errors.append(f"{label} timing/iteration distributions are missing")
        else:
            for field in required_distributions:
                recorded = distributions.get(field)
                values = sample_values[field]
                require(isinstance(recorded, dict), f"{label} distribution {field} is missing")
                if not isinstance(recorded, dict) or not values:
                    continue
                ordered = sorted(values)
                expected = {
                    "min": ordered[0],
                    "median": (ordered[(len(ordered) - 1) // 2] + ordered[len(ordered) // 2]) / 2,
                    "p95": ordered[math.ceil(0.95 * len(ordered)) - 1],
                    "max": ordered[-1],
                }
                for statistic, computed in expected.items():
                    actual = recorded.get(statistic)
                    require(finite(actual) and math.isclose(float(actual), computed, rel_tol=1e-7, abs_tol=1e-9),
                            f"{label} distribution {field}.{statistic} disagrees with measured samples")
            require(distributions.get("capHitCount") == cap_hits,
                    f"{label} cap-hit distribution disagrees with measured status")

    if isinstance(first_config, dict) and isinstance(second_config, dict):
        require(first_config.get("seedSHA256") == second_config.get("seedSHA256"),
                "separately reset benchmark configurations must use identical seed hashes")
    return errors


def distribution(values: list[float]) -> dict[str, float]:
    ordered = sorted(values)
    if not ordered:
        raise ValueError("cannot summarize an empty sample set")
    return {
        "min": ordered[0],
        "median": (ordered[(len(ordered) - 1) // 2] + ordered[len(ordered) // 2]) / 2,
        "p95": ordered[math.ceil(0.95 * len(ordered)) - 1],
        "max": ordered[-1],
    }


def _capture(command: list[str], *, timeout: int = 120) -> str:
    result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=timeout)
    if result.returncode != 0:
        raise RuntimeError(
            f"Command failed ({result.returncode}): {' '.join(command)}\n"
            + result.stdout
            + result.stderr
        )
    return (result.stdout + result.stderr).strip()


def _portable_path(path: Path) -> str:
    resolved = path.resolve()
    try:
        return "~/" + resolved.relative_to(Path.home()).as_posix()
    except ValueError:
        try:
            return "<repo>/" + resolved.relative_to(ROOT).as_posix()
        except ValueError:
            return resolved.name


def _resolve_artifact_path(value: object) -> Path | None:
    if not isinstance(value, str) or not value:
        return None
    path = Path(value).expanduser()
    return path if path.is_absolute() else ROOT / path


def run_benchmark(evidence_dir: Path) -> Path:
    evidence_dir.mkdir(parents=True, exist_ok=True)
    reference_dir = ROOT / ".build/fluid3d-reference"
    export_command = [
        sys.executable,
        str(ROOT / "Tests/Integration/test_fluid3d_reference.py"),
        "--export",
        str(reference_dir),
        "--check-contract",
    ]
    export = subprocess.run(export_command, cwd=ROOT, capture_output=True, text=True, timeout=600)
    if export.returncode != 0:
        raise RuntimeError("CPU reference export failed:\n" + export.stdout + export.stderr)

    settings_command = [
        "xcodebuild", "-project", str(ROOT / "FluidDynamicsMetal.xcodeproj"),
        "-scheme", "FluidDynamicsMetalOSX", "-configuration", "Debug",
        "-destination", "platform=macOS,arch=arm64", "CODE_SIGNING_ALLOWED=NO",
        "-showBuildSettings", "-json",
    ]
    settings_output = _capture(settings_command, timeout=180)
    settings = json.loads(settings_output)
    app_settings = next(
        item["buildSettings"] for item in settings if item.get("target") == "FluidDynamicsMetalOSX"
    )
    metallib = (
        Path(app_settings["TARGET_BUILD_DIR"])
        / app_settings["WRAPPER_NAME"]
        / "Contents/Resources/default.metallib"
    )
    shader = ROOT / "Sources/Shared/Shaders3D.metal"
    if not metallib.is_file() or metallib.stat().st_mtime_ns < shader.stat().st_mtime_ns:
        raise RuntimeError(f"Fresh Mac Debug metallib is missing or stale; build the Mac scheme first: {metallib}")
    metal_version = _capture(["xcrun", "metal", "--version"])

    log_path = evidence_dir / "benchmark.log"
    with tempfile.TemporaryDirectory(prefix="fluid3d-benchmark-") as temporary:
        executable = Path(temporary) / "fluid3d-benchmark"
        compile_command = [
            "xcrun", "swiftc", "-swift-version", "6", "-parse-as-library", "-O",
            *[str(ROOT / source) for source in SWIFT_SOURCES], "-o", str(executable),
        ]
        compile_result = subprocess.run(
            compile_command, cwd=ROOT, capture_output=True, text=True, timeout=300
        )
        log_parts = ["SWIFT COMPILE\n", compile_result.stdout, compile_result.stderr]
        if compile_result.returncode != 0:
            log_path.write_text("".join(log_parts), encoding="utf-8")
            raise RuntimeError(f"Benchmark harness compilation failed; see {log_path}:\n" + compile_result.stderr)

        fixture_command = [str(executable), str(metallib), str(reference_dir), "benchmark"]
        environment = dict(os.environ)
        environment.pop("MTL_DEBUG_LAYER", None)
        environment.pop("MTL_CAPTURE_ENABLED", None)
        run_result = subprocess.run(
            fixture_command, cwd=ROOT, capture_output=True, text=True,
            timeout=3600, env=environment,
        )
        log_parts.extend(["\nPRODUCTION BENCHMARK\n", run_result.stdout, run_result.stderr])
        log_path.write_text("".join(log_parts), encoding="utf-8")
        if run_result.returncode != 0:
            raise RuntimeError(f"Production benchmark failed; see {log_path}:\n" + run_result.stdout + run_result.stderr)
        result_lines = [
            line.removeprefix("FLUID3D_RESULT=")
            for line in run_result.stdout.splitlines()
            if line.startswith("FLUID3D_RESULT=")
        ]
        if len(result_lines) != 1:
            raise RuntimeError(f"Benchmark must emit exactly one result object; see {log_path}")
        result = json.loads(result_lines[0])
        if result.get("passed") is not True or result.get("fixture") != "benchmark":
            raise RuntimeError(f"Benchmark reported a failure; see {log_path}: {result}")

    configurations = result.get("configurations")
    if not isinstance(configurations, list):
        raise RuntimeError("Benchmark omitted its two configurations")
    keyed_configurations: dict[str, dict] = {}
    for config in configurations:
        if not isinstance(config, dict):
            raise RuntimeError("Benchmark configuration is not an object")
        mode = config.get("mode")
        key = "solverOnly" if mode == "solver-only" else "solverAndFixedSlice" if mode == "solver-plus-fixed-slice" else None
        if key is None or key in keyed_configurations:
            raise RuntimeError(f"Unexpected or duplicate benchmark mode: {mode}")
        samples = config.get("samples")
        if not isinstance(samples, list):
            raise RuntimeError(f"Benchmark mode {mode} omitted samples")
        for field in (
            "gpuMilliseconds", "hostEncodeMilliseconds", "hostSubmitMilliseconds",
            "hostCompletionMilliseconds",
        ):
            config.setdefault("distributions", {})[field] = distribution(
                [float(sample[field]) for sample in samples]
            )
        config.setdefault("distributions", {})["iterations"] = distribution(
            [float(sample["projection"]["iterations"]) for sample in samples]
        )
        config["distributions"]["capHitCount"] = sum(
            sample["projection"]["capHit"] is True for sample in samples
        )
        keyed_configurations[key] = config
    if set(keyed_configurations) != {"solverOnly", "solverAndFixedSlice"}:
        raise RuntimeError("Benchmark must include solver-only and solver-plus-fixed-slice runs")

    current_sources = {source: sha256(ROOT / source) for source in HASHED_SOURCES}
    complete_contract_hash = sha256(ROOT / "docs/3d-numerical-contract.md")
    host_model = _capture(["sysctl", "-n", "hw.model"])
    chip = _capture(["sysctl", "-n", "machdep.cpu.brand_string"])
    os_version = _capture(["sw_vers", "-productVersion"])
    xcode_version = _capture(["xcodebuild", "-version"])
    swift_version = _capture(["swift", "--version"])
    benchmark_manifest = {
        "schemaVersion": 1,
        "kind": "fluid3d-benchmark",
        "generatedAtUTC": datetime.now(timezone.utc).replace(microsecond=0).isoformat(),
        "contractSHA256": CONTRACT_HASH,
        "completeContractSHA256": complete_contract_hash,
        "referenceManifestSHA256": sha256(reference_dir / "manifest.json"),
        "metallibPath": _portable_path(metallib),
        "metallibSHA256": sha256(metallib),
        "metalToolchain": metal_version,
        "sourceSHA256": current_sources,
        "environment": {
            "device": result.get("device", ""),
            "hostModel": host_model,
            "chip": chip,
            "os": os_version,
            "xcode": xcode_version,
            "swift": swift_version,
            "configuration": "Debug",
            "architecture": "arm64",
            "metalValidation": "disabled for timed run (MTL_DEBUG_LAYER unset)",
        },
        "commands": {
            "referenceExport": ["python3", "Tests/Integration/test_fluid3d_reference.py", "--export", ".build/fluid3d-reference", "--check-contract"],
            "swiftCompile": ["xcrun", "swiftc", "-swift-version", "6", "-parse-as-library", "-O", "<production harness sources>", "-o", "<temporary executable>"],
            "benchmark": ["<temporary executable>", "<fresh Mac Debug metallib>", ".build/fluid3d-reference", "benchmark"],
        },
        "timedSegment": result.get("timedSegment"),
        "grid": result.get("grid"),
        "stepDefinition": result.get("stepDefinition"),
        "seedSHA256": result.get("seedSHA256"),
        "output": result.get("output"),
        "viewport": result.get("viewport"),
        "configurations": keyed_configurations,
        "result": {"passed": True, "fixture": "benchmark"},
    }
    schema_errors = validate_benchmark_manifest(benchmark_manifest)
    if schema_errors:
        raise RuntimeError("Generated benchmark evidence failed schema validation:\n- " + "\n- ".join(schema_errors))
    benchmark_path = evidence_dir / "benchmark.json"
    benchmark_path.write_text(
        json.dumps(benchmark_manifest, indent=2, sort_keys=True, allow_nan=False) + "\n",
        encoding="utf-8",
    )
    print(f"PASS: production solver/slice benchmark; evidence: {benchmark_path}")
    print(f"LOG: {log_path}")
    for key, config in keyed_configurations.items():
        gpu = config["distributions"]["gpuMilliseconds"]
        host = config["distributions"]["hostCompletionMilliseconds"]
        print(f"{key}: GPU median/p95/max {gpu['median']:.3f}/{gpu['p95']:.3f}/{gpu['max']:.3f} ms; "
              f"submit-to-completion median/p95/max {host['median']:.3f}/{host['p95']:.3f}/{host['max']:.3f} ms")
    print("Displayed frame pacing: NOT MEASURED (offscreen work is not FPS)")
    return benchmark_path


def validate_regression_matrix(matrix: object) -> list[str]:
    errors: list[str] = []
    if not isinstance(matrix, dict):
        return ["regression matrix must be an object"]
    if matrix.get("schemaVersion") != 1 or matrix.get("kind") != "fluid3d-regression-matrix":
        errors.append("regression matrix schemaVersion/kind is unsupported")
    results = matrix.get("results")
    if not isinstance(results, dict):
        return errors + ["regression matrix results are missing"]
    for name in REGRESSION_MATRIX_REQUIRED:
        item = results.get(name)
        if not isinstance(item, dict):
            errors.append(f"regression matrix is missing {name}")
            continue
        status = item.get("status")
        if status not in {"PASS", "NOT TESTED"}:
            errors.append(f"{name} has invalid status {status!r}")
            continue
        if name in {"macBuild", "iosBuild", "macTests", "integrationTests"} and status != "PASS":
            errors.append(f"required regression check {name} is not PASS")
        if status == "NOT TESTED":
            if not isinstance(item.get("reason"), str) or not item["reason"].strip():
                errors.append(f"{name} NOT TESTED entry must include a reason")
            continue
        if item.get("exitCode") != 0:
            errors.append(f"{name} PASS entry must record exitCode 0")
        log_path = _resolve_artifact_path(item.get("logPath"))
        if log_path is None or not log_path.is_file():
            errors.append(f"{name} command log is missing")
        elif item.get("logSHA256") != sha256(log_path):
            errors.append(f"{name} command log SHA-256 is stale")
        if name in {"macTests", "iphoneHUD", "ipadHUD"}:
            if not isinstance(item.get("testCount"), int) or item["testCount"] <= 0:
                errors.append(f"{name} must record a positive test count")
            if status == "PASS":
                result_bundle = _resolve_artifact_path(item.get("xcresultPath"))
                if result_bundle is None or not result_bundle.exists():
                    errors.append(f"{name} xcresult bundle is missing")
    coverage = matrix.get("coverage")
    if not isinstance(coverage, dict):
        errors.append("regression matrix coverage labels are missing")
    else:
        if coverage.get("macOS26Runtime") != "NOT TESTED":
            errors.append("macOS 26 runtime must remain NOT TESTED on this newer host")
        if coverage.get("physicalMultitouch") != "NOT TESTED":
            errors.append("physical-device multitouch must remain NOT TESTED")
        if coverage.get("manualVisualReview") != "PENDING":
            errors.append("manual visual review must remain PENDING for plan 07-09")
    return errors


def _validate_fixture_metrics(fixture: str, report: dict) -> list[str]:
    errors: list[str] = []
    result = report.get("result")
    if not isinstance(result, dict) or result.get("passed") is not True or result.get("fixture") != fixture:
        return [f"{fixture} does not contain a passing production fixture result"]
    if fixture == "evolution-visibility":
        observations = result.get("observations")
        if not isinstance(observations, list):
            return ["evolution-visibility observations are missing"]
        by_step = {item.get("step"): item for item in observations if isinstance(item, dict)}
        for step, peak_min, count_min in ((0, 0.5, 0), (24, 0.05, 8), (48, 0.05, 8)):
            item = by_step.get(step)
            if not isinstance(item, dict):
                errors.append(f"evolution-visibility is missing step {step}")
                continue
            if not isinstance(item.get("slicePeak"), (int, float)) or item["slicePeak"] < peak_min:
                errors.append(f"evolution-visibility step {step} peak misses its preregistered gate")
            if step and item.get("sliceCountAtLeast0_02", 0) < count_min:
                errors.append(f"evolution-visibility step {step} count misses its preregistered gate")
            if item.get("projection", {}).get("failure") != "none" or not item.get("projection", {}).get("converged"):
                errors.append(f"evolution-visibility step {step} projection status failed")
        if result.get("velocityChangeNormalizedByResetSpeed", {}).keys() != {"u", "v", "w"}:
            errors.append("evolution-visibility must report all three velocity components")
        elif any(value < 1e-4 for value in result["velocityChangeNormalizedByResetSpeed"].values()):
            errors.append("evolution-visibility component evolution misses its threshold")
        if result.get("depthVariationNormalizedByResetSpeed", 0) < 1e-3:
            errors.append("evolution-visibility depth variation misses its threshold")
        if result.get("maximumProbeZTravelCells", 0) < 0.5:
            errors.append("evolution-visibility dye-seeded probe misses its Z-travel threshold")
        analytic = result.get("analyticReferenceTrajectory", {})
        if not isinstance(analytic, dict) or analytic.get("finite") is not True or analytic.get("plane_rms_arc_ratio", 0) < 0.01:
            errors.append("evolution-visibility analytic trajectory misses its finite/nonplanar threshold")
    elif fixture == "reset-finite":
        snapshots = result.get("snapshots")
        if not isinstance(snapshots, list) or not snapshots or any(item.get("finite") is not True for item in snapshots):
            errors.append("reset-finite snapshots are missing or nonfinite")
    elif fixture == "slice-palette":
        if result.get("renderingReadOnly") is not True or result.get("finite") is not True:
            errors.append("slice-palette read-only/finite result is missing")
        if result.get("sampledPlanes") != [31, 32] or result.get("sampleWeights") != [0.5, 0.5]:
            errors.append("slice-palette does not report the central 31/32 midpoint")
    elif fixture == "spatial-slices":
        if result.get("cubeEdgesChecked") != 12:
            errors.append("spatial-slices must verify all 12 projected cube edges")
        scale_ratio = result.get("cubeGuidePointScaleRatio")
        if not isinstance(scale_ratio, (int, float)) or not 3.2 <= scale_ratio <= 4.8:
            errors.append("spatial-slices guide-pixel coverage must scale with 1x/2x point size")
        if result.get("cubeDepthAttachmentReuseAllocations") != 2:
            errors.append("spatial-slices repeated-size checks must allocate one depth attachment per size")
        if result.get("cubeSpatialPipelineAllocations") != 2:
            errors.append("spatial-slices must reuse its sheet and guide pipelines across viewport changes")
        for key in (
            "checkedPipelineAllocationFailure",
            "checkedDepthAllocationFailure",
            "emptyDyeGuidesVisible",
            "cameraMatrixChanged",
            "cameraChangesProjectedImage",
            "resizePreservesInspectionState",
            "resizePreservesBothSimulationGenerations",
            "invalidDestinationFormatRejected",
            "invalidViewportRejected",
            "zeroExtentDeferredWithoutDepthAllocation",
        ):
            if result.get(key) is not True:
                errors.append(f"spatial-slices is missing required regression evidence: {key}")
    return errors


def validate_evidence_bundle(evidence_dir: Path, *, quick: bool) -> list[str]:
    errors: list[str] = []
    benchmark_path = evidence_dir / "benchmark.json"
    if not benchmark_path.is_file():
        return [f"missing benchmark manifest: {benchmark_path}"]
    try:
        benchmark = json.loads(benchmark_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        return [f"could not read benchmark manifest: {error}"]
    errors.extend(validate_benchmark_manifest(benchmark))

    current_sources: dict[str, str] = {}
    for source in HASHED_SOURCES:
        path = ROOT / source
        if not path.is_file():
            errors.append(f"missing hashed source: {source}")
            continue
        current_sources[source] = sha256(path)
    if benchmark.get("sourceSHA256") != current_sources:
        errors.append("benchmark source hashes are stale")
    if benchmark.get("completeContractSHA256") != sha256(ROOT / "docs/3d-numerical-contract.md"):
        errors.append("complete numerical contract hash is stale")
    reference_manifest = ROOT / ".build/fluid3d-reference/manifest.json"
    if not reference_manifest.is_file():
        errors.append("CPU reference manifest is missing")
    elif benchmark.get("referenceManifestSHA256") != sha256(reference_manifest):
        errors.append("benchmark CPU reference manifest hash is stale")
    metallib_path = _resolve_artifact_path(benchmark.get("metallibPath"))
    if metallib_path is None or not metallib_path.is_file():
        errors.append("fresh production metallib path is missing")
        metallib_hash = None
    else:
        metallib_hash = sha256(metallib_path)
        if benchmark.get("metallibSHA256") != metallib_hash:
            errors.append("benchmark metallib hash is stale")

    for fixture in PRODUCTION_FIXTURES:
        report_path = evidence_dir / f"{fixture}.json"
        if not report_path.is_file():
            errors.append(f"missing required production fixture evidence: {report_path.name}")
            continue
        try:
            report = json.loads(report_path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as error:
            errors.append(f"could not read {report_path.name}: {error}")
            continue
        if report.get("schemaVersion") != 1 or report.get("fixture") != fixture:
            errors.append(f"{report_path.name} has an unsupported schema or fixture identity")
        fixture_sources = current_sources
        if fixture == "spatial-slices":
            fixture_sources = {}
            for source in SPATIAL_HASHED_SOURCES:
                path = ROOT / source
                if not path.is_file():
                    errors.append(f"missing spatial hashed source: {source}")
                    continue
                fixture_sources[source] = sha256(path)
        if report.get("sourceSHA256") != fixture_sources:
            errors.append(f"{report_path.name} source hashes are stale")
        if metallib_hash and report.get("metallibSHA256") != metallib_hash:
            errors.append(f"{report_path.name} metallib hash is stale")
        reference_hash = report.get("referenceManifestSHA256")
        if reference_manifest.is_file() and reference_hash != sha256(reference_manifest):
            errors.append(f"{report_path.name} reference manifest hash is stale")
        if not quick:
            errors.extend(_validate_fixture_metrics(fixture, report))
        result = report.get("result")
        if isinstance(result, dict):
            capture_directory = (
                ROOT / ".build/inspection3d-evidence"
                if fixture == "spatial-slices"
                else evidence_dir
            )
            for capture in result.get("captures", []):
                if not isinstance(capture, str) or not (capture_directory / capture).is_file():
                    errors.append(f"{report_path.name} references a missing capture: {capture}")

    matrix_path = evidence_dir / "regression-matrix.json"
    if not matrix_path.is_file():
        errors.append(f"missing regression/build outcome evidence: {matrix_path.name}")
    else:
        try:
            matrix = json.loads(matrix_path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as error:
            errors.append(f"could not read regression matrix: {error}")
        else:
            errors.extend(validate_regression_matrix(matrix))

    if errors:
        return errors
    if quick:
        return []

    for key, config in benchmark["configurations"].items():
        quality = config.get("qualitySummary")
        if not isinstance(quality, dict) or quality.get("failedStatusCount") != 0 or quality.get("capHitCount") != 0:
            errors.append(f"{key} quality summary contains failure or cap-hit statuses")
        validation = config.get("validation", {})
        if validation.get("allWarmupAndMeasuredStatusesPassed") is not True:
            errors.append(f"{key} did not validate every warm-up and measured projection status")
        if validation.get("postflightStep") != 300:
            errors.append(f"{key} postflight did not follow all 300 reset-relative advances")
        changes = validation.get("changedFields", {})
        if set(changes) != {"u", "v", "w", "dye"} or any(
            not isinstance(value, (int, float)) or not math.isfinite(value) or value <= 0
            for value in changes.values()
        ):
            errors.append(f"{key} did not demonstrate finite evolution in all transported fields")
    return errors


class Fluid3DTests(unittest.TestCase):
    def test_evidence_schema(self):
        def sample():
            return {
                "gpuMilliseconds": 1.25,
                "hostEncodeMilliseconds": 0.1,
                "hostSubmitMilliseconds": 0.01,
                "hostCompletionMilliseconds": 1.4,
                "finite": True,
                "projection": {
                    "failure": "none",
                    "converged": True,
                    "capHit": False,
                    "iterations": 144,
                    "trueResidualDTInf": 1e-6,
                    "projectedDivergenceDTInf": 1e-6,
                    "identityDTError": 1e-7,
                    "maximumWallNormalValue": 0.0,
                },
            }

        def configuration(name, with_slice):
            samples = [sample() for _ in range(240)]
            return {
                "mode": name,
                "grid": [64, 64, 64],
                "dt": 1 / 60,
                "pressure": {"iterationCap": 320, "dtInfTolerance": 1e-5},
                "seedSHA256": "c" * 64,
                "warmupSteps": 60,
                "measuredSteps": 240,
                "inFlightLimit": 3,
                "output": {
                    "allocated": True,
                    "width": 1280,
                    "height": 720,
                    "pixelFormat": "bgra8Unorm",
                },
                "viewport": {"x": 280, "y": 0, "width": 720, "height": 720},
                "presentation": {
                    "kind": "offscreen",
                    "fixedSliceRendered": with_slice,
                    "displayedFPSClaim": False,
                    "displayedFramePacing": "NOT MEASURED",
                },
                "validation": {
                    "status": "PASS",
                    "preflightFinite": True,
                    "preflightWallNormalsExactZero": True,
                    "postflightFinite": True,
                    "postflightWallNormalsExactZero": True,
                },
                "resourceInventory": {
                    "simulation3DTextures": {"pingPongTextureCount": 32, "allocatedBytes": 1000},
                    "pressure": {"reductionWorkspaceBytes": 256, "statusSlotBytes": 304},
                    "readbackStaging": {"transientBytes": 512},
                    "retained2D": {"textureCount": 12, "allocatedBytes": 1024},
                    "output": {"allocated": True, "allocatedBytes": 4096},
                },
                "distributions": {
                    "gpuMilliseconds": {"min": 1.25, "median": 1.25, "p95": 1.25, "max": 1.25},
                    "hostEncodeMilliseconds": {"min": 0.1, "median": 0.1, "p95": 0.1, "max": 0.1},
                    "hostSubmitMilliseconds": {"min": 0.01, "median": 0.01, "p95": 0.01, "max": 0.01},
                    "hostCompletionMilliseconds": {"min": 1.4, "median": 1.4, "p95": 1.4, "max": 1.4},
                    "iterations": {"min": 144, "median": 144, "p95": 144, "max": 144},
                    "capHitCount": 0,
                },
                "samples": samples,
            }

        valid = {
            "schemaVersion": 1,
            "kind": "fluid3d-benchmark",
            "contractSHA256": CONTRACT_HASH,
            "metallibSHA256": "a" * 64,
            "sourceSHA256": {source: "b" * 64 for source in HASHED_SOURCES},
            "environment": {
                "device": "Synthetic Apple GPU",
                "os": "synthetic",
                "xcode": "synthetic",
                "swift": "synthetic",
                "configuration": "Debug",
            },
            "configurations": {
                "solverOnly": configuration("solver-only", False),
                "solverAndFixedSlice": configuration("solver-plus-fixed-slice", True),
            },
        }
        self.assertEqual(validate_benchmark_manifest(valid), [])

        invalid_cases = []
        missing_gpu_time = copy.deepcopy(valid)
        del missing_gpu_time["configurations"]["solverOnly"]["samples"][0]["gpuMilliseconds"]
        invalid_cases.append(("missing GPU time", missing_gpu_time))

        nonfinite_gpu_time = copy.deepcopy(valid)
        nonfinite_gpu_time["configurations"]["solverOnly"]["samples"][0]["gpuMilliseconds"] = math.inf
        invalid_cases.append(("nonfinite GPU time", nonfinite_gpu_time))

        stale_contract = copy.deepcopy(valid)
        stale_contract["contractSHA256"] = "0" * 64
        invalid_cases.append(("stale contract hash", stale_contract))

        mismatched_seed = copy.deepcopy(valid)
        mismatched_seed["configurations"]["solverAndFixedSlice"]["seedSHA256"] = "d" * 64
        invalid_cases.append(("configuration seed mismatch", mismatched_seed))

        mislabeled_fps = copy.deepcopy(valid)
        mislabeled_fps["configurations"]["solverAndFixedSlice"]["presentation"]["displayedFPSClaim"] = True
        invalid_cases.append(("offscreen displayed-FPS claim", mislabeled_fps))

        cap_hit = copy.deepcopy(valid)
        cap_hit["configurations"]["solverOnly"]["samples"][0]["projection"]["capHit"] = True
        invalid_cases.append(("pressure iteration cap hit", cap_hit))

        undersized_run = copy.deepcopy(valid)
        undersized_run["configurations"]["solverOnly"]["samples"].pop()
        invalid_cases.append(("wrong measured sample count", undersized_run))

        missing_inventory = copy.deepcopy(valid)
        del missing_inventory["configurations"]["solverAndFixedSlice"]["resourceInventory"]["pressure"]
        invalid_cases.append(("incomplete pressure resource inventory", missing_inventory))

        for label, manifest in invalid_cases:
            with self.subTest(case=label):
                self.assertTrue(validate_benchmark_manifest(manifest), label)

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

    def test_spatial_source_inventory_is_separate_from_historical_fixture_inventory(self):
        self.assertEqual(SPATIAL_HASHED_SOURCES[:len(HASHED_SOURCES)], HASHED_SOURCES)
        self.assertIn("Tests/Integration/inspection3d_reference.swift", SPATIAL_HASHED_SOURCES)
        self.assertIn("Tests/Integration/test_inspection3d_reference.py", SPATIAL_HASHED_SOURCES)
        self.assertIn("docs/3d-inspection-contract.md", SPATIAL_HASHED_SOURCES)
        self.assertNotIn("Tests/Integration/inspection3d_reference.swift", HASHED_SOURCES)

    def test_spatial_fixture_evidence_requires_cube_resource_and_camera_checks(self):
        report = {
            "result": {
                "passed": True,
                "fixture": "spatial-slices",
                "cubeEdgesChecked": 12,
                "cubeGuidePointScaleRatio": 4.0,
                "cubeDepthAttachmentReuseAllocations": 2,
                "cubeSpatialPipelineAllocations": 2,
                "checkedPipelineAllocationFailure": True,
                "checkedDepthAllocationFailure": True,
                "emptyDyeGuidesVisible": True,
                "cameraMatrixChanged": True,
                "cameraChangesProjectedImage": True,
                "resizePreservesInspectionState": True,
                "resizePreservesBothSimulationGenerations": True,
                "invalidDestinationFormatRejected": True,
                "invalidViewportRejected": True,
                "zeroExtentDeferredWithoutDepthAllocation": True,
            }
        }
        self.assertEqual(_validate_fixture_metrics("spatial-slices", report), [])
        self.assertTrue(
            validate_benchmark_manifest(report),
            "A spatial fixture report must not be valid solver/slice benchmark evidence",
        )
        report["result"]["cubeEdgesChecked"] = 11
        errors = _validate_fixture_metrics("spatial-slices", report)
        self.assertIn("spatial-slices must verify all 12 projected cube edges", errors)

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

    def test_slice_and_palette(self):
        self.run_production_fixture("slice-palette")

    def test_spatial_slices(self):
        self.run_production_fixture("spatial-slices")

    def test_evolution_and_visibility(self):
        self.run_production_fixture("evolution-visibility")

    def test_transitions_and_failures(self):
        self.run_production_fixture("transitions-and-failures")

    def test_renderer_steps_and_inactivity(self):
        self.run_production_fixture("renderer-steps-and-inactivity")

    def run_production_fixture(self, fixture: str) -> None:
        evidence_dir = ROOT / ".build/fluid3d-evidence"
        reference_dir = ROOT / ".build/fluid3d-reference"
        evidence_dir.mkdir(parents=True, exist_ok=True)
        log_path = evidence_dir / f"{fixture}.log"

        fixture_sources = SPATIAL_HASHED_SOURCES if fixture == "spatial-slices" else HASHED_SOURCES
        missing = [str(ROOT / source) for source in fixture_sources if not (ROOT / source).is_file()]
        self.assertFalse(missing, "Missing required production/test sources:\n" + "\n".join(missing))

        if fixture == "spatial-slices":
            reference_dir = ROOT / ".build/inspection3d-reference"
            reference_command = [
                sys.executable,
                "-m",
                "unittest",
                "Tests.Integration.test_inspection3d_reference",
            ]
        else:
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
        self.assertEqual(
            manifest.get("contractHash"),
            INSPECTION_CONTRACT_HASH if fixture == "spatial-slices" else CONTRACT_HASH,
        )
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
                timeout=1800 if fixture in {"reset-finite", "evolution-visibility"} else 600,
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
                    source: sha256(ROOT / source) for source in fixture_sources
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
            if fixture == "evolution-visibility":
                recipe_path = evidence_dir / "recipe.json"
                recipe_path.write_text(
                    json.dumps(
                        {
                            "schemaVersion": 1,
                            "fixture": fixture,
                            "referenceContractSHA256": manifest["contractHash"],
                            "sourceSHA256": report["sourceSHA256"],
                            "result": result,
                        },
                        indent=2,
                        sort_keys=True,
                    )
                    + "\n",
                    encoding="utf-8",
                )
                print(f"RECIPE EVIDENCE: {recipe_path}")
            print(f"PASS: {fixture}; evidence: {report_path}")


def main() -> int:
    parser = argparse.ArgumentParser(description="Production 3D Metal fixtures and evidence validation")
    actions = parser.add_mutually_exclusive_group()
    actions.add_argument("--benchmark", action="store_true", help="run solver-only and solver-plus-slice baselines")
    actions.add_argument("--check-evidence", action="store_true", help="validate current 3D evidence artifacts")
    parser.add_argument("--quick", action="store_true", help="check schema, hashes, and required files only")
    parser.add_argument(
        "--evidence-dir",
        type=Path,
        default=ROOT / ".build/fluid3d-evidence",
        help="evidence directory (default: .build/fluid3d-evidence)",
    )
    args, unittest_args = parser.parse_known_args()
    if args.quick and not args.check_evidence:
        parser.error("--quick is valid only with --check-evidence")
    if args.benchmark:
        try:
            run_benchmark(args.evidence_dir.resolve())
        except (OSError, RuntimeError, ValueError, KeyError, IndexError) as error:
            print(f"ERROR: {error}", file=sys.stderr)
            return 1
        return 0
    if args.check_evidence:
        errors = validate_evidence_bundle(args.evidence_dir.resolve(), quick=args.quick)
        if errors:
            print("FAIL: evidence validation found issues:")
            for error in errors:
                print(f"- {error}")
            return 1
        if args.quick:
            print("PASS: evidence schema, hashes, and required files are current. No numerical PASS is asserted by --quick.")
        else:
            print("PASS: current production evidence and regression matrix validated. Manual visual review remains PENDING.")
        return 0
    unittest.main(argv=[sys.argv[0], *unittest_args])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
