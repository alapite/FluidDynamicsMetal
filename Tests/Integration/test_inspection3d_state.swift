import Foundation
import simd

private func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() { fatalError(message) }
}

private struct StateOperationSnapshot: Equatable {
    let field: DisplayField
    let userPaused: Bool
    let inactive: Bool
    let mode: SimulationMode
    let adjustment: ExperimentAdjustment?
    let displayOptions: DisplayOptions
    let stepCount: Int
    let pendingSteps: Int
    let resetting: Bool
    let tuning: SimulationTuning

    init(_ state: SimulationState) {
        field = state.field
        userPaused = state.userPaused
        inactive = state.inactive
        mode = state.mode
        adjustment = state.adjustment
        displayOptions = state.displayOptions
        stepCount = state.stepCount
        pendingSteps = state.pendingSteps
        resetting = state.resetting
        tuning = state.tuning
    }
}

private func changedInspection(_ original: InspectionState3D) -> InspectionState3D {
    var inspection = original
    inspection.plane = .yz
    inspection.setDepth(0.27)
    inspection.camera.setYawDegrees(-73)
    inspection.camera.setElevationDegrees(41)
    inspection.camera.setZoomPercent(137)
    inspection.showTracers = false
    return inspection
}
private func close(_ actual: Double, _ expected: Double, _ message: String, tolerance: Double = 3e-5) {
    check(actual.isFinite && expected.isFinite && abs(actual-expected) <= tolerance, "\(message): \(actual) != \(expected)")
}

// Independent scalar camera evaluator: analytic Euler basis and perspective
// equations, no production matrix or production basis used as reference.
private func reference(_ p: SIMD3<Double>, yaw: Double, elevation: Double, zoom: Double, width: Double, height: Double) -> SIMD3<Double> {
    let y = yaw * .pi/180, e = elevation * .pi/180
    let r = sqrt(3.0)/2, a = width/height
    let alpha = atan(tan(.pi/9)*min(1,a))
    let distance = max(r+0.1, 1.1*r/sin(alpha)/(zoom/100))
    let x = p.x-0.5, v = p.y-0.5, z = p.z-0.5
    let vx = cos(y)*x + sin(y)*z
    let vy = -sin(y)*sin(e)*x + cos(e)*v + cos(y)*sin(e)*z
    let vz = -sin(y)*cos(e)*x - sin(e)*v + cos(y)*cos(e)*z + distance
    let far = distance+r+1, near = 0.05
    return [vx/(tan(.pi/9)*a*vz), vy/(tan(.pi/9)*vz), far/(far-near)*(1-near/vz)]
}

@main private struct InspectionChecks {
    static func main() throws {
        var state = InspectionState3D()
        check(state.plane == .xy && state.depth == 0.5 && state.showTracers, "initial inspection")
        check(state.camera == CameraState3D(), "initial camera")
        check(state.camera.yawDegrees == 25 && state.camera.elevationDegrees == 18 && state.camera.zoomPercent == 100, "camera constants")
        state.setDepth(0.3)
        state.camera.setYawDegrees(73)
        state.camera.setElevationDegrees(-42)
        state.camera.setZoomPercent(123)
        state.showTracers = false
        let camera = state.camera
        for plane in InspectionPlane3D.allCases {
            state.plane = plane
            check(state.depth == 0.3 && state.camera == camera && !state.showTracers, "plane preserves shared depth/camera")
            let p = plane.worldPosition(s: 0.23, t: 0.67, depth: Float(state.depth))
            let expected: SIMD3<Float> = plane == .xy ? [0.23,0.67,0.3] : plane == .xz ? [0.23,0.3,0.67] : [0.3,0.67,0.23]
            check(p == expected, "plane mapping")
        }
        state.centreSlice()
        check(state.depth == 0.5 && state.plane == .yz && state.camera == camera && !state.showTracers, "centre only depth")
        state.setDepth(0.31)
        state.resetCamera()
        check(state.camera == CameraState3D() && state.depth == 0.31 && state.plane == .yz && !state.showTracers, "reset only camera")
        for invalid in [Double.nan, .infinity, -.infinity] {
            let before = state
            state.setDepth(invalid)
            state.camera.setYawDegrees(invalid)
            state.camera.setGestureYawDegrees(invalid)
            state.camera.setElevationDegrees(invalid)
            state.camera.setZoomPercent(invalid)
            check(state == before, "nonfinite edit poisons state")
        }
        state.setDepth(-1); check(state.depth == 0, "depth low")
        state.setDepth(2); check(state.depth == 1, "depth high")
        state.camera.setYawDegrees(180); check(state.camera.yawDegrees == 180, "slider seam +180")
        state.camera.setYawDegrees(1000); check(state.camera.yawDegrees == 180, "slider clamp")
        state.camera.setGestureYawDegrees(181); check(state.camera.yawDegrees == -179, "gesture wraps")
        state.camera.setGestureYawDegrees(-181); check(state.camera.yawDegrees == 179, "gesture wraps negative")
        state.camera.setGestureYawDegrees(.greatestFiniteMagnitude)
        check((-180...180).contains(state.camera.yawDegrees), "finite extreme wrap")
        state.camera.setElevationDegrees(-1000); check(state.camera.elevationDegrees == -75, "elevation low")
        state.camera.setElevationDegrees(1000); check(state.camera.elevationDegrees == 75, "elevation high")
        state.camera.setZoomPercent(-1000); check(state.camera.zoomPercent == 50, "zoom low")
        state.camera.setZoomPercent(1000); check(state.camera.zoomPercent == 150, "zoom high")
        let validState = state
        let invalidSizes: [CGSize] = [CGSize(width: 0,height: 0), CGSize(width: -1,height: 2), CGSize(width: CGFloat.nan,height: 2), CGSize(width: CGFloat.infinity,height: 2), CGSize(width: 1,height: CGFloat.infinity), CGSize(width: Double.leastNonzeroMagnitude,height: Double.greatestFiniteMagnitude)]
        for size in invalidSizes {
            do { _ = try Camera3D.frame(state: state.camera, viewportSize: size); fatalError("invalid viewport accepted") }
            catch is Camera3DError { }
            check(state == validState, "viewport mutated state")
        }
        var projections = 0
        let points: [SIMD3<Double>] = [[0.17,0.28,0.39], [0.83,0.62,0.91], [0.5,0.5,0.5], [0,0,0], [1,1,1]]
        for size: CGSize in [CGSize(width: 320,height: 240), CGSize(width: 1280,height: 720), CGSize(width: 200,height: 1200), CGSize(width: 2000,height: 300)] {
            for scale in [1.0,2.0] {
                for yaw in [-180.0,-90,0,25,90,180] {
                    for elevation in [-75.0,0,18,75] {
                        for zoom in [50.0,100,150] {
                            var c = CameraState3D()
                            c.setYawDegrees(yaw); c.setElevationDegrees(elevation); c.setZoomPercent(zoom)
                            let frame = try Camera3D.frame(state: c, viewportSize: CGSize(width: size.width*scale,height: size.height*scale))
                            close(Double(simd_length(frame.right)),1,"right unit")
                            close(Double(simd_dot(frame.right,frame.up)),0,"orthogonal")
                            check(frame.up.y > 0 && frame.distance > sqrt(3)/2+0.05, "upright outside volume")
                            for p in points {
                                let clip = frame.worldToClip * SIMD4<Float>(SIMD3<Float>(p),1)
                                let expected = reference(p,yaw: yaw,elevation: elevation,zoom: zoom,width: size.width,height: size.height)
                                for a in 0..<3 { close(Double(clip[a]/clip.w),expected[a],"independent projected landmark") }
                                projections += 1
                            }
                            if zoom == 100 {
                                for x in [Float(0),1] { for y in [Float(0),1] { for z in [Float(0),1] {
                                    let clip = frame.worldToClip * SIMD4<Float>(x,y,z,1)
                                    check(clip.w > 0 && abs(clip.x/clip.w) <= 1 && abs(clip.y/clip.w) <= 1 && (0...1).contains(clip.z/clip.w), "100% cube corner fit / Metal depth")
                                } } }
                            }
                            let guide = frame.axisProjections
                            let y = yaw * .pi/180, e = elevation * .pi/180
                            let expectedAxes: [SIMD3<Double>] = [[cos(y),-sin(y)*sin(e),-sin(y)*cos(e)], [0,cos(e),-sin(e)], [sin(y),cos(y)*sin(e),cos(y)*cos(e)]]
                            for a in 0..<3 { for lane in 0..<3 { close(Double(guide[a][lane]),expectedAxes[a][lane],"guide rotation only") } }
                            // Near/far endpoints in view space, independent of world origin.
                            for (distance,expected) in [(frame.near,0.0),(frame.far,1.0)] {
                                let world = frame.eye + frame.forward * Float(distance)
                                let clip = frame.worldToClip * SIMD4<Float>(world,1)
                                // Float world-point construction and matrix cancellation
                                // at near=0.05 amplify rounding by distance/near.
                                let roundingBound = 32 * Double(Float.ulpOfOne) * frame.far / frame.near
                                close(Double(clip.z/clip.w),expected,"Metal depth endpoint",tolerance: roundingBound)
                            }
                        }
                    }
                }
            }
        }
        print("PASS production inspection: \(projections) independent projections; bounds, reset/centre, fit, depth, guide, invalid values")
        try testStateOperationScopes()
    }

    private static func threeDState() -> SimulationState {
        var state = SimulationState()
        state.selectMode(.dyeAdvection3D)
        state.finishReset()
        return state
    }

    private static func testStateOperationScopes() throws {
        var paused = threeDState()
        check(paused.inspection3D == InspectionState3D(), "initial 3D entry defaults")
        paused.tuning.force = 1.7
        paused.selectField(.pressure)
        paused.setDisplayOptions(DisplayOptions(arrows: true, particles: false, trails: true))
        check(paused.requestSingleStep() && paused.requestSingleStep(), "paused pending-step setup")
        let pausedBefore = StateOperationSnapshot(paused)
        let pausedInspection = changedInspection(paused.inspection3D)
        paused.setInspection3D(pausedInspection)
        check(paused.inspection3D == pausedInspection, "paused inspection edit was rejected")
        check(StateOperationSnapshot(paused) == pausedBefore, "paused inspection edit changed experiment state")
        check(paused.pendingSteps == 2 && paused.userPaused, "paused inspection edit consumed accepted work")

        var running = threeDState()
        running.togglePause()
        let runningBefore = StateOperationSnapshot(running)
        running.setInspection3D(changedInspection(running.inspection3D))
        check(StateOperationSnapshot(running) == runningBefore && running.shouldAdvance, "running intent changed during inspection edit")

        var inactive = threeDState()
        inactive.togglePause()
        inactive.resignActive()
        let inactiveBefore = StateOperationSnapshot(inactive)
        inactive.setInspection3D(changedInspection(inactive.inspection3D))
        check(StateOperationSnapshot(inactive) == inactiveBefore && inactive.inactive, "inactive state changed during inspection edit")

        var resetting = threeDState()
        resetting.beginReset()
        let resettingBefore = StateOperationSnapshot(resetting)
        resetting.setInspection3D(changedInspection(resetting.inspection3D))
        check(StateOperationSnapshot(resetting) == resettingBefore && resetting.resetting, "resetting state changed during inspection edit")

        var completed = threeDState()
        for _ in 0..<SimulationState.lessonSteps {
            check(completed.requestSingleStep() && completed.consumeStep(), "completion-cap setup")
        }
        check(completed.complete && completed.stepCount == SimulationState.lessonSteps, "completion cap setup")
        let completedBefore = StateOperationSnapshot(completed)
        let completedInspection = changedInspection(completed.inspection3D)
        completed.setInspection3D(completedInspection)
        check(completed.inspection3D == completedInspection, "inspection unavailable at inherited completion cap")
        check(StateOperationSnapshot(completed) == completedBefore, "completion-cap inspection changed experiment state")

        var twoD = SimulationState()
        twoD.selectMode(.experiment(.advection))
        twoD.finishReset()
        check(twoD.setExperimentAdjustment(.speed(.fast)), "2D adjustment setup")
        twoD.finishReset()
        twoD.requestSingleStep()
        let twoDBefore = StateOperationSnapshot(twoD)
        let twoDInspectionBefore = twoD.inspection3D
        twoD.setInspection3D(changedInspection(twoD.inspection3D))
        check(twoD.inspection3D == twoDInspectionBefore, "2D inspection mutation was accepted")
        check(StateOperationSnapshot(twoD) == twoDBefore, "guarded 2D inspection mutation changed state")

        var retained = threeDState()
        let retainedInspection = changedInspection(retained.inspection3D)
        retained.setInspection3D(retainedInspection)
        retained.beginReset()
        retained.finishReset()
        check(retained.inspection3D == retainedInspection, "restart reset inspection choices")

        retained.selectMode(.dyeAdvection3D)
        retained.finishReset()
        check(retained.inspection3D == InspectionState3D(), "3D reselection did not restore inspection defaults")

        let reselectedInspection = changedInspection(retained.inspection3D)
        retained.setInspection3D(reselectedInspection)
        retained.selectMode(.freePlay)
        retained.finishReset()
        retained.selectMode(.dyeAdvection3D)
        retained.finishReset()
        check(retained.inspection3D == InspectionState3D(), "3D re-entry did not restore inspection defaults")
        print("PASS SimulationState operation scopes: paused, running, inactive, resetting, completion cap, 2D guard, restart retention, and 3D re-entry defaults")
    }
}
