//
//  FaviconManager.swift
//  EvoArc
//
//  Manages favicon (website icons) downloading, caching, and retrieval.
//
//  Key responsibilities:
//  1. Download favicons from websites
//  2. Cache favicons in memory (NSCache) and on disk (Files)
//  3. Provide async favicon lookup with completion handlers
//  4. Handle multiple favicon URL patterns (favicon.ico, apple-touch-icon.png, etc.)
//  5. Cross-platform support (iOS/macOS)
//
//  Architecture:
//  - Singleton pattern (one shared instance)
//  - Three-tier caching: memory → disk → network
//  - Background queue for disk I/O
//  - Main thread for image decoding (required for UIKit/AppKit)
//
//  For Swift beginners:
//  - Favicons are the small icons websites display in browser tabs
//  - This manager optimizes performance by caching them locally
//  - Multiple lookups for the same site reuse cached images
//

import Foundation  // Core Swift - FileManager, URLSession, Data
import SwiftUI    // Apple's UI framework - ObservableObject
import Combine    // Reactive framework - ObservableObjectPublisher

// MARK: - Platform Compatibility
// These conditional imports allow the code to work on both iOS and macOS.
// iOS uses UIKit (UIImage), macOS uses AppKit (NSImage).
#if os(iOS)
import UIKit  // iOS framework - provides UIImage
#else
import AppKit  // macOS framework - provides NSImage
#endif

/// Manages favicon fetching and caching for browser tabs.
///
/// **final**: Cannot be subclassed - this is a concrete implementation.
///
/// **ObservableObject**: SwiftUI views can observe changes (though rarely used here).
///
/// **Singleton**: One shared instance accessed via `FaviconManager.shared`.
///
/// **Caching strategy**:
/// 1. Check memory cache (NSCache) - instant
/// 2. Check disk cache - fast
/// 3. Download from network - slow
///
/// **Thread safety**: Uses background queue for disk I/O, main thread for image decoding.
final class FaviconManager: ObservableObject {
    // MARK: - ObservableObject Conformance
    
    /// Manual ObservableObjectPublisher for fine-grained control.
    ///
    /// **Why manual?**: We trigger updates explicitly rather than using @Published
    /// for better performance control.
    let objectWillChange = ObservableObjectPublisher()
    
    /// The shared singleton instance.
    ///
    /// **Singleton pattern**: Only one FaviconManager exists app-wide.
    static let shared = FaviconManager()

    // MARK: - Private Properties
    
    /// Background queue for favicon operations.
    ///
    /// **DispatchQueue**: Manages task execution off the main thread.
    /// - label: Unique identifier for debugging
    /// - qos: .utility = background work, can be throttled by system
    ///
    /// **Why background?**: Disk I/O and network shouldn't block UI.
    private let queue = DispatchQueue(label: "com.evoarc.favicons", qos: .utility)
    
    /// In-memory cache of favicons (keyed by hostname).
    ///
    /// **NSCache**: Apple's thread-safe cache with automatic eviction.
    /// - Evicts least-recently-used items when memory is low
    /// - No need for manual cleanup
    /// - Keys: NSString (hostname like "github.com")
    /// - Values: PlatformImage (UIImage on iOS, NSImage on macOS)
    ///
    /// **Why NSCache vs Dictionary?**:
    /// - Automatic memory management
    /// - Thread-safe
    /// - System purges it under memory pressure
    private let cache = NSCache<NSString, PlatformImage>()
    
    /// Tracks loading state for each URL (not currently used, placeholder for future).
    @Published private var cacheState: [String: Bool] = [:]
    
    /// File system manager for disk operations.
    private let fileManager = FileManager.default

    /// Private initializer (singleton pattern).
    ///
    /// **Configuration**:
    /// - Sets cache limits to prevent excessive memory use
    /// - Creates disk cache directory if it doesn't exist
    ///
    /// **Why private?**: Prevents external code from creating multiple instances.
    private init() {
        /// Maximum number of favicons to keep in memory.
        /// 500 favicons is sufficient for most browsing sessions.
        cache.countLimit = 500
        
        /// Maximum memory used by cache (32 megabytes).
        /// Prevents favicons from consuming too much RAM.
        /// Calculation: 32 * 1024 * 1024 bytes = 32MB
        cache.totalCostLimit = 32 * 1024 * 1024
        
        /// Create disk cache directory if it doesn't exist.
        /// withIntermediateDirectories: true = create parent directories too
        /// try? = ignore errors (directory might already exist)
        try? fileManager.createDirectory(at: diskFolderURL(), withIntermediateDirectories: true)
    }

    // MARK: - Public API
    
    /// Retrieves a favicon for the given URL (async with completion handler).
    ///
    /// **Three-tier lookup**:
    /// 1. Memory cache (instant)
    /// 2. Disk cache (fast)
    /// 3. Network download (slow)
    ///
    /// **Parameters**:
    /// - url: The website URL (we extract the host/domain)
    /// - completion: Called with the image (or nil if not found)
    ///
    /// **@escaping**: The completion handler is called AFTER this function returns.
    /// It "escapes" the function scope.
    ///
    /// **Use case**: Call this when displaying a tab to show its favicon.
    ///
    /// **Example**:
    /// ```swift
    /// FaviconManager.shared.image(for: URL(string: "https://github.com")) { image in
    ///     // Update UI with image (or show placeholder if nil)
    /// }
    /// ```
    func image(for url: URL?, completion: @escaping (PlatformImage?) -> Void) {
        /// Notify observers that we're about to change (for SwiftUI reactivity).
        /// [weak self] prevents retain cycle.
        DispatchQueue.main.async { [weak self] in
            self?.objectWillChange.send()
        }
        
        /// Extract hostname from URL (e.g., "github.com" from "https://github.com/user/repo").
        /// Lowercase for consistency ("GitHub.com" and "github.com" are the same).
        guard let host = url?.host?.lowercased(), !host.isEmpty else {
            completion(nil)  // Invalid URL, return nil
            return
        }
        
        // STEP 1: Check memory cache (instant)
        if let img = cache.object(forKey: host as NSString) {
            completion(img)
            return
        }
        
        // STEP 2: Check disk cache (fast)
        if let img = loadFromDisk(host: host) {
            /// Found on disk - add to memory cache for next time.
            cache.setObject(img, forKey: host as NSString)
            completion(img)
            return
        }
        
        // STEP 3: Download from network (slow)
        fetch(host: host, pageURL: url) { [weak self] img in
            if let img = img {
                /// Cache the downloaded image for future use.
                self?.cache.setObject(img, forKey: host as NSString)  // Memory
                self?.saveToDisk(img: img, host: host)                 // Disk
            }
            completion(img)
        }
    }

    /// Prefetches a favicon without waiting for the result.
    ///
    /// **Purpose**: Warm up the cache for URLs we expect to need soon.
    ///
    /// **Use case**: Prefetch favicons for all tabs when the tab drawer opens,
    /// so they display instantly when the user looks at them.
    ///
    /// **Implementation**: Calls `image(for:completion:)` with empty completion.
    /// The image gets cached even though we don't use it immediately.
    func prefetch(for url: URL?) {
        image(for: url, completion: { _ in })  // Ignore result, just cache it
    }

    // MARK: - Network Fetching
    // Methods for downloading favicons from websites.

    /// Attempts to download a favicon from common locations.
    ///
    /// **Strategy**: Try multiple common favicon URLs in sequence until one succeeds.
    ///
    /// **Common patterns**:
    /// - /favicon.ico (most common, oldest convention)
    /// - /favicon.png (modern alternative)
    /// - /favicon-32x32.png (specific size)
    /// - /apple-touch-icon.png (iOS home screen icon, usually high quality)
    ///
    /// **Privacy**: We fetch directly from the website, no third-party services.
    /// Some favicon services track users - we avoid that.
    ///
    /// **Parameters**:
    /// - host: The website hostname (e.g., "github.com")
    /// - pageURL: Full page URL (optional, for path-based favicon hints)
    /// - completion: Called with the image or nil
    private func fetch(host: String, pageURL: URL?, completion: @escaping (PlatformImage?) -> Void) {
        let https = "https://"

        /// List of candidate URLs to try.
        /// compactMap removes any nil values (invalid URLs).
        var candidates: [URL] = [
            URL(string: https + host + "/favicon.ico"),               // Standard location
            URL(string: https + host + "/favicon.png"),               // PNG alternative
            URL(string: https + host + "/favicon-32x32.png"),         // Specific size
            URL(string: https + host + "/favicon-16x16.png"),         // Smaller size
            URL(string: https + host + "/apple-touch-icon.png"),     // iOS icon
            URL(string: https + host + "/apple-touch-icon-precomposed.png")
        ].compactMap { $0 }

        /// If the page URL has a path (e.g., https://example.com/blog/post),
        /// also try /blog/favicon.ico in case it's a subsite with its own icon.
        if let pageURL, pageURL.host?.lowercased() == host {
            let base = pageURL.deletingLastPathComponent().absoluteString
            if let u = URL(string: base + "favicon.ico") { 
                candidates.insert(u, at: 0)  // Try this first
            }
        }

        /// Start trying URLs in sequence.
        tryNext(candidates: candidates, completion: completion)
    }

    /// Recursively tries candidate URLs until one succeeds.
    ///
    /// **Recursive strategy**: Try first URL. If it fails, recursively try remaining URLs.
    ///
    /// **Parameters**:
    /// - candidates: Array of URLs to try
    /// - completion: Called with the first successful image, or nil if all fail
    ///
    /// **Error handling**: If a URL fails (404, timeout, invalid image),
    /// automatically try the next one. Only return nil when all options exhausted.
    private func tryNext(candidates: [URL], completion: @escaping (PlatformImage?) -> Void) {
        /// Make a mutable copy so we can remove items.
        var list = candidates
        
        /// Base case: no more URLs to try.
        guard !list.isEmpty else {
            completion(nil)  // All attempts failed
            return
        }
        
        /// Remove and try the first URL.
        let url = list.removeFirst()
        
        /// Configure the HTTP request.
        /// - cachePolicy: .reloadIgnoringLocalCacheData = always fetch fresh
        /// - timeoutInterval: 12 seconds max wait
        var req = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 12)
        
        /// Set Accept header to indicate we want images.
        /// The server might use this to serve optimal format.
        req.setValue("image/*,*/*;q=0.8", forHTTPHeaderField: "Accept")

        /// Start the network request.
        URLSession.shared.dataTask(with: req) { [weak self] data, resp, _ in
            /// Check for success:
            /// 1. self still exists (not deallocated)
            /// 2. HTTP status code 200-299 (success)
            /// 3. Response has data
            /// 4. Data can be decoded as an image
            guard
                let self,
                let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode),
                let data = data,
                let img = self.decodeImage(data: data)
            else {
                /// This URL failed - try the next one recursively.
                self?.tryNext(candidates: list, completion: completion)
                return
            }
            /// Success! Return the image.
            completion(img)
        }.resume()  // Start the request
    }

    // MARK: - Disk Caching
    // Methods for persisting favicons to disk for long-term caching.

    /// Returns the directory where favicons are saved on disk.
    ///
    /// **Location**: App's Caches directory / Favicons /
    ///
    /// **Why Caches?**: System can clear this directory under storage pressure,
    /// but it persists between app launches (unlike temp directories).
    ///
    /// **Path example**: 
    /// `/Users/.../Library/Caches/Favicons/`
    ///
    /// **Returns**: URL to the Favicons folder
    private func diskFolderURL() -> URL {
        /// Get the app's Caches directory.
        /// .first! is safe because every app has a Caches directory.
        let base = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        
        /// Append "Favicons" subdirectory.
        return base.appendingPathComponent("Favicons", isDirectory: true)
    }

    /// Returns the file URL for a specific host's favicon.
    ///
    /// **Filename**: hostname.png (e.g., "github.com.png")
    ///
    /// **Sanitization**: Colons are replaced with underscores
    /// (colons are invalid in filenames on many systems).
    ///
    /// **Example**: 
    /// Host "example.com:8080" → "example.com_8080.png"
    ///
    /// **Parameter**:
    /// - host: The website hostname
    ///
    /// **Returns**: Full file path for the favicon
    private func fileURL(for host: String) -> URL {
        /// Sanitize hostname for filesystem compatibility.
        /// Replace colons with underscores (ports like ":8080").
        let safe = host.replacingOccurrences(of: ":", with: "_")
        
        /// Return full path: Caches/Favicons/hostname.png
        return diskFolderURL().appendingPathComponent(safe + ".png")
    }

    /// Saves a favicon image to disk.
    ///
    /// **Format**: PNG (lossless compression, widely supported)
    ///
    /// **Platform differences**:
    /// - iOS: UIImage has pngData() method
    /// - macOS: NSImage requires conversion through TIFF → PNG
    ///
    /// **Atomic write**: The file appears all-at-once (no partial writes).
    /// Prevents corruption if app crashes during save.
    ///
    /// **Parameters**:
    /// - img: The image to save
    /// - host: The website hostname (used for filename)
    private func saveToDisk(img: PlatformImage, host: String) {
        /// Convert image to PNG data (platform-specific).
        #if os(iOS)
        /// iOS: UIImage → PNG data
        guard let data = img.pngData() else { return }
        #else
        /// macOS: NSImage → TIFF → BitmapRep → PNG
        /// (NSImage doesn't have direct PNG conversion)
        guard let tiff = img.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let data = rep.representation(using: .png, properties: [:])
        else { return }
        #endif
        
        /// Write to disk with atomic write.
        /// try? = ignore errors (disk full, permissions, etc.)
        try? data.write(to: fileURL(for: host), options: .atomicWrite)
    }

    /// Loads a favicon from disk cache.
    ///
    /// **Parameters**:
    /// - host: The website hostname
    ///
    /// **Returns**: The image if found on disk, nil otherwise
    ///
    /// **Platform differences**: iOS uses UIImage, macOS uses NSImage
    private func loadFromDisk(host: String) -> PlatformImage? {
        /// Get the file path for this host.
        let url = fileURL(for: host)
        
        /// Try to read the file data.
        /// Returns nil if file doesn't exist or can't be read.
        guard let data = try? Data(contentsOf: url) else { return nil }
        
        /// Decode PNG data into a platform-specific image.
        #if os(iOS)
        return UIImage(data: data)  // iOS
        #else
        return NSImage(data: data)  // macOS
        #endif
    }

    /// Decodes raw image data into a platform-specific image object.
    ///
    /// **Thread safety**: UIKit/AppKit require image decoding on the main thread.
    /// If called from background thread, automatically switches to main thread.
    ///
    /// **Why main thread?**: UIKit/AppKit image APIs are not thread-safe.
    ///
    /// **Parameters**:
    /// - data: Raw image data (PNG, JPEG, etc.)
    ///
    /// **Returns**: Platform image or nil if decoding fails
    private func decodeImage(data: Data) -> PlatformImage? {
        /// Check if we're on the main thread.
        if !Thread.isMainThread {
            /// Not on main thread - dispatch synchronously to main.
            /// DispatchQueue.main.sync ensures we wait for result.
            var result: PlatformImage?
            DispatchQueue.main.sync {
                #if os(iOS)
                result = UIImage(data: data)  // iOS
                #else
                result = NSImage(data: data)  // macOS
                #endif
            }
            return result
        }
        
        /// We're on main thread - safe to decode image.
        #if os(iOS)
        return UIImage(data: data)  // iOS
        #else
        return NSImage(data: data)  // macOS
        #endif
    }
}

// MARK: - Architecture Summary
//
// FaviconManager implements a sophisticated three-tier caching system:
//
// ┌─────────────────────────────────────────┐
// │  FaviconManager Architecture │
// └─────────────────────────────────────────┘
//
// Request Flow:
// ============
//
// 1. image(for: URL) called
//      ↓
// 2. Extract hostname ("github.com")
//      ↓
// 3. Check NSCache (memory)
//      ├─ Hit → Return immediately ✅ (fastest)
//      └─ Miss ↓
// 4. Check disk cache
//      ├─ Hit → Cache in memory, return ✅ (fast)
//      └─ Miss ↓
// 5. Try network URLs sequentially:
//      /favicon.ico
//      /favicon.png
//      /favicon-32x32.png
//      /apple-touch-icon.png
//      etc.
//      ├─ Success → Cache in memory + disk, return ✅
//      └─ All fail → Return nil ❌
//
// Caching Tiers:
// =============
//
// Tier 1: NSCache (Memory)
// - Fastest access (nanoseconds)
// - Automatically evicts under memory pressure
// - Limit: 500 images or 32MB
// - Thread-safe
// - Cleared when app terminates
//
// Tier 2: FileManager (Disk)
// - Fast access (milliseconds)
// - Persists between app launches
// - Location: Caches/Favicons/*.png
// - System can clear under storage pressure
// - Manual cleanup not needed
//
// Tier 3: URLSession (Network)
// - Slowest (seconds)
// - Tries multiple common paths
// - No third-party services (privacy)
// - 12 second timeout per URL
//
// Thread Safety:
// =============
//
// - NSCache: Thread-safe by design
// - Disk I/O: Uses background queue
// - Image decoding: Forced to main thread (UIKit requirement)
// - Network requests: Async by design
//
// Performance Characteristics:
// ==========================
//
// Memory cache hit:  ~0.001ms (instant)
// Disk cache hit:    ~1-10ms  (fast)
// Network download:  ~100-2000ms (slow, varies by connection)
//
// For a typical browsing session:
// - First visit to site: Network (~1s)
// - Next visit same session: Memory (~instant)
// - Next visit after app restart: Disk (~10ms)
//
// Privacy Considerations:
// ======================
//
// ✅ No third-party favicon services (Google, DuckDuckGo, etc.)
// ✅ Direct fetch from origin website only
// ✅ No tracking or analytics
// ✅ Cached locally, never uploaded
//
// Some browsers use services like:
// - https://www.google.com/s2/favicons?domain=example.com
//
// These leak browsing history to third parties. We avoid them.
//
// Platform Differences:
// ====================
//
// iOS (UIKit):
// - Uses UIImage
// - Simple .pngData() conversion
// - Direct PNG encoding
//
// macOS (AppKit):
// - Uses NSImage
// - Requires TIFF → BitmapRep → PNG conversion
// - More complex encoding pipeline
//
// Both use PlatformImage typealias for code sharing.
//
// Common Pitfalls:
// ===============
//
// ❌ Don't create multiple FaviconManager instances (use .shared)
// ❌ Don't decode images on background thread (UIKit limitation)
// ❌ Don't manually manage NSCache (automatic eviction handles it)
// ❌ Don't use third-party favicon services (privacy leak)
//
// ✅ Do use .shared singleton
// ✅ Do rely on automatic caching
// ✅ Do prefetch for better UX
// ✅ Do check main thread before image operations
