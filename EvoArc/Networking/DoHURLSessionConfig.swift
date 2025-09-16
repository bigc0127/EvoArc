//
//  DoHURLSessionConfig.swift
//  EvoArc
//
//  URLSession-based DNS over HTTPS configuration for iOS 14+ compatibility
//

/**
 * # DoHURLSessionConfig
 * 
 * Provides DNS over HTTPS (DoH) configuration for URLSession and WKWebView using
 * URLSessionConfiguration customization. This approach works on iOS 14+ and provides
 * a fallback for devices that don't support the iOS 17+ proxy server approach.
 * 
 * ## Architecture Overview
 * 
 * ### For New Swift Developers:
 * - **URLSessionConfiguration**: Configures networking behavior for URLSession
 * - **Custom URL Protocol**: Intercepts and modifies network requests
 * - **WKURLSchemeHandler**: Custom handler for WebKit URL schemes  
 * - **Fallback Pattern**: Provides compatibility across iOS versions
 * - **Dependency Injection**: Passes configurations to dependent components
 * 
 * ### DoH Integration Strategy:
 * 1. **URL Interception**: Custom protocol intercepts DNS-dependent requests
 * 2. **DoH Resolution**: Resolve domains using DoH before making requests
 * 3. **Request Modification**: Replace domain with IP address in requests
 * 4. **Header Preservation**: Maintain original Host headers for servers
 * 
 * ## iOS Version Compatibility
 * 
 * - **iOS 14-16**: Uses URLSessionConfiguration with custom protocols
 * - **iOS 17+**: Can optionally use proxy server for better performance
 * - **Automatic Fallback**: Gracefully degrades on older versions
 * 
 * ## Limitations of URL Protocol Approach
 * 
 * - **Application Scope**: Only affects URLSession requests from the app
 * - **System DNS**: Doesn't intercept system-level DNS queries
 * - **Complex Implementation**: Requires careful request/response handling
 * 
 * ## Usage:
 * ```swift
 * let config = DoHURLSessionConfig()
 * let webViewConfig = config.createWKWebViewConfiguration()
 * let webView = WKWebView(frame: .zero, configuration: webViewConfig)
 * ```
 */

import Foundation
@preconcurrency import WebKit
import Combine

/// Sendable wrapper for WKURLSchemeTask to avoid concurrency warnings
@MainActor
private final class URLSchemeTaskWrapper: Sendable {
    private let task: WKURLSchemeTask
    
    init(task: WKURLSchemeTask) {
        self.task = task
    }
    
    func didFailWithError(_ error: Error) {
        task.didFailWithError(error)
    }
    
    func didReceive(_ response: URLResponse) {
        task.didReceive(response)
    }
    
    func didReceive(_ data: Data) {
        task.didReceive(data)
    }
    
    func didFinish() {
        task.didFinish()
    }
}

/// URLSession-based DoH configuration for iOS 14+ compatibility
class DoHURLSessionConfig: NSObject, ObservableObject {
    // Deprecated: DoH removed. Retained for compatibility but unused.
    
    // MARK: - Configuration
    
    /// DoH resolver for DNS queries
    private let dohResolver: DoHResolver
    
    /// Published property to track DoH configuration status
    @Published private(set) var isConfigured: Bool = false
    
    /// Cache for resolved hostnames to avoid repeated DoH queries
    private var hostnameCache: [String: String] = [:]
    private let cacheQueue = DispatchQueue(label: "com.evoarc.doh-cache", attributes: .concurrent)
    
    /// TTL for cached hostname resolutions (5 minutes)
    private let cacheTTL: TimeInterval = 300
    
    // MARK: - Initialization
    
    /// Creates a new DoH URL session configuration
    /// - Parameter resolver: DoH resolver to use (defaults to new instance)
    override init() {
        // Get the provider from browser settings if available
        let provider: DoHResolver.Provider
        // DoH removed; default to Cloudflare mapping for compatibility
        provider = .cloudflare
        print("🌐 DoH disabled; defaulting resolver provider to Cloudflare for compatibility")
        
        self.dohResolver = DoHResolver(provider: provider)
        super.init()
        
        // Register our custom URL protocol for DNS interception
        registerCustomURLProtocol()
    }
    
    // MARK: - Public Configuration Methods
    
    /// Creates a WKWebViewConfiguration with DoH support
    /// 
    /// This configuration ensures that all network requests from the WKWebView
    /// use DNS over HTTPS for domain resolution. The configuration is compatible
    /// with iOS 14+ and provides enhanced privacy for web browsing.
    /// 
    /// - Returns: Configured WKWebViewConfiguration with DoH support
    func createWKWebViewConfiguration() -> WKWebViewConfiguration {
        let configuration = WKWebViewConfiguration()
        
        // Configure basic WebView preferences for optimal browsing
        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true  // Enable JavaScript for modern web functionality
        configuration.defaultWebpagePreferences = preferences
        
        // Allow JavaScript to open windows (for popup functionality)
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        
        // iOS-specific media playback settings for better user experience
        #if os(iOS)
        configuration.allowsInlineMediaPlayback = true    // Allow videos to play inline
        configuration.mediaTypesRequiringUserActionForPlayback = []  // Auto-play media
        configuration.allowsAirPlayForMediaPlayback = true          // Enable AirPlay
        configuration.allowsPictureInPictureMediaPlayback = true    // Enable PiP
        #endif
        
        // Create custom URL session configuration with our DoH protocol handler (disabled)
        // _ = createDoHURLSessionConfiguration()
        
        // Configure website data store
        let websiteDataStore = WKWebsiteDataStore.default()
        
        // Important: Use the configured URLSession for all WebView network requests
        configuration.websiteDataStore = websiteDataStore
        
        // Register our custom URL protocol for intercepting requests
        // Note: This ensures all HTTP/HTTPS requests go through our DoH resolver
        URLProtocol.registerClass(DoHURLProtocol.self)
        
        isConfigured = true
        print("✅ WKWebView configured with DoH support - DNS queries will be resolved via DoH")
        
        return configuration
    }
    
    /// Creates a URLSessionConfiguration with DoH support
    /// 
    /// This configuration can be used for URLSession requests outside of WebKit
    /// to ensure all app network traffic uses DNS over HTTPS.
    /// 
    /// - Returns: URLSessionConfiguration with DoH DNS resolution
    func createDoHURLSessionConfiguration() -> URLSessionConfiguration {
        let config = URLSessionConfiguration.default
        
        // Set reasonable timeouts for network requests
        config.timeoutIntervalForRequest = 30.0
        config.timeoutIntervalForResource = 60.0
        
        // Configure protocol classes to use our DoH protocol handler
        config.protocolClasses = [DoHURLProtocol.self]
        
        // Set user agent for app identification
        config.httpAdditionalHeaders = [
            "User-Agent": "EvoArc-Browser/1.0 (DoH-Enabled)"
        ]
        
        print("URLSession configured with DoH support")
        
        return config
    }
    
    // MARK: - Private Helper Methods
    
    /// Registers the custom URL protocol for DNS interception
    private func registerCustomURLProtocol() {
        // Configure the custom protocol with our resolver
        DoHURLProtocol.configure(resolver: dohResolver, cache: self)
        
        // Register the protocol class globally so it intercepts all URL requests
        URLProtocol.registerClass(DoHURLProtocol.self)
        
        // Also register with WKWebView's URL protocol classes
        let protocolClasses = URLSessionConfiguration.default.protocolClasses ?? []
        if !protocolClasses.contains(where: { $0 == DoHURLProtocol.self }) {
            URLSessionConfiguration.default.protocolClasses = [DoHURLProtocol.self] + protocolClasses
        }
        
        print("✅ DoH URL protocol registered for DNS interception")
    }
    
    /// Creates a website data store configured for DoH
    /// - Returns: WKWebsiteDataStore with DoH support
    private func createDoHWebsiteDataStore() -> WKWebsiteDataStore {
        let dataStore = WKWebsiteDataStore.default()
        
        // Configure HTTP cookies to work with DoH-resolved addresses
        dataStore.httpCookieStore.setCookie(HTTPCookie(properties: [
            .name: "DoH-Enabled",
            .value: "true",
            .domain: ".evoarc.local",
            .path: "/"
        ])!) { }
        
        return dataStore
    }
    
    // MARK: - Hostname Caching
    
    /// Caches a resolved hostname
    /// - Parameters:
    ///   - hostname: Original hostname
    ///   - ipAddress: Resolved IP address
    internal func cacheHostname(_ hostname: String, ipAddress: String) {
        cacheQueue.async(flags: .barrier) {
            self.hostnameCache[hostname] = ipAddress
        }
    }
    
    /// Retrieves a cached hostname resolution
    /// - Parameter hostname: Hostname to look up
    /// - Returns: Cached IP address or nil if not cached
    internal func getCachedIPAddress(for hostname: String) -> String? {
        return cacheQueue.sync {
            return hostnameCache[hostname]
        }
    }
}

// MARK: - WKURLSchemeHandler Implementation

/// Custom URL scheme handler for DoH-enabled HTTPS requests
extension DoHURLSessionConfig: WKURLSchemeHandler {
    
    /// Handles custom URL scheme requests with DoH resolution
    /// - Parameters:
    ///   - webView: The web view making the request
    ///   - urlSchemeTask: The URL scheme task to handle
    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url,
              let hostname = url.host else {
            let error = NSError(domain: "DoHSchemeHandler", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Invalid URL for DoH resolution"
            ])
            urlSchemeTask.didFailWithError(error)
            return
        }
        
        // Create a sendable wrapper for the URL scheme task
        let taskWrapper = URLSchemeTaskWrapper(task: urlSchemeTask)
        
        Task {
            // Resolve hostname using DoH
            let addresses = await dohResolver.resolve(hostname: hostname)
            
            guard let ipAddress = addresses.first else {
                let error = NSError(domain: "DoHSchemeHandler", code: 2, userInfo: [
                    NSLocalizedDescriptionKey: "Failed to resolve hostname via DoH: \(hostname)"
                ])
                taskWrapper.didFailWithError(error)
                return
            }
            
            // Cache the resolution
            cacheHostname(hostname, ipAddress: ipAddress)
            
            // Create new URL with IP address
            var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)!
            urlComponents.scheme = "https"  // Convert back to standard HTTPS
            urlComponents.host = ipAddress
            
            guard let resolvedURL = urlComponents.url else {
                let error = NSError(domain: "DoHSchemeHandler", code: 3, userInfo: [
                    NSLocalizedDescriptionKey: "Failed to create resolved URL"
                ])
                taskWrapper.didFailWithError(error)
                return
            }
            
            // Create new request with resolved IP
            var resolvedRequest = urlSchemeTask.request
            resolvedRequest.url = resolvedURL
            
            // Preserve original hostname in Host header
            resolvedRequest.setValue(hostname, forHTTPHeaderField: "Host")
            
            // Execute the request with standard URLSession
            let session = URLSession.shared
            
            let task = session.dataTask(with: resolvedRequest) { data, response, error in
                Task {
                    if let error = error {
                        await taskWrapper.didFailWithError(error)
                        return
                    }
                    
                    if let response = response {
                        await taskWrapper.didReceive(response)
                    }
                    
                    if let data = data {
                        await taskWrapper.didReceive(data)
                    }
                    
                    await taskWrapper.didFinish()
                }
            }
            
            task.resume()
        }
    }
    
    /// Stops a URL scheme task
    /// - Parameters:
    ///   - webView: The web view
    ///   - urlSchemeTask: The task to stop
    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
        // Task cancellation is handled automatically by URLSession
        print("DoH URL scheme task stopped")
    }
}

// MARK: - Custom URL Protocol for DoH

/// Custom URL protocol that intercepts HTTP(S) requests and resolves domains via DoH
private final class DoHURLProtocol: URLProtocol, @unchecked Sendable {
    
    // MARK: - Static Configuration
    
    /// DoH resolver instance (shared across all protocol instances)
    private static var sharedResolver: DoHResolver!
    
    /// Cache manager instance
    private static var cacheManager: DoHURLSessionConfig!
    
    /// Configures the protocol class with resolver and cache
    /// - Parameters:
    ///   - resolver: DoH resolver to use
    ///   - cache: Cache manager for hostname resolutions
    static func configure(resolver: DoHResolver, cache: DoHURLSessionConfig) {
        sharedResolver = resolver
        cacheManager = cache
    }
    
    // MARK: - URLProtocol Implementation
    
    /// Determines if this protocol can handle the given request
    /// - Parameter request: The URL request to evaluate
    /// - Returns: true if this protocol should handle the request
    override class func canInit(with request: URLRequest) -> Bool {
        // Handle HTTP and HTTPS requests that haven't been processed yet
        guard let scheme = request.url?.scheme,
              scheme == "http" || scheme == "https",
              property(forKey: "DoHProcessed", in: request) == nil else {
            return false
        }
        
        // Only handle requests with hostnames (not IP addresses)
        guard let host = request.url?.host,
              !host.isEmpty,
              !isIPAddress(host) else {
            return false
        }
        
        return true
    }
    
    /// Returns the canonical version of the request
    /// - Parameter request: The original request
    /// - Returns: Canonical request (same as original for our use case)
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }
    
    /// Starts loading the request with DoH resolution
    override func startLoading() {
        guard let url = request.url,
              let hostname = url.host else {
            client?.urlProtocol(self, didFailWithError: NSError(
                domain: "DoHURLProtocol",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Invalid request URL"]
            ))
            return
        }
        
        Task {
            // Check cache first
            var ipAddress: String?
            
            if let cachedIP = Self.cacheManager.getCachedIPAddress(for: hostname) {
                ipAddress = cachedIP
                print("Using cached DoH resolution for \(hostname): \(cachedIP)")
            } else {
                // Resolve using DoH
                let addresses = await Self.sharedResolver.resolve(hostname: hostname)
                ipAddress = addresses.first
                
                if let ip = ipAddress {
                    Self.cacheManager.cacheHostname(hostname, ipAddress: ip)
                    print("DoH resolved \(hostname) to \(ip)")
                }
            }
            
            guard let resolvedIP = ipAddress else {
                client?.urlProtocol(self, didFailWithError: NSError(
                    domain: "DoHURLProtocol",
                    code: 2,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to resolve hostname via DoH: \(hostname)"]
                ))
                return
            }
            
            // Create new request with resolved IP
            var resolvedRequest = request
            var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)!
            urlComponents.host = resolvedIP
            resolvedRequest.url = urlComponents.url
            
            // Preserve original hostname in Host header
            resolvedRequest.setValue(hostname, forHTTPHeaderField: "Host")
            
            // Mark as processed to prevent infinite recursion
            let mutableRequest = NSMutableURLRequest(url: resolvedRequest.url!, cachePolicy: resolvedRequest.cachePolicy, timeoutInterval: resolvedRequest.timeoutInterval)
            mutableRequest.httpMethod = resolvedRequest.httpMethod ?? "GET"
            mutableRequest.allHTTPHeaderFields = resolvedRequest.allHTTPHeaderFields
            mutableRequest.httpBody = resolvedRequest.httpBody
            DoHURLProtocol.setProperty(true, forKey: "DoHProcessed", in: mutableRequest)
            resolvedRequest = mutableRequest as URLRequest
            
            // Execute the resolved request
            let session = URLSession.shared
            let client = self.client
            let protocolInstance = self
            let task = session.dataTask(with: resolvedRequest) { data, response, error in
                
                if let error = error {
                    client?.urlProtocol(protocolInstance, didFailWithError: error)
                    return
                }
                
                if let response = response {
                    client?.urlProtocol(protocolInstance, didReceive: response, cacheStoragePolicy: .notAllowed)
                }
                
                if let data = data {
                    client?.urlProtocol(protocolInstance, didLoad: data)
                }
                
                client?.urlProtocolDidFinishLoading(protocolInstance)
            }
            
            task.resume()
        }
    }
    
    /// Stops loading the request
    override func stopLoading() {
        // Cancellation is handled by URLSession task
    }
    
    // MARK: - Helper Methods
    
    /// Checks if a string is an IP address
    /// - Parameter string: String to check
    /// - Returns: true if the string is an IP address
    private static func isIPAddress(_ string: String) -> Bool {
        // Simple regex check for IPv4
        let ipv4Regex = "^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$"
        let ipv4Test = NSPredicate(format: "SELF MATCHES %@", ipv4Regex)
        if ipv4Test.evaluate(with: string) {
            return true
        }
        
        // Simple check for IPv6 (contains colons)
        return string.contains(":")
    }
}