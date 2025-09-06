//
//  WebView.swift
//  EvoArc
//
//  Created on 2025-09-04.
//

import SwiftUI
import WebKit

#if os(iOS)
import UIKit

struct WebView: UIViewRepresentable {
    @ObservedObject var tab: Tab
    @Binding var urlString: String
    @Binding var shouldNavigate: Bool
    let onNavigate: (URL) -> Void
    @StateObject private var settings = BrowserSettings.shared
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> WKWebView {
        // Use basic configuration to test WebView loading
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
            // We only update the UI state when navigation actually starts
            Task { @MainActor in
                if let url = webView.url {
                    parent.tab.url = url
                    parent.urlString = url.absoluteString
                    parent.onNavigate(url)
                }
            }
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            Task { @MainActor in
                if let url = webView.url {
                    parent.tab.url = url
                    parent.urlString = url.absoluteString
                }
            }
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            // Handle canceled requests (error code -999) gracefully
            let nsError = error as NSError
            if nsError.code == NSURLErrorCancelled {
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
        // Use basic configuration to test WebView loading
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
            if let url = webView.url {
                parent.tab.url = url
                parent.urlString = url.absoluteString
                parent.onNavigate(url)
            }
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            if let url = webView.url {
                parent.tab.url = url
                parent.urlString = url.absoluteString
            }
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            // Handle canceled requests (error code -999) gracefully
            let nsError = error as NSError
            if nsError.code == NSURLErrorCancelled {
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
