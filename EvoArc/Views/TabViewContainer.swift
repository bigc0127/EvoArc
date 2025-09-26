//
//  TabViewContainer.swift
//  EvoArc
//
//  Created on 2025-09-05.
//

import SwiftUI
import WebKit

/// Container that manages multiple WebView instances and displays only the selected tab
struct TabViewContainer: View {
    @ObservedObject var tabManager: TabManager
    @Binding var urlString: String
    @Binding var shouldNavigate: Bool
    @Binding var urlBarVisible: Bool
    let onNavigate: (URL) -> Void
    let autoHideEnabled: Bool
    
    var body: some View {
        ZStack {
            // Render all tabs but only show the selected one
            ForEach(tabManager.tabs) { tab in
                EngineSwitchableScrollDetectingWebView(
                    tab: tab,
                    urlString: $urlString,
                    shouldNavigate: Binding<Bool>(
                        get: { shouldNavigate && tabManager.selectedTab?.id == tab.id },
                        set: { shouldNavigate = $0 }
                    ),
                    urlBarVisible: $urlBarVisible,
                    onNavigate: onNavigate,
                    autoHideEnabled: autoHideEnabled,
                    tabManager: tabManager
                )
                .opacity(tabManager.selectedTab?.id == tab.id ? 1 : 0)
                .allowsHitTesting(tabManager.selectedTab?.id == tab.id)
                .id(tab.id) // Important: This ensures each tab gets its own WebView
            }
        }
        // Respect the top safe area so top content isn't clipped
                    // Don't ignore any safe areas - let web content handle its own layout
                    .edgesIgnoringSafeArea([])
        .onReceive(tabManager.$selectedTab) { _ in
            // Update URL bar when tab switches
            if let selectedTab = tabManager.selectedTab {
                // Only update URL string if explicitly showing URL
                if selectedTab.showURLInBar {
                    if let webViewURL = selectedTab.webView?.url {
                        urlString = webViewURL.absoluteString
                    } else {
                        urlString = selectedTab.url?.absoluteString ?? ""
                    }
                } else {
                    urlString = "" // Keep URL bar empty
                }
            }
        }
    }
}
