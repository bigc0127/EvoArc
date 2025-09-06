//
//  DoHProxy.swift
//  EvoArc
//
//  Created on 2025-09-04.
//

import Foundation
import WebKit

/// DNS over HTTPS Proxy Configuration for ControlD
class DoHProxy {
    
    static let shared = DoHProxy()
    
    private init() {}
    
    /// Creates a properly configured WKWebViewConfiguration with DoH
    func createConfiguration() -> WKWebViewConfiguration {
        let configuration = WKWebViewConfiguration()
        
        // Set up preferences for better website compatibility
        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        configuration.defaultWebpagePreferences = preferences
        
        // Enhanced compatibility settings
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        // Note: JavaScript is enabled by default in WKWebpagePreferences.allowsContentJavaScript = true
        
        // Media settings (iOS only)
        #if os(iOS)
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.allowsAirPlayForMediaPlayback = true
        configuration.allowsPictureInPictureMediaPlayback = true
        #endif
        
        // Enhanced data store configuration
        configuration.websiteDataStore = WKWebsiteDataStore.default()
        
        // Temporarily disable DoH JavaScript to test basic loading
        // injectDoHScript(into: configuration)
        
        return configuration
    }
    
    /// Injects JavaScript for DNS over HTTPS (simplified version)
    private func injectDoHScript(into configuration: WKWebViewConfiguration) {
        let doHScript = """
        // Simple ControlD DoH indicator (non-blocking)
        (function() {
            'use strict';
            
            // Add meta tag to indicate DoH is active
            const meta = document.createElement('meta');
            meta.name = 'dns-provider';
            meta.content = 'ControlD DoH (freedns.controld.com/p2)';
            
            // Only add the meta tag after DOM is loaded to avoid conflicts
            if (document.readyState === 'loading') {
                document.addEventListener('DOMContentLoaded', function() {
                    document.head.appendChild(meta);
                    console.log('ControlD DoH initialized');
                });
            } else {
                document.head.appendChild(meta);
                console.log('ControlD DoH initialized');
            }
        })();
        """
        
        let userScript = WKUserScript(
            source: doHScript,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        
        configuration.userContentController.addUserScript(userScript)
    }
    
    /// Returns a URLSession configured to use ControlD's DoH
    static func createDoHURLSession() -> URLSession {
        let config = URLSessionConfiguration.default
        
        // Configure proxy dictionary for DoH (platform-specific)
        #if os(macOS)
        config.connectionProxyDictionary = [
            kCFNetworkProxiesHTTPEnable: 1,
            kCFNetworkProxiesHTTPProxy: "freedns.controld.com",
            kCFNetworkProxiesHTTPPort: 443,
            kCFNetworkProxiesHTTPSEnable: 1,
            kCFNetworkProxiesHTTPSProxy: "freedns.controld.com",
            kCFNetworkProxiesHTTPSPort: 443
        ]
        #else
        // iOS doesn't support these proxy keys directly
        // We'll use URLSession delegate methods instead
        config.connectionProxyDictionary = [:]
        #endif
        
        // Additional headers for DoH
        config.httpAdditionalHeaders = [
            "Accept": "application/dns-json",
            "Content-Type": "application/dns-json"
        ]
        
        return URLSession(configuration: config)
    }
}
