import Foundation
import simd

/// Deterministic initial data for the first volumetric dye-advection lesson.
/// This recipe is applied only by reset; every later velocity is transported
/// and projected by `FluidSimulation3D` without reseeding or explicit dye loss.
enum ExperimentRecipes3D {
    static let maximumVectorSpeed: Float = 0.12
    static let blobCenter = SIMD3<Float>(0.42, 0.48, 0.52)
    static let blobRadius: Float = 0.12
    static let blobPeak: Float = 1

    /// Samples the analytic curl of the approved smooth vector potential at
    /// each MAC face, normalizes reconstructed cell-centred speed, and returns
    /// one compact off-centre cell-centred dye blob.
    static func initialState(for grid: FluidSimulation3DConfiguration) -> Fluid3DInitialState {
        let nx = grid.nx
        let ny = grid.ny
        let nz = grid.nz
        var u = Array(repeating: Float.zero, count: (nx + 1) * ny * nz)
        var v = Array(repeating: Float.zero, count: nx * (ny + 1) * nz)
        var w = Array(repeating: Float.zero, count: nx * ny * (nz + 1))
        var dye = Array(repeating: Float.zero, count: nx * ny * nz)

        func squaredSine(_ coordinate: Float) -> Float {
            let value = sin(Float.pi * coordinate)
            return value * value
        }

        func squaredSineDerivative(_ coordinate: Float) -> Float {
            Float.pi * sin(2 * Float.pi * coordinate)
        }

        // curl(A) with A=(0.7*f, f*sin^2(pi*y), 0.6*f*sin^2(pi*z)),
        // f=sin^2(pi*x)sin^2(pi*y)sin^2(pi*z).
        for k in 0..<nz {
            let z = (Float(k) + 0.5) / Float(nz)
            let sz = squaredSine(z)
            let dsz = squaredSineDerivative(z)
            for j in 0..<ny {
                let y = (Float(j) + 0.5) / Float(ny)
                let sy = squaredSine(y)
                let dsy = squaredSineDerivative(y)
                for i in 0...nx {
                    let x = Float(i) / Float(nx)
                    let sx = squaredSine(x)
                    let index = (k * ny + j) * (nx + 1) + i
                    u[index] = sx * (0.6 * dsy * sz * sz - sy * sy * dsz)
                }
            }
        }

        for k in 0..<nz {
            let z = (Float(k) + 0.5) / Float(nz)
            let sz = squaredSine(z)
            let dsz = squaredSineDerivative(z)
            for j in 0...ny {
                let y = Float(j) / Float(ny)
                let sy = squaredSine(y)
                for i in 0..<nx {
                    let x = (Float(i) + 0.5) / Float(nx)
                    let sx = squaredSine(x)
                    let dsx = squaredSineDerivative(x)
                    let index = (k * (ny + 1) + j) * nx + i
                    v[index] = 0.7 * sx * sy * dsz - 0.6 * dsx * sy * sz * sz
                }
            }
        }

        for k in 0...nz {
            let z = Float(k) / Float(nz)
            let sz = squaredSine(z)
            for j in 0..<ny {
                let y = (Float(j) + 0.5) / Float(ny)
                let sy = squaredSine(y)
                let dsy = squaredSineDerivative(y)
                for i in 0..<nx {
                    let x = (Float(i) + 0.5) / Float(nx)
                    let sx = squaredSine(x)
                    let dsx = squaredSineDerivative(x)
                    let index = (k * ny + j) * nx + i
                    w[index] = dsx * sy * sy * sz - 0.7 * sx * dsy * sz
                }
            }
        }

        // Do not rely on sin(pi) rounding to impose closed normal walls.
        for k in 0..<nz {
            for j in 0..<ny {
                u[(k * ny + j) * (nx + 1)] = 0
                u[(k * ny + j) * (nx + 1) + nx] = 0
            }
        }
        for k in 0..<nz {
            for i in 0..<nx {
                v[(k * (ny + 1)) * nx + i] = 0
                v[(k * (ny + 1) + ny) * nx + i] = 0
            }
        }
        for j in 0..<ny {
            for i in 0..<nx {
                w[j * nx + i] = 0
                w[(nz * ny + j) * nx + i] = 0
            }
        }

        // Reconstruct the staggered field at cell centres before applying the
        // one documented global speed scale.
        var maximumSpeed: Float = 0
        for k in 0..<nz {
            for j in 0..<ny {
                for i in 0..<nx {
                    let uIndex = (k * ny + j) * (nx + 1) + i
                    let vIndex = (k * (ny + 1) + j) * nx + i
                    let wIndex = (k * ny + j) * nx + i
                    let center = SIMD3<Float>(
                        0.5 * (u[uIndex] + u[uIndex + 1]),
                        0.5 * (v[vIndex] + v[vIndex + nx]),
                        0.5 * (w[wIndex] + w[wIndex + nx * ny])
                    )
                    maximumSpeed = max(maximumSpeed, simd_length(center))
                }
            }
        }
        let speedScale = maximumSpeed > 0 ? maximumVectorSpeed / maximumSpeed : 0
        for index in u.indices { u[index] *= speedScale }
        for index in v.indices { v[index] *= speedScale }
        for index in w.indices { w[index] *= speedScale }

        for k in 0..<nz {
            let z = (Float(k) + 0.5) / Float(nz)
            for j in 0..<ny {
                let y = (Float(j) + 0.5) / Float(ny)
                for i in 0..<nx {
                    let x = (Float(i) + 0.5) / Float(nx)
                    let dx = (x - blobCenter.x) / blobRadius
                    let dy = (y - blobCenter.y) / blobRadius
                    let dz = (z - blobCenter.z) / blobRadius
                    let radiusSquared = dx * dx + dy * dy + dz * dz
                    if radiusSquared < 1 {
                        dye[(k * ny + j) * nx + i] = blobPeak * exp(1 - 1 / (1 - radiusSquared))
                    }
                }
            }
        }

        return Fluid3DInitialState(u: u, v: v, w: w, dye: dye)
    }
}
