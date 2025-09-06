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
    
    weak var webView: WKWebView?
    
    init(url: URL? = nil, browserEngine: BrowserEngine? = nil) {
        // Use provided URL or default to homepage
        if let url = url {
            self.url = url
            print("Tab initialized with provided URL: \(url)")
        } else {
            self.url = BrowserSettings.shared.homepageURL
            print("Tab initialized with homepage URL: \(self.url?.absoluteString ?? "nil")")
        }
        
        // Use provided engine or default from settings
        self.browserEngine = browserEngine ?? BrowserSettings.shared.browserEngine
        self.title = "New Tab"
    }
}
