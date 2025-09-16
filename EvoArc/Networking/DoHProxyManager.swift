//
//  DoHProxyManager.swift
//  EvoArc
//
//  DNS over HTTPS proxy manager for iOS 17+ using NetworkExtension framework
//

/**
 * # DoHProxyManager
 * 
 * Manages DNS over HTTPS (DoH) using the iOS 17+ network proxy approach.
 * This implementation uses the NetworkExtension framework to provide
 * system-wide DNS interception and resolution via DoH providers.
 * 
 * ## Architecture Overview
 * 
 * ### For New Swift Developers:
 * - **NetworkExtension**: iOS framework for network configuration
 * - **NEDNSProxyManager**: Manages DNS proxy configurations
 * - **System-Wide DNS**: Affects all apps and system services
 * - **Privileged Operations**: Requires user permission for network changes
 * 
 * ### iOS 17+ Features:
 * - **Native DoH Support**: Built-in DNS over HTTPS in iOS 17+
 * - **System Integration**: Works with all network traffic
 * - **Better Performance**: More efficient than URL protocol approach
 * - **User Permission**: Requires VPN configuration permission
 * 
 * ## Implementation Strategy:
 * 1. **Proxy Configuration**: Set up NEDNSProxyManager with DoH endpoints
 * 2. **Permission Handling**: Request and manage VPN configuration permissions
 * 3. **Provider Management**: Support multiple DoH providers
 * 4. **Fallback Handling**: Graceful degradation on permission denial
 * 
 * ## Usage:
 * ```swift
 * let proxyManager = DoHProxyManager()
 * let webViewConfig = proxyManager.createWKWebViewConfiguration()
 * ```
 * 
 * ## Important Notes:
 * - Only available on iOS 17+
 * - Requires user permission for VPN configuration
 * - Affects system-wide DNS resolution
 * - Falls back to standard configuration if unavailable
 */

import Foundation
import WebKit
import Combine
#if canImport(NetworkExtension)
import NetworkExtension
#endif

/// DoH proxy manager for iOS 17+ network proxy approach
@available(iOS 17.0, *)
class DoHProxyManager: ObservableObject { /* deprecated - not used */
    
    // MARK: - Configuration
    
    /// DoH provider endpoints
    enum DoHProvider: String, CaseIterable {
        /// Google Public DNS
        case google = "https://dns.google/dns-query"
        /// Cloudflare DNS
        case cloudflare = "https://cloudflare-dns.com/dns-query"
        /// Quad9 DNS
        case quad9 = "https://dns.quad9.net/dns-query"
        
        /// Human-readable name
        var displayName: String {
            switch self {
            case .google:
                return "Google DNS"
            case .cloudflare:
                return "Cloudflare DNS"
            case .quad9:
                return "Quad9 DNS"
            }
        }
    }
    
    /// Current DoH provider
    private var provider: DoHProvider = .google
    
    /// DNS proxy manager (iOS 17+ only)
    #if canImport(NetworkExtension)
    private var proxyManager: NEDNSProxyManager?
    #endif
    
    /// Published property to track proxy status
    @Published private(set) var isActive: Bool = false
    
    /// Published property to track permission status
    @Published private(set) var hasPermission: Bool = false
    
    // MARK: - Initialization
    
    /// Creates a new DoH proxy manager
    init() {
        checkAvailability()
    }
    
    // MARK: - Public Methods
    
    /// Creates a WKWebViewConfiguration with DoH proxy support
    /// 
    /// This configuration leverages the iOS 17+ network proxy capabilities
    /// to provide system-wide DoH resolution for the WebView.
    /// 
    /// - Returns: Configured WKWebViewConfiguration
    func createWKWebViewConfiguration() -> WKWebViewConfiguration {
        let configuration = WKWebViewConfiguration()
        
        // Configure basic WebView preferences
        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        configuration.defaultWebpagePreferences = preferences
        
        // Allow JavaScript to open windows
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        
        // iOS-specific media settings
        #if os(iOS)
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.allowsAirPlayForMediaPlayback = true
        configuration.allowsPictureInPictureMediaPlayback = true
        #endif
        
        // Use default website data store - DNS proxy handles resolution
        configuration.websiteDataStore = WKWebsiteDataStore.default()
        
        print("✅ iOS 17+ DoH proxy configuration created")
        
        return configuration
    }
    
    /// Enables DoH proxy with the specified provider
    /// - Parameter provider: DoH provider to use
    func enableDoH(provider: DoHProvider = .google) async {
        #if canImport(NetworkExtension)
        self.provider = provider
        
        await setupDNSProxy()
        #else
        print("⚠️ NetworkExtension not available - DoH proxy not supported")
        #endif
    }
    
    /// Disables DoH proxy and returns to system DNS
    func disableDoH() async {
        #if canImport(NetworkExtension)
        await teardownDNSProxy()
        #endif
    }
    
    /// Changes the DoH provider
    /// - Parameter provider: New provider to use
    func setProvider(_ provider: DoHProvider) async {
        guard provider != self.provider else { return }
        
        self.provider = provider
        
        if isActive {
            // Restart with new provider
            await disableDoH()
            await enableDoH(provider: provider)
        }
    }
    
    // MARK: - Private Implementation
    
    /// Checks if DoH proxy is available on this system
    private func checkAvailability() {
        #if canImport(NetworkExtension)
        #if os(iOS)
        print("✅ iOS 17+ DoH proxy support available")
        checkPermissions()
        #else
        print("✅ macOS DoH proxy support available")
        checkPermissions()
        #endif
        #else
        print("⚠️ NetworkExtension framework not available")
        #endif
    }
    
    /// Checks for VPN configuration permissions
    private func checkPermissions() {
        #if canImport(NetworkExtension)
        #if os(iOS)
        NEDNSProxyManager.shared().loadFromPreferences { [weak self] error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Failed to load DNS proxy preferences: \(error)")
                    self?.hasPermission = false
                } else {
                    print("✅ DNS proxy preferences loaded successfully")
                    self?.hasPermission = true
                }
            }
        }
        #else
        NEDNSProxyManager.shared().loadFromPreferences { [weak self] error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Failed to load DNS proxy preferences: \(error)")
                    self?.hasPermission = false
                } else {
                    print("✅ DNS proxy preferences loaded successfully")
                    self?.hasPermission = true
                }
            }
        }
        #endif
        #endif
    }
    
    #if canImport(NetworkExtension)
    /// Sets up the DNS proxy configuration
    @available(iOS 17.0, *)
    private func setupDNSProxy() async {
        do {
            let manager = NEDNSProxyManager.shared()
            
            // Load existing configuration
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                manager.loadFromPreferences { error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            }
            
            // Configure DNS proxy settings
            manager.localizedDescription = "EvoArc DoH Proxy"
            manager.isEnabled = true
            
            // Configure proxy provider settings
            let providerConfiguration = NEDNSProxyProviderProtocol()
            providerConfiguration.providerBundleIdentifier = Bundle.main.bundleIdentifier
            providerConfiguration.serverAddress = provider.rawValue
            
            // Configure DoH-specific settings
            providerConfiguration.providerConfiguration = [
                "doh_endpoint": provider.rawValue,
                "provider_name": provider.displayName
            ]
            
            manager.providerProtocol = providerConfiguration
            
            // Save configuration
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                manager.saveToPreferences { error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            }
            
            await MainActor.run {
                self.isActive = true
                self.hasPermission = true
            }
            
            print("✅ DoH proxy enabled with \(provider.displayName)")
            
        } catch {
            print("❌ Failed to setup DoH proxy: \(error)")
            
            await MainActor.run {
                self.isActive = false
                
                // Check if this is a permission error
                if (error as NSError).domain == "NEVPNErrorDomain" {
                    self.hasPermission = false
                }
            }
        }
    }
    
    /// Tears down the DNS proxy configuration
    @available(iOS 17.0, *)
    private func teardownDNSProxy() async {
        do {
            let manager = NEDNSProxyManager.shared()
            
            // Load current configuration
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                manager.loadFromPreferences { error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            }
            
            // Disable the proxy
            manager.isEnabled = false
            
            // Save the disabled configuration
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                manager.saveToPreferences { error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            }
            
            await MainActor.run {
                self.isActive = false
            }
            
            print("✅ DoH proxy disabled")
            
        } catch {
            print("❌ Failed to disable DoH proxy: \(error)")
        }
    }
    #endif
}

// MARK: - Fallback Implementation for iOS < 17

/// Fallback DoH proxy manager for iOS versions before 17
class DoHProxyManagerFallback: ObservableObject {
    
    @Published private(set) var isActive: Bool = false
    @Published private(set) var hasPermission: Bool = false
    
    init() {
        print("⚠️ Using DoH proxy fallback for iOS < 17")
    }
    
    func createWKWebViewConfiguration() -> WKWebViewConfiguration {
        let configuration = WKWebViewConfiguration()
        
        // Configure basic WebView preferences
        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        configuration.defaultWebpagePreferences = preferences
        
        // Allow JavaScript to open windows
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        
        // iOS-specific media settings
        #if os(iOS)
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.allowsAirPlayForMediaPlayback = true
        configuration.allowsPictureInPictureMediaPlayback = true
        #endif
        
        // Use default website data store - no DoH proxy available
        configuration.websiteDataStore = WKWebsiteDataStore.default()
        
        print("⚠️ Standard WebView configuration (no DoH proxy support)")
        
        return configuration
    }
    
    enum DoHProvider {
        case google
        case cloudflare 
        case quad9
    }
    
    func enableDoH(provider: DoHProvider = .google) async {
        print("⚠️ DoH proxy not available on iOS < 17")
    }
    
    func disableDoH() async {
        print("⚠️ DoH proxy not available on iOS < 17")
    }
    
    func setProvider(_ provider: DoHProvider) async {
        print("⚠️ DoH proxy not available on iOS < 17")
    }
}
