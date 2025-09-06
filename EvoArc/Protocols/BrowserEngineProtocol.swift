//
//  BrowserEngineProtocol.swift
//  EvoArc
//
//  Created on 2025-09-05.
//

import SwiftUI
import WebKit

/// Protocol defining the interface for different browser engine implementations
protocol BrowserEngineProtocol {
    associatedtype ViewType: View
    
    /// Create a view for the browser engine
    func createView(tab: Tab, urlString: Binding<String>, shouldNavigate: Binding<Bool>, onNavigate: @escaping (URL) -> Void, tabManager: TabManager) -> ViewType
    
    /// Get the engine name for display
    var engineName: String { get }
    
    /// Check if the engine is available on the current system
    var isAvailable: Bool { get }
}

/// WebKit implementation of the browser engine
struct WebKitEngine: BrowserEngineProtocol {
    func createView(tab: Tab, urlString: Binding<String>, shouldNavigate: Binding<Bool>, onNavigate: @escaping (URL) -> Void, tabManager: TabManager) -> some View {
        WebView(tab: tab, urlString: urlString, shouldNavigate: shouldNavigate, onNavigate: onNavigate)
    }
    
    var engineName: String {
        "WebKit"
    }
    
    var isAvailable: Bool {
        true // WebKit is always available on Apple platforms
    }
}
