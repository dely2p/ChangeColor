//
//  ViewController.swift
//  ChangeColor
//
//  Created by dely on 2018. 10. 18..
//  Copyright © 2018년 dely. All rights reserved.
//

import UIKit
import Metal
import MetalKit

class ViewController: UIViewController {

    var pixelSize: UInt = 60
    @IBOutlet weak var imageView: UIImageView!
    @IBAction func changeButton(_ sender: Any) {
        
        queue.async { () -> Void in
            
            self.importTexture()
            
            self.applyFilter()
            
            let finalResult = self.image(from: self.outTexture)
            DispatchQueue.main.async {
                self.imageView.image = finalResult
            }
            
        }
    }
    
    /// The queue to process Metal
    let queue = DispatchQueue(label: "com.invasivecode.metalQueue")
    
    /// A Metal device
    lazy var device: MTLDevice! = MTLCreateSystemDefaultDevice()
    
    /// A Metal library
    lazy var defaultLibrary: MTLLibrary! = {
        self.device.makeDefaultLibrary()
    }()
    
    /// A Metal command queue
    lazy var commandQueue: MTLCommandQueue! = {
        NSLog("\(self.device.name)")
        return self.device.makeCommandQueue()
    }()
    
    var inTexture: MTLTexture!
    var outTexture: MTLTexture!
    let bytesPerPixel: Int = 4
    
    /// A Metal compute pipeline state
    var pipelineState: MTLComputePipelineState?
    
    func setUpMetal() {
        if let kernelFunction = defaultLibrary.makeFunction(name: "pixelate") {
            do {
                pipelineState = try device.makeComputePipelineState(function: kernelFunction)
                print("pipeline init")
            }
            catch {
                fatalError("Impossible to setup Metal")
            }
        }
    }
    
    let threadGroupCount = MTLSizeMake(16, 16, 1)
    
    lazy var threadGroups: MTLSize = {
        MTLSizeMake(Int(self.inTexture.width) / self.threadGroupCount.width, Int(self.inTexture.height) / self.threadGroupCount.height, 1)
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        queue.async {
            self.setUpMetal()
        }
    }
    
    func importTexture() {
        guard let image = UIImage(named: "bass") else {
            fatalError("Can't read image")
        }
        inTexture = texture(from: image)
    }
    
    func applyFilter() {
        
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            return
        }
        guard let commandEncoder = commandBuffer.makeComputeCommandEncoder() else {
            return
        }
        guard let pState = pipelineState else {
            print("is pipelinestate nil??")
            return
        }
        
        commandEncoder.setComputePipelineState(pState)
        commandEncoder.setTexture(inTexture, index: 0)
        commandEncoder.setTexture(outTexture, index: 1)
        
        let buffer = device.makeBuffer(bytes: &pixelSize, length: MemoryLayout<UInt>.size, options: MTLResourceOptions.storageModeShared)
        commandEncoder.setBuffer(buffer, offset: 0, index: 0)
        
        commandEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupCount)
        commandEncoder.endEncoding()
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }
    
    func texture(from image: UIImage) -> MTLTexture {
        
        guard let cgImage = image.cgImage else {
            fatalError("Can't open image \(image)")
        }
        
        let textureLoader = MTKTextureLoader(device: self.device)
        do {
            let textureOut = try textureLoader.newTexture(cgImage: cgImage, options: [:])
            let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: textureOut.pixelFormat, width: textureOut.width, height: textureOut.height, mipmapped: false)
            textureDescriptor.usage = [.shaderRead, .shaderWrite]
            outTexture = self.device.makeTexture(descriptor: textureDescriptor)
            return textureOut
        }
        catch {
            fatalError("Can't load texture")
        }
    }
    
    func image(from texture: MTLTexture) -> UIImage {
        
        let imageByteCount = texture.width * texture.height * bytesPerPixel
        let bytesPerRow = texture.width * bytesPerPixel
        var src = [UInt8](repeating: 0, count: Int(imageByteCount))
        
        let region = MTLRegionMake2D(0, 0, texture.width, texture.height)
        texture.getBytes(&src, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)
        
        let bitmapInfo = CGBitmapInfo(rawValue: (CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue))
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitsPerComponent = 8
        let context = CGContext(data: &src,
                                width: texture.width,
                                height: texture.height,
                                bitsPerComponent: bitsPerComponent,
                                bytesPerRow: bytesPerRow,
                                space: colorSpace,
                                bitmapInfo: bitmapInfo.rawValue)
        
        let dstImageFilter = context?.makeImage()
        
        return UIImage(cgImage: dstImageFilter!, scale: 0.0, orientation: UIImage.Orientation.up)
    }


}

