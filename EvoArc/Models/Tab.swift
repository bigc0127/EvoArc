//
//  Tab.swift
//  EvoArc
//
//  Represents a single browser tab in the EvoArc application.
//  Each Tab manages its own web content, loading state, navigation history, and metadata.
//
//  Architecture:
//  - Conforms to ObservableObject to enable SwiftUI reactive updates
//  - Uses @Published properties to automatically notify views of changes
//  - Manages the lifecycle of a WKWebView (WebKit's web rendering engine)
//  - Implements tab-specific features like pinning, grouping, and reader mode

import Foundation  // Core types like URL, UUID, Date
import Combine     // Reactive programming framework for @Published
import WebKit      // Apple's web rendering engine (WKWebView)

// MARK: - Tab Class

/// @MainActor ensures all Tab operations run on the main thread.
/// This is critical because:
/// 1. WKWebView MUST be used on the main thread
/// 2. SwiftUI updates must happen on the main thread
/// 3. @Published property changes trigger UI updates, which need main thread
/// 
/// For Swift beginners:
/// - @MainActor is a Swift concurrency feature introduced in Swift 5.5
/// - It's similar to DispatchQueue.main.async but enforced at compile time
/// - Any function or property access on this class will automatically run on main thread
@MainActor
class Tab: ObservableObject, Identifiable {
    // MARK: - Identity
    
    /// Unique identifier for this tab, generated once when the tab is created.
    /// UUID (Universally Unique Identifier) ensures no two tabs have the same ID.
    /// .uuidString converts UUID to a String like "E621E1F8-C36C-495A-93FC-0C247A3E6E5F"
    /// 
    /// 'let' means this cannot change after initialization (immutable).
    /// Identifiable protocol requires an 'id' property for SwiftUI's list identification.
    let id = UUID().uuidString
    
    // MARK: - Timers
    
    /// Optional timer that periodically updates the tab's thumbnail preview image.
    /// Timer is a Foundation class that executes code after a time interval.
    /// The '?' makes this an optional - it can be nil (no timer running).
    /// 'var' means it can be reassigned (mutable).
    var thumbnailUpdateTimer: Timer?
    
    // MARK: - Published Properties (Automatically Update UI)
    
    /// The title of the current web page being displayed.
    /// @Published is a property wrapper that automatically notifies SwiftUI when the value changes.
    /// 
    /// How @Published works:
    /// 1. When title changes, it triggers objectWillChange.send()
    /// 2. SwiftUI views observing this Tab automatically re-render
    /// 3. No manual notification code needed - it's all automatic!
    @Published var title: String = "New Tab"
    
    /// Indicates whether the web page is currently loading.
    /// Used to show/hide loading indicators in the UI.
    /// Bool is Swift's boolean type (true or false).
    @Published var isLoading: Bool = false
    
    /// Tracks whether the tab's web view can navigate backward in history.
    /// This controls the enabled/disabled state of the "back" button.
    /// 
    /// didSet is a property observer that runs code after the value changes.
    /// We use it here to force an immediate UI update by manually triggering objectWillChange.
    @Published var canGoBack: Bool = false {
        didSet {
            /// oldValue is automatically provided by didSet - it's the previous value.
            /// Only send a change notification if the value actually changed.
            /// This prevents unnecessary UI updates when the value stays the same.
            if canGoBack != oldValue {
                /// objectWillChange is part of ObservableObject protocol.
                /// .send() broadcasts a change notification to all observers.
                /// This ensures SwiftUI immediately updates navigation button states.
                objectWillChange.send()
            }
        }
    }
    
    /// Tracks whether the tab's web view can navigate forward in history.
    /// Similar to canGoBack but for forward navigation.
    /// Uses the same didSet pattern to force immediate UI updates.
    @Published var canGoForward: Bool = false {
        didSet {
            if canGoForward != oldValue {
                objectWillChange.send()
            }
        }
    }
    
    /// Loading progress estimate from 0.0 (not started) to 1.0 (complete).
    /// Double is Swift's floating-point type for decimal numbers.
    /// Used to display a progress bar while pages load.
    @Published var estimatedProgress: Double = 0.0
    
    /// The browser engine used to render this tab (WebKit or Blink).
    /// BrowserEngine is an enum defined elsewhere with cases like .webkit and .blink.
    /// .webkit is Apple's engine (Safari), .blink is Chromium's engine.
    @Published var browserEngine: BrowserEngine = .webkit
    
    /// Whether this tab is pinned (stays open and appears first in tab list).
    /// Pinned tabs are like favorites - they persist across sessions.
    @Published var isPinned: Bool = false
    
    /// Optional UUID linking this tab to a tab group.
    /// UUID? means it can be nil (not in any group) or contain a UUID value.
    /// Tab groups let users organize related tabs together.
    @Published var groupID: UUID? = nil
    
    /// Controls whether the URL should be visible in the address bar.
    /// false = show homepage or blank (cleaner UI)
    /// true = show the actual URL
    @Published var showURLInBar: Bool = false
    
    /// Whether reader mode is currently active for this tab.
    /// Reader mode simplifies page layout for easier reading (removes ads, navigation, etc.).
    @Published var readerModeEnabled: Bool = false
    
    /// Internal flag indicating this tab needs to load its initial URL.
    /// private(set) means:
    /// - External code can READ this value
    /// - Only THIS class can WRITE to it
    /// This encapsulation prevents other code from incorrectly setting this flag.
    @Published private(set) var needsInitialLoad: Bool = false
    
    // MARK: - WebView Reference
    
    /// Reference to the WKWebView that displays web content for this tab.
    /// 
    /// 'weak' is critical here - it prevents a retain cycle:
    /// - Tab holds a weak reference to WKWebView
    /// - WKWebView's parent view might hold a strong reference to Tab
    /// - Without 'weak', they'd keep each other alive forever (memory leak)
    /// 
    /// For Swift beginners:
    /// - weak references don't increase the retain count
    /// - When the WKWebView is destroyed, this automatically becomes nil
    /// - weak can only be used with Optional types (notice the ?)
    weak var webView: WKWebView?
    
    // MARK: - Loading Timeout System
    
    /// Timer that enforces a maximum loading time for web pages.
    /// If a page takes longer than loadingTimeout seconds, we force-stop it.
    /// This prevents indefinite loading states that hurt user experience.
    /// 'private' means only this class can access these properties.
    private var loadingTimer: Timer?
    
    /// Maximum time (in seconds) to wait for a page to load before giving up.
    /// TimeInterval is a typealias for Double, used for time durations.
    /// 'let' makes this constant - 30 seconds is fixed and never changes.
    private let loadingTimeout: TimeInterval = 30.0
    
    // MARK: - URL Management
    
    /// Private storage for the tab's current URL.
    /// We use a private backing variable (_url) to add custom logic in the getter/setter.
    /// The underscore prefix is a Swift convention for private backing storage.
    private var _url: URL?
    
    /// The current URL being displayed in this tab.
    /// Uses custom getter/setter to manage needsInitialLoad flag automatically.
    /// 
    /// Computed property pattern:
    /// - get { } defines what happens when you READ url
    /// - set { } defines what happens when you WRITE to url
    /// - newValue is automatically provided - it's the value being assigned
    var url: URL? {
        get { 
            /// Simply return the private backing storage.
            _url 
        }
        set {
            /// Update the backing storage with the new URL.
            _url = newValue
            
            /// If a URL was set (not nil), mark that this tab needs to load it.
            /// This flag is checked later to trigger the initial page load.
            if newValue != nil {
                needsInitialLoad = true
            }
        }
    }
    
    /// Convenience property for working with URLs as Strings.
    /// Automatically converts between URL objects and String representations.
    var urlString: String {
        get { 
            /// Convert URL to String, or return empty string if URL is nil.
            /// The ?? operator is the "nil coalescing operator" - provides a default value.
            /// .absoluteString gives the complete URL as a String.
            url?.absoluteString ?? "" 
        }
        set {
            /// When setting via String, validate and normalize it first.
            /// Only set the URL if validation succeeds.
            /// This prevents malformed URLs from being set.
            if let url = validateAndNormalizeURL(newValue) {
                /// 'self.url' explicitly refers to this instance's url property.
                /// This calls the url setter above, which also sets needsInitialLoad.
                self.url = url
            }
        }
    }
    
    // MARK: - Initialization
    
    /// Creates a new Tab instance with optional configuration.
    /// 
    /// Parameters explained for Swift beginners:
    /// - url: The initial URL to load (nil = use homepage)
    /// - browserEngine: Which engine to use (nil = use user's default setting)
    /// - isPinned: Should this tab be pinned? (default: false)
    /// - groupID: Optional group this tab belongs to (default: nil/none)
    /// 
    /// The '= nil' and '= false' provide default values.
    /// This means you can call: Tab() or Tab(url: someURL) or Tab(url: someURL, isPinned: true)
    init(url: URL? = nil, browserEngine: BrowserEngine? = nil, isPinned: Bool = false, groupID: UUID? = nil) {
        /// 'if let' safely unwraps the optional url parameter.
        /// If url contains a value (not nil), the block executes with that value.
        if let url = url {
            /// Directly set the private backing storage to avoid triggering the setter.
            /// This is more efficient during initialization.
            self._url = url
            
            /// Hide the URL in the address bar for the homepage (cleaner look),
            /// but show it for all other URLs (so users know where they are).
            /// The != operator checks for inequality (not equal).
            self.showURLInBar = url != BrowserSettings.shared.homepageURL
            
            /// Mark that this URL needs to be loaded into the web view later.
            self.needsInitialLoad = true
        } else {
            /// If no URL was provided, default to the user's configured homepage.
            /// BrowserSettings.shared is a singleton pattern - one shared instance.
            self._url = BrowserSettings.shared.homepageURL
            
            /// Don't show the URL for new tabs - gives a cleaner first impression.
            self.showURLInBar = false
            
            /// Still need to load the homepage URL.
            self.needsInitialLoad = true
        }
        
        /// The ?? operator is "nil coalescing" - use left side if not nil, otherwise use right side.
        /// If browserEngine parameter is nil, fall back to the user's default setting.
        self.browserEngine = browserEngine ?? BrowserSettings.shared.browserEngine
        
        /// Set the pinned state from the parameter.
        self.isPinned = isPinned
        
        /// Set the group ID (may be nil if tab is not in a group).
        self.groupID = groupID
        
        /// Initialize title to default. It will be updated when the page loads.
        self.title = "New Tab"
    }
    
    // MARK: - Loading Timeout Management
    
    /// Starts a 30-second countdown timer for page loading.
    /// If the page doesn't finish loading within this time, we force-stop it.
    /// This prevents infinite loading states that frustrate users.
    func startLoadingTimeout() {
        /// Cancel any previously running timer to avoid multiple timers.
        /// The ? is optional chaining - safely calls invalidate() only if loadingTimer isn't nil.
        /// invalidate() stops the timer permanently (it can't be restarted).
        loadingTimer?.invalidate()
        
        /// Log to Xcode console for debugging.
        /// \(variable) is string interpolation - embeds variable values in strings.
        print("🚀 Starting \(loadingTimeout)s loading timeout for tab: \(title) (\(id))")
        
        /// Create and schedule a new timer.
        /// 
        /// Parameters:
        /// - withTimeInterval: How long to wait (loadingTimeout = 30.0 seconds)
        /// - repeats: false means fire only once, then stop
        /// - closure: Code to run when timer fires
        /// 
        /// [weak self] is a capture list that prevents retain cycles:
        /// - Without it, the timer holds a strong reference to self
        /// - Self holds a strong reference to the timer
        /// - They keep each other alive forever (memory leak)
        /// - weak makes self optional inside the closure
        loadingTimer = Timer.scheduledTimer(withTimeInterval: loadingTimeout, repeats: false) { [weak self] _ in
            /// DispatchQueue.main.async ensures this code runs on the main thread.
            /// UI updates MUST happen on the main thread, and isLoading affects UI.
            DispatchQueue.main.async {
                /// Check if loading is still happening after 30 seconds.
                /// self? is optional chaining - if self was deallocated, this safely does nothing.
                if self?.isLoading == true {
                    /// Log that we're forcing a stop due to timeout.
                    print("⚠️ Loading timeout reached for tab: \(self?.title ?? "Unknown") (\(self?.id.description ?? "unknown"))")
                    
                    /// Force-stop the loading process.
                    self?.forceStopLoading()
                }
            }
        }
    }
    
    /// Cancels the loading timeout timer because the page finished loading normally.
    /// This prevents the timeout from firing after the page successfully loads.
    func stopLoadingTimeout() {
        /// Only do work if a timer actually exists.
        /// This check avoids unnecessary console logs and operations.
        if loadingTimer != nil {
            /// Log that we're stopping the timer.
            print("🛑 Stopping loading timeout for tab: \(title) (\(id))")
            
            /// Stop the timer permanently.
            loadingTimer?.invalidate()
            
            /// Set to nil to release memory and indicate no timer is running.
            /// This is good memory management practice.
            loadingTimer = nil
        }
    }
    
    /// Immediately halts page loading, regardless of state.
    /// Called when the timeout expires or when the user manually stops loading.
    func forceStopLoading() {
        /// Debug logging to track when force-stop is triggered.
        print("🚫 Force stopping loading for tab: \(title) (\(id))")
        
        /// Reset loading state to false.
        /// This will automatically update any UI showing loading indicators.
        isLoading = false
        
        /// Reset progress to 0 (not loading).
        /// Progress bars in the UI will hide or reset based on this.
        estimatedProgress = 0.0
        
        /// Tell the WebKit web view to stop loading the current page.
        /// This cancels all network requests for this page.
        webView?.stopLoading()
        
        /// Clean up the timeout timer since we're manually stopping.
        stopLoadingTimeout()
        
        /// Log completion for debugging.
        print("🔄 Forced loading stop completed for tab: \(title)")
    }
    
    // MARK: - URL Loading
    
    /// Triggers the initial page load for this tab if needed.
    /// This is called after the web view is created and attached to the tab.
    func handleInitialLoad() {
        /// guard is like an early return - if conditions aren't met, exit immediately.
        /// This reads as: "guard that all these are true, otherwise return"
        /// 
        /// Conditions checked:
        /// 1. needsInitialLoad must be true (we haven't loaded yet)
        /// 2. self.url must not be nil (we have a URL to load)
        /// 3. webView?.url must be nil (webView hasn't loaded anything yet)
        /// 
        /// If any condition fails, 'return' exits the function early.
        guard needsInitialLoad,
              let url = self.url,
              webView?.url == nil else { return }
        
        /// Create a URL request and tell the web view to load it.
        /// URLRequest wraps a URL with additional loading configuration (caching, etc.).
        webView?.load(URLRequest(url: url))
        
        /// Clear the flag so we don't accidentally load again.
        needsInitialLoad = false
    }
    
    /// Validates user input and converts it to a proper URL object.
    /// Handles common user mistakes like missing https:// prefix.
    /// 
    /// For Swift beginners:
    /// - Returns URL? (optional) because validation might fail
    /// - nil return means the string wasn't a valid URL
    /// - Non-nil return means we successfully created a URL
    func validateAndNormalizeURL(_ urlString: String) -> URL? {
        /// Check if the string is empty or only whitespace.
        /// .trimmingCharacters removes spaces/tabs/newlines from both ends.
        /// .whitespacesAndNewlines is a predefined CharacterSet.
        /// The ! negates the isEmpty check ("guard that it's NOT empty").
        guard !urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            /// Return nil for empty input - can't make a URL from nothing.
            return nil
        }
        
        /// Try to create a URL from the string and standardize it.
        /// .standardized normalizes the URL format (removes redundant slashes, etc.).
        /// The ? after URL(string:) means it returns an optional - might fail.
        if let url = URL(string: urlString)?.standardized {
            /// Check if the URL has a scheme (http://, https://, ftp://, etc.).
            /// .scheme extracts the protocol part before the ://
            if url.scheme != nil {
                /// URL is complete with scheme - return it as-is.
                return url
            } else {
                /// Missing scheme - user probably typed "google.com" instead of "https://google.com".
                /// Try adding https:// prefix (most common case).
                if let urlWithScheme = URL(string: "https://" + urlString) {
                    return urlWithScheme
                }
            }
        }
        
        /// If we got here, we couldn't create a valid URL - return nil.
        /// The calling code should handle this by showing an error or treating it as a search.
        return nil
    }
    
    // MARK: - Deinitialization
    
    /// deinit is called automatically when this Tab object is being destroyed.
    /// This is Swift's equivalent of a destructor in other languages.
    /// 
    /// For Swift beginners:
    /// - deinit has no parameters and no return value
    /// - You never call deinit manually - Swift calls it automatically
    /// - Use it to release resources (timers, file handles, observers, etc.)
    /// - Good memory management requires cleaning up in deinit
    deinit {
        /// Stop and invalidate both timers to prevent them from firing after Tab is destroyed.
        /// This is critical because timer closures might reference self.
        /// Without cleanup, timers could try to access deallocated memory = crash!
        loadingTimer?.invalidate()
        loadingTimer = nil
        thumbnailUpdateTimer?.invalidate()
        thumbnailUpdateTimer = nil
        
        /// Task creates a new asynchronous task using Swift's structured concurrency.
        /// @MainActor ensures this cleanup runs on the main thread.
        /// [weak self] prevents a retain cycle during cleanup.
        /// 
        /// Why we need this:
        /// - ThumbnailManager stores thumbnail images indexed by tab ID
        /// - If we don't remove them, they stay in memory forever (memory leak)
        /// - This cleanup ensures thumbnails are released when tabs close
        Task { @MainActor [weak self] in
            /// Safely unwrap self to get the ID.
            /// If self is already nil, guard exits early (no-op).
            guard let id = self?.id else { return }
            
            /// Tell ThumbnailManager to remove this tab's thumbnail from memory.
            /// .shared is the singleton pattern - one shared instance.
            ThumbnailManager.shared.removeThumbnail(for: id)
        }
    }
}
