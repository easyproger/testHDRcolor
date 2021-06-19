//
//  ViewController.swift
//  testHDR
//
//  Created by Дмитрий Савичев on 05.03.2021.
//

import UIKit
import MetalKit
import MetalPerformanceShaders
import Photos
class ViewController: UIViewController {

    var metalView: TestMTK?
    override func viewDidLoad() {
        super.viewDidLoad()
        
       
//        let inputImage = UIImage(named: "gray")!
//        let context = CIContext(options: nil)
//        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { return }
//        if let currentFilter = colorCubeFilterFromLUT(imageName: "itur2020HLGtoSRGB", colorSpace: colorSpace) {
//            
//            
//            var options: [CIImageOption : Any] = [:]
////            options[.applyOrientationProperty] = true
////            options[.properties] = [kCGImagePropertyOrientation: CGImagePropertyOrientation.downMirrored.rawValue]
//            if #available(iOS 14.0, *) {
//                options[CIImageOption.colorSpace] = CGColorSpace(name: kCGColorSpaceITUR_2100_HLG)
//            }
//            let beginImage = CIImage(image: inputImage, options: options)
//            
//            currentFilter.setValue(beginImage, forKey: kCIInputImageKey)
////            currentFilter.setValue(1.0, forKey: kCIInputIntensityKey)
//
//            if let output = currentFilter.outputImage {
//                if let cgimg = context.createCGImage(output, from: output.extent) {
//                    let processedImage = UIImage(cgImage: cgimg)
//                    // do something interesting with the processed image
//                    
//                    
//                    do {
//                            if let data = processedImage.pngData() {
//                                let filename = getDocumentsDirectory().appendingPathComponent("converted111.png")
//                                try? data.write(to: filename)
//                            }
//
//                    }catch (let e) {
//                        print(e.localizedDescription)
//                    }
//                    
//                    
//                }
//            }
//        }
        
        
        
        PHPhotoLibrary.requestAuthorization { _ in
            DispatchQueue.main.async { self.initViews() }
        }
    }

    func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
    
    fileprivate func colorCubeFilterFromLUT(imageName : String, colorSpace: CGColorSpace) -> CIFilter? {

        let size = 64

        let lutImage    = UIImage(named: imageName)!.cgImage
        let lutWidth    = lutImage!.width
        let lutHeight   = lutImage!.height
        let rowCount    = lutHeight / size
        let columnCount = lutWidth / size

        if ((lutWidth % size != 0) || (lutHeight % size != 0) || (rowCount * columnCount != size)) {
            NSLog("Invalid colorLUT %@", imageName);
            return nil
        }

        let bitmap  = getBytesFromImage(image: UIImage(named: imageName), colorSpace: colorSpace)!
        let floatSize = MemoryLayout<Float>.size

        let cubeData = UnsafeMutablePointer<Float>.allocate(capacity: size * size * size * 4 * floatSize)
        var z = 0
        var bitmapOffset = 0

        for _ in 0 ..< rowCount {
            for y in 0 ..< size {
                let tmp = z
                for _ in 0 ..< columnCount {
                    for x in 0 ..< size {

                        let alpha   = Float(bitmap[bitmapOffset]) / 255.0
                        let red     = Float(bitmap[bitmapOffset+1]) / 255.0
                        let green   = Float(bitmap[bitmapOffset+2]) / 255.0
                        let blue    = Float(bitmap[bitmapOffset+3]) / 255.0

                        let dataOffset = (z * size * size + y * size + x) * 4

                        cubeData[dataOffset + 3] = alpha
                        cubeData[dataOffset + 2] = red
                        cubeData[dataOffset + 1] = green
                        cubeData[dataOffset + 0] = blue
                        bitmapOffset += 4
                    }
                    z += 1
                }
                z = tmp
            }
            z += columnCount
        }

        let colorCubeData = NSData(bytesNoCopy: cubeData, length: size * size * size * 4 * floatSize, freeWhenDone: true)

        // create CIColorCube Filter
        let filter = CIFilter(name: "CIColorCube")
        filter?.setValue(colorCubeData, forKey: "inputCubeData")
        filter?.setValue(size, forKey: "inputCubeDimension")

        return filter
    }


    fileprivate func getBytesFromImage(image:UIImage?, colorSpace: CGColorSpace) -> [UInt8]?
    {
        var pixelValues: [UInt8]?
        if let imageRef = image?.cgImage {
            let width = Int(imageRef.width)
            let height = Int(imageRef.height)
            let bitsPerComponent = 8
            let bytesPerRow = width * 4
            let totalBytes = height * bytesPerRow

            let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
            var intensities = [UInt8](repeating: 0, count: totalBytes)

            let contextRef = CGContext(data: &intensities, width: width, height: height, bitsPerComponent: bitsPerComponent, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo)
            contextRef?.draw(imageRef, in: CGRect(x: 0.0, y: 0.0, width: CGFloat(width), height: CGFloat(height)))

            pixelValues = intensities
        }
        return pixelValues!
    }
    
    
    func initViews() {
        guard let fileURL = Bundle.main.url(forResource: "IMG_0423", withExtension: "MOV") else { return }
        metalView = TestMTK(frame: .zero, device: MTLCreateSystemDefaultDevice(), url: fileURL)
        
        if #available(iOS 14.0, *) {
            if let metalLayer = metalView!.layer as? CAMetalLayer {
                metalLayer.colorspace = CGColorSpace(name: CGColorSpace.sRGB)
            }
        } else {
            // Fallback on earlier versions
        }
        
        metalView?.backgroundColor = .red
        metalView!.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(metalView!)
        
        NSLayoutConstraint.activate([
            metalView!.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            metalView!.leftAnchor.constraint(equalTo: view.leftAnchor),
            metalView!.rightAnchor.constraint(equalTo: view.rightAnchor),
            metalView!.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])
//
//        NSLayoutConstraint.activate([
//            metalView!.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
//            metalView!.leftAnchor.constraint(equalTo: view.leftAnchor),
//            metalView!.widthAnchor.constraint(equalToConstant: 200),
//            metalView!.heightAnchor.constraint(equalToConstant: 300),
//        ])
    }

}

