//
//  MetalDevice.swift
//  FluidDynamicsMetal
//
//  Created by Andrei-Sergiu Pițiș on 06/06/2017.
//  Copyright © 2017 Andrei-Sergiu Pițiș. All rights reserved.
//

import Foundation
import Metal

enum MetalDeviceError: Error {
    case failedToCreateFunction(name: String)
}

struct RenderPipelineKey: Hashable {
    let vertexFunctionName: String
    let fragmentFunctionName: String
    let pixelFormat: MTLPixelFormat
}

@MainActor
class MetalDevice {
    static let sharedInstance = MetalDevice()
    
    private var renderPipelineCache: [RenderPipelineKey: MTLRenderPipelineState] = [:]
    private let computePipelineCache = NSCache<NSString, AnyObject>()
    
    let queue = DispatchQueue.global(qos: .background)
    
    let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    
    var activeCommandBuffer: MTLCommandBuffer
    let defaultLibrary: MTLLibrary
    
    internal var inputTexture: MTLTexture?
    internal var outputTexture: MTLTexture?
    
    private convenience init() {
        let device = MTLCreateSystemDefaultDevice()!
        self.init(device: device, library: device.makeDefaultLibrary()!)
    }

    // Explicit dependencies let offscreen checks use the same pipeline factory.
    init(device: MTLDevice, library: MTLLibrary) {
        self.device = device
        commandQueue = device.makeCommandQueue()!
        activeCommandBuffer = commandQueue.makeCommandBuffer()!
        defaultLibrary = library
    }

    //Convenience methods
    
    final class func createRenderPipeline(vertexFunctionName: String = "basicVertexFunction", fragmentFunctionName: String, pixelFormat: MTLPixelFormat) throws -> MTLRenderPipelineState {
        return try self.sharedInstance.createRenderPipeline(vertexFunctionName: vertexFunctionName, fragmentFunctionName: fragmentFunctionName, pixelFormat: pixelFormat)
    }
    
    final class func createComputePipeline(computeFunctionName: String) throws -> MTLComputePipelineState {
        return try self.sharedInstance.createComputePipeline(computeFunctionName: computeFunctionName)
    }
    
    final class func createTexture(descriptor: MTLTextureDescriptor) -> MTLTexture {
        return self.sharedInstance.device.makeTexture(descriptor: descriptor)!
    }
    
    final func swapBuffers() {
        let texture = inputTexture
        inputTexture = outputTexture
        outputTexture = texture
    }
    
    final func buffer<T: BitwiseCopyable>(array: [T], storageMode: MTLResourceOptions = []) -> MTLBuffer {
        precondition(!array.isEmpty, "A Metal buffer requires nonempty data")
        return array.withUnsafeBytes { bytes in
            device.makeBuffer(bytes: bytes.baseAddress!, length: bytes.count, options: storageMode)!
        }
    }
    
    final func newCommandBuffer() -> MTLCommandBuffer {
        return commandQueue.makeCommandBuffer()!
    }
    
    final func createRenderPipeline(vertexFunctionName: String = "basicVertexFunction", fragmentFunctionName: String, pixelFormat: MTLPixelFormat) throws -> MTLRenderPipelineState {
        let cacheKey = RenderPipelineKey(vertexFunctionName: vertexFunctionName,
                                         fragmentFunctionName: fragmentFunctionName,
                                         pixelFormat: pixelFormat)
        
        if let pipelineState = renderPipelineCache[cacheKey] {
            return pipelineState
        }
        
        guard let vertexFunction = defaultLibrary.makeFunction(name: vertexFunctionName) else {
            throw MetalDeviceError.failedToCreateFunction(name: vertexFunctionName)
        }
        
        guard let fragmentFunction = defaultLibrary.makeFunction(name: fragmentFunctionName) else {
            throw MetalDeviceError.failedToCreateFunction(name: fragmentFunctionName)
        }
        
        let pipelineStateDescriptor = MTLRenderPipelineDescriptor()
        pipelineStateDescriptor.colorAttachments[0].pixelFormat = pixelFormat
        pipelineStateDescriptor.vertexFunction = vertexFunction
        pipelineStateDescriptor.fragmentFunction = fragmentFunction
        pipelineStateDescriptor.label = fragmentFunctionName
        
        let pipelineState = try device.makeRenderPipelineState(descriptor: pipelineStateDescriptor)
        
        renderPipelineCache[cacheKey] = pipelineState
        
        return pipelineState
    }
    
    final func createComputePipeline(computeFunctionName: String) throws -> MTLComputePipelineState {
        let cacheKey = NSString(string: computeFunctionName)
        
        if let pipelineState = computePipelineCache.object(forKey: cacheKey) as? MTLComputePipelineState {
            return pipelineState
        }
        
        guard let computeFunction = defaultLibrary.makeFunction(name: computeFunctionName) else {
            throw MetalDeviceError.failedToCreateFunction(name: computeFunctionName)
        }
        
        let pipelineState =  try device.makeComputePipelineState(function: computeFunction)
        
        computePipelineCache.setObject(pipelineState, forKey: cacheKey)
        
        return pipelineState
    }
}
