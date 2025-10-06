//
//  JavaScriptBlockingManager.swift
//  EvoArc
//
//  Created on 2025-09-16.
//
//  Manages per-site JavaScript blocking/enabling settings.
//
//  Key responsibilities:
//  1. Track which sites have JavaScript blocked
//  2. Persist blocked sites list across app launches
//  3. Provide simple API to check/toggle JS blocking
//  4. Support bulk operations (clear all, list all)
//
//  Design patterns:
//  - Singleton: One shared instance app-wide
//  - @MainActor: All operations run on main thread
//  - ObservableObject: SwiftUI views can observe changes
//  - Set<String>: Fast O(1) lookup for blocked sites
//
//  Use cases:
//  - User blocks JS on slow/buggy sites
//  - Privacy-focused browsing
//  - Troubleshooting website issues
//  - Content blocking for better performance
//

import Foundation  // Core Swift - UserDefaults, URL
import Combine     // Reactive framework - ObservableObject

/// Manages per-site JavaScript blocking settings.
///
/// **Purpose**: Allows users to selectively disable JavaScript on specific websites.
///
/// **Why block JavaScript?**:
/// - Performance (heavy scripts slow down browsing)
/// - Privacy (tracking scripts)
/// - Security (malicious scripts)
/// - Debugging (isolate JS-related issues)
///
/// **Architecture**:
/// - @MainActor: Thread-safe UI updates
/// - Singleton: One shared instance
/// - Set storage: Fast O(1) lookups
/// - Persistent: Survives app restarts
///
/// **Example usage**:
/// ```swift
/// let manager = JavaScriptBlockingManager.shared
///
/// // Block JS on example.com
/// manager.blockJavaScript(for: URL(string: "https://example.com")!)
///
/// // Check if blocked
/// if manager.isJavaScriptBlocked(for: url) {
///     print("JS is blocked on this site")
/// }
///
/// // Unblock
/// manager.unblockJavaScript(for: url)
/// ```
@MainActor
final class JavaScriptBlockingManager: ObservableObject {
    /// The shared singleton instance.
    ///
    /// **Singleton pattern**: Ensures single source of truth.
    /// All app components reference the same blocked sites list.
    static let shared = JavaScriptBlockingManager()
    
    // MARK: - Published Properties
    
    /// Set of blocked site hosts (domain names).
    ///
    /// **@Published**: SwiftUI views automatically update when this changes.
    ///
    /// **private(set)**: External code can read but not modify directly.
    /// Must use blockJavaScript() / unblockJavaScript() methods.
    ///
    /// **Set<String>**: Uses Set for O(1) lookup performance.
    /// Checking if site is blocked is instant even with 1000s of entries.
    ///
    /// **Contains**: Host names only ("example.com"), not full URLs.
    ///
    /// **Example**: ["youtube.com", "twitter.com", "facebook.com"]
    @Published private(set) var blockedSites: Set<String> = []
    
    // MARK: - Private Properties
    
    /// UserDefaults for persistent storage.
    ///
    /// **Standard**: Uses shared app preferences.
    private let userDefaults = UserDefaults.standard
    
    /// UserDefaults key for storing blocked sites array.
    ///
    /// **Value**: "blockedJavaScriptSites"
    private let blockedSitesKey = "blockedJavaScriptSites"
    
    /// Private initializer (singleton pattern).
    ///
    /// **Why private?**: Prevents creating multiple instances.
    /// Forces use of `.shared` singleton.
    ///
    /// **Initialization**: Loads previously blocked sites from storage.
    private init() {
        loadBlockedSites()  // Restore persisted state
    }
    
    // MARK: - Public Methods
    // These methods are called by other parts of EvoArc.
    
    /// Checks if JavaScript is blocked for a given URL.
    ///
    /// **Fast check**: O(1) lookup in Set.
    ///
    /// **Host-based**: Only checks domain ("example.com"),
    /// not full path. Blocking applies to entire site.
    ///
    /// **Parameter**:
    /// - url: The URL to check
    ///
    /// **Returns**: true if JS blocked, false if allowed
    ///
    /// **Example**:
    /// ```swift
    /// let url = URL(string: "https://example.com/page")!
    /// if manager.isJavaScriptBlocked(for: url) {
    ///     // Disable JS for this webview
    /// }
    /// ```
    func isJavaScriptBlocked(for url: URL) -> Bool {
        /// Extract host from URL.
        /// https://example.com/page → "example.com"
        guard let host = url.host else { return false }  // Invalid URL
        
        /// Check if host is in blocked set.
        /// O(1) lookup - instant even with 1000s of entries.
        return blockedSites.contains(host)
    }
    
    /// Blocks JavaScript for a site.
    ///
    /// **Effect**: Future page loads on this site will have JS disabled.
    ///
    /// **Persistence**: Automatically saved to UserDefaults.
    ///
    /// **Immediate**: Current tabs not affected - applies to new loads.
    ///
    /// **Parameter**:
    /// - url: URL of site to block
    ///
    /// **Example**:
    /// ```swift
    /// // Block JS on YouTube
    /// manager.blockJavaScript(for: URL(string: "https://youtube.com")!)
    /// // Now youtube.com pages load without JavaScript
    /// ```
    func blockJavaScript(for url: URL) {
        /// Extract host from URL.
        guard let host = url.host else { return }  // Invalid URL - do nothing
        
        /// Add host to blocked set.
        /// Set automatically handles duplicates (no effect if already blocked).
        blockedSites.insert(host)
        
        /// Persist to disk.
        /// Survives app restart.
        saveBlockedSites()
    }
    
    /// Unblocks JavaScript for a site.
    ///
    /// **Effect**: Future page loads on this site will have JS enabled.
    ///
    /// **Persistence**: Automatically saved to UserDefaults.
    ///
    /// **Immediate**: Current tabs not affected - applies to new loads.
    ///
    /// **Parameter**:
    /// - url: URL of site to unblock
    ///
    /// **Example**:
    /// ```swift
    /// // Unblock JS on YouTube
    /// manager.unblockJavaScript(for: URL(string: "https://youtube.com")!)
    /// // Now youtube.com pages load with JavaScript enabled
    /// ```
    func unblockJavaScript(for url: URL) {
        /// Extract host from URL.
        guard let host = url.host else { return }  // Invalid URL - do nothing
        
        /// Remove host from blocked set.
        /// No effect if host wasn't blocked.
        blockedSites.remove(host)
        
        /// Persist to disk.
        saveBlockedSites()
    }
    
    /// Toggles JavaScript blocking for a site.
    ///
    /// **Convenience**: If blocked, unblock. If unblocked, block.
    ///
    /// **Use case**: Single button to toggle JS on/off for site.
    ///
    /// **Parameter**:
    /// - url: URL of site to toggle
    ///
    /// **Example**:
    /// ```swift
    /// // Toggle button handler
    /// @IBAction func toggleJavaScript() {
    ///     manager.toggleJavaScriptBlocking(for: currentURL)
    ///     // Reload page to apply new setting
    ///     webView.reload()
    /// }
    /// ```
    func toggleJavaScriptBlocking(for url: URL) {
        /// Check current state and flip it.
        if isJavaScriptBlocked(for: url) {
            unblockJavaScript(for: url)  // Was blocked → unblock
        } else {
            blockJavaScript(for: url)    // Was allowed → block
        }
    }
    
    /// Returns all blocked sites as a sorted array.
    ///
    /// **Use case**: Display list of blocked sites in settings UI.
    ///
    /// **Sorted**: Alphabetically for better UX.
    ///
    /// **Returns**: Array of blocked host names
    ///
    /// **Example**:
    /// ```swift
    /// let blocked = manager.getAllBlockedSites()
    /// // ["example.com", "facebook.com", "youtube.com"]
    ///
    /// ForEach(blocked, id: \.self) { site in
    ///     Text(site)
    /// }
    /// ```
    func getAllBlockedSites() -> [String] {
        /// Convert Set to Array (for ordered iteration).
        /// Sort alphabetically for consistent display.
        return Array(blockedSites).sorted()
    }
    
    /// Clears all blocked sites.
    ///
    /// **Effect**: Re-enables JavaScript on all previously blocked sites.
    ///
    /// **Use case**: "Reset to defaults" button in settings.
    ///
    /// **Warning**: This action is irreversible!
    ///
    /// **Persistence**: Empty list saved to UserDefaults.
    func clearAllBlockedSites() {
        /// Remove all entries from Set.
        blockedSites.removeAll()
        
        /// Persist empty state.
        /// Next app launch will have no blocked sites.
        saveBlockedSites()
    }
    
    /// Removes a specific blocked site.
    ///
    /// **Use case**: Delete button in blocked sites list UI.
    ///
    /// **Parameter**:
    /// - host: Host name to unblock (e.g., "example.com")
    ///
    /// **Note**: Pass host directly, not URL.
    ///
    /// **Example**:
    /// ```swift
    /// // User swipes to delete in list
    /// manager.removeBlockedSite("youtube.com")
    /// ```
    func removeBlockedSite(_ host: String) {
        /// Remove from Set.
        /// No effect if host wasn't in Set.
        blockedSites.remove(host)
        
        /// Persist changes.
        saveBlockedSites()
    }
    
    // MARK: - Private Methods
    // Internal persistence implementation.
    
    /// Loads blocked sites from UserDefaults.
    ///
    /// **Called**: Once during initialization (in init()).
    ///
    /// **Process**:
    /// 1. Try to load array from UserDefaults
    /// 2. Convert array to Set
    /// 3. If fails, start with empty Set
    ///
    /// **Storage format**: Array of strings (UserDefaults doesn't support Set directly).
    ///
    /// **Failure handling**: Silent (starts with empty Set if no saved data).
    /// This is normal for first app launch.
    private func loadBlockedSites() {
        /// Try to load array from UserDefaults.
        /// Cast to [String] (could be nil or wrong type).
        if let sitesArray = userDefaults.array(forKey: blockedSitesKey) as? [String] {
            /// Convert array to Set.
            /// Set removes duplicates automatically (shouldn't have any).
            blockedSites = Set(sitesArray)
        }
        /// If load fails, blockedSites remains empty Set (initial value).
    }
    
    /// Saves blocked sites to UserDefaults.
    ///
    /// **Called**: After every modification (block, unblock, clear, remove).
    ///
    /// **Process**:
    /// 1. Convert Set to Array
    /// 2. Save to UserDefaults
    ///
    /// **Why Array?**: UserDefaults doesn't support Set directly.
    /// Must convert Set → Array for storage, Array → Set for loading.
    ///
    /// **Performance**: Fast (only stores host names, not full URLs).
    /// 100 blocked sites ≈ 5KB. Instant save.
    ///
    /// **Persistence**: Survives app termination and device restart.
    private func saveBlockedSites() {
        /// Convert Set to Array for UserDefaults.
        /// Order doesn't matter (will be sorted when displayed).
        userDefaults.set(Array(blockedSites), forKey: blockedSitesKey)
    }
}

// MARK: - Architecture Summary
//
// JavaScriptBlockingManager provides per-site JS control.
//
// ┌──────────────────────────────────────────────────┐
// │  JavaScriptBlockingManager Architecture  │
// └──────────────────────────────────────────────────┘
//
// Data Structure:
// ===============
//
// blockedSites: Set<String>
// ┌──────────────────────────────┐
// │ "youtube.com"              │
// │ "twitter.com"              │
// │ "facebook.com"             │
// │ "reddit.com"               │
// └──────────────────────────────┘
//
// Why Set?
// - O(1) lookup (instant check if site blocked)
// - Automatic duplicate prevention
// - No order needed (sorted on display)
//
// Typical Flow:
// =============
//
// User visits slow site:
//   ↓
// Right-click → "Block JavaScript"
//   ↓
// blockJavaScript(for: url)
//   ↓
// Extract host: "example.com"
//   ↓
// Add to blockedSites Set
//   ↓
// Save to UserDefaults
//   ↓
// User refreshes page:
//   ↓
// isJavaScriptBlocked(for: url)?
//   ↓ Yes
// Disable JS in WKWebView configuration
//   ↓
// Page loads without JavaScript ✅
//
// Integration with WKWebView:
// ==========================
//
// When creating webview:
// ```swift
// let config = WKWebViewConfiguration()
//
// if JavaScriptBlockingManager.shared.isJavaScriptBlocked(for: url) {
//     config.preferences.javaScriptEnabled = false  // Block JS
// } else {
//     config.preferences.javaScriptEnabled = true   // Allow JS
// }
//
// let webView = WKWebView(frame: .zero, configuration: config)
// ```
//
// When navigating to new URL:
// ```swift
// func loadURL(_ url: URL) {
//     if JavaScriptBlockingManager.shared.isJavaScriptBlocked(for: url) {
//         // Need to recreate webview with new config
//         // OR show warning to user
//     }
//     webView.load(URLRequest(url: url))
// }
// ```
//
// Performance:
// ===========
//
// Lookup: O(1) - instant
// Insert: O(1) - instant  
// Remove: O(1) - instant
// Save: O(n) - linear with number of blocked sites
//   - 100 sites: ~1ms
//   - 1000 sites: ~10ms
//   - Still fast enough for user actions
//
// Memory usage:
// - Per site: ~50 bytes ("example.com" string)
// - 100 sites: ~5KB
// - 1000 sites: ~50KB
// - Negligible impact
//
// Persistence:
// ===========
//
// Storage: UserDefaults
// Format: Array<String> ("blockedJavaScriptSites")
// Size limit: ~4MB (UserDefaults)
// Typical usage: <50KB
//
// Conversion:
// - Save: Set → Array → UserDefaults
// - Load: UserDefaults → Array → Set
//
// Why not store Set directly?
// - UserDefaults only supports property list types
// - Property list types: String, Number, Date, Data, Array, Dictionary
// - Set is not a property list type
//
// Best Practices:
// ==============
//
// ✅ DO use host-only blocking (not full URL)
// ✅ DO persist after every change
// ✅ DO handle invalid URLs gracefully
// ✅ DO provide bulk operations (clear all)
// ✅ DO show blocked sites list in settings
//
// ❌ DON'T block JS globally by default
// ❌ DON'T block per-page (block per-site)
// ❌ DON'T forget to reload page after toggle
// ❌ DON'T cache isBlocked results (check each time)
// ❌ DON'T modify blockedSites directly (use methods)
//
// Common Use Cases:
// ================
//
// 1. Performance:
//    - Heavy JS sites load faster without JS
//    - Useful for slow connections
//
// 2. Privacy:
//    - Block tracking scripts
//    - Reduce fingerprinting
//
// 3. Security:
//    - Prevent malicious scripts
//    - Sandbox untrusted sites
//
// 4. Debugging:
//    - Isolate JS-related issues
//    - Test graceful degradation
//
// 5. Content:
//    - Read articles without popups/animations
//    - Access paywalled content (sometimes)
//
// Future Enhancements:
// ===================
//
// Potential additions:
// - Wildcard support (*.example.com)
// - Temporary blocking (auto-expire)
// - JS blocking per-feature (not all-or-nothing)
// - Whitelist mode (block all except these)
// - Import/export blocked list
// - Sync across devices
//
// Integration Points:
// ===================
//
// Used by:
// - TabWebView (applies blocking to webview config)
// - ContextMenu ("Block JavaScript" option)
// - Settings (list/manage blocked sites)
// - Tab restoration (preserve JS state)
//
// This provides Safari-style per-site JS control
// with simple API and efficient performance!
