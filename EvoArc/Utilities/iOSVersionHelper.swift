//
//  iOSVersionHelper.swift
//  EvoArc
//
//  iOS/macOS version detection utility
//  This helper provides cross-platform version detection for iOS and macOS,
//  allowing the app to adapt behavior based on OS capabilities and features.
//

// MARK: - Import Explanation for Beginners
// These imports bring in system frameworks needed for OS version detection:
import Foundation         // Core Swift framework for ProcessInfo (OS version access)
import WebKit            // Web view framework (WKWebView) - not actively used here
import SystemConfiguration // Network and system configuration (not actively used here)

import UIKit             // iOS/macOS UI framework - provides UIDevice for device type detection

// MARK: - What is this file?
// This is a utility helper class that detects the current iOS/macOS version
// and device information. It's used throughout EvoArc to:
// 1. Check if certain features are available (feature gating by OS version)
// 2. Adapt behavior for different OS versions
// 3. Debug device and OS information
//
// Key Swift Concepts:
// - Static properties/methods: Called on the class itself, not instances (iOSVersionHelper.currentMajorVersion)
// - Computed properties: Properties that calculate their value each time they're accessed (no storage)
// - ProcessInfo: Apple's API for accessing system and process information
// - Conditional compilation: #if directives that include/exclude code at compile time

/// A utility class for detecting iOS/macOS version and device information.
///
/// **Purpose**: Provides version checking and device detection for feature gating
/// and platform-specific behavior in the EvoArc browser.
///
/// **Usage Example**:
/// ```swift
/// if iOSVersionHelper.isVersion(atLeast: 17) {
///     // Use iOS 17+ features
/// }
/// print(iOSVersionHelper.versionString) // "17.2.1"
/// ```
///
/// **Design Pattern**: Static utility class (all methods/properties are static,
/// no instances are created).
public class iOSVersionHelper {
    
    // MARK: - Version Properties
    // These computed properties access the OS version through ProcessInfo.processInfo.
    // ProcessInfo is Apple's API for querying system information.
    //
    // Computed Property Explanation:
    // These don't store a value - they calculate it each time you access them.
    // The syntax "var name: Type { return value }" defines a read-only computed property.
    
    /// The current operating system's major version number.
    ///
    /// **Example**: For iOS 17.2.1, this returns `17`.
    ///
    /// **How it works**: Uses `ProcessInfo.processInfo.operatingSystemVersion`,
    /// which queries the system for version information.
    ///
    /// **Use case**: Check if you're on iOS 17 or later for feature availability.
    public static var currentMajorVersion: Int {
        return ProcessInfo.processInfo.operatingSystemVersion.majorVersion
    }
    
    /// The current operating system's minor version number.
    ///
    /// **Example**: For iOS 17.2.1, this returns `2`.
    ///
    /// **Use case**: Check for specific feature additions within a major release
    /// (e.g., iOS 17.2 added new APIs not in iOS 17.0).
    public static var currentMinorVersion: Int {
        return ProcessInfo.processInfo.operatingSystemVersion.minorVersion
    }
    
    /// The current operating system's patch version number.
    ///
    /// **Example**: For iOS 17.2.1, this returns `1`.
    ///
    /// **Use case**: Typically used for bug fixes. Less commonly checked
    /// than major/minor versions.
    public static var currentPatchVersion: Int {
        return ProcessInfo.processInfo.operatingSystemVersion.patchVersion
    }
    
    /// A formatted string representation of the full OS version.
    ///
    /// **Example**: Returns `"17.2.1"` for iOS 17.2.1.
    ///
    /// **String Interpolation Explanation**: The `\(...)` syntax embeds
    /// variable values directly into strings. This is Swift's primary way
    /// to build strings from variables.
    ///
    /// **Use case**: Logging, debugging, displaying version in settings/about screens.
    public static var versionString: String {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
    }
    
    /// Indicates whether the current OS supports modern WKWebView configuration options.
    ///
    /// **Requirement**: iOS/macOS 15 or later.
    ///
    /// **Purpose**: Apple introduced new WKWebView APIs in iOS 15 (like improved
    /// content blocking, privacy features, etc.). This flag lets EvoArc use
    /// those features when available, or fall back to older APIs on iOS 14.
    ///
    /// **Example Usage**:
    /// ```swift
    /// if iOSVersionHelper.supportsModernWebViewConfig {
    ///     // Use iOS 15+ WKWebView APIs
    /// } else {
    ///     // Use fallback for iOS 14
    /// }
    /// ```
    public static var supportsModernWebViewConfig: Bool {
        return currentMajorVersion >= 15
    }
    
    // MARK: - Version Detection Methods
    // These methods provide flexible version comparison logic.
    // They use semantic versioning comparison (major.minor.patch).
    
    /// Checks if the current OS version meets or exceeds a specified version.
    ///
    /// **Logic**: Compares major, then minor, then patch versions in order.
    /// Returns `true` if the current version is greater than or equal to
    /// the specified version.
    ///
    /// **Default Parameters Explanation**: The `minor` and `patch` parameters
    /// have default values of `0`, so you can call this with just a major version:
    /// `isVersion(atLeast: 17)` is equivalent to `isVersion(atLeast: 17, minor: 0, patch: 0)`
    ///
    /// **Example Usage**:
    /// ```swift
    /// // Check if running iOS 17 or later
    /// if iOSVersionHelper.isVersion(atLeast: 17) {
    ///     // Use iOS 17+ features
    /// }
    ///
    /// // Check for iOS 16.4 or later (for a specific API)
    /// if iOSVersionHelper.isVersion(atLeast: 16, minor: 4) {
    ///     // Use iOS 16.4+ API
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - major: Major version to compare against (e.g., 17)
    ///   - minor: Minor version to compare against (default: 0)
    ///   - patch: Patch version to compare against (default: 0)
    /// - Returns: `true` if current version >= specified version, `false` otherwise
    public static func isVersion(atLeast major: Int, minor: Int = 0, patch: Int = 0) -> Bool {
        // Get the current OS version from the system
        let current = ProcessInfo.processInfo.operatingSystemVersion
        
        // Semantic versioning comparison:
        // 1. If major version is higher, we're definitely >= the target
        if current.majorVersion > major {
            return true
        }
        // 2. If major version matches, check minor version
        else if current.majorVersion == major {
            // If minor version is higher, we're >= the target
            if current.minorVersion > minor {
                return true
            }
            // If minor version matches, check patch version
            else if current.minorVersion == minor {
                return current.patchVersion >= patch
            }
        }
        
        // If we get here, current version is lower than the target
        return false
    }
    
    /// Checks if the current OS version exactly matches a specified version.
    ///
    /// **Use Case**: Rarely used - typically for checking known bugs
    /// in a specific OS version or testing.
    ///
    /// **Boolean Logic Explanation**: The `&&` operator is "logical AND".
    /// All three conditions must be true for the function to return `true`.
    ///
    /// **Example Usage**:
    /// ```swift
    /// // Check if running exactly iOS 17.0.0
    /// if iOSVersionHelper.isVersion(exactly: 17) {
    ///     // Apply workaround for iOS 17.0.0 specific bug
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - major: Major version to compare against
    ///   - minor: Minor version to compare against (default: 0)
    ///   - patch: Patch version to compare against (default: 0)
    /// - Returns: `true` if current version matches exactly, `false` otherwise
    public static func isVersion(exactly major: Int, minor: Int = 0, patch: Int = 0) -> Bool {
        let current = ProcessInfo.processInfo.operatingSystemVersion
        // All three version components must match exactly
        return current.majorVersion == major && 
               current.minorVersion == minor && 
               current.patchVersion == patch
    }
    
    /// Checks if the current OS version is below a specified version.
    ///
    /// **Implementation Note**: This is implemented as the logical inverse
    /// of `isVersion(atLeast:)`. The `!` operator negates a boolean value.
    ///
    /// **Use Case**: Checking if you need to provide a fallback for older OS versions.
    ///
    /// **Example Usage**:
    /// ```swift
    /// // Check if running iOS 16 or earlier
    /// if iOSVersionHelper.isVersion(below: 17) {
    ///     // Use legacy APIs for iOS 16 and earlier
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - major: Major version to compare against
    ///   - minor: Minor version to compare against (default: 0)
    ///   - patch: Patch version to compare against (default: 0)
    /// - Returns: `true` if current version < specified version, `false` otherwise
    public static func isVersion(below major: Int, minor: Int = 0, patch: Int = 0) -> Bool {
        // Simply negate the result of "atLeast" - if we're NOT at least that version,
        // then we must be below it
        return !isVersion(atLeast: major, minor: minor, patch: patch)
    }
    
    /// Generates a formatted debug report showing OS version and feature support.
    ///
    /// **Multi-line String Explanation**: The `"""..."""`  syntax creates a
    /// multi-line string literal in Swift. Everything between the triple quotes
    /// is included, with proper formatting and line breaks preserved.
    ///
    /// **Ternary Operator Explanation**: The `condition ? valueIfTrue : valueIfFalse`
    /// syntax is a concise if-else expression. Here it's used to show ✅ or ❌
    /// based on feature support.
    ///
    /// **Use Case**: Logging for debugging, or displaying in a developer settings screen.
    ///
    /// **Example Output**:
    /// ```
    /// Version Debug Report
    /// ===================
    /// OS Version: 17.2.1
    /// Major: 17, Minor: 2, Patch: 1
    ///
    /// Features:
    /// - Modern WebView Config: ✅ (iOS 15+)
    /// ```
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
    // These properties provide information about the physical device,
    // not just the OS version.
    
    /// The device's hardware model identifier.
    ///
    /// **Example**: Returns `"iPhone14,2"` for an iPhone 13 Pro,
    /// or `"iPad13,1"` for iPad Pro 11-inch (5th generation).
    ///
    /// **How it works**: Uses the low-level `utsname` C API to query
    /// the system's hardware identifier. This is an advanced technique
    /// involving unsafe pointers.
    ///
    /// **Unsafe Pointer Explanation**: The `withMemoryRebound` and
    /// `withUnsafePointer` functions are low-level Swift APIs for working
    /// with C-style data structures. They're called "unsafe" because Swift
    /// can't guarantee memory safety - you must manually ensure correctness.
    ///
    /// **Use Case**: Hardware-specific detection (e.g., different behavior
    /// for iPhone vs iPad, or specific models with known hardware issues).
    public static var deviceModel: String {
        // Create an uninitialized utsname structure (C struct for system info)
        var systemInfo = utsname()
        // Call the C function uname() to populate the struct with system data
        // The & prefix passes the address of systemInfo (C requires pointers)
        uname(&systemInfo)
        
        // Extract the machine field (device model) using unsafe pointer access
        // This is complex because we're bridging Swift and C:
        let modelCode = withUnsafePointer(to: &systemInfo.machine) {
            // $0 is the pointer to the machine field (tuple of CChars)
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                // Reinterpret the memory as a C string (CChar pointer)
                ptr in String.init(validatingUTF8: ptr)
                // Convert the C string to a Swift String
            }
        }
        
        // If the conversion failed, return "Unknown" (the ?? operator provides a default)
        return modelCode ?? "Unknown"
    }
    
    /// Indicates whether the app is running in the iOS Simulator (not on physical hardware).
    ///
    /// **Conditional Compilation Explanation**: The `#if` directives are processed
    /// at compile-time, not runtime. The compiler includes only the code that matches
    /// the current build target.
    ///
    /// **How it works**:
    /// - When building for Simulator: Only `return true` is included in the binary
    /// - When building for device: Only `return false` is included in the binary
    ///
    /// **Use Case**: Enable debugging features or mock data in the simulator,
    /// while using real implementations on physical devices.
    public static var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }
    
    /// Returns a human-readable string describing the device type.
    ///
    /// **UIDevice.current Explanation**: `UIDevice` is a singleton object
    /// (only one instance exists) that provides information about the current device.
    /// The `.current` property accesses that singleton instance.
    ///
    /// **userInterfaceIdiom Explanation**: This enum property identifies the type
    /// of device based on its UI paradigm (phone, tablet, TV, etc.).
    ///
    /// **Switch Statement Explanation**: Swift's `switch` is a powerful pattern-matching
    /// construct. It must be exhaustive (handle all possible cases).
    ///
    /// **@unknown default Explanation**: This special case handles future enum values
    /// that might be added in later iOS versions. Without it, the compiler would warn
    /// that the switch might not be exhaustive in the future.
    ///
    /// **Possible Return Values**:
    /// - "iPhone" (phones running iOS)
    /// - "iPad" (tablets running iPadOS)
    /// - "Apple TV" (tvOS devices)
    /// - "CarPlay" (when running in CarPlay)
    /// - "Mac (Catalyst)" (Mac apps built with Mac Catalyst)
    /// - "Vision Pro" (visionOS devices)
    /// - "Unspecified" (rare edge case)
    /// - "Unknown" (future device types not known at compile time)
    public static var deviceType: String {
        // Switch on the device's UI paradigm
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
            return "Mac (Catalyst)"  // iOS app running on Mac via Catalyst technology
        case .unspecified:
            return "Unspecified"
        case .vision:
            return "Vision Pro"  // Apple's mixed reality headset
        @unknown default:
            // Handle any future device types added by Apple in later SDK versions
            return "Unknown"
        }
    }
    
    /// Generates a comprehensive debug report with OS version and device information.
    ///
    /// **String Interpolation with Function Calls**: The `\(debugReport())`
    /// syntax calls the function and embeds its result (the entire basic debug report)
    /// into this extended report.
    ///
    /// **Use Case**: Complete system information for bug reports, logging,
    /// or developer settings screens.
    ///
    /// **Example Output**:
    /// ```
    /// Version Debug Report
    /// ===================
    /// OS Version: 17.2.1
    /// Major: 17, Minor: 2, Patch: 1
    ///
    /// Features:
    /// - Modern WebView Config: ✅ (iOS 15+)
    ///
    /// Device Information:
    /// - Device Type: iPhone
    /// - Device Model: iPhone14,2
    /// - Simulator: No
    /// ```
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

// MARK: - Summary for Beginners
// This utility class demonstrates several important Swift and iOS concepts:
//
// 1. **Static utility pattern**: All methods/properties are static - no instances needed
// 2. **Computed properties**: Properties that calculate values on-demand
// 3. **System APIs**: ProcessInfo for OS version, UIDevice for device info
// 4. **Conditional compilation**: #if directives for simulator detection
// 5. **Low-level C interop**: Using utsname and unsafe pointers for hardware info
// 6. **String interpolation**: Embedding variables and expressions in strings
// 7. **Ternary operator**: Concise conditional expressions (condition ? a : b)
// 8. **Default parameters**: Functions with optional parameters (minor: Int = 0)
//
// This file is a good reference for understanding how iOS apps detect and adapt
// to different OS versions and device types - a crucial skill for cross-platform
// and backwards-compatible app development.
