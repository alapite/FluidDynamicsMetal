"""Diagnostic only: pressure quantization, not production GPU acceptance.

Run after exporting the independent reference manifest. Measures b-Aq for the
analytic cosine pressure rounded once to Float32, using Float32 input velocities
but independent Double arithmetic for D and A. A failed rounding candidate is
not a proof that every possible Float32 pressure fails, nor a solver PASS.
"""

import array
import json
import math
from pathlib import Path
import struct
import sys


def float32(value):
    return struct.unpack("<f", struct.pack("<f", value))[0]


def diagnose(reference_directory):
    manifest = json.loads((reference_directory / "manifest.json").read_text())
    payload = next(
        item for item in manifest["binaryPayloads"]
        if item["fixture"] == "manufactured_cosine"
    )
    values = array.array("d")
    values.frombytes((reference_directory / payload["file"]).read_bytes())
    if sys.byteorder != "little":
        values.byteswap()
    fields = {}
    start = 0
    for item in payload["arrayOrder"]:
        count = math.prod(item["shape"])
        fields[item["name"]] = values[start:start + count]
        start += count
    if start != len(values):
        raise ValueError("Reference payload size does not match its declared shapes")

    n = 64
    h = 1 / n
    dt = float32(1 / 60)
    target = 1e-5 * h * h / dt
    u, v, w = (
        [float32(value) for value in fields[name]]
        for name in ("u_input", "v_input", "w_input")
    )
    pressure = [
        float32(
            math.cos(math.pi * (i + 0.5) / n)
            * math.cos(2 * math.pi * (j + 0.5) / n)
            * math.cos(3 * math.pi * (k + 0.5) / n)
        )
        for k in range(n) for j in range(n) for i in range(n)
    ]
    maximum = 0.0
    maximum_location = None
    cells_over_target = 0
    for k in range(n):
        for j in range(n):
            for i in range(n):
                cell = (k * n + j) * n + i
                ui = (k * n + j) * (n + 1) + i
                vi = (k * (n + 1) + j) * n + i
                flux = (
                    u[ui + 1] - u[ui]
                    + v[vi + n] - v[vi]
                    + w[cell + n * n] - w[cell]
                )
                applied = sum(
                    pressure[cell] - pressure[cell + offset]
                    for include, offset in (
                        (i > 0, -1), (i + 1 < n, 1),
                        (j > 0, -n), (j + 1 < n, n),
                        (k > 0, -n * n), (k + 1 < n, n * n),
                    )
                    if include
                )
                residual = abs(-h * flux - applied)
                if residual > maximum:
                    maximum = residual
                    maximum_location = [i, j, k]
                cells_over_target += residual > target
    return {
        "diagnosticOnly": True,
        "productionAcceptance": False,
        "contractHash": manifest["contractHash"],
        "referencePayloadSHA256": payload["sha256"],
        "pressure": "analytic exact cosine rounded once to Float32; not a PCG iterate",
        "operatorArithmetic": "independent Double D and A on Float32 inputs",
        "rawResidualTarget": target,
        "independentResidualMax": maximum,
        "independentResidualDT": maximum * dt / (h * h),
        "maxLocation": maximum_location,
        "cellsOverTarget": cells_over_target,
        "provesAllFloat32SolutionsImpossible": False,
    }


if __name__ == "__main__":
    root = Path(__file__).resolve().parents[2]
    print(json.dumps(diagnose(root / ".build/fluid3d-reference"), indent=2))
