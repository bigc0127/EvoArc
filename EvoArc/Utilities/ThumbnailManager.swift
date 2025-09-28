import SwiftUI
import WebKit
import Combine

class ThumbnailManager: ObservableObject {
    static let shared = ThumbnailManager()
    
    let objectWillChange = ObservableObjectPublisher()
    
    private var thumbnailCache: [String: PlatformImage] = [:] {
        didSet {
            if Thread.isMainThread {
                objectWillChange.send()
            } else {
                DispatchQueue.main.async { [objectWillChange] in
                    objectWillChange.send()
                }
            }
        }
    }
    
    private let queue = DispatchQueue(label: "com.evoarc.thumbnailmanager")
    // Safari-optimized thumbnail size - matches Safari's aspect ratio and quality
    private let thumbnailSize = CGSize(width: 1920, height: 1080) // 16:9 aspect ratio for tab cards
    
    func captureThumbnail(for webView: WKWebView, tab: Tab) {
        // Ensure we're on main thread for UI operations
        if !Thread.isMainThread {
            DispatchQueue.main.async {
                self.captureThumbnail(for: webView, tab: tab)
            }
            return
        }
        
        // Skip if webView is hidden or has no size
        guard webView.frame.size != .zero else { return }
        
        // Wait for content to load before capturing
        guard !webView.isLoading else {
            // Retry after a short delay if still loading
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.captureThumbnail(for: webView, tab: tab)
            }
            return
        }
        
        // Create configuration for snapshot - capture full viewport
        let config = WKSnapshotConfiguration()
        config.rect = CGRect(origin: .zero, size: webView.bounds.size)
        config.afterScreenUpdates = true
        
        // Take snapshot
        webView.takeSnapshot(with: config) { [weak self] image, error in
            guard let image = image else {
                if let error = error {
                    print("Thumbnail capture failed: \(error.localizedDescription)")
                }
                return
            }
            
            // Process image to match Safari's thumbnail appearance
            let processedImage = self?.processImageForThumbnail(image)
            
            self?.queue.async {
                // Store in cache
                if let processedImage = processedImage {
                    self?.thumbnailCache[tab.id] = processedImage
                }
                
                // Notify UI
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .thumbnailDidUpdate, object: nil, userInfo: ["tabID": tab.id])
                }
            }
        }
    }
    
    private func processImageForThumbnail(_ image: PlatformImage) -> PlatformImage? {
        #if os(iOS)
        // Create a properly sized thumbnail with Safari's aspect ratio
        let targetSize = thumbnailSize
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        
        return renderer.image { context in
            // Fill with white background (like Safari does for web content)
            UIColor.systemBackground.setFill()
            context.fill(CGRect(origin: .zero, size: targetSize))
            
            // Calculate scaling to fill the target size while maintaining aspect ratio
            let imageAspectRatio = image.size.width / image.size.height
            let targetAspectRatio = targetSize.width / targetSize.height
            
            var drawRect: CGRect
            
            if imageAspectRatio > targetAspectRatio {
                // Image is wider - scale to fit height
                let scaledWidth = targetSize.height * imageAspectRatio
                drawRect = CGRect(
                    x: (targetSize.width - scaledWidth) / 2,
                    y: 0,
                    width: scaledWidth,
                    height: targetSize.height
                )
            } else {
                // Image is taller - scale to fit width
                let scaledHeight = targetSize.width / imageAspectRatio
                drawRect = CGRect(
                    x: 0,
                    y: 0,
                    width: targetSize.width,
                    height: scaledHeight
                )
            }
            
            image.draw(in: drawRect)
        }
        #else
        // macOS implementation
        let targetSize = thumbnailSize
        let newImage = NSImage(size: targetSize)
        
        newImage.lockFocus()
        defer { newImage.unlockFocus() }
        
        // Fill with background color
        NSColor.controlBackgroundColor.setFill()
        NSRect(origin: .zero, size: targetSize).fill()
        
        // Calculate scaling
        let imageAspectRatio = image.size.width / image.size.height
        let targetAspectRatio = targetSize.width / targetSize.height
        
        var drawRect: NSRect
        
        if imageAspectRatio > targetAspectRatio {
            let scaledWidth = targetSize.height * imageAspectRatio
            drawRect = NSRect(
                x: (targetSize.width - scaledWidth) / 2,
                y: 0,
                width: scaledWidth,
                height: targetSize.height
            )
        } else {
            let scaledHeight = targetSize.width / imageAspectRatio
            drawRect = NSRect(
                x: 0,
                y: 0,
                width: targetSize.width,
                height: scaledHeight
            )
        }
        
        image.draw(in: drawRect)
        
        return newImage
        #endif
    }
    
    func getThumbnail(for tabID: String) -> PlatformImage? {
        thumbnailCache[tabID]
    }
    
    func removeThumbnail(for tabID: String) {
        queue.async { [weak self] in
            self?.thumbnailCache.removeValue(forKey: tabID)
        }
    }
    
    func clearCache() {
        queue.async { [weak self] in
            self?.thumbnailCache.removeAll()
        }
    }
    
    // Enhanced cache management for better memory usage
    func cleanupOldThumbnails(keepingTabs activeTabIDs: Set<String>) {
        queue.async { [weak self] in
            guard let self = self else { return }
            let keysToRemove = self.thumbnailCache.keys.filter { !activeTabIDs.contains($0) }
            keysToRemove.forEach { self.thumbnailCache.removeValue(forKey: $0) }
        }
    }
}

// Notification name for thumbnail updates
extension Notification.Name {
    static let thumbnailDidUpdate = Notification.Name("thumbnailDidUpdate")
}

// Remove title extension since it's already defined in Tab class

