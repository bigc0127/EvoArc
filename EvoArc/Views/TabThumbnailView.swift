import SwiftUI
import WebKit
import CryptoKit
import ObjectiveC.runtime
#if os(iOS)
import UIKit
public typealias PlatformImage = UIImage
#else
import AppKit
public typealias PlatformImage = NSImage
#endif

private var NavKey: UInt8 = 0

extension Notification.Name {
    static let snapshotDidUpdate = Notification.Name("SnapshotDidUpdate")
}

private func digest(_ url: URL) -> String {
    SHA256.hash(data: Data(url.absoluteString.utf8))
        .map { String(format: "%02x", $0) }.joined()
}

private func fileURL(for url: URL) -> URL {
    FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent(digest(url) + ".png")
}

private func loadDisk(for url: URL) -> PlatformImage? {
    guard let data = try? Data(contentsOf: fileURL(for: url)) else { return nil }
    #if os(iOS)
    return UIImage(data: data)
    #else
    return NSImage(data: data)
    #endif
}

private func saveDisk(_ img: PlatformImage, for url: URL) {
    #if os(iOS)
    guard let data = img.pngData() else { return }
    #else
    guard let tiff = img.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff), let data = rep.representation(using: .png, properties: [:]) else { return }
    #endif
    try? data.write(to: fileURL(for: url), options: .atomic)
    NotificationCenter.default.post(name: .snapshotDidUpdate, object: url.absoluteString)
}

struct TabThumbnailView: View {
    let tab: Tab
    @State private var image: PlatformImage?
    
    var body: some View {
        ZStack {
            if let img = image {
                #if os(iOS)
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                #else
                Image(nsImage: img)
                    .resizable()
                    .scaledToFill()
                #endif
            } else {
                #if os(iOS)
                Color(UIColor.secondarySystemBackground)
                #else
                Color(NSColor.windowBackgroundColor)
                #endif
                ProgressView()
            }
        }
        .clipped()
        #if os(iOS)
        .background(
            HiddenLoader(urlString: tab.url?.absoluteString ?? "") { self.image = $0 }
                .frame(width: 400, height: 600)
                .opacity(0.001)
        )
        #endif
        .onReceive(NotificationCenter.default.publisher(for: .snapshotDidUpdate)) { note in
            guard let s = note.object as? String,
                  s == tab.url?.absoluteString,
                  let url = tab.url,
                  let fresh = loadDisk(for: url) else { return }
            self.image = fresh
        }
    }
}

#if os(iOS)
private struct HiddenLoader: UIViewRepresentable {
    let urlString: String
    let onSnapshot: (UIImage) -> Void
    
    func makeUIView(context: Context) -> WKWebView {
        let wv = WKWebView()
        Task { await startCapture(on: wv) }
        return wv
    }
    
    func updateUIView(_: WKWebView, context: Context) {}
    
    @MainActor
    private func startCapture(on wv: WKWebView) async {
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        guard let url = URL(string: urlString) else { return }
        
        if let disk = loadDisk(for: url) {
            onSnapshot(disk)
            return
        }
        
        try? await load(url, in: wv)
        try? await Task.sleep(nanoseconds: 250_000_000)
        if let img = await snapshot(from: wv) {
            saveDisk(img, for: url)
            onSnapshot(img)
        }
    }
    
    private func load(_ url: URL, in wv: WKWebView) async throws {
        try await withCheckedThrowingContinuation { c in
            let nav = NavDelegate(c) {
                objc_setAssociatedObject(wv, &NavKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            }
            wv.navigationDelegate = nav
            objc_setAssociatedObject(wv, &NavKey, nav, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            wv.load(URLRequest(url: url))
        }
    }
    
    private func snapshot(from wv: WKWebView) async -> PlatformImage? {
        await withCheckedContinuation { c in
            let cfg = WKSnapshotConfiguration()
            cfg.rect = CGRect(origin: .zero, size: .init(width: 400, height: 600))
            cfg.snapshotWidth = 400
            cfg.afterScreenUpdates = true
            wv.takeSnapshot(with: cfg) { img, _ in c.resume(returning: img) }
        }
    }
    
    private final class NavDelegate: NSObject, WKNavigationDelegate {
        private var cont: CheckedContinuation<Void, Error>?
        private let cleanup: () -> Void
        
        init(_ cont: CheckedContinuation<Void, Error>, _ cleanup: @escaping () -> Void) {
            self.cont = cont
            self.cleanup = cleanup
        }
        
        private func finish(_ err: Error? = nil) {
            if let e = err { cont?.resume(throwing: e) }
            else { cont?.resume() }
            cont = nil
            cleanup()
        }
        
        func webView(_ w: WKWebView, didFinish n: WKNavigation!) { finish() }
        func webView(_ w: WKWebView, didFail n: WKNavigation!, withError e: Error) { finish(e) }
        func webView(_ w: WKWebView, didFailProvisionalNavigation n: WKNavigation!, withError e: Error) { finish(e) }
    }
}
#endif

struct TabThumbnailView_Previews: View {
    let tab: Tab
    @StateObject private var thumbnailManager = ThumbnailManager.shared
    @State private var shouldUpdate = false
    
    var body: some View {
GeometryReader { geo in
            ZStack {
                // Browser indicator in top right
                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: "safari")
                            .font(.system(size: 16, weight: .light))
                            .foregroundColor(.secondary)
                            .padding(8)
                    }
                    Spacer()
                }
                .zIndex(1)
                
                if let thumbnail = thumbnailManager.getThumbnail(for: tab.id) {
                    #if os(iOS)
                    GeometryReader { geometry in
                        Image(uiImage: thumbnail)
                            .resizable()
                            .aspectRatio(16/9, contentMode: .fill)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .clipped()
                    }
                    .frame(width: geo.size.width, height: geo.size.width * (9/16))
                    .cornerRadius(UIScaleMetrics.scaledPadding(8))
                    .overlay(RoundedRectangle(cornerRadius: UIScaleMetrics.scaledPadding(8))
                        .stroke(Color.gray.opacity(0.2), lineWidth: 0.5))
                    #else
                    Image(nsImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geo.size.width, height: geo.size.width * (9/16))
                        .clipped()
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
                        )
                    #endif
                } else {
                    // Safari-style placeholder
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                            .frame(width: geo.size.width - 16, height: (geo.size.width - 16) * 1.33)
                            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
                            )
                        
                        VStack(spacing: 8) {
                            Text(tab.title.isEmpty ? "New Tab" : String(tab.title.prefix(20)))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.clear)
        }
        .id(shouldUpdate) // Force view refresh when shouldUpdate changes
        .onReceive(NotificationCenter.default.publisher(for: .thumbnailDidUpdate)) { notification in
            if let tabID = notification.userInfo?["tabID"] as? String,
               tabID == tab.id {
                shouldUpdate.toggle()
            }
        }
    }
}
