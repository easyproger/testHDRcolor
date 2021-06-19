//
//  VideoMediaCacheItem.swift

import UIKit
import Foundation
import AVFoundation
import Photos

class PlayerView : UIView {
    let player: AVPlayer
    override init(frame: CGRect) {
        player = AVPlayer(playerItem: nil)
        player.isMuted = true
        super.init(frame: frame)
        if let playerLayer = self.layer as? AVPlayerLayer {
            playerLayer.player = player
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override class var layerClass: AnyClass { AVPlayerLayer.self }
}

class VideoMediaCacheItem: NSObject, AVPlayerItemOutputPullDelegate {
    private var videoOutput: AVPlayerItemVideoOutput?
    private var assetReader: AVAssetReader!
    private var trackOutputs: [AVAssetReaderTrackOutput]!
    
    private var player: AVPlayer?
    private var playerView: PlayerView?
    private var cleared = false
    var added: Bool = false
    var superView: UIView
    init(assetURL: URL?, superView: UIView, pixelOutFormat: OSType) {
        self.superView = superView
        
        super.init()
//        test(assetLocalIdentifier: "F5BCA583-68B6-49FF-8825-804479D1D8C4/L0/001", pixelOutFormat: pixelOutFormat)
//        "DB693DFB-8A4A-4E64-8563-6E03A55F9797/L0/001" vital on device
        
//        "F5BCA583-68B6-49FF-8825-804479D1D8C4/L0/001" vital HDR
//        "A5D607AB-86F3-45D5-9721-6AED2BE08AF9/L0/001" Vital
//        "8AE6EAA6-F7B7-4A81-8EC4-19F4E5EA48B5/L0/001" deserts
        setupPlaybackForAssetID(assetLocalIdentifier: "DB693DFB-8A4A-4E64-8563-6E03A55F9797/L0/001", waitUntilDone: false, pixelOutFormat: pixelOutFormat)
//        guard let url = assetURL else { return }
//        setupPlaybackForAssetID(url: url, pixelOutFormat: pixelOutFormat)
    }
    
    
    
    
    func test(assetLocalIdentifier: String, pixelOutFormat: OSType) {
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [assetLocalIdentifier], options: nil)
        guard let asset = assets.firstObject else { fatalError("no asset") }
        
        // We only want videos here
        guard asset.mediaType == .video else { return  }
        // Create your semaphore and allow only one thread to access it
        let semaphore = DispatchSemaphore.init(value: 0)
        let imageManager = PHImageManager()
        var avAsset_: AVAsset?
        // Lock the thread with the wait() command
        
        // Now go fetch the AVAsset for the given PHAsset
        imageManager.requestAVAsset(forVideo: asset, options: nil) { (asset, _, _) in
            // Save your asset to the earlier place holder
            avAsset_ = asset
            // We're done, let the semaphore know it can unlock now
            semaphore.signal()
        }
        semaphore.wait()
        
        
        guard let avasset = avAsset_ else { return }
        self.assetReader = try? AVAssetReader(asset: avasset)
        let selectedTracks = avasset.tracks(withMediaType: .video)
        let videoColorProperties = [AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
                                    AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
                                    AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2
        ]
        
        var size = avasset.naturalSize
        if avasset.naturalSize.width > 1920 || avasset.naturalSize.height > 1920 {
            let wScale = avasset.naturalSize.width / 1920
            let hScale = avasset.naturalSize.height / 1920
            if wScale > hScale {
                size.width = avasset.naturalSize.width / wScale
                size.height = avasset.naturalSize.height / wScale
            } else {
                size.width = avasset.naturalSize.width / hScale
                size.height = avasset.naturalSize.height / hScale
            }
        }
        
        
        let properties = NSMutableDictionary()
        properties["IOSurfaceIsGlobal"] = NSNumber(value: true)
        properties["IOSurfacePurgeWhenNotInUse"] = NSNumber(value: true)
        let outputSettings: [String: Any] = [
            kCVPixelBufferWidthKey as String: size.width,
            kCVPixelBufferHeightKey as String: size.height,
            kCVPixelBufferPixelFormatTypeKey as String: Int(pixelOutFormat),
            kCVPixelBufferMetalCompatibilityKey as String: true,
            AVVideoColorPropertiesKey: videoColorProperties,
            kCVPixelBufferIOSurfacePropertiesKey as String: properties
        ]
        
        
        self.trackOutputs = selectedTracks.map {
          AVAssetReaderTrackOutput(track: $0, outputSettings: outputSettings)
        }

        for trackOutput in self.trackOutputs {
          self.assetReader.add(trackOutput)
        }
        
        self.assetReader.timeRange = CMTimeRange(start: .zero, duration: avasset.duration)
        
        if !self.assetReader.startReading() {
          fatalError()
        }
    }
    
    func clear() {
        self.videoOutput = nil
    }
    
    
    private func initVideoOutput(asset: AVAsset, pixelOutFormat: OSType) {
        let this = self
        guard let _ = this.player else { return }
        
        var size = asset.naturalSize
        if asset.naturalSize.width > 1920 || asset.naturalSize.height > 1920 {
            let wScale = asset.naturalSize.width / 1920
            let hScale = asset.naturalSize.height / 1920
            if wScale > hScale {
                size.width = asset.naturalSize.width / wScale
                size.height = asset.naturalSize.height / wScale
            } else {
                size.width = asset.naturalSize.width / hScale
                size.height = asset.naturalSize.height / hScale
            }
        }
        let videoColorProperties = [AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
                                    AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
                                    AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2
        ]
        let properties = NSMutableDictionary()
        properties["IOSurfaceIsGlobal"] = NSNumber(value: true)
        properties["IOSurfacePurgeWhenNotInUse"] = NSNumber(value: true)
        let settings = [
            kCVPixelBufferWidthKey as String: size.width,
            kCVPixelBufferHeightKey as String: size.height,
            kCVPixelBufferMetalCompatibilityKey as String: true,
            kCVPixelBufferPixelFormatTypeKey as String: Int(pixelOutFormat),
            AVVideoColorPropertiesKey: videoColorProperties,
            kCVPixelBufferIOSurfacePropertiesKey as String: properties
        ] as [String : Any]
//        kCVImageBufferYCbCrMatrix_ITU_R_601_4
        
        
        
        let outputSettings: [String: Any] = [
            kCVPixelBufferWidthKey as String: size.width,
            kCVPixelBufferHeightKey as String: size.height,
            kCVPixelBufferMetalCompatibilityKey as String: true,
            kCVPixelBufferPixelFormatTypeKey as String: Int(pixelOutFormat),
            kCVPixelBufferIOSurfacePropertiesKey as String: properties,
          AVVideoColorPropertiesKey: [AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
                                      AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
                                      AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2
          ]
        ]
        
        
        
        
        
        this.videoOutput = AVPlayerItemVideoOutput(outputSettings: outputSettings)//AVPlayerItemVideoOutput(pixelBufferAttributes: settings)
    }
    
    func requestAVAsset(asset: PHAsset) -> AVAsset? {
        // We only want videos here
        guard asset.mediaType == .video else { return nil }
        // Create your semaphore and allow only one thread to access it
        let semaphore = DispatchSemaphore.init(value: 1)
        let imageManager = PHImageManager()
        var avAsset: AVAsset?
        // Lock the thread with the wait() command
        semaphore.wait()
        // Now go fetch the AVAsset for the given PHAsset
        imageManager.requestAVAsset(forVideo: asset, options: nil) { (asset, _, _) in
            // Save your asset to the earlier place holder
            avAsset = asset
            // We're done, let the semaphore know it can unlock now
            semaphore.signal()
        }

        return avAsset
    }
    
    private func setupPlaybackForAssetID(assetLocalIdentifier: String, waitUntilDone: Bool, pixelOutFormat: OSType) {
        
        
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [assetLocalIdentifier], options: nil)
        guard let asset = assets.firstObject else { fatalError("no asset") }
        
        
        
        
        let options = PHVideoRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        let _ = PHImageManager.default().requestPlayerItem(forVideo: asset,
            options: options,
            resultHandler: { [weak self] playerItem, info in
                guard let this = self else { return }
                guard let item = playerItem else { fatalError("can't get player item") }

                this.player = AVPlayer()
                
                guard let player = this.player else { return }
                
                let asset = item.asset
                this.initVideoOutput(asset: asset, pixelOutFormat: pixelOutFormat)
                guard let videoOutput = this.videoOutput else { return }
                item.add(videoOutput)
                player.replaceCurrentItem(with: item)
                player.seek(to: CMTime(seconds: 0, preferredTimescale: 60), toleranceBefore: CMTime.zero, toleranceAfter: CMTime.zero)
                player.play()
                NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: player.currentItem, queue: .main) { [weak self] _ in
                    guard let player = self?.player else { return}
                    player.seek(to: CMTime(seconds: 0, preferredTimescale: 60), toleranceBefore: CMTime.zero, toleranceAfter: CMTime.zero)
                    player.play()
                }
            }
        )
        
    }
    
    private var readyPixelBuffer: CVImageBuffer?
    
    func pixelBuffer(time: CMTime, complete: ((CVImageBuffer?) -> Void)? = nil) -> CVImageBuffer? {
//        guard let sampleBuffer = trackOutputs[0].copyNextSampleBuffer() else {
//          return nil
//        }
//        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
//            return nil
//        }
//        return imageBuffer
        
        
        guard let player = player else { return nil }
        guard let videoOutput = self.videoOutput else { return nil }
        guard let imageBufferR = videoOutput.copyPixelBuffer(forItemTime: player.currentTime(), itemTimeForDisplay: nil) else { return nil }
        
        return imageBufferR
    }
}

public extension AVAsset {
    
    var videoTrack: AVAssetTrack? { tracks(withMediaType: AVMediaType.video).first }
    var audioTrack: AVAssetTrack? { tracks(withMediaType: AVMediaType.audio).first }
    
    var naturalSize: CGSize { videoTrack?.naturalSize ?? .zero }
}
