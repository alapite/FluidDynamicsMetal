import Foundation
import Metal
import MetalKit
import AppKit
import simd

@main @MainActor struct EducationalChecks {
    static func require(_ condition: @autoclosure () -> Bool, _ message: String) {
        if !condition() { fatalError(message) }
    }
    static func close(_ a: [Float], _ b: [Float], _ message: String, absolute: Float = 1e-4, relative: Float = 1e-3) {
        require(a.count == b.count, "Count: \(message)")
        for i in a.indices { require(a[i].isFinite && b[i].isFinite && abs(a[i] - b[i]) <= absolute + relative * abs(b[i]), "\(message) at \(i): \(a[i]) vs \(b[i])") }
    }
    static func main() throws {
        let device = MTLCreateSystemDefaultDevice()!
        let metal = MetalDevice(device: device, library: try device.makeLibrary(URL: URL(fileURLWithPath: CommandLine.arguments[1])))
        let output = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let visualization = FieldVisualization(metal: metal)
        var report = ["Hardware: \(device.name)", "OS: \(ProcessInfo.processInfo.operatingSystemVersionString)", "GPU comparisons: absolute 1e-4 + relative 1e-3; RG16F fields, float32 particles."]
        func command(_ body: (MTLCommandBuffer) -> Void) -> Double {
            let cmd = metal.newCommandBuffer(); body(cmd); cmd.commit(); cmd.waitUntilCompleted()
            require(cmd.status == .completed, "GPU failure: \(String(describing: cmd.error))")
            return (cmd.gpuEndTime - cmd.gpuStartTime) * 1000
        }
        func texture(_ texture: MTLTexture) -> [Float] {
            let buffer = device.makeBuffer(length: texture.width * texture.height * 4, options: .storageModeShared)!
            _ = command { cmd in
                let blit = cmd.makeBlitCommandEncoder()!
                blit.copy(from: texture, sourceSlice: 0, sourceLevel: 0, sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0), sourceSize: MTLSize(width: texture.width, height: texture.height, depth: 1), to: buffer, destinationOffset: 0, destinationBytesPerRow: texture.width * 4, destinationBytesPerImage: buffer.length); blit.endEncoding()
            }
            let ptr = buffer.contents().bindMemory(to: Float16.self, capacity: buffer.length / 2)
            return (0..<buffer.length / 2).map { Float(ptr[$0]) }
        }
        func buffer(_ source: MTLBuffer) -> [Float] {
            let copy = device.makeBuffer(length: source.length, options: .storageModeShared)!
            _ = command { cmd in let blit = cmd.makeBlitCommandEncoder()!; blit.copy(from: source, sourceOffset: 0, to: copy, destinationOffset: 0, size: source.length); blit.endEncoding() }
            let ptr = copy.contents().bindMemory(to: Float.self, capacity: copy.length / 4)
            return Array(UnsafeBufferPointer(start: ptr, count: copy.length / 4))
        }
        func fill(_ texture: MTLTexture, _ value: (Int, Int) -> SIMD2<Float>) {
            var halves = [Float16](); halves.reserveCapacity(texture.width * texture.height * 2)
            for y in 0..<texture.height { for x in 0..<texture.width { let v = value(x, y); halves.append(Float16(v.x)); halves.append(Float16(v.y)) } }
            let seed = device.makeBuffer(bytes: halves, length: halves.count * 2, options: .storageModeShared)!
            _ = command { cmd in let blit = cmd.makeBlitCommandEncoder()!; blit.copy(from: seed, sourceOffset: 0, sourceBytesPerRow: texture.width * 4, sourceBytesPerImage: seed.length, sourceSize: MTLSize(width: texture.width, height: texture.height, depth: 1), to: texture, destinationSlice: 0, destinationLevel: 0, destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0)); blit.endEncoding() }
        }
        func imageTexture(_ width: Int = 256, _ height: Int = 256) -> MTLTexture {
            let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false)
            d.usage = [.renderTarget, .shaderRead]; return device.makeTexture(descriptor: d)!
        }
        func viewport(_ target: MTLTexture) -> MTLViewport { MTLViewport(originX: 0, originY: 0, width: Double(target.width), height: Double(target.height), znear: 0, zfar: 1) }
        func imageBytes(_ target: MTLTexture) -> [UInt8] {
            var data = [UInt8](repeating: 0, count: target.width * target.height * 4)
            target.getBytes(&data, bytesPerRow: target.width * 4, from: MTLRegionMake2D(0, 0, target.width, target.height), mipmapLevel: 0)
            return data
        }
        func save(_ target: MTLTexture, _ name: String) throws {
            let data = imageBytes(target)
            let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: target.width, pixelsHigh: target.height, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: target.width * 4, bitsPerPixel: 32)!
            let bytes = bitmap.bitmapData!
            for i in stride(from: 0, to: data.count, by: 4) { bytes[i] = data[i + 2]; bytes[i + 1] = data[i + 1]; bytes[i + 2] = data[i]; bytes[i + 3] = 255 }
            try bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent(name + ".png"))
        }
        func snapshot(_ simulation: FluidSimulation) -> [Float] { simulation.allTextures.flatMap { texture($0) } + buffer(simulation.particles.positions) + buffer(simulation.particles.history) }
        func reset(_ simulation: FluidSimulation, _ lesson: ExperimentID?, _ adjustment: ExperimentAdjustment? = nil) {
            _ = command { simulation.encodeReset(command: $0, mode: lesson.map { .experiment($0) } ?? .freePlay, adjustment: adjustment ?? lesson?.defaultAdjustment) }
        }
        func draw(_ simulation: FluidSimulation, _ target: MTLTexture, _ field: DisplayField, overlays: Bool = false) -> Double {
            command { cmd in
                visualization.encodeField(command: cmd, simulation: simulation, destination: target, viewport: viewport(target), field: field)
                if overlays {
                    simulation.particles.encodeDisplay(command: cmd, destination: target, viewport: viewport(target), pointSize: [256,256], trails: true)
                    visualization.encodeArrows(command: cmd, simulation: simulation, destination: target, viewport: viewport(target), pointSize: [256,256])
                }
            }
        }
        // Exercise the actual view-facing scheduler with no window or drawable.
        let hiddenView = MTKView(frame: .zero, device: device)
        let renderer = Renderer(metalView: hiddenView, metal: metal)
        renderer.selectMode(.experiment(.advection))
        require(hiddenView.currentDrawable == nil, "Headless scheduler fixture must have no drawable")
        for _ in 0..<17 { renderer.requestSingleStep() }
        for _ in 0..<17 { renderer.draw(in: hiddenView) }
        require(renderer.state.stepCount == 17 && renderer.state.userPaused, "Renderer drains exactly 17 queued steps without a drawable")
        renderer.draw(in: hiddenView); require(renderer.state.stepCount == 17, "Paused redraw cannot advance")
        renderer.requestSingleStep(); renderer.resignActive(); renderer.becomeActive(); renderer.draw(in: hiddenView)
        require(renderer.state.stepCount == 17 && renderer.state.pendingSteps == 0, "Inactivity cancels queued renderer steps")
        let originalSimulation = renderer.simulation!
        hiddenView.frame = CGRect(x: 0, y: 0, width: 640, height: 480)
        renderer.mtkView(hiddenView, drawableSizeWillChange: CGSize(width: 1280, height: 960))
        require(renderer.simulation === originalSimulation && renderer.state.stepCount == 17, "Lesson resize must keep the same GPU resources and step")
        renderer.requestSingleStep(); renderer.restartCurrentSimulation()
        require(renderer.state.stepCount == 0 && renderer.state.pendingSteps == 0, "Renderer restart cancels queued steps")
        let emptyView = MTKView(frame: .zero, device: device)
        let freeRenderer = Renderer(metalView: emptyView, metal: metal)
        freeRenderer.enqueueTap(at: [0,0], in: emptyView)
        freeRenderer.restartCurrentSimulation(); freeRenderer.draw(in: emptyView)
        require(texture(freeRenderer.simulation.density.ping).allSatisfy { $0 == 0 }, "Reset cancels pending taps")
        report.append("PASS real renderer: no-drawable stepping, rapid queue, paused redraw, inactivity, resize resource identity, pending-input reset")
        let sim = FluidSimulation(width: 256, height: 256, metal: metal)
        let target = imageTexture()
        reset(sim, nil)
        let pristine = snapshot(sim)
        for field in sim.allTextures { fill(field) { _,_ in [17, -9] } }
        _ = command { cmd in let blit = cmd.makeBlitCommandEncoder()!; for b in [sim.particles.positions, sim.particles.history] { blit.fill(buffer: b, range: 0..<b.length, value: 255) }; blit.endEncoding() }
        reset(sim, nil); require(snapshot(sim) == pristine, "Complete reset must exactly reproduce deterministic seeds")
        let seeds = buffer(sim.particles.positions)
        _ = command { sim.encodeStep(command: $0, tuning: .lesson, step: 0) }
        close(buffer(sim.particles.positions), seeds, "Stationary zero-field tracers")
        for field in DisplayField.allCases {
            _ = draw(sim, target, field)
            let bytes = imageBytes(target)
            let expected: [UInt8] = field == .density ? [0,0,0,255] : field == .velocity ? [46,5,23,255] : [224,224,224,255]
            for channel in 0..<4 { require(abs(Int(bytes[channel]) - Int(expected[channel])) <= 1, "Neutral zero display \(field)") }
            close(buffer(visualization.statistics), [0, 1e-5, 1e-5, 1e-5], "Finite zero statistics", absolute: 1e-7)
        }
        _ = draw(sim, target, .density); let zeroImage = imageBytes(target)
        _ = command { visualization.encodeArrows(command: $0, simulation: sim, destination: target, viewport: viewport(target), pointSize: [256,256]) }
        require(zeroImage == imageBytes(target), "Zero velocity must suppress arrows")
        report.append("PASS complete reset, zero fields, stationary tracers, suppressed zero arrows")
        // Controlled uniform field tests particle grid conversion and chronological history after wrap.
        fill(sim.velocity.ping) { _,_ in [1, 0.5] }
        for _ in 0..<70 { _ = command { sim.particles.encodeAdvance(command: $0, velocity: sim.velocity.ping) } }
        let moved = buffer(sim.particles.positions), history = buffer(sim.particles.history)
        close(Array(moved[0..<2]), [0.1 + 70 / 256, 0.1 + 35 / 256], "Uniform velocity displacement")
        require(sim.particles.sampleCount == 64 && sim.particles.head == 7, "Ring indices")
        for sample in 0..<64 {
            let slot = (Int(sim.particles.head) + 1 + sample) % 64
            close(Array(history[(slot * 2)..<(slot * 2 + 2)]), [0.1 + Float(sample + 7) / 256, 0.1 + Float(sample + 7) / 512], "History chronological")
        }
        _ = draw(sim, target, .velocity, overlays: true); try save(target, "uniform-arrows-particles")
        // Reset clears history and cannot leave any trail segment.
        reset(sim, nil); _ = draw(sim, target, .density)
        let base = imageBytes(target)
        _ = command { sim.particles.encodeDisplay(command: $0, destination: target, viewport: viewport(target), pointSize: [256,256], trails: true) }
        let over = imageBytes(target)
        require(Array(base[0..<4]) == Array(over[0..<4]), "Overlay must preserve untouched base pixels")
        require(base != over, "Markers must composite")
        report.append("PASS uniform particle displacement, ring wrap ordering, reset history, overlay compositing")
        // Independent advection channels, with transport disabled by a zero advecting field.
        reset(sim, nil); fill(sim.density.ping) { _,_ in [1, 0.5] }
        var tuning = SimulationTuning.lesson; tuning.dyeRetention = 0.9905
        _ = command { sim.pass("advectVelocity", command: $0, data: sim.uniform(tuning: tuning), sources: [sim.velocity.ping, sim.density.ping], destination: sim.velocity.pong) }
        close(texture(sim.velocity.pong), texture(sim.density.ping), "Dye fading preserves velocity")
        tuning.dyeRetention = 1; tuning.velocityRetention = 0.9905
        _ = command { sim.pass("advect", command: $0, data: sim.uniform(tuning: tuning), sources: [sim.velocity.ping, sim.density.ping], destination: sim.density.pong) }
        close(texture(sim.density.pong), texture(sim.density.ping), "Velocity damping preserves dye")
        // Synthetic clockwise/anticlockwise rotation, with downward-positive y.
        for sign: Float in [1, -1] {
            fill(sim.velocity.ping) { x,y in SIMD2<Float>(-Float(y - 128), Float(x - 128)) * sign / 128 }
            _ = command { sim.encodeFinalCurl(command: $0, data: sim.uniform(tuning: .lesson)) }
            let curl = texture(sim.finalCurl.ping)
            require(curl[(128 * 256 + 128) * 2] * sign > 0, "Curl orientation")
            _ = draw(sim, target, .vorticity)
            let pixels = imageBytes(target), index = (128 * 256 + 128) * 4
            require(sign > 0 ? pixels[index + 2] > pixels[index] : pixels[index] > pixels[index + 2], "Labelled curl colour")
            try save(target, sign > 0 ? "clockwise-orange" : "anticlockwise-blue")
        }
        fill(sim.pressure.ping) { x,_ in [Float(x % 16) / 16, 0] }
        _ = draw(sim, target, .pressure); let pressureImage = imageBytes(target)
        fill(sim.pressure.ping) { x,_ in [Float(x % 16) / 16 + 4, 0] }
        _ = draw(sim, target, .pressure)
        require(pressureImage == imageBytes(target), "Pressure offset invariance")
        report.append("PASS retention isolation, rotating-field signs/colours, pressure offset invariance")
        let resized = FluidSimulation(width: 128, height: 96, metal: metal)
        let positionsBeforeResize = buffer(sim.particles.positions)
        _ = command { resized.encodeResample(from: sim, command: $0) }
        require(resized.particles === sim.particles, "Free Play resize retains normalized particle/history resources")
        require(buffer(resized.particles.positions) == positionsBeforeResize, "Free Play resize cannot advance particles")
        let resizedVelocity = texture(resized.velocity.ping), resizedCurl = texture(resized.finalCurl.ping)
        for y in 1..<95 { for x in 1..<127 {
            let expected = 0.5 * (resizedVelocity[(y * 128 + x + 1) * 2 + 1] - resizedVelocity[(y * 128 + x - 1) * 2 + 1]
                - resizedVelocity[((y + 1) * 128 + x) * 2] + resizedVelocity[((y - 1) * 128 + x) * 2])
            close([resizedCurl[(y * 128 + x) * 2]], [expected], "Paused Free Play resize displays current curl")
        } }
        report.append("PASS Free Play resize preserves normalized particles and recomputes display curl")
        var lessonMeasurements: [String: [Float]] = [:]
        func centroid(_ data: [Float]) -> SIMD2<Float> {
            var sum: Float = 0; var center = SIMD2<Float>.zero
            for y in 0..<256 { for x in 0..<256 { let c = data[(y * 256 + x) * 2]; sum += c; center += SIMD2<Float>(Float(x) + 0.5, Float(y) + 0.5) * c } }
            return center / max(sum, 1e-5) / 256
        }
        for lesson in ExperimentID.allCases {
            for adjustment in lesson.choices {
                reset(sim, lesson, adjustment)
                let start = centroid(texture(sim.density.ping))
                var state = SimulationState(); state.selectMode(.experiment(lesson)); state.finishReset()
                var at120: [Float] = []; var at120Dye: [Float] = []
                var timesOff = [Double](), timesOn = [Double]()
                var framesOff = [Double](), framesOn = [Double]()
                for step in 0...600 {
                    if [0,120,240,600].contains(step) {
                        _ = draw(sim, target, lesson.defaultField, overlays: true)
                        try save(target, "lesson-\(lesson.rawValue)-\(lesson.choices.firstIndex(of: adjustment)!)-step-\(step)")
                        _ = draw(sim, target, lesson.defaultField)
                        try save(target, "field-\(lesson.rawValue)-\(lesson.choices.firstIndex(of: adjustment)!)-step-\(step)")
                    }
                    if step == 120 { at120 = snapshot(sim); at120Dye = texture(sim.density.ping) }
                    if step == 600 { break }
                    require(state.requestSingleStep() && state.consumeStep(), "Manual scheduling")
                    let frameStart = ProcessInfo.processInfo.systemUptime
                    let duration = command { cmd in
                        sim.encodeStep(command: cmd, tuning: .lesson, mode: .experiment(lesson), adjustment: adjustment, step: step)
                        visualization.encodeField(command: cmd, simulation: sim, destination: target, viewport: viewport(target), field: lesson.defaultField)
                        if step % 2 == 1 {
                            sim.particles.encodeDisplay(command: cmd, destination: target, viewport: viewport(target), pointSize: [256,256], trails: true)
                            visualization.encodeArrows(command: cmd, simulation: sim, destination: target, viewport: viewport(target), pointSize: [256,256])
                        }
                    }
                    let frameDuration = (ProcessInfo.processInfo.systemUptime - frameStart) * 1000
                    if step > 20 {
                        if step % 2 == 0 { timesOff.append(duration); framesOff.append(frameDuration) }
                        else { timesOn.append(duration); framesOn.append(frameDuration) }
                    }
                }
                require(state.complete && state.userPaused, "Completion scheduling")
                require(snapshot(sim).allSatisfy(\.isFinite), "Finite lesson fields, particles and history")
                let v = texture(sim.velocity.ping), c = texture(sim.finalCurl.ping)
                for y in 1..<255 { for x in 1..<255 {
                    let expected = 0.5 * (v[(y * 256 + x + 1) * 2 + 1] - v[(y * 256 + x - 1) * 2 + 1] - v[((y + 1) * 256 + x) * 2] + v[((y - 1) * 256 + x) * 2])
                    close([c[(y * 256 + x) * 2]], [expected], "Final projected curl")
                } }
                let key = "\(lesson.rawValue)-\(lesson.choices.firstIndex(of: adjustment)!)"
                lessonMeasurements[key] = [simd_length(centroid(at120Dye) - start)]
                if lesson == .dyeStretching {
                    // Length of each vertical material line on the particle lattice.
                    let points = buffer(sim.particles.positions)
                    var length: Float = 0
                    for y in 0..<15 { for x in 0..<16 { let a = (y * 16 + x) * 2, b = ((y + 1) * 16 + x) * 2; length += simd_length(SIMD2<Float>(points[b] - points[a], points[b + 1] - points[a + 1])) } }
                    lessonMeasurements[key]!.append(length)
                }
                // Running scheduling reproduces 120 manual steps, with all displays hidden.
                reset(sim, lesson, adjustment)
                state.beginReset(); state.finishReset(); state.togglePause()
                for step in 0..<120 { require(state.consumeStep(), "Running scheduling"); _ = command { sim.encodeStep(command: $0, tuning: .lesson, mode: .experiment(lesson), adjustment: adjustment, step: step) } }
                close(snapshot(sim), at120, "Restart, scheduling and display isolation \(key)")
                // Present in differently sized viewports without touching simulation state.
                _ = draw(sim, imageTexture(512, 320), .pressure, overlays: true)
                _ = draw(sim, imageTexture(320, 512), .velocity, overlays: true)
                close(snapshot(sim), at120, "Viewport isolation")
                let off = timesOff.reduce(0,+) / Double(timesOff.count), on = timesOn.reduce(0,+) / Double(timesOn.count)
                report.append("Lesson \(key) GPU ms mean: overlays off \(off), all on \(on); measurements \(lessonMeasurements[key]!)")
                report.append("  Offscreen encode/submit/completion ms mean: overlays off \(framesOff.reduce(0,+) / Double(framesOff.count)), all on \(framesOn.reduce(0,+) / Double(framesOn.count))")
                require(on < 1000 / 30, "Sustained GPU cost below 30fps needs investigation")
            }
        }
        require(lessonMeasurements["0-2"]![0] > lessonMeasurements["0-0"]![0], "Faster advection must move farther at step 120")
        require(abs(lessonMeasurements["1-0"]![0] - lessonMeasurements["1-1"]![0]) > 0.005, "Reversing vortex must change dye-region movement")
        require(lessonMeasurements["2-2"]![1] > lessonMeasurements["2-0"]![1] * 1.02, "Strong stirring must stretch material lines more than gentle")
        report.append("PASS reproducibility, manual/running equivalence, display/viewport isolation, final curl, lesson observations")
        report.append("PASS: educational production engine")
        let text = report.joined(separator: "\n") + "\n"
        try text.write(to: output.appendingPathComponent("results.txt"), atomically: true, encoding: .utf8)
        print(text)
    }
}
