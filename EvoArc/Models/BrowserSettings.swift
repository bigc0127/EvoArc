//
//  BrowserSettings.swift
//  EvoArc
//
//  Created on 2025-09-04.
//

import Foundation
import SwiftUI
import Combine
import UIKit

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

// Navigation button position for iPad when sidebar is hidden
enum NavigationButtonPosition: String, CaseIterable, Identifiable {
    case topLeft = "topLeft"
    case topRight = "topRight"
    case bottomLeft = "bottomLeft"
    case bottomRight = "bottomRight"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .topLeft: return "Top Left"
        case .topRight: return "Top Right"
        case .bottomLeft: return "Bottom Left"
        case .bottomRight: return "Bottom Right"
        }
    }
}

// Ad blocking subscription options
enum AdBlockList: String, CaseIterable, Identifiable {
    case easyList
    case easyListPrivacy
    case peterLowe
    case adAway
    case oneHostsLite
    case stevenBlack
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .easyList: return "EasyList"
        case .easyListPrivacy: return "EasyList Privacy"
        case .peterLowe: return "Peter Lowe's List"
        case .adAway: return "AdAway Hosts"
        case .oneHostsLite: return "1Hosts (Lite)"
        case .stevenBlack: return "StevenBlack (basic)"
        }
    }
    
    var description: String {
        switch self {
        case .easyList: return "General purpose ad blocking rules"
        case .easyListPrivacy: return "Additional privacy protection rules"
        case .peterLowe: return "Compact list of common ad and tracking domains"
        case .adAway: return "Mobile-focused ad and malware domains"
        case .oneHostsLite: return "Lightweight curated host list"
        case .stevenBlack: return "Combined reputable hosts list (large)"
        }
    }
}

class BrowserSettings: ObservableObject {
    static let shared = BrowserSettings()
    
    @Published var useDesktopMode = false {
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
    
    // Search preloading setting (enabled by default)
    @Published var searchPreloadingEnabled: Bool {
        didSet {
            UserDefaults.standard.set(searchPreloadingEnabled, forKey: "searchPreloadingEnabled")
            NotificationCenter.default.post(name: .browserSettingsChanged, object: nil)
        }
    }
    
    // Navigation button position for iPad ARC Like UI
    @Published var navigationButtonPosition: NavigationButtonPosition {
        didSet {
            UserDefaults.standard.set(navigationButtonPosition.rawValue, forKey: "navigationButtonPosition")
            NotificationCenter.default.post(name: .browserSettingsChanged, object: nil)
        }
    }
    
    // Hide navigation buttons when sidebar is hidden on iPad
    @Published var hideNavigationButtonsOnIPad: Bool {
        didSet {
            UserDefaults.standard.set(hideNavigationButtonsOnIPad, forKey: "hideNavigationButtonsOnIPad")
            NotificationCenter.default.post(name: .browserSettingsChanged, object: nil)
        }
    }
    
    // Confirmation for closing pinned tabs
    @Published var confirmClosingPinnedTabs: Bool {
        didSet {
            UserDefaults.standard.set(confirmClosingPinnedTabs, forKey: "confirmClosingPinnedTabs")
            NotificationCenter.default.post(name: .browserSettingsChanged, object: nil)
        }
    }
    
    // Persistence for tab groups and their tabs
    @Published var persistTabGroups: Bool {
        didSet {
            UserDefaults.standard.set(persistTabGroups, forKey: "persistTabGroups")
            NotificationCenter.default.post(name: .browserSettingsChanged, object: nil)
        }
    }
    
    // Hide empty tab groups from the UI
    @Published var hideEmptyTabGroups: Bool {
        didSet {
            UserDefaults.standard.set(hideEmptyTabGroups, forKey: "hideEmptyTabGroups")
            NotificationCenter.default.post(name: .browserSettingsChanged, object: nil)
        }
    }
    
    // MARK: - Ad Blocking Settings
    
    // Enable/disable ad blocking
    @Published var adBlockEnabled: Bool {
        didSet {
            UserDefaults.standard.set(adBlockEnabled, forKey: "adBlockEnabled")
            NotificationCenter.default.post(name: .adBlockSettingsChanged, object: nil)
        }
    }
    
    // Selected ad block lists
    @Published var selectedAdBlockLists: [String] {
        didSet {
            UserDefaults.standard.set(selectedAdBlockLists, forKey: "selectedAdBlockLists")
            NotificationCenter.default.post(name: .adBlockSettingsChanged, object: nil)
        }
    }
    
    // Auto-update lists on launch
    @Published var adBlockAutoUpdateOnLaunch: Bool {
        didSet {
            UserDefaults.standard.set(adBlockAutoUpdateOnLaunch, forKey: "adBlockAutoUpdateOnLaunch")
            NotificationCenter.default.post(name: .adBlockSettingsChanged, object: nil)
        }
    }
    
    // Enable scriptlet that hides JS-inserted ad elements
    @Published var adBlockScriptletEnabled: Bool {
        didSet {
            UserDefaults.standard.set(adBlockScriptletEnabled, forKey: "adBlockScriptletEnabled")
            NotificationCenter.default.post(name: .adBlockSettingsChanged, object: nil)
        }
    }
    
    // Extra-aggressive JS ad blocking that may break some sites
    @Published var adBlockAdvancedJS: Bool {
        didSet {
            UserDefaults.standard.set(adBlockAdvancedJS, forKey: "adBlockAdvancedJS")
            NotificationCenter.default.post(name: .adBlockSettingsChanged, object: nil)
        }
    }
    
    // Hide elements with likely obfuscated/random class names (very aggressive)
    @Published var adBlockObfuscatedClass: Bool {
        didSet {
            UserDefaults.standard.set(adBlockObfuscatedClass, forKey: "adBlockObfuscatedClass")
            NotificationCenter.default.post(name: .adBlockSettingsChanged, object: nil)
        }
    }
    
    // Hide cookie consent banners/popups and related overlays
    @Published var adBlockCookieBanners: Bool {
        didSet {
            UserDefaults.standard.set(adBlockCookieBanners, forKey: "adBlockCookieBanners")
            NotificationCenter.default.post(name: .adBlockSettingsChanged, object: nil)
        }
    }
    
    /// Shows download completion notifications
    @Published var showDownloadNotifications: Bool {
        didSet {
            UserDefaults.standard.set(showDownloadNotifications, forKey: "showDownloadNotifications")
            NotificationCenter.default.post(name: .browserSettingsChanged, object: nil)
        }
    }
    
    /// Automatically opens non-viewable downloads when completed (e.g., zip files)
    @Published var autoOpenDownloads: Bool {
        didSet {
            UserDefaults.standard.set(autoOpenDownloads, forKey: "autoOpenDownloads")
            NotificationCenter.default.post(name: .browserSettingsChanged, object: nil)
        }
    }
    
    private init() {
        // Set default based on device type
        let defaultDesktopMode: Bool
        
        // Check if it's an iPad
        if UIDevice.current.userInterfaceIdiom == .pad {
            defaultDesktopMode = true  // iPad defaults to desktop
        } else {
            defaultDesktopMode = false // iPhone defaults to mobile
        }
        
        // Use stored value if available, otherwise use device default
        if UserDefaults.standard.object(forKey: "useDesktopMode") != nil {
            self.useDesktopMode = UserDefaults.standard.bool(forKey: "useDesktopMode")
        } else {
            self.useDesktopMode = defaultDesktopMode
        }
        
        // Load homepage setting with default to Google
        if let storedHomepage = UserDefaults.standard.string(forKey: "homepage") {
            self.homepage = storedHomepage
        } else {
            self.homepage = "https://start.duckduckgo.com"
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
        
        // Load AdBlock scriptlet toggle (default on)
        if UserDefaults.standard.object(forKey: "adBlockScriptletEnabled") != nil {
            self.adBlockScriptletEnabled = UserDefaults.standard.bool(forKey: "adBlockScriptletEnabled")
        } else {
            self.adBlockScriptletEnabled = true
        }
        
        // Load advanced JS ad blocking (default off)
        if UserDefaults.standard.object(forKey: "adBlockAdvancedJS") != nil {
            self.adBlockAdvancedJS = UserDefaults.standard.bool(forKey: "adBlockAdvancedJS")
        } else {
            self.adBlockAdvancedJS = false
        }
        
        // Load obfuscated class blocking (default off)
        if UserDefaults.standard.object(forKey: "adBlockObfuscatedClass") != nil {
            self.adBlockObfuscatedClass = UserDefaults.standard.bool(forKey: "adBlockObfuscatedClass")
        } else {
            self.adBlockObfuscatedClass = false
        }
        
        // Load cookie banner blocking (default on)
        if UserDefaults.standard.object(forKey: "adBlockCookieBanners") != nil {
            self.adBlockCookieBanners = UserDefaults.standard.bool(forKey: "adBlockCookieBanners")
        } else {
            self.adBlockCookieBanners = true
        }
        
        // Load download notification setting (default on)
        if UserDefaults.standard.object(forKey: "showDownloadNotifications") != nil {
            self.showDownloadNotifications = UserDefaults.standard.bool(forKey: "showDownloadNotifications")
        } else {
            self.showDownloadNotifications = true
        }
        
        // Load auto-open downloads setting (default off)
        if UserDefaults.standard.object(forKey: "autoOpenDownloads") != nil {
            self.autoOpenDownloads = UserDefaults.standard.bool(forKey: "autoOpenDownloads")
        } else {
            self.autoOpenDownloads = false
        }
        
        // Load default search engine setting with default to Google
        if let seString = UserDefaults.standard.string(forKey: "defaultSearchEngine"),
           let se = SearchEngine(rawValue: seString) {
            self.defaultSearchEngine = se
        } else {
            self.defaultSearchEngine = .duckduckgo
        }
        
        // Load custom search template (default template includes {query})
        if let template = UserDefaults.standard.string(forKey: "customSearchTemplate") {
            self.customSearchTemplate = template
        } else {
            self.customSearchTemplate = "https://example.com/search?q={query}"
        }
        
        // Load navigation button position for iPad (default to bottom right)
        if let positionString = UserDefaults.standard.string(forKey: "navigationButtonPosition"),
           let position = NavigationButtonPosition(rawValue: positionString) {
            self.navigationButtonPosition = position
        } else {
            self.navigationButtonPosition = .bottomRight
        }
        
        // Load hide navigation buttons on iPad setting (default false)
        if UserDefaults.standard.object(forKey: "hideNavigationButtonsOnIPad") != nil {
            self.hideNavigationButtonsOnIPad = UserDefaults.standard.bool(forKey: "hideNavigationButtonsOnIPad")
        } else {
            self.hideNavigationButtonsOnIPad = false
        }
        
        // Load confirm closing pinned tabs setting with default to true
        if UserDefaults.standard.object(forKey: "confirmClosingPinnedTabs") != nil {
            self.confirmClosingPinnedTabs = UserDefaults.standard.bool(forKey: "confirmClosingPinnedTabs")
        } else {
            self.confirmClosingPinnedTabs = true
        }
        
        // Load persist tab groups setting with default to false
        if UserDefaults.standard.object(forKey: "persistTabGroups") != nil {
            self.persistTabGroups = UserDefaults.standard.bool(forKey: "persistTabGroups")
        } else {
            self.persistTabGroups = false
        }
        
        // Load hide empty tab groups setting with default to false
        if UserDefaults.standard.object(forKey: "hideEmptyTabGroups") != nil {
            self.hideEmptyTabGroups = UserDefaults.standard.bool(forKey: "hideEmptyTabGroups")
        } else {
            self.hideEmptyTabGroups = false
        }
        
        // Load AdBlock enabled setting (default true)
        if UserDefaults.standard.object(forKey: "adBlockEnabled") != nil {
            self.adBlockEnabled = UserDefaults.standard.bool(forKey: "adBlockEnabled")
        } else {
            self.adBlockEnabled = true
        }
        
        // Load selected ad block lists (default to EasyList + EasyList Privacy)
        if let stored = UserDefaults.standard.array(forKey: "selectedAdBlockLists") as? [String] {
            self.selectedAdBlockLists = stored
        } else {
            self.selectedAdBlockLists = [
                AdBlockList.easyList.rawValue,
                AdBlockList.easyListPrivacy.rawValue,
                AdBlockList.peterLowe.rawValue,
                AdBlockList.adAway.rawValue
            ]
        }
        
        // Auto-update on launch (default true)
        if UserDefaults.standard.object(forKey: "adBlockAutoUpdateOnLaunch") != nil {
            self.adBlockAutoUpdateOnLaunch = UserDefaults.standard.bool(forKey: "adBlockAutoUpdateOnLaunch")
        } else {
            self.adBlockAutoUpdateOnLaunch = true
        }
        
        // Custom list URLs
        if let customLists = UserDefaults.standard.array(forKey: "customAdBlockListURLs") as? [String] {
            self.customAdBlockListURLs = customLists
        } else {
            self.customAdBlockListURLs = []
        }
        
        // Load search preloading setting with default to true (enabled by default)
        if UserDefaults.standard.object(forKey: "searchPreloadingEnabled") != nil {
            self.searchPreloadingEnabled = UserDefaults.standard.bool(forKey: "searchPreloadingEnabled")
        } else {
            self.searchPreloadingEnabled = true
        }
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
        // Fallback to Google
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
                return URL(string: "https://www.google.com/search?q=\(encoded)")
            }
            let urlString = template.replacingOccurrences(of: "{query}", with: encoded)
            if let url = URL(string: urlString),
               let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme),
               url.host != nil {
                return url
            } else {
                return URL(string: "https://www.google.com/search?q=\(encoded)")
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
    
    // MARK: - AdBlock Helpers
    
    /// Convenience accessor for selected lists as enums
    var selectedAdBlockListsEnum: [AdBlockList] {
        selectedAdBlockLists.compactMap { AdBlockList(rawValue: $0) }
    }
    
    // Custom list URLs (uBlock/EasyList compatible text). Users can paste GitHub raw URLs.
    @Published var customAdBlockListURLs: [String] {
        didSet {
            UserDefaults.standard.set(customAdBlockListURLs, forKey: "customAdBlockListURLs")
            NotificationCenter.default.post(name: .adBlockSettingsChanged, object: nil)
        }
    }
}

extension Notification.Name {
    static let browserSettingsChanged = Notification.Name("browserSettingsChanged")
    static let browserEngineChanged = Notification.Name("browserEngineChanged")
    static let adBlockSettingsChanged = Notification.Name("adBlockSettingsChanged")
}
