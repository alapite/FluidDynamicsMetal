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
import time
import unittest


ROOT = Path(__file__).resolve().parents[2]
CONTRACT_HASH = "a7768571a996d5b9520aff5095100bb52fb67f96560f99633d081c04a3a9e01b"
INSPECTION_CONTRACT_HASH = "ac824cffb3cb3db141cf1c03f9425cd67797db0586246480a258ddd06a502cbb"
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
    "Sources/Shared/TracerSystem3D.swift",
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
    "Sources/macOS/RenderViewController.swift",
    "Sources/iOS/RenderViewController.swift",
    "FluidDynamicsMetal.xcodeproj/project.pbxproj",
    "Tests/UI/macOS/HUDUITests.swift",
    "Tests/UI/iOS/HUDUITests.swift",
    "Tests/Integration/test_inspection3d_state.swift",
    "Tests/Integration/test_inspection3d_state.py",
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
    "inspection-routing",
    "tracer-evolution",
    "tracer-occlusion",
    "inspection-independence",
)
SPATIAL_FIXTURES = frozenset({"spatial-slices", "tracer-evolution", "tracer-occlusion", "inspection-independence"})
REGRESSION_MATRIX_REQUIRED = (
    "macBuild",
    "iosBuild",
    "macTests",
    "integrationTests",
    "iphoneHUD",
    "ipadHUD",
)

# Human-calibrated early-window visibility amendment (docs/3d-numerical-contract.md, UAT G-07-2).
# These mirror the amendment thresholds; the validator never trusts an emitted `passed` flag.
EVOLUTION_OBSERVATION_STEPS = (0, 1, 10, 20, 24, 48, 72)
EVOLUTION_CALIBRATED_GATES = {
    "step10RMSFromStep0Minimum": 0.025,
    "step20RMSFromStep0Minimum": 0.04,
    "encodedChangeThreshold": 32,
    "step10EncodedChangeCountMinimum": 100,
    "sectionAreaThreshold": 0.1,
    "step0SectionAreaMinimum": 100,
    "step48SectionAreaRelativeChangeMinimum": 0.30,
    "earlyWindowSteps": [10, 20, 24, 48],
    "earlyWindowPeakMinimum": 0.30,
    "earlyWindowSectionAreaMinimum": 50,
}
# Larger-blob, square-root display and 3D lesson-length amendment (2026-11-21) item 6; supersedes
# item 3 of the 07-11 amendment.
LESSON_RECIPE_ENVELOPE = {
    "seedMaximumVectorSpeed": (0.12, 0.17),
    "blobRadius": (0.20, 0.26),
    "blobPeak": (1.0, 1.25),
    "blobCenterCoordinate": (0.30, 0.70),
    "wallClearanceMinimum": 0.06,
    "equatorOffsetOverRadius": (0.30, 0.60),
    "tolerance": 1e-6,
}
LESSON_RECIPE_600 = {
    "steps": 600,
    "inputDivergenceLimit": 9e-4,
    "volumePeakMinimum": 0.05,
    "checkpointSteps": [100, 200, 300, 400, 500, 600],
    "iterationCap": 320,
}
# Larger-blob, square-root display and 3D lesson-length amendment (2026-11-21) items 2-4; equal to
# the gates dict the evolution-visibility fixture emits.
LARGER_BLOB_GATES = {
    "step0SectionAreaMinimum": 250,
    "step0DisplayVisibleAreaMinimum": 300,
    "displayLightnessThreshold": 50,
    "fadeFraction": 0.5,
    "returnDisplayVisibleAreaMinimum": 150,
    "returnMaximumLightnessMinimum": 60,
    "returnTailSteps": 100,
    "noFadeVisibleAreaMinimum": 150,
    "noFadeWindowSteps": 1200,
    "lessonLengthChoices": [1200, 1500, 1800],
    "checkpointInterval": 50,
}
THREE_D_LESSON_HORIZON = {
    "horizonSteps": 1800,
    "checkpointInterval": 50,
    "lessonLengthChoices": [1200, 1500, 1800],
    "inputDivergenceLimit": 9e-4,
    "volumePeakMinimum": 0.05,
    "iterationCap": 320,
}


def _display_lightness(red: int, green: int, blue: int) -> float:
    """CIE L* of one encoded sRGB pixel (bytes 0-255), as defined by the 2026-11-21 amendment."""

    def linear(byte: int) -> float:
        value = byte / 255
        return value / 12.92 if value <= 0.04045 else ((value + 0.055) / 1.055) ** 2.4

    luminance = 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    if luminance > 216 / 24389:
        return 116 * luminance ** (1 / 3) - 16
    return (24389 / 27) * luminance


def _read_ppm(path: Path) -> tuple[int, int, bytes]:
    """Read a binary P6 PPM with maxval 255; returns (width, height, rgb bytes)."""
    data = path.read_bytes()
    tokens: list[bytes] = []
    index = 0
    while len(tokens) < 4:
        while index < len(data) and data[index:index + 1].isspace():
            index += 1
        if data[index:index + 1] == b"#":
            while index < len(data) and data[index:index + 1] != b"\n":
                index += 1
            continue
        start = index
        while index < len(data) and not data[index:index + 1].isspace():
            index += 1
        tokens.append(data[start:index])
    if tokens[0] != b"P6" or tokens[3] != b"255":
        raise ValueError(f"{path.name} is not a binary P6 PPM with maxval 255")
    width, height = int(tokens[1]), int(tokens[2])
    pixels = data[index + 1:index + 1 + width * height * 3]
    if len(pixels) != width * height * 3:
        raise ValueError(f"{path.name} has {len(pixels)} pixel bytes, expected {width * height * 3}")
    return width, height, pixels


def _derive_lesson_steps(step0_v50: object, checkpoints: list[dict]) -> dict:
    """Independently recompute fadeStep, returnStep, R1 and derivedLessonSteps from V50 and max L*."""
    gates = LARGER_BLOB_GATES
    v50 = {item["step"]: item.get("displayVisibleAreaL50") for item in checkpoints}
    lightness = {item["step"]: item.get("sliceMaximumLightness") for item in checkpoints}
    horizon = THREE_D_LESSON_HORIZON["horizonSteps"]
    steps = sorted(v50)
    derived: dict = {"fadeStep": None, "returnStep": None, "r1": False, "derivedLessonSteps": None}
    if not _is_number(step0_v50) or not all(_is_number(v50[step]) for step in steps):
        return derived
    fade = next((step for step in steps if step >= 50 and v50[step] <= gates["fadeFraction"] * step0_v50), None)
    derived["fadeStep"] = fade
    if fade is None:
        window = [step0_v50] + [v50[step] for step in steps if step <= gates["noFadeWindowSteps"]]
        derived["minimumVisibleAreaThroughNoFadeWindow"] = min(window)
        derived["r1"] = min(window) >= gates["noFadeVisibleAreaMinimum"]
        if derived["r1"]:
            derived["derivedLessonSteps"] = gates["lessonLengthChoices"][0]
        return derived
    returned = next(
        (
            step for step in steps
            if step > fade
            and v50[step] >= gates["returnDisplayVisibleAreaMinimum"]
            and (step == horizon or (step + 50 in v50 and v50[step] >= v50[step + 50]))
        ),
        None,
    )
    derived["returnStep"] = returned
    if returned is not None:
        derived["returnDisplayVisibleArea"] = v50[returned]
        derived["returnMaximumLightness"] = lightness[returned]
        derived["r1"] = (
            returned + gates["returnTailSteps"] <= horizon
            and _is_number(lightness[returned])
            and lightness[returned] >= gates["returnMaximumLightnessMinimum"]
        )
        if derived["r1"]:
            derived["derivedLessonSteps"] = next(
                (n for n in gates["lessonLengthChoices"] if n >= returned + gates["returnTailSteps"]), None
            )
    return derived


def _validate_larger_blob_lesson(result: dict, by_step: dict) -> list[str]:
    """Fail-closed checks of the 2026-11-21 larger-blob gates (S1, S2, R1) and the 1800-step lesson (E7')."""
    errors: list[str] = []
    gates = LARGER_BLOB_GATES
    horizon = THREE_D_LESSON_HORIZON
    blob = result.get("largerBlobGates")
    lesson = result.get("threeDLesson")
    if not isinstance(blob, dict):
        errors.append("evolution-visibility largerBlobGates is missing")
    if not isinstance(lesson, dict):
        errors.append("evolution-visibility threeDLesson is missing")
    if errors:
        return errors

    if lesson.get("horizonSteps") != horizon["horizonSteps"]:
        errors.append(f"evolution-visibility threeDLesson horizonSteps must be {horizon['horizonSteps']}")
    if lesson.get("stepsValidated") != horizon["horizonSteps"]:
        errors.append(
            f"evolution-visibility threeDLesson stepsValidated {lesson.get('stepsValidated')} is not "
            f"{horizon['horizonSteps']}"
        )
    for key in ("projectionFailures", "capHits"):
        if lesson.get(key) != 0:
            errors.append(f"evolution-visibility threeDLesson {key} {lesson.get(key)} must be 0")
    iterations = lesson.get("maximumIterations")
    if not _is_number(iterations) or iterations >= horizon["iterationCap"]:
        errors.append(
            f"evolution-visibility threeDLesson maximum iterations {iterations} do not stay below "
            f"the {horizon['iterationCap']} cap"
        )
    if lesson.get("inputDivergenceMarginLimit") != horizon["inputDivergenceLimit"]:
        errors.append("evolution-visibility threeDLesson input divergence limit differs from the amendment")
    maximum_input = lesson.get("maximumInputDivergenceDTInf")
    if not _is_number(maximum_input) or maximum_input > horizon["inputDivergenceLimit"]:
        errors.append(
            f"evolution-visibility threeDLesson maximum input divergence {maximum_input} exceeds "
            f"{horizon['inputDivergenceLimit']}"
        )
    if lesson.get("reductionGateActiveSteps") != 0:
        errors.append(
            f"evolution-visibility threeDLesson reduction gate was active on "
            f"{lesson.get('reductionGateActiveSteps')} steps; it must never be active"
        )
    if lesson.get("finite") is not True:
        errors.append("evolution-visibility threeDLesson is not finite")
    if lesson.get("volumePeakMinimum") != horizon["volumePeakMinimum"]:
        errors.append("evolution-visibility threeDLesson volume peak minimum differs from the amendment")

    checkpoints = lesson.get("checkpoints")
    expected_steps = list(range(horizon["checkpointInterval"], horizon["horizonSteps"] + 1,
                                horizon["checkpointInterval"]))
    checkpoints_ok = isinstance(checkpoints, list) and [
        item.get("step") if isinstance(item, dict) else None for item in checkpoints
    ] == expected_steps
    if not checkpoints_ok:
        errors.append("evolution-visibility threeDLesson checkpoint steps must be 50 to 1800 by 50")
    else:
        numeric = ("slicePeak", "sliceAreaAtLeast0_1", "sliceCountAtLeast0_02", "displayVisibleAreaL50",
                   "sliceMaximumLightness", "volumePeak", "volumeMass")
        for item in checkpoints:
            if item.get("finite") is not True or not all(_is_number(item.get(key)) for key in numeric):
                errors.append(f"evolution-visibility threeDLesson checkpoint step {item['step']} is not finite")
            if not isinstance(item.get("sliceCapture"), str) or not item["sliceCapture"]:
                errors.append(f"evolution-visibility threeDLesson checkpoint step {item['step']} has no capture")

    if blob.get("gates") != gates:
        errors.append("evolution-visibility largerBlobGates gates differ from the amendment constants")
        return errors
    observed = blob.get("observed")
    if not isinstance(observed, dict):
        errors.append("evolution-visibility largerBlobGates observed values are missing")
        return errors
    if blob.get("passed") is not True:
        errors.append("evolution-visibility largerBlobGates did not report passed")

    step0 = by_step.get(0) if isinstance(by_step.get(0), dict) else {}
    area0 = step0.get("sliceAreaAtLeast0_1")
    v50_0 = step0.get("displayVisibleAreaL50")
    if observed.get("step0SectionArea") != area0:
        errors.append("evolution-visibility S1 step-0 section area does not match its observation")
    if not _is_number(area0) or area0 < gates["step0SectionAreaMinimum"]:
        errors.append(f"evolution-visibility S1 step-0 section area {area0} is below {gates['step0SectionAreaMinimum']}")
    if observed.get("step0DisplayVisibleArea") != v50_0:
        errors.append("evolution-visibility S2 step-0 display-visible area does not match its observation")
    if not _is_number(v50_0) or v50_0 < gates["step0DisplayVisibleAreaMinimum"]:
        errors.append(
            f"evolution-visibility S2 step-0 display-visible area {v50_0} is below "
            f"{gates['step0DisplayVisibleAreaMinimum']}"
        )

    if not checkpoints_ok:
        return errors
    derived = _derive_lesson_steps(v50_0, checkpoints)
    for key in ("fadeStep", "returnStep"):
        if observed.get(key) != derived[key]:
            errors.append(
                f"evolution-visibility R1 emitted {key} {observed.get(key)} differs from the recomputed {derived[key]}"
            )
    if derived["returnStep"] is not None:
        if observed.get("returnDisplayVisibleArea") != derived["returnDisplayVisibleArea"]:
            errors.append("evolution-visibility R1 return display-visible area does not match its checkpoint")
        emitted = observed.get("returnMaximumLightness")
        if not _is_number(emitted) or abs(emitted - derived["returnMaximumLightness"]) > 1e-9:
            errors.append("evolution-visibility R1 return maximum lightness does not match its checkpoint")
    if derived["fadeStep"] is None and (
        observed.get("minimumVisibleAreaThroughNoFadeWindow") != derived.get("minimumVisibleAreaThroughNoFadeWindow")
    ):
        errors.append("evolution-visibility R1 no-fade minimum visible area does not match the checkpoints")
    if not derived["r1"]:
        errors.append(
            f"evolution-visibility R1 failed: fadeStep {derived['fadeStep']}, returnStep {derived['returnStep']}"
        )
    lesson_steps = derived["derivedLessonSteps"]
    for label, value in (
        ("largerBlobGates", observed.get("derivedLessonSteps")),
        ("threeDLesson", lesson.get("derivedLessonSteps")),
        ("result", result.get("derivedLessonSteps")),
    ):
        if value != lesson_steps:
            errors.append(
                f"evolution-visibility {label} derivedLessonSteps {value} differs from the recomputed {lesson_steps}"
            )
    by_checkpoint = {item["step"]: item for item in checkpoints}
    volume_end = lesson.get("volumePeakAtLessonEnd")
    if not _is_number(volume_end) or volume_end < horizon["volumePeakMinimum"]:
        errors.append(
            f"evolution-visibility threeDLesson volume dye peak at the lesson end {volume_end} is below "
            f"{horizon['volumePeakMinimum']}"
        )
    elif lesson_steps in by_checkpoint and abs(by_checkpoint[lesson_steps]["volumePeak"] - volume_end) > 1e-9:
        errors.append("evolution-visibility threeDLesson volume peak at the lesson end does not match its checkpoint")
    volume_horizon = lesson.get("volumePeakAtHorizon")
    if not _is_number(volume_horizon) or abs(by_checkpoint[horizon["horizonSteps"]]["volumePeak"] - volume_horizon) > 1e-9:
        errors.append("evolution-visibility threeDLesson volume peak at the horizon does not match its checkpoint")
    return errors


def _validate_evolution_display_captures(result: dict, evidence_dir: Path) -> list[str]:
    """Recompute V50 and maximum L* from each sliceCapture PPM and require agreement with the emitted values."""
    errors: list[str] = []
    threshold = LARGER_BLOB_GATES["displayLightnessThreshold"]
    lesson = result.get("threeDLesson") if isinstance(result.get("threeDLesson"), dict) else {}
    items = [("observation", item) for item in result.get("observations") or []]
    items += [("checkpoint", item) for item in lesson.get("checkpoints") or []]
    if not items:
        return ["evolution-visibility has no display captures to check"]
    cache: dict[str, tuple[int, float]] = {}
    for kind, item in items:
        if not isinstance(item, dict):
            errors.append(f"evolution-visibility {kind} entry is not an object")
            continue
        step = item.get("step")
        name = item.get("sliceCapture")
        if not isinstance(name, str) or not name:
            errors.append(f"evolution-visibility {kind} step {step} has no capture")
            continue
        if name not in cache:
            path = evidence_dir / name
            if not path.is_file():
                errors.append(f"evolution-visibility {kind} step {step} capture {name} is missing")
                continue
            try:
                width, height, pixels = _read_ppm(path)
            except (ValueError, IndexError) as error:
                errors.append(f"evolution-visibility {kind} step {step} capture {name} is unreadable: {error}")
                continue
            lightness_by_colour: dict[bytes, float] = {}
            visible = 0
            maximum = 0.0
            for offset in range(0, width * height * 3, 3):
                colour = pixels[offset:offset + 3]
                value = lightness_by_colour.get(colour)
                if value is None:
                    value = _display_lightness(colour[0], colour[1], colour[2])
                    lightness_by_colour[colour] = value
                if value >= threshold:
                    visible += 1
                maximum = max(maximum, value)
            cache[name] = (visible, maximum)
        visible, maximum = cache[name]
        if item.get("displayVisibleAreaL50") != visible:
            errors.append(
                f"evolution-visibility {kind} step {step} V50 {item.get('displayVisibleAreaL50')} differs from "
                f"the capture's {visible}"
            )
        emitted = item.get("sliceMaximumLightness")
        if not _is_number(emitted) or abs(emitted - maximum) > 1e-6:
            errors.append(
                f"evolution-visibility {kind} step {step} maximum L* {emitted} differs from the capture's {maximum}"
            )
    return errors


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def _fixture_reference_manifest_path(fixture: str) -> Path:
    directory = ".build/inspection3d-reference" if fixture in SPATIAL_FIXTURES else ".build/fluid3d-reference"
    return ROOT / directory / "manifest.json"


def _fixture_source_inventory(fixture: str) -> list[str]:
    return SPATIAL_HASHED_SOURCES if fixture in SPATIAL_FIXTURES else HASHED_SOURCES


def _fixture_capture_directory(fixture: str, evidence_dir: Path) -> Path:
    return ROOT / ".build/inspection3d-evidence" if fixture in SPATIAL_FIXTURES else evidence_dir


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


def _is_number(value: object) -> bool:
    return isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(value)


def _validate_evolution_calibration(result: dict, by_step: dict) -> list[str]:
    """Fail-closed checks of the human-calibrated early-window amendment (E1-E7) and recipe envelope."""
    errors: list[str] = []
    gates = EVOLUTION_CALIBRATED_GATES
    for step in EVOLUTION_OBSERVATION_STEPS:
        if step in (0, 24, 48):
            continue  # preregistered steps are checked by the original validator branch
        item = by_step.get(step)
        if not isinstance(item, dict):
            errors.append(f"evolution-visibility is missing step {step}")
        elif item.get("projection", {}).get("failure") != "none" or not item.get("projection", {}).get("converged"):
            errors.append(f"evolution-visibility step {step} projection status failed")

    window = result.get("calibratedEarlyWindow")
    if not isinstance(window, dict):
        errors.append("evolution-visibility calibratedEarlyWindow is missing")
    elif window.get("gates") != gates:
        errors.append("evolution-visibility calibratedEarlyWindow gates differ from the amendment constants")
    else:
        observed = window.get("observed")
        if not isinstance(observed, dict):
            errors.append("evolution-visibility calibratedEarlyWindow observed values are missing")
        else:
            if window.get("passed") is not True:
                errors.append("evolution-visibility calibratedEarlyWindow did not report passed")
            for step, key, label in ((10, "step10RMSFromStep0", "step-10"), (20, "step20RMSFromStep0", "step-20")):
                value = observed.get(key)
                item = by_step.get(step)
                minimum = gates[f"step{step}RMSFromStep0Minimum"]
                if not _is_number(value):
                    errors.append(f"evolution-visibility {label} RMS is missing or nonfinite")
                    continue
                if value < minimum:
                    errors.append(f"evolution-visibility {label} RMS {value} is below the amendment gate {minimum}")
                if isinstance(item, dict) and not (
                    _is_number(item.get("sliceRMSFromStep0")) and abs(item["sliceRMSFromStep0"] - value) <= 1e-9
                ):
                    errors.append(f"evolution-visibility {label} RMS does not match its observation")
            encoded = observed.get("step10EncodedChangeCount")
            if not _is_number(encoded) or encoded < gates["step10EncodedChangeCountMinimum"]:
                errors.append(
                    f"evolution-visibility step-10 encoded-change count {encoded} is below "
                    f"{gates['step10EncodedChangeCountMinimum']}"
                )
            areas = observed.get("sectionArea")
            peaks = observed.get("earlyWindowPeaks")
            if not isinstance(areas, dict) or not isinstance(peaks, dict):
                errors.append("evolution-visibility section areas or early-window peaks are missing")
            else:
                for step in [0] + list(gates["earlyWindowSteps"]):
                    item = by_step.get(step)
                    area = areas.get(str(step))
                    if not _is_number(area):
                        errors.append(f"evolution-visibility section area for step {step} is missing")
                    elif isinstance(item, dict) and item.get("sliceAreaAtLeast0_1") != area:
                        errors.append(f"evolution-visibility section area for step {step} does not match its observation")
                for step in gates["earlyWindowSteps"]:
                    item = by_step.get(step)
                    peak = peaks.get(str(step))
                    area = areas.get(str(step))
                    if not _is_number(peak) or peak < gates["earlyWindowPeakMinimum"]:
                        errors.append(
                            f"evolution-visibility step-{step} early-window peak {peak} is below "
                            f"{gates['earlyWindowPeakMinimum']}"
                        )
                    elif isinstance(item, dict) and not (
                        _is_number(item.get("slicePeak")) and abs(item["slicePeak"] - peak) <= 1e-9
                    ):
                        errors.append(f"evolution-visibility step-{step} early-window peak does not match its observation")
                    if _is_number(area) and area < gates["earlyWindowSectionAreaMinimum"]:
                        errors.append(
                            f"evolution-visibility step-{step} early-window section area {area} is below "
                            f"{gates['earlyWindowSectionAreaMinimum']}"
                        )
                area0, area48 = areas.get("0"), areas.get("48")
                if _is_number(area0) and area0 < gates["step0SectionAreaMinimum"]:
                    errors.append(
                        f"evolution-visibility step-0 section area {area0} is below {gates['step0SectionAreaMinimum']}"
                    )
                if _is_number(area0) and _is_number(area48) and area0 > 0:
                    relative = abs(area48 - area0) / area0
                    if relative < gates["step48SectionAreaRelativeChangeMinimum"]:
                        errors.append(
                            f"evolution-visibility step-48 section-area change {relative} is below "
                            f"{gates['step48SectionAreaRelativeChangeMinimum']}"
                        )
                    reported = observed.get("step48SectionAreaRelativeChange")
                    if not _is_number(reported) or abs(reported - relative) > 1e-9:
                        errors.append("evolution-visibility step-48 section-area change does not match its areas")

    lesson = result.get("lessonRecipe600")
    contract = LESSON_RECIPE_600
    if not isinstance(lesson, dict):
        errors.append("evolution-visibility lessonRecipe600 is missing")
    else:
        if lesson.get("stepsValidated") != contract["steps"]:
            errors.append(
                f"evolution-visibility lessonRecipe600 stepsValidated is {lesson.get('stepsValidated')}, "
                f"expected {contract['steps']}"
            )
        if lesson.get("projectionFailures") != 0:
            errors.append("evolution-visibility lessonRecipe600 projectionFailures must be 0")
        if lesson.get("capHits") != 0:
            errors.append("evolution-visibility lessonRecipe600 capHits must be 0")
        input_divergence = lesson.get("maximumInputDivergenceDTInf")
        if not _is_number(input_divergence) or input_divergence > contract["inputDivergenceLimit"]:
            errors.append(
                f"evolution-visibility lessonRecipe600 maximum input divergence {input_divergence} "
                f"exceeds {contract['inputDivergenceLimit']}"
            )
        if lesson.get("inputDivergenceMarginLimit") != contract["inputDivergenceLimit"]:
            errors.append("evolution-visibility lessonRecipe600 input divergence margin limit differs from the amendment")
        if lesson.get("reductionGateActiveSteps") != 0:
            errors.append(
                f"evolution-visibility lessonRecipe600 reduction gate was active on "
                f"{lesson.get('reductionGateActiveSteps')} steps"
            )
        iterations = lesson.get("maximumIterations")
        if not _is_number(iterations) or iterations >= contract["iterationCap"]:
            errors.append(
                f"evolution-visibility lessonRecipe600 maximum iterations {iterations} do not stay below "
                f"the {contract['iterationCap']} cap"
            )
        if lesson.get("finite") is not True:
            errors.append("evolution-visibility lessonRecipe600 is not finite")
        volume = lesson.get("volumePeakAt600")
        if not _is_number(volume) or volume < contract["volumePeakMinimum"]:
            errors.append(
                f"evolution-visibility lessonRecipe600 volume dye peak at step 600 {volume} is below "
                f"{contract['volumePeakMinimum']}"
            )
        if lesson.get("volumePeakMinimumAt600") != contract["volumePeakMinimum"]:
            errors.append("evolution-visibility lessonRecipe600 volume peak minimum differs from the amendment")
        checkpoints = lesson.get("checkpoints")
        if not isinstance(checkpoints, list) or [
            item.get("step") if isinstance(item, dict) else None for item in checkpoints
        ] != contract["checkpointSteps"]:
            errors.append("evolution-visibility lessonRecipe600 checkpoint steps must be 100 to 600 by 100")
        else:
            for item in checkpoints:
                numeric = ("slicePeak", "sliceAreaAtLeast0_1", "sliceCountAtLeast0_02", "volumePeak", "volumeMass")
                if item.get("finite") is not True or not all(_is_number(item.get(key)) for key in numeric):
                    errors.append(f"evolution-visibility lessonRecipe600 checkpoint step {item['step']} is not finite")
                if not isinstance(item.get("sliceCapture"), str) or not item["sliceCapture"]:
                    errors.append(f"evolution-visibility lessonRecipe600 checkpoint step {item['step']} has no capture")
            last = checkpoints[-1]
            if _is_number(volume) and _is_number(last.get("volumePeak")) and abs(last["volumePeak"] - volume) > 1e-9:
                errors.append("evolution-visibility lessonRecipe600 step-600 checkpoint volume peak does not match volumePeakAt600")

    recipe = result.get("recipe")
    envelope = LESSON_RECIPE_ENVELOPE
    tolerance = envelope["tolerance"]
    if not isinstance(recipe, dict):
        errors.append("evolution-visibility recipe is missing")
    else:
        def within(value: object, bounds: tuple[float, float]) -> bool:
            return _is_number(value) and bounds[0] - tolerance <= value <= bounds[1] + tolerance

        speed = recipe.get("seedMaximumVectorSpeed")
        if not within(speed, envelope["seedMaximumVectorSpeed"]):
            errors.append(f"evolution-visibility recipe seed speed {speed} is outside {envelope['seedMaximumVectorSpeed']}")
        radius = recipe.get("blobRadius")
        if not within(radius, envelope["blobRadius"]):
            errors.append(f"evolution-visibility recipe blob radius {radius} is outside {envelope['blobRadius']}")
        center = recipe.get("blobCenter")
        if not isinstance(center, list) or len(center) != 3 or not all(
            within(value, envelope["blobCenterCoordinate"]) for value in center
        ):
            errors.append(
                f"evolution-visibility recipe blob centre {center} is outside {envelope['blobCenterCoordinate']}"
            )
        else:
            if _is_number(radius):
                for axis, coordinate in zip("xyz", center):
                    clearance = min(coordinate - radius, 1 - coordinate - radius)
                    if clearance < envelope["wallClearanceMinimum"] - tolerance:
                        errors.append(
                            f"evolution-visibility recipe {axis} wall clearance {clearance} is below "
                            f"{envelope['wallClearanceMinimum']}"
                        )
            offset = abs(center[2] - 0.5) / radius if _is_number(radius) and radius > 0 else math.inf
            if not within(offset, envelope["equatorOffsetOverRadius"]):
                errors.append(
                    f"evolution-visibility recipe equator offset |cz-0.5|/r {offset} is outside "
                    f"{envelope['equatorOffsetOverRadius']}"
                )
        peak = recipe.get("blobPeak")
        if not within(peak, envelope["blobPeak"]):
            errors.append(f"evolution-visibility recipe blob peak {peak} is outside {envelope['blobPeak']}")
        if recipe.get("dyeDecayPerStep") != 0:
            errors.append("evolution-visibility recipe dye decay per step must be 0")
        if recipe.get("velocityReseedAfterReset") is not False:
            errors.append("evolution-visibility recipe velocity reseed after reset must be false")
    errors.extend(_validate_larger_blob_lesson(result, by_step))
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
        errors.extend(_validate_evolution_calibration(result, by_step))
    elif fixture == "reset-finite":
        snapshots = result.get("snapshots")
        if not isinstance(snapshots, list) or not snapshots or any(item.get("finite") is not True for item in snapshots):
            errors.append("reset-finite snapshots are missing or nonfinite")
    elif fixture == "slice-palette":
        if result.get("renderingReadOnly") is not True or result.get("finite") is not True:
            errors.append("slice-palette read-only/finite result is missing")
        if result.get("sampledPlanes") != [31, 32] or result.get("sampleWeights") != [0.5, 0.5]:
            errors.append("slice-palette does not report the central 31/32 midpoint")
        if result.get("displayTransfer") != "square-root":
            errors.append("slice-palette must report the fixed square-root display transfer")
        stops = result.get("paletteStops")
        if (
            not isinstance(stops, list)
            or [item.get("concentration") for item in stops if isinstance(item, dict)] != [0.0, 0.25, 1.0]
            or [item.get("displayValue") for item in stops if isinstance(item, dict)] != [0.0, 0.5, 1.0]
            or [item.get("rgb") for item in stops if isinstance(item, dict)]
            != [[0, 0, 0], [237, 139, 35], [255, 241, 214]]
        ):
            errors.append(
                "slice-palette stops must be concentration [0, 0.25, 1], display value [0, 0.5, 1] "
                "and RGB black/amber/cream"
            )
        samples = result.get("transferSamples")
        if not isinstance(samples, list) or not any(
            isinstance(item, dict) and item.get("concentration") == 0.25 and item.get("rgb") == [237, 139, 35]
            for item in samples
        ):
            errors.append("slice-palette transferSamples must pin concentration 0.25 to full amber (237,139,35)")
    elif fixture == "spatial-slices":
        if result.get("cubeEdgesChecked") != 12:
            errors.append("spatial-slices must verify all 12 projected cube edges")
        scale_ratio = result.get("cubeGuidePointScaleRatio")
        if not isinstance(scale_ratio, (int, float)) or not 3.2 <= scale_ratio <= 4.8:
            errors.append("spatial-slices guide-pixel coverage must scale with 1x/2x point size")
        if result.get("cubeDepthAttachmentReuseAllocations") != 2:
            errors.append("spatial-slices repeated-size checks must allocate one depth attachment per size")
        if result.get("cubeSpatialPipelineAllocations") != 3:
            errors.append("spatial-slices must reuse its sheet, tracer and guide pipelines across viewport changes")
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
    elif fixture == "tracer-evolution":
        if result.get("markerCount") != 512 or result.get("positionBufferBytes") != 8192:
            errors.append("tracer-evolution marker storage inventory is incorrect")
        expected_cases = {
            "positive_x", "negative_x", "positive_y", "negative_y",
            "positive_z", "negative_z", "combined_xyz", "combined_mixed",
        }
        if set(result.get("forwardCaseNames", [])) != expected_cases:
            errors.append("tracer-evolution must compare every registered forward-RK2 velocity case")
        if result.get("forwardComparedPositions") != 512 * len(expected_cases):
            errors.append("tracer-evolution forward-RK2 position comparison count is incomplete")
        if result.get("boundaryProbeCount") != 27 or result.get("affineProbeCount") != 28:
            errors.append("tracer-evolution wall/edge/corner or affine-MAC probes are incomplete")
        if result.get("productionStepCount") != 48:
            errors.append("tracer-evolution must run exactly 48 production solver/tracer steps")
        for key in (
            "threeQueuedSubmissionsChecked",
            "currentFailureGuarded",
            "priorFailureGuarded",
            "noFluidFeedback",
            "finite",
            "positionsInBounds",
        ):
            if result.get(key) is not True:
                errors.append(f"tracer-evolution is missing required regression evidence: {key}")
        scheduling = result.get("rendererScheduling")
        if not isinstance(scheduling, dict):
            errors.append("tracer-evolution renderer scheduling evidence is missing")
        else:
            for key in (
                "nilDrawable",
                "initialSeedsExact",
                "pausedPresentationsUnchanged",
                "threeQueuedCommands",
                "hiddenVisiblePositionsEqual",
                "hiddenAdvanced",
                "visibilityDoesNotReseed",
                "restartRestoresSeeds",
                "restartRetainsInspection",
                "latestCompletedStatusRetained",
            ):
                if scheduling.get(key) is not True:
                    errors.append(
                        f"tracer-evolution renderer scheduling is missing required regression evidence: {key}"
                    )
            for key in ("acceptedStepCount", "validatedCompletionCount"):
                if scheduling.get(key) != 3:
                    errors.append(
                        f"tracer-evolution renderer scheduling must report exactly 3 {key}"
                    )
    elif fixture == "transitions-and-failures":
        recovery = result.get("lessonFailureRecovery")
        expected_lessons = {
            "Dye carried by a flow",
            "Two interacting vortices",
            "Stretching dye by stirring",
        }
        if not isinstance(recovery, dict):
            errors.append("transitions-and-failures lesson recovery evidence is missing")
        else:
            if set(recovery.get("twoDLessons", [])) != expected_lessons:
                errors.append("transitions-and-failures must cover failed Restart from every 2D lesson")
            for key in (
                "allRecoveredToRunningFreePlay",
                "freePlayPreferencesRetained",
                "failedRestartRetrySucceeded",
            ):
                if recovery.get(key) is not True:
                    errors.append(f"transitions-and-failures is missing required regression evidence: {key}")
    elif fixture == "inspection-routing":
        for key in (
            "nilDrawablePresentation",
            "pausedPendingStepsPreserved",
            "tracerInitialSeedsExact",
            "hiddenTracerStepAdvanced",
            "restartRetainsInspection",
            "restartRestoresTracerSeeds",
            "reselectionRestoresDefaults",
        ):
            if result.get(key) is not True:
                errors.append(f"inspection-routing is missing required regression evidence: {key}")
    elif fixture == "tracer-occlusion":
        for key in (
            "frontMarkersVisibleInBlack",
            "behindMarkersHiddenInBlack",
            "frontMarkersVisibleInDyed",
            "behindMarkersHiddenInDyed",
            "outsideFootprintVisible",
            "oppositeSideOcclusionReversed",
            "discCornersDiscarded",
            "edgeOnMarkersRemainCircular",
            "oneXThreePointDiameter",
            "twoXThreePointDiameter",
            "markerColorIsExact",
            "blackSheetRemainsOpaque",
            "dyedSheetRemainsOpaque",
        ):
            if result.get(key) is not True:
                errors.append(f"tracer-occlusion is missing required regression evidence: {key}")
        if not isinstance(result.get("measurements"), dict):
            errors.append("tracer-occlusion projected-diameter measurements are missing")
        else:
            measurements = result["measurements"]
            for key in ("oneXDiameterPixels", "twoXDiameterPixels"):
                value = measurements.get(key)
                if not isinstance(value, (int, float)) or not math.isfinite(value) or value <= 0:
                    errors.append(f"tracer-occlusion has invalid {key}")
            for key in ("oneXDiameterPoints", "twoXDiameterPoints"):
                value = measurements.get(key)
                if not isinstance(value, (int, float)) or not math.isfinite(value) or abs(value - 3.0) > 1.0:
                    errors.append(f"tracer-occlusion does not meet the 3-point size gate for {key}")
    return errors


INSPECTION_FIXTURES = (
    "spatial-slices", "inspection-routing", "tracer-evolution",
    "tracer-occlusion", "inspection-independence",
)
INSPECTION_COVERAGE = {
    "manualVisualReview": "PENDING", "voiceOver": "NOT TESTED",
    "physicalPointerFeel": "NOT TESTED", "macOS26Runtime": "NOT TESTED",
    "physicalMultitouch": "NOT TESTED", "displayedFramePacing": "NOT MEASURED",
    "phase7ManualAcceptance": "PENDING",
}
INSPECTION_TOLERANCES = {
    "oracleAbsolute": 2e-5, "oracleRelative": 2e-4, "equalStepAbsolute": 2e-6,
    "paletteCodes": 1, "pressureDTInf": 1e-5, "pressureIterationCap": 320,
}
INSPECTION_CONFIGURATION = {
    "grid": [64, 64, 64], "dt": 1 / 60, "markerCount": 512,
    "seed": "i-fastest float4((i+.5)/8,(j+.5)/8,(k+.5)/8,1)",
}
INSPECTION_FLAGS = {
    "spatial-slices": (
        "abiRoundTrip", "backsideGeometry", "edgeOnRemainsThin",
        "legacyFixedSliceRetained", "simulationTexturesUnchanged",
        "checkedPipelineAllocationFailure", "checkedDepthAllocationFailure",
        "emptyDyeGuidesVisible", "cameraMatrixChanged", "cameraChangesProjectedImage",
        "resizePreservesInspectionState", "resizePreservesBothSimulationGenerations",
        "invalidDestinationFormatRejected", "invalidViewportRejected",
        "zeroExtentDeferredWithoutDepthAllocation",
    ),
    "inspection-routing": (
        "nilDrawablePresentation", "pausedPendingStepsPreserved",
        "presentationFieldsBitwiseUnchanged", "cameraMatrixChanged",
        "presentationImageChanged", "ordinaryStepDrainRetained",
        "restartRetainsInspection", "tracerInitialSeedsExact", "hiddenTracerStepAdvanced",
        "restartRestoresTracerSeeds", "reselectionRestoresDefaults",
        "zeroSizeDepthDeferred", "fullCanvasViewport", "depthFailureRecoveryAndRetry",
    ),
    "tracer-evolution": (
        "repeatResetByteIdentical", "allocationFailureThrows", "pipelineFailureThrows",
        "encoderFailureThrows", "threeQueuedSubmissionsChecked",
        "currentFailureGuarded", "priorFailureGuarded", "noFluidFeedback",
        "positionsInBounds", "finite",
    ),
    "tracer-occlusion": (
        "frontMarkersVisibleInBlack", "behindMarkersHiddenInBlack",
        "frontMarkersVisibleInDyed", "behindMarkersHiddenInDyed",
        "outsideFootprintVisible", "oppositeSideOcclusionReversed",
        "discCornersDiscarded", "edgeOnMarkersRemainCircular",
        "oneXThreePointDiameter", "twoXThreePointDiameter", "markerColorIsExact",
        "blackSheetRemainsOpaque", "dyedSheetRemainsOpaque",
    ),
    "inspection-independence": ("restartCompleteInventoryMatched",),
}
INSPECTION_PAUSED = (
    [f"{kind}-{plane}{suffix}" for plane in ("xz", "yz", "xy")
     for kind, suffix in [("plane", ""), *[("depth", f"-{d}") for d in ("0.0", "0.3", "0.5", "1.0")]]]
    + ["camera-0.0-0.0-50.0", "camera-180.0-0.0-150.0", "camera-90.0-0.0-100.0",
       "camera--71.0-75.0-115.0", "gesture-orbit-and-zoom", "reset-camera", "centre-slice",
       "visibility-false", "visibility-true", "resize-640x240-1x", "resize-240x640-1x",
       "resize-320x240-1x", "resize-320x240-2x", "zero-viewport-defers-presentation"]
)


def inspection_inventory(statuses=("reset",)) -> list[dict]:
    """Independent named production layout, not inferred from submitted evidence."""
    records = []
    for field in ("u", "v", "w", "dye", "transport-u", "transport-v", "transport-w",
                  "q-high-low", "divergence", "rhs", "Aq", "true-residual", "identity",
                  "recursive-residual", "preconditioned", "search"):
        component = field.removeprefix("transport-")
        shape = [64 + int(component == axis) for axis in ("u", "v", "w")]
        for role in ("ping", "pong"):
            records.append({"name": f"{field}/{role}", "shape": shape,
                            "byteCount": math.prod(shape) * 4, "format": "r32Float", "scalar": "Float32"})
    for name, size in [
        ("simulation/failure-latch", 4), ("projection/reduction-partials", 16640),
        ("projection/standalone-latch", 4), ("projection/iteration-gate", 48),
        ("tracer/positions", 8192),
        *[(f"status/{role}/state", 304) for role in statuses],
    ]:
        records.append({"name": name, "shape": [size], "byteCount": size, "format": "buffer",
                        "scalar": "UInt32" if "latch" in name or name.endswith("iteration-gate")
                        else "Float32"})
    return records


def validate_inspection_manifest(manifest: object, *, actual: bool = False) -> list[str]:
    """Schema/freshness validation; synthetic manifests are never acceptance runs."""
    errors = []
    if not isinstance(manifest, dict):
        return ["inspection manifest must be an object"]

    def require(ok, label):
        if not ok:
            errors.append(label)

    def finite(value):
        return isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(value)

    def artifact(item, path_key, hash_key):
        path = _resolve_artifact_path(item.get(path_key))
        require(path is not None and path.exists(), f"missing artifact: {path_key}")
        if path is not None and path.is_file():
            require(item.get(hash_key) == sha256(path), f"stale artifact: {path_key}")

    require(manifest.get("schemaVersion") == 1, "unsupported inspection schema")
    require(manifest.get("kind") == "fluid3d-inspection", "wrong inspection kind")
    require(manifest.get("evidenceClass") in {"synthetic-schema-fixture", "actual-production-run"},
            "explicit evidenceClass required")
    if actual:
        require(manifest.get("evidenceClass") == "actual-production-run", "synthetic evidence is not an actual run")
    require(manifest.get("workload") == "offscreen-spatial-inspection-not-fps", "spatial workload mislabeled")
    require(isinstance(manifest.get("generatedAtUTC"), str) and bool(manifest["generatedAtUTC"]),
            "timestamp required")
    require(manifest.get("coverage") == INSPECTION_COVERAGE, "explicit pending/manual/runtime/pacing statuses required")
    require(manifest.get("configuration") == INSPECTION_CONFIGURATION, "exact grid/dt/seed configuration required")
    require(manifest.get("tolerances") == INSPECTION_TOLERANCES, "contracted tolerances required")
    require(manifest.get("sourceSHA256") == {p: sha256(ROOT / p) for p in SPATIAL_HASHED_SOURCES},
            "source inventory or hashes stale")
    for key, path in [
        ("completeContractSHA256", "docs/3d-numerical-contract.md"),
        ("inspectionContractSHA256", "docs/3d-inspection-contract.md"),
        ("oracleSHA256", "Tests/Integration/inspection3d_reference.swift"),
    ]:
        require(manifest.get(key) == sha256(ROOT / path), f"stale {key}")
    require(manifest.get("inspectionContractSHA256") == INSPECTION_CONTRACT_HASH, "inspection contract not pinned")
    require(isinstance(manifest.get("metallibSHA256"), str)
            and re.fullmatch("[0-9a-f]{64}", manifest["metallibSHA256"]) is not None, "metallib hash required")
    require(isinstance(manifest.get("metallibPath"), str) and bool(manifest["metallibPath"]), "metallib path required")
    environment = manifest.get("environment", {})
    for key in ("device", "hostModel", "os", "xcode", "swift", "metalToolchain", "configuration", "architecture"):
        require(isinstance(environment.get(key), str) and bool(environment[key].strip()), f"environment.{key} required")
    if actual:
        artifact(manifest, "metallibPath", "metallibSHA256")
    fixtures = manifest.get("fixtures", {})
    require(isinstance(fixtures, dict) and set(fixtures) == set(INSPECTION_FIXTURES), "complete fixture inventory required")
    if not isinstance(fixtures, dict):
        return errors
    for name in INSPECTION_FIXTURES:
        report = fixtures.get(name, {})
        require(report.get("fixture") == name and report.get("schemaVersion") == 1, f"{name}: report identity")
        for key in ("sourceSHA256", "metallibSHA256", "completeContractSHA256"):
            expected = manifest.get(key)
            if key == "sourceSHA256" and name == "inspection-routing":
                expected = {p: sha256(ROOT / p) for p in HASHED_SOURCES}
            require(report.get(key) == expected, f"{name}: stale {key}")
        require(report.get("referenceContractSHA256") == (
            CONTRACT_HASH if name == "inspection-routing" else INSPECTION_CONTRACT_HASH), f"{name}: reference contract")
        reference = _fixture_reference_manifest_path(name)
        require(isinstance(report.get("referenceManifestSHA256"), str)
                and re.fullmatch("[0-9a-f]{64}", report["referenceManifestSHA256"]) is not None,
                f"{name}: reference hash required")
        commands = report.get("commands", {})
        for command in ("referenceExport", "swiftCompile", "buildSettings", "fixture"):
            require(isinstance(commands.get(command), list) and bool(commands[command]), f"{name}: {command} required")
        run = report.get("execution", {})
        require(run.get("exitCode") == 0 and run.get("status") == "PASS"
                and finite(run.get("durationSeconds")) and run["durationSeconds"] > 0,
                f"{name}: passing measured execution required")
        require(isinstance(run.get("logPath"), str) and bool(run["logPath"])
                and isinstance(run.get("logSHA256"), str), f"{name}: log identity required")
        if actual:
            artifact(run, "logPath", "logSHA256")
            require(reference.is_file() and report.get("referenceManifestSHA256") == sha256(reference),
                    f"{name}: stale reference manifest")
        result = report.get("result", {})
        errors.extend(_validate_fixture_metrics(name, report))
        for key in INSPECTION_FLAGS[name]:
            require(result.get(key) is True, f"{name}: required {key}")
        if name in {"spatial-slices", "tracer-occlusion"}:
            captures = result.get("captures")
            require(isinstance(captures, list) and len(captures) > 0, f"{name}: captures required")
            if actual and isinstance(captures, list):
                for capture in captures:
                    require(isinstance(capture, str) and (ROOT / ".build/inspection3d-evidence" / capture).is_file(),
                            f"{name}: missing capture")
        if name == "spatial-slices":
            for key, value in {"planes": ["xy", "xz", "yz"], "depths": [0, .3, .5, 1],
                               "checkedAsymmetricSamples": 24}.items():
                require(result.get(key) == value, f"{name}: incomplete {key}")
            require(isinstance(result.get("independentPayloadSHA256"), str), f"{name}: payload hash required")
            if actual:
                payload = ROOT / ".build/inspection3d-reference/expectations.f64le"
                require(payload.is_file() and result.get("independentPayloadSHA256") == sha256(payload),
                        f"{name}: stale oracle payload")
            require(set(result.get("cubeGuidePixelCounts", {})) == {"1x", "2x"}, f"{name}: scale counts required")
        if name == "tracer-evolution":
            for key, value in {"positionStride": 16, "positionAlignment": 16,
                               "exactSeedValues": 2048, "uniqueInteriorSeeds": 512}.items():
                require(result.get(key) == value, f"{name}: {key}")
            require(finite(result.get("maximumForwardOracleError"))
                    and 0 <= result["maximumForwardOracleError"] <= 2e-5, f"{name}: oracle error")
        if name == "inspection-independence":
            errors.extend(_validate_inspection_independence(result))
    matrix = manifest.get("regressionMatrix", {})
    require(isinstance(matrix, dict) and set(matrix) == set(REGRESSION_MATRIX_REQUIRED), "full fresh matrix required")
    if isinstance(matrix, dict):
        for name in REGRESSION_MATRIX_REQUIRED:
            item = matrix.get(name, {})
            require(item.get("status") == "PASS" and item.get("exitCode") == 0, f"{name}: required PASS")
            require(finite(item.get("durationSeconds")) and item["durationSeconds"] > 0, f"{name}: measured duration")
            require(isinstance(item.get("command"), list) and bool(item["command"]), f"{name}: command required")
            for key in ("logPath", "logSHA256"):
                require(isinstance(item.get(key), str) and bool(item[key]), f"{name}: {key} required")
            if name not in {"macBuild", "iosBuild"}:
                require(isinstance(item.get("testCount"), int) and item["testCount"] > 0, f"{name}: test count required")
            if name in {"macTests", "iphoneHUD", "ipadHUD"}:
                require(isinstance(item.get("xcresultPath"), str) and bool(item["xcresultPath"]), f"{name}: bundle required")
                if actual:
                    path = _resolve_artifact_path(item.get("xcresultPath"))
                    require(path is not None and path.is_dir(), f"{name}: missing xcresult")
            if actual:
                artifact(item, "logPath", "logSHA256")
    return errors


def _validate_inspection_independence(result: dict) -> list[str]:
    errors = []

    def require(ok, label):
        if not ok:
            errors.append("inspection-independence: " + label)

    def inventory(records, statuses, exact=False, traced=False):
        expected = inspection_inventory(statuses)
        if traced:
            expected.append({"name": "status/traced/trace", "shape": [10240], "byteCount": 10240,
                             "format": "buffer", "scalar": "Float32"})
        require(isinstance(records, list) and len(records) == len(expected), "incomplete resource count")
        if not isinstance(records, list):
            return
        require({r.get("name") for r in records} == {r["name"] for r in expected}, "resource names")
        for wanted in expected:
            found = next((r for r in records if r.get("name") == wanted["name"]), {})
            require(all(found.get(k) == v for k, v in wanted.items()), "resource shape/bytes/type: " + wanted["name"])
            value = found.get("maximumAbsoluteError")
            require(isinstance(value, (int, float)) and math.isfinite(value) and 0 <= value <= 2e-6,
                    "finite per-resource error: " + wanted["name"])
            if (exact or wanted["name"].startswith("status/") or "latch" in wanted["name"]
                    or wanted["name"].endswith("iteration-gate")):
                require(found.get("byteMatch") is True, "exact bytes: " + wanted["name"])
            if exact:
                require(found.get("identityPreserved") is True, "paused allocation identity")

    def metadata(record, *, session=False):
        keys = {"grid", "h/dt", "cap", "productionConfiguration", "tracer-schema",
                "mode", "steps", "encoded", "completed", "pending", "paused", "inactive",
                "resetting", "complete", "failure", "drainScheduled", "mouseInput",
                "tapCount", "touchCount", "touchRadius", "statusRoles"}
        keys |= {"generation/" + r["name"].split("/")[0]
                 for r in inspection_inventory() if r["format"] == "r32Float"}
        if session:
            keys.add("sessionGeneration")
        require(all(isinstance(record.get(k), str) and bool(record[k]) for k in keys), "complete discrete metadata")
        for key, value in {"grid": "64,64,64", "cap": "320", "productionConfiguration": "true",
                           "h/dt": "1015021568,1015580809", "mode": "3D Dye Advection",
                           "failure": "false", "tapCount": "0", "touchCount": "0", "touchRadius": "nil",
                           "tracer-schema": "512 float4 stride16 w1 in-place"}.items():
            require(record.get(key) == value, "discrete configuration: " + key)

    inventory(result.get("inventory"), ("reset",), True)
    inventory(result.get("traceInventory"), ("reset", "traced"), True, True)
    require(result.get("byteCount") == 33776184, "reset payload bytes")
    negatives = {f"{kind}/{r['name']}" for r in inspection_inventory()
                 for kind in ("byte", "omission", "rename", "resize")}
    negatives |= {f"{kind}/status/traced/{role}" for kind in ("byte", "omission", "rename", "resize")
                  for role in ("state", "trace")}
    negatives |= {"finite-first", "extra-duplicate", "discrete-metadata", "allocation-role"}
    require(set(result.get("negativeChecks", [])) == negatives, "complete detector negative cases")
    paused = result.get("pausedCases", [])
    require(len(paused) == 29 and {c.get("case") for c in paused} == set(INSPECTION_PAUSED), "paused coverage")
    for case in paused:
        require(case.get("positivePresentationChange") is True, "inert presentation edit")
        state = case.get("metadata", {})
        metadata(state, session=True)
        require(state.get("pending") == "2" and state.get("steps") == "2", "paused pending/steps")
        inventory(case.get("resources"), ("reset", "latest"), True)
    schedules = ("shown", "hidden", "alternating", "nil-drawable")
    equal = result.get("equalStepCases", [])
    require(len(equal) == 4 and {c.get("schedule") for c in equal} == set(schedules), "visibility/drawable schedules")
    for case in equal:
        require(case.get("redrawCounts") == [0, 1, 2] and case.get("backingScales") == [1, 2]
                and case.get("reshowNoCatchUp") is True, "redraw/scale/reshow schedule")
        require(case.get("viewports") == ["wide", "tall", "zero in nil-drawable schedule"], "viewport schedule")
        reads = case.get("usableDrawableReads", -1)
        require(isinstance(reads, int) and (reads == 0 if case.get("schedule") == "nil-drawable" else reads > 0),
                "actual drawable schedule")
        checkpoints = case.get("checkpoints", [])
        require([c.get("step") for c in checkpoints] == [0, 1, 24, 48], "equal-step checkpoints")
        for checkpoint in checkpoints:
            step = checkpoint.get("step")
            state = checkpoint.get("metadata", {})
            metadata(state)
            require(all(state.get(k) == str(step) for k in ("steps", "encoded", "completed"))
                    and state.get("pending") == "0", "equal-step metadata")
            inventory(checkpoint.get("resources"), ("reset",) if step == 0 else ("reset", "latest"))
    queued = result.get("threeInFlight", [])
    require(len(queued) == 4 and {c.get("schedule") for c in queued} == set(schedules), "in-flight coverage")
    roles = ("reset", "latest", "submitted-2", "submitted-3", "submitted-4")
    for case in queued:
        metadata(case.get("metadata", {}), session=True)
        require(case.get("roles") == [f"status/{r}" for r in roles], "queued status ownership")
        require(case.get("metadata", {}).get("encoded") == "4"
                and case.get("metadata", {}).get("completed") == "1", "queued counters")
        inventory(case.get("inventory"), roles, True)
    restart = result.get("restartComparisons", [])
    require([c.get("step") for c in restart] == [0, 1], "restart checkpoints")
    for case in restart:
        inventory(case.get("resources"), ("reset",) if case.get("step") == 0 else ("reset", "latest"))
    failures = result.get("failureEvidence", {})
    require(set(failures) == {"active-depth-recovery", "inspection-routing",
                             "transitions-and-failures", "renderer-steps-and-inactivity"}, "failure inventory")
    depth = failures.get("active-depth-recovery", {})
    require(all(depth.get(k) is True for k in ("fallbackAdvanced", "recoveredToRunningFreePlay", "retrySucceeded")),
            "active depth failure/retry")
    for name in ("inspection-routing", "transitions-and-failures", "renderer-steps-and-inactivity"):
        errors.extend(_validate_fixture_metrics(name, {"result": failures.get(name)}))
    transitions = failures.get("transitions-and-failures", {})
    require(set(transitions.get("injectedFailures", [])) == {
        "allocation", "pipeline", "reset", "wrong-grid", "tracer-allocation", "tracer-reset", "tracer-advance"},
        "injected failures")
    renderer = failures.get("renderer-steps-and-inactivity", {})
    for key in ("solverFaultRecoveredToTwoD", "staleCompletionIgnoredAfterModeTransition",
                "pausedAndRunningInactivityFrozen", "redrawAndResizeNoOp", "referenceFieldsMatched", "nilDrawable"):
        require(renderer.get(key) is True, "renderer failure/schedule: " + key)
    require(renderer.get("reactivationCatchUp") is False and renderer.get("exactRendererSteps") == [1, 31],
            "renderer exact step/catch-up")
    return errors


def validate_inspection_bundle(directory: Path) -> list[str]:
    try:
        manifest = json.loads((directory / "manifest.json").read_text())
        matrix = json.loads((directory / "regression-matrix.json").read_text())
        errors = validate_inspection_manifest(manifest, actual=True)
        if {n: matrix.get("results", {}).get(n) for n in REGRESSION_MATRIX_REQUIRED} != manifest.get("regressionMatrix"):
            errors.append("regression matrix does not match inspection manifest")
        if matrix.get("sourceSHA256") != manifest.get("sourceSHA256"):
            errors.append("regression matrix source identity differs from manifest")
        if matrix.get("environment") != manifest.get("environment") or matrix.get("coverage") != INSPECTION_COVERAGE:
            errors.append("regression matrix environment/coverage differs from manifest")
        for name in INSPECTION_FIXTURES:
            report = json.loads((directory / f"{name}.json").read_text())
            if report != manifest.get("fixtures", {}).get(name):
                errors.append(f"manifest differs from {name}.json")
        return errors
    except (OSError, ValueError, TypeError, KeyError, AttributeError) as error:
        return [f"missing/malformed inspection evidence: {error}"]


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
        if _fixture_source_inventory(fixture) == SPATIAL_HASHED_SOURCES:
            fixture_sources = {}
            for source in _fixture_source_inventory(fixture):
                path = ROOT / source
                if not path.is_file():
                    errors.append(f"missing spatial hashed source: {source}")
                    continue
                fixture_sources[source] = sha256(path)
        if report.get("sourceSHA256") != fixture_sources:
            errors.append(f"{report_path.name} source hashes are stale")
        if metallib_hash and report.get("metallibSHA256") != metallib_hash:
            errors.append(f"{report_path.name} metallib hash is stale")
        fixture_reference_manifest = _fixture_reference_manifest_path(fixture)
        if not fixture_reference_manifest.is_file():
            errors.append(
                f"missing {fixture} reference manifest: {fixture_reference_manifest}"
            )
        elif report.get("referenceManifestSHA256") != sha256(fixture_reference_manifest):
            errors.append(f"{report_path.name} reference manifest hash is stale")
        if not quick:
            errors.extend(_validate_fixture_metrics(fixture, report))
        result = report.get("result")
        if isinstance(result, dict):
            capture_directory = _fixture_capture_directory(fixture, evidence_dir)
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


def synthetic_inspection_manifest() -> dict:
    """In-memory schema test data only; never written to the evidence namespace."""
    def resources(statuses=("reset",), traced=False):
        records = inspection_inventory(statuses)
        if traced:
            records.append({"name": "status/traced/trace", "shape": [10240],
                            "byteCount": 10240, "format": "buffer", "scalar": "Float32"})
        return [{**r, "byteMatch": True, "maximumAbsoluteError": 0, "identityPreserved": True} for r in records]

    def metadata(step=0, pending=0):
        return {"steps": str(step), "encoded": str(step), "completed": str(step),
                "pending": str(pending), "grid": "64,64,64", "cap": "320",
                "h/dt": "1015021568,1015580809", "productionConfiguration": "true",
                "tracer-schema": "512 float4 stride16 w1 in-place", "mode": "3D Dye Advection",
                "paused": "true", "inactive": "false", "resetting": "false", "complete": "false",
                "failure": "false", "drainScheduled": "false", "mouseInput": "nil",
                "tapCount": "0", "touchCount": "0", "touchRadius": "nil",
                "statusRoles": "status/reset", "sessionGeneration": "synthetic",
                **{"generation/" + r["name"].split("/")[0]: "synthetic-ping|synthetic-pong"
                   for r in inspection_inventory() if r["format"] == "r32Float"}}

    def checkpoint(step):
        return {"step": step, "metadata": metadata(step),
                "resources": resources(("reset",) if step == 0 else ("reset", "latest"))}

    fixtures = {}
    for name in INSPECTION_FIXTURES:
        fixtures[name] = {
            "schemaVersion": 1, "fixture": name,
            "sourceSHA256": {p: sha256(ROOT / p) for p in _fixture_source_inventory(name)},
            "metallibSHA256": "a" * 64,
            "completeContractSHA256": sha256(ROOT / "docs/3d-numerical-contract.md"),
            "referenceContractSHA256": CONTRACT_HASH if name == "inspection-routing" else INSPECTION_CONTRACT_HASH,
            "referenceManifestSHA256": "b" * 64,
            "commands": {key: ["synthetic-not-executed"] for key in
                         ("referenceExport", "swiftCompile", "buildSettings", "fixture")},
            "execution": {"status": "PASS", "exitCode": 0, "durationSeconds": 1,
                          "logPath": "synthetic-not-a-log", "logSHA256": "c" * 64},
            "result": {"fixture": name, "passed": True, **{key: True for key in INSPECTION_FLAGS[name]}},
        }
    fixtures["spatial-slices"]["result"].update({
        "planes": ["xy", "xz", "yz"], "depths": [0, .3, .5, 1], "checkedAsymmetricSamples": 24,
        "cubeEdgesChecked": 12, "cubeGuidePointScaleRatio": 4, "cubeDepthAttachmentReuseAllocations": 2,
        "cubeSpatialPipelineAllocations": 3, "captures": ["synthetic.ppm"],
        "independentPayloadSHA256": "d" * 64, "cubeGuidePixelCounts": {"1x": 1, "2x": 4},
    })
    fixtures["tracer-evolution"]["result"].update({
        "markerCount": 512, "positionBufferBytes": 8192, "positionStride": 16,
        "positionAlignment": 16, "exactSeedValues": 2048, "uniqueInteriorSeeds": 512,
        "maximumForwardOracleError": 0, "forwardComparedPositions": 4096,
        "boundaryProbeCount": 27, "affineProbeCount": 28, "productionStepCount": 48,
        "forwardCaseNames": ["positive_x", "negative_x", "positive_y", "negative_y",
                             "positive_z", "negative_z", "combined_xyz", "combined_mixed"],
        "rendererScheduling": {
            **{key: True for key in ("nilDrawable", "initialSeedsExact", "pausedPresentationsUnchanged",
                "threeQueuedCommands", "hiddenVisiblePositionsEqual", "hiddenAdvanced", "visibilityDoesNotReseed",
                "restartRestoresSeeds", "restartRetainsInspection", "latestCompletedStatusRetained")},
            "acceptedStepCount": 3, "validatedCompletionCount": 3,
        },
    })
    fixtures["tracer-occlusion"]["result"].update({
        "captures": ["synthetic.ppm"], "measurements": {
            "oneXDiameterPixels": 3, "twoXDiameterPixels": 6,
            "oneXDiameterPoints": 3, "twoXDiameterPoints": 3,
        },
    })
    statuses = ("reset", "latest", "submitted-2", "submitted-3", "submitted-4")
    fixtures["inspection-independence"]["result"].update({
        "inventory": resources(), "traceInventory": resources(("reset", "traced"), True),
        "byteCount": 33776184,
        "negativeChecks": [
            *[f"{kind}/{r['name']}" for r in inspection_inventory() for kind in ("byte", "omission", "rename", "resize")],
            *[f"{kind}/status/traced/{role}" for kind in ("byte", "omission", "rename", "resize") for role in ("state", "trace")],
            "finite-first", "extra-duplicate", "discrete-metadata", "allocation-role",
        ],
        "pausedCases": [{"case": label, "positivePresentationChange": True, "metadata": metadata(2, 2),
                         "resources": resources(("reset", "latest"))} for label in INSPECTION_PAUSED],
        "equalStepCases": [
            {"schedule": schedule, "checkpoints": [checkpoint(s) for s in (0, 1, 24, 48)],
             "usableDrawableReads": 0 if schedule == "nil-drawable" else 1,
             "redrawCounts": [0, 1, 2], "backingScales": [1, 2],
             "viewports": ["wide", "tall", "zero in nil-drawable schedule"], "reshowNoCatchUp": True}
            for schedule in ("shown", "hidden", "alternating", "nil-drawable")
        ],
        "threeInFlight": [
            {"schedule": schedule, "roles": [f"status/{r}" for r in statuses],
             "metadata": {**metadata(4), "completed": "1"}, "inventory": resources(statuses)}
            for schedule in ("shown", "hidden", "alternating", "nil-drawable")
        ],
        "restartComparisons": [checkpoint(0), checkpoint(1)],
        "failureEvidence": {
            "active-depth-recovery": {"fallbackAdvanced": True, "recoveredToRunningFreePlay": True, "retrySucceeded": True},
            "inspection-routing": copy.deepcopy(fixtures["inspection-routing"]["result"]),
            "transitions-and-failures": {
                "fixture": "transitions-and-failures", "passed": True,
                "injectedFailures": ["allocation", "pipeline", "reset", "wrong-grid",
                                     "tracer-allocation", "tracer-reset", "tracer-advance"],
                "lessonFailureRecovery": {
                    "twoDLessons": ["Dye carried by a flow", "Two interacting vortices", "Stretching dye by stirring"],
                    "allRecoveredToRunningFreePlay": True, "freePlayPreferencesRetained": True, "failedRestartRetrySucceeded": True,
                },
            },
            "renderer-steps-and-inactivity": {
                "fixture": "renderer-steps-and-inactivity", "passed": True, "exactRendererSteps": [1, 31],
                "reactivationCatchUp": False,
                **{key: True for key in ("solverFaultRecoveredToTwoD", "staleCompletionIgnoredAfterModeTransition",
                   "pausedAndRunningInactivityFrozen", "redrawAndResizeNoOp", "referenceFieldsMatched", "nilDrawable")},
            },
        },
    })
    return {
        "schemaVersion": 1, "kind": "fluid3d-inspection", "evidenceClass": "synthetic-schema-fixture",
        "workload": "offscreen-spatial-inspection-not-fps", "generatedAtUTC": "synthetic-not-run",
        "sourceSHA256": {p: sha256(ROOT / p) for p in SPATIAL_HASHED_SOURCES},
        "completeContractSHA256": sha256(ROOT / "docs/3d-numerical-contract.md"),
        "inspectionContractSHA256": INSPECTION_CONTRACT_HASH,
        "oracleSHA256": sha256(ROOT / "Tests/Integration/inspection3d_reference.swift"),
        "metallibSHA256": "a" * 64, "metallibPath": "synthetic-not-a-metallib",
        "environment": {key: "synthetic" for key in ("device", "hostModel", "os", "xcode", "swift",
                                                   "metalToolchain", "configuration", "architecture")},
        "coverage": copy.deepcopy(INSPECTION_COVERAGE), "configuration": copy.deepcopy(INSPECTION_CONFIGURATION),
        "tolerances": copy.deepcopy(INSPECTION_TOLERANCES), "fixtures": fixtures,
        "regressionMatrix": {
            name: {"status": "PASS", "exitCode": 0, "durationSeconds": 1, "command": ["synthetic-not-run"],
                   "logPath": "synthetic.log", "logSHA256": "a" * 64,
                   **({"testCount": 1} if name not in {"macBuild", "iosBuild"} else {}),
                   **({"xcresultPath": "synthetic.xcresult"} if name in {"macTests", "iphoneHUD", "ipadHUD"} else {})}
            for name in REGRESSION_MATRIX_REQUIRED
        },
    }


def synthetic_evolution_visibility_report() -> dict:
    """Explicitly synthetic passing evolution-visibility report; never written to .build."""

    def observation(step: int, peak: float, count: int, rms: float, area: int) -> dict:
        return {
            "step": step,
            "slicePeak": peak,
            "sliceCountAtLeast0_02": count,
            "sliceAreaAtLeast0_1": area,
            "sliceRMSFromStep0": rms,
            "projection": {"failure": "none", "converged": True, "capHit": False},
        }

    observations = [
        observation(0, 0.67, 160, 0.0, 260),
        observation(1, 0.69, 162, 0.0034, 160),
        observation(10, 0.80, 190, 0.0304, 193),
        observation(20, 0.88, 215, 0.0527, 224),
        observation(24, 0.90, 220, 0.0594, 231),
        observation(48, 0.905, 240, 0.078, 360),
        observation(72, 0.745, 250, 0.072, 255),
    ]
    return add_synthetic_larger_blob_lesson({
        "result": {
            "passed": True,
            "fixture": "evolution-visibility",
            "recipe": {
                "seedMaximumVectorSpeed": 0.15,
                "blobCenter": [0.64, 0.44, 0.62],
                "blobRadius": 0.24,
                "blobPeak": 1.0,
                "dyeDecayPerStep": 0.0,
                "velocityReseedAfterReset": False,
            },
            "observations": observations,
            "velocityChangeNormalizedByResetSpeed": {"u": 0.2, "v": 0.2, "w": 0.2},
            "depthVariationNormalizedByResetSpeed": 0.5,
            "maximumProbeZTravelCells": 2.0,
            "analyticReferenceTrajectory": {"finite": True, "plane_rms_arc_ratio": 0.0166},
            "calibratedEarlyWindow": {
                "amendment": "Human-calibrated early-window visibility amendment — 2026-11-20 (UAT G-07-2)",
                "gates": {
                    "step10RMSFromStep0Minimum": 0.025,
                    "step20RMSFromStep0Minimum": 0.04,
                    "encodedChangeThreshold": 32,
                    "step10EncodedChangeCountMinimum": 100,
                    "sectionAreaThreshold": 0.1,
                    "step0SectionAreaMinimum": 100,
                    "step48SectionAreaRelativeChangeMinimum": 0.30,
                    "earlyWindowSteps": [10, 20, 24, 48],
                    "earlyWindowPeakMinimum": 0.30,
                    "earlyWindowSectionAreaMinimum": 50,
                },
                "observed": {
                    "step10RMSFromStep0": 0.0304,
                    "step20RMSFromStep0": 0.0527,
                    "step10EncodedChangeCount": 160,
                    "sectionArea": {"0": 260, "10": 193, "20": 224, "24": 231, "48": 360},
                    "step48SectionAreaRelativeChange": (360 - 260) / 260,
                    "earlyWindowPeaks": {"10": 0.80, "20": 0.88, "24": 0.90, "48": 0.905},
                },
                "passed": True,
            },
            "lessonRecipe600": {
                "stepsValidated": 600,
                "projectionFailures": 0,
                "capHits": 0,
                "maximumIterations": 144,
                "maximumInputDivergenceDTInf": 7.6e-4,
                "inputDivergenceMarginLimit": 9e-4,
                "reductionGateActiveSteps": 0,
                "minimumReductionWhereGateActive": None,
                "finite": True,
                "volumePeakAt600": 0.25,
                "volumePeakMinimumAt600": 0.05,
                "checkpoints": [
                    {
                        "step": step,
                        "slicePeak": 0.2,
                        "sliceAreaAtLeast0_1": 50,
                        "sliceCountAtLeast0_02": 100,
                        "volumePeak": 0.25 if step == 600 else 0.5,
                        "volumeMass": 540.0,
                        "finite": True,
                        "sliceCapture": f"recipe-step-{step:03d}.ppm",
                    }
                    for step in (100, 200, 300, 400, 500, 600)
                ],
            },
        },
    })


def add_synthetic_larger_blob_lesson(report: dict) -> dict:
    """Give a synthetic evolution-visibility report consistent larger-blob and 1800-step lesson blocks.

    The values are literal and synthetic (never written to .build): V50 310 at step 0, a fade at
    step 300, a return at step 950 and a derived lesson length of 1200.
    """
    result = report["result"]
    step0 = next(item for item in result["observations"] if item["step"] == 0)
    step0["displayVisibleAreaL50"] = 310
    step0["sliceMaximumLightness"] = 86.1
    v50 = {50: 300, 100: 280, 150: 240, 200: 200, 250: 170, 300: 140, 350: 120, 400: 100, 450: 95,
           500: 90, 550: 92, 600: 96, 650: 100, 700: 110, 750: 120, 800: 130, 850: 140, 900: 150,
           950: 165, 1000: 160, 1050: 150, 1100: 140}
    checkpoints = []
    for step in range(50, 1801, 50):
        checkpoints.append({
            "step": step,
            "slicePeak": 0.5,
            "sliceAreaAtLeast0_1": 200,
            "sliceCountAtLeast0_02": 300,
            "displayVisibleAreaL50": v50.get(step, 130 - (step - 1100) // 50),
            "sliceMaximumLightness": 70.5 if step == 950 else 80.0,
            "volumePeak": {1200: 0.33, 1800: 0.22}.get(step, 0.5),
            "volumeMass": 4300.0,
            "finite": True,
            "sliceCapture": f"recipe-step-{step:03d}.ppm",
        })
    result["largerBlobGates"] = {
        "amendment": "Larger-blob, square-root display and 3D lesson-length amendment — 2026-11-21 "
                     "(UAT G-07-2 re-observation)",
        "gates": {
            "step0SectionAreaMinimum": 250,
            "step0DisplayVisibleAreaMinimum": 300,
            "displayLightnessThreshold": 50,
            "fadeFraction": 0.5,
            "returnDisplayVisibleAreaMinimum": 150,
            "returnMaximumLightnessMinimum": 60,
            "returnTailSteps": 100,
            "noFadeVisibleAreaMinimum": 150,
            "noFadeWindowSteps": 1200,
            "lessonLengthChoices": [1200, 1500, 1800],
            "checkpointInterval": 50,
        },
        "observed": {
            "step0SectionArea": step0["sliceAreaAtLeast0_1"],
            "step0DisplayVisibleArea": 310,
            "fadeStep": 300,
            "returnStep": 950,
            "returnDisplayVisibleArea": 165,
            "returnMaximumLightness": 70.5,
            "derivedLessonSteps": 1200,
        },
        "passed": True,
    }
    result["threeDLesson"] = {
        "horizonSteps": 1800,
        "stepsValidated": 1800,
        "projectionFailures": 0,
        "capHits": 0,
        "maximumIterations": 136,
        "maximumInputDivergenceDTInf": 7.5e-4,
        "inputDivergenceMarginLimit": 9e-4,
        "reductionGateActiveSteps": 0,
        "minimumReductionWhereGateActive": None,
        "finite": True,
        "derivedLessonSteps": 1200,
        "volumePeakAtLessonEnd": 0.33,
        "volumePeakAtHorizon": 0.22,
        "volumePeakMinimum": 0.05,
        "checkpoints": checkpoints,
    }
    result["derivedLessonSteps"] = 1200
    return report


def _write_test_ppm(path: Path, lit_pixels: int, color: tuple[int, int, int]) -> None:
    pixels = bytearray(64 * 64 * 3)
    for index in range(lit_pixels):
        pixels[3 * index:3 * index + 3] = bytes(color)
    path.write_bytes(b"P6\n64 64\n255\n" + bytes(pixels))


class Fluid3DTests(unittest.TestCase):
    def test_evolution_visibility_evidence_requires_larger_blob_return_and_lesson_horizon(self):
        report = synthetic_evolution_visibility_report()
        self.assertEqual(_validate_fixture_metrics("evolution-visibility", report), [])
        result = report["result"]
        self.assertEqual(result["largerBlobGates"]["observed"]["fadeStep"], 300)

        def observation(candidate: dict, step: int) -> dict:
            return next(item for item in candidate["result"]["observations"] if item["step"] == step)

        def checkpoint(candidate: dict, step: int) -> dict:
            return next(item for item in candidate["result"]["threeDLesson"]["checkpoints"] if item["step"] == step)

        def set_step0_area(value: int):
            def mutate(candidate: dict) -> None:
                observation(candidate, 0)["sliceAreaAtLeast0_1"] = value
                candidate["result"]["largerBlobGates"]["observed"]["step0SectionArea"] = value
                window = candidate["result"]["calibratedEarlyWindow"]["observed"]
                window["sectionArea"]["0"] = value
                window["step48SectionAreaRelativeChange"] = abs(window["sectionArea"]["48"] - value) / value
            return mutate

        def set_step0_v50(value: int):
            def mutate(candidate: dict) -> None:
                observation(candidate, 0)["displayVisibleAreaL50"] = value
                candidate["result"]["largerBlobGates"]["observed"]["step0DisplayVisibleArea"] = value
            return mutate

        def no_return(candidate: dict) -> None:
            for item in candidate["result"]["threeDLesson"]["checkpoints"]:
                if item["step"] > 300:
                    item["displayVisibleAreaL50"] = 149

        def dim_return(candidate: dict) -> None:
            checkpoint(candidate, 950)["sliceMaximumLightness"] = 59.9
            candidate["result"]["largerBlobGates"]["observed"]["returnMaximumLightness"] = 59.9

        def late_return(candidate: dict) -> None:
            for item in candidate["result"]["threeDLesson"]["checkpoints"]:
                if item["step"] > 300:
                    item["displayVisibleAreaL50"] = {1750: 160, 1800: 150}.get(item["step"], 120)
            observed = candidate["result"]["largerBlobGates"]["observed"]
            observed["returnStep"] = 1750
            observed["returnDisplayVisibleArea"] = 160

        def set_observed(key: str, value):
            def mutate(candidate: dict) -> None:
                candidate["result"]["largerBlobGates"]["observed"][key] = value
            return mutate

        def set_gate(key: str, value):
            def mutate(candidate: dict) -> None:
                candidate["result"]["largerBlobGates"]["gates"][key] = value
            return mutate

        def set_lesson(key: str, value):
            def mutate(candidate: dict) -> None:
                candidate["result"]["threeDLesson"][key] = value
            return mutate

        def nonfinite_checkpoint(candidate: dict) -> None:
            checkpoint(candidate, 600)["finite"] = False

        def missing_checkpoint(candidate: dict) -> None:
            del candidate["result"]["threeDLesson"]["checkpoints"][5]

        def set_recipe(key: str, value):
            def mutate(candidate: dict) -> None:
                candidate["result"]["recipe"][key] = value
            return mutate

        def thin_wall(candidate: dict) -> None:
            candidate["result"]["recipe"]["blobRadius"] = 0.26
            candidate["result"]["recipe"]["blobCenter"] = [0.70, 0.44, 0.62]

        mutations = [
            ("S1 249", set_step0_area(249), "S1"),
            ("S2 299", set_step0_v50(299), "S2"),
            ("fade without return", no_return, "R1"),
            ("return lightness", dim_return, "R1"),
            ("return in final 100 steps", late_return, "R1"),
            ("derived lesson length", set_observed("derivedLessonSteps", 1500), "derivedLessonSteps"),
            ("emitted gates", set_gate("step0SectionAreaMinimum", 200), "largerBlobGates gates"),
            ("1799 steps", set_lesson("stepsValidated", 1799), "stepsValidated"),
            ("cap hit", set_lesson("capHits", 1), "capHits"),
            ("input", set_lesson("maximumInputDivergenceDTInf", 9.1e-4), "input divergence"),
            ("reduction active", set_lesson("reductionGateActiveSteps", 1), "reduction gate"),
            ("nonfinite checkpoint", nonfinite_checkpoint, "checkpoint"),
            ("checkpoint steps", missing_checkpoint, "checkpoint"),
            ("volume peak", set_lesson("volumePeakAtLessonEnd", 0.049), "volume"),
            ("radius", set_recipe("blobRadius", 0.27), "radius"),
            ("peak", set_recipe("blobPeak", 1.3), "peak"),
            ("wall clearance", thin_wall, "wall clearance"),
        ]
        for name, mutate, expected in mutations:
            changed = copy.deepcopy(report)
            mutate(changed)
            errors = _validate_fixture_metrics("evolution-visibility", changed)
            with self.subTest(mutation=name):
                self.assertTrue(errors, f"{name} was accepted")
                self.assertTrue(any(expected in error for error in errors),
                                f"{name}: no error mentions {expected!r}: {errors}")
        for key in ("largerBlobGates", "threeDLesson"):
            changed = copy.deepcopy(report)
            del changed["result"][key]
            with self.subTest(omitted=key):
                self.assertTrue(_validate_fixture_metrics("evolution-visibility", changed))

        # Display captures: V50 and maximum L* are recomputed from the PPM bytes.
        amber = (237, 139, 35)
        self.assertAlmostEqual(_display_lightness(*amber), 67.0, delta=0.2)
        self.assertAlmostEqual(_display_lightness(255, 241, 214), 95.6, delta=0.2)
        with tempfile.TemporaryDirectory() as directory:
            folder = Path(directory)
            _write_test_ppm(folder / "black.ppm", 0, (0, 0, 0))
            _write_test_ppm(folder / "amber.ppm", 300, amber)

            def capture_result(emitted_amber: int) -> dict:
                return {
                    "observations": [
                        {"step": 0, "sliceCapture": "black.ppm", "displayVisibleAreaL50": 0,
                         "sliceMaximumLightness": 0.0},
                        {"step": 1, "sliceCapture": "amber.ppm", "displayVisibleAreaL50": emitted_amber,
                         "sliceMaximumLightness": _display_lightness(*amber)},
                    ],
                    "threeDLesson": {"checkpoints": []},
                }

            self.assertEqual(_validate_evolution_display_captures(capture_result(300), folder), [])
            self.assertTrue(_validate_evolution_display_captures(capture_result(301), folder))
            missing = capture_result(300)
            missing["observations"][1]["sliceCapture"] = "absent.ppm"
            self.assertTrue(_validate_evolution_display_captures(missing, folder))

    def test_inspection_evidence_schema(self):
        # Explicitly synthetic: schema validity never constitutes an actual run.
        self.assertIn("validate_inspection_manifest", globals(),
                      "Phase 8 has no separately versioned evidence validator")
        valid = synthetic_inspection_manifest()
        self.assertEqual(validate_inspection_manifest(valid), [])
        self.assertTrue(validate_inspection_manifest(valid, actual=True))
        for key in valid:
            changed = copy.deepcopy(valid)
            del changed[key]
            with self.subTest(omitted=key):
                self.assertTrue(validate_inspection_manifest(changed))
        for category in ("sourceSHA256", "environment", "configuration", "coverage",
                         "tolerances", "fixtures", "regressionMatrix"):
            for key in valid[category]:
                changed = copy.deepcopy(valid)
                del changed[category][key]
                with self.subTest(category=category, omitted=key):
                    self.assertTrue(validate_inspection_manifest(changed))
        mutations = [
            ("kind", "fluid3d-benchmark"),
            ("workload", "solver-plus-fixed-slice"),
            ("inspectionContractSHA256", "0" * 64),
            ("completeContractSHA256", "0" * 64),
            ("oracleSHA256", "0" * 64),
            ("metallibSHA256", ""),
        ]
        for key, value in mutations:
            changed = copy.deepcopy(valid)
            changed[key] = value
            with self.subTest(corrupted=key):
                self.assertTrue(validate_inspection_manifest(changed))
        for name, report in valid["fixtures"].items():
            for key in report:
                changed = copy.deepcopy(valid)
                del changed["fixtures"][name][key]
                with self.subTest(fixture=name, omitted=key):
                    self.assertTrue(validate_inspection_manifest(changed))
            for key in report["result"]:
                changed = copy.deepcopy(valid)
                del changed["fixtures"][name]["result"][key]
                with self.subTest(fixture=name, result_omitted=key):
                    self.assertTrue(validate_inspection_manifest(changed))
        for name in REGRESSION_MATRIX_REQUIRED:
            for key in valid["regressionMatrix"][name]:
                changed = copy.deepcopy(valid)
                del changed["regressionMatrix"][name][key]
                with self.subTest(matrix=name, omitted=key):
                    self.assertTrue(validate_inspection_manifest(changed))
            changed = copy.deepcopy(valid)
            changed["regressionMatrix"][name]["status"] = "NOT TESTED"
            self.assertTrue(validate_inspection_manifest(changed))
        for key in valid["tolerances"]:
            changed = copy.deepcopy(valid)
            changed["tolerances"][key] *= 10
            self.assertTrue(validate_inspection_manifest(changed))
        for key in valid["coverage"]:
            changed = copy.deepcopy(valid)
            changed["coverage"][key] = "PASS"
            self.assertTrue(validate_inspection_manifest(changed))
        for key in valid["sourceSHA256"]:
            changed = copy.deepcopy(valid)
            changed["sourceSHA256"][key] = "0" * 64
            self.assertTrue(validate_inspection_manifest(changed))
        independence = valid["fixtures"]["inspection-independence"]["result"]
        for key in independence["pausedCases"][0]["metadata"]:
            changed = copy.deepcopy(valid)
            del changed["fixtures"]["inspection-independence"]["result"]["pausedCases"][0]["metadata"][key]
            with self.subTest(metadata_omission=key):
                self.assertTrue(validate_inspection_manifest(changed))
        for name, flags in INSPECTION_FLAGS.items():
            for flag in flags:
                changed = copy.deepcopy(valid)
                changed["fixtures"][name]["result"][flag] = False
                with self.subTest(failed_flag=f"{name}/{flag}"):
                    self.assertTrue(validate_inspection_manifest(changed))
        for key in ("inventory", "negativeChecks", "pausedCases", "equalStepCases",
                    "threeInFlight", "restartComparisons", "failureEvidence"):
            changed = copy.deepcopy(valid)
            value = changed["fixtures"]["inspection-independence"]["result"][key]
            if isinstance(value, list):
                value.pop()
            else:
                value.pop(next(iter(value)))
            with self.subTest(incomplete=key):
                self.assertTrue(validate_inspection_manifest(changed))
        for mutation in ("missing-resource", "renamed", "resized", "nonfinite", "error",
                         "status-bytes", "pending", "step", "drawable", "failure"):
            changed = copy.deepcopy(valid)
            result = changed["fixtures"]["inspection-independence"]["result"]
            resource = result["equalStepCases"][0]["checkpoints"][1]["resources"][0]
            if mutation == "missing-resource":
                result["equalStepCases"][0]["checkpoints"][1]["resources"].pop()
            elif mutation == "renamed":
                resource["name"] = "unexpected"
            elif mutation == "resized":
                resource["byteCount"] += 4
            elif mutation in {"nonfinite", "error"}:
                resource["maximumAbsoluteError"] = math.nan if mutation == "nonfinite" else 3e-6
            elif mutation == "status-bytes":
                result["equalStepCases"][0]["checkpoints"][1]["resources"][-1]["byteMatch"] = False
            elif mutation == "pending":
                result["pausedCases"][0]["metadata"]["pending"] = "0"
            elif mutation == "step":
                result["equalStepCases"][0]["checkpoints"].pop()
            elif mutation == "drawable":
                result["equalStepCases"][-1]["usableDrawableReads"] = 1
            else:
                result["failureEvidence"]["active-depth-recovery"]["retrySucceeded"] = False
            with self.subTest(corruption=mutation):
                self.assertTrue(validate_inspection_manifest(changed))
        self.assertEqual(len(independence["inventory"]), 38)

    def test_evolution_visibility_evidence_requires_calibrated_window_and_600_step_lesson(self):
        report = synthetic_evolution_visibility_report()
        self.assertEqual(_validate_fixture_metrics("evolution-visibility", report), [])

        def observation(candidate: dict, step: int) -> dict:
            return next(item for item in candidate["result"]["observations"] if item["step"] == step)

        def drop_observation(step: int):
            def mutate(candidate: dict) -> None:
                candidate["result"]["observations"] = [
                    item for item in candidate["result"]["observations"] if item["step"] != step
                ]
            return mutate

        def set_rms(step: int, value: float):
            def mutate(candidate: dict) -> None:
                observation(candidate, step)["sliceRMSFromStep0"] = value
                candidate["result"]["calibratedEarlyWindow"]["observed"][f"step{step}RMSFromStep0"] = value
            return mutate

        def set_window(key: str, value):
            def mutate(candidate: dict) -> None:
                candidate["result"]["calibratedEarlyWindow"]["observed"][key] = value
            return mutate

        def set_gate(key: str, value):
            def mutate(candidate: dict) -> None:
                candidate["result"]["calibratedEarlyWindow"]["gates"][key] = value
            return mutate

        def set_peak(step: str, value: float):
            def mutate(candidate: dict) -> None:
                candidate["result"]["calibratedEarlyWindow"]["observed"]["earlyWindowPeaks"][step] = value
            return mutate

        def set_area(step: str, value: int):
            def mutate(candidate: dict) -> None:
                candidate["result"]["calibratedEarlyWindow"]["observed"]["sectionArea"][step] = value
            return mutate

        def set_lesson(key: str, value):
            def mutate(candidate: dict) -> None:
                candidate["result"]["lessonRecipe600"][key] = value
            return mutate

        def set_recipe(key: str, value):
            def mutate(candidate: dict) -> None:
                candidate["result"]["recipe"][key] = value
            return mutate

        def combine(*mutations):
            def mutate(candidate: dict) -> None:
                for item in mutations:
                    item(candidate)
            return mutate

        def nonfinite_checkpoint(candidate: dict) -> None:
            candidate["result"]["lessonRecipe600"]["checkpoints"][2]["finite"] = False

        def short_checkpoints(candidate: dict) -> None:
            del candidate["result"]["lessonRecipe600"]["checkpoints"][-1]

        def small_area_change(candidate: dict) -> None:
            observed = candidate["result"]["calibratedEarlyWindow"]["observed"]
            observed["sectionArea"]["48"] = 290
            observed["step48SectionAreaRelativeChange"] = (290 - 260) / 260
            observation(candidate, 48)["sliceAreaAtLeast0_1"] = 290

        mutations = [
            ("missing step 10", drop_observation(10), "missing step 10"),
            ("missing step 20", drop_observation(20), "missing step 20"),
            ("step-10 RMS", set_rms(10, 0.02), "step-10 RMS"),
            ("step-20 RMS", set_rms(20, 0.03), "step-20 RMS"),
            ("encoded change", set_window("step10EncodedChangeCount", 99), "encoded-change"),
            ("section-area change", small_area_change, "section-area change"),
            ("early-window peak", set_peak("24", 0.29), "early-window peak"),
            ("early-window area", set_area("20", 49), "early-window section area"),
            ("emitted gate", set_gate("step10RMSFromStep0Minimum", 0.01), "gates"),
            ("RMS cross-check", set_window("step10RMSFromStep0", 0.05), "does not match"),
            ("599 steps", set_lesson("stepsValidated", 599), "stepsValidated"),
            ("projection failure", set_lesson("projectionFailures", 1), "projectionFailures"),
            ("cap hit", set_lesson("capHits", 1), "capHits"),
            ("input divergence", set_lesson("maximumInputDivergenceDTInf", 9.5e-4), "input divergence"),
            ("reduction gate active", set_lesson("reductionGateActiveSteps", 1), "reduction gate"),
            ("iteration cap", set_lesson("maximumIterations", 320), "iterations"),
            ("nonfinite checkpoint", nonfinite_checkpoint, "checkpoint"),
            ("missing checkpoint", short_checkpoints, "checkpoint"),
            ("volume peak", set_lesson("volumePeakAt600", 0.04), "volume"),
            ("speed", set_recipe("seedMaximumVectorSpeed", 0.19), "speed"),
            ("speed below envelope", set_recipe("seedMaximumVectorSpeed", 0.11), "speed"),
            ("radius", set_recipe("blobRadius", 0.12), "radius"),
            ("radius above envelope", set_recipe("blobRadius", 0.27), "radius"),
            ("centre x", set_recipe("blobCenter", [0.75, 0.44, 0.62]), "centre"),
            ("equator offset low", set_recipe("blobCenter", [0.64, 0.44, 0.56]), "equator offset"),
            ("equator offset high", set_recipe("blobCenter", [0.64, 0.44, 0.70]), "equator offset"),
            ("wall clearance", combine(set_recipe("blobRadius", 0.26), set_recipe("blobCenter", [0.70, 0.44, 0.62])),
             "wall clearance"),
            ("blob peak", set_recipe("blobPeak", 1.3), "peak"),
            ("decay", set_recipe("dyeDecayPerStep", 0.01), "decay"),
            ("reseed", set_recipe("velocityReseedAfterReset", True), "reseed"),
        ]
        for name, mutate, expected in mutations:
            changed = copy.deepcopy(report)
            mutate(changed)
            errors = _validate_fixture_metrics("evolution-visibility", changed)
            with self.subTest(mutation=name):
                self.assertTrue(errors, f"{name} was accepted")
                self.assertTrue(
                    any(expected in error for error in errors),
                    f"{name}: no error mentions {expected!r}: {errors}",
                )

        for key in ("calibratedEarlyWindow", "lessonRecipe600", "recipe"):
            changed = copy.deepcopy(report)
            del changed["result"][key]
            with self.subTest(omitted=key):
                self.assertTrue(_validate_fixture_metrics("evolution-visibility", changed))

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
            "fluid3DPCGProjectResidualPartial", "fluid3DProjectPreconditioner",
            "fluid3DPCGUpdateStatePartial", "fluid3DProjectDirection", "fluid3DNormalizePressureGauge",
            "fluid3DPCGApplySearchDot", "fluid3DPCGCandidateResidualPartial",
            "fluid3DPCGPreconditionPartial", "fluid3DPCGProjectPreconditionerDot",
            "fluid3DPCGUpdateDirectionPartial",
        ]:
            start = source.index("kernel void " + name + "(")
            end = source.index("\n}", start)
            body = source[start:end]
            with self.subTest(kernel=name):
                self.assertRegex(body, r"device const float4 \*state")
                # Assignment or compound assignment, but not an == comparison.
                self.assertNotRegex(body, r"state\[\d+\](?:\.[xyzw])?\s*(?:[+*/-]?=)(?!=)")

    def test_evidence_hashes_python_driver(self):
        self.assertIn("Tests/Integration/test_fluid3d.py", HASHED_SOURCES)

    def test_spatial_source_inventory_is_separate_from_historical_fixture_inventory(self):
        self.assertEqual(SPATIAL_HASHED_SOURCES[:len(HASHED_SOURCES)], HASHED_SOURCES)
        self.assertIn("Tests/Integration/inspection3d_reference.swift", SPATIAL_HASHED_SOURCES)
        self.assertIn("Tests/Integration/test_inspection3d_reference.py", SPATIAL_HASHED_SOURCES)
        self.assertIn("docs/3d-inspection-contract.md", SPATIAL_HASHED_SOURCES)
        self.assertNotIn("Tests/Integration/inspection3d_reference.swift", HASHED_SOURCES)

    def test_tracer_fixture_evidence_requires_forward_rk2_and_failure_guards(self):
        result = {
            "passed": True,
            "fixture": "tracer-evolution",
            "markerCount": 512,
            "positionBufferBytes": 8192,
            "forwardCaseNames": [
                "positive_x", "negative_x", "positive_y", "negative_y",
                "positive_z", "negative_z", "combined_xyz", "combined_mixed",
            ],
            "forwardComparedPositions": 4096,
            "boundaryProbeCount": 27,
            "affineProbeCount": 28,
            "productionStepCount": 48,
            "threeQueuedSubmissionsChecked": True,
            "currentFailureGuarded": True,
            "priorFailureGuarded": True,
            "noFluidFeedback": True,
            "finite": True,
            "positionsInBounds": True,
            "rendererScheduling": {
                "nilDrawable": True,
                "initialSeedsExact": True,
                "pausedPresentationsUnchanged": True,
                "threeQueuedCommands": True,
                "acceptedStepCount": 3,
                "validatedCompletionCount": 3,
                "latestCompletedStatusRetained": True,
                "hiddenVisiblePositionsEqual": True,
                "hiddenAdvanced": True,
                "visibilityDoesNotReseed": True,
                "restartRestoresSeeds": True,
                "restartRetainsInspection": True,
            },
        }
        report = {"result": result}
        self.assertEqual(_validate_fixture_metrics("tracer-evolution", report), [])

        missing_prior_guard = copy.deepcopy(report)
        del missing_prior_guard["result"]["priorFailureGuarded"]
        self.assertIn(
            "tracer-evolution is missing required regression evidence: priorFailureGuarded",
            _validate_fixture_metrics("tracer-evolution", missing_prior_guard),
        )

        missing_scheduler_evidence = copy.deepcopy(report)
        del missing_scheduler_evidence["result"]["rendererScheduling"]["hiddenAdvanced"]
        self.assertIn(
            "tracer-evolution renderer scheduling is missing required regression evidence: hiddenAdvanced",
            _validate_fixture_metrics("tracer-evolution", missing_scheduler_evidence),
        )

    def test_transition_fixture_requires_free_play_recovery_from_each_2d_lesson(self):
        report = {
            "result": {
                "passed": True,
                "fixture": "transitions-and-failures",
                "lessonFailureRecovery": {
                    "twoDLessons": [
                        "Dye carried by a flow",
                        "Two interacting vortices",
                        "Stretching dye by stirring",
                    ],
                    "allRecoveredToRunningFreePlay": True,
                    "freePlayPreferencesRetained": True,
                    "failedRestartRetrySucceeded": True,
                },
            }
        }
        self.assertEqual(_validate_fixture_metrics("transitions-and-failures", report), [])
        del report["result"]["lessonFailureRecovery"]["freePlayPreferencesRetained"]
        self.assertIn(
            "transitions-and-failures is missing required regression evidence: freePlayPreferencesRetained",
            _validate_fixture_metrics("transitions-and-failures", report),
        )

    def test_inspection_routing_requires_transactional_tracer_reset_and_step_evidence(self):
        report = {
            "result": {
                "passed": True,
                "fixture": "inspection-routing",
                "nilDrawablePresentation": True,
                "pausedPendingStepsPreserved": True,
                "tracerInitialSeedsExact": True,
                "hiddenTracerStepAdvanced": True,
                "restartRetainsInspection": True,
                "restartRestoresTracerSeeds": True,
                "reselectionRestoresDefaults": True,
            }
        }
        self.assertEqual(_validate_fixture_metrics("inspection-routing", report), [])
        del report["result"]["restartRestoresTracerSeeds"]
        self.assertIn(
            "inspection-routing is missing required regression evidence: restartRestoresTracerSeeds",
            _validate_fixture_metrics("inspection-routing", report),
        )

    def test_renderer_sources_and_fault_seams_cover_tracer_ownership(self):
        renderer_source = (ROOT / "Sources/Shared/Renderer.swift").read_text(encoding="utf-8")
        for seam in ("makeTracers", "encodeTracerReset", "encodeTracerAdvance"):
            with self.subTest(seam=seam):
                self.assertIn(seam, renderer_source)

        project = (ROOT / "FluidDynamicsMetal.xcodeproj/project.pbxproj").read_text(encoding="utf-8")
        self.assertIn("TracerSystem3D.swift in state test Sources", project)

        for relative_path in (
            "Tests/Integration/test_renderer_correctness.py",
            "Tests/Integration/test_educational_release.py",
        ):
            with self.subTest(source_list=relative_path):
                source = (ROOT / relative_path).read_text(encoding="utf-8")
                self.assertIn("TracerSystem3D.swift", source)

    def test_tracer_evidence_uses_inspection_reference_and_source_inventory(self):
        inspection_reference = ROOT / ".build/inspection3d-reference/manifest.json"
        solver_reference = ROOT / ".build/fluid3d-reference/manifest.json"
        evidence_directory = ROOT / ".build/fluid3d-evidence"
        self.assertEqual(
            SPATIAL_FIXTURES,
            frozenset({"spatial-slices", "tracer-evolution", "tracer-occlusion", "inspection-independence"}),
        )
        self.assertEqual(_fixture_reference_manifest_path("tracer-evolution"), inspection_reference)
        self.assertEqual(_fixture_reference_manifest_path("tracer-occlusion"), inspection_reference)
        self.assertEqual(_fixture_reference_manifest_path("spatial-slices"), inspection_reference)
        self.assertEqual(_fixture_reference_manifest_path("projection"), solver_reference)
        self.assertEqual(_fixture_source_inventory("tracer-evolution"), SPATIAL_HASHED_SOURCES)
        self.assertEqual(_fixture_source_inventory("tracer-occlusion"), SPATIAL_HASHED_SOURCES)
        self.assertEqual(_fixture_source_inventory("spatial-slices"), SPATIAL_HASHED_SOURCES)
        self.assertEqual(_fixture_source_inventory("projection"), HASHED_SOURCES)
        self.assertEqual(
            _fixture_capture_directory("tracer-occlusion", evidence_directory),
            ROOT / ".build/inspection3d-evidence",
        )

    def test_tracer_occlusion_fixture_requires_production_image_evidence(self):
        measurements = {
            "oneXDiameterPixels": 3,
            "twoXDiameterPixels": 6,
            "oneXDiameterPoints": 3,
            "twoXDiameterPoints": 3,
        }
        keys = (
            "frontMarkersVisibleInBlack",
            "behindMarkersHiddenInBlack",
            "frontMarkersVisibleInDyed",
            "behindMarkersHiddenInDyed",
            "outsideFootprintVisible",
            "oppositeSideOcclusionReversed",
            "discCornersDiscarded",
            "edgeOnMarkersRemainCircular",
            "oneXThreePointDiameter",
            "twoXThreePointDiameter",
            "markerColorIsExact",
            "blackSheetRemainsOpaque",
            "dyedSheetRemainsOpaque",
        )
        report = {
            "result": {
                "passed": True,
                "fixture": "tracer-occlusion",
                "measurements": measurements,
                **{key: True for key in keys},
            }
        }
        self.assertIn("tracer-occlusion", PRODUCTION_FIXTURES)
        self.assertEqual(_fixture_source_inventory("tracer-occlusion"), SPATIAL_HASHED_SOURCES)
        self.assertEqual(_validate_fixture_metrics("tracer-occlusion", report), [])

        missing_black_occlusion = copy.deepcopy(report)
        del missing_black_occlusion["result"]["behindMarkersHiddenInBlack"]
        self.assertIn(
            "tracer-occlusion is missing required regression evidence: behindMarkersHiddenInBlack",
            _validate_fixture_metrics("tracer-occlusion", missing_black_occlusion),
        )

    def test_native_tracer_source_contract_includes_copy_accessibility_and_failure_scope(self):
        source = (ROOT / "Sources/macOS/RenderViewController.swift").read_text(encoding="utf-8")
        for text in (
            "inspection3d.showTracers",
            "Pale-cyan dots follow the flow, even while hidden.",
            "Show or hide passive markers. Hidden markers keep moving with simulation steps.",
            "Pale-cyan dots are passive tracers. Tracers behind the opaque slice are hidden, even where the slice is black.",
            "Couldn’t continue 3D Dye Advection",
            "The 3D view could not be updated. Free Play has been restored. Continue in 2D, or choose 3D Dye Advection again to retry.",
        ):
            with self.subTest(text=text):
                self.assertIn(text, source)

    def test_spatial_fixture_evidence_requires_cube_resource_and_camera_checks(self):
        report = {
            "result": {
                "passed": True,
                "fixture": "spatial-slices",
                "cubeEdgesChecked": 12,
                "cubeGuidePointScaleRatio": 4.0,
                "cubeDepthAttachmentReuseAllocations": 2,
                "cubeSpatialPipelineAllocations": 3,
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

    def test_slice_palette_evidence_requires_square_root_transfer(self):
        def passing_report() -> dict:
            return {
                "result": {
                    "passed": True,
                    "fixture": "slice-palette",
                    "renderingReadOnly": True,
                    "finite": True,
                    "sampledPlanes": [31, 32],
                    "sampleWeights": [0.5, 0.5],
                    "displayTransfer": "square-root",
                    "paletteStops": [
                        {"displayValue": 0.0, "concentration": 0.0, "rgb": [0, 0, 0]},
                        {"displayValue": 0.5, "concentration": 0.25, "rgb": [237, 139, 35]},
                        {"displayValue": 1.0, "concentration": 1.0, "rgb": [255, 241, 214]},
                    ],
                    "transferSamples": [
                        {"concentration": 0.0, "rgb": [0, 0, 0]},
                        {"concentration": 0.015625, "rgb": [59, 35, 9]},
                        {"concentration": 0.25, "rgb": [237, 139, 35]},
                        {"concentration": 0.5, "rgb": [244, 181, 109]},
                        {"concentration": 0.75, "rgb": [250, 214, 166]},
                        {"concentration": 1.0, "rgb": [255, 241, 214]},
                        {"concentration": 1.25, "rgb": [255, 241, 214]},
                    ],
                }
            }

        self.assertEqual(_validate_fixture_metrics("slice-palette", passing_report()), [])

        def mutated(mutate) -> dict:
            report = passing_report()
            mutate(report["result"])
            return report

        mutations = {
            "missing displayTransfer": lambda r: r.pop("displayTransfer"),
            "linear displayTransfer": lambda r: r.__setitem__("displayTransfer", "linear"),
            "linear stop concentrations": lambda r: r["paletteStops"][1].__setitem__("concentration", 0.5),
            "wrong display values": lambda r: r["paletteStops"][1].__setitem__("displayValue", 0.25),
            "wrong amber rgb": lambda r: r["paletteStops"][1].__setitem__("rgb", [119, 70, 18]),
            "wrong cream rgb": lambda r: r["paletteStops"][2].__setitem__("rgb", [255, 241, 215]),
            "missing quarter sample": lambda r: r.__setitem__(
                "transferSamples", [s for s in r["transferSamples"] if s["concentration"] != 0.25]
            ),
            "dim quarter sample": lambda r: [
                s.__setitem__("rgb", [119, 70, 18]) for s in r["transferSamples"] if s["concentration"] == 0.25
            ],
        }
        for name, mutate in mutations.items():
            with self.subTest(mutation=name):
                errors = _validate_fixture_metrics("slice-palette", mutated(mutate))
                self.assertTrue(errors, f"{name} must be rejected")

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

    def test_inspection_routing(self):
        self.run_production_fixture("inspection-routing")

    def test_tracer_evolution(self):
        self.run_production_fixture("tracer-evolution")

    def test_tracer_occlusion(self):
        self.run_production_fixture("tracer-occlusion")

    def test_inspection_independence(self):
        result = self.run_production_fixture("inspection-independence")
        self.assertEqual({case["schedule"] for case in result.get("equalStepCases", [])},
                         {"shown", "hidden", "alternating", "nil-drawable"})
        self.assertTrue(result.get("restartCompleteInventoryMatched"))
        self.assertGreaterEqual(len(result.get("pausedCases", [])), 20)
        for case in result["equalStepCases"]:
            self.assertEqual([item["step"] for item in case["checkpoints"]], [0, 1, 24, 48])
            for checkpoint in case["checkpoints"]:
                resources = checkpoint["resources"]
                self.assertEqual(len(resources), 38 if checkpoint["step"] == 0 else 39)
                for resource in resources:
                    self.assertTrue(math.isfinite(resource["maximumAbsoluteError"]))
                    self.assertLessEqual(resource["maximumAbsoluteError"], 2e-6)
                    if resource["name"].startswith("status/"):
                        self.assertTrue(resource["byteMatch"])
                self.assertEqual(checkpoint["metadata"]["steps"], str(checkpoint["step"]))
                self.assertEqual(checkpoint["metadata"]["pending"], "0")
        for case in result["pausedCases"]:
            self.assertEqual(case["metadata"]["pending"], "2")

    def run_production_fixture(self, fixture: str) -> dict:
        started = time.monotonic()
        evidence_dir = ROOT / ".build/fluid3d-evidence"
        reference_dir = ROOT / ".build/fluid3d-reference"
        evidence_dir.mkdir(parents=True, exist_ok=True)
        log_path = evidence_dir / f"{fixture}.log"
        if log_path.exists():
            log_path.rename(log_path.with_name(f"{fixture}.previous-{time.time_ns()}.log"))

        fixture_sources = _fixture_source_inventory(fixture)
        missing = [str(ROOT / source) for source in fixture_sources if not (ROOT / source).is_file()]
        self.assertFalse(missing, "Missing required production/test sources:\n" + "\n".join(missing))

        if fixture in SPATIAL_FIXTURES:
            reference_dir = _fixture_reference_manifest_path(fixture).parent
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
            INSPECTION_CONTRACT_HASH
            if fixture in SPATIAL_FIXTURES
            else CONTRACT_HASH,
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
                "execution": {
                    "status": "PASS", "exitCode": run_result.returncode,
                    "durationSeconds": time.monotonic() - started,
                    "logPath": str(log_path.relative_to(ROOT)), "logSHA256": sha256(log_path),
                },
                "result": result,
            }
            report_path = evidence_dir / f"{fixture}.json"
            report_path.write_text(
                json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8"
            )
            if fixture in INSPECTION_FIXTURES:
                inspection_report = ROOT / ".build/inspection3d-evidence" / f"{fixture}.json"
                inspection_report.parent.mkdir(parents=True, exist_ok=True)
                inspection_report.write_text(
                    json.dumps(report, indent=2, sort_keys=True, allow_nan=False) + "\n",
                    encoding="utf-8",
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
            if fixture == "evolution-visibility":
                capture_errors = _validate_evolution_display_captures(report["result"], evidence_dir)
                self.assertEqual(capture_errors, [], "evolution-visibility display captures disagree with the report")
            print(f"PASS: {fixture}; evidence: {report_path}")
            return result


def main() -> int:
    parser = argparse.ArgumentParser(description="Production 3D Metal fixtures and evidence validation")
    actions = parser.add_mutually_exclusive_group()
    actions.add_argument("--benchmark", action="store_true", help="run solver-only and solver-plus-slice baselines")
    actions.add_argument("--check-evidence", action="store_true", help="validate current 3D evidence artifacts")
    actions.add_argument("--verify-inspection-evidence", type=Path,
                         help="validate separately versioned actual Phase 8 evidence")
    parser.add_argument("--quick", action="store_true", help="check schema, hashes, and required files only")
    parser.add_argument(
        "--evidence-dir",
        type=Path,
        default=ROOT / ".build/fluid3d-evidence",
        help="evidence directory (default: .build/fluid3d-evidence)",
    )
    args, unittest_args = parser.parse_known_args()
    if args.verify_inspection_evidence:
        errors = validate_inspection_bundle(args.verify_inspection_evidence.resolve())
        if errors:
            print("FAIL: inspection evidence:\n- " + "\n- ".join(errors))
            return 1
        print("PASS: fresh actual inspection evidence and full matrix; human review PENDING; pacing NOT MEASURED.")
        return 0
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
