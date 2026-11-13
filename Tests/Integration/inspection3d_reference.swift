// Independent Double oracle: no production sources and no Metal imports.
import Foundation
import CryptoKit

private let contractHash = "7f793d4ecfff13e7138a96e354f7597a9da9db88853c657d47a23ae09955e0c7"
private enum OracleError: Error { case invalid(String) }
private func hash(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}
private func clamp(_ p: [Double]) -> [Double] { p.map { min(1, max(0, $0)) } }
private func affine(_ p: [Double]) -> Double { 0.1 + 0.2*p[0] + 0.3*p[1] + 0.4*p[2] }
private func landmark(_ p: [Double]) -> Double { 7*p[0] + 19*p[1] + 43*p[2] }

// General tensor interpolation, independently implemented for scalar/face grids.
private func interpolate(_ p: [Double], n: Int, normal: Int?, value: ([Double]) -> Double) -> Double {
    var folded = p
    var parity = [1.0, 1.0, 1.0]
    for a in 0..<3 {
        var q = p[a].truncatingRemainder(dividingBy: 2)
        if q < 0 { q += 2 }
        folded[a] = q <= 1 ? q : 2-q
        parity[a] = q <= 1 ? 1 : -1
    }
    let offset = (0..<3).map { $0 == normal ? 0.0 : 0.5 }
    let q = (0..<3).map { folded[$0]*Double(n)-offset[$0] }
    let base = q.map { Int(floor($0)) }
    let f = (0..<3).map { q[$0]-Double(base[$0]) }
    var sum = 0.0
    for mask in 0..<8 {
        var point = [Double](repeating: 0, count: 3)
        var weight = 1.0
        var wall = false
        for a in 0..<3 {
            let upper = (mask >> a) & 1
            var i = base[a]+upper
            weight *= upper == 0 ? 1-f[a] : f[a]
            if a == normal {
                i = min(n, max(0, i))
                wall = wall || i == 0 || i == n
            } else {
                // Even tangential ghost centres (queries already folded).
                if i < 0 { i = -i-1 }
                if i >= n { i = 2*n-1-i }
            }
            point[a] = (Double(i)+offset[a])/Double(n)
        }
        sum += weight * (wall ? 0 : value(point))
    }
    return sum * (normal.map { parity[$0] } ?? 1)
}
private func scalar(_ p: [Double], value: ([Double]) -> Double) -> Double {
    // Clamp endpoints before interpolation, unlike velocity reflection.
    let bounded = p.map { min(63.5/64, max(0.5/64, $0)) }
    return interpolate(bounded, n: 64, normal: nil, value: value)
}
private func velocity(_ p: [Double], _ v: [Double], affineMAC: Bool = false) -> [Double] {
    (0..<3).map { a in
        interpolate(p, n: 64, normal: a) { x in
            affineMAC ? Double(a+1)*0.01 + 0.02*x[0]-0.03*x[1]+0.04*x[2] : v[a]
        }
    }
}
private func advance(_ p: [Double], _ v: [Double], affineMAC: Bool = false) -> [Double] {
    let first = velocity(p, v, affineMAC: affineMAC)
    let midpoint = clamp((0..<3).map { p[$0]+first[$0]/120 })
    let second = velocity(midpoint, v, affineMAC: affineMAC)
    return clamp((0..<3).map { p[$0]+second[$0]/60 })
}

@main private struct InspectionReference {
    static func main() throws {
        let args = CommandLine.arguments
        guard args.count >= 3 else { throw OracleError.invalid("contract/output arguments required") }
        let data = try Data(contentsOf: URL(fileURLWithPath: args[1]))
        guard hash(data) == contractHash else { throw OracleError.invalid("contract hash mismatch") }
        let directory = URL(fileURLWithPath: args[2], isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var seeds: [Double] = []
        for k in 0..<8 { for j in 0..<8 { for i in 0..<8 {
            seeds += [(Double(i)+0.5)/8, (Double(j)+0.5)/8, (Double(k)+0.5)/8, 1]
        } } }
        if args.contains("--nonfinite") { seeds[0] = .nan }
        guard seeds.allSatisfy(\.isFinite) else { throw OracleError.invalid("nonfinite fixture") }
        var binary = Data()
        for v in seeds {
            var word = v.bitPattern.littleEndian
            withUnsafeBytes(of: &word) { binary.append(contentsOf: $0) }
        }
        var slices: [[String: Any]] = []
        var midpointError = 0.0
        for plane in ["xy", "xz", "yz"] {
            for d in [0.0, 0.3, 0.5, 1.0] {
                let p = plane == "xy" ? [0.23,0.67,d] : plane == "xz" ? [0.23,d,0.67] : [d,0.67,0.23]
                slices.append(["plane": plane, "depth": d, "world": p,
                               "value": scalar(p, value: affine), "landmark": scalar(p, value: landmark)])
            }
            let axis = plane == "xy" ? 2 : plane == "xz" ? 1 : 0
            var p = [0.23,0.67,0.23]; p[axis] = 0.5
            var lo = p; lo[axis] = 31.5/64
            var hi = p; hi[axis] = 32.5/64
            midpointError = max(midpointError, abs(scalar(p, value: landmark) - (scalar(lo, value: landmark)+scalar(hi, value: landmark))/2))
        }
        let cases: [(String, [Double])] = [
            ("positive_x",[0.12,0,0]), ("negative_x",[-0.12,0,0]),
            ("positive_y",[0,0.12,0]), ("negative_y",[0,-0.12,0]),
            ("positive_z",[0,0,0.12]), ("negative_z",[0,0,-0.12]),
            ("combined_xyz",[0.13,-0.07,0.19]), ("combined_mixed",[-0.09,0.16,-0.05]),
            ("wall_edge_corner",[0.9,-0.7,0.8])]
        var trajectories: [[String: Any]] = []
        for (name,v) in cases {
            var p = name == "wall_edge_corner" ? [0.999,0.001,1.0] : [0.5,0.5,0.5]
            var points = [p]
            for _ in 0..<48 { p = advance(p,v); points.append(p) }
            trajectories.append(["name": name, "velocity": v, "positions": points])
        }
        var reflectionError = 0.0
        var wallTrajectories: [[String: Any]] = []
        for x in [0.001,0.5,0.999] { for y in [0.001,0.5,0.999] { for z in [0.001,0.5,0.999] {
            if x == 0.5 && y == 0.5 && z == 0.5 { continue }
            var point = [x,y,z]
            let v = [0.9,-0.7,0.8]
            var positions = [point]
            for _ in 0..<48 { point = advance(point,v); positions.append(point) }
            wallTrajectories.append(["velocity": v, "positions": positions])
        } } }
        var affinePoint = [0.31,0.42,0.57]
        var affineTrajectory: [[Double]] = []
        for _ in 0..<48 {
            affinePoint = advance(affinePoint,[0,0,0],affineMAC: true)
            affineTrajectory.append(affinePoint)
        }
        var reflectionCases = 0
        for x in [-0.031,0.37,1.031] { for y in [-0.031,0.37,1.031] { for z in [-0.031,0.37,1.031] {
            let p = [x,y,z]
            if p.allSatisfy({ $0 == 0.37 }) { continue }
            let folded = p.map { $0 < 0 ? -$0 : $0 > 1 ? 2-$0 : $0 }
            let a = velocity(p,[0.13,-0.07,0.19])
            let b = velocity(folded,[0.13,-0.07,0.19])
            for axis in 0..<3 {
                let sign = p[axis] < 0 || p[axis] > 1 ? -1.0 : 1.0
                reflectionError = max(reflectionError,abs(a[axis]-sign*b[axis]))
            }
            reflectionCases += 1
        } } }
        let p = [0.31,0.42,0.57]
        let mac = velocity(p,[0,0,0],affineMAC: true)
        let affineError = (0..<3).map { abs(mac[$0] - (Double($0+1)*0.01+0.02*p[0]-0.03*p[1]+0.04*p[2])) }.max()!
        let manifest: [String: Any] = [
            "schemaVersion": 1, "contractHash": contractHash, "byteCount": binary.count,
            "sha256": hash(binary), "slices": slices, "midpointPlanes": [31,32],
            "midpointError": midpointError, "trajectories": trajectories,
            "reflectionCases": reflectionCases, "reflectionError": reflectionError,
            "affineMACError": affineError, "wallTrajectories": wallTrajectories,
            "affineTrajectory": affineTrajectory]
        try binary.write(to: directory.appendingPathComponent("expectations.f64le"), options: .atomic)
        try JSONSerialization.data(withJSONObject: manifest, options: [.sortedKeys, .prettyPrinted])
            .write(to: directory.appendingPathComponent("manifest.json"), options: .atomic)
        print("Independent Double inspection fixtures exported")
    }
}
