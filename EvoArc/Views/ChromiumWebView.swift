//
//  ChromiumWebView.swift
//  EvoArc
//
//  Created on 2025-09-05.
//

import SwiftUI
import WebKit
#if os(iOS)
import UIKit
#else
import AppKit
#endif

/// A WebView wrapper that simulates Chromium behavior with Chrome-like features
struct ChromiumWebView: View {
    @ObservedObject var tab: Tab
    @Binding var urlString: String
    @Binding var shouldNavigate: Bool
    let onNavigate: (URL) -> Void
    @StateObject private var settings = BrowserSettings.shared
    
    var body: some View {
        ChromiumWebViewRepresentable(
            tab: tab,
            urlString: $urlString,
            shouldNavigate: $shouldNavigate,
            onNavigate: onNavigate
        )
    }
}

#if os(iOS)
struct ChromiumWebViewRepresentable: UIViewRepresentable {
    @ObservedObject var tab: Tab
    @Binding var urlString: String
    @Binding var shouldNavigate: Bool
    let onNavigate: (URL) -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> WKWebView {
        return createWebView(context: context)
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        updateWebView(webView, context: context)
    }
    
    // MARK: - Shared Implementation
    private func createWebView(context: Context) -> WKWebView {
        // Standard WebKit configuration for Chromium mode
        let configuration = WKWebViewConfiguration()
        let preferences = WKWebpagePreferences()
        
        // Check if JavaScript should be blocked for this site
        let jsEnabled = tab.url.map { !JavaScriptBlockingManager.shared.isJavaScriptBlocked(for: $0) } ?? true
        preferences.allowsContentJavaScript = jsEnabled
        
        configuration.defaultWebpagePreferences = preferences
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = jsEnabled
        configuration.mediaTypesRequiringUserActionForPlayback = []
        
        // Apply content blocking (AdBlock) after webView creation below
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        
        // Enable developer extras for Chromium-like dev tools
        configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")
        
        // Configure content rules for ad blocking (similar to Chrome's built-in features)
        let contentController = WKUserContentController()
        
        // Add Chrome-like user agent
        let chromeUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        
        // Add user scripts for Chrome-like features
        let script = WKUserScript(
            source: """
            // Emulate Chrome-specific APIs
            window.chrome = window.chrome || {};
            window.chrome.runtime = window.chrome.runtime || {};
            window.chrome.runtime.id = 'evoarc-chromium-mode';
            
            // Add Chrome-specific console methods
            console.timeline = console.timeline || function() {};
            console.timelineEnd = console.timelineEnd || function() {};
            """,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        contentController.addUserScript(script)
        
        configuration.userContentController = contentController
        
        // Create the WebView with Chromium configuration
        let webView = WKWebView(frame: .zero, configuration: configuration)
        AdBlockManager.shared.applyContentBlocking(to: webView)
        
        // Set delegates
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.customUserAgent = chromeUserAgent
        
        // Store reference to webView in tab for control
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
    
    private func updateWebView(_ webView: WKWebView, context: Context) {
        // Handle navigation when user submits URL
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
        if webView.url == nil, let tabURL = tab.url {
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
        
        // Use the selected default search engine
        return BrowserSettings.shared.searchURL(for: string)
    }
    
    // MARK: - Coordinator
    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var parent: ChromiumWebViewRepresentable
        weak var webView: WKWebView?
        
        init(_ parent: ChromiumWebViewRepresentable) {
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
        
        // MARK: - Navigation Delegate Methods
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            Task { @MainActor in
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
            Task { @MainActor in
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
                    print("📚 Chromium iOS: Added to history: \(title) - \(url.absoluteString)")
                }
                
                // Inject Chrome-specific features after page load
                Task {
                    try? await webView.evaluateJavaScript("""
                        // Add Chrome-specific performance timing
                        if (!window.performance.memory) {
                            Object.defineProperty(window.performance, 'memory', {
                                get: function() {
                                    return {
                                        jsHeapSizeLimit: 2147483648,
                                        totalJSHeapSize: 35000000,
                                        usedJSHeapSize: 20000000
                                    };
                                }
                            });
                        }
                    """)
                }
            }
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            let nsError = error as NSError
            if nsError.code == NSURLErrorCancelled {
                return
            }
            print("Chromium mode navigation failed: \(error)")
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            // Handle Chrome-specific URL schemes
            if let url = navigationAction.request.url {
                if url.scheme == "chrome" || url.scheme == "chrome-extension" {
                    // Handle Chrome-specific URLs
                    print("Chrome-specific URL detected: \(url)")
                    decisionHandler(.cancel)
                    return
                }
            }
            decisionHandler(.allow)
        }
        
        // MARK: - UI Delegate Methods
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            // Chrome-like popup handling
            if navigationAction.targetFrame == nil {
                // Option to open in new tab (Chrome behavior)
                if navigationAction.request.url != nil {
                    // Could trigger new tab creation here
                    webView.load(navigationAction.request)
                }
            }
            return nil
        }
        
        func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
            // Show Chrome-style alert on iOS
            DispatchQueue.main.async {
                guard let windowScene = UIApplication.shared.connectedScenes
                    .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
                      let rootViewController = windowScene.windows.first?.rootViewController else {
                    completionHandler()
                    return
                }
                
                let alert = UIAlertController(title: "Page Alert", message: message, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
                    completionHandler()
                }))
                rootViewController.present(alert, animated: true)
            }
        }
        
        func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
            // Show Chrome-style confirm dialog on iOS
            DispatchQueue.main.async {
                guard let windowScene = UIApplication.shared.connectedScenes
                    .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
                      let rootViewController = windowScene.windows.first?.rootViewController else {
                    completionHandler(false)
                    return
                }
                
                let alert = UIAlertController(title: "Page Confirmation", message: message, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
                    completionHandler(true)
                }))
                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { _ in
                    completionHandler(false)
                }))
                rootViewController.present(alert, animated: true)
            }
        }
        
        func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
            // Show Chrome-style prompt dialog on iOS
            DispatchQueue.main.async {
                guard let windowScene = UIApplication.shared.connectedScenes
                    .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
                      let rootViewController = windowScene.windows.first?.rootViewController else {
                    completionHandler(nil)
                    return
                }
                
                let alert = UIAlertController(title: "Page Prompt", message: prompt, preferredStyle: .alert)
                alert.addTextField { textField in
                    textField.text = defaultText ?? ""
                }
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
                    completionHandler(alert.textFields?.first?.text)
                }))
                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { _ in
                    completionHandler(nil)
                }))
                rootViewController.present(alert, animated: true)
            }
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

#else

struct ChromiumWebViewRepresentable: NSViewRepresentable {
    @ObservedObject var tab: Tab
    @Binding var urlString: String
    @Binding var shouldNavigate: Bool
    let onNavigate: (URL) -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeNSView(context: Context) -> WKWebView {
        return createWebView(context: context)
    }
    
    func updateNSView(_ webView: WKWebView, context: Context) {
        updateWebView(webView, context: context)
    }
    
    // MARK: - Shared Implementation
    private func createWebView(context: Context) -> WKWebView {
        // Standard WebKit configuration for Chromium mode
        let configuration = WKWebViewConfiguration()
        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        configuration.defaultWebpagePreferences = preferences
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        
        // Apply content blocking (AdBlock) after webView creation below
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        
        // Enable developer extras for Chromium-like dev tools
        configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")
        
        // Configure content rules for ad blocking (similar to Chrome's built-in features)
        let contentController = WKUserContentController()
        
        // Add Chrome-like user agent
        let chromeUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        
        // Add user scripts for Chrome-like features
        let script = WKUserScript(
            source: """
            // Emulate Chrome-specific APIs
            window.chrome = window.chrome || {};
            window.chrome.runtime = window.chrome.runtime || {};
            window.chrome.runtime.id = 'evoarc-chromium-mode';
            
            // Add Chrome-specific console methods
            console.timeline = console.timeline || function() {};
            console.timelineEnd = console.timelineEnd || function() {};
            """,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        contentController.addUserScript(script)
        
        configuration.userContentController = contentController
        
        // Create the WebView with Chromium configuration
        let webView = WKWebView(frame: .zero, configuration: configuration)
        AdBlockManager.shared.applyContentBlocking(to: webView)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.customUserAgent = chromeUserAgent
        
        // Enable Chrome-like features on macOS
        webView.allowsMagnification = true
        webView.allowsLinkPreview = true
        
        // Store reference to webView in tab for control
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
    
    private func updateWebView(_ webView: WKWebView, context: Context) {
        // Handle navigation when user submits URL
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
        if webView.url == nil, let tabURL = tab.url {
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
        
        // Use the selected default search engine
        return BrowserSettings.shared.searchURL(for: string)
    }
    
    // MARK: - Coordinator
    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var parent: ChromiumWebViewRepresentable
        weak var webView: WKWebView?
        
        init(_ parent: ChromiumWebViewRepresentable) {
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
        
        // MARK: - Navigation Delegate Methods
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            Task { @MainActor in
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
            Task { @MainActor in
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
                    print("📚 Chromium macOS: Added to history: \(title) - \(url.absoluteString)")
                }
                
                // Inject Chrome-specific features after page load
                Task {
                    try? await webView.evaluateJavaScript("""
                        // Add Chrome-specific performance timing
                        if (!window.performance.memory) {
                            Object.defineProperty(window.performance, 'memory', {
                                get: function() {
                                    return {
                                        jsHeapSizeLimit: 2147483648,
                                        totalJSHeapSize: 35000000,
                                        usedJSHeapSize: 20000000
                                    };
                                }
                            });
                        }
                    """)
                }
            }
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            let nsError = error as NSError
            if nsError.code == NSURLErrorCancelled {
                return
            }
            print("Chromium mode navigation failed: \(error)")
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            // Handle Chrome-specific URL schemes
            if let url = navigationAction.request.url {
                if url.scheme == "chrome" || url.scheme == "chrome-extension" {
                    // Handle Chrome-specific URLs
                    print("Chrome-specific URL detected: \(url)")
                    decisionHandler(.cancel)
                    return
                }
            }
            decisionHandler(.allow)
        }
        
        // MARK: - UI Delegate Methods
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            // Chrome-like popup handling
            if navigationAction.targetFrame == nil {
                // Option to open in new tab (Chrome behavior)
                if navigationAction.request.url != nil {
                    // Could trigger new tab creation here
                    webView.load(navigationAction.request)
                }
            }
            return nil
        }
        
        func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
            // Show Chrome-style alert on macOS
            let alert = NSAlert()
            alert.messageText = "Page Alert"
            alert.informativeText = message
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
            completionHandler()
        }
        
        func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
            // Show Chrome-style confirm dialog on macOS
            let alert = NSAlert()
            alert.messageText = "Page Confirmation"
            alert.informativeText = message
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.addButton(withTitle: "Cancel")
            let response = alert.runModal()
            completionHandler(response == .alertFirstButtonReturn)
        }
        
        func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
            // Show Chrome-style prompt dialog on macOS
            let alert = NSAlert()
            alert.messageText = "Page Prompt"
            alert.informativeText = prompt
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.addButton(withTitle: "Cancel")
            
            let inputField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
            inputField.stringValue = defaultText ?? ""
            alert.accessoryView = inputField
            
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                completionHandler(inputField.stringValue)
            } else {
                completionHandler(nil)
            }
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
