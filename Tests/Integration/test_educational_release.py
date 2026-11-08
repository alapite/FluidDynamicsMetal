"""Production encoder regressions; GPU comparisons use rtol=1e-3, atol=1e-4.

Build the Mac app first. This harness loads that exact app's Metal library.
Artifacts and identified GPU timings are written beneath .build/educational-evidence.
"""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]

class EducationalReleaseTests(unittest.TestCase):
    def test_production_engine(self):
        settings = subprocess.run(['xcodebuild', '-project', str(ROOT / 'FluidDynamicsMetal.xcodeproj'),
            '-scheme', 'FluidDynamicsMetalOSX', '-configuration', 'Debug', '-destination',
            'platform=macOS,arch=arm64', 'CODE_SIGNING_ALLOWED=NO', '-showBuildSettings', '-json'],
            capture_output=True, text=True, check=True)
        target = next(x['buildSettings'] for x in json.loads(settings.stdout) if x['target'] == 'FluidDynamicsMetalOSX')
        library = Path(target['TARGET_BUILD_DIR']) / target['WRAPPER_NAME'] / 'Contents/Resources/default.metallib'
        self.assertTrue(library.is_file())
        sources = [ROOT / 'Sources/Shared' / name for name in ['MetalDevice.swift', 'RenderShader.swift',
            'Slab.swift', 'SimulationState.swift', 'SimulationTypes.swift', 'ExperimentRecipes.swift',
            'FluidSimulation.swift', 'FieldVisualization.swift', 'ParticleSystem.swift', 'Renderer.swift',
            'SimulationTypes3D.swift', 'VolumeField3D.swift', 'FluidSimulation3D.swift',
            'PressureProjection3D.swift', 'ExperimentRecipes3D.swift', 'FieldVisualization3D.swift']]
        with tempfile.TemporaryDirectory(prefix='fluid-education-') as directory:
            executable = Path(directory) / 'check'
            compile_result = subprocess.run(['xcrun', 'swiftc', '-swift-version', '6', '-parse-as-library', '-O',
                *map(str, sources), str(Path(__file__).with_suffix('.swift')), '-o', str(executable)], capture_output=True, text=True)
            self.assertEqual(compile_result.returncode, 0, compile_result.stdout + compile_result.stderr)
            result = subprocess.run([str(executable), str(library), str(ROOT / '.build/educational-evidence')],
                capture_output=True, text=True, timeout=600, env=dict(os.environ, MTL_DEBUG_LAYER='1'))
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            print(result.stdout)
            self.assertIn('PASS: educational production engine', result.stdout)

if __name__ == '__main__': unittest.main()
