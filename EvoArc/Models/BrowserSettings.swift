//
//  BrowserSettings.swift
//  EvoArc
//
//  Created on 2025-09-04.
//
//  This file defines ALL user-configurable settings for the EvoArc browser.
//  It uses the Singleton pattern to provide a single, shared settings instance
//  throughout the app. All settings automatically persist to UserDefaults.
//
//  Key responsibilities:
//  1. Define available options (browser engines, search engines, etc.)
//  2. Store user preferences with @Published for automatic UI updates
//  3. Persist settings to UserDefaults automatically
//  4. Provide computed properties for derived values (user agent strings, search URLs)
//  5. Broadcast changes via NotificationCenter for non-SwiftUI components
//

// MARK: - Import Explanation for Beginners
import Foundation  // Core Swift framework - provides UserDefaults for persistence
import SwiftUI    // Apple's UI framework - provides ObservableObject and @Published
import Combine    // Reactive programming framework - used by @Published under the hood
import UIKit      // iOS/iPadOS UI framework - provides UIDevice for platform detection

// MARK: - Configuration Enums
// These enums define the available options for various settings.
// They're used throughout the settings UI to present choices to the user.
//
// Swift Enum Concepts:
// - String: The enum has a String raw value (useful for persistence)
// - CaseIterable: Automatically provides an `allCases` array of all enum values
// - Identifiable: Makes the enum usable in SwiftUI ForEach loops

/// Defines the available browser rendering engines.
///
/// **Purpose**: EvoArc supports two rendering engines:
/// - **WebKit** (Safari's engine): iOS's native engine, fast and energy-efficient
/// - **Blink** (Chrome's engine): Google's engine for cross-platform compatibility
///
/// **Raw Value**: String makes it easy to save/load from UserDefaults.
///
/// **CaseIterable**: Provides `BrowserEngine.allCases` for settings UI.
///
/// **Use case**: Users can switch engines in settings to test compatibility
/// or performance differences.
enum BrowserEngine: String, CaseIterable {
    case webkit = "webkit"  // Apple's WebKit engine (WKWebView)
    case blink = "blink"    // Google's Blink engine (experimental via Chromium wrapper)
    
    /// Human-readable name for display in settings UI.
    ///
    /// **Computed Property**: Calculates the display name each time it's accessed.
    var displayName: String {
        switch self {
        case .webkit: return "Safari Mode"  // More familiar to users than "WebKit"
        case .blink: return "Chrome Mode"  // More familiar than "Blink"
        }
    }
}

/// Defines the available search engines for the browser.
///
/// **Purpose**: Users can choose their preferred search engine for the URL bar.
/// When they type a query (not a URL), EvoArc uses this engine to search.
///
/// **Privacy Focus**: Engines are ordered by privacy-friendliness, with private
/// engines like Qwant and DuckDuckGo first, followed by mainstream engines.
///
/// **Identifiable Protocol**: Required for SwiftUI's Picker and ForEach.
/// We use the `rawValue` (String) as the `id`.
///
/// **String Raw Value**: Makes persistence to UserDefaults trivial.
enum SearchEngine: String, CaseIterable, Identifiable {
    // MARK: Privacy-focused search engines
    // These engines don't track users, sell data, or build advertising profiles.
    case qwant = "qwant"            // French search engine, respects privacy
    case startpage = "startpage"    // Google results without tracking
    case presearch = "presearch"    // Decentralized blockchain-based search
    case duckduckgo = "duckduckgo"  // Popular privacy-focused search
    case ecosia = "ecosia"          // Plants trees with ad revenue, privacy-friendly
    
    // MARK: Mainstream search engines
    // These engines provide excellent results but collect user data for advertising.
    case perplexity = "perplexity"  // AI-powered search engine
    case google = "google"          // Most popular, but tracks heavily
    case bing = "bing"              // Microsoft's search engine
    case yahoo = "yahoo"            // Yahoo search (powered by Bing)
    
    // MARK: User-defined custom engine
    case custom = "custom"          // User provides their own search URL template
    
    /// The unique identifier for SwiftUI's Identifiable protocol.
    ///
    /// **Identifiable Requirement**: SwiftUI's ForEach and Picker require
    /// conforming types to have a unique `id`. We use the raw value (String).
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

/// Defines where navigation buttons appear on iPad when the sidebar is hidden.
///
/// **iPad-specific**: On iPad, when the Arc-like sidebar is hidden, users can
/// optionally display floating back/forward navigation buttons. This enum
/// controls where those buttons appear.
///
/// **Why this matters**: Different users have different preferences - left-handed
/// users might prefer buttons on the left, right-handed on the right, etc.
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

/// Defines the available ad blocking filter lists.
///
/// **Purpose**: EvoArc supports multiple ad blocking lists that users can enable.
/// Each list is maintained by a different community and targets different types
/// of ads, trackers, and annoyances.
///
/// **How it works**: These filter lists contain rules (like "block requests to
/// ads.example.com") that EvoArc downloads and compiles into WKWebView content
/// blockers. Multiple lists can be active simultaneously.
///
/// **List quality**: These are well-maintained, reputable lists used by millions.
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

// MARK: - BrowserSettings Class
// This is the central settings store for EvoArc. It manages all user preferences
// and handles persistence to UserDefaults.
//
// Key Design Patterns:
// 1. **Singleton**: Only one instance exists app-wide (shared)
// 2. **ObservableObject**: SwiftUI views can observe changes
// 3. **Property Observers (didSet)**: Automatically save to UserDefaults when changed
// 4. **NotificationCenter Broadcasting**: Notify non-SwiftUI components of changes
//
// Swift Concepts:
// - @Published: Property wrapper that notifies observers when value changes
// - didSet: Observer that runs after a property's value is set
// - private init(): Prevents external code from creating additional instances
// - UserDefaults: iOS's key-value storage for app preferences (persists between launches)

/// The central settings manager for EvoArc.
///
/// **Singleton Pattern**: Access via `BrowserSettings.shared`. Only one instance exists.
///
/// **ObservableObject**: SwiftUI views that reference this (via @StateObject or
/// @ObservedObject) automatically update when any @Published property changes.
///
/// **Persistence**: Every setting automatically saves to UserDefaults when changed.
/// The `didSet` observer on each @Published property handles this.
///
/// **Notifications**: Settings changes are broadcast via NotificationCenter so
/// non-SwiftUI components (like WebView managers) can react to changes.
///
/// **Initialization**: All settings are loaded from UserDefaults in the `init()`,
/// with sensible defaults if no saved value exists.
class BrowserSettings: ObservableObject {
    
    /// The shared singleton instance.
    ///
    /// **Singleton Pattern**: This is the only instance of BrowserSettings.
    /// All parts of the app use this same instance via `BrowserSettings.shared`.
    ///
    /// **Why singleton?**: Settings should be consistent app-wide. Having multiple
    /// instances would lead to conflicting preferences.
    static let shared = BrowserSettings()
    
    // MARK: - General Browser Settings
    
    /// Whether to request desktop websites instead of mobile versions.
    ///
    /// **@Published Explanation**: This property wrapper makes the property observable.
    /// When `useDesktopMode` changes, SwiftUI views observing BrowserSettings
    /// automatically re-render.
    ///
    /// **didSet Explanation**: This code block runs AFTER the property's value is set.
    /// We use it to:
    /// 1. Save the new value to UserDefaults (persistent storage)
    /// 2. Broadcast a notification so other app components can react
    ///
    /// **Default**: iPad defaults to true (desktop mode), iPhone to false (mobile mode).
    /// The actual default is set in `init()`.
    ///
    /// **Use case**: iPad has more screen space, so desktop sites work better.
    @Published var useDesktopMode = false {
        didSet {
            // Save to UserDefaults so the setting persists between app launches
            UserDefaults.standard.set(useDesktopMode, forKey: "useDesktopMode")
            // Broadcast notification so WebView managers can update user agent strings
            NotificationCenter.default.post(name: .browserSettingsChanged, object: nil)
        }
    }
    
    
    /// The user's homepage URL (opened in new tabs).
    ///
    /// **Default**: DuckDuckGo's start page (set in `init()`).
    ///
    /// **Type**: String instead of URL because users can type invalid URLs.
    /// The `homepageURL` computed property handles validation and fallbacks.
    ///
    /// **Use case**: New tabs open this URL by default.
    @Published var homepage: String {
        didSet {
            UserDefaults.standard.set(homepage, forKey: "homepage")
            NotificationCenter.default.post(name: .browserSettingsChanged, object: nil)
        }
    }
    
    /// Whether the URL bar automatically hides when scrolling down.
    ///
    /// **iPhone-specific**: This setting only affects iPhone layouts.
    /// iPad uses a different UI (sidebar) that doesn't have this feature.
    ///
    /// **Default**: true (URL bar hides for more screen space).
    ///
    /// **UX**: When enabled, the URL bar hides when scrolling down and shows
    /// when scrolling up or tapping the bottom of the screen.
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
    
    /// Provides haptic feedback when bottom bar reveals (light tap)
    /// Only applies on iPhone when auto-hide is enabled
    @Published var bottomBarHaptics: Bool {
        didSet {
            UserDefaults.standard.set(bottomBarHaptics, forKey: "bottomBarHaptics")
            NotificationCenter.default.post(name: .browserSettingsChanged, object: nil)
        }
    }
    
    // MARK: - Download Settings
    
    /// Controls whether downloads are enabled in the app
    ///
    /// **Default**: false (disabled) for App Store compliance
    ///
    /// **Purpose**: When enabled, users can download files from websites.
    /// Each download requires per-file confirmation (Brave-style approach).
    @Published var downloadsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(downloadsEnabled, forKey: "downloadsEnabled")
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
        
        // Load bottom bar haptics setting (default on)
        if UserDefaults.standard.object(forKey: "bottomBarHaptics") != nil {
            self.bottomBarHaptics = UserDefaults.standard.bool(forKey: "bottomBarHaptics")
        } else {
            self.bottomBarHaptics = true
        }
        
        // Load downloads enabled setting (default OFF for App Store compliance)
        if UserDefaults.standard.object(forKey: "downloadsEnabled") != nil {
            self.downloadsEnabled = UserDefaults.standard.bool(forKey: "downloadsEnabled")
        } else {
            self.downloadsEnabled = false
        }
    }
    
    // MARK: - Computed Properties (Derived Values)
    // These properties calculate their values based on other settings.
    // They don't store data - they compute it on-demand.
    
    /// Generates the appropriate user agent string based on desktop mode setting.
    ///
    /// **User Agent Explanation**: The user agent is a string that browsers send
    /// to websites to identify themselves. Websites use this to serve desktop or
    /// mobile versions of their site.
    ///
    /// **Computed Property**: The `var name: Type { }` syntax defines a read-only
    /// computed property. It calculates the value each time it's accessed.
    ///
    /// **Safari Masquerading**: EvoArc identifies as Safari (not a custom browser)
    /// to maximize compatibility. Websites trust Safari and serve it well-tested content.
    ///
    /// **Example Values**:
    /// - Desktop: "Mozilla/5.0 (Macintosh...) Safari/605.1.15"
    /// - Mobile: "Mozilla/5.0 (iPhone...) Mobile/15E148 Safari/604.1"
    var userAgentString: String {
        if useDesktopMode {
            // Desktop Safari user agent (macOS)
            // Websites see this as Safari on Mac and serve desktop layouts
            return "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
        } else {
            // Mobile Safari user agent (iOS)
            // Websites see this as Safari on iPhone and serve mobile layouts
            return "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
        }
    }
    
    /// Converts the homepage string into a valid URL.
    ///
    /// **Purpose**: The `homepage` property is a String (users can type anything),
    /// but we need a proper URL to load. This computed property validates and
    /// fixes common user mistakes.
    ///
    /// **Validation Steps**:
    /// 1. Try parsing the string as-is
    /// 2. If that fails and there's no "://", add "https://" prefix
    /// 3. If all else fails, return Qwant as a safe fallback
    ///
    /// **Optional Return**: Returns `URL?` (optional) because even with validation,
    /// the URL might be invalid. Callers must handle the nil case.
    ///
    /// **Example Transformations**:
    /// - "google.com" → "https://google.com"
    /// - "https://example.com" → unchanged
    /// - "invalid!!!" → fallback to Qwant
    var homepageURL: URL? {
        // Step 1: Try parsing as-is
        if let url = URL(string: homepage) {
            return url
        }
        // Step 2: Try adding https:// prefix if no scheme exists
        if !homepage.contains("://") {
            return URL(string: "https://\(homepage)")
        }
        // Step 3: Fallback to a known-good URL (Qwant)
        return URL(string: "https://www.qwant.com")
    }
    
    // MARK: - Search URL Building
    
    /// Builds a search URL for the given query using the currently selected search engine.
    ///
    /// **Purpose**: When the user types a query (not a URL) in the address bar,
    /// this function converts it into a search URL for the appropriate engine.
    ///
    /// **URL Encoding**: The query is percent-encoded to handle special characters
    /// (spaces become %20, etc.). This is required for URLs.
    ///
    /// **Custom Engine**: If the user selected "custom", we use their template
    /// (which must contain "{query}") and replace it with the encoded query.
    ///
    /// **Fallback**: If the custom template is invalid, falls back to Google.
    ///
    /// **Parameters**:
    /// - query: The user's search query (e.g., "swift programming")
    ///
    /// **Returns**: A complete search URL, or nil if construction failed
    ///
    /// **Example**:
    /// ```swift
    /// // If defaultSearchEngine is .google:
    /// searchURL(for: "swift tips")
    /// // Returns: https://www.google.com/search?q=swift%20tips
    /// ```
    func searchURL(for query: String) -> URL? {
        // Percent-encode the query for URL safety
        // Example: "swift programming" becomes "swift%20programming"
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

// MARK: - Notification Names

/// Notification names for broadcasting setting changes.
/// BrowserSettings posts these notifications.
/// Other parts of the app (WebView managers, ad blocker, etc.) can observe
/// these notifications and update accordingly.
///
/// **Pattern**: Using static constants prevents typos and provides autocomplete.
///
/// **SwiftUI Alternative**: SwiftUI views don't need these - they use @Published
/// and ObservableObject automatically. These are for UIKit/non-SwiftUI code.
extension Notification.Name {
    /// Posted when any general browser setting changes (desktop mode, homepage, etc.).
    static let browserSettingsChanged = Notification.Name("browserSettingsChanged")
    
    /// Posted specifically when the browser engine changes (WebKit ↔ Blink).
    /// This has its own notification because engine changes require special handling.
    static let browserEngineChanged = Notification.Name("browserEngineChanged")
    
    /// Posted when any ad blocking setting changes (lists, enabled state, etc.).
    /// AdBlockManager observes this to recompile content blocker rules.
    static let adBlockSettingsChanged = Notification.Name("adBlockSettingsChanged")
}

// MARK: - Architecture Summary for Beginners
// ============================================
//
// BrowserSettings is the CENTRAL CONFIGURATION HUB for EvoArc. Here's how it works:
//
// 1. SINGLETON PATTERN:
//    ┌────────────────────────────────────┐
//    │  BrowserSettings.shared       │  ← Only one instance exists
//    │  (singleton)                  │
//    └────────────────────────────────────┘
//             │
//             ├── ContentView observes
//             ├── SettingsView observes
//             ├── WebView managers observe via NotificationCenter
//             └── All access the same instance
//
// 2. PROPERTY WRAPPER CHAIN (@Published + didSet):
//
//    User changes setting in UI
//         ↓
//    @Published property updates
//         ↓
//    didSet observer runs:
//      1. Save to UserDefaults (persistence)
//      2. Post NotificationCenter notification
//         ↓                        ↓
//    SwiftUI views re-render    Non-SwiftUI components react
//
// 3. PERSISTENCE STRATEGY:
//
//    UserDefaults.standard
//    ├─ Key-value storage
//    ├─ Automatically persists to disk
//    ├─ Survives app restarts
//    ├─ Simple types only (String, Bool, Int, Array)
//    └─ NOT secure (don't store passwords here!)
//
// 4. INITIALIZATION PATTERN:
//
//    private init() {
//      // For each setting:
//      if let stored = UserDefaults.standard.value(forKey: "key") {
//          self.property = stored  // Restore saved value
//      } else {
//          self.property = defaultValue  // First launch: use default
//      }
//    }
//
//    Why private? Prevents external code from creating multiple instances.
//
// 5. COMPUTED PROPERTIES vs STORED PROPERTIES:
//
//    Stored Properties (@Published):
//    - Actually store a value in memory
//    - Persist to UserDefaults
//    - Example: useDesktopMode, homepage
//
//    Computed Properties (var name: Type { }):
//    - Calculate value on-demand
//    - Don't store anything
//    - Example: userAgentString, homepageURL
//
// 6. ENUM PATTERN FOR OPTIONS:
//
//    enum SearchEngine: String, CaseIterable, Identifiable {
//        case google = "google"
//        case duckduckgo = "duckduckgo"
//        // ...
//    }
//
//    Benefits:
//    - Type-safe (can't have invalid values)
//    - Autocomplete in Xcode
//    - CaseIterable provides array of all options for UI
//    - String raw value makes persistence easy
//
// 7. SETTINGS CATEGORIES:
//
//    General:
//    ├─ useDesktopMode
//    ├─ homepage
//    ├─ autoHideURLBar
//    └─ browserEngine
//
//    Search:
//    ├─ defaultSearchEngine
//    ├─ customSearchTemplate
//    └─ searchPreloadingEnabled
//
//    iPad UI:
//    ├─ navigationButtonPosition
//    └─ hideNavigationButtonsOnIPad
//
//    Tab Management:
//    ├─ confirmClosingPinnedTabs
//    ├─ persistTabGroups
//    └─ hideEmptyTabGroups
//
//    Ad Blocking:
//    ├─ adBlockEnabled
//    ├─ selectedAdBlockLists
//    ├─ adBlockScriptletEnabled
//    ├─ adBlockAdvancedJS
//    ├─ adBlockObfuscatedClass
//    └─ adBlockCookieBanners
//
//    Downloads:
//    ├─ showDownloadNotifications
//    └─ autoOpenDownloads
//
// 8. NOTIFICATION CENTER INTEGRATION:
//
//    Why use NotificationCenter if we have @Published?
//    - @Published only works for SwiftUI (ObservableObject pattern)
//    - Some managers (AdBlockManager, WebView delegates) are NOT SwiftUI views
//    - NotificationCenter is the UIKit way to broadcast events
//    - We use BOTH: @Published for SwiftUI, NotificationCenter for everything else
//
// 9. VALIDATION PATTERNS:
//
//    Some settings need validation (custom search template, homepage URL).
//    Validation strategies used:
//
//    a) Store as String, validate on use:
//       - homepage (String) → homepageURL (computed URL?)
//       - Allows storing invalid values temporarily
//
//    b) Validation helper methods:
//       - isCustomSearchTemplateValid
//       - customSearchTemplateErrorMessage
//       - Used by settings UI to show errors
//
//    c) Fallbacks for invalid values:
//       - Invalid homepage → fallback to Qwant
//       - Invalid custom template → fallback to Google
//
// 10. DEFAULT VALUE STRATEGY:
//
//     Some defaults depend on device type:
//     - iPad: useDesktopMode = true (more screen space)
//     - iPhone: useDesktopMode = false (mobile sites work better)
//
//     Privacy-focused defaults:
//     - defaultSearchEngine = .duckduckgo (not Google)
//     - homepage = DuckDuckGo start page
//     - adBlockEnabled = true by default
//
// 11. COMMON PITFALLS & TIPS:
//
//     ❌ Don't: Directly modify UserDefaults elsewhere in the app
//     ✅ Do: Always change settings through BrowserSettings.shared
//
//     ❌ Don't: Create instances of BrowserSettings (init is private)
//     ✅ Do: Always use BrowserSettings.shared singleton
//
//     ❌ Don't: Forget didSet when adding new @Published properties
//     ✅ Do: Always add didSet to save to UserDefaults + post notification
//
//     ❌ Don't: Use @Published for expensive computations
//     ✅ Do: Use computed properties for derived values
//
// 12. TESTING CONSIDERATIONS:
//
//     The singleton pattern can make unit testing harder (shared state).
//     Potential improvements for testability:
//     - Add a reset() method to restore defaults
//     - Consider dependency injection for UserDefaults
//     - Mock NotificationCenter for testing
//
// This file demonstrates production-quality settings management in iOS.
// Study the patterns here - they're applicable to any app with user preferences!
