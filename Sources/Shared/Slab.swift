//
//  Slab.swift
//  FluidDynamicsMetal
//
//  Created by Andrei-Sergiu Pițiș on 15/08/2017.
//  Copyright © 2017 Andrei-Sergiu Pițiș. All rights reserved.
//

import Foundation
import Metal

@MainActor
class Slab {
    var ping: MTLTexture!
    var pong: MTLTexture!

    init(width: Int, height: Int, format: MTLPixelFormat = .rgba16Float, usage: MTLTextureUsage = .unknown, name: String? = nil) {
        let textureDescriptor = MTLTextureDescriptor()
        textureDescriptor.pixelFormat = format
        textureDescriptor.usage = MTLTextureUsage(rawValue: MTLTextureUsage.shaderRead.rawValue | MTLTextureUsage.renderTarget.rawValue)
        textureDescriptor.width = width
        textureDescriptor.height = height

        ping = MetalDevice.createTexture(descriptor: textureDescriptor)
        pong = MetalDevice.createTexture(descriptor: textureDescriptor)

        ping.label = name
        pong.label = name
    }

    func swap() {
        let temp = ping
        ping = pong
        pong = temp
    }

    // Only initial read surfaces need clearing: every pong is fully overwritten
    // before it becomes a source. Resized ping surfaces are populated by resampling.
    static func clearInitialFields(_ textures: [MTLTexture], commandBuffer: MTLCommandBuffer) {
        for texture in textures {
            let pass = MTLRenderPassDescriptor()
            pass.colorAttachments[0].texture = texture
            pass.colorAttachments[0].loadAction = .clear
            pass.colorAttachments[0].storeAction = .store
            pass.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0)
            guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: pass) else {
                fatalError("Unable to create initialization encoder for \(texture.label ?? "fluid field")")
            }
            encoder.endEncoding()
        }
    }
}
