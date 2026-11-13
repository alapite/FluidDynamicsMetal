import Foundation
import simd

enum Camera3DError: Error {
    case invalidViewport
    case unrepresentableFrame
}

struct CameraFrame3D {
    let worldToClip: simd_float4x4
    let right: SIMD3<Float>
    let up: SIMD3<Float>
    let forward: SIMD3<Float>
    let eye: SIMD3<Float>
    let distance: Double
    let near: Double
    let far: Double

    /// Rotation-only positive X/Y/Z axes, including depth for label ordering.
    /// XY stays Y-up; native top-left conversion belongs to the drawing caller.
    var axisProjections: [SIMD3<Float>] {
        (0..<3).map { SIMD3<Float>(right[$0], up[$0], forward[$0]) }
    }
}

enum Camera3D {
    /// Full-aspect, column-vector left-handed camera; Metal NDC depth is 0…1.
    /// Invalid viewports defer presentation, without mutating stored choices.
    static func frame(state: CameraState3D, viewportSize: CGSize) throws -> CameraFrame3D {
        let width = Double(viewportSize.width), height = Double(viewportSize.height)
        guard width.isFinite, height.isFinite, width > 0, height > 0 else {
            throw Camera3DError.invalidViewport
        }
        let aspect = width / height
        let radius = sqrt(3.0) / 2
        let halfFOV = Double.pi / 9
        let alpha = atan(tan(halfFOV) * min(1, aspect))
        let fittedDistance = 1.10 * radius / sin(alpha)
        let distance = max(radius + 0.10, fittedDistance / (state.zoomPercent / 100))
        let near = 0.05, far = distance + radius + 1
        guard aspect.isFinite, aspect > 0, distance.isFinite, far.isFinite else {
            throw Camera3DError.unrepresentableFrame
        }
        let yaw = state.yawDegrees * .pi / 180
        let elevation = state.elevationDegrees * .pi / 180
        let offset = SIMD3<Double>(sin(yaw)*cos(elevation), sin(elevation), -cos(yaw)*cos(elevation))
        let eye = SIMD3<Double>(repeating: 0.5) + distance * offset
        let forward = -offset
        let right = simd_normalize(simd_cross(SIMD3<Double>(0, 1, 0), forward))
        let up = simd_cross(forward, right)
        let view = simd_double4x4(rows: [
            SIMD4<Double>(right, -simd_dot(right, eye)),
            SIMD4<Double>(up, -simd_dot(up, eye)),
            SIMD4<Double>(forward, -simd_dot(forward, eye)),
            SIMD4<Double>(0, 0, 0, 1)
        ])
        let sy = 1 / tan(halfFOV)
        let projection = simd_double4x4(rows: [
            SIMD4<Double>(sy/aspect, 0, 0, 0),
            SIMD4<Double>(0, sy, 0, 0),
            SIMD4<Double>(0, 0, far/(far-near), -near*far/(far-near)),
            SIMD4<Double>(0, 0, 1, 0)
        ])
        let product = projection * view
        let matrix = simd_float4x4(columns: (
            SIMD4<Float>(product.columns.0), SIMD4<Float>(product.columns.1),
            SIMD4<Float>(product.columns.2), SIMD4<Float>(product.columns.3)
        ))
        let columns = [matrix.columns.0, matrix.columns.1, matrix.columns.2, matrix.columns.3]
        guard columns.allSatisfy({ v in (0..<4).allSatisfy { v[$0].isFinite } }),
              Float(distance).isFinite, (0..<3).allSatisfy({ Float(eye[$0]).isFinite }),
              Float(sy/aspect) > 0 else {
            throw Camera3DError.unrepresentableFrame
        }
        return CameraFrame3D(worldToClip: matrix, right: SIMD3<Float>(right), up: SIMD3<Float>(up),
                             forward: SIMD3<Float>(forward), eye: SIMD3<Float>(eye),
                             distance: distance, near: near, far: far)
    }
}
