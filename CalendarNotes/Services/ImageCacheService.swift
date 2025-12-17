//
//  ImageCacheService.swift
//  CalendarNotes
//
//  Created by Soham Mahesh Naik on 23/10/25.
//

import Foundation
import SwiftUI
import Combine

// MARK: - Image Cache Service (macOS Compatible)

class ImageCacheService: ObservableObject {
    static let shared = ImageCacheService()
    
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    private let diskCacheQueue = DispatchQueue(label: "com.calendarnotes.imagecache.disk")
    private let imageProcessingQueue = DispatchQueue(label: "com.calendarnotes.imagecache.processing", qos: .userInitiated)
    
    private let maxDiskCacheSize: Int64 = 100 * 1024 * 1024 // 100MB
    private let maxMemoryCacheSize: Int = 50 * 1024 * 1024 // 50MB
    
    // Use NSCache for automatic memory pressure handling
    #if os(macOS)
    private let memoryCache = NSCache<NSString, NSImage>()
    #else
    private let memoryCache = NSCache<NSString, UIImage>()
    #endif
    
    private var memoryCacheSize: Int = 0
    
    private init() {
        // Setup disk cache directory
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        cacheDirectory = documentsPath.appendingPathComponent("ImageCache")
        
        // Create cache directory if it doesn't exist
        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        }
        
        // Configure NSCache
        memoryCache.totalCostLimit = maxMemoryCacheSize
        memoryCache.countLimit = 100 // Limit number of cached images
        memoryCache.name = "com.calendarnotes.imagecache.memory"
        
        // Observe memory warnings to clear cache
        #if os(iOS)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
        #endif
        
        // Clean up old cache files on startup
        cleanUpOldCacheFiles()
    }
    
    #if os(iOS)
    @objc private func handleMemoryWarning() {
        clearMemoryCache()
    }
    
    func handleMemoryWarningPublic() {
        clearMemoryCache()
        cleanUpOldCacheFiles()
    }
    #endif
    
    // MARK: - Image Loading
    
    func loadImage(named name: String) -> AnyPublisher<Data?, Never> {
        return Future { [weak self] promise in
            self?.loadImageSync(named: name) { data in
                promise(.success(data))
            }
        }
        .eraseToAnyPublisher()
    }
    
    func loadImageSync(named name: String, completion: @escaping (Data?) -> Void) {
        // Check memory cache first
        if let cachedImage = getFromMemoryCache(name: name) {
            DispatchQueue.main.async {
                completion(cachedImage)
            }
            return
        }
        
        // Check disk cache
        diskCacheQueue.async { [weak self] in
            guard let self = self else { return }
            let diskPath = self.cacheDirectory.appendingPathComponent("\(name.hash).jpg")
            
            if self.fileManager.fileExists(atPath: diskPath.path) {
                if let data = try? Data(contentsOf: diskPath) {
                    // Downscale large images before returning
                    let processedData = self.downscaleImageIfNeeded(data: data, maxDimension: 1024)
                    self.addToMemoryCache(name: name, data: processedData)
                    DispatchQueue.main.async {
                        completion(processedData)
                    }
                    return
                }
            }
            
            // Load from bundle
            if let bundleURL = Bundle.main.url(forResource: name, withExtension: nil),
               let data = try? Data(contentsOf: bundleURL) {
                
                // Downscale and cache
                let processedData = self.downscaleImageIfNeeded(data: data, maxDimension: 1024)
                
                // Store in disk cache
                self.diskCacheQueue.async {
                    self.saveImageToDisk(processedData, name: name)
                }
                
                self.addToMemoryCache(name: name, data: processedData)
                
                DispatchQueue.main.async {
                    completion(processedData)
                }
            } else {
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
    }
    
    // MARK: - Memory Cache Management
    
    #if os(macOS)
    private func getFromMemoryCache(name: String) -> Data? {
        if let image = memoryCache.object(forKey: name as NSString) {
            return image.tiffRepresentation
        }
        return nil
    }
    
    private func addToMemoryCache(name: String, data: Data) {
        guard let image = NSImage(data: data) else { return }
        let imageSize = data.count
        
        // NSCache automatically handles eviction based on totalCostLimit
        memoryCache.setObject(image, forKey: name as NSString, cost: imageSize)
        memoryCacheSize += imageSize
    }
    #else
    private func getFromMemoryCache(name: String) -> Data? {
        if let image = memoryCache.object(forKey: name as NSString) {
            return image.jpegData(compressionQuality: 0.8)
        }
        return nil
    }
    
    private func addToMemoryCache(name: String, data: Data) {
        guard let image = UIImage(data: data) else { return }
        let imageSize = data.count
        
        // NSCache automatically handles eviction based on totalCostLimit
        memoryCache.setObject(image, forKey: name as NSString, cost: imageSize)
        memoryCacheSize += imageSize
    }
    #endif
    
    // MARK: - Image Processing
    
    private func downscaleImageIfNeeded(data: Data, maxDimension: CGFloat) -> Data {
        #if os(macOS)
        guard let image = NSImage(data: data) else { return data }
        let size = image.size
        if size.width <= maxDimension && size.height <= maxDimension {
            return data
        }
        
        let scale = min(maxDimension / size.width, maxDimension / size.height)
        let newSize = NSSize(width: size.width * scale, height: size.height * scale)
        
        let resizedImage = NSImage(size: newSize)
        resizedImage.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: newSize))
        resizedImage.unlockFocus()
        
        return resizedImage.tiffRepresentation ?? data
        #else
        guard let image = UIImage(data: data) else { return data }
        let size = image.size
        if size.width <= maxDimension && size.height <= maxDimension {
            return data
        }
        
        let scale = min(maxDimension / size.width, maxDimension / size.height)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return resizedImage?.jpegData(compressionQuality: 0.8) ?? data
        #endif
    }
    
    // MARK: - Cache Management
    
    private func saveImageToDisk(_ data: Data, name: String) {
        let fileName = "\(name.hash).jpg"
        let filePath = cacheDirectory.appendingPathComponent(fileName)
        
        try? data.write(to: filePath)
    }
    
    func clearDiskCache() {
        diskCacheQueue.async { [weak self] in
            guard let self = self else { return }
            
            do {
                let files = try self.fileManager.contentsOfDirectory(at: self.cacheDirectory, includingPropertiesForKeys: nil)
                for file in files {
                    try self.fileManager.removeItem(at: file)
                }
            } catch {
                print("Error clearing disk cache: \(error)")
            }
        }
    }
    
    func clearAllCache() {
        clearDiskCache()
        clearMemoryCache()
    }
    
    func clearMemoryCache() {
        memoryCache.removeAllObjects()
        memoryCacheSize = 0
    }
    
    deinit {
        #if os(iOS)
        NotificationCenter.default.removeObserver(self)
        #endif
    }
    
    // MARK: - Cache Cleanup
    
    private func cleanUpOldCacheFiles() {
        diskCacheQueue.async { [weak self] in
            guard let self = self else { return }
            
            do {
                let files = try self.fileManager.contentsOfDirectory(at: self.cacheDirectory, includingPropertiesForKeys: [.creationDateKey, .fileSizeKey])
                
                // Sort by creation date (oldest first)
                let sortedFiles = files.sorted { file1, file2 in
                    let date1 = (try? file1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                    let date2 = (try? file2.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                    return date1 < date2
                }
                
                // Calculate total size
                var totalSize: Int64 = 0
                for file in files {
                    let size = (try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                    totalSize += Int64(size)
                }
                
                // Remove old files if cache is too large
                var index = 0
                while totalSize > self.maxDiskCacheSize && index < sortedFiles.count {
                    let file = sortedFiles[index]
                    let size = (try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                    totalSize -= Int64(size)
                    try? self.fileManager.removeItem(at: file)
                    index += 1
                }
                
            } catch {
                print("Error cleaning up cache files: \(error)")
            }
        }
    }
    
    // MARK: - Cache Statistics
    
    func getCacheStatistics() -> Int64 {
        var diskSize: Int64 = 0
        diskCacheQueue.sync {
            do {
                let files = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey])
                for file in files {
                    let size = (try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                    diskSize += Int64(size)
                }
            } catch {
                print("Error calculating disk cache size: \(error)")
            }
        }
        
        return diskSize
    }
}

// MARK: - SwiftUI Image View with Caching

struct CachedImageView: View {
    let imageName: String
    let placeholder: Image
    
    @State private var imageData: Data?
    @State private var isLoading = true
    
    init(imageName: String, placeholder: Image = Image(systemName: "photo")) {
        self.imageName = imageName
        self.placeholder = placeholder
    }
    
    var body: some View {
        Group {
            #if os(macOS)
            if let data = imageData, let nsImage = NSImage(data: data) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else if isLoading {
                placeholder
                    .foregroundColor(.gray)
                    .onAppear {
                        loadImage()
                    }
            } else {
                placeholder
            }
            #else
            if let data = imageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else if isLoading {
                placeholder
                    .foregroundColor(.gray)
                    .onAppear {
                        loadImage()
                    }
            } else {
                placeholder
                    .foregroundColor(.gray)
            }
            #endif
        }
    }
    
    private func loadImage() {
        ImageCacheService.shared.loadImage(named: imageName)
            .sink { loadedData in
                self.imageData = loadedData
                self.isLoading = false
            }
            .store(in: &cancellables)
    }
    
    @State private var cancellables = Set<AnyCancellable>()
}

// MARK: - System Icon Cache (for SF Symbols)

class SystemIconCache {
    static let shared = SystemIconCache()
    
    private let cacheQueue = DispatchQueue(label: "com.calendarnotes.systemicon", attributes: .concurrent)
    
    // Use NSCache for automatic memory pressure handling
    #if os(macOS)
    private let cache = NSCache<NSString, NSImage>()
    #else
    private let cache = NSCache<NSString, UIImage>()
    #endif
    
    private init() {
        cache.totalCostLimit = 10 * 1024 * 1024 // 10MB
        cache.countLimit = 200
        cache.name = "com.calendarnotes.systemicon.cache"
    }
    
    #if os(macOS)
    func getSystemIcon(named name: String, size: CGFloat = 20) -> NSImage? {
        let cacheKey = "\(name)_\(size)" as NSString
        
        return cacheQueue.sync {
            if let cachedIcon = cache.object(forKey: cacheKey) {
                return cachedIcon
            }
            
            let icon = NSImage(systemSymbolName: name, accessibilityDescription: nil)
            
            if let icon = icon {
                cacheQueue.async(flags: .barrier) {
                    self.cache.setObject(icon, forKey: cacheKey)
                }
            }
            
            return icon
        }
    }
    #else
    func getSystemIcon(named name: String, size: CGFloat = 20) -> UIImage? {
        let cacheKey = "\(name)_\(size)" as NSString
        
        return cacheQueue.sync {
            if let cachedIcon = cache.object(forKey: cacheKey) {
                return cachedIcon
            }
            
            let icon = UIImage(systemName: name)
            
            if let icon = icon {
                cacheQueue.async(flags: .barrier) {
                    self.cache.setObject(icon, forKey: cacheKey)
                }
            }
            
            return icon
        }
    }
    #endif
    
    func clearCache() {
        cache.removeAllObjects()
    }
}