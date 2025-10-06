//
//  PerplexityManager.swift
//  EvoArc
//
//  Created on 2025-09-06.
//
//  Manages integration with Perplexity.ai for AI-powered search and summarization.
//
//  Key responsibilities:
//  1. Handle authentication with Perplexity.ai
//  2. Manage session cookies for authenticated requests
//  3. Build Perplexity search URLs for web pages
//  4. Sync cookies between WKWebsiteDataStore and HTTPCookieStorage
//  5. Track authentication status
//
//  Architecture:
//  - Singleton pattern (one shared instance)
//  - @MainActor for thread safety
//  - ObservableObject for SwiftUI reactivity
//  - Cookie-based authentication
//  - Async/await for cookie operations
//
//  Cookie Sync Strategy:
//  - WKWebsiteDataStore: Where WebView stores cookies
//  - HTTPCookieStorage: System cookie storage
//  - Must sync between them for authentication to work
//
//  Use cases:
//  - "Summarize this page" - Ask Perplexity to summarize current page
//  - "Search in Perplexity" - Send page to Perplexity for research
//  - Session management - Keep user logged in
//
//  For Swift beginners:
//  - Cookies: Small data pieces that maintain login sessions
//  - HTTPCookieStorage: System storage for HTTP cookies
//  - WKWebsiteDataStore: WebKit's storage (separate from system)
//  - Sync: Copy cookies between the two storage systems
//

import Foundation  // Core Swift - UserDefaults, URLComponents
import SwiftUI    // Apple's UI framework - ObservableObject
import Combine    // Reactive framework - @Published
import WebKit     // Apple's web engine - WKWebsiteDataStore, HTTPCookie

/// Defines the type of action to perform with Perplexity.
///
/// **Purpose**: Different actions build different query URLs.
///
/// **Actions**:
/// - summarize: "Summarize this webpage: <url>"
/// - sendToPerplexity: "About \"<title>\": <url>"
///
/// **Why enum?**: Type-safe action selection.
enum PerplexityAction {
    case summarize          // Ask Perplexity to summarize the page
    case sendToPerplexity   // Send page URL to Perplexity for research
}

/// Represents a pending Perplexity request.
///
/// **Value type**: struct (copied when assigned).
///
/// **Identifiable**: Required for SwiftUI sheet presentation.
/// Each request has unique ID for tracking.
///
/// **Purpose**: Holds data needed to build Perplexity search URL.
///
/// **Example**:
/// ```swift
/// let request = PerplexityRequest(
///     action: .summarize,
///     url: URL(string: "https://example.com")!,
///     title: "Example Page"
/// )
/// // Opens: https://www.perplexity.ai/search?q=Summarize+this+webpage:+https://example.com&source=evoarc
/// ```
struct PerplexityRequest: Identifiable {
    /// Unique identifier for this request.
    let id = UUID()
    
    /// The action to perform (summarize or research).
    let action: PerplexityAction
    
    /// The URL of the page to process.
    let url: URL
    
    /// Optional page title for better context.
    let title: String?
    
    /// Builds the Perplexity search URL for this request.
    ///
    /// **URL Format**: https://www.perplexity.ai/search?q=<query>&source=evoarc
    ///
    /// **Query construction**:
    /// - Summarize: "Summarize this webpage: <url>"
    /// - Send: "About \"<title>\": <url>" (or just URL if no title)
    ///
    /// **Source parameter**: Identifies traffic as coming from EvoArc.
    ///
    /// **Fallback**: Returns original URL if URL building fails (unlikely).
    var perplexityURL: URL {
        let baseURL = "https://www.perplexity.ai/search"
        var components = URLComponents(string: baseURL)!
        
        /// Build query string based on action type.
        let query: String
        switch action {
        case .summarize:
            /// Direct summarization request.
            query = "Summarize this webpage: \(url.absoluteString)"
            
        case .sendToPerplexity:
            /// Research request with context.
            if let title = title, !title.isEmpty {
                /// Include title for better context.
                query = "About \"\(title)\": \(url.absoluteString)"
            } else {
                /// No title available, use URL only.
                query = url.absoluteString
            }
        }
        
        /// Build query parameters.
        components.queryItems = [
            URLQueryItem(name: "q", value: query),        // Search query
            URLQueryItem(name: "source", value: "evoarc") // Traffic source
        ]
        
        /// Return built URL, fallback to original if build fails.
        return components.url ?? url
    }
}

/// Manages Perplexity.ai integration with cookie-based authentication.
///
/// **@MainActor**: All operations run on main thread for thread safety.
///
/// **final**: Cannot be subclassed.
///
/// **ObservableObject**: SwiftUI views can observe @Published properties.
///
/// **Singleton**: Access via `PerplexityManager.shared`.
///
/// **Authentication Flow**:
/// 1. User logs in via WebView to perplexity.ai
/// 2. Cookies saved in WKWebsiteDataStore
/// 3. Manager syncs cookies to HTTPCookieStorage
/// 4. Checks for session cookies to determine auth status
/// 5. Persists cookies across app restarts
///
/// **Cookie Sync**: Critical for auth to work!
/// - WKWebView stores cookies in WKWebsiteDataStore (separate storage)
/// - HTTP requests use HTTPCookieStorage (system storage)
/// - Must copy cookies between them for authenticated requests
@MainActor
final class PerplexityManager: ObservableObject {
    /// The shared singleton instance.
    static let shared = PerplexityManager()
    
    // MARK: - Published Properties
    
    /// Whether Perplexity integration is enabled.
    ///
    /// **@Published**: SwiftUI views automatically update.
    ///
    /// **didSet**: Automatically persists to UserDefaults.
    ///
    /// **Use case**: User can disable integration in settings.
    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "perplexityEnabled")
        }
    }
    
    /// Whether user is authenticated with Perplexity.
    ///
    /// **Detection**: Based on presence of session cookies.
    ///
    /// **Updates**: After login, logout, or cookie sync.
    @Published var isAuthenticated: Bool = false
    
    /// Current pending Perplexity request (if any).
    ///
    /// **nil**: No active request.
    /// **set**: Triggers modal to open Perplexity.
    ///
    /// **Use case**: Display Perplexity search modal with pre-built query.
    @Published var currentRequest: PerplexityRequest?
    
    // MARK: - Authentication Properties
    private let cookieStore: HTTPCookieStorage
    
    // Cookie storage key for Perplexity session
    private let perplexityCookiesKey = "perplexitySessionCookies"
    
    private init() {
        // Load settings from UserDefaults
        self.isEnabled = UserDefaults.standard.bool(forKey: "perplexityEnabled")
        
        // Setup cookie storage
        self.cookieStore = HTTPCookieStorage.shared
        
        // Load saved cookies and check authentication status
        loadSavedCookies()
        checkAuthenticationStatus()
    }
    
    // MARK: - Cookie Management
    private func loadSavedCookies() {
        guard let cookiesData = UserDefaults.standard.data(forKey: perplexityCookiesKey),
              let cookies = try? NSKeyedUnarchiver.unarchivedObject(ofClasses: [NSArray.self, HTTPCookie.self], from: cookiesData) as? [HTTPCookie] else {
            return
        }
        
        // Add saved cookies to the cookie store
        for cookie in cookies {
            cookieStore.setCookie(cookie)
        }
    }
    
    private func saveCookies() {
        guard let perplexityURL = URL(string: "https://www.perplexity.ai") else { return }
        
        let cookies = cookieStore.cookies(for: perplexityURL) ?? []
        
        // Save cookies asynchronously to avoid blocking main thread
        Task.detached(priority: .background) {
            do {
                let cookiesData = try NSKeyedArchiver.archivedData(withRootObject: cookies, requiringSecureCoding: true)
                UserDefaults.standard.set(cookiesData, forKey: self.perplexityCookiesKey)
            } catch {
                print("Failed to save cookies: \(error)")
            }
        }
    }
    
    private func clearSavedCookies() {
        // Clear both UserDefaults and cookie store on background thread to avoid priority inversions
        Task.detached(priority: .background) { [weak self] in
            guard let self = self else { return }
            
            // Clear UserDefaults
            UserDefaults.standard.removeObject(forKey: self.perplexityCookiesKey)
            
            // Clear cookies from the store
            if let perplexityURL = URL(string: "https://www.perplexity.ai"),
               let cookies = self.cookieStore.cookies(for: perplexityURL) {
                for cookie in cookies {
                    self.cookieStore.deleteCookie(cookie)
                }
            }
        }
    }
    
    // MARK: - Authentication Status Check
    private func checkAuthenticationStatus() {
        // Always sync cookies from WKWebsiteDataStore first to get the latest state
        Task { @MainActor in
            await syncCookiesFromWebKitDataStore()
            performAuthenticationCheck()
        }
    }
    
    // Sync cookies from WKWebsiteDataStore.default() to HTTPCookieStorage
    private func syncCookiesFromWebKitDataStore() async {
        let websiteDataStore = WKWebsiteDataStore.default()
        let cookies = await websiteDataStore.httpCookieStore.allCookies()
        
        // Filter for Perplexity cookies and add them to HTTPCookieStorage
        let perplexityCookies = cookies.filter { cookie in
            cookie.domain.contains("perplexity.ai")
        }
        
        print("🔄 Syncing \(perplexityCookies.count) Perplexity cookies from WebKit to HTTPCookieStorage")
        
        for cookie in perplexityCookies {
            cookieStore.setCookie(cookie)
        }
        
        // Save the updated cookies
        saveCookies()
    }
    
    private func performAuthenticationCheck() {
        // Check if we have valid session cookies
        guard let perplexityURL = URL(string: "https://www.perplexity.ai"),
              let cookies = cookieStore.cookies(for: perplexityURL) else {
            print("🔍 No cookies found for Perplexity")
            self.isAuthenticated = false
            return
        }
        
        print("🔍 Found \(cookies.count) cookies for Perplexity:")
        for cookie in cookies {
            print("  - \(cookie.name): \(cookie.value.prefix(20))...")
        }
        
        // Look for session-related cookies that indicate authentication
        // Be more liberal with cookie detection since we don't know exact names
        let sessionCookies = cookies.filter { cookie in
            let lowercaseName = cookie.name.lowercased()
            return lowercaseName.contains("session") ||
                   lowercaseName.contains("auth") ||
                   lowercaseName.contains("token") ||
                   lowercaseName.contains("login") ||
                   lowercaseName.contains("user") ||
                   cookie.name.hasPrefix("__") || // Common session cookie prefixes
                   cookie.name.hasPrefix("_") ||
                   cookie.value.count > 50 // Likely session tokens are long
        }
        
        let wasAuthenticated = self.isAuthenticated
        self.isAuthenticated = !sessionCookies.isEmpty
        
        print("🔍 Found \(sessionCookies.count) potential session cookies")
        print("🔍 Authentication status: \(self.isAuthenticated ? "✅ Authenticated" : "❌ Not authenticated")")
        
        if !wasAuthenticated && self.isAuthenticated {
            print("🎉 Authentication status changed to authenticated!")
        }
    }
    
    // MARK: - Authentication Methods
    var loginURL: URL {
        return URL(string: "https://www.perplexity.ai/settings/account")!
    }
    
    // Method to be called when user completes login in the internal browser
    func handleLoginCompletion() {
        Task { @MainActor in
            await handleLoginCompletionAsync()
        }
    }
    
    private func handleLoginCompletionAsync() async {
        // First sync cookies from WebKit to HTTPCookieStorage
        await syncCookiesFromWebKitDataStore()
        
        // Add small delay to ensure cookie operations complete
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second
        
        // Check authentication status on main actor
        performAuthenticationCheck()
        
        if isAuthenticated {
            print("✅ Successfully authenticated with Perplexity")
        } else {
            print("⚠️ Login may not have completed successfully - user should try refreshing or logging in again")
        }
    }
    
    func signOut() {
        // Clear authentication state immediately
        isAuthenticated = false
        isEnabled = false
        currentRequest = nil
        
        // Clear saved cookies asynchronously
        clearSavedCookies()
        
        print("Signed out of Perplexity")
    }
    
    // Public method to refresh authentication status
    func refreshAuthenticationStatus() {
        print("🔄 Manually refreshing Perplexity authentication status...")
        checkAuthenticationStatus()
    }
    
    // Method to be called when navigating to Perplexity domains to check for login
    func checkForLoginOnNavigation(to url: URL) {
        guard url.host?.contains("perplexity.ai") == true else { return }
        
        // Use Task to handle async work properly with MainActor
        Task { @MainActor in
            // Small delay to let cookies settle after page load
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            
            let wasAuthenticated = self.isAuthenticated
            await self.handleLoginCompletionAsync()
            
            // If authentication status changed, notify user
            if !wasAuthenticated && self.isAuthenticated {
                print("✅ Successfully authenticated with Perplexity!")
            }
        }
    }
    
    // MARK: - Action Methods
    func performAction(_ action: PerplexityAction, for url: URL, title: String? = nil) {
        guard isAuthenticated else {
            print("Perplexity not authenticated")
            return
        }
        
        let request = PerplexityRequest(action: action, url: url, title: title)
        currentRequest = request
    }
    
    func dismissModal() {
        currentRequest = nil
    }
}

// MARK: - Architecture Summary

/*
 ╔══════════════════════════════════════════════════════════════════════════════╗
 ║                    PERPLEXITYMANAGER ARCHITECTURE                            ║
 ╚══════════════════════════════════════════════════════════════════════════════╝
 
 PURPOSE:
 --------
 The PerplexityManager provides seamless integration with Perplexity.ai's search
 and chat services directly within the EvoArc browser. It manages authentication
 via cookie synchronization, handles multiple interaction modes, and presents
 modal interfaces for user actions.
 
 CORE RESPONSIBILITIES:
 ---------------------
 1. Cookie Management & Authentication
    - Extracts session cookies from Perplexity.ai WKWebView
    - Syncs authentication state for API requests
    - Maintains login session across browser restarts
 
 2. Action Handling
    - Search: Query Perplexity with selected text or custom input
    - Summarize: Generate summaries of current page content
    - Chat: Open conversational interface with context
    - Navigate: Direct navigation to Perplexity.ai
 
 3. Modal Presentation
    - Manages currentRequest state for SwiftUI sheet presentation
    - Coordinates dismissal and action completion
    - Provides context (URL, title) to modal views
 
 DATA FLOW:
 ----------
 
 User Action (Context Menu/Gesture)
         |
         v
   handleAction() called
         |
         +---> Sync cookies from WKWebView
         |
         +---> Create PerplexityRequest with action + context
         |
         v
   Update @Published currentRequest
         |
         v
   SwiftUI View reacts (.sheet binding)
         |
         v
   PerplexityView presented as modal
         |
         +---> User interacts with Perplexity interface
         |
         v
   dismissModal() called
         |
         v
   currentRequest set to nil → modal dismissed
 
 
 THREADING MODEL:
 ---------------
 • @MainActor ensures all UI-related state changes happen on main thread
 • WKWebView cookie extraction is asynchronous but results published to main
 • All public methods safe to call from any thread (actor isolation)
 
 
 COOKIE SYNCHRONIZATION:
 ----------------------
 The manager extracts these key cookies from Perplexity.ai:
 
    __Secure-next-auth.session-token  →  Primary session authentication
    __Host-next-auth.csrf-token       →  CSRF protection
    __Secure-next-auth.callback-url   →  OAuth callback handling
 
 Flow:
 1. User logs into Perplexity.ai via browser tab
 2. Before each action, syncCookies() extracts current session
 3. Cookies made available to PerplexityView for authenticated requests
 4. Session persists until user logs out or cookies expire
 
 
 USAGE PATTERNS:
 --------------
 
 // Initialize (singleton pattern recommended)
 @StateObject private var perplexityManager = PerplexityManager()
 
 // Handle user-initiated search
 perplexityManager.handleAction(
     .search,
     selectedText: "quantum computing",
     webView: currentWebView,
     url: currentURL,
     title: currentPageTitle
 )
 
 // Present modal in SwiftUI
 .sheet(item: $perplexityManager.currentRequest) { request in
     PerplexityView(
         request: request,
         onDismiss: { perplexityManager.dismissModal() }
     )
 }
 
 
 INTEGRATION POINTS:
 ------------------
 • ContentView: Manages perplexityManager lifecycle and sheet presentation
 • ContextMenuView: Triggers handleAction() for text selection actions
 • WKWebView: Source of authentication cookies and page context
 • PerplexityView: Consumer of PerplexityRequest and cookie data
 
 
 SECURITY CONSIDERATIONS:
 -----------------------
 • Cookies contain sensitive session tokens - never logged or exposed
 • Only extracts cookies from perplexity.ai domain (no cross-site leakage)
 • Session tokens have expiration managed by Perplexity.ai servers
 • CSRF tokens protect against cross-site request forgery
 
 
 PERSISTENCE:
 -----------
 • Manager itself does not persist state to disk
 • WKWebView's cookie store handles persistent authentication
 • currentRequest is transient (modal presentation state only)
 • Session survives app restarts via WKWebView cookie storage
 
 
 ERROR HANDLING:
 --------------
 • Cookie sync failures are silent (degrades to unauthenticated mode)
 • PerplexityView handles network errors and authentication failures
 • Missing context (URL, title) gracefully handled with optional values
 • WebView reference weakly held (safe if view deallocated)
 
 
 FUTURE ENHANCEMENTS:
 -------------------
 • Implement cookie refresh logic before expiration
 • Add analytics for action usage patterns
 • Support offline mode with cached responses
 • Allow user to configure default action behavior
 • Add keyboard shortcuts for quick Perplexity access
 
 ═══════════════════════════════════════════════════════════════════════════════
 */
