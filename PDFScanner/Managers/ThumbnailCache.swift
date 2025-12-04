import UIKit

class ThumbnailCache {
    static let shared = ThumbnailCache()
    private let cache = NSCache<NSURL, UIImage>()
    private let fileManager = FileManager.default
    private let diskCacheURL: URL
    
    private init() {
        // Limit memory usage
        cache.countLimit = 200 
        cache.totalCostLimit = 1024 * 1024 * 100 // 100 MB approx
        
        // Setup Disk Cache Directory
        let cachePaths = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        diskCacheURL = cachePaths[0].appendingPathComponent("Thumbnails")
        
        try? fileManager.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
    }
    
    func image(for url: URL) -> UIImage? {
        // 1. Check Memory Cache
        if let cachedImage = cache.object(forKey: url as NSURL) {
            return cachedImage
        }
        
        // 2. Check Disk Cache
        let diskURL = diskCachePath(for: url)
        if let data = try? Data(contentsOf: diskURL),
           let image = UIImage(data: data) {
            // Restore to Memory Cache
            cache.setObject(image, forKey: url as NSURL)
            return image
        }
        
        return nil
    }
    
    func insert(_ image: UIImage, for url: URL) {
        // 1. Save to Memory Cache
        cache.setObject(image, forKey: url as NSURL)
        
        // 2. Save to Disk Cache (Async)
        Task.detached(priority: .background) {
            let diskURL = self.diskCachePath(for: url)
            if let data = image.jpegData(compressionQuality: 0.7) {
                try? data.write(to: diskURL)
            }
        }
    }
    
    func removeImage(for url: URL) {
        cache.removeObject(forKey: url as NSURL)
        let diskURL = diskCachePath(for: url)
        try? fileManager.removeItem(at: diskURL)
    }
    
    func clear() {
        cache.removeAllObjects()
        try? fileManager.removeItem(at: diskCacheURL)
        try? fileManager.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
    }
    
    private func diskCachePath(for url: URL) -> URL {
        // Use filename + hash to ensure uniqueness and valid filename
        let filename = url.lastPathComponent
        let hash = url.path.hashValue
        return diskCacheURL.appendingPathComponent("\(hash)_\(filename).jpg")
    }
}
