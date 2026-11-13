"""Independent preregistered inspection expectations; no production/GPU dependency."""
import copy
import hashlib
import json
import math
from pathlib import Path
import struct
import subprocess
import time
import unittest

ROOT = Path(__file__).resolve().parents[2]
CONTRACT = ROOT / "docs/3d-inspection-contract.md"
SOURCE = ROOT / "Tests/Integration/inspection3d_reference.swift"
BUILD = ROOT / ".build/inspection3d-reference"
CONTRACT_HASH = "7f793d4ecfff13e7138a96e354f7597a9da9db88853c657d47a23ae09955e0c7"
PHASE7_HASH = "5fdc33b839d7f135a828ac9e6e3c3b4e7adba03d5341771ddbed4b13767951a8"


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
        self.assertEqual(len(manifest["trajectories"]), 9)
        for item in manifest["trajectories"]:
            self.assertEqual(len(item["positions"]), 49)
            for p in item["positions"]:
                self.assertTrue(all(math.isfinite(x) and 0 <= x <= 1 for x in p))
            if item["name"] != "wall_edge_corner":
                for a in range(3):
                    self.assertAlmostEqual(item["positions"][1][a], .5 + item["velocity"][a]/60, places=12)
                    self.assertAlmostEqual(item["positions"][48][a], .5 + 48*item["velocity"][a]/60, places=12)
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
