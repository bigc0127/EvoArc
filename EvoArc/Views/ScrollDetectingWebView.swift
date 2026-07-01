//
//  ScrollDetectingWebView.swift
//  EvoArc
//
//  Created on 2025-09-05.
//

/**
 * # ScrollDetectingWebView
 * 
 * A SwiftUI wrapper around WKWebView that provides scroll-based URL bar visibility management.
 * This component is the core web browsing engine for EvoArc, providing cross-platform 
 * (iOS and macOS) web content rendering with auto-hide URL bar functionality.
 * 
 * ## Architecture Overview
 * 
 * ### For New Swift Developers:
 * - **UIViewRepresentable/NSViewRepresentable**: These protocols allow SwiftUI to wrap UIKit (iOS) or AppKit (macOS) components
 * - **@Binding**: A two-way connection between parent and child views that automatically updates both when changed
 * - **@ObservedObject**: Watches for changes in an ObservableObject and updates the UI when properties change
 * - **Coordinator**: A design pattern used by SwiftUI representables to handle delegate callbacks from UIKit/AppKit
 * 
 * ### Component Structure:
 * 1. **ScrollDetectingWebView**: The main SwiftUI view that chooses iOS or macOS implementation
 * 2. **ScrollAwareWebView**: Platform-specific implementations that handle WebKit integration
 * 3. **Coordinator**: Manages WebKit delegate callbacks and scroll detection
 * 
 * ## Key Features:
 * - **Cross-Platform**: Single interface works on both iOS and macOS
 * - **Scroll Detection**: Hides/shows URL bar based on scroll direction
 * - **Tab Management**: Integrates with EvoArc's tab system
 * - **Standard DNS**: Uses system DNS resolution (no custom DNS providers)
 * - **WebKit Integration**: Full WKWebView functionality with custom user agents
 * 
 * ## Usage:
 * ```swift
 * ScrollDetectingWebView(
 *     tab: currentTab,
 *     urlString: $urlString,
 *     shouldNavigate: $shouldNavigate,
 *     urlBarVisible: $urlBarVisible,
 *     onNavigate: { url in /* handle navigation */ },
 *     autoHideEnabled: settings.autoHideURLBar,
 *     tabManager: tabManager
 * )
 * ```
 */

import SwiftUI
import WebKit

/// The main SwiftUI view that provides scroll-aware web browsing functionality
/// This view automatically chooses between iOS and macOS implementations
struct ScrollDetectingWebView: View {
    /// The tab object containing the web content and state
    /// - Note: Tab is an ObservableObject that tracks loading state, URL, title, etc.
    let tab: Tab
    
    /// Two-way binding to the URL bar text field
    /// - Note: @Binding creates a connection between parent and child views
    @Binding var urlString: String
    
    /// Flag indicating whether navigation should occur (set by URL bar submission)
    @Binding var shouldNavigate: Bool
    
    /// Controls whether the URL bar is visible (affected by scroll direction)
    @Binding var urlBarVisible: Bool
    
    /// Callback function called when navigation to a new URL occurs
    /// - Parameter url: The URL that was navigated to
    let onNavigate: (URL) -> Void
    
    /// Whether auto-hide functionality is enabled for the URL bar
    let autoHideEnabled: Bool
    
    /// Reference to the tab manager for creating new tabs and handling context menus
    let tabManager: TabManager
    
    /// The main body of the SwiftUI view
    /// Creates the platform-specific ScrollAwareWebView and handles scroll-based URL bar visibility
    var body: some View {
        ScrollAwareWebView(
            tab: tab,
            urlString: $urlString,
            shouldNavigate: $shouldNavigate,
            onNavigate: onNavigate,
            tabManager: tabManager,
            // This closure is called whenever the user scrolls in the web view
            onScrollChange: { scrollDirection in
                // Only hide/show URL bar if auto-hide is enabled in settings
                if autoHideEnabled {
                    // Animate the URL bar visibility change for smooth UX
                    withAnimation(.easeInOut(duration: 0.3)) {
                        switch scrollDirection {
                        case .up:
                            // Scrolling up - show URL bar (user wants to navigate)
                            urlBarVisible = true
                        case .down:
                            // Scrolling down - hide URL bar (user is reading content)
                            urlBarVisible = false
                        case .none:
                            // No significant scroll change - do nothing
                            break
                        }
                    }
                }
            }
        )
    }
}

/// Represents the direction of scroll movement in the web view
/// Used to determine whether to show or hide the URL bar
enum ScrollDirection {
    /// User is scrolling upward (towards the top of the page)
    case up
    /// User is scrolling downward (towards the bottom of the page)
    case down
    /// No significant scroll movement detected
    case none
}

struct ScrollAwareWebView: UIViewRepresentable {
    let tab: Tab
    @Binding var urlString: String
    @Binding var shouldNavigate: Bool
    let onNavigate: (URL) -> Void
    let tabManager: TabManager
    let onScrollChange: (ScrollDirection) -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> WKWebView {
        // Standard configuration
        let configuration = WKWebViewConfiguration()
        let preferences = WKWebpagePreferences()
        
        // Check if JavaScript should be blocked for this site
        let jsEnabled = tab.url.map { !JavaScriptBlockingManager.shared.isJavaScriptBlocked(for: $0) } ?? true
        preferences.allowsContentJavaScript = jsEnabled
        
        configuration.defaultWebpagePreferences = preferences
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = jsEnabled
        let webView = WKWebView(frame: .zero, configuration: configuration)

        // Enable the native system Find-on-Page interaction (Find feature).
        if #available(iOS 16.0, *) {
            webView.isFindInteractionEnabled = true
        }

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
        
        AdBlockManager.shared.applyContentBlocking(to: webView)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.scrollView.delegate = context.coordinator
        
        // Enable swipe gestures for back/forward navigation
        // Always enable for better native gesture support
        webView.allowsBackForwardNavigationGestures = true
        
        webView.customUserAgent = BrowserSettings.shared.userAgentString
        
        // CRITICAL: Set tab.webView BEFORE setting up observers
        // This ensures observers can update the tab state immediately
        tab.webView = webView
        
        context.coordinator.webView = webView
        dlog("🔵 iOS: Setting up KVO observers for webView=\(Unmanaged.passUnretained(webView).toOpaque()) tab=\(tab.id)")
        context.coordinator.setupObservers()
        
        // Load initial URL if available
        // But don't load if we're showing the new tab page (showURLInBar is false)
        if let url = tab.url, tab.showURLInBar {
            let request = URLRequest(url: url)
            webView.load(request)
        }
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        if webView.customUserAgent != BrowserSettings.shared.userAgentString {
            webView.customUserAgent = BrowserSettings.shared.userAgentString
        }
        
        if shouldNavigate {
            if let url = formatURL(from: urlString) {
                var request = URLRequest(url: url)
                request.cachePolicy = .reloadIgnoringLocalCacheData
                webView.load(request)
                
                Task { @MainActor in
                    shouldNavigate = false
                }
            }
        }
        
        // Load tab URL if webView has no URL loaded
        // But don't load if we're showing the new tab page (showURLInBar is false)
        if webView.url == nil, let tabURL = tab.url, tab.showURLInBar {
            var request = URLRequest(url: tabURL)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            webView.load(request)
        }
    }
    
    private func formatURL(from string: String) -> URL? {
        if let url = URL(string: string), url.scheme != nil {
            return url
        }
        
        if string.contains(".") && !string.contains(" ") {
            if let url = URL(string: "https://\(string)") {
                return url
            }
        }
        
        return BrowserSettings.shared.searchURL(for: string)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, UIScrollViewDelegate {
        var parent: ScrollAwareWebView
        weak var webView: WKWebView?
        // Offset at the time of the most recent reported direction change.
        // We compare against this (not every frame) so the threshold reflects
        // sustained scrolling in one direction, not jitter.
        private var lastReportedOffset: CGFloat = 0
        // Asymmetric thresholds: hiding requires deliberate scrolling, while
        // any small upward gesture brings the bar back. This matches Safari's
        // behavior and fixes "hides too easily, hard to recover" complaints.
        private let hideThreshold: CGFloat = 60
        private let showThreshold: CGFloat = 8
        
        init(_ parent: ScrollAwareWebView) {
            self.parent = parent
        }
        
        func setupObservers() {
            guard let webView = webView else { return }
            webView.addObserver(self, forKeyPath: #keyPath(WKWebView.isLoading), options: .new, context: nil)
            webView.addObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress), options: .new, context: nil)
            webView.addObserver(self, forKeyPath: #keyPath(WKWebView.title), options: .new, context: nil)
            webView.addObserver(self, forKeyPath: #keyPath(WKWebView.canGoBack), options: .new, context: nil)
            webView.addObserver(self, forKeyPath: #keyPath(WKWebView.canGoForward), options: .new, context: nil)
        }
        
        override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
            guard let webView = object as? WKWebView else { return }
            
            // Use async dispatch to avoid "Publishing changes from within view updates"
            DispatchQueue.main.async {
                switch keyPath {
                case #keyPath(WKWebView.isLoading):
                    self.parent.tab.isLoading = webView.isLoading
                    dlog("ℹ️ iOS KVO isLoading=\(webView.isLoading) URL=\(webView.url?.absoluteString ?? "unknown")")
                case #keyPath(WKWebView.estimatedProgress):
                    self.parent.tab.estimatedProgress = webView.estimatedProgress
                    dlog("📈 iOS progress=\(String(format: "%.2f", webView.estimatedProgress)) URL=\(webView.url?.absoluteString ?? "unknown")")
                case #keyPath(WKWebView.title):
                    self.parent.tab.title = webView.title ?? "New Tab"
                case #keyPath(WKWebView.canGoBack):
                    dlog("🔙 iOS KVO canGoBack=\(webView.canGoBack) for tab=\(self.parent.tab.id)")
                    self.parent.tab.canGoBack = webView.canGoBack
                case #keyPath(WKWebView.canGoForward):
                    dlog("🔜 iOS KVO canGoForward=\(webView.canGoForward) for tab=\(self.parent.tab.id)")
                    self.parent.tab.canGoForward = webView.canGoForward
                default:
                    break
                }
            }
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            let currentOffset = scrollView.contentOffset.y
            let topInset = scrollView.adjustedContentInset.top
            // Distance from the top of the content (0 when at the very top).
            let distanceFromTop = currentOffset + topInset

            // Always reveal the bar near the top of the page so users aren't
            // stuck without it after a short scroll up.
            if distanceFromTop <= 10 {
                parent.onScrollChange(.up)
                lastReportedOffset = currentOffset
                return
            }

            let difference = currentOffset - lastReportedOffset
            if difference > hideThreshold {
                parent.onScrollChange(.down)
                lastReportedOffset = currentOffset
            } else if difference < -showThreshold {
                parent.onScrollChange(.up)
                lastReportedOffset = currentOffset
            }
        }
        
        // MARK: - Navigation Delegate Methods
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            dlog("🔄 iOS: didStartProvisionalNavigation - \(webView.url?.absoluteString ?? "unknown")")
            dlog("🔍 iOS: At nav start - canGoBack=\(webView.canGoBack) canGoForward=\(webView.canGoForward)")
            Task { @MainActor in
                parent.tab.isLoading = true
                parent.tab.estimatedProgress = 0.0
                parent.tab.startLoadingTimeout()
                dlog("💪 iOS: Started loading timeout for tab: \(parent.tab.id)")
                
                // Record navigation start time for tap intent detection
                // This helps determine if a tap triggered navigation (clicked a link)
                // versus just trying to reveal the bottom bar
                parent.tabManager.lastNavigationStart = Date()
                
                if let url = webView.url {
                    parent.tab.url = url
                    parent.urlString = url.absoluteString
                    parent.onNavigate(url)
                    // TabViewContainer derives the new-tab-page overlay from selectedTab.url
                    // but observes the TabManager, not the Tab, so nudge it to re-evaluate
                    // and dismiss the overlay now that navigation has started.
                    parent.tabManager.objectWillChange.send()
                }
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            dlog("✅ iOS: didFinish navigation - \(webView.url?.absoluteString ?? "unknown")")
            dlog("🔍 iOS: At nav finish - canGoBack=\(webView.canGoBack) canGoForward=\(webView.canGoForward)")
            Task { @MainActor in
                // Ensure we're scrolled to the real top, accounting for adjusted content inset
                let topInset = webView.scrollView.adjustedContentInset.top
                let expectedTop = -topInset
                if abs(webView.scrollView.contentOffset.y - expectedTop) > 0.5 {
                    webView.scrollView.setContentOffset(CGPoint(x: 0, y: expectedTop), animated: false)
                }
                
                parent.tab.isLoading = false
                parent.tab.estimatedProgress = 1.0
                parent.tab.stopLoadingTimeout()
                dlog("🚫 iOS: Stopped loading timeout for tab: \(parent.tab.id)")
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
                    dlog("📚 iOS: Added to history: \(title) - \(url.absoluteString)")
                    
                    // Apply JavaScript blocking settings for the new URL
                    let jsBlocked = JavaScriptBlockingManager.shared.isJavaScriptBlocked(for: url)
                    if jsBlocked != !webView.configuration.defaultWebpagePreferences.allowsContentJavaScript {
                        webView.configuration.defaultWebpagePreferences.allowsContentJavaScript = !jsBlocked
                        webView.configuration.preferences.javaScriptCanOpenWindowsAutomatically = !jsBlocked
                    }
                }
                
                // Capture a thumbnail of the web content for the tab selector
                ThumbnailManager.shared.captureThumbnail(for: webView, tab: self.parent.tab)
            }
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            let nsError = error as NSError
            if nsError.code == NSURLErrorCancelled {
                dlog("💫 iOS: Navigation cancelled (expected)")
                return
            }
            Task { @MainActor in
                parent.tab.isLoading = false
                parent.tab.estimatedProgress = 0.0
                parent.tab.stopLoadingTimeout()
                dlog("🚫 iOS: Stopped loading timeout for failed nav: \(parent.tab.id)")
            }
            dlog("😨 iOS: didFailProvisionalNavigation - URL=\(webView.url?.absoluteString ?? "unknown") code=\(nsError.code) domain=\(nsError.domain) desc=\(nsError.localizedDescription)")
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            dlog("🎯 Navigation policy requested for: \(navigationAction.request.url?.absoluteString ?? "unknown URL")")
            dlog("🎯 Navigation type: \(navigationAction.navigationType.rawValue)")

            // Link Sanitizer: strip tracking params from clicked links (only when the
            // setting is on and something was actually removed). Loading the cleaned URL
            // has no tracking params, so this can't loop.
            if BrowserSettings.shared.stripTrackingParams,
               navigationAction.navigationType == .linkActivated,
               let url = navigationAction.request.url {
                let result = URLSanitizer.sanitize(url)
                if !result.removed.isEmpty {
                    dlog("🧼 Stripped \(result.removed.count) tracking param(s) from link")
                    decisionHandler(.cancel)
                    webView.load(URLRequest(url: result.url))
                    return
                }
            }

            decisionHandler(.allow)
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
            dlog("🎯 Response policy requested for: \(navigationResponse.response.url?.absoluteString ?? "unknown URL")")
            
            if let httpResponse = navigationResponse.response as? HTTPURLResponse {
                dlog("🎯 HTTP Status: \(httpResponse.statusCode)")
                
                // Check if this is a download (MIME type or Content-Disposition)
                if !navigationResponse.canShowMIMEType {
                    dlog("⬇️ Detected non-displayable MIME type: \(navigationResponse.response.mimeType ?? "unknown")")
                    
                    if let url = navigationResponse.response.url {
                        // Hand off to DownloadManager
                        Task { @MainActor in
                            DownloadManager.shared.downloadFile(from: url, suggestedFilename: navigationResponse.response.suggestedFilename)
                        }
                    }
                    
                    decisionHandler(.cancel)
                    return
                }
                
                // Check Content-Disposition header for "attachment"
                if let contentDisposition = httpResponse.allHeaderFields["Content-Disposition"] as? String,
                   contentDisposition.lowercased().contains("attachment") {
                    dlog("⬇️ Detected Content-Disposition attachment")
                    
                    if let url = navigationResponse.response.url {
                        // Hand off to DownloadManager
                        Task { @MainActor in
                            DownloadManager.shared.downloadFile(from: url, suggestedFilename: navigationResponse.response.suggestedFilename)
                        }
                    }
                    
                    decisionHandler(.cancel)
                    return
                }
            }
            
            decisionHandler(.allow)
        }
        
        // MARK: - UI Delegate Methods
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if navigationAction.targetFrame == nil {
                webView.load(navigationAction.request)
            }
            return nil
        }
        
        func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
            completionHandler()
        }
        
        func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
            completionHandler(true)
        }
        
        // MARK: - Context Menu Support
        @available(iOS 13.0, *)
        func webView(_ webView: WKWebView, contextMenuConfigurationForElement elementInfo: WKContextMenuElementInfo, completionHandler: @escaping (UIContextMenuConfiguration?) -> Void) {
            let configuration = UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
                var linkActions: [UIAction] = []
                var pageActions: [UIAction] = []
                
                // Link-specific actions
                if let linkURL = elementInfo.linkURL {
                    let openInNewTab = UIAction(title: "Open in New Tab", image: UIImage(systemName: "plus.square.on.square")) { [weak self] _ in
                        DispatchQueue.main.async {
                            self?.parent.tabManager.createNewTab(url: linkURL)
                        }
                    }
                    
                    let copyLink = UIAction(title: "Copy Link", image: UIImage(systemName: "doc.on.doc")) { _ in
                        UIPasteboard.general.string = linkURL.absoluteString
                    }
                    
                    linkActions.append(contentsOf: [openInNewTab, copyLink])
                    
                    // Perplexity actions for link
                    if PerplexityManager.shared.isAuthenticated {
                        let summarizeLink = UIAction(title: "Summarize Link with Perplexity", image: UIImage(systemName: "doc.text.magnifyingglass")) { _ in
                            DispatchQueue.main.async {
                                PerplexityManager.shared.performAction(.summarize, for: linkURL)
                            }
                        }
                        
                        let sendLinkToPerplexity = UIAction(title: "Send Link to Perplexity", image: UIImage(systemName: "arrow.up.right.square")) { _ in
                            DispatchQueue.main.async {
                                PerplexityManager.shared.performAction(.sendToPerplexity, for: linkURL)
                            }
                        }
                        
                        linkActions.append(contentsOf: [summarizeLink, sendLinkToPerplexity])
                    }
                }
                
                // Page-level actions (always available when right-clicking)
                if let currentURL = webView.url, PerplexityManager.shared.isAuthenticated {
                    let summarizePage = UIAction(title: "Summarize Page with Perplexity", image: UIImage(systemName: "doc.text.magnifyingglass")) { _ in
                        DispatchQueue.main.async {
                            PerplexityManager.shared.performAction(.summarize, for: currentURL, title: webView.title)
                        }
                    }
                    
                    let sendPageToPerplexity = UIAction(title: "Send Page to Perplexity", image: UIImage(systemName: "arrow.up.right.square")) { _ in
                        DispatchQueue.main.async {
                            PerplexityManager.shared.performAction(.sendToPerplexity, for: currentURL, title: webView.title)
                        }
                    }
                    
                    pageActions.append(contentsOf: [summarizePage, sendPageToPerplexity])
                }
                
                var menuItems: [UIMenuElement] = []
                
                if !linkActions.isEmpty {
                    menuItems.append(UIMenu(title: "", options: .displayInline, children: linkActions))
                }
                
                if !pageActions.isEmpty {
                    menuItems.append(UIMenu(title: "", options: .displayInline, children: pageActions))
                }
                
                return menuItems.isEmpty ? nil : UIMenu(title: "", children: menuItems)
            }
            
            completionHandler(configuration)
        }
        
        deinit {
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

