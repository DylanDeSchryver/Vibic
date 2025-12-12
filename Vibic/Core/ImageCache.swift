import UIKit
import SwiftUI

final class ImageCache {
    static let shared = ImageCache()
    
    private let cache = NSCache<NSString, UIImage>()
    private let thumbnailQueue = DispatchQueue(label: "com.vibic.thumbnailQueue", qos: .userInitiated, attributes: .concurrent)
    
    private init() {
        cache.countLimit = 200
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB max
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(clearCache),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }
    
    @objc private func clearCache() {
        cache.removeAllObjects()
    }
    
    // MARK: - Thumbnail Generation
    
    func thumbnail(for trackId: UUID?, artworkData: Data?, size: CGSize) -> UIImage? {
        guard let trackId = trackId else { return nil }
        
        let cacheKey = "\(trackId.uuidString)_\(Int(size.width))x\(Int(size.height))" as NSString
        
        // Check cache first
        if let cached = cache.object(forKey: cacheKey) {
            return cached
        }
        
        // Generate thumbnail
        guard let data = artworkData,
              let image = UIImage(data: data) else {
            return nil
        }
        
        let thumbnail = generateThumbnail(from: image, targetSize: size)
        
        // Cache it
        if let thumbnail = thumbnail {
            let cost = Int(thumbnail.size.width * thumbnail.size.height * 4)
            cache.setObject(thumbnail, forKey: cacheKey, cost: cost)
        }
        
        return thumbnail
    }
    
    func thumbnailAsync(for trackId: UUID?, artworkData: Data?, size: CGSize, completion: @escaping (UIImage?) -> Void) {
        guard let trackId = trackId else {
            completion(nil)
            return
        }
        
        let cacheKey = "\(trackId.uuidString)_\(Int(size.width))x\(Int(size.height))" as NSString
        
        // Check cache first
        if let cached = cache.object(forKey: cacheKey) {
            completion(cached)
            return
        }
        
        // Generate on background thread
        thumbnailQueue.async { [weak self] in
            guard let data = artworkData,
                  let image = UIImage(data: data) else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            let thumbnail = self?.generateThumbnail(from: image, targetSize: size)
            
            // Cache and return on main thread
            DispatchQueue.main.async {
                if let thumbnail = thumbnail {
                    let cost = Int(thumbnail.size.width * thumbnail.size.height * 4)
                    self?.cache.setObject(thumbnail, forKey: cacheKey, cost: cost)
                }
                completion(thumbnail)
            }
        }
    }
    
    private func generateThumbnail(from image: UIImage, targetSize: CGSize) -> UIImage? {
        let scale = UIScreen.main.scale
        let scaledSize = CGSize(width: targetSize.width * scale, height: targetSize.height * scale)
        
        let renderer = UIGraphicsImageRenderer(size: scaledSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: scaledSize))
        }
    }
    
    // MARK: - Cache Management
    
    func preloadThumbnails(for tracks: [Track], size: CGSize) {
        thumbnailQueue.async { [weak self] in
            for track in tracks.prefix(20) {
                guard let trackId = track.id,
                      let artworkData = track.artworkData else { continue }
                
                let cacheKey = "\(trackId.uuidString)_\(Int(size.width))x\(Int(size.height))" as NSString
                
                // Skip if already cached
                if self?.cache.object(forKey: cacheKey) != nil { continue }
                
                if let image = UIImage(data: artworkData),
                   let thumbnail = self?.generateThumbnail(from: image, targetSize: size) {
                    let cost = Int(thumbnail.size.width * thumbnail.size.height * 4)
                    self?.cache.setObject(thumbnail, forKey: cacheKey, cost: cost)
                }
            }
        }
    }
    
    func removeThumbnail(for trackId: UUID?, size: CGSize) {
        guard let trackId = trackId else { return }
        let cacheKey = "\(trackId.uuidString)_\(Int(size.width))x\(Int(size.height))" as NSString
        cache.removeObject(forKey: cacheKey)
    }
}
