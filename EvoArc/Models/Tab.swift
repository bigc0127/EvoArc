//
//  Tab.swift
//  EvoArc
//
//  Created on 2025-09-04.
//

import Foundation
import Combine
import WebKit

class Tab: ObservableObject, Identifiable {
    let id = UUID()
    @Published var title: String = "New Tab"
    @Published var url: URL?
    @Published var isLoading: Bool = false
    @Published var canGoBack: Bool = false
    @Published var canGoForward: Bool = false
    @Published var estimatedProgress: Double = 0.0
    @Published var browserEngine: BrowserEngine = .webkit
    @Published var isPinned: Bool = false
    @Published var groupID: UUID? = nil
    @Published var showURLInBar: Bool = false
    
    weak var webView: WKWebView?
    
    // Loading timeout mechanism
    private var loadingTimer: Timer?
    private let loadingTimeout: TimeInterval = 30.0 // 30 seconds timeout
    
    init(url: URL? = nil, browserEngine: BrowserEngine? = nil, isPinned: Bool = false, groupID: UUID? = nil) {
        // Store URL for loading but don't show in bar for new tabs or homepage
        if let url = url {
            self.url = url
            // Only hide URL for homepage, show for all other URLs
            self.showURLInBar = url != BrowserSettings.shared.homepageURL
        } else {
            self.url = BrowserSettings.shared.homepageURL
            self.showURLInBar = false // Hide URL for new tabs
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
    
    deinit {
        stopLoadingTimeout()
    }
}
