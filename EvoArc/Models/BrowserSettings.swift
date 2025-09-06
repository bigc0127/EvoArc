//
//  BrowserSettings.swift
//  EvoArc
//
//  Created on 2025-09-04.
//

import Foundation
import SwiftUI
import Combine
#if os(iOS)
import UIKit
#endif

// Browser engine available on all platforms
enum BrowserEngine: String, CaseIterable {
    case webkit = "webkit"
    case blink = "blink"
    
    var displayName: String {
        switch self {
        case .webkit: return "Safari Mode"
        case .blink: return "Chrome Mode"
        }
    }
}

// Default search engine selection
enum SearchEngine: String, CaseIterable, Identifiable {
    // Private engines
    case qwant = "qwant"
    case startpage = "startpage"
    case presearch = "presearch"
    case duckduckgo = "duckduckgo"
    case ecosia = "ecosia"
    
    // Less private engines
    case perplexity = "perplexity"
    case google = "google"
    case bing = "bing"
    case yahoo = "yahoo"
    
    // Custom
    case custom = "custom"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        // Private
        case .qwant: return "Qwant"
        case .startpage: return "Startpage"
        case .presearch: return "Presearch"
        case .duckduckgo: return "DuckDuckGo"
        case .ecosia: return "Ecosia"
        // Less private
        case .perplexity: return "Perplexity"
        case .google: return "Google"
        case .bing: return "Bing"
        case .yahoo: return "Yahoo"
        // Custom
        case .custom: return "Custom"
        }
    }
}

#if os(macOS)
enum TabDrawerPosition: String, CaseIterable {
    case left = "left"
    case right = "right"
    
    var displayName: String {
        switch self {
        case .left: return "Left"
        case .right: return "Right"
        }
    }
}
#endif

class BrowserSettings: ObservableObject {
    static let shared = BrowserSettings()
    
    @Published var useDesktopMode: Bool {
        didSet {
            UserDefaults.standard.set(useDesktopMode, forKey: "useDesktopMode")
            NotificationCenter.default.post(name: .browserSettingsChanged, object: nil)
        }
    }
    
    @Published var homepage: String {
        didSet {
            UserDefaults.standard.set(homepage, forKey: "homepage")
            NotificationCenter.default.post(name: .browserSettingsChanged, object: nil)
        }
    }
    
    @Published var autoHideURLBar: Bool {
        didSet {
            UserDefaults.standard.set(autoHideURLBar, forKey: "autoHideURLBar")
            NotificationCenter.default.post(name: .browserSettingsChanged, object: nil)
        }
    }
    
    // When enabled, external search URLs (e.g., from Spotlight or other apps)
    // will be redirected to the user's default search engine within EvoArc.
    @Published var redirectExternalSearches: Bool {
        didSet {
            UserDefaults.standard.set(redirectExternalSearches, forKey: "redirectExternalSearches")
            NotificationCenter.default.post(name: .browserSettingsChanged, object: nil)
        }
    }
    
    @Published var browserEngine: BrowserEngine {
        didSet {
            UserDefaults.standard.set(browserEngine.rawValue, forKey: "browserEngine")
            NotificationCenter.default.post(name: .browserEngineChanged, object: nil)
        }
    }
    
    // Default search engine preference (across platforms)
    @Published var defaultSearchEngine: SearchEngine {
        didSet {
            UserDefaults.standard.set(defaultSearchEngine.rawValue, forKey: "defaultSearchEngine")
            NotificationCenter.default.post(name: .browserSettingsChanged, object: nil)
        }
    }
    
    // Custom search engine template. Must include {query}
    @Published var customSearchTemplate: String {
        didSet {
            UserDefaults.standard.set(customSearchTemplate, forKey: "customSearchTemplate")
            NotificationCenter.default.post(name: .browserSettingsChanged, object: nil)
        }
    }
    
    #if os(macOS)
    @Published var tabDrawerPosition: TabDrawerPosition {
        didSet {
            UserDefaults.standard.set(tabDrawerPosition.rawValue, forKey: "tabDrawerPosition")
            NotificationCenter.default.post(name: .browserSettingsChanged, object: nil)
        }
    }
    #endif
    
    private init() {
        // Set default based on device type
        let defaultDesktopMode: Bool
        
        #if os(iOS)
        // Check if it's an iPad
        if UIDevice.current.userInterfaceIdiom == .pad {
            defaultDesktopMode = true  // iPad defaults to desktop
        } else {
            defaultDesktopMode = false // iPhone defaults to mobile
        }
        #else
        // macOS always defaults to desktop
        defaultDesktopMode = true
        #endif
        
        // Use stored value if available, otherwise use device default
        if UserDefaults.standard.object(forKey: "useDesktopMode") != nil {
            self.useDesktopMode = UserDefaults.standard.bool(forKey: "useDesktopMode")
        } else {
            self.useDesktopMode = defaultDesktopMode
        }
        
        // Load homepage setting with default to Qwant
        if let storedHomepage = UserDefaults.standard.string(forKey: "homepage") {
            self.homepage = storedHomepage
        } else {
            self.homepage = "https://www.qwant.com"
        }
        
        // Load auto-hide URL bar setting with default to true
        if UserDefaults.standard.object(forKey: "autoHideURLBar") != nil {
            self.autoHideURLBar = UserDefaults.standard.bool(forKey: "autoHideURLBar")
        } else {
            self.autoHideURLBar = true
        }
        
        // Load redirect external searches toggle with default to false
        if UserDefaults.standard.object(forKey: "redirectExternalSearches") != nil {
            self.redirectExternalSearches = UserDefaults.standard.bool(forKey: "redirectExternalSearches")
        } else {
            self.redirectExternalSearches = false
        }
        
        // Load browser engine setting with default to webkit (all platforms)
        if let engineString = UserDefaults.standard.string(forKey: "browserEngine"),
           let engine = BrowserEngine(rawValue: engineString) {
            self.browserEngine = engine
        } else {
            self.browserEngine = .webkit
        }
        
        // Load default search engine setting with default to Qwant
        if let seString = UserDefaults.standard.string(forKey: "defaultSearchEngine"),
           let se = SearchEngine(rawValue: seString) {
            self.defaultSearchEngine = se
        } else {
            self.defaultSearchEngine = .qwant
        }
        
        // Load custom search template (default template includes {query})
        if let template = UserDefaults.standard.string(forKey: "customSearchTemplate") {
            self.customSearchTemplate = template
        } else {
            self.customSearchTemplate = "https://example.com/search?q={query}"
        }
        
        #if os(macOS)
        // Load tab drawer position setting with default to left
        if let positionString = UserDefaults.standard.string(forKey: "tabDrawerPosition"),
           let position = TabDrawerPosition(rawValue: positionString) {
            self.tabDrawerPosition = position
        } else {
            self.tabDrawerPosition = .left
        }
        #endif
    }
    
    var userAgentString: String {
        if useDesktopMode {
            // Desktop Safari user agent
            return "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
        } else {
            // Mobile Safari user agent
            return "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
        }
    }
    
    var homepageURL: URL? {
        // Ensure the homepage has a valid scheme
        if let url = URL(string: homepage) {
            return url
        }
        // Try adding https:// if no scheme
        if !homepage.contains("://") {
            return URL(string: "https://\(homepage)")
        }
        // Fallback to Qwant
        return URL(string: "https://www.qwant.com")
    }
    
    // Build a search URL for the current default search engine
    func searchURL(for query: String) -> URL? {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        switch defaultSearchEngine {
        // Private
        case .qwant:
            return URL(string: "https://www.qwant.com/?q=\(encoded)")
        case .startpage:
            return URL(string: "https://www.startpage.com/sp/search?q=\(encoded)")
        case .presearch:
            return URL(string: "https://presearch.com/search?q=\(encoded)")
        case .duckduckgo:
            return URL(string: "https://duckduckgo.com/?q=\(encoded)")
        case .ecosia:
            return URL(string: "https://www.ecosia.org/search?q=\(encoded)")
        // Less private
        case .perplexity:
            return URL(string: "https://www.perplexity.ai/search?q=\(encoded)")
        case .google:
            return URL(string: "https://www.google.com/search?q=\(encoded)")
        case .bing:
            return URL(string: "https://www.bing.com/search?q=\(encoded)")
        case .yahoo:
            return URL(string: "https://search.yahoo.com/search?p=\(encoded)")
        // Custom
        case .custom:
            let template = customSearchTemplate.trimmingCharacters(in: .whitespacesAndNewlines)
            guard template.contains("{query}") else {
                return URL(string: "https://www.qwant.com/?q=\(encoded)")
            }
            let urlString = template.replacingOccurrences(of: "{query}", with: encoded)
            if let url = URL(string: urlString),
               let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme),
               url.host != nil {
                return url
            } else {
                return URL(string: "https://www.qwant.com/?q=\(encoded)")
            }
        }
    }
    
    // Validation helpers for custom template
    var isCustomSearchTemplateValid: Bool {
        return customSearchTemplateErrorMessage == nil
    }
    
    var customSearchTemplateErrorMessage: String? {
        let template = customSearchTemplate.trimmingCharacters(in: .whitespacesAndNewlines)
        if !template.contains("{query}") {
            return "Template must include {query} placeholder."
        }
        let replaced = template.replacingOccurrences(of: "{query}", with: "test")
        guard let url = URL(string: replaced) else {
            return "Template must be a valid URL."
        }
        guard let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme) else {
            return "URL must use http or https."
        }
        guard url.host != nil else {
            return "URL must include a hostname."
        }
        return nil
    }
    
    func exampleCustomSearchURL() -> URL? {
        let template = customSearchTemplate.trimmingCharacters(in: .whitespacesAndNewlines)
        let encoded = ("example query").addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "example"
        guard template.contains("{query}") else { return nil }
        let urlString = template.replacingOccurrences(of: "{query}", with: encoded)
        return URL(string: urlString)
    }
}

extension Notification.Name {
    static let browserSettingsChanged = Notification.Name("browserSettingsChanged")
    static let browserEngineChanged = Notification.Name("browserEngineChanged")
}
