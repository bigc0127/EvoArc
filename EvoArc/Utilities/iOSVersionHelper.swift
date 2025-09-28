//
//  iOSVersionHelper.swift
//  EvoArc
//
//  iOS/macOS version detection utility
//

import Foundation
import WebKit
import SystemConfiguration

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// Utility for iOS/macOS version detection
public class iOSVersionHelper {
    
    // MARK: - Version Properties
    
    /// Current OS major version (e.g., 17 for iOS/macOS 17.x)
    public static var currentMajorVersion: Int {
        return ProcessInfo.processInfo.operatingSystemVersion.majorVersion
    }
    
    /// Current OS minor version (e.g., 2 for version 17.2)
    public static var currentMinorVersion: Int {
        return ProcessInfo.processInfo.operatingSystemVersion.minorVersion
    }
    
    /// Current OS patch version (e.g., 1 for version 17.2.1)
    public static var currentPatchVersion: Int {
        return ProcessInfo.processInfo.operatingSystemVersion.patchVersion
    }
    
    /// Full OS version string for debugging (e.g., "17.2.1")
    public static var versionString: String {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
    }
    
    /// Whether WKWebView supports modern configuration options (iOS/macOS 15+)
    public static var supportsModernWebViewConfig: Bool {
        return currentMajorVersion >= 15
    }
    
    // MARK: - Version Detection Methods
    
    /// Checks if the current OS version is at least the specified version
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
    
    /// Checks if the current OS version is exactly the specified version
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
    
    /// Checks if the current OS version is below the specified version
    ///
    /// - Parameters:
    ///   - major: Major version to compare against
    ///   - minor: Minor version to compare against (default: 0)
    ///   - patch: Patch version to compare against (default: 0)
    /// - Returns: true if current version is < specified version
    public static func isVersion(below major: Int, minor: Int = 0, patch: Int = 0) -> Bool {
        return !isVersion(atLeast: major, minor: minor, patch: patch)
    }
    
    /// Generates a basic debug report about version and feature support
    public static func debugReport() -> String {
        return """
        Version Debug Report
        ===================
        OS Version: \(versionString)
        Major: \(currentMajorVersion), Minor: \(currentMinorVersion), Patch: \(currentPatchVersion)
        
        Features:
        - Modern WebView Config: \(supportsModernWebViewConfig ? "✅" : "❌") (iOS 15+)
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