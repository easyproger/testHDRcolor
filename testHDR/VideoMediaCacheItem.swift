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
    private var player: AVPlayer?
    private var playerView: PlayerView?
    private var cleared = false
    var added: Bool = false
    var superView: UIView
    init(assetURL: URL?, superView: UIView, pixelOutFormat: OSType) {
        self.superView = superView
        super.init()
        
        guard let url = assetURL else { return }
        setupPlaybackForAssetID(url: url, pixelOutFormat: pixelOutFormat)
    }
    
    func clear() {
        self.videoOutput = nil
    }
    
    private func setupPlaybackForAssetID(url: URL, pixelOutFormat: OSType) {
        let this = self
        let item = AVPlayerItem(url: url)
        let playerView = PlayerView(frame: CGRect(origin: CGPoint(x: 0, y: 0), size: CGSize(width: 200, height: 200)))
        playerView.backgroundColor = .green
        this.playerView = playerView
        if !this.added {
//            superView.addSubview(playerView)
            this.added = true
        }
        
        this.player = playerView.player
        
        guard let player = this.player else { return }
        
        let properties = NSMutableDictionary()
        properties["IOSurfaceIsGlobal"] = NSNumber(value: true)
        properties["IOSurfacePurgeWhenNotInUse"] = NSNumber(value: true)
        let settings = [
            kCVPixelBufferMetalCompatibilityKey as String: true,
            kCVPixelBufferPixelFormatTypeKey as String: Int(pixelOutFormat),
            kCVPixelBufferIOSurfacePropertiesKey as String: properties
        ] as [String : Any]
        
        this.videoOutput = AVPlayerItemVideoOutput(pixelBufferAttributes: settings)
        
        item.add(this.videoOutput!)
        player.replaceCurrentItem(with: item)
        player.seek(to: CMTime(seconds: 0, preferredTimescale: 60), toleranceBefore: CMTime.zero, toleranceAfter: CMTime.zero)
        
        playerView.player.play()
        
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: player.currentItem, queue: .main) { [weak self] _ in
            self?.playerView?.player.seek(to: .zero)
            self?.playerView?.player.play()
        }
    }
    
    private var readyPixelBuffer: CVImageBuffer?
    
    func pixelBuffer(time: CMTime, complete: ((CVImageBuffer?) -> Void)? = nil) -> CVImageBuffer? {
        guard let player = player else { return nil }
        guard let videoOutput = self.videoOutput else { return nil }
        return videoOutput.copyPixelBuffer(forItemTime: .zero, itemTimeForDisplay: nil)
    }
}
