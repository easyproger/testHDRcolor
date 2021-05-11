//
//  TestMTK.swift
//  testHDR
//
//  Created by Дмитрий Савичев on 05.03.2021.
//

import UIKit
import MetalKit
import MetalPerformanceShaders

class TestMTK: MTKView {
    var lutTexture: MTLTexture!
    private var pixelVideoFormat: OSType = kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
    
    private var textureCache: CVMetalTextureCache?
    var bufferLayerVertex: MTLBuffer?
    var bufferDataLayer: [Float] = [
        -1,  1,  0,  0,
         1,  1,  1,  0,
        -1, -1,  0,  1,
        
         1,  1,  1,  0,
        -1, -1,  0,  1,
         1, -1,  1,  1,
    ]
    var bufferDataLayerPortrait: [Float] = [
        -1,  1,  0,  1,
         1,  1,  0,  0,
        -1, -1,  1,  1,
        
         1,  1,  0,  0,
        -1, -1,  1,  1,
         1, -1,  1,  0,
    ]
    private func makeCoordsBuffer(data: [Float]) -> MTLBuffer? {
        let dataSize = data.count * MemoryLayout.size(ofValue: data[0])
        return device.makeBuffer(bytes: data, length: dataSize, options: [])
    }
    
    private var commandQueue: MTLCommandQueue! = nil
    private var library: MTLLibrary! = nil
    
    private let renderPassDescriptor = MTLRenderPassDescriptor()
    private var pipelineDescriptor = MTLRenderPipelineDescriptor()
    private var pipelineState : MTLRenderPipelineState?

    var videoSource: VideoMediaCacheItem?
    
    var textures: [MTLTexture] = []
    
    override var device: MTLDevice! {
        didSet {
            super.device = device
            commandQueue = (self.device?.makeCommandQueue())!
            
            do {
                self.library = try device.makeDefaultLibrary(bundle: Bundle(for: type(of: self)))
            } catch {
                fatalError(error.localizedDescription)
            }
            guard let vertex = library?.makeFunction(name: "vertexDefault") else { return }
            
            switch pixelVideoFormat {
            case kCVPixelFormatType_420YpCbCr8BiPlanarFullRange, kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange:
                guard let fragment = library?.makeFunction(name: "capturedImageFragmentShader") else { return }
                pipelineDescriptor.fragmentFunction = fragment
            default:
                guard let fragment = library?.makeFunction(name: "layerFragment") else { return }
                pipelineDescriptor.fragmentFunction = fragment
            }
            
            pipelineDescriptor.vertexFunction = vertex
            
            pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            
            let vert = MTLVertexAttributeDescriptor()
            vert.format = .float2
            vert.bufferIndex = 0
            vert.offset = 0
            
            // Texture coordinates
            let tex = MTLVertexAttributeDescriptor()
            tex.format = .float2
            tex.bufferIndex = 0
            tex.offset = 2 * MemoryLayout<Float>.size
            
            let layout = MTLVertexBufferLayoutDescriptor()
            layout.stride = 4 * MemoryLayout<Float>.size
            layout.stepFunction = .perVertex
            
            let desc = MTLVertexDescriptor()
            desc.layouts[0] = layout
            desc.attributes[0] = vert
            desc.attributes[1] = tex
            
            pipelineDescriptor.vertexDescriptor = desc
            do {
                try pipelineState = device?.makeRenderPipelineState(descriptor: pipelineDescriptor)
            } catch (let e) {
                print("e \(e.localizedDescription)")
                return
            }
            
            bufferLayerVertex = makeCoordsBuffer(data: bufferDataLayerPortrait)
            
            _ = device.map { CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, $0, nil, &textureCache) }
            lutTexture = newTexture(UIImage(named: "candidate1")!)
        }
    }
    func newTexture(_ image: UIImage) -> MTLTexture {
        let imageRef = image.cgImage!
        let width = imageRef.width
        let height = imageRef.height
        let colorSpace = CGColorSpaceCreateDeviceRGB() //s色域
        let rawData = calloc(height * width * 4, MemoryLayout<UInt8>.size) //图片存储数据的指针
        let bitsPerComponent = 8 //指定每一个像素中组件的位数(bits，二进制位)。例如：对于32位格式的RGB色域，你需要为每一个部分指定8位
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let context = CGContext(data: rawData,
                  width: width,
                  height: height,
                  bitsPerComponent: bitsPerComponent,
                  bytesPerRow: bytesPerRow,
                  space: colorSpace,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue)
        context?.draw(imageRef, in: CGRect(x: 0, y: 0, width: width, height: height))
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: width, height: height, mipmapped: false)
        let texture = device?.makeTexture(descriptor: textureDescriptor)
        let region = MTLRegionMake2D(0, 0, width, height)
        texture?.replace(region: region, mipmapLevel: 0, withBytes: rawData!, bytesPerRow: bytesPerRow)
        free(rawData)
        return texture!
    }
    init(frame frameRect: CGRect, device: MTLDevice?, url: URL) {
        super.init(frame: frameRect, device: device)
        
        self.videoSource = VideoMediaCacheItem(assetURL: url, superView: self, pixelOutFormat: pixelVideoFormat)
        
        configureWithDevice(device!)
    }
    
    required init(coder: NSCoder) {
        super.init(coder: coder)
        configureWithDevice(MTLCreateSystemDefaultDevice()!)
    }
    
    private func configureWithDevice(_ device : MTLDevice) {
        self.clearColor = MTLClearColor.init(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
        self.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.framebufferOnly = false
        self.colorPixelFormat = .bgra8Unorm
        
        self.preferredFramesPerSecond = 60
        self.device = device
        
        self.isPaused = false
    }
    
    func createTexture(fromPixelBuffer pixelBuffer: CVPixelBuffer, pixelFormat: MTLPixelFormat, planeIndex: Int) -> MTLTexture? {
        var mtlTexture: MTLTexture? = nil
        let width = CVPixelBufferGetWidthOfPlane(pixelBuffer, planeIndex)
        let height = CVPixelBufferGetHeightOfPlane(pixelBuffer, planeIndex)
        
        var texture: CVMetalTexture? = nil
        let status = CVMetalTextureCacheCreateTextureFromImage(nil, textureCache!, pixelBuffer, nil, pixelFormat, width, height, planeIndex, &texture)
        if status == kCVReturnSuccess {
            mtlTexture = CVMetalTextureGetTexture(texture!)
        }
        
        return mtlTexture
    }
    
    func render(descriptor: MTLRenderPassDescriptor, drawable: CAMetalDrawable? = nil) {
        guard let videoSource = self.videoSource,
              let pixelBuffer = videoSource.pixelBuffer(time: .zero) else { return }
        guard let pipelineState = pipelineState else { return }
        guard let bufferLayerVertex = bufferLayerVertex else { return }
        guard let buffer = commandQueue?.makeCommandBuffer() else { return }
        
        if let encoder = buffer.makeRenderCommandEncoder(descriptor: descriptor) {
            
            encoder.setVertexBuffer(bufferLayerVertex, offset: 0, index: 0)
            
            switch pixelVideoFormat {
            case kCVPixelFormatType_420YpCbCr8BiPlanarFullRange, kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange:
                guard let firstPlane = createTexture(fromPixelBuffer: pixelBuffer, pixelFormat:.r8Unorm, planeIndex:0) else { return }
                guard let secondPlane = createTexture(fromPixelBuffer: pixelBuffer, pixelFormat:.rg8Unorm, planeIndex:1) else { return }
                encoder.setFragmentTexture(firstPlane, index: 0)
                encoder.setFragmentTexture(secondPlane, index: 1)
                encoder.setFragmentTexture(lutTexture, index: 2)
            default:
                guard let firstPlane = createTexture(fromPixelBuffer: pixelBuffer, pixelFormat:.bgra8Unorm, planeIndex:0) else { return }
                encoder.setFragmentTexture(firstPlane, index: 0)
                encoder.setFragmentTexture(lutTexture, index: 1)
                break
            }
            
            encoder.setRenderPipelineState(pipelineState)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6, instanceCount: 1)
            encoder.endEncoding()
        }
        
        if let drawable = drawable { buffer.present(drawable) }
        buffer.commit()
    }
    
    override func draw(_ rect: CGRect) {
        guard let descriptor = currentRenderPassDescriptor else { return }
        guard let drawable = currentDrawable else { return }
        render(descriptor: descriptor, drawable: drawable)
    }
}
