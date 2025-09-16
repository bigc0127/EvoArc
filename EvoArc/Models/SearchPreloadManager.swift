//
//  SearchPreloadManager.swift
//  EvoArc
//
//  Created by Agent on 2025-09-16.
//

import Foundation
import WebKit
import SwiftUI
import Combine

class SearchPreloadManager: NSObject, ObservableObject {
    static let shared = SearchPreloadManager()
    
    @Published var preloadedResults: [String: SearchResult] = [:]
    @Published var isPreloading: Bool = false
    
    private var preloadWebView: WKWebView?
    private var searchQueue: DispatchQueue
    
    struct SearchResult {
        let query: String
        let searchURL: URL
        let firstResultURL: URL?
        let firstResultTitle: String?
        let timestamp: Date
        let searchEngine: SearchEngine
    }
    
    private override init() {
        self.searchQueue = DispatchQueue(label: "search.preload", qos: .utility)
        super.init()
        setupPreloadWebView()
    }
    
    private func setupPreloadWebView() {
        let config = WKWebViewConfiguration()
        config.suppressesIncrementalRendering = true
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        config.preferences.javaScriptCanOpenWindowsAutomatically = false
        
        #if os(iOS)
        config.allowsInlineMediaPlayback = false
        config.allowsPictureInPictureMediaPlayback = false
        #endif
        
        // Set a reasonable user agent to avoid being blocked
        let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
        
        preloadWebView = WKWebView(frame: .zero, configuration: config)
        preloadWebView?.customUserAgent = userAgent
        preloadWebView?.navigationDelegate = self
        
        print("[SearchPreloadManager] WebView configured for search preloading")
    }
    
    func preloadSearch(for query: String) {
        guard !query.isEmpty && query.count > 2 else { return }
        
        // Check if search preloading is enabled
        let settings = BrowserSettings.shared
        guard settings.searchPreloadingEnabled else { return }
        
        // Don't preload if we already have recent results for this query
        if let existing = preloadedResults[query],
           Date().timeIntervalSince(existing.timestamp) < 300 { // 5 minutes cache
            return
        }
        
        // Always use Google for preloading for better stability on macOS
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        guard let searchURL = URL(string: "https://www.google.com/search?q=\(encoded)") else { return }
        
        searchQueue.async { [weak self] in
            self?.performPreload(query: query, searchURL: searchURL, searchEngine: .google)
        }
    }
    
    private func performPreload(query: String, searchURL: URL, searchEngine: SearchEngine) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Prevent duplicate preloading
            guard !self.isPreloading else { 
                print("[SearchPreloadManager] Already preloading, skipping query: \(query)")
                return 
            }
            
            print("[SearchPreloadManager] Starting preload for query: '\(query)' on \(searchEngine)")
            self.isPreloading = true
            
            var request = URLRequest(url: searchURL)
            request.cachePolicy = .useProtocolCachePolicy
            request.timeoutInterval = 10.0
            
            self.preloadWebView?.load(request)
            
            // Store preliminary result immediately
            let preliminaryResult = SearchResult(
                query: query,
                searchURL: searchURL,
                firstResultURL: nil,
                firstResultTitle: nil,
                timestamp: Date(),
                searchEngine: searchEngine
            )
            
            self.preloadedResults[query] = preliminaryResult
            print("[SearchPreloadManager] Stored preliminary result for: \(query)")
            
            // Set a timeout to ensure spinner doesn't get stuck
            DispatchQueue.main.asyncAfter(deadline: .now() + 15.0) {
                if self.isPreloading {
                    print("[SearchPreloadManager] Timeout reached, stopping preload for: \(query)")
                    self.isPreloading = false
                }
            }
        }
    }
    
    func getPreloadedResult(for query: String) -> SearchResult? {
        return preloadedResults[query]
    }
    
    func clearOldResults() {
        let cutoffTime = Date().addingTimeInterval(-1800) // 30 minutes
        preloadedResults = preloadedResults.filter { $0.value.timestamp > cutoffTime }
    }
    
    private func extractFirstSearchResult(from webView: WKWebView, query: String, searchEngine: SearchEngine) {
        let script: String
        
        switch searchEngine {
        case .google:
            script = """
                (function() {
                    // Try multiple selectors for Google's evolving DOM
                    var selectors = [
                        'div.yuRUbf > a',                    // Modern Google results
                        'div[data-ved] h3 a',               // Legacy Google results
                        '.g h3 a',                          // Older Google results
                        'div.g a[href*="http"]:not([href*="google."]):not([href*="youtube.com/results"])'
                    ];
                    
                    for (var i = 0; i < selectors.length; i++) {
                        var firstResult = document.querySelector(selectors[i]);
                        if (firstResult && firstResult.href) {
                            var title = '';
                            if (firstResult.querySelector('h3')) {
                                title = firstResult.querySelector('h3').innerText || firstResult.querySelector('h3').textContent || '';
                            } else {
                                title = firstResult.innerText || firstResult.textContent || '';
                            }
                            return {
                                url: firstResult.href,
                                title: title
                            };
                        }
                    }
                    return null;
                })();
            """
        case .duckduckgo:
            script = """
                (function() {
                    var selectors = [
                        'h2.result__title a',              // DuckDuckGo result titles
                        'article h2 a',                    // Alternative DuckDuckGo layout
                        '.result__a',                      // Direct result links
                        'a[data-testid="result-title-a"]' // Newer DuckDuckGo layout
                    ];
                    
                    for (var i = 0; i < selectors.length; i++) {
                        var firstResult = document.querySelector(selectors[i]);
                        if (firstResult && firstResult.href) {
                            return {
                                url: firstResult.href,
                                title: firstResult.innerText || firstResult.textContent || ''
                            };
                        }
                    }
                    return null;
                })();
            """
        case .bing:
            script = """
                (function() {
                    var selectors = [
                        '.b_algo h2 a',                    // Bing result titles
                        'h2 a[href*="http"]:not([href*="bing."]):not([href*="microsoft."])',
                        '.b_title a',                      // Alternative Bing layout
                        '.b_algo .b_title a'              // Specific Bing structure
                    ];
                    
                    for (var i = 0; i < selectors.length; i++) {
                        var firstResult = document.querySelector(selectors[i]);
                        if (firstResult && firstResult.href) {
                            return {
                                url: firstResult.href,
                                title: firstResult.innerText || firstResult.textContent || ''
                            };
                        }
                    }
                    return null;
                })();
            """
        default:
            // Generic fallback for other search engines
            script = """
                (function() {
                    // Generic selectors that work for most search engines
                    var selectors = [
                        'h3 a[href*="http"]:not([href*="search"]):not([href*="support"]):not([href*="help"])',
                        'h2 a[href*="http"]:not([href*="search"]):not([href*="support"]):not([href*="help"])',
                        'a[href*="http"]:not([href*="search"]):not([href*="support"]):not([href*="help"]):not([href*="about"])',
                        '.result a[href*="http"]',
                        '.search-result a[href*="http"]'
                    ];
                    
                    for (var i = 0; i < selectors.length; i++) {
                        var firstResult = document.querySelector(selectors[i]);
                        if (firstResult && firstResult.href) {
                            return {
                                url: firstResult.href,
                                title: firstResult.innerText || firstResult.textContent || ''
                            };
                        }
                    }
                    return null;
                })();
            """
        }
        
        print("[SearchPreloadManager] Executing JavaScript for \(searchEngine) search results")
        webView.evaluateJavaScript(script) { [weak self] result, error in
            DispatchQueue.main.async {
                defer { 
                    print("[SearchPreloadManager] JavaScript execution completed, setting isPreloading = false")
                    self?.isPreloading = false 
                } // Always reset loading state
                
                if let error = error {
                    print("[SearchPreloadManager] JavaScript execution error: \(error.localizedDescription)")
                    return
                }
                
                guard let self = self else { return }
                
                guard let resultDict = result as? [String: String] else {
                    print("[SearchPreloadManager] JavaScript returned unexpected result type: \(type(of: result))")
                    if let result = result {
                        print("[SearchPreloadManager] Actual result: \(result)")
                    }
                    return
                }
                
                guard let urlString = resultDict["url"], let url = URL(string: urlString) else {
                    print("[SearchPreloadManager] No valid URL found in result: \(resultDict)")
                    return
                }
                
                let title = resultDict["title"] ?? ""
                print("[SearchPreloadManager] Successfully extracted first result: \(title) - \(url.absoluteString)")
                
                // Update the preloaded result with first link information
                if var existingResult = self.preloadedResults[query] {
                    existingResult = SearchResult(
                        query: existingResult.query,
                        searchURL: existingResult.searchURL,
                        firstResultURL: url,
                        firstResultTitle: title.isEmpty ? nil : title,
                        timestamp: existingResult.timestamp,
                        searchEngine: existingResult.searchEngine
                    )
                    self.preloadedResults[query] = existingResult
                    print("[SearchPreloadManager] Updated preloaded result for: \(query)")
                    
                    // Now preload the first result page
                    self.preloadFirstResult(url: url)
                } else {
                    print("[SearchPreloadManager] No existing result found to update for query: \(query)")
                }
            }
        }
    }
    
    private func preloadFirstResult(url: URL) {
        // Create a separate request to preload the first result page
        // This will populate the browser cache
        let request = URLRequest(url: url)
        URLSession.shared.dataTask(with: request) { _, _, _ in
            // We just want to populate the cache, so we don't need to handle the response
        }.resume()
    }
}

// MARK: - WKNavigationDelegate
extension SearchPreloadManager: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("[SearchPreloadManager] WebView finished loading: \(webView.url?.absoluteString ?? "unknown")")
        
        // Extract the query from the current URL
        guard let currentURL = webView.url,
              let query = extractSearchQuery(from: currentURL) else {
            print("[SearchPreloadManager] Could not extract query from URL: \(webView.url?.absoluteString ?? "nil")")
            isPreloading = false
            return
        }
        
        print("[SearchPreloadManager] Extracted query: '\(query)' from URL")
        
        // Wait a bit for JavaScript to load content
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self = self,
                  let existingResult = self.preloadedResults[query] else { 
                print("[SearchPreloadManager] No existing result for query: \(query)")
                return 
            }
            
            print("[SearchPreloadManager] Starting JavaScript extraction for: \(query)")
            self.extractFirstSearchResult(from: webView, query: query, searchEngine: existingResult.searchEngine)
        }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("[SearchPreloadManager] WebView navigation failed: \(error.localizedDescription)")
        DispatchQueue.main.async { [weak self] in
            self?.isPreloading = false
        }
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        print("[SearchPreloadManager] WebView provisional navigation failed: \(error.localizedDescription)")
        DispatchQueue.main.async { [weak self] in
            self?.isPreloading = false
        }
    }
    
    private func extractSearchQuery(from url: URL) -> String? {
        guard let host = url.host else { return nil }
        
        func value(for parameter: String) -> String? {
            guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                  let queryItems = components.queryItems else { return nil }
            return queryItems.first(where: { $0.name == parameter })?.value
        }
        
        // Google: https://www.google.com/search?q=...
        if host.contains("google.") {
            return value(for: "q")
        }
        
        // DuckDuckGo: https://duckduckgo.com/?q=...
        if host.contains("duckduckgo.") {
            return value(for: "q")
        }
        
        // Bing: https://www.bing.com/search?q=...
        if host.contains("bing.") {
            return value(for: "q")
        }
        
        // Yahoo: https://search.yahoo.com/search?p=...
        if host.contains("yahoo.") {
            return value(for: "p")
        }
        
        // Other engines: try common parameters
        return value(for: "q") ?? value(for: "query") ?? value(for: "p") ?? value(for: "text")
    }
}