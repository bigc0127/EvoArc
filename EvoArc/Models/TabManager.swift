//
//  TabManager.swift
//  EvoArc
//
//  Created on 2025-09-04.
//

import Foundation
import SwiftUI
import Combine

class TabManager: ObservableObject {
    @Published var tabs: [Tab] = []
    @Published var selectedTab: Tab?
    @Published var isTabDrawerVisible: Bool = false
    
    init() {
        createNewTab()
    }
    
    func createNewTab(url: URL? = nil) {
        let newTab = Tab(url: url)
        tabs.append(newTab)
        selectedTab = newTab
    }
    
    func closeTab(_ tab: Tab) {
        if let index = tabs.firstIndex(where: { $0.id == tab.id }) {
            // Clean up WebView reference
            tab.webView = nil
            
            tabs.remove(at: index)
            
            if tabs.isEmpty {
                createNewTab()
            } else if selectedTab?.id == tab.id {
                // Select the next tab or the previous one
                if index < tabs.count {
                    selectedTab = tabs[index]
                } else if index > 0 {
                    selectedTab = tabs[index - 1]
                } else {
                    selectedTab = tabs.first
                }
            }
        }
    }
    
    func selectTab(_ tab: Tab) {
        selectedTab = tab
        isTabDrawerVisible = false
        
        // Trigger a change notification to update UI
        objectWillChange.send()
    }
    
    func toggleTabDrawer() {
        withAnimation(.spring()) {
            isTabDrawerVisible.toggle()
        }
    }
    
    func hideTabDrawer() {
        withAnimation(.spring()) {
            isTabDrawerVisible = false
        }
    }
    
    func changeBrowserEngine(for tab: Tab, to engine: BrowserEngine) {
        // Use async dispatch to avoid "Publishing changes from within view updates"
        DispatchQueue.main.async {
            tab.browserEngine = engine
            
            // Force WebView recreation by clearing the current WebView reference
            tab.webView = nil
            
            // Trigger objectWillChange to update UI
            self.objectWillChange.send()
        }
    }
    
    func toggleBrowserEngine(for tab: Tab) {
        let newEngine: BrowserEngine = tab.browserEngine == .webkit ? .blink : .webkit
        changeBrowserEngine(for: tab, to: newEngine)
    }
}
