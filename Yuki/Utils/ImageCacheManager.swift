//
//  PersistentImageCacheManager.swift
//  Yuki
//
//  Created by Daniel Inama on 7/3/25.
//

import AppKit
import CryptoKit

/// Cache manager for images with both memory and disk caching
class ImageCacheManager {
    /// Singleton instance
    static let shared = ImageCacheManager()
    
    /// In-memory cache dictionary
    private var memoryCache = NSCache<NSURL, NSImage>()
    
    /// Queue for thread-safe operations
    private let queue = DispatchQueue(label: "com.yuki.ImageCacheQueue", attributes: .concurrent)
    
    /// Cache directory URL
    private var cacheDirectory: URL? {
        // Get the application support directory
        guard let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            print("Failed to get caches directory")
            return nil
        }
        
        // Create a specific cache directory for our app
        let appCacheDir = cachesDirectory.appendingPathComponent("com.frostplexx.Yuki/ImageCache", isDirectory: true)
        
        // Create the directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: appCacheDir.path) {
            do {
                try FileManager.default.createDirectory(at: appCacheDir, withIntermediateDirectories: true)
                return appCacheDir
            } catch {
                print("Failed to create cache directory: \(error)")
                return nil
            }
        }
        
        return appCacheDir
    }
    
    private let fileManager = FileManager.default
    
    private init() {
        memoryCache.countLimit = 100 // Limit the number of items in memory cache
        memoryCache.totalCostLimit = 50 * 1024 * 1024 // Limit total size to 50MB
        
        // Set up periodic disk cache cleanup
        Timer.scheduledTimer(withTimeInterval: 86400, repeats: true) { [weak self] _ in
            self?.cleanupDiskCache()
        }
        
        // Ensure the cache directory exists
        if let _ = cacheDirectory {
            print("Image cache directory initialized")
        }
    }
    
    /// Get an image from the cache or load it asynchronously
    /// - Parameters:
    ///   - url: URL of the image
    ///   - completion: Completion handler with the loaded image
    func getImage(for url: URL, completion: @escaping (NSImage?) -> Void) {
        // Check memory cache first (fastest)
        queue.async { [weak self] in
            guard let self = self else {
                completion(nil)
                return
            }
            
            // If image is in memory cache, return it immediately
            if let cachedImage = self.memoryCache.object(forKey: url as NSURL) {
                DispatchQueue.main.async {
                    completion(cachedImage)
                }
                return
            }
            
            // Next, check disk cache
            if let diskCachedImage = self.loadImageFromDiskCache(for: url) {
                // Store in memory cache for future use
                self.memoryCache.setObject(diskCachedImage, forKey: url as NSURL)
                
                DispatchQueue.main.async {
                    completion(diskCachedImage)
                }
                return
            }
            
            // Finally, load from source
            Task {
                if let image = await self.loadImage(from: url) {
                    // Save to disk cache
                    self.saveImageToDiskCache(image, for: url)
                    
                    // Store in memory cache
                    self.memoryCache.setObject(image, forKey: url as NSURL)
                    
                    // Return image on main thread
                    DispatchQueue.main.async {
                        completion(image)
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(nil)
                    }
                }
            }
        }
    }
    
    /// Load an image asynchronously
    /// - Parameter url: URL of the image
    /// - Returns: The loaded image, if successful
    private func loadImage(from url: URL) async -> NSImage? {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return NSImage(data: data)
        } catch {
            // Handle local file URLs differently (most wallpapers are local files)
            if url.isFileURL {
                return NSImage(contentsOf: url)
            }
            return nil
        }
    }
    
    /// Generate a unique filename for caching based on URL
    private func cacheFilename(for url: URL) -> String {
        // Hash the URL to create a unique, valid filename
        let urlString = url.absoluteString
        let hash = SHA256.hash(data: urlString.data(using: .utf8) ?? Data())
        let hashString = hash.prefix(16).compactMap { String(format: "%02x", $0) }.joined()
        
        // Return filename with extension based on URL path extension or default to png
        let ext = url.pathExtension.isEmpty ? "png" : url.pathExtension
        return "\(hashString).\(ext)"
    }
    
    /// Load image from disk cache
    /// - Parameter url: Original URL of the image
    /// - Returns: Cached image if available
    private func loadImageFromDiskCache(for url: URL) -> NSImage? {
        guard let cacheDir = cacheDirectory else { return nil }
        
        let cacheFile = cacheDir.appendingPathComponent(cacheFilename(for: url))
        
        if FileManager.default.fileExists(atPath: cacheFile.path) {
            return NSImage(contentsOfFile: cacheFile.path)
        }
        
        return nil
    }
    
    /// Save image to disk cache
    /// - Parameters:
    ///   - image: Image to cache
    ///   - url: Original URL of the image
    private func saveImageToDiskCache(_ image: NSImage, for url: URL) {
        guard let cacheDir = cacheDirectory else { return }
        
        let cacheFile = cacheDir.appendingPathComponent(cacheFilename(for: url))
        
        // Convert to proper format based on file extension
        let fileExtension = cacheFile.pathExtension.lowercased()
        
        guard let imageData = getBitmapDataForImage(image, fileExtension: fileExtension) else {
            print("Failed to get bitmap data for image")
            return
        }
        
        do {
            try imageData.write(to: cacheFile)
        } catch {
            print("Failed to write image to cache: \(error)")
        }
    }
    
    /// Get bitmap data for an image in the appropriate format
    private func getBitmapDataForImage(_ image: NSImage, fileExtension: String) -> Data? {
        guard let rep = NSBitmapImageRep(data: image.tiffRepresentation ?? Data()) else {
            return nil
        }
        
        // Convert to appropriate format based on extension
        switch fileExtension {
        case "jpg", "jpeg":
            return rep.representation(using: .jpeg, properties: [:])
        case "png":
            return rep.representation(using: .png, properties: [:])
        case "tiff", "tif":
            return rep.representation(using: .tiff, properties: [:])
        default:
            // Default to PNG for unknown formats
            return rep.representation(using: .png, properties: [:])
        }
    }
    
    /// Clear the memory cache only (keeps disk cache)
    func clearMemoryCache() {
        queue.async(flags: .barrier) { [weak self] in
            self?.memoryCache.removeAllObjects()
        }
    }
    
    /// Clear both memory and disk cache
    func clearAllCache() {
        // Clear memory cache
        queue.async(flags: .barrier) { [weak self] in
            self?.memoryCache.removeAllObjects()
        }
        
        // Clear disk cache
        guard let cacheDir = cacheDirectory else { return }
        
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(
                at: cacheDir,
                includingPropertiesForKeys: nil
            )
            
            for fileURL in fileURLs {
                try FileManager.default.removeItem(at: fileURL)
            }
        } catch {
            print("Failed to clear disk cache: \(error)")
        }
    }
    
    /// Remove a specific image from both memory and disk cache
    /// - Parameter url: URL of the image to remove
    func removeImage(for url: URL) {
        // Remove from memory cache
        queue.async(flags: .barrier) { [weak self] in
            self?.memoryCache.removeObject(forKey: url as NSURL)
        }
        
        // Remove from disk cache
        guard let cacheDir = cacheDirectory else { return }
        
        let cacheFile = cacheDir.appendingPathComponent(cacheFilename(for: url))
        
        if FileManager.default.fileExists(atPath: cacheFile.path) {
            do {
                try FileManager.default.removeItem(at: cacheFile)
            } catch {
                print("Failed to remove image from disk cache: \(error)")
            }
        }
    }
    
    private func cleanupDiskCache() {
        guard let cacheDir = cacheDirectory else { return }
        
        let expirationDate = Date().addingTimeInterval(-7 * 86400) // 7 days ago
        
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: [.creationDateKey])
            for fileURL in fileURLs {
                guard let creationDate = try fileURL.resourceValues(forKeys: [.creationDateKey]).creationDate else { continue }
                if creationDate < expirationDate {
                    try fileManager.removeItem(at: fileURL)
                }
            }
        } catch {
            print("Failed to clean up disk cache: \(error)")
        }
    }
}
