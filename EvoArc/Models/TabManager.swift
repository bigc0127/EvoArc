//
//  TabManager.swift
//  EvoArc
//
//  Central coordinator for managing all browser tabs and tab groups in EvoArc.
//  This is one of the most critical classes in the app - it orchestrates tab lifecycle,
//  persistence, grouping, pinning, and state management.
//
//  Responsibilities:
//  - Create, close, and switch between tabs
//  - Manage tab groups (collections of related tabs)
//  - Handle pinned tabs (persistent across sessions)
//  - Persist and restore tab state
//  - Coordinate with browser engine switching
//  - Track UI state (drawer visibility, gestures, etc.)
//
//  Architecture:
//  - Conforms to ObservableObject for SwiftUI reactivity
//  - Uses Combine for reactive updates
//  - Singleton pattern via shared manager references
//  - Integrates with HybridPinnedTabManager for pinned tabs
//
//  For Swift beginners:
//  - This is a reference type (class) that lives for the app's lifetime
//  - @Published properties automatically update the UI when changed
//  - Manages arrays of Tab and TabGroup objects

import Foundation  // Core types, UUID, URL, UserDefaults
import SwiftUI     // ObservableObject, Published wrappers
import Combine     // Reactive programming, publishers, subscribers
import WebKit      // WKWebView for web view access

// MARK: - Tab State Structure

/// Lightweight snapshot of a tab's state for persistence.
/// Used to save and restore tabs between app launches.
/// 
/// For Swift beginners:
/// - struct is a value type (copied when assigned)
/// - Codable enables JSON encoding/decoding for saving to disk
/// - This is a "data transfer object" pattern - just data, no logic
/// 
/// Why we need this:
/// - Tab objects contain WKWebView references that can't be saved
/// - TabState extracts only the serializable data
/// - We reconstruct full Tab objects from TabState on app launch
struct TabState: Codable {
    /// The tab's current URL as a string.
    /// Empty string if tab has no URL (rare).
    let urlString: String
    
    /// Optional UUID string of the tab group this tab belongs to.
    /// nil means the tab is not in any group.
    let groupID: String?
    
    /// The browser engine name ("webkit" or "blink").
    /// Stored as string for Codable compatibility.
    let browserEngine: String
    
    /// The page title, or nil if it's still "New Tab".
    /// We don't persist default titles to keep saved data clean.
    let title: String?
    
    /// Creates a TabState from an existing Tab object.
    /// Extracts only the data that can be persisted to disk.
    /// 
    /// For Swift beginners:
    /// - init(from:) is a custom initializer that converts one type to another
    /// - We use optional chaining (?.) to safely access properties that might be nil
    /// - The ?? operator provides fallback values for nil cases
    init(from tab: Tab) {
        /// Convert URL to string, defaulting to empty if nil.
        self.urlString = tab.url?.absoluteString ?? ""
        
        /// Convert UUID to string for storage. nil stays nil.
        self.groupID = tab.groupID?.uuidString
        
        /// Get the engine's string representation ("webkit" or "blink").
        self.browserEngine = tab.browserEngine.rawValue
        
        /// Only save custom titles, not the default "New Tab".
        /// This keeps our saved data cleaner and smaller.
        self.title = tab.title != "New Tab" ? tab.title : nil
    }
}

// MARK: - Tab Manager Class

/// Central manager coordinating all tab and tab group operations.
/// This class is the "brain" of EvoArc's tab system.
/// 
/// For Swift beginners:
/// - class (not struct) because we want reference semantics
/// - ObservableObject enables SwiftUI to watch for changes
/// - All tabs in the app are managed by this single instance
class TabManager: ObservableObject {
    // MARK: - Published Properties
    
    /// Indicates whether a user gesture (swipe/drag) is currently in progress.
    /// Used to prevent conflicting gestures from activating simultaneously.
    /// 
    /// For Swift beginners:
    /// - @Published automatically notifies SwiftUI when this changes
    /// - Bool is true/false (gesture active/inactive)
    @Published var isGestureActive: Bool = false
    
    /// Array of all open tabs in the browser.
    /// Order matters: pinned tabs appear first, then unpinned tabs.
    /// 
    /// For Swift beginners:
    /// - [Tab] means "array of Tab objects"
    /// - = [] initializes with empty array
    /// - This is the master list of all tabs
    @Published var tabs: [Tab] = []
    
    /// The currently active/visible tab, or nil if no tabs exist (rare).
    /// When this changes, the UI switches to display the new tab's content.
    /// 
    /// For Swift beginners:
    /// - Tab? means "optional Tab" - can be nil or contain a Tab
    /// - nil should only happen briefly during initialization
    @Published var selectedTab: Tab?
    
    /// Controls visibility of the tab drawer (tab switcher UI).
    /// true = drawer is visible (showing all tabs)
    /// false = drawer is hidden (showing active tab)
    @Published var isTabDrawerVisible: Bool = false
    
    /// Array of all tab groups defined by the user.
    /// Tab groups let users organize tabs into logical collections.
    @Published var tabGroups: [TabGroup] = []
    
    /// Indicates whether TabManager has completed its initialization.
    /// false during startup while loading pinned tabs and restoring state.
    /// true once all initialization is complete and tabs are ready.
    /// 
    /// Used by UI to show loading state vs. ready state.
    @Published var isInitialized: Bool = false
    
    /// Timestamp of the last navigation start event.
    /// Used to detect if a navigation was triggered by a tap (to avoid showing bottom bar).
    @Published var lastNavigationStart: Date = .distantPast
    
    // MARK: - Confirmation Dialog State
    
    /// Whether to show the "confirm unpin tab" dialog.
    /// User preference determines if we ask before unpinning.
    @Published var showUnpinConfirmation: Bool = false
    
    /// The tab waiting to be unpinned (pending user confirmation).
    /// nil when no confirmation is pending.
    @Published var tabToUnpin: Tab?
    
    // MARK: - Private Properties
    
    /// Manager responsible for persisting pinned tabs.
    /// HybridPinnedTabManager handles both local and cloud storage.
    /// 
    /// For Swift beginners:
    /// - 'let' means this reference never changes (always points to same manager)
    /// - .shared is singleton pattern (one instance for entire app)
    /// - 'private' means only TabManager can access this
    private let pinnedTabManager = HybridPinnedTabManager.shared
    
    /// Set of Combine subscriptions for reactive updates.
    /// Stores connections to publishers we're observing.
    /// 
    /// For Swift beginners:
    /// - Set<AnyCancellable> holds subscriptions
    /// - When TabManager is deallocated, these subscriptions auto-cancel
    /// - This prevents memory leaks from dangling observers
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    /// Initializes the TabManager and restores previous session state.
    /// 
    /// Initialization sequence:
    /// 1. Set up observers for pinned tab changes
    /// 2. Load saved tab groups from disk
    /// 3. Asynchronously restore pinned tabs
    /// 4. Create a new tab if none exist
    /// 5. Restore tab group assignments
    /// 6. Mark initialization as complete
    /// 
    /// For Swift beginners:
    /// - init() is called automatically when creating a TabManager
    /// - We use async dispatch to avoid blocking the UI during restoration
    /// - [weak self] prevents retain cycles in the closure
    init() {
        /// Set up Combine observer to watch for pinned tab changes.
        /// This keeps our tabs array synchronized with the pinned tab manager.
        setupPinnedTabObserver()
        
        /// Load tab groups from persistent storage (UserDefaults).
        /// Must happen before restoring tabs so groups exist for assignment.
        loadTabGroups()
        
        /// Defer tab restoration to the next run loop to avoid circular initialization issues.
        /// 
        /// Why async:
        /// - Tab restoration might trigger observers
        /// - Observers might access TabManager properties
        /// - We need TabManager fully initialized first
        /// 
        /// DispatchQueue.main.async schedules work on the main thread "soon".
        /// [weak self] prevents a retain cycle (closure strongly capturing self).
        DispatchQueue.main.async { [weak self] in
            /// Restore pinned tabs from persistent storage.
            /// These are tabs the user wants to persist across app launches.
            self?.restorePinnedTabs()
            
            /// Ensure at least one tab exists for the user to browse.
            /// Without this check, the app would show an empty state.
            if self?.tabs.isEmpty == true {
                self?.createNewTab()
            }
            
            /// Restore which tabs belong to which groups.
            /// This must happen after tabs are created.
            self?.restoreTabGroupAssignments()
            
            /// Signal that initialization is complete and UI can show tabs.
            /// Views watching isInitialized will update from "loading" to "ready" state.
            self?.isInitialized = true
            print("✅ TabManager initialization complete with \(self?.tabs.count ?? 0) tabs")
        }
    }
    
    // MARK: - Tab Creation
    
    /// Creates a new tab and makes it the active tab.
    /// 
    /// Parameter url: Optional URL to load in the new tab.
    ///   - nil: Creates a blank tab (homepage will load automatically)
    ///   - URL: Loads the specified URL immediately
    /// 
    /// Side effects:
    /// - Adds tab to tabs array
    /// - Selects the new tab (becomes visible)
    /// - Records URL in browsing history (if URL provided)
    /// - Saves tab state to disk (if URL provided)
    /// 
    /// For Swift beginners:
    /// - URL? = nil provides a default parameter value
    /// - You can call: createNewTab() or createNewTab(url: someURL)
    func createNewTab(url: URL? = nil) {
        /// Create the new tab object with the specified URL.
        /// Tab's initializer handles homepage logic if url is nil.
        let newTab = Tab(url: url)
        
        /// Hide URL in the address bar for new tabs (cleaner look).
        /// The URL will show once the page loads.
        newTab.showURLInBar = false
        
        /// Add to our master list of tabs.
        tabs.append(newTab)
        
        /// Make this the visible/active tab.
        /// This triggers UI update to display the new tab's content.
        selectedTab = newTab
        
        /// Record in browsing history if a URL was provided.
        /// Uses optional binding (if let) to safely unwrap the optional URL.
        if let url = url {
            /// Generate a title for history: use tab title if set, otherwise use domain.
            /// The ternary operator ? : is a compact if-else.
            /// Empty check prevents recording untitled pages.
            HistoryManager.shared.addEntry(url: url, title: newTab.title.isEmpty ? (url.host ?? url.absoluteString) : newTab.title)
        }
        
        /// Persist tab state if a URL was provided.
        /// We don't save blank tabs to keep storage clean.
        if url != nil {
            saveTabGroupsIfNeeded()
        }
    }
    
    /// Creates a tab from saved state during app restoration.
    /// This is used when loading tabs from disk, not for user-initiated tab creation.
    /// 
    /// Key differences from createNewTab:
    /// - Doesn't make the tab active/selected
    /// - Doesn't save state (we're loading, not saving)
    /// - Doesn't add to history (these are old pages)
    /// - Accepts all tab properties for exact restoration
    /// 
    /// Parameters:
    /// - title: The page title to restore
    /// - url: The URL to restore (nil = homepage)
    /// - isPinned: Whether this tab was pinned
    /// - groupID: Optional UUID of tab group
    /// - engine: Browser engine to use (nil = user's default)
    /// 
    /// Returns: The newly created Tab object
    /// 
    /// For Swift beginners:
    /// - Multiple default parameters (= false, = nil) make calling convenient
    /// - Return type is Tab (not optional) - always succeeds
    func createRestoredTab(title: String, url: URL?, isPinned: Bool = false, groupID: UUID? = nil, engine: BrowserEngine? = nil) -> Tab {
        /// Create tab with full restoration parameters.
        /// Uses nil coalescing (??) to fall back to default engine if none specified.
        let tab = Tab(url: url, browserEngine: engine ?? BrowserSettings.shared.browserEngine, isPinned: isPinned, groupID: groupID)
        
        /// Set the restored title.
        /// Tab initializer sets title to "New Tab", so we override with saved title.
        tab.title = title
        
        /// Add to tabs array WITHOUT selecting it.
        /// Caller decides which tab to select after all are restored.
        tabs.append(tab)
        
        /// Return the tab in case caller needs to do additional setup.
        return tab
    }
    
    // MARK: - Tab Lifecycle
    
    /// Closes the specified tab and selects an appropriate replacement.
    /// Ensures at least one tab always exists.
    /// 
    /// Selection logic after closing:
    /// 1. If other tabs exist, select the next tab (or previous if closing last tab)
    /// 2. If no tabs remain, create a new blank tab
    /// 
    /// For Swift beginners:
    /// - firstIndex(where:) finds array index matching a condition
    /// - The closure { $0.id == tab.id } checks if each element's id matches
    func closeTab(_ tab: Tab) {
        /// Find this tab's position in our array.
        /// Returns nil if tab isn't found (shouldn't happen).
        if let index = tabs.firstIndex(where: { $0.id == tab.id }) {
            /// Break the reference cycle by clearing the WKWebView.
            /// This ensures proper memory cleanup.
            tab.webView = nil
            
            /// Remove from array. This triggers @Published update.
            tabs.remove(at: index)
            
            /// Save updated state to disk.
            saveTabGroupsIfNeeded()
            
            /// Ensure at least one tab exists.
            if tabs.isEmpty {
                createNewTab()
            } else if selectedTab?.id == tab.id {
                /// We closed the active tab - select a replacement.
                /// Try next tab, then previous, then first available.
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
    
    /// Makes the specified tab active and visible.
    /// Also records the visit in browsing history.
    func selectTab(_ tab: Tab) {
        selectedTab = tab
        isTabDrawerVisible = false
        
        /// Add to history for visit tracking.
        if let url = tab.url {
            HistoryManager.shared.addEntry(url: url, title: tab.title.isEmpty ? (url.host ?? url.absoluteString) : tab.title)
        }
        
        /// Force UI update by manually sending change notification.
        objectWillChange.send()
    }
    
    // MARK: - Tab Drawer UI
    
    /// Toggles tab drawer visibility with spring animation.
    func toggleTabDrawer() {
        withAnimation(.spring()) {
            isTabDrawerVisible.toggle()
        }
    }
    
    /// Hides the tab drawer with spring animation.
    func hideTabDrawer() {
        withAnimation(.spring()) {
            isTabDrawerVisible = false
        }
    }
    
    // MARK: - Web View Access
    
    /// Provides safe access to the currently selected tab's web view.
    /// Returns nil if no tab is selected or if the web view hasn't been initialized yet.
    /// 
    /// **Use case**: Useful for features that need to interact with the current page's content,
    /// such as detecting taps on interactive elements or executing JavaScript.
    var currentWebView: WKWebView? {
        return selectedTab?.webView
    }
    
    /// Checks if a navigation event started after the given timestamp.
    /// Used to determine if a user's tap triggered navigation (clicking a link)
    /// versus just trying to reveal the bottom bar.
    /// 
    /// **Use case**: When the bottom bar is hidden and user taps, we wait a short time.
    /// If navigation starts during that window, we assume they clicked a link and don't show the bar.
    /// 
    /// - Parameter since: The timestamp to compare against (typically when tap was detected)
    /// - Returns: true if navigation started after the given time, false otherwise
    func navigationStartedSince(_ since: Date) -> Bool {
        return lastNavigationStart > since
    }
    
    // MARK: - Browser Engine Switching
    
    /// Changes the browser engine for a specific tab.
    /// Forces WebView recreation to apply the new engine.
    /// 
    /// For Swift beginners:
    /// - We use DispatchQueue.main.async to avoid SwiftUI publishing errors
    /// - Changing @Published properties during view updates can cause crashes
    /// - async schedules the change for "next run loop" safely
    func changeBrowserEngine(for tab: Tab, to engine: BrowserEngine) {
        DispatchQueue.main.async {
            tab.browserEngine = engine
            
            /// Clear WebView to force recreation with new engine.
            tab.webView = nil
            
            /// Persist the engine change.
            self.saveTabGroupsIfNeeded()
            
            /// Trigger UI update.
            self.objectWillChange.send()
        }
    }
    
    /// Toggles between WebKit and Blink for the specified tab.
    func toggleBrowserEngine(for tab: Tab) {
        let newEngine: BrowserEngine = tab.browserEngine == .webkit ? .blink : .webkit
        changeBrowserEngine(for: tab, to: newEngine)
    }
    
    // MARK: - Pinned Tabs
    
    /// Pins a tab, making it persistent across app launches.
    /// Pinned tabs appear first in the tab list.
    func pinTab(_ tab: Tab) {
        /// Tabs without URLs can't be pinned (nothing to restore).
        guard let url = tab.url else { 
            print("Cannot pin tab without URL")
            return 
        }
        
        /// Register with persistence manager.
        pinnedTabManager.pinTab(url: url, title: tab.title)
        tab.isPinned = true
        
        /// Move to front of tabs array.
        repositionPinnedTabs()
    }
    
    /// Unpins a tab, making it ephemeral (won't persist).
    func unpinTab(_ tab: Tab) {
        guard let url = tab.url else {
            print("Cannot unpin tab without URL")
            return
        }
        
        /// Unregister from persistence.
        pinnedTabManager.unpinTab(url: url)
        tab.isPinned = false
        
        /// Reorder tabs array.
        repositionPinnedTabs()
    }
    
    /// Checks if a tab is currently pinned.
    func isTabPinned(_ tab: Tab) -> Bool {
        guard let url = tab.url else { return false }
        return pinnedTabManager.isTabPinned(url: url)
    }
    
    // MARK: - Private Helpers
    
    /// Sets up Combine observer to watch for pinned tab changes.
    /// When pinned tabs change externally (iCloud sync, other device), update our tabs.
    /// 
    /// For Swift beginners:
    /// - $ prefix accesses the @Published property's publisher
    /// - .sink subscribes to published values
    /// - [weak self] prevents retain cycle
    /// - .store saves subscription so it stays active
    private func setupPinnedTabObserver() {
        pinnedTabManager.$pinnedTabs
            .sink { [weak self] _ in
                /// Always update on main thread (UI requirement).
                DispatchQueue.main.async {
                    self?.updateTabPinnedStates()
                }
            }
            .store(in: &cancellables)
    }
    
    /// Restores pinned tabs from persistent storage on app launch.
    /// Creates Tab objects from saved pinned tab entities.
    private func restorePinnedTabs() {
        /// Get pinned tabs sorted by their saved order.
        /// .sorted creates a new sorted array without modifying original.
        let pinnedTabEntities = pinnedTabManager.pinnedTabs
            .sorted { $0.pinnedOrder < $1.pinnedOrder }
        
        /// Create a Tab for each pinned entity.
        for entity in pinnedTabEntities {
            let url = entity.url
            /// _ = discards the return value (we don't need it here).
            _ = createRestoredTab(title: entity.title, url: url, isPinned: true, groupID: nil)
        }
        
        /// Auto-select the first tab so user sees content immediately.
        if let firstTab = tabs.first {
            selectedTab = firstTab
        }
    }
    
    /// Synchronizes tab pinned states with the pinned tab manager.
    /// Called when pinned tabs change externally (iCloud sync).
    private func updateTabPinnedStates() {
        /// Check each tab against persistence to see if pin state changed.
        for tab in tabs {
            if let url = tab.url {
                let wasPinned = tab.isPinned
                let isPinned = pinnedTabManager.isTabPinned(url: url)
                
                /// Only update if state actually changed.
                if wasPinned != isPinned {
                    tab.isPinned = isPinned
                }
            }
        }
        
        /// Reorder tabs to maintain pinned-first ordering.
        repositionPinnedTabs()
    }
    
    /// Sorts tabs array so pinned tabs appear before unpinned tabs.
    /// Within each group (pinned/unpinned), maintains existing order.
    private func repositionPinnedTabs() {
        /// Sort using custom comparison logic.
        /// For Swift beginners:
        /// - .sort modifies array in-place
        /// - Closure returns true if tab1 should come before tab2
        tabs.sort { tab1, tab2 in
            if tab1.isPinned && !tab2.isPinned {
                /// Pinned tab comes before unpinned tab.
                return true
            } else if !tab1.isPinned && tab2.isPinned {
                /// Unpinned tab comes after pinned tab.
                return false
            } else {
                /// Both same type - maintain existing relative order.
                return false
            }
        }
    }
    
    /// Sorts tabs by pinned status first, then by group membership.
    /// Final order: pinned tabs, grouped tabs (by group age), ungrouped tabs.
    private func repositionGroupedTabs() {
        /// First pass: ensure pinned tabs are at front.
        repositionPinnedTabs()
        
        /// Second pass: sort non-pinned tabs by group membership.
        /// .filter creates new array with only matching elements.
        let nonPinnedTabs = tabs.filter { !$0.isPinned }
        let sortedNonPinned = nonPinnedTabs.sorted { tab1, tab2 in
            /// Use switch on tuple to handle all four combinations.
            /// For Swift beginners:
            /// - (tab1.groupID != nil, tab2.groupID != nil) creates a tuple of bools
            /// - switch matches against tuple patterns
            switch (tab1.groupID != nil, tab2.groupID != nil) {
            case (true, false):
                /// tab1 has group, tab2 doesn't - tab1 comes first.
                return true
            case (false, true):
                /// tab2 has group, tab1 doesn't - tab2 comes first.
                return false
            case (true, true):
                /// Both have groups - sort by group creation date (older groups first).
                guard let group1 = tabGroups.first(where: { $0.id == tab1.groupID }),
                      let group2 = tabGroups.first(where: { $0.id == tab2.groupID }) else {
                    return false
                }
                return group1.createdAt < group2.createdAt
            case (false, false):
                /// Neither has group - maintain original order.
                return false
            }
        }
        
        /// Reconstruct tabs array: pinned first, then sorted non-pinned.
        /// The + operator concatenates arrays.
        let pinnedTabs = tabs.filter { $0.isPinned }
        tabs = pinnedTabs + sortedNonPinned
        
        print("🔄 Repositioned tabs: \(pinnedTabs.count) pinned + \(sortedNonPinned.count) grouped/ungrouped")
    }
    
    // MARK: - Tab Groups
    
    /// Creates a new tab group and optionally assigns tabs to it.
    /// 
    /// Parameters:
    /// - name: Display name for the group
    /// - color: Visual color identifier (default: blue)
    /// - selectedTabIDs: Tab IDs to add to the group immediately
    /// 
    /// Returns: The newly created TabGroup
    func createTabGroup(name: String, color: TabGroupColor = .blue, selectedTabIDs: [String] = []) -> TabGroup {
        /// Create the group object.
        let group = TabGroup(name: name, color: color)
        tabGroups.append(group)
        
        /// Assign specified tabs to this group.
        /// .first(where:) finds first tab matching the condition.
        for tabID in selectedTabIDs {
            if let tab = tabs.first(where: { $0.id == tabID }) {
                tab.groupID = group.id
            }
        }
        
        /// Persist the new group.
        saveTabGroupsIfNeeded()
        
        /// Force UI update on main thread.
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
        
        return group
    }
    
    /// Deletes a tab group and optionally ungroups its tabs.
    /// 
    /// Parameter moveTabsToNoGroup:
    /// - true: Tabs stay open but leave the group (default)
    /// - false: Tabs are closed along with the group
    func deleteTabGroup(_ group: TabGroup, moveTabsToNoGroup: Bool = true) {
        /// Unlink tabs from this group if requested.
        /// 'where' clause filters tabs in the loop.
        if moveTabsToNoGroup {
            for tab in tabs where tab.groupID == group.id {
                tab.groupID = nil
            }
        }
        
        /// Remove group from array.
        /// .removeAll with closure removes matching elements.
        tabGroups.removeAll { $0.id == group.id }
        saveTabGroupsIfNeeded()
        
        /// Update UI.
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }
    
    /// Adds a tab to an existing group.
    func addTabToGroup(_ tab: Tab, group: TabGroup) {
        tab.groupID = group.id
        saveTabGroupsIfNeeded()
        
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
        
        print("📝 Added tab '\(tab.title)' to group '\(group.name)'")
    }
    
    /// Removes a tab from its current group (if any).
    func removeTabFromGroup(_ tab: Tab) {
        tab.groupID = nil
        saveTabGroupsIfNeeded()
        
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
        
        print("📝 Removed tab '\(tab.title)' from group")
    }
    
    /// Convenience method that calls saveTabGroupsIfNeeded.
    func saveTabsIfNeeded() {
        saveTabGroupsIfNeeded()
    }
    
    /// Returns all tabs belonging to the specified group.
    func getTabsInGroup(_ group: TabGroup) -> [Tab] {
        /// .filter creates new array with only matching elements.
        return tabs.filter { $0.groupID == group.id }
    }
    
    /// Returns all tabs not belonging to any group.
    func getUngroupedTabs() -> [Tab] {
        return tabs.filter { $0.groupID == nil }
    }
    
    // MARK: - Confirmation Dialogs
    
    /// Requests to unpin a tab, showing confirmation dialog if enabled in settings.
    func requestUnpinTab(_ tab: Tab) {
        if BrowserSettings.shared.confirmClosingPinnedTabs {
            /// Show confirmation dialog.
            tabToUnpin = tab
            showUnpinConfirmation = true
        } else {
            /// Unpin immediately without confirmation.
            unpinTab(tab)
        }
    }
    
    /// User confirmed unpinning the tab.
    func confirmUnpinTab() {
        if let tab = tabToUnpin {
            unpinTab(tab)
        }
        tabToUnpin = nil
        showUnpinConfirmation = false
    }
    
    /// User cancelled unpinning the tab.
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
            // Load tab groups first
            if let data = UserDefaults.standard.data(forKey: "savedTabGroups"),
               let decoded = try? JSONDecoder().decode([TabGroup].self, from: data) {
                // Sort tab groups by creation date to maintain consistent order
                tabGroups = decoded.sorted { $0.createdAt < $1.createdAt }
            }
            print("📂 Loaded \(tabGroups.count) tab groups")
        }
    }
    
    func restoreTabGroupAssignments() {
        if BrowserSettings.shared.persistTabGroups {
            // First ensure we have all necessary groups loaded
            loadTabGroups()
            
            // Load comprehensive tab states first (new format)
            if let data = UserDefaults.standard.data(forKey: "savedTabStates"),
               let tabStates = try? JSONDecoder().decode([String: TabState].self, from: data) {
                
                print("📂 Restoring \(tabStates.count) tab states")
                restoreFromTabStates(tabStates)
                
            } else {
                // Fallback to old format for backward compatibility
                print("⚠️ Using legacy format for tab group restoration")
                restoreFromLegacyFormat()
            }
            
            // After restoration, ensure tabs are properly ordered within their groups
            repositionGroupedTabs()
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
                    print("🔄 Restored group assignment for tab: \(tab.title) -> \(groupID)")
                }
                
                // Restore browser engine
                if let browserEngine = BrowserEngine(rawValue: tabState.browserEngine) {
                    tab.browserEngine = browserEngine
                }
                
                // Restore title if available
                if let title = tabState.title, !title.isEmpty {
                    tab.title = title
                }
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
                let title = (tabState.title?.isEmpty == false) ? tabState.title! : "New Tab"
                let newTab = createRestoredTab(title: title, url: url, isPinned: false, groupID: groupID, engine: browserEngine)
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
            
            let validGroups = tabGroups.map { $0.id }
            print("📂 Found \(validGroups.count) valid groups for legacy restoration")
            
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
                   validGroups.contains(groupID) {
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
                    let newTab = createRestoredTab(title: "New Tab", url: url, isPinned: false, groupID: groupID)
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
