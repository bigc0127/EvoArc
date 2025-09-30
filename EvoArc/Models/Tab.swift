//
//  Tab.swift
//  EvoArc
//
//  Created on 2025-09-04.
//

import Foundation
import Combine
import WebKit

@MainActor
class Tab: ObservableObject, Identifiable {
    let id = UUID().uuidString
    var thumbnailUpdateTimer: Timer?
    @Published var title: String = "New Tab"
    @Published var isLoading: Bool = false
    @Published var canGoBack: Bool = false {
        didSet {
            // Force immediate objectWillChange notification
            if canGoBack != oldValue {
                objectWillChange.send()
            }
        }
    }
    @Published var canGoForward: Bool = false {
        didSet {
            // Force immediate objectWillChange notification
            if canGoForward != oldValue {
                objectWillChange.send()
            }
        }
    }
    @Published var estimatedProgress: Double = 0.0
    @Published var browserEngine: BrowserEngine = .webkit
    @Published var isPinned: Bool = false
    @Published var groupID: UUID? = nil
    @Published var showURLInBar: Bool = false
    @Published var readerModeEnabled: Bool = false
    @Published private(set) var needsInitialLoad: Bool = false
    
    weak var webView: WKWebView?
    
    // Loading timeout mechanism
    private var loadingTimer: Timer?
    private let loadingTimeout: TimeInterval = 30.0 // 30 seconds timeout
    
    // URL handling with private storage
    private var _url: URL?
    var url: URL? {
        get { _url }
        set {
            _url = newValue
            if newValue != nil {
                needsInitialLoad = true
            }
        }
    }
    
    var urlString: String {
        get { url?.absoluteString ?? "" }
        set {
            if let url = validateAndNormalizeURL(newValue) {
                self.url = url
            }
        }
    }
    
init(url: URL? = nil, browserEngine: BrowserEngine? = nil, isPinned: Bool = false, groupID: UUID? = nil) {
        // Store URL for loading but don't show in bar for new tabs or homepage
        if let url = url {
            self._url = url // Use private storage
            // Only hide URL for homepage, show for all other URLs
            self.showURLInBar = url != BrowserSettings.shared.homepageURL
            self.needsInitialLoad = true
        } else {
            self._url = BrowserSettings.shared.homepageURL
            self.showURLInBar = false // Hide URL for new tabs
            self.needsInitialLoad = true
        }
        
        // Use provided engine or default from settings
        self.browserEngine = browserEngine ?? BrowserSettings.shared.browserEngine
        self.isPinned = isPinned
        self.groupID = groupID
        self.title = "New Tab"
    }
    
    func startLoadingTimeout() {
        // Cancel any existing timer
        loadingTimer?.invalidate()
        print("🚀 Starting \(loadingTimeout)s loading timeout for tab: \(title) (\(id))")
        
        // Start a new timer
        loadingTimer = Timer.scheduledTimer(withTimeInterval: loadingTimeout, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                if self?.isLoading == true {
        print("⚠️ Loading timeout reached for tab: \(self?.title ?? "Unknown") (\(self?.id.description ?? "unknown"))")
                    self?.forceStopLoading()
                }
            }
        }
    }
    
    func stopLoadingTimeout() {
        if loadingTimer != nil {
            print("🛑 Stopping loading timeout for tab: \(title) (\(id))")
            loadingTimer?.invalidate()
            loadingTimer = nil
        }
    }
    
    func forceStopLoading() {
        print("🚫 Force stopping loading for tab: \(title) (\(id))")
        isLoading = false
        estimatedProgress = 0.0
        webView?.stopLoading()
        stopLoadingTimeout()
        print("🔄 Forced loading stop completed for tab: \(title)")
    }
    
    func handleInitialLoad() {
        guard needsInitialLoad,
              let url = self.url,
              webView?.url == nil else { return }
        
        webView?.load(URLRequest(url: url))
        needsInitialLoad = false
    }
    
    func validateAndNormalizeURL(_ urlString: String) -> URL? {
        // Handle empty strings
        guard !urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        
        // Try to create URL directly
        if let url = URL(string: urlString)?.standardized {
            if url.scheme != nil {
                return url
            } else {
                // Try adding https:// if no scheme
                if let urlWithScheme = URL(string: "https://" + urlString) {
                    return urlWithScheme
                }
            }
        }
        
        return nil
    }
    
    deinit {
        // Cancel any active timers
        loadingTimer?.invalidate()
        loadingTimer = nil
        thumbnailUpdateTimer?.invalidate()
        thumbnailUpdateTimer = nil
        
        // Clean up on main actor
        Task { @MainActor [weak self] in
            guard let id = self?.id else { return }
            ThumbnailManager.shared.removeThumbnail(for: id)
        }
    }
}
