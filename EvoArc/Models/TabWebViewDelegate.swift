import WebKit
import SwiftUI

#if os(iOS)
import UIKit
#else
import AppKit
#endif

class TabWebViewDelegate: NSObject, WKNavigationDelegate, WKUIDelegate {
    private weak var tab: Tab?
    
    init(tab: Tab) {
        self.tab = tab
    }
    
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        Task { @MainActor in
            tab?.isLoading = true
            tab?.startLoadingTimeout()
        }
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor in
            guard let tab = tab else { return }
            
            tab.isLoading = false
            tab.estimatedProgress = 1.0
            tab.title = webView.title ?? ""
            tab.stopLoadingTimeout()
            
            // Update navigation state
            tab.canGoBack = webView.canGoBack
            tab.canGoForward = webView.canGoForward
            
            // Capture initial thumbnail after a short delay to ensure content is rendered
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
            ThumbnailManager.shared.captureThumbnail(for: webView, tab: tab)
            
            // Set up periodic thumbnail updates
            tab.thumbnailUpdateTimer?.invalidate()
            tab.thumbnailUpdateTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak tab] _ in
                guard let tab = tab else { return }
                ThumbnailManager.shared.captureThumbnail(for: webView, tab: tab)
            }
        }
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in
            tab?.isLoading = false
            tab?.estimatedProgress = 0
            tab?.stopLoadingTimeout()
            tab?.thumbnailUpdateTimer?.invalidate()
            print("Navigation failed: \(error.localizedDescription)")
        }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in
            tab?.isLoading = false
            tab?.estimatedProgress = 0
            tab?.stopLoadingTimeout()
            tab?.thumbnailUpdateTimer?.invalidate()
            print("Navigation failed: \(error.localizedDescription)")
        }
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
        // Update URL as soon as navigation starts
        if let url = navigationAction.request.url {
            await MainActor.run {
                tab?.url = url
                // Show URL in bar for all navigations except homepage
                if url != BrowserSettings.shared.homepageURL {
                    tab?.showURLInBar = true
                }
            }
        }
        return .allow
    }
    
    // MARK: - WKUIDelegate
    
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
    
    #if os(iOS)
    @available(iOS 13.0, *)
    func webView(_ webView: WKWebView, contextMenuConfigurationForElement elementInfo: WKContextMenuElementInfo, completionHandler: @escaping (UIContextMenuConfiguration?) -> Void) {
        // Pass through to allow default context menu
        completionHandler(nil)
    }
    #endif
}
