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
    
    private let maxDiskCacheSize: Int64 = 100 * 1024 * 1024 // 100MB
    
    private init() {
        // Setup disk cache directory
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        cacheDirectory = documentsPath.appendingPathComponent("ImageCache")
        
        // Create cache directory if it doesn't exist
        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        }
        
        // Clean up old cache files on startup
        cleanUpOldCacheFiles()
    }
    
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
        let _ = name as NSString
        
        // Check disk cache
        diskCacheQueue.async { [weak self] in
            let diskPath = self?.cacheDirectory.appendingPathComponent("\(name.hash).jpg")
            
            if let diskPath = diskPath, self?.fileManager.fileExists(atPath: diskPath.path) == true {
                if let data = try? Data(contentsOf: diskPath) {
                    DispatchQueue.main.async {
                        completion(data)
                    }
                    return
                }
            }
            
            // Load from bundle
            if let bundleURL = Bundle.main.url(forResource: name, withExtension: nil),
               let data = try? Data(contentsOf: bundleURL) {
                
                // Store in disk cache
                self?.diskCacheQueue.async {
                    self?.saveImageToDisk(data, name: name)
                }
                
                DispatchQueue.main.async {
                    completion(data)
                }
            } else {
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
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
    #if os(macOS)
    private var cache: [String: NSImage] = [:]
    #else
    private var cache: [String: UIImage] = [:]
    #endif
    
    private init() {}
    
    #if os(macOS)
    func getSystemIcon(named name: String, size: CGFloat = 20) -> NSImage? {
        let cacheKey = "\(name)_\(size)"
        
        return cacheQueue.sync {
            if let cachedIcon = cache[cacheKey] {
                return cachedIcon
            }
            
            let icon = NSImage(systemSymbolName: name, accessibilityDescription: nil)
            
            if let icon = icon {
                cacheQueue.async(flags: .barrier) {
                    self.cache[cacheKey] = icon
                }
            }
            
            return icon
        }
    }
    #else
    func getSystemIcon(named name: String, size: CGFloat = 20) -> UIImage? {
        let cacheKey = "\(name)_\(size)"
        
        return cacheQueue.sync {
            if let cachedIcon = cache[cacheKey] {
                return cachedIcon
            }
            
            let icon = UIImage(systemName: name)
            
            if let icon = icon {
                cacheQueue.async(flags: .barrier) {
                    self.cache[cacheKey] = icon
                }
            }
            
            return icon
        }
    }
    #endif
    
    func clearCache() {
        cacheQueue.async(flags: .barrier) {
            self.cache.removeAll()
        }
    }
}