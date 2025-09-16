//
//  iOSVersionHelper.swift
//  EvoArc
//
//  iOS version detection utility for selecting appropriate DoH implementation
//

/**
 * # iOSVersionHelper
 * 
 * Utility class to detect iOS version and determine which DNS over HTTPS (DoH)
 * implementation approach should be used for optimal compatibility and performance.
 * 
 * ## Architecture Overview
 * 
 * ### For New Swift Developers:
 * - **Static Methods**: Class methods that don't require instantiation
 * - **Version Comparison**: Using operating system version checking
 * - **Feature Detection**: Determining available APIs based on iOS version
 * - **Strategy Pattern**: Selecting implementation strategy based on capabilities
 * 
 * ### DoH Implementation Strategy Selection:
 * - **iOS 17+**: Use network proxy server approach for system-wide DNS control
 * - **iOS 14-16**: Use URLSession protocol interception for app-specific DNS
 * - **iOS 13 and below**: Fallback to system DNS (no DoH support)
 * 
 * ## Usage Examples:
 * ```swift
 * if iOSVersionHelper.supportsNetworkProxyDoH {
 *     // Use proxy server approach (iOS 17+)
 *     let proxyConfig = DoHProxyManager()
 * } else if iOSVersionHelper.supportsURLProtocolDoH {
 *     // Use URL protocol approach (iOS 14-16)
 *     let urlConfig = DoHURLSessionConfig()
 * } else {
 *     // Fall back to system DNS
 *     print("DoH not supported on this iOS version")
 * }
 * ```
 */

import Foundation
import WebKit
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// Utility for iOS version detection and DoH feature availability
public class iOSVersionHelper {
    
    // MARK: - Version Detection
    
    /// Current iOS major version (e.g., 17 for iOS 17.x)
    public static var currentMajorVersion: Int {
        return ProcessInfo.processInfo.operatingSystemVersion.majorVersion
    }
    
    /// Current iOS minor version (e.g., 2 for iOS 17.2)
    public static var currentMinorVersion: Int {
        return ProcessInfo.processInfo.operatingSystemVersion.minorVersion
    }
    
    /// Current iOS patch version (e.g., 1 for iOS 17.2.1)
    public static var currentPatchVersion: Int {
        return ProcessInfo.processInfo.operatingSystemVersion.patchVersion
    }
    
    /// Full iOS version string for debugging (e.g., "17.2.1")
    public static var versionString: String {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
    }
    
    // MARK: - DoH Feature Support Detection
    
    /// Whether the device supports network proxy-based DoH (iOS 17+)
    /// 
    /// Network proxy approach provides system-wide DNS control and is the
    /// preferred method for DoH implementation on supported devices.
    public static var supportsNetworkProxyDoH: Bool {
        return currentMajorVersion >= 17
    }
    
    /// Whether the device supports URLSession protocol-based DoH (iOS 14+)
    /// 
    /// URLSession protocol approach provides app-specific DNS control and
    /// serves as a fallback for devices that don't support the proxy approach.
    public static var supportsURLProtocolDoH: Bool {
        return currentMajorVersion >= 14
    }
    
    /// Whether the device supports any form of DoH implementation
    /// 
    /// Returns true if the device can use either proxy-based or URLSession-based DoH.
    public static var supportsDoH: Bool {
        return supportsURLProtocolDoH || supportsNetworkProxyDoH
    }
    
    /// Whether WKWebView supports modern configuration options
    /// 
    /// Some WKWebView configuration features require iOS 15+
    public static var supportsModernWebViewConfig: Bool {
        return currentMajorVersion >= 15
    }
    
    // MARK: - Recommended DoH Strategy
    
    /// The recommended DoH implementation strategy for the current device
    public enum DoHStrategy {
        /// Use network proxy server approach (iOS 17+)
        case networkProxy
        /// Use URLSession protocol interception (iOS 14-16)
        case urlProtocol
        /// DoH not supported, use system DNS
        case systemDNS
        
        /// Human-readable description of the strategy
        var description: String {
            switch self {
            case .networkProxy:
                return "Network Proxy (iOS 17+)"
            case .urlProtocol:
                return "URLSession Protocol (iOS 14-16)"
            case .systemDNS:
                return "System DNS (iOS 13 and below)"
            }
        }
        
        /// Whether this strategy provides DoH functionality
        var providesDoH: Bool {
            switch self {
            case .networkProxy, .urlProtocol:
                return true
            case .systemDNS:
                return false
            }
        }
    }
    
    /// Returns the recommended DoH strategy for the current iOS version
    /// 
    /// This method considers both feature availability and performance
    /// characteristics to recommend the best DoH approach.
    /// 
    /// - Returns: The recommended DoH strategy
    public static var recommendedDoHStrategy: DoHStrategy {
        if supportsNetworkProxyDoH {
            return .networkProxy
        } else if supportsURLProtocolDoH {
            return .urlProtocol
        } else {
            return .systemDNS
        }
    }
    
    // MARK: - Version Comparison Utilities
    
    /// Checks if the current iOS version is at least the specified version
    /// 
    /// - Parameters:
    ///   - major: Major version to compare against
    ///   - minor: Minor version to compare against (default: 0)
    ///   - patch: Patch version to compare against (default: 0)
    /// - Returns: true if current version is >= specified version
    public static func isVersion(atLeast major: Int, minor: Int = 0, patch: Int = 0) -> Bool {
        let current = ProcessInfo.processInfo.operatingSystemVersion
        
        if current.majorVersion > major {
            return true
        } else if current.majorVersion == major {
            if current.minorVersion > minor {
                return true
            } else if current.minorVersion == minor {
                return current.patchVersion >= patch
            }
        }
        
        return false
    }
    
    /// Checks if the current iOS version is exactly the specified version
    /// 
    /// - Parameters:
    ///   - major: Major version to compare against
    ///   - minor: Minor version to compare against (default: 0)
    ///   - patch: Patch version to compare against (default: 0)
    /// - Returns: true if current version matches exactly
    public static func isVersion(exactly major: Int, minor: Int = 0, patch: Int = 0) -> Bool {
        let current = ProcessInfo.processInfo.operatingSystemVersion
        return current.majorVersion == major && 
               current.minorVersion == minor && 
               current.patchVersion == patch
    }
    
    /// Checks if the current iOS version is below the specified version
    /// 
    /// - Parameters:
    ///   - major: Major version to compare against
    ///   - minor: Minor version to compare against (default: 0)
    ///   - patch: Patch version to compare against (default: 0)
    /// - Returns: true if current version is < specified version
    public static func isVersion(below major: Int, minor: Int = 0, patch: Int = 0) -> Bool {
        return !isVersion(atLeast: major, minor: minor, patch: patch)
    }
    
    // MARK: - Debug Information
    
    /// Generates a comprehensive debug report about iOS version and DoH support
    /// 
    /// This method is useful for troubleshooting DoH configuration issues
    /// and understanding why a particular strategy was selected.
    /// 
    /// - Returns: Debug information string
    public static func debugReport() -> String {
        let strategy = recommendedDoHStrategy
        
        return """
        iOS Version Debug Report
        ========================
        iOS Version: \(versionString)
        Major: \(currentMajorVersion), Minor: \(currentMinorVersion), Patch: \(currentPatchVersion)
        
        DoH Support:
        - Network Proxy DoH: \(supportsNetworkProxyDoH ? "✅" : "❌") (iOS 17+)
        - URLSession DoH: \(supportsURLProtocolDoH ? "✅" : "❌") (iOS 14+)
        - Any DoH: \(supportsDoH ? "✅" : "❌")
        
        Other Features:
        - Modern WebView Config: \(supportsModernWebViewConfig ? "✅" : "❌") (iOS 15+)
        
        Recommended Strategy: \(strategy.description)
        Provides DoH: \(strategy.providesDoH ? "✅" : "❌")
        """
    }
    
    // MARK: - Device Information
    
    /// Device model identifier (e.g., "iPhone14,2")
    public static var deviceModel: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let modelCode = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                ptr in String.init(validatingUTF8: ptr)
            }
        }
        return modelCode ?? "Unknown"
    }
    
    /// Whether the device is running in a simulator
    public static var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }
    
    /// Device type (iPhone, iPad, etc.)
    public static var deviceType: String {
        #if os(iOS)
        switch UIDevice.current.userInterfaceIdiom {
        case .phone:
            return "iPhone"
        case .pad:
            return "iPad"
        case .tv:
            return "Apple TV"
        case .carPlay:
            return "CarPlay"
        case .mac:
            return "Mac (Catalyst)"
        case .unspecified:
            return "Unspecified"
        case .vision:
            return "Vision Pro"
        @unknown default:
            return "Unknown"
        }
        #elseif os(macOS)
        return "Mac"
        #else
        return "Unknown Platform"
        #endif
    }
    
    /// Extended debug report including device information
    public static func extendedDebugReport() -> String {
        return """
        \(debugReport())
        
        Device Information:
        - Device Type: \(deviceType)
        - Device Model: \(deviceModel)
        - Simulator: \(isSimulator ? "Yes" : "No")
        """
    }
}

// MARK: - DoH Configuration Factory

/// Factory class for creating appropriate DoH configuration based on iOS version
public class DoHConfigurationFactory {
    
    /// Creates the appropriate DoH configuration for the current iOS version
    /// 
    /// This factory method automatically selects the best DoH implementation
    /// based on the current iOS version and returns a configured instance.
    /// 
    /// - Returns: DoH configuration object or nil if DoH is not supported
    public static func createDoHConfiguration() -> AnyObject? {
        switch iOSVersionHelper.recommendedDoHStrategy {
        case .networkProxy:
            // Return proxy server configuration for iOS 17+
            if #available(iOS 17.0, *) {
                return DoHProxyManager()
            } else {
                return DoHProxyManagerFallback()
            }
        case .urlProtocol:
            // Return URLSession configuration for iOS 14-16
            return DoHURLSessionConfig()
        case .systemDNS:
            // No DoH configuration needed/supported
            return nil
        }
    }
    
    /// Creates a WKWebViewConfiguration with the appropriate DoH setup
    /// 
    /// This method automatically configures WKWebView to use the best available
    /// DoH implementation for the current iOS version.
    /// 
    /// - Returns: Configured WKWebViewConfiguration
    public static func createWebViewConfiguration() -> WKWebViewConfiguration {
        switch iOSVersionHelper.recommendedDoHStrategy {
        case .networkProxy:
            // Use proxy server configuration
            if #available(iOS 17.0, *) {
                let proxyManager = DoHProxyManager()
                return proxyManager.createWKWebViewConfiguration()
            } else {
                let fallbackManager = DoHProxyManagerFallback()
                return fallbackManager.createWKWebViewConfiguration()
            }
        case .urlProtocol:
            // Use URLSession configuration
            let urlConfig = DoHURLSessionConfig()
            return urlConfig.createWKWebViewConfiguration()
        case .systemDNS:
            // Standard configuration without DoH
            print("⚠️ DoH not supported on iOS \(iOSVersionHelper.versionString), using system DNS")
            return WKWebViewConfiguration()
        }
    }
}

// MARK: - Usage Example (for documentation)

/*
 Example usage of iOS version detection and DoH configuration:
 
 ```swift
 import UIKit
 import WebKit
 
 class BrowserViewController: UIViewController {
     
     override func viewDidLoad() {
         super.viewDidLoad()
         
         // Check iOS version and DoH support
         print(iOSVersionHelper.debugReport())
         
         // Create appropriate DoH-enabled WebView
         let webViewConfig = DoHConfigurationFactory.createWebViewConfiguration()
         let webView = WKWebView(frame: view.bounds, configuration: webViewConfig)
         view.addSubview(webView)
         
         // Load a website with DoH-enabled DNS resolution
         if let url = URL(string: "https://example.com") {
             webView.load(URLRequest(url: url))
         }
     }
 }
 ```
 */