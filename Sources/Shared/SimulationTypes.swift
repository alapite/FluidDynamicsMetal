//
//  SimulationTypes.swift
//  FluidDynamicsMetal
//
//  Created by Andrei-Sergiu Pițiș on 20/12/2017.
//  Copyright © 2017 Andrei-Sergiu Pițiș. All rights reserved.
//

import MetalKit

typealias ContactTuple = (SIMD2<Float>, SIMD2<Float>, SIMD2<Float>, SIMD2<Float>, SIMD2<Float>, SIMD2<Float>, SIMD2<Float>, SIMD2<Float>, SIMD2<Float>, SIMD2<Float>)

struct FluidContact {
    let position: SIMD2<Float>
    let impulse: SIMD2<Float>
}

struct MouseInputState {
    private var position: SIMD2<Float>?
    private var previousFramePosition: SIMD2<Float>?

    mutating func update(position: SIMD2<Float>?) {
        self.position = position
        if position == nil { previousFramePosition = nil }
    }

    mutating func clear() {
        position = nil
        previousFramePosition = nil
    }

    mutating func contactForFrame() -> FluidContact? {
        guard let position else { return nil }
        let impulse = position - (previousFramePosition ?? position)
        previousFramePosition = position
        return FluidContact(position: position, impulse: impulse)
    }
}

// GPU ABI: matches BufferData in Shaders.metal (208-byte stride, 16-byte alignment).
// RendererContactTests locks member offsets and the packed ten-contact tuples.
struct StaticData {
    var positions: ContactTuple
    var impulses: ContactTuple

    var impulseScalar: SIMD2<Float>
    var offsets: SIMD2<Float>

    var screenSize: SIMD2<Float>
    var inkRadius: simd_float1
    var tuning: simd_float4
}

struct VertexData: BitwiseCopyable {
    let position: SIMD2<Float>
    let texCoord: SIMD2<Float>
}
