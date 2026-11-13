import Foundation

/// Presentation-only choices. These values never own solver or tracer resources.
enum InspectionPlane3D: Int, CaseIterable {
    case xy = 0, xz = 1, yz = 2

    func worldPosition(s: Float, t: Float, depth: Float) -> SIMD3<Float> {
        switch self {
        case .xy: [s, t, depth]
        case .xz: [s, depth, t]
        case .yz: [depth, t, s]
        }
    }
}

struct CameraState3D: Equatable {
    private(set) var yawDegrees: Double = 25
    private(set) var elevationDegrees: Double = 18
    private(set) var zoomPercent: Double = 100

    // Suppress the synthesized memberwise initializer: all edits must validate.
    init() {}

    /// Native slider endpoints clamp; +180 must not jump to the other endpoint.
    mutating func setYawDegrees(_ value: Double) {
        guard value.isFinite else { return }
        yawDegrees = min(180, max(-180, value))
    }

    /// Canvas orbit crosses the equivalent ±180° seam continuously.
    mutating func setGestureYawDegrees(_ value: Double) {
        guard value.isFinite else { return }
        var wrapped = value.truncatingRemainder(dividingBy: 360)
        if wrapped > 180 { wrapped -= 360 }
        if wrapped < -180 { wrapped += 360 }
        yawDegrees = wrapped
    }

    mutating func setElevationDegrees(_ value: Double) {
        guard value.isFinite else { return }
        elevationDegrees = min(75, max(-75, value))
    }

    mutating func setZoomPercent(_ value: Double) {
        guard value.isFinite else { return }
        zoomPercent = min(150, max(50, value))
    }
}

struct InspectionState3D: Equatable {
    var plane: InspectionPlane3D = .xy
    private(set) var depth: Double = 0.5
    var showTracers = true
    var camera = CameraState3D()

    init() {}

    mutating func setDepth(_ value: Double) {
        guard value.isFinite else { return }
        depth = min(1, max(0, value))
    }

    mutating func resetCamera() { camera = CameraState3D() }
    mutating func centreSlice() { depth = 0.5 }
}
