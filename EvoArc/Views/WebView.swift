//
//  WebView.swift
//  EvoArc
//
//  Created on 2025-09-04.
//

/**
 * # WebView
 * 
 * A basic SwiftUI wrapper around WKWebView for iOS, providing essential web browsing
 * functionality without scroll-based URL bar management. This is the simpler alternative
 * to ScrollDetectingWebView when auto-hide features aren't needed.
 * 
 * ## Architecture Overview
 * 
 * ### For New Swift Developers:
 * - **UIViewRepresentable**: Protocol that allows SwiftUI to wrap UIKit components
 * - **WKWebView**: Apple's modern web rendering engine (WebKit)
 * - **Coordinator**: Design pattern for handling delegate callbacks from UIKit
 * - **KVO (Key-Value Observing)**: Automatic notification when object properties change
 * 
 * ### Component Responsibilities:
 * 1. **WebView**: The SwiftUI wrapper that manages the WKWebView lifecycle
 * 2. **Coordinator**: Handles WKWebView delegate methods and property observations
 * 3. **Tab Integration**: Syncs web view state with EvoArc's tab management system
 * 
 * ## Key Features:
 * - **Standard WebKit**: Uses system DNS resolution (no custom DNS providers)
 * - **User Agent Management**: Automatically applies desktop/mobile user agents
 * - **Navigation Handling**: Processes URL submissions and tab switching
 * - **Loading State Tracking**: Monitors progress and updates tab state
 * - **Gesture Support**: Enables swipe navigation between pages
 * 
 * ## WebKit Configuration:
 * - JavaScript enabled for modern web functionality
 * - Standard website data store for cookies and cache
 * - No custom proxy or DNS-over-HTTPS configuration
 * - Platform-appropriate media playback settings
 * 
 * ## Usage:
 * ```swift
 * WebView(
 *     tab: currentTab,
 *     urlString: $urlString,
 *     shouldNavigate: $shouldNavigate,
 *     onNavigate: { url in /* handle navigation */ }
 * )
 * ```
 */

import SwiftUI
import WebKit

#if os(iOS)
import UIKit

/// iOS-specific WebView implementation using UIViewRepresentable
/// This struct bridges SwiftUI with UIKit's WKWebView component
struct WebView: UIViewRepresentable {
    /// The tab object this web view is displaying content for
    /// @ObservedObject automatically updates the view when tab properties change
    @ObservedObject var tab: Tab
    
    /// Two-way binding to the URL bar text field in the parent view
    /// Changes to this trigger navigation, and navigation updates this value
    @Binding var urlString: String
    
    /// Flag that triggers navigation when set to true by URL bar submission
    /// Reset to false after navigation is processed
    @Binding var shouldNavigate: Bool
    
    /// Callback function executed when navigation to a new URL occurs
    /// Used by parent views to update their state and UI
    let onNavigate: (URL) -> Void
    
    /// Reference to global browser settings for user agent and preferences
    /// @StateObject ensures this view owns the settings instance
    @StateObject private var settings = BrowserSettings.shared
    
    /// Creates the Coordinator that handles WKWebView delegate callbacks
    /// The Coordinator pattern is SwiftUI's way of handling UIKit delegate methods
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    /// Creates and configures a new WKWebView instance for UIKit integration
    /// This method is called by SwiftUI when the view first appears
    /// - Parameter context: SwiftUI context containing the coordinator and other data
    /// - Returns: A fully configured WKWebView ready for web browsing
    func makeUIView(context: Context) -> WKWebView {
        // Standard WebKit configuration
        let configuration = WKWebViewConfiguration()
        let preferences = WKWebpagePreferences()
        
        // Check if JavaScript should be blocked for this site
        let jsEnabled = tab.url.map { !JavaScriptBlockingManager.shared.isJavaScriptBlocked(for: $0) } ?? true
        preferences.allowsContentJavaScript = jsEnabled
        
        configuration.defaultWebpagePreferences = preferences
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = jsEnabled
        #if os(iOS)
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.allowsAirPlayForMediaPlayback = true
        configuration.allowsPictureInPictureMediaPlayback = true
        #endif
        
        // Create the WebView with zero frame (SwiftUI will handle sizing)
        let webView = WKWebView(frame: .zero, configuration: configuration)
        
        // Configure for optimal mobile site display
        webView.scrollView.contentInsetAdjustmentBehavior = .scrollableAxes
        webView.scrollView.automaticallyAdjustsScrollIndicatorInsets = true
        webView.scrollView.contentInset = .zero
        
        // Configure viewport
        configuration.defaultWebpagePreferences.preferredContentMode = .mobile
        
        // Enable navigation gestures
        webView.allowsBackForwardNavigationGestures = true
        
        // Configure for optimal mobile display
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        
        // Apply content blocking (AdBlock)
        AdBlockManager.shared.applyContentBlocking(to: webView)
        
        // Set up delegate pattern - coordinator handles all WebKit callbacks
        webView.navigationDelegate = context.coordinator  // Handle navigation events
        webView.uiDelegate = context.coordinator          // Handle UI events (alerts, etc.)
        
        // Enable swipe gestures for back/forward navigation (iOS standard behavior)
        webView.allowsBackForwardNavigationGestures = true
        
        // Apply user agent string based on user's desktop/mobile preference
        // This determines whether websites show mobile or desktop versions
        webView.customUserAgent = BrowserSettings.shared.userAgentString
        
        // Two-finger swipe down to toggle Reader Mode
        let readerSwipe = UISwipeGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleReaderSwipe(_:)))
        readerSwipe.direction = .down
        readerSwipe.numberOfTouchesRequired = 2
        webView.addGestureRecognizer(readerSwipe)
        
        // Establish bidirectional reference between tab and web view
        // This allows the tab to control the web view and vice versa
        DispatchQueue.main.async {
            tab.webView = webView
        }
        
        // Give coordinator access to web view for delegate method implementation
        context.coordinator.webView = webView
        
        // Set up Key-Value Observing (KVO) for automatic UI updates
        // These observers automatically update the tab state when WebView properties change
        webView.addObserver(context.coordinator, forKeyPath: #keyPath(WKWebView.isLoading), options: .new, context: nil)
        webView.addObserver(context.coordinator, forKeyPath: #keyPath(WKWebView.estimatedProgress), options: .new, context: nil)
        webView.addObserver(context.coordinator, forKeyPath: #keyPath(WKWebView.title), options: .new, context: nil)
        webView.addObserver(context.coordinator, forKeyPath: #keyPath(WKWebView.canGoBack), options: .new, context: nil)
        webView.addObserver(context.coordinator, forKeyPath: #keyPath(WKWebView.canGoForward), options: .new, context: nil)
        
        // Load the tab's current URL if one exists (handles tab restoration)
        if let url = tab.url {
            webView.load(URLRequest(url: url))
        }
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        // Update user agent if settings changed
        if webView.customUserAgent != settings.userAgentString {
            webView.customUserAgent = settings.userAgentString
        }
        
        // Handle navigation when user submits URL
        if shouldNavigate {
            if let url = formatURL(from: urlString) {
                // Create a new URLRequest with caching policy
                var request = URLRequest(url: url)
                request.cachePolicy = .reloadIgnoringLocalCacheData
                webView.load(request)
                
                // Reset the flag after navigation - must be done asynchronously
                Task { @MainActor in
                    shouldNavigate = false
                }
            }
        }
        
        // Only sync tab URL to WebView if the WebView has no URL loaded
        if webView.url == nil, let tabURL = tab.url {
            var request = URLRequest(url: tabURL)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            webView.load(request)
        }
    }
    private func formatURL(from string: String) -> URL? {
        // Check if it's already a valid URL
        if let url = URL(string: string), url.scheme != nil {
            return url
        }
        
        // Check if it looks like a domain
        if string.contains(".") && !string.contains(" ") {
            if let url = URL(string: "https://\(string)") {
                return url
            }
        }
        
        // Otherwise, treat it as a search query using the selected engine
        return BrowserSettings.shared.searchURL(for: string)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var parent: WebView
        weak var webView: WKWebView?
        
        init(_ parent: WebView) {
            self.parent = parent
        }
        
        override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
            guard let webView = object as? WKWebView else { return }
            
            // Use async dispatch to avoid "Publishing changes from within view updates"
            DispatchQueue.main.async {
                switch keyPath {
                case #keyPath(WKWebView.isLoading):
                    self.parent.tab.isLoading = webView.isLoading
                case #keyPath(WKWebView.estimatedProgress):
                    self.parent.tab.estimatedProgress = webView.estimatedProgress
                case #keyPath(WKWebView.title):
                    self.parent.tab.title = webView.title ?? "New Tab"
                case #keyPath(WKWebView.canGoBack):
                    self.parent.tab.canGoBack = webView.canGoBack
                case #keyPath(WKWebView.canGoForward):
                    self.parent.tab.canGoForward = webView.canGoForward
                default:
                    break
                }
            }
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            print("🔄 iOS: didStartProvisionalNavigation - \(webView.url?.absoluteString ?? "unknown")")
            // We only update the UI state when navigation actually starts
            Task { @MainActor in
                // Force loading state to true when navigation starts
                // Loading state is handled by KVO
                parent.tab.startLoadingTimeout()
                print("💪 Started loading timeout for tab: \(parent.tab.id)")
                
                if let url = webView.url {
                    parent.tab.url = url
                    if parent.tab.showURLInBar {
                        parent.urlString = url.absoluteString
                    }
                    parent.onNavigate(url)
                }
            }
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("✅ iOS: didFinish navigation - \(webView.url?.absoluteString ?? "unknown")")
            Task { @MainActor in
                // Ensure we're scrolled to the real top, accounting for adjusted content inset
                let topInset = webView.scrollView.adjustedContentInset.top
                let expectedTop = -topInset
                if abs(webView.scrollView.contentOffset.y - expectedTop) > 0.5 {
                    webView.scrollView.setContentOffset(CGPoint(x: 0, y: expectedTop), animated: false)
                }
                
                // Force loading state to false when navigation finishes
                parent.tab.isLoading = false
                parent.tab.estimatedProgress = 1.0
                parent.tab.stopLoadingTimeout()
                print("🚫 Stopped loading timeout for tab: \(parent.tab.id)")
                
                if let url = webView.url {
                    parent.tab.url = url
                    // Show URL unless it's the homepage
                    parent.tab.showURLInBar = url != BrowserSettings.shared.homepageURL
                    if parent.tab.showURLInBar {
                        parent.urlString = url.absoluteString
                    }
                    
                    // Add to browsing history
                    let title = webView.title ?? parent.tab.title
                    HistoryManager.shared.addEntry(url: url, title: title)
                    print("📚 Added to history: \(title) - \(url.absoluteString)")
                    
                    // Apply JavaScript blocking settings for the new URL
                    let jsBlocked = JavaScriptBlockingManager.shared.isJavaScriptBlocked(for: url)
                    if jsBlocked != !webView.configuration.defaultWebpagePreferences.allowsContentJavaScript {
                        // JavaScript setting needs to be updated
                        webView.configuration.defaultWebpagePreferences.allowsContentJavaScript = !jsBlocked
                        webView.configuration.preferences.javaScriptCanOpenWindowsAutomatically = !jsBlocked
                    }
                    
                    // Check for Perplexity authentication when navigating to Perplexity pages
                    PerplexityManager.shared.checkForLoginOnNavigation(to: url)
                }
                
                // Capture a thumbnail of the web content for the tab selector
                ThumbnailManager.shared.captureThumbnail(for: webView, tab: self.parent.tab)
            }
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            let nsError = error as NSError
            print("😨 iOS: didFailProvisionalNavigation - \(webView.url?.absoluteString ?? "unknown") - Error: \(nsError.code)")
            
            Task { @MainActor in
                // Force loading state to false when navigation fails
                parent.tab.isLoading = false
                parent.tab.estimatedProgress = 0.0
                parent.tab.stopLoadingTimeout()
                print("🚫 Stopped loading timeout for failed navigation: \(parent.tab.id)")
            }
            
            // Handle canceled requests (error code -999) gracefully
            if nsError.code == NSURLErrorCancelled {
                print("💫 Navigation cancelled (expected)")
                return
            }
            
            // For other errors, we might want to show an error page or message
            print("Navigation failed: \(error)")
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            // Intercept link activations that trigger downloads
            if navigationAction.navigationType == .linkActivated,
               let url = navigationAction.request.url {
                // If the URL looks like a direct file (no HTML), let URLSession handle it
                let fileExtensions = ["zip","pdf","png","jpg","jpeg","gif","mp4","mov","mp3","wav","dmg","pkg","ipa","csv","txt","json"]
                if fileExtensions.contains(url.pathExtension.lowercased()) {
                    DownloadManager.shared.downloadFile(from: url)
                    decisionHandler(.cancel)
                    return
                }
            }
            decisionHandler(.allow)
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
            // For MIME types we can't show, check if it's a download
            if !navigationResponse.canShowMIMEType,
               let url = navigationResponse.response.url,
               let mimeType = navigationResponse.response.mimeType {
                // Known downloadable MIME types
                let downloadableTypes = [
                    "application/pdf",
                    "application/zip",
                    "application/x-zip",
                    "application/x-zip-compressed",
                    "application/octet-stream",
                    "image/jpeg",
                    "image/png",
                    "image/gif",
                    "audio/mpeg",
                    "video/mp4",
                    "text/csv",
                    "text/plain"
                ]
                
                if downloadableTypes.contains(mimeType.lowercased()) {
                    DownloadManager.shared.downloadFile(from: url)
                    decisionHandler(.cancel)
                    return
                }
            }
            decisionHandler(.allow)
        }
        
        // MARK: - WKUIDelegate methods for better website compatibility
        
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            // Handle popup windows by loading in the current webview
            if navigationAction.targetFrame == nil {
                webView.load(navigationAction.request)
            }
            return nil
        }
        
        func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
            // Handle JavaScript alerts (just complete them for now)
            completionHandler()
        }
        
        func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
            // Handle JavaScript confirms (default to OK)
            completionHandler(true)
        }
        
        @objc func handleReaderSwipe(_ gesture: UISwipeGestureRecognizer) {
            guard gesture.state == .ended, let webView = webView else { return }
            // Toggle reader mode state
            parent.tab.readerModeEnabled.toggle()
            if parent.tab.readerModeEnabled {
                applyReaderMode(on: webView)
            } else {
                removeReaderMode(on: webView)
            }
        }
        
        private func applyReaderMode(on webView: WKWebView) {
            let css = """
            #evoarc-reader-style { display: none; }
            .evoarc-reader body { background:#f7f7f7 !important; }
            .evoarc-reader article, .evoarc-reader main, .evoarc-reader #content, .evoarc-reader .content, .evoarc-reader .post, .evoarc-reader .entry { max-width: 700px; margin: 0 auto; padding: 16px; background: #ffffff !important; color: #111 !important; line-height: 1.6; font-size: 19px; }
            .evoarc-reader p { line-height: 1.7 !important; }
            .evoarc-reader img, .evoarc-reader video, .evoarc-reader figure { max-width: 100%; height: auto; }
            .evoarc-reader nav, .evoarc-reader header, .evoarc-reader footer, .evoarc-reader aside, .evoarc-reader .sidebar, .evoarc-reader .ads, .evoarc-reader [role='banner'], .evoarc-reader [role='navigation'], .evoarc-reader [role='complementary'] { display: none !important; }
            """
            let js = """
            (function(){
              try {
                if (!document.getElementById('evoarc-reader-style')) {
                  var style = document.createElement('style');
                  style.id = 'evoarc-reader-style';
                  style.textContent = `\(css.replacingOccurrences(of: "`", with: "\\`"))`;
                  document.head.appendChild(style);
                }
                document.documentElement.classList.add('evoarc-reader');
                return true;
              } catch (e) { return false; }
            })();
            """
            webView.evaluateJavaScript(js, completionHandler: nil)
        }
        
        private func removeReaderMode(on webView: WKWebView) {
            let js = """
            (function(){
              try {
                var style = document.getElementById('evoarc-reader-style');
                if (style && style.parentNode) { style.parentNode.removeChild(style); }
                document.documentElement.classList.remove('evoarc-reader');
                return true;
              } catch (e) { return false; }
            })();
            """
            webView.evaluateJavaScript(js, completionHandler: nil)
        }
        
        deinit {
            // Remove observers when coordinator is deallocated
            if let webView = webView {
                webView.removeObserver(self, forKeyPath: #keyPath(WKWebView.isLoading))
                webView.removeObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress))
                webView.removeObserver(self, forKeyPath: #keyPath(WKWebView.title))
                webView.removeObserver(self, forKeyPath: #keyPath(WKWebView.canGoBack))
                webView.removeObserver(self, forKeyPath: #keyPath(WKWebView.canGoForward))
            }
        }
    }
}
#endif

#if os(macOS)
import AppKit

struct WebView: NSViewRepresentable {
    @ObservedObject var tab: Tab
    @Binding var urlString: String
    @Binding var shouldNavigate: Bool
    let onNavigate: (URL) -> Void
    @StateObject private var settings = BrowserSettings.shared
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeNSView(context: Context) -> WKWebView {
        // Create standard WebKit configuration
        let configuration = WKWebViewConfiguration()
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        
        // Set custom user agent based on settings
        webView.customUserAgent = BrowserSettings.shared.userAgentString
        
        // Store reference to webView in the tab
        DispatchQueue.main.async {
            tab.webView = webView
        }
        
        // Set coordinator's webView reference
        context.coordinator.webView = webView
        
        // Add observers for loading state
        webView.addObserver(context.coordinator, forKeyPath: #keyPath(WKWebView.isLoading), options: .new, context: nil)
        webView.addObserver(context.coordinator, forKeyPath: #keyPath(WKWebView.estimatedProgress), options: .new, context: nil)
        webView.addObserver(context.coordinator, forKeyPath: #keyPath(WKWebView.title), options: .new, context: nil)
        webView.addObserver(context.coordinator, forKeyPath: #keyPath(WKWebView.canGoBack), options: .new, context: nil)
        webView.addObserver(context.coordinator, forKeyPath: #keyPath(WKWebView.canGoForward), options: .new, context: nil)
        
        // Load initial URL if available
        if let url = tab.url {
            webView.load(URLRequest(url: url))
        }
        
        return webView
    }
    
    func updateNSView(_ webView: WKWebView, context: Context) {
        // Update user agent if settings changed
        if webView.customUserAgent != settings.userAgentString {
            webView.customUserAgent = settings.userAgentString
        }
        
        // Handle navigation when user submits URL
        if shouldNavigate {
            if let url = formatURL(from: urlString) {
                // Create a new URLRequest with caching policy
                var request = URLRequest(url: url)
                request.cachePolicy = .reloadIgnoringLocalCacheData
                webView.load(request)
                
                // Reset the flag after navigation - must be done asynchronously
                Task { @MainActor in
                    shouldNavigate = false
                }
            }
        }
        
        // Only sync tab URL to WebView if the WebView has no URL loaded
        if webView.url == nil, let tabURL = tab.url {
            var request = URLRequest(url: tabURL)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            webView.load(request)
        }
    }
    private func formatURL(from string: String) -> URL? {
        // Check if it's already a valid URL
        if let url = URL(string: string), url.scheme != nil {
            return url
        }
        
        // Check if it looks like a domain
        if string.contains(".") && !string.contains(" ") {
            if let url = URL(string: "https://\(string)") {
                return url
            }
        }
        
        // Otherwise, treat it as a search query using the selected engine
        return BrowserSettings.shared.searchURL(for: string)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var parent: WebView
        weak var webView: WKWebView?
        
        init(_ parent: WebView) {
            self.parent = parent
        }
        
        override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
            guard let webView = object as? WKWebView else { return }
            
            // Use async dispatch to avoid "Publishing changes from within view updates"
            DispatchQueue.main.async {
                switch keyPath {
                case #keyPath(WKWebView.isLoading):
                    self.parent.tab.isLoading = webView.isLoading
                case #keyPath(WKWebView.estimatedProgress):
                    self.parent.tab.estimatedProgress = webView.estimatedProgress
                case #keyPath(WKWebView.title):
                    self.parent.tab.title = webView.title ?? "New Tab"
                case #keyPath(WKWebView.canGoBack):
                    self.parent.tab.canGoBack = webView.canGoBack
                case #keyPath(WKWebView.canGoForward):
                    self.parent.tab.canGoForward = webView.canGoForward
                default:
                    break
                }
            }
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            print("🔄 macOS: didStartProvisionalNavigation - \(webView.url?.absoluteString ?? "unknown")")
            // Force loading state to true when navigation starts
            parent.tab.isLoading = true
            parent.tab.estimatedProgress = 0.0
            parent.tab.startLoadingTimeout()
            print("💪 macOS: Started loading timeout for tab: \(parent.tab.id)")
            
            if let url = webView.url {
                parent.tab.url = url
                if parent.tab.showURLInBar {
                    parent.urlString = url.absoluteString
                }
                parent.onNavigate(url)
            }
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("✅ macOS: didFinish navigation - \(webView.url?.absoluteString ?? "unknown")")
            // Force loading state to false when navigation finishes
            parent.tab.isLoading = false
            parent.tab.estimatedProgress = 1.0
            parent.tab.stopLoadingTimeout()
            print("🚫 macOS: Stopped loading timeout for tab: \(parent.tab.id)")
            
            if let url = webView.url {
                parent.tab.url = url
                if parent.tab.showURLInBar {
                    parent.urlString = url.absoluteString
                }
                
                // Check for Perplexity authentication when navigating to Perplexity pages
                PerplexityManager.shared.checkForLoginOnNavigation(to: url)
            }
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            let nsError = error as NSError
            print("😨 macOS: didFailProvisionalNavigation - \(webView.url?.absoluteString ?? "unknown") - Error: \(nsError.code)")
            
            // Force loading state to false when navigation fails
            parent.tab.isLoading = false
            parent.tab.estimatedProgress = 0.0
            parent.tab.stopLoadingTimeout()
            print("🚫 macOS: Stopped loading timeout for failed navigation: \(parent.tab.id)")
            
            // Handle canceled requests (error code -999) gracefully
            if nsError.code == NSURLErrorCancelled {
                print("💫 macOS: Navigation cancelled (expected)")
                return
            }
            
            // For other errors, we might want to show an error page or message
            print("Navigation failed: \(error)")
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            // Allow all navigation by default
            decisionHandler(.allow)
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
            // Allow all responses by default
            decisionHandler(.allow)
        }
        
        // MARK: - WKUIDelegate methods for better website compatibility
        
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            // Handle popup windows by loading in the current webview
            if navigationAction.targetFrame == nil {
                webView.load(navigationAction.request)
            }
            return nil
        }
        
        func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
            // Handle JavaScript alerts (just complete them for now)
            completionHandler()
        }
        
        func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
            // Handle JavaScript confirms (default to OK)
            completionHandler(true)
        }
        
        deinit {
            // Remove observers when coordinator is deallocated
            if let webView = webView {
                webView.removeObserver(self, forKeyPath: #keyPath(WKWebView.isLoading))
                webView.removeObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress))
                webView.removeObserver(self, forKeyPath: #keyPath(WKWebView.title))
                webView.removeObserver(self, forKeyPath: #keyPath(WKWebView.canGoBack))
                webView.removeObserver(self, forKeyPath: #keyPath(WKWebView.canGoForward))
            }
        }
    }
}
#endif
