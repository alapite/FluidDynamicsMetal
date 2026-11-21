"""Independent preregistered inspection expectations; no production/GPU dependency."""
import copy
import hashlib
import json
import math
from pathlib import Path
import struct
import subprocess
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[2]
CONTRACT = ROOT / "docs/3d-inspection-contract.md"
SOURCE = ROOT / "Tests/Integration/inspection3d_reference.swift"
BUILD = ROOT / ".build/inspection3d-reference"
CONTRACT_HASH = "ac824cffb3cb3db141cf1c03f9425cd67797db0586246480a258ddd06a502cbb"
# Tracks the complete amended numerical contract; repinned with each dated amendment (the prefix stays pinned by CONTRACT_HASH in test_fluid3d.py).
PHASE7_HASH = "1f396b713eb126c084c71a3cd8465f264f869991db1be23ca6e87bb726aa8aa3"


def validate_export(directory, contract_hash):
    manifest = json.loads((directory / "manifest.json").read_text())
    if manifest["contractHash"] != contract_hash or manifest["schemaVersion"] != 1:
        raise ValueError("contract/schema mismatch")
    payload = (directory / "expectations.f64le").read_bytes()
    if len(payload) != manifest["byteCount"] or len(payload) != 512 * 4 * 8:
        raise ValueError("malformed binary length")
    if hashlib.sha256(payload).hexdigest() != manifest["sha256"]:
        raise ValueError("binary hash mismatch")
    values = [v for (v,) in struct.iter_unpack("<d", payload)]
    if not all(math.isfinite(v) for v in values):
        raise ValueError("nonfinite fixture")
    return manifest, values


def _fold_coordinate(value):
    folded = value % 2.0
    return (folded, 1.0) if folded <= 1.0 else (2.0 - folded, -1.0)


def _sample_affine_mac(position, component):
    offsets = [0.5, 0.5, 0.5]
    offsets[component] = 0.0
    folded = []
    parity = []
    for coordinate in position:
        value, sign = _fold_coordinate(coordinate)
        folded.append(value)
        parity.append(sign)
    lattice = [folded[axis] * 64 - offsets[axis] for axis in range(3)]
    base = [math.floor(value) for value in lattice]
    fraction = [lattice[axis] - base[axis] for axis in range(3)]
    total = 0.0
    for mask in range(8):
        indices = []
        weight = 1.0
        wall_face = False
        for axis in range(3):
            upper = (mask >> axis) & 1
            index = base[axis] + upper
            weight *= fraction[axis] if upper else 1 - fraction[axis]
            if axis == component:
                index = min(64, max(0, index))
                wall_face = wall_face or index in (0, 64)
            elif index < 0:
                index = -index - 1
            elif index >= 64:
                index = 127 - index
            indices.append(index)
        if wall_face:
            sample = 0.0
        else:
            point = [(indices[axis] + offsets[axis]) / 64 for axis in range(3)]
            sample = (component + 1) * 0.01 + 0.02 * point[0] - 0.03 * point[1] + 0.04 * point[2]
        total += weight * sample
    return total * parity[component]


def _advance_affine_mac(position):
    first = [_sample_affine_mac(position, component) for component in range(3)]
    midpoint = [min(1.0, max(0.0, position[axis] + first[axis] / 120)) for axis in range(3)]
    second = [_sample_affine_mac(midpoint, component) for component in range(3)]
    return [min(1.0, max(0.0, position[axis] + second[axis] / 60)) for axis in range(3)]


class InspectionReferenceTests(unittest.TestCase):
    def test_contract_and_oracle(self):
        self.assertTrue(CONTRACT.is_file(), "preregistered inspection contract missing")
        self.assertEqual(hashlib.sha256(CONTRACT.read_bytes()).hexdigest(), CONTRACT_HASH)
        self.assertEqual(hashlib.sha256((ROOT / "docs/3d-numerical-contract.md").read_bytes()).hexdigest(), PHASE7_HASH)
        self.assertTrue(SOURCE.is_file(), "independent Double oracle missing")
        BUILD.mkdir(parents=True, exist_ok=True)
        started = time.perf_counter()
        compiled = subprocess.run(["swiftc", "-O", "-parse-as-library", str(SOURCE), "-o", str(BUILD / "oracle")], capture_output=True, text=True, timeout=180)
        self.assertEqual(compiled.returncode, 0, compiled.stdout + compiled.stderr)
        compile_seconds = time.perf_counter() - started
        started = time.perf_counter()
        def run(contract=CONTRACT, extra=()):
            return subprocess.run([str(BUILD / "oracle"), str(contract), str(BUILD), *extra], capture_output=True, text=True, timeout=30)
        result = run()
        self.assertEqual(result.returncode, 0, result.stderr)
        manifest, seeds = validate_export(BUILD, CONTRACT_HASH)
        original = (BUILD / "manifest.json").read_bytes(), (BUILD / "expectations.f64le").read_bytes()
        self.assertEqual(run().returncode, 0)
        self.assertEqual(original, ((BUILD / "manifest.json").read_bytes(), (BUILD / "expectations.f64le").read_bytes()))
        with tempfile.TemporaryDirectory(dir=BUILD, prefix="negative-") as temporary:
            negative = Path(temporary)
            with self.assertRaises(FileNotFoundError):
                validate_export(negative, CONTRACT_HASH)
            (negative / "manifest.json").write_text("not-json")
            with self.assertRaises(json.JSONDecodeError):
                validate_export(negative, CONTRACT_HASH)
            (negative / "manifest.json").write_bytes(original[0])
            (negative / "expectations.f64le").write_bytes(original[1][:-8])
            with self.assertRaisesRegex(ValueError, "length"):
                validate_export(negative, CONTRACT_HASH)
            changed = bytearray(original[1]); changed[0] ^= 1
            (negative / "expectations.f64le").write_bytes(changed)
            with self.assertRaisesRegex(ValueError, "hash"):
                validate_export(negative, CONTRACT_HASH)
        expected = [v for k in range(8) for j in range(8) for i in range(8) for v in ((i+.5)/8, (j+.5)/8, (k+.5)/8, 1.)]
        self.assertEqual(seeds, expected)
        self.assertEqual(len(manifest["slices"]), 12)
        for item in manifest["slices"]:
            s, t, d = .23, .67, item["depth"]
            world = {"xy": [s,t,d], "xz": [s,d,t], "yz": [d,t,s]}[item["plane"]]
            self.assertEqual(item["world"], world)
            xyz = [min(63.5/64, max(.5/64, x)) for x in world]
            self.assertAlmostEqual(item["value"], .1 + .2*xyz[0] + .3*xyz[1] + .4*xyz[2], places=12)
            self.assertAlmostEqual(item["landmark"], 7*xyz[0]+19*xyz[1]+43*xyz[2], places=11)
        self.assertEqual(manifest["midpointPlanes"], [31,32])
        self.assertLessEqual(manifest["midpointError"], 1e-12)
        self.assertGreaterEqual(manifest["reflectionCases"], 26)
        self.assertLessEqual(manifest["reflectionError"], 1e-12)
        self.assertLessEqual(manifest["affineMACError"], 1e-12)
        self.assertEqual(manifest["tracerGridCells"], 64)
        forward_cases = {item["name"]: item for item in manifest["forwardRK2Cases"]}
        expected_names = {
            "positive_x", "negative_x", "positive_y", "negative_y",
            "positive_z", "negative_z", "combined_xyz", "combined_mixed",
        }
        self.assertEqual(set(forward_cases), expected_names)
        seed_positions = [
            [seeds[offset], seeds[offset + 1], seeds[offset + 2]]
            for offset in range(0, len(seeds), 4)
        ]
        for name, item in forward_cases.items():
            self.assertEqual(len(item["positions"]), 512, name)
            velocity = item["velocity"]
            for start, actual in zip(seed_positions, item["positions"]):
                self.assertEqual(len(actual), 3)
                for axis in range(3):
                    expected = start[axis] + velocity[axis] / 60
                    self.assertAlmostEqual(actual[axis], expected, places=12, msg=name)
                    self.assertTrue(math.isfinite(actual[axis]) and 0 <= actual[axis] <= 1)

        self.assertEqual(len(manifest["boundaryProbes"]), 27)
        boundary_velocity = manifest["boundaryProbeVelocity"]
        for item in manifest["boundaryProbes"]:
            point = item["initial"]
            first = [
                boundary_velocity[axis] * min(1.0, 64 * point[axis], 64 * (1 - point[axis]))
                for axis in range(3)
            ]
            midpoint = [min(1.0, max(0.0, point[axis] + first[axis] / 120)) for axis in range(3)]
            second = [
                boundary_velocity[axis] * min(1.0, 64 * midpoint[axis], 64 * (1 - midpoint[axis]))
                for axis in range(3)
            ]
            expected = [min(1.0, max(0.0, point[axis] + second[axis] / 60)) for axis in range(3)]
            for actual, reference in zip(item["expected"], expected):
                self.assertAlmostEqual(actual, reference, places=12)

        self.assertEqual(len(manifest["affineTracerProbes"]), 28)
        for item in manifest["affineTracerProbes"]:
            expected = _advance_affine_mac(item["initial"])
            for actual, reference in zip(item["expected"], expected):
                self.assertAlmostEqual(actual, reference, places=12)

        self.assertEqual(len(manifest["trajectories"]), 9)
        for item in manifest["trajectories"]:
            self.assertEqual(len(item["positions"]), 49)
            for p in item["positions"]:
                self.assertTrue(all(math.isfinite(x) and 0 <= x <= 1 for x in p))
            if item["name"] != "wall_edge_corner":
                for a in range(3):
                    self.assertAlmostEqual(item["positions"][1][a], .5 + item["velocity"][a]/60, places=12)
                    self.assertAlmostEqual(item["positions"][48][a], .5 + 48*item["velocity"][a]/60, places=12)
        # Independent closed-form reconstruction of a constant interior MAC
        # component: the one-cell normal boundary interval tapers to zero.
        self.assertEqual(len(manifest["wallTrajectories"]), 26)
        for item in manifest["wallTrajectories"]:
            p = item["positions"][0]
            for actual in item["positions"][1:]:
                def sample(x, a):
                    return item["velocity"][a] * min(1, 64*x[a], 64*(1-x[a]))
                mid = [min(1,max(0,p[a]+sample(p,a)/120)) for a in range(3)]
                p = [min(1,max(0,p[a]+sample(mid,a)/60)) for a in range(3)]
                for a in range(3):
                    self.assertAlmostEqual(actual[a], p[a], places=12)
        p = [.31,.42,.57]
        for actual in manifest["affineTrajectory"]:
            def affine_velocity(x):
                return [(a+1)*.01+.02*x[0]-.03*x[1]+.04*x[2] for a in range(3)]
            first = affine_velocity(p)
            mid = [p[a]+first[a]/120 for a in range(3)]
            second = affine_velocity(mid)
            p = [p[a]+second[a]/60 for a in range(3)]
            for a in range(3):
                self.assertAlmostEqual(actual[a], p[a], places=12)
        # Exercise actual rejection, not a declared boolean in a manifest.
        corrupt = BUILD / "corrupt-contract.md"
        corrupt.write_bytes(CONTRACT.read_bytes() + b"corrupt")
        self.assertNotEqual(run(corrupt).returncode, 0)
        self.assertNotEqual(run(extra=("--nonfinite",)).returncode, 0)
        bad = bytearray(original[1]); bad[:8] = struct.pack("<d", math.nan)
        (BUILD / "expectations.f64le").write_bytes(bad)
        mutated = copy.deepcopy(manifest); mutated["sha256"] = hashlib.sha256(bad).hexdigest()
        (BUILD / "manifest.json").write_text(json.dumps(mutated))
        with self.assertRaisesRegex(ValueError, "nonfinite"):
            validate_export(BUILD, CONTRACT_HASH)
        (BUILD / "manifest.json").write_bytes(original[0])
        (BUILD / "expectations.f64le").write_bytes(original[1])
        print(f"PASS independent inspection oracle: compile={compile_seconds:.3f}s run/checks={time.perf_counter()-started:.3f}s")
