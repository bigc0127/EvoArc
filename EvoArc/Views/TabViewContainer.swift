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
    
    /// Check if the current tab should show the new tab page instead of web content
    private var shouldShowNewTabPage: Bool {
        guard let selectedTab = tabManager.selectedTab else { return false }
        
        // Show new tab page if tab has the custom newtab URL scheme
        if let url = selectedTab.url,
           url.absoluteString == "evoarc://newtab" {
            return true
        }
        
        return false
    }
    
    var body: some View {
        ZStack {
            // Always render all tabs (needed so webViews exist)
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
                .onAppear {
                    // Trigger URL load when WebView appears
                    tab.handleInitialLoad()
                }
                .opacity(tabManager.selectedTab?.id == tab.id && !shouldShowNewTabPage ? 1 : 0)
                .allowsHitTesting(tabManager.selectedTab?.id == tab.id && !shouldShowNewTabPage)
                .id(tab.id) // Important: This ensures each tab gets its own WebView
            }
            
            // Overlay new tab page on top when appropriate
            if shouldShowNewTabPage {
                NewTabPageView(
                    urlString: $urlString,
                    shouldNavigate: $shouldNavigate,
                    tabManager: tabManager
                )
                .transition(.opacity)
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
