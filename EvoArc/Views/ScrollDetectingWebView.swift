//
//  ScrollDetectingWebView.swift
//  EvoArc
//
//  Created on 2025-09-05.
//

import SwiftUI
import WebKit

struct ScrollDetectingWebView: View {
    let tab: Tab
    @Binding var urlString: String
    @Binding var shouldNavigate: Bool
    @Binding var urlBarVisible: Bool
    let onNavigate: (URL) -> Void
    let autoHideEnabled: Bool
    let tabManager: TabManager
    
    var body: some View {
        ScrollAwareWebView(
            tab: tab,
            urlString: $urlString,
            shouldNavigate: $shouldNavigate,
            onNavigate: onNavigate,
            tabManager: tabManager,
            onScrollChange: { scrollDirection in
                if autoHideEnabled {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        switch scrollDirection {
                        case .up:
                            urlBarVisible = true
                        case .down:
                            urlBarVisible = false
                        case .none:
                            break
                        }
                    }
                }
            }
        )
    }
}

enum ScrollDirection {
    case up
    case down
    case none
}

#if os(iOS)
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
        let configuration = DoHProxy.shared.createConfiguration()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.scrollView.delegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.customUserAgent = BrowserSettings.shared.userAgentString
        
        DispatchQueue.main.async {
            tab.webView = webView
        }
        
        context.coordinator.webView = webView
        context.coordinator.setupObservers()
        
        if let url = tab.url {
            print("Loading initial URL: \(url)")
            let request = URLRequest(url: url)
            webView.load(request)
        } else {
            print("Tab has no URL to load")
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
        
        return BrowserSettings.shared.searchURL(for: string)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, UIScrollViewDelegate {
        var parent: ScrollAwareWebView
        weak var webView: WKWebView?
        private var lastContentOffset: CGFloat = 0
        
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
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            let currentOffset = scrollView.contentOffset.y
            let difference = currentOffset - lastContentOffset
            
            if abs(difference) > 10 { // Threshold to prevent jitter
                if difference > 0 {
                    parent.onScrollChange(.down)
                } else {
                    parent.onScrollChange(.up)
                }
                lastContentOffset = currentOffset
            }
        }
        
        // MARK: - Navigation Delegate Methods
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
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
            let nsError = error as NSError
            if nsError.code == NSURLErrorCancelled {
                print("Navigation cancelled (expected)")
                return
            }
            print("🚨 Navigation failed: \(error)")
            print("🚨 Error code: \(nsError.code)")
            print("🚨 Error domain: \(nsError.domain)")
            print("🚨 Error description: \(nsError.localizedDescription)")
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            print("🎯 Navigation policy requested for: \(navigationAction.request.url?.absoluteString ?? "unknown URL")")
            print("🎯 Navigation type: \(navigationAction.navigationType.rawValue)")
            decisionHandler(.allow)
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
            print("🎯 Response policy requested for: \(navigationResponse.response.url?.absoluteString ?? "unknown URL")")
            if let httpResponse = navigationResponse.response as? HTTPURLResponse {
                print("🎯 HTTP Status: \(httpResponse.statusCode)")
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
            guard let linkURL = elementInfo.linkURL else {
                completionHandler(nil)
                return
            }
            
            let configuration = UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
                let openInNewTab = UIAction(title: "Open in New Tab", image: UIImage(systemName: "plus.square.on.square")) { [weak self] _ in
                    DispatchQueue.main.async {
                        self?.parent.tabManager.createNewTab(url: linkURL)
                    }
                }
                
                let copyLink = UIAction(title: "Copy Link", image: UIImage(systemName: "doc.on.doc")) { _ in
                    UIPasteboard.general.string = linkURL.absoluteString
                }
                
                return UIMenu(title: "", children: [openInNewTab, copyLink])
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
#endif

#if os(macOS)
struct ScrollAwareWebView: NSViewRepresentable {
    let tab: Tab
    @Binding var urlString: String
    @Binding var shouldNavigate: Bool
    let onNavigate: (URL) -> Void
    let tabManager: TabManager
    let onScrollChange: (ScrollDirection) -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeNSView(context: Context) -> WKWebView {
        let configuration = DoHProxy.shared.createConfiguration()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.customUserAgent = BrowserSettings.shared.userAgentString
        
        DispatchQueue.main.async {
            tab.webView = webView
        }
        
        context.coordinator.webView = webView
        context.coordinator.setupObservers()
        context.coordinator.setupScrollObserver()
        
        if let url = tab.url {
            print("Loading initial URL (macOS): \(url)")
            let request = URLRequest(url: url)
            webView.load(request)
        } else {
            print("Tab has no URL to load (macOS)")
        }
        
        return webView
    }
    
    func updateNSView(_ webView: WKWebView, context: Context) {
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
        
        return BrowserSettings.shared.searchURL(for: string)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var parent: ScrollAwareWebView
        weak var webView: WKWebView?
        private var lastContentOffset: CGFloat = 0
        
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
        
        func setupScrollObserver() {
            guard let webView = webView else { return }
            
            // Observe scroll view changes on macOS
            NotificationCenter.default.addObserver(
                forName: NSScrollView.didLiveScrollNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                if let scrollView = notification.object as? NSScrollView,
                   scrollView.documentView == webView {
                    self?.handleScroll(scrollView: scrollView)
                }
            }
        }
        
        private func handleScroll(scrollView: NSScrollView) {
            let currentOffset = scrollView.contentView.bounds.origin.y
            let difference = currentOffset - lastContentOffset
            
            if abs(difference) > 10 {
                if difference > 0 {
                    parent.onScrollChange(.down)
                } else {
                    parent.onScrollChange(.up)
                }
                lastContentOffset = currentOffset
            }
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
            let nsError = error as NSError
            if nsError.code == NSURLErrorCancelled {
                print("Navigation cancelled (expected) - macOS")
                return
            }
            print("🚨 Navigation failed (macOS): \(error)")
            print("🚨 Error code: \(nsError.code)")
            print("🚨 Error domain: \(nsError.domain)")
            print("🚨 Error description: \(nsError.localizedDescription)")
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            print("🎯 Navigation policy requested (macOS) for: \(navigationAction.request.url?.absoluteString ?? "unknown URL")")
            print("🎯 Navigation type (macOS): \(navigationAction.navigationType.rawValue)")
            decisionHandler(.allow)
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
            print("🎯 Response policy requested (macOS) for: \(navigationResponse.response.url?.absoluteString ?? "unknown URL")")
            if let httpResponse = navigationResponse.response as? HTTPURLResponse {
                print("🎯 HTTP Status (macOS): \(httpResponse.statusCode)")
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
        // Note: macOS doesn't have WKContextMenuElementInfo like iOS
        // Context menus on macOS work differently and are handled by the system
        
        deinit {
            if let webView = webView {
                webView.removeObserver(self, forKeyPath: #keyPath(WKWebView.isLoading))
                webView.removeObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress))
                webView.removeObserver(self, forKeyPath: #keyPath(WKWebView.title))
                webView.removeObserver(self, forKeyPath: #keyPath(WKWebView.canGoBack))
                webView.removeObserver(self, forKeyPath: #keyPath(WKWebView.canGoForward))
            }
            NotificationCenter.default.removeObserver(self)
        }
    }
}
#endif
