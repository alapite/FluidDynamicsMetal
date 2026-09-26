//
//  RenderShader.swift
//  FluidDynamicsMetal
//
//  Created by Andrei-Sergiu Pițiș on 15/08/2017.
//  Copyright © 2017 Andrei-Sergiu Pițiș. All rights reserved.
//

import Foundation
import CoreMedia
import Metal

struct PipelineStateConfiguration {
    let pixelFormat: MTLPixelFormat
    let vertexShader: String
    let fragmentShader: String
    let computeShader: String
}

@MainActor
class RenderShader {
    private let pipelineState: PipelineStateConfiguration
    private let renderPipelineState: MTLRenderPipelineState

    init(fragmentShader: String, vertexShader: String, pixelFormat: MTLPixelFormat = .bgra8Unorm,
         metalDevice: MetalDevice = .sharedInstance) {
        pipelineState = PipelineStateConfiguration(pixelFormat: pixelFormat, vertexShader: vertexShader,
                                                   fragmentShader: fragmentShader, computeShader: "")
        do {
            renderPipelineState = try metalDevice.createRenderPipeline(vertexFunctionName: vertexShader,
                                                                        fragmentFunctionName: fragmentShader,
                                                                        pixelFormat: pixelFormat)
        } catch {
            fatalError("Metal render pipeline initialization failed (vertex: \(vertexShader), fragment: \(fragmentShader), pixel format: \(pixelFormat.rawValue)): \(error)")
        }
    }

    final func calculateWithCommandBuffer(buffer: MTLCommandBuffer, texture: MTLTexture, configureEncoder: ((_ commandEncoder: MTLRenderCommandEncoder) -> Void)?) {
        let encoder = makeEncoder(buffer: buffer, texture: texture)
        configureEncoder?(encoder)
        encoder.setRenderPipelineState(renderPipelineState)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        encoder.popDebugGroup()
        encoder.endEncoding()
    }

    final func calculateWithCommandBuffer(buffer: MTLCommandBuffer, indices: MTLBuffer, count: Int, texture: MTLTexture, configureEncoder: ((_ commandEncoder: MTLRenderCommandEncoder) -> Void)) {
        let encoder = makeEncoder(buffer: buffer, texture: texture)
        configureEncoder(encoder)
        encoder.setCullMode(.back)
        encoder.setRenderPipelineState(renderPipelineState)
        encoder.drawIndexedPrimitives(type: .triangle, indexCount: count, indexType: .uint16,
                                      indexBuffer: indices, indexBufferOffset: 0)
        encoder.popDebugGroup()
        encoder.endEncoding()
    }

    private func makeEncoder(buffer: MTLCommandBuffer, texture: MTLTexture) -> MTLRenderCommandEncoder {
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = texture
        pass.colorAttachments[0].loadAction = .dontCare
        pass.colorAttachments[0].storeAction = .store
        guard let encoder = buffer.makeRenderCommandEncoder(descriptor: pass) else {
            fatalError("Metal render encoder creation failed (vertex: \(pipelineState.vertexShader), fragment: \(pipelineState.fragmentShader), pixel format: \(texture.pixelFormat.rawValue), destination: \(texture.label ?? "unnamed"))")
        }
        encoder.pushDebugGroup("Render Encoder \(pipelineState.fragmentShader)")
        return encoder
    }
}
