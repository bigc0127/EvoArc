//
//  BrowserEngineProtocol.swift
//  EvoArc
//
//  Defines the protocol (interface) for browser engine implementations.
//  This allows EvoArc to support multiple rendering engines (WebKit, Blink, etc.)
//  through a common interface, making it easy to switch engines per tab.
//
//  Architecture:
//  - Protocol defines the contract all engines must fulfill
//  - Each engine implementation provides its own view and behavior
//  - Current implementations: WebKit (Safari engine), Blink (Chromium - if available)
//
//  For Swift beginners:
//  - Protocols are like interfaces in other languages
//  - They define "what" without defining "how"
//  - Types conforming to protocols must implement all requirements

import SwiftUI  // View protocol and Binding
import WebKit   // WKWebView for web rendering

// MARK: - Browser Engine Protocol

/// Protocol that all browser engine implementations must conform to.
/// This abstraction allows tabs to use different rendering engines interchangeably.
/// 
/// For Swift beginners:
/// - protocol is Swift's way of defining an interface or contract
/// - Any type conforming to this must implement all these requirements
/// - This enables polymorphism - treating different engines uniformly
protocol BrowserEngineProtocol {
    /// Associated type specifies what kind of View this engine produces.
    /// Different engines can return different view types as long as they conform to View.
    /// 
    /// For Swift beginners:
    /// - associatedtype is like a generic placeholder
    /// - ViewType: View means "ViewType must conform to SwiftUI's View protocol"
    /// - Each conforming type specifies its concrete ViewType
    associatedtype ViewType: View
    
    /// Creates the SwiftUI view that displays web content for this engine.
    /// 
    /// Parameters:
    /// - tab: The Tab object managing this web view's state
    /// - urlString: Two-way binding to the URL bar text (updates bidirectionally)
    /// - shouldNavigate: Binding that triggers navigation when set to true
    /// - onNavigate: Callback executed when navigation occurs
    /// - tabManager: Reference to the TabManager for tab operations
    /// 
    /// Returns: A SwiftUI View (the concrete type depends on the implementation)
    /// 
    /// For Swift beginners:
    /// - Binding<T> is a two-way connection to a value (read and write)
    /// - @escaping means the closure can outlive this function call
    /// - 'some View' means "returns a type conforming to View" (type inference)
    func createView(tab: Tab, urlString: Binding<String>, shouldNavigate: Binding<Bool>, onNavigate: @escaping (URL) -> Void, tabManager: TabManager) -> ViewType
    
    /// Human-readable name of the engine for display in UI.
    /// Examples: "WebKit", "Blink", "Gecko"
    var engineName: String { get }
    
    /// Indicates whether this engine can be used on the current platform/device.
    /// 
    /// For example:
    /// - WebKit is always available on Apple platforms
    /// - Blink (Chromium) might only be available if bundled with the app
    /// 
    /// Returns:
    /// - true: Engine is available and can be used
    /// - false: Engine is not available (hide from UI, can't create tabs with it)
    var isAvailable: Bool { get }
}

// MARK: - WebKit Engine Implementation

/// WebKit browser engine implementation.
/// WebKit is Apple's rendering engine, used by Safari and built into all Apple devices.
/// It provides excellent performance and full integration with iOS/macOS.
/// 
/// For Swift beginners:
/// - struct is a value type (copied when passed around)
/// - This struct conforms to BrowserEngineProtocol (implements all requirements)
/// - WebKit is free and always available on Apple platforms
struct WebKitEngine: BrowserEngineProtocol {
    /// Creates a WebView (our WKWebView wrapper) for rendering web content.
    /// 
    /// For Swift beginners:
    /// - 'some View' is an opaque return type - the compiler knows the exact type
    /// - We return a WebView which conforms to SwiftUI's View protocol
    /// - All the bindings and callbacks are passed through to WebView
    func createView(tab: Tab, urlString: Binding<String>, shouldNavigate: Binding<Bool>, onNavigate: @escaping (URL) -> Void, tabManager: TabManager) -> some View {
        /// Create and return our WebView implementation.
        /// WebView is defined in Views/WebView.swift and wraps WKWebView.
        /// The tabManager parameter is available but not currently used by WebView.
        WebView(tab: tab, urlString: urlString, shouldNavigate: shouldNavigate, onNavigate: onNavigate)
    }
    
    /// Returns the display name for this engine.
    /// Shown in settings and browser engine selection UI.
    var engineName: String {
        "WebKit"
    }
    
    /// WebKit availability check.
    /// Always returns true because WebKit is built into all Apple platforms.
    /// 
    /// For Swift beginners:
    /// - This is a computed property (getter only, no stored value)
    /// - The inline comment explains why it's always true
    /// - Other engines (like Blink) might need runtime checks
    var isAvailable: Bool {
        /// WebKit is always available on iOS, iPadOS, and macOS.
        /// It's part of the operating system and requires no additional setup.
        true
    }
}
