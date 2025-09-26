//
//  TabManager.swift
//  EvoArc
//
//  Created on 2025-09-04.
//

import Foundation
import SwiftUI
import Combine

// MARK: - Tab State for Persistence
struct TabState: Codable {
    let urlString: String
    let groupID: String?
    let browserEngine: String
    let title: String?
    
    init(from tab: Tab) {
        self.urlString = tab.url?.absoluteString ?? ""
        self.groupID = tab.groupID?.uuidString
        self.browserEngine = tab.browserEngine.rawValue
        self.title = tab.title != "New Tab" ? tab.title : nil
    }
}

class TabManager: ObservableObject {
    @Published var isGestureActive: Bool = false
    @Published var tabs: [Tab] = []
    @Published var selectedTab: Tab?
    @Published var isTabDrawerVisible: Bool = false
    @Published var tabGroups: [TabGroup] = []
    @Published var isInitialized: Bool = false
    
    // Confirmation dialog states
    @Published var showUnpinConfirmation: Bool = false
    @Published var tabToUnpin: Tab?
    
    private let pinnedTabManager = HybridPinnedTabManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Set up observer first
        setupPinnedTabObserver()
        
        // Load tab groups first
        loadTabGroups()
        
        // Defer pinned tab restoration to avoid circular initialization
        DispatchQueue.main.async { [weak self] in
            self?.restorePinnedTabs()
            
            // Create a new tab if no tabs exist (including pinned ones)
            if self?.tabs.isEmpty == true {
                self?.createNewTab()
            }
            
            // Restore tab group assignments after all tabs are loaded
            self?.restoreTabGroupAssignments()
            
            // Mark initialization as complete
            self?.isInitialized = true
            print("✅ TabManager initialization complete with \(self?.tabs.count ?? 0) tabs")
        }
    }
    
    func createNewTab(url: URL? = nil) {
        let newTab = Tab(url: url)
        newTab.showURLInBar = false // Ensure URL bar starts empty
        tabs.append(newTab)
        selectedTab = newTab
        
        // Record history for new tabs with URLs
        if let url = url {
            HistoryManager.shared.addEntry(url: url, title: newTab.title.isEmpty ? (url.host ?? url.absoluteString) : newTab.title)
        }
        
        // Save tab states when new tabs are created with URLs
        if url != nil {
            saveTabGroupsIfNeeded()
        }
    }
    
    func closeTab(_ tab: Tab) {
        if let index = tabs.firstIndex(where: { $0.id == tab.id }) {
            // Clean up WebView reference
            tab.webView = nil
            
            tabs.remove(at: index)
            
            // Save tab group assignments after removing tab
            saveTabGroupsIfNeeded()
            
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
        
        // Record history when selecting a tab with a URL
        if let url = tab.url {
            HistoryManager.shared.addEntry(url: url, title: tab.title.isEmpty ? (url.host ?? url.absoluteString) : tab.title)
        }
        
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
            
            // Save updated tab states
            self.saveTabGroupsIfNeeded()
            
            // Trigger objectWillChange to update UI
            self.objectWillChange.send()
        }
    }
    
    func toggleBrowserEngine(for tab: Tab) {
        let newEngine: BrowserEngine = tab.browserEngine == .webkit ? .blink : .webkit
        changeBrowserEngine(for: tab, to: newEngine)
    }
    
    // MARK: - Pinned Tab Methods
    
    func pinTab(_ tab: Tab) {
        guard let url = tab.url else { 
            print("Cannot pin tab without URL")
            return 
        }
        
        pinnedTabManager.pinTab(url: url, title: tab.title)
        tab.isPinned = true
        
        // Move pinned tab to front of tabs array
        repositionPinnedTabs()
    }
    
    func unpinTab(_ tab: Tab) {
        guard let url = tab.url else {
            print("Cannot unpin tab without URL")
            return
        }
        
        pinnedTabManager.unpinTab(url: url)
        tab.isPinned = false
        
        // Reposition tabs to maintain pinned tabs at front
        repositionPinnedTabs()
    }
    
    func isTabPinned(_ tab: Tab) -> Bool {
        guard let url = tab.url else { return false }
        return pinnedTabManager.isTabPinned(url: url)
    }
    
    // MARK: - Private Methods
    
    private func setupPinnedTabObserver() {
        pinnedTabManager.$pinnedTabs
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.updateTabPinnedStates()
                }
            }
            .store(in: &cancellables)
    }
    
    private func restorePinnedTabs() {
        let pinnedTabEntities = pinnedTabManager.pinnedTabs
        
        for entity in pinnedTabEntities {
            if let url = entity.url {
                let tab = Tab(url: url, isPinned: true)
                tab.title = entity.title
                tabs.append(tab)
            }
        }
        
        // Select the first tab if available
        if let firstTab = tabs.first {
            selectedTab = firstTab
        }
    }
    
    private func updateTabPinnedStates() {
        for tab in tabs {
            if let url = tab.url {
                let wasPinned = tab.isPinned
                let isPinned = pinnedTabManager.isTabPinned(url: url)
                
                if wasPinned != isPinned {
                    tab.isPinned = isPinned
                }
            }
        }
        
        repositionPinnedTabs()
    }
    
    private func repositionPinnedTabs() {
        // Sort tabs so pinned tabs appear first
        tabs.sort { tab1, tab2 in
            if tab1.isPinned && !tab2.isPinned {
                return true
            } else if !tab1.isPinned && tab2.isPinned {
                return false
            } else {
                return false // Maintain existing order for same type
            }
        }
    }
    
    // MARK: - Tab Group Methods
    
    func createTabGroup(name: String, color: TabGroupColor = .blue, selectedTabIDs: [String] = []) -> TabGroup {
        let group = TabGroup(name: name, color: color)
        tabGroups.append(group)
        
        // Assign selected tabs to the group
        for tabID in selectedTabIDs {
            if let tab = tabs.first(where: { $0.id == tabID }) {
                tab.groupID = group.id
            }
        }
        
        saveTabGroupsIfNeeded()
        
        // Trigger UI update
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
        
        return group
    }
    
    func deleteTabGroup(_ group: TabGroup, moveTabsToNoGroup: Bool = true) {
        // Remove group reference from tabs
        if moveTabsToNoGroup {
            for tab in tabs where tab.groupID == group.id {
                tab.groupID = nil
            }
        }
        
        // Remove the group
        tabGroups.removeAll { $0.id == group.id }
        saveTabGroupsIfNeeded()
        
        // Trigger UI update
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }
    
    func addTabToGroup(_ tab: Tab, group: TabGroup) {
        tab.groupID = group.id
        saveTabGroupsIfNeeded()
        
        // Trigger UI update
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
        
        print("📝 Added tab '\(tab.title)' to group '\(group.name)'")
    }
    
    func removeTabFromGroup(_ tab: Tab) {
        tab.groupID = nil
        saveTabGroupsIfNeeded()
        
        // Trigger UI update
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
        
        print("📝 Removed tab '\(tab.title)' from group")
    }
    
    func saveTabsIfNeeded() {
        saveTabGroupsIfNeeded()
    }
    
    func getTabsInGroup(_ group: TabGroup) -> [Tab] {
        return tabs.filter { $0.groupID == group.id }
    }
    
    func getUngroupedTabs() -> [Tab] {
        return tabs.filter { $0.groupID == nil }
    }
    
    // MARK: - Confirmation Methods
    
    func requestUnpinTab(_ tab: Tab) {
        if BrowserSettings.shared.confirmClosingPinnedTabs {
            tabToUnpin = tab
            showUnpinConfirmation = true
        } else {
            unpinTab(tab)
        }
    }
    
    func confirmUnpinTab() {
        if let tab = tabToUnpin {
            unpinTab(tab)
        }
        tabToUnpin = nil
        showUnpinConfirmation = false
    }
    
    func cancelUnpinTab() {
        tabToUnpin = nil
        showUnpinConfirmation = false
    }
    
    // MARK: - Persistence
    
    private func saveTabGroupsIfNeeded() {
        if BrowserSettings.shared.persistTabGroups {
            // Save tab groups
            if let encoded = try? JSONEncoder().encode(tabGroups) {
                UserDefaults.standard.set(encoded, forKey: "savedTabGroups")
            }
            
            // Save comprehensive tab states
            var tabStates: [String: TabState] = [:]
            
            for tab in tabs {
                // Only save tabs with URLs (these can be restored)
                if let url = tab.url?.absoluteString, !url.isEmpty {
                    let tabState = TabState(from: tab)
                    tabStates[url] = tabState
                }
            }
            
            if let encoded = try? JSONEncoder().encode(tabStates) {
                UserDefaults.standard.set(encoded, forKey: "savedTabStates")
            }
            
            // Keep backward compatibility - save simple group assignments as fallback
            var tabGroupAssignments: [String: String] = [:]
            
            for tab in tabs {
                guard let groupID = tab.groupID?.uuidString else { continue }
                
                // Only save URL-based mapping for tabs with URLs (these can be restored)
                if let url = tab.url?.absoluteString {
                    tabGroupAssignments["url_" + url] = groupID
                }
                
                // Also save tab ID-based mapping as fallback for current session
                tabGroupAssignments["id_" + tab.id] = groupID
            }
            
            if let encoded = try? JSONEncoder().encode(tabGroupAssignments) {
                UserDefaults.standard.set(encoded, forKey: "savedTabGroupAssignments")
            }
        }
    }
    
    private func loadTabGroups() {
        if BrowserSettings.shared.persistTabGroups {
            // Load tab groups
            if let data = UserDefaults.standard.data(forKey: "savedTabGroups"),
               let decoded = try? JSONDecoder().decode([TabGroup].self, from: data) {
                tabGroups = decoded
            }
        }
    }
    
    func restoreTabGroupAssignments() {
        if BrowserSettings.shared.persistTabGroups {
            // Try to load comprehensive tab states first (new format)
            if let data = UserDefaults.standard.data(forKey: "savedTabStates"),
               let tabStates = try? JSONDecoder().decode([String: TabState].self, from: data) {
                
                restoreFromTabStates(tabStates)
                
            } else {
                // Fallback to old format for backward compatibility
                restoreFromLegacyFormat()
            }
        }
    }
    
    private func restoreFromTabStates(_ tabStates: [String: TabState]) {
        // First, restore state for existing tabs
        for tab in tabs {
            if let urlString = tab.url?.absoluteString,
               let tabState = tabStates[urlString] {
                
                // Restore group assignment
                if let groupIDString = tabState.groupID,
                   let groupID = UUID(uuidString: groupIDString),
                   tabGroups.contains(where: { $0.id == groupID }) {
                    tab.groupID = groupID
                }
                
                // Restore browser engine
                if let browserEngine = BrowserEngine(rawValue: tabState.browserEngine) {
                    tab.browserEngine = browserEngine
                }
                
                // Restore title if available
                if let title = tabState.title, !title.isEmpty {
                    tab.title = title
                }
                
                print("🔄 Restored tab state: \(tab.title) [\(tab.browserEngine.displayName)]")
            }
        }
        
        // Second, create tabs for URLs that don't exist but have saved states
        // ONLY restore tabs that were in groups (not ungrouped tabs)
        let existingUrls = Set(tabs.compactMap { $0.url?.absoluteString })
        
        for (urlString, tabState) in tabStates {
            // Skip if we already have a tab with this URL
            if existingUrls.contains(urlString) { continue }
            
            // Only restore tabs that were in a group (skip ungrouped tabs)
            guard let groupIDString = tabState.groupID,
                  let groupID = UUID(uuidString: groupIDString),
                  tabGroups.contains(where: { $0.id == groupID }) else {
                print("⏭️ Skipping ungrouped tab restoration: \(urlString)")
                continue
            }
            
            // Create new tab from saved state
            if let url = URL(string: urlString) {
                let browserEngine = BrowserEngine(rawValue: tabState.browserEngine) ?? .webkit
                let newTab = Tab(url: url, browserEngine: browserEngine, groupID: groupID)
                
                // Restore title if available
                if let title = tabState.title, !title.isEmpty {
                    newTab.title = title
                }
                
                tabs.append(newTab)
                print("🆕 Recreated grouped tab from saved state: \(newTab.title) [\(newTab.browserEngine.displayName)]")
            }
        }
        
        // Select the first tab if we have tabs but no selection
        if selectedTab == nil && !tabs.isEmpty {
            selectedTab = tabs.first
        }
    }
    
    private func restoreFromLegacyFormat() {
        // Load tab-to-group assignments (legacy format)
        if let data = UserDefaults.standard.data(forKey: "savedTabGroupAssignments"),
           let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
            
            // First, restore assignments for existing tabs
            for tab in tabs {
                var groupID: UUID?
                
                // First try URL-based lookup
                if let urlString = tab.url?.absoluteString,
                   let groupIDString = decoded["url_" + urlString] {
                    groupID = UUID(uuidString: groupIDString)
                }
                
                // Fallback to tab ID-based lookup
                if groupID == nil,
                   let groupIDString = decoded["id_" + tab.id] {
                    groupID = UUID(uuidString: groupIDString)
                }
                
                // Apply the group assignment if found and group still exists
                if let groupID = groupID,
                   tabGroups.contains(where: { $0.id == groupID }) {
                    tab.groupID = groupID
                    print("🔄 Restored tab group assignment (legacy): \(tab.title) -> Group ID: \(groupID)")
                }
            }
            
            // Second, create tabs for URLs that don't exist but have group assignments
            // This already only restores tabs that were in groups (legacy format)
            let existingUrls = Set(tabs.compactMap { $0.url?.absoluteString })
            
            for (key, groupIDString) in decoded {
                guard key.hasPrefix("url_"),
                      let groupID = UUID(uuidString: groupIDString),
                      tabGroups.contains(where: { $0.id == groupID }) else { continue }
                
                let urlString = String(key.dropFirst(4)) // Remove "url_" prefix
                
                // Skip if we already have a tab with this URL
                if existingUrls.contains(urlString) { continue }
                
                // Create new tab for this URL (with default browser engine)
                if let url = URL(string: urlString) {
                    let newTab = Tab(url: url)
                    newTab.groupID = groupID
                    tabs.append(newTab)
                    print("🆕 Recreated grouped tab from legacy format: \(newTab.title)")
                }
            }
            
            // Select the first tab if we have tabs but no selection
            if selectedTab == nil && !tabs.isEmpty {
                selectedTab = tabs.first
            }
        }
    }
}
