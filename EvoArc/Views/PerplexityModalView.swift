//
//  PerplexityModalView.swift
//  EvoArc
//
//  Created on 2025-09-06.
//

import SwiftUI
import WebKit
#if os(iOS)
import SafariServices
#else
import AppKit
#endif

struct PerplexityModalView: View {
    let request: PerplexityRequest
    let onDismiss: () -> Void
    
    var body: some View {
        #if os(iOS)
        NavigationView {
            PerplexityWebView(url: request.perplexityURL)
                .navigationTitle("Perplexity")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Done") {
                            onDismiss()
                        }
                    }
                }
        }
        #else
        VStack(spacing: 0) {
            // Header bar
            HStack {
                Text("Perplexity")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // Web view
            PerplexityWebView(url: request.perplexityURL)
        }
        .frame(minWidth: 800, minHeight: 600)
        #endif
    }
}

struct PerplexityWebView: View {
    let url: URL
    
    var body: some View {
        #if os(iOS)
        PerplexityWebViewiOS(url: url)
        #else
        PerplexityWebViewMacOS(url: url)
        #endif
    }
}

#if os(iOS)
struct PerplexityWebViewiOS: UIViewRepresentable {
    let url: URL
    
    func makeUIView(context: Context) -> WKWebView {
        // Use the default configuration to share cookies with main browser
        let configuration = WKWebViewConfiguration()
        // Use default persistent data store to share cookies
        configuration.websiteDataStore = WKWebsiteDataStore.default()
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        
        // Set the same user agent as main browser
        webView.customUserAgent = BrowserSettings.shared.userAgentString
        
        // Set up coordinator references
        context.coordinator.webView = webView
        
        // Load the URL
        let request = URLRequest(url: url)
        webView.load(request)
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        // Check if we need to load a new URL
        if webView.url != url {
            let request = URLRequest(url: url)
            webView.load(request)
        }
        
        // Update user agent if settings changed
        if webView.customUserAgent != BrowserSettings.shared.userAgentString {
            webView.customUserAgent = BrowserSettings.shared.userAgentString
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        weak var webView: WKWebView?
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            print("Started loading Perplexity page")
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("Finished loading Perplexity page")
            
            // Simplified authentication check - only on perplexity.ai domains
            if let url = webView.url, url.host?.contains("perplexity.ai") == true {
                PerplexityManager.shared.refreshAuthenticationStatus()
            }
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            print("Failed to load Perplexity page: \(error.localizedDescription)")
        }
        
        deinit {
            // Cleanup if needed
        }
        
        // Handle new window requests
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            // Open links in the same webview instead of creating new windows
            if navigationAction.targetFrame == nil {
                webView.load(navigationAction.request)
            }
            return nil
        }
        
        // Handle JavaScript alerts
        func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
            DispatchQueue.main.async {
                let alert = UIAlertController(title: "Perplexity", message: message, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                    completionHandler()
                })
                
                // Present from the top-most view controller
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first,
                   let rootViewController = window.rootViewController {
                    var topController = rootViewController
                    while let presentedViewController = topController.presentedViewController {
                        topController = presentedViewController
                    }
                    topController.present(alert, animated: true)
                } else {
                    completionHandler()
                }
            }
        }
        
        func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
            DispatchQueue.main.async {
                let alert = UIAlertController(title: "Perplexity", message: message, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                    completionHandler(true)
                })
                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
                    completionHandler(false)
                })
                
                // Present from the top-most view controller
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first,
                   let rootViewController = window.rootViewController {
                    var topController = rootViewController
                    while let presentedViewController = topController.presentedViewController {
                        topController = presentedViewController
                    }
                    topController.present(alert, animated: true)
                } else {
                    completionHandler(false)
                }
            }
        }
    }
}
#endif

#if os(macOS)
struct PerplexityWebViewMacOS: NSViewRepresentable {
    let url: URL
    
    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        // Use default persistent data store to share cookies with main browser
        configuration.websiteDataStore = WKWebsiteDataStore.default()
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        
        // Set the same user agent as main browser
        webView.customUserAgent = BrowserSettings.shared.userAgentString
        
        // Set up coordinator references
        context.coordinator.webView = webView
        
        // Load the URL
        let request = URLRequest(url: url)
        webView.load(request)
        
        return webView
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {
        // Check if we need to load a new URL
        if nsView.url != url {
            let request = URLRequest(url: url)
            nsView.load(request)
        }
        
        // Update user agent if settings changed
        if nsView.customUserAgent != BrowserSettings.shared.userAgentString {
            nsView.customUserAgent = BrowserSettings.shared.userAgentString
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        weak var webView: WKWebView?
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            print("Started loading Perplexity page")
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("Finished loading Perplexity page")
            
            // Simplified authentication check - only on perplexity.ai domains
            if let url = webView.url, url.host?.contains("perplexity.ai") == true {
                PerplexityManager.shared.refreshAuthenticationStatus()
            }
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            print("Failed to load Perplexity page: \(error.localizedDescription)")
        }
        
        deinit {
            // Cleanup if needed
        }
        
        // Handle new window requests
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            // Open links in the same webview instead of creating new windows
            if navigationAction.targetFrame == nil {
                webView.load(navigationAction.request)
            }
            return nil
        }
        
        // Handle JavaScript alerts
        func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
            let alert = NSAlert()
            alert.messageText = "Perplexity"
            alert.informativeText = message
            alert.addButton(withTitle: "OK")
            alert.runModal()
            completionHandler()
        }
        
        func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
            let alert = NSAlert()
            alert.messageText = "Perplexity"
            alert.informativeText = message
            alert.addButton(withTitle: "OK")
            alert.addButton(withTitle: "Cancel")
            let response = alert.runModal()
            completionHandler(response == .alertFirstButtonReturn)
        }
    }
}
#endif

#Preview {
    PerplexityModalView(
        request: PerplexityRequest(
            action: .summarize,
            url: URL(string: "https://www.example.com")!,
            title: "Example Page"
        ),
        onDismiss: {}
    )
}
