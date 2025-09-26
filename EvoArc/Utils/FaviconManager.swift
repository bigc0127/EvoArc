import Foundation
import SwiftUI
import Combine

#if os(iOS)
import UIKit
#else
import AppKit
#endif

final class FaviconManager: ObservableObject {
    // ObservableObject conformance
    let objectWillChange = ObservableObjectPublisher()
    static let shared = FaviconManager()

    private let queue = DispatchQueue(label: "com.evoarc.favicons", qos: .utility)
    private let cache = NSCache<NSString, PlatformImage>()
    @Published private var cacheState: [String: Bool] = [:]  // Track loading state for each URL
    private let fileManager = FileManager.default

    private init() {
        cache.countLimit = 500
        cache.totalCostLimit = 32 * 1024 * 1024 // ~32MB
        try? fileManager.createDirectory(at: diskFolderURL(), withIntermediateDirectories: true)
    }

    // Public API
    func image(for url: URL?, completion: @escaping (PlatformImage?) -> Void) {
        DispatchQueue.main.async { [weak self] in
            self?.objectWillChange.send()
        }
        guard let host = url?.host?.lowercased(), !host.isEmpty else {
            completion(nil)
            return
        }
        // In-memory
        if let img = cache.object(forKey: host as NSString) {
            completion(img)
            return
        }
        // Disk
        if let img = loadFromDisk(host: host) {
            cache.setObject(img, forKey: host as NSString)
            completion(img)
            return
        }
        // Network
        fetch(host: host, pageURL: url) { [weak self] img in
            if let img = img {
                self?.cache.setObject(img, forKey: host as NSString)
                self?.saveToDisk(img: img, host: host)
            }
            completion(img)
        }
    }

    func prefetch(for url: URL?) {
        image(for: url, completion: { _ in })
    }

    // MARK: - Network

    private func fetch(host: String, pageURL: URL?, completion: @escaping (PlatformImage?) -> Void) {
        let https = "https://"

        // Common favicon locations (no 3rd-party services)
        var candidates: [URL] = [
            URL(string: https + host + "/favicon.ico"),
            URL(string: https + host + "/favicon.png"),
            URL(string: https + host + "/favicon-32x32.png"),
            URL(string: https + host + "/favicon-16x16.png"),
            URL(string: https + host + "/apple-touch-icon.png"),
            URL(string: https + host + "/apple-touch-icon-precomposed.png")
        ].compactMap { $0 }

        // If a pageURL path is not root, try that base path too
        if let pageURL, pageURL.host?.lowercased() == host {
            let base = pageURL.deletingLastPathComponent().absoluteString
            if let u = URL(string: base + "favicon.ico") { candidates.insert(u, at: 0) }
        }

        tryNext(candidates: candidates, completion: completion)
    }

    private func tryNext(candidates: [URL], completion: @escaping (PlatformImage?) -> Void) {
        var list = candidates
        guard !list.isEmpty else {
            completion(nil)
            return
        }
        let url = list.removeFirst()
        var req = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 12)
        req.setValue("image/*,*/*;q=0.8", forHTTPHeaderField: "Accept")

        URLSession.shared.dataTask(with: req) { [weak self] data, resp, _ in
            guard
                let self,
                let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode),
                let data = data,
                let img = self.decodeImage(data)
            else {
                self?.tryNext(candidates: list, completion: completion)
                return
            }
            completion(img)
        }.resume()
    }

    // MARK: - Disk

    private func diskFolderURL() -> URL {
        let base = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("Favicons", isDirectory: true)
    }

    private func fileURL(for host: String) -> URL {
        // Sanitize host for filesystem
        let safe = host.replacingOccurrences(of: ":", with: "_")
        return diskFolderURL().appendingPathComponent(safe + ".png")
    }

    private func saveToDisk(img: PlatformImage, host: String) {
        #if os(iOS)
        guard let data = img.pngData() else { return }
        #else
        guard let tiff = img.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let data = rep.representation(using: .png, properties: [:])
        else { return }
        #endif
        try? data.write(to: fileURL(for: host), options: .atomicWrite)
    }

    private func loadFromDisk(host: String) -> PlatformImage? {
        let url = fileURL(for: host)
        guard let data = try? Data(contentsOf: url) else { return nil }
        #if os(iOS)
        return UIImage(data: data)
        #else
        return NSImage(data: data)
        #endif
    }

    private func decodeImage(_ data: Data) -> PlatformImage? {
        // Make sure we're on the right thread
        if !Thread.isMainThread {
            var result: PlatformImage?
            DispatchQueue.main.sync {
                result = self.decodeImage(data)
            }
            return result
        }
        #if os(iOS)
        return UIImage(data: data)
        #else
        return NSImage(data: data)
        #endif
    }
}