//
//  BrowserEngineView.swift
//  EvoArc
//
//  Created on 2025-09-05.
//

import SwiftUI
import WebKit

/// A view that dynamically switches between browser engines based on user settings
struct BrowserEngineView: View {
    @ObservedObject var tab: Tab
    @Binding var urlString: String
    @Binding var shouldNavigate: Bool
    let onNavigate: (URL) -> Void
    let tabManager: TabManager
    @StateObject private var settings = BrowserSettings.shared
    
    var body: some View {
        Group {
            // Browser engine switching based on tab's engine setting
            if tab.browserEngine == .blink {
                // Use enhanced WebKit with Chrome features
                ChromiumWebView(
                    tab: tab,
                    urlString: $urlString,
                    shouldNavigate: $shouldNavigate,
                    onNavigate: onNavigate
                )
                .id("chromium-\(tab.id)")  // Force recreation when switching
            } else {
                WebView(
                    tab: tab,
                    urlString: $urlString,
                    shouldNavigate: $shouldNavigate,
                    onNavigate: onNavigate
                )
                .id("webkit-\(tab.id)")  // Force recreation when switching
            }
        }
        // Keep top safe area; allow horizontal/optional bottom expansion managed by parent
        .ignoresSafeArea(edges: [.horizontal])
        .onReceive(tab.$browserEngine) { _ in
            // When tab's engine changes, reload the current page
            Task { @MainActor in
                if let currentURL = tab.url {
                    urlString = currentURL.absoluteString
                    shouldNavigate = true
                }
            }
        }
    }
}

/// Extension for ScrollDetectingWebView to use BrowserEngineView
struct EngineSwitchableScrollDetectingWebView: View {
    let tab: Tab
    @Binding var urlString: String
    @Binding var shouldNavigate: Bool
    @Binding var urlBarVisible: Bool
    let onNavigate: (URL) -> Void
    let autoHideEnabled: Bool
    let tabManager: TabManager
    @StateObject private var settings = BrowserSettings.shared
    
    var body: some View {
        // Browser engine switching based on tab's engine setting
        if tab.browserEngine == .blink {
            // Use enhanced WebKit with Chrome features
            ChromiumWebView(
                tab: tab,
                urlString: $urlString,
                shouldNavigate: $shouldNavigate,
                onNavigate: onNavigate
            )
        } else {
            // For WebKit, use the existing ScrollDetectingWebView
            ScrollDetectingWebView(
                tab: tab,
                urlString: $urlString,
                shouldNavigate: $shouldNavigate,
                urlBarVisible: $urlBarVisible,
                onNavigate: onNavigate,
                autoHideEnabled: autoHideEnabled,
                tabManager: tabManager
            )
        }
    }
}
