//
//  PerplexityManager.swift
//  EvoArc
//
//  Created on 2025-09-06.
//

import Foundation
import SwiftUI
import Combine
import WebKit

enum PerplexityAction {
    case summarize
    case sendToPerplexity
}

struct PerplexityRequest: Identifiable {
    let id = UUID()
    let action: PerplexityAction
    let url: URL
    let title: String?
    
    var perplexityURL: URL {
        let baseURL = "https://www.perplexity.ai/search"
        var components = URLComponents(string: baseURL)!
        
        let query: String
        switch action {
        case .summarize:
            query = "Summarize this webpage: \(url.absoluteString)"
        case .sendToPerplexity:
            if let title = title, !title.isEmpty {
                query = "About \"\(title)\": \(url.absoluteString)"
            } else {
                query = url.absoluteString
            }
        }
        
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "source", value: "evoarc")
        ]
        
        return components.url ?? url
    }
}

@MainActor
class PerplexityManager: ObservableObject {
    static let shared = PerplexityManager()
    
    // MARK: - Published Properties
    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "perplexityEnabled")
        }
    }
    
    @Published var isAuthenticated: Bool = false
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
