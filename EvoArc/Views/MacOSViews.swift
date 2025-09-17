//
//  MacOSViews.swift
//  EvoArc
//
//  Created on 2025-09-05.
//

import SwiftUI
import WebKit

#if os(macOS)
struct MacOSTabDrawerView: View {
    @ObservedObject var tabManager: TabManager
    @StateObject private var settings = BrowserSettings.shared
    @StateObject private var bookmarkManager = BookmarkManager.shared
    @State private var showingCreateGroupSheet = false
    @State private var newGroupName = ""
    @State private var newGroupColor: TabGroupColor = .blue
    @State private var showingBookmarks = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Tabs")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: {
                    showingBookmarks = true
                }) {
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: {
                    showingCreateGroupSheet = true
                }) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 14))
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: {
                    tabManager.createNewTab()
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 16))
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: {
                    tabManager.hideTabDrawer()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Tabs list
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    // Pinned tabs section
                    let pinnedTabs = tabManager.tabs.filter { $0.isPinned }
                    if !pinnedTabs.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Image(systemName: "pin.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.accentColor)
                                Text("PINNED")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.top, 4)
                            
                            ForEach(pinnedTabs) { tab in
                                MacOSTabItemView(
                                    tab: tab,
                                    isSelected: tabManager.selectedTab?.id == tab.id,
                                    onSelect: {
                                        tabManager.selectTab(tab)
                                    },
                                    onClose: {
                                        tabManager.closeTab(tab)
                                    },
                                    tabManager: tabManager
                                )
                            }
                        }
                    }
                    
                    // Tab groups sections
                    ForEach(tabManager.tabGroups) { group in
                        let groupTabs = tabManager.getTabsInGroup(group).filter { !$0.isPinned }
                        if !settings.hideEmptyTabGroups || !groupTabs.isEmpty {
                            MacOSTabGroupSectionView(
                                group: group,
                                tabs: groupTabs,
                                tabManager: tabManager
                            )
                        }
                    }
                    
                    // Ungrouped tabs section
                    let ungroupedTabs = tabManager.getUngroupedTabs().filter { !$0.isPinned }
                    if !ungroupedTabs.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            if (!pinnedTabs.isEmpty || !tabManager.tabGroups.isEmpty) {
                                HStack {
                                    Text("OTHER TABS")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .padding(.top, 8)
                            }
                            
                            ForEach(ungroupedTabs) { tab in
                                MacOSTabItemView(
                                    tab: tab,
                                    isSelected: tabManager.selectedTab?.id == tab.id,
                                    onSelect: {
                                        tabManager.selectTab(tab)
                                    },
                                    onClose: {
                                        tabManager.closeTab(tab)
                                    },
                                    tabManager: tabManager
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
        .border(Color(NSColor.separatorColor), width: 1)
        .sheet(isPresented: $showingCreateGroupSheet) {
            createGroupSheet
                .frame(minWidth: 800, minHeight: 600)
                .frame(idealWidth: 900, idealHeight: 700)
        }
        .sheet(isPresented: $showingBookmarks) {
            BookmarksView(tabManager: tabManager)
                .frame(minWidth: 800, minHeight: 600)
                .frame(idealWidth: 900, idealHeight: 700)
        }
    }
    
    @ViewBuilder
    private var createGroupSheet: some View {
        VStack(spacing: 0) {
            // Modern header with icon
            HStack(spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: "folder.badge.plus")
                        .font(.title)
                        .foregroundColor(.accentColor)
                    Text("Create Tab Group")
                        .font(.title)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                Spacer()
                Button("Cancel") {
                    showingCreateGroupSheet = false
                    newGroupName = ""
                    newGroupColor = .blue
                }
                .buttonStyle(.bordered)
                Button("Create") {
                    if !newGroupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        _ = tabManager.createTabGroup(name: newGroupName.trimmingCharacters(in: .whitespacesAndNewlines), color: newGroupColor)
                        showingCreateGroupSheet = false
                        newGroupName = ""
                        newGroupColor = .blue
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(newGroupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 20)
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // Main content area with spacious design
            ScrollView {
                VStack(spacing: 0) {
                    Spacer().frame(height: 60)
                    
                    VStack(spacing: 48) {
                        // Group Name Section with enhanced design
                        VStack(alignment: .leading, spacing: 20) {
                            HStack {
                                Text("Group Name")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                TextField("Enter a name for your tab group", text: $newGroupName)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.title3)
                                    .frame(height: 48)
                                    .focused($focusedField, equals: .groupName)
                                
                                Text("Choose a descriptive name to help organize your tabs")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: 500)
                        
                        // Group Color Section with enhanced layout
                        VStack(alignment: .leading, spacing: 24) {
                            HStack {
                                Text("Group Color")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                            
                            VStack(spacing: 16) {
                                Text("Select a color to identify this group")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                // Enhanced color grid with better spacing
                                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 20), count: 6), spacing: 24) {
                                    ForEach(TabGroupColor.allCases) { color in
                                        Button(action: {
                                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                                newGroupColor = color
                                            }
                                        }) {
                                            Circle()
                                                .fill(
                                                    LinearGradient(
                                                        gradient: Gradient(colors: [color.color, color.color.opacity(0.8)]),
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    )
                                                )
                                                .frame(width: 80, height: 80)
                                                .overlay(
                                                    Circle()
                                                        .stroke(newGroupColor == color ? Color.primary : Color.clear, lineWidth: 4)
                                                        .scaleEffect(newGroupColor == color ? 1.1 : 1.0)
                                                )
                                                .overlay(
                                                    Image(systemName: "checkmark")
                                                        .font(.system(size: 24, weight: .semibold))
                                                        .foregroundColor(.white)
                                                        .opacity(newGroupColor == color ? 1 : 0)
                                                        .scaleEffect(newGroupColor == color ? 1 : 0.5)
                                                )
                                                .shadow(color: color.color.opacity(0.3), radius: newGroupColor == color ? 8 : 4, x: 0, y: 4)
                                                .scaleEffect(newGroupColor == color ? 1.05 : 1.0)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                                .frame(maxWidth: 600)
                            }
                        }
                        
                        // Preview section
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Preview")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                            
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(newGroupColor.color)
                                    .frame(width: 16, height: 16)
                                
                                Text(newGroupName.isEmpty ? "My Tab Group" : newGroupName)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.primary)
                                
                                Text("(0 tabs)")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(NSColor.controlBackgroundColor))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                                    )
                            )
                            .frame(maxWidth: 300)
                            
                            Text("This is how your tab group will appear in the tab drawer")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: 500)
                    }
                    
                    Spacer().frame(height: 80)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 48)
            }
            .background(Color(NSColor.controlBackgroundColor))
        }
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                focusedField = .groupName
            }
        }
    }
    
    @FocusState private var focusedField: Field?
    
    enum Field {
        case groupName
    }
}

struct MacOSTabGroupSectionView: View {
    @ObservedObject var group: TabGroup
    let tabs: [Tab]
    let tabManager: TabManager
    
    @State private var showingDeleteConfirmation = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Group header
            HStack {
                Button(action: {
                    withAnimation(.spring()) {
                        group.update(isCollapsed: !group.isCollapsed)
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: group.isCollapsed ? "chevron.right" : "chevron.down")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        
                        Circle()
                            .fill(group.color.color)
                            .frame(width: 10, height: 10)
                        
                        Text(group.name.uppercased())
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                        
                        Text("(\(tabs.count))")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary.opacity(0.8))
                        
                        Spacer()
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: {
                    showingDeleteConfirmation = true
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                        .foregroundColor(.red)
                }
                .buttonStyle(PlainButtonStyle())
                .opacity(0.7)
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            
            // Group tabs (collapsible)
            if !group.isCollapsed {
                ForEach(tabs) { tab in
                    MacOSTabItemView(
                        tab: tab,
                        isSelected: tabManager.selectedTab?.id == tab.id,
                        onSelect: {
                            tabManager.selectTab(tab)
                        },
                        onClose: {
                            tabManager.closeTab(tab)
                        },
                        tabManager: tabManager
                    )
                    .padding(.leading, 8) // Indent group tabs slightly
                }
            }
        }
        .confirmationDialog(
            "Delete Group",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Group Only") {
                tabManager.deleteTabGroup(group, moveTabsToNoGroup: true)
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will delete the group but keep all tabs. The tabs will be moved to 'Other Tabs'.")
        }
    }
}

struct MacOSTabItemView: View {
    let tab: Tab
    let isSelected: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
    let tabManager: TabManager
    
    @State private var isHovered: Bool = false
    @State private var showingNewGroupAlert = false
    @State private var newGroupName = ""
    @State private var newGroupColor: TabGroupColor = .blue
    
    var body: some View {
        HStack(spacing: 8) {
            // Favicon placeholder or pin indicator
            if tab.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.accentColor)
                    .frame(width: 16, height: 16)
            } else {
                Image(systemName: "globe")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .frame(width: 16, height: 16)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(tab.title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                    .foregroundColor(.primary)
                
                if let url = tab.url {
                    Text(url.host ?? url.absoluteString)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Engine indicator badge
            Text(tab.browserEngine == .webkit ? "S" : "C")
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 12, height: 12)
                .background(
                    Circle()
                        .fill(tab.browserEngine == .webkit ? Color.blue : Color.orange)
                )
            
            if isHovered {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor.opacity(0.2) : (isHovered ? Color(NSColor.controlAccentColor).opacity(0.1) : Color.clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1)
        )
        .onTapGesture {
            onSelect()
        }
        .onHover { hovering in
            isHovered = hovering
        }
        .contextMenu {
            // Pin/Unpin option
            if tab.isPinned {
                Button(action: {
                    tabManager.requestUnpinTab(tab)
                }) {
                    Label("Unpin Tab", systemImage: "pin.slash")
                }
            } else {
                Button(action: {
                    tabManager.pinTab(tab)
                }) {
                    Label("Pin Tab", systemImage: "pin")
                }
            }
            
            Divider()
            
            // Tab Group options
            if tab.groupID != nil {
                Button(action: {
                    tabManager.removeTabFromGroup(tab)
                }) {
                    Label("Remove from Group", systemImage: "folder.badge.minus")
                }
            }
            
            // Always show "Create New Group" option
            Button(action: {
                showingNewGroupAlert = true
            }) {
                Label("Create New Group", systemImage: "folder.badge.plus")
            }
            
            // Show existing groups if any exist
            if !tabManager.tabGroups.isEmpty {
                Menu("Add to Existing Group") {
                    ForEach(tabManager.tabGroups.filter { $0.id != tab.groupID }) { group in
                        Button(action: {
                            tabManager.addTabToGroup(tab, group: group)
                        }) {
                            HStack {
                                Circle()
                                    .fill(group.color.color)
                                    .frame(width: 12, height: 12)
                                Text(group.name)
                            }
                        }
                    }
                }
            }
            
            Divider()
            
            Text("Browser Engine")
            
            Button(action: {
                tabManager.changeBrowserEngine(for: tab, to: .webkit)
            }) {
                HStack {
                    Text(BrowserEngine.webkit.displayName)
                    Spacer()
                    if tab.browserEngine == .webkit {
                        Image(systemName: "checkmark")
                    }
                }
            }
            
            Button(action: {
                tabManager.changeBrowserEngine(for: tab, to: .blink)
            }) {
                HStack {
                    Text(BrowserEngine.blink.displayName)
                    Spacer()
                    if tab.browserEngine == .blink {
                        Image(systemName: "checkmark")
                    }
                }
            }
            
            Divider()
            
            Button("Close Tab", action: onClose)
        }
        .sheet(isPresented: $showingNewGroupAlert) {
            newGroupSheet
                .frame(minWidth: 580, minHeight: 480)
                .frame(idealWidth: 620, idealHeight: 520)
        }
    }
    
    private func createNewGroupAndAddTab() {
        let trimmedName = newGroupName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedName.isEmpty {
            let group = tabManager.createTabGroup(name: trimmedName, color: newGroupColor)
            tabManager.addTabToGroup(tab, group: group)
            resetGroupCreation()
        }
    }
    
    private func resetGroupCreation() {
        newGroupName = ""
        newGroupColor = .blue
    }
    
    @ViewBuilder
    private var newGroupSheet: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Main content area with proper vertical centering
                VStack(spacing: 0) {
                    Spacer().frame(height: 20)
                    
                    VStack(spacing: 32) {
                        // Group Name Section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Group Name")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                            TextField("Enter group name", text: $newGroupName)
                                .textFieldStyle(.roundedBorder)
                                .font(.body)
                                .frame(height: 44)
                        }
                        
                        // Group Color Section
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Group Color")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                            
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 16) {
                                ForEach(TabGroupColor.allCases) { color in
                                    Button(action: {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            newGroupColor = color
                                        }
                                    }) {
                                        Circle()
                                            .fill(color.color)
                                            .frame(minWidth: 60, idealWidth: 70, maxWidth: 90)
                                            .aspectRatio(1, contentMode: .fit)
                                            .overlay(
                                                Circle()
                                                    .stroke(newGroupColor == color ? Color.primary : Color.clear, lineWidth: 3)
                                            )
                                            .scaleEffect(newGroupColor == color ? 1.1 : 1.0)
                                            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 2)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                    }
                    
                    Spacer().frame(minHeight: 20)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 40)
            }
            .padding()
            .navigationTitle("New Tab Group")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        resetGroupCreation()
                        showingNewGroupAlert = false
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createNewGroupAndAddTab()
                        showingNewGroupAlert = false
                    }
                    .disabled(newGroupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                #else
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        resetGroupCreation()
                        showingNewGroupAlert = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createNewGroupAndAddTab()
                        showingNewGroupAlert = false
                    }
                    .disabled(newGroupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                #endif
            }
        }
    }
}

struct MacOSBottomBarView: View {
    @Binding var urlString: String
    @Binding var isURLBarFocused: Bool
    @ObservedObject var tabManager: TabManager
    @ObservedObject var selectedTab: Tab
    @Binding var showingSettings: Bool
    @Binding var shouldNavigate: Bool
    @StateObject private var settings = BrowserSettings.shared
    @StateObject private var bookmarkManager = BookmarkManager.shared
    @StateObject private var searchPreloadManager = SearchPreloadManager.shared
    @State private var urlEditingText: String = ""
    @State private var searchTimer: Timer?
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Progress bar
            if selectedTab.isLoading {
                ProgressView(value: selectedTab.estimatedProgress, total: 1.0)
                    .progressViewStyle(LinearProgressViewStyle())
                    .frame(height: 2)
            }
            
            Divider()
            
            HStack(spacing: 12) {
                // Back button
                Button(action: {
                    selectedTab.webView?.goBack()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14))
                        .foregroundColor(selectedTab.canGoBack ? .primary : .secondary)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(!selectedTab.canGoBack)
                
                // Forward button
                Button(action: {
                    selectedTab.webView?.goForward()
                }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .foregroundColor(selectedTab.canGoForward ? .primary : .secondary)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(!selectedTab.canGoForward)
                
                // Reload/Stop button
                Button(action: {
                    if selectedTab.isLoading {
                        selectedTab.webView?.stopLoading()
                    } else {
                        selectedTab.webView?.reload()
                    }
                }) {
                    Image(systemName: selectedTab.isLoading ? "xmark" : "arrow.clockwise")
                        .font(.system(size: 14))
                        .foregroundColor(.primary)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Enhanced URL bar with suggestions support
                HStack {
                    Button(action: {
                        if selectedTab.isLoading {
                            selectedTab.webView?.stopLoading()
                        }
                    }) {
                        Image(systemName: selectedTab.isLoading ? "xmark" : "lock.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .disabled(!selectedTab.isLoading)
                    
                    TextField("Search or enter address", text: $urlEditingText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .onReceive(selectedTab.$url) { newURL in
                            if !isURLBarFocused {
                                // Only show URL if explicitly enabled
                                if selectedTab.showURLInBar {
                                    urlEditingText = newURL?.absoluteString ?? ""
                                } else {
                                    urlEditingText = ""
                                }
                            }
                        }
                        .onTapGesture {
                            if !isTextFieldFocused {
                                // When user taps URL bar, enable URL display
                                selectedTab.showURLInBar = true
                                // Show current URL if available
                                if let currentURL = selectedTab.webView?.url {
                                    urlEditingText = currentURL.absoluteString
                                }
                                isTextFieldFocused = true
                            }
                        }
                        .onChange(of: urlEditingText) { _, newValue in
                            // Cancel previous timer
                            searchTimer?.invalidate()
                            
                            // Preload search results after a delay
                            if newValue.count > 2 {
                                searchTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
                                    searchPreloadManager.preloadSearch(for: newValue)
                                }
                            }
                        }
                        .onSubmit {
                            urlString = urlEditingText
                            shouldNavigate = true
                            isTextFieldFocused = false
                        }
                        .focused($isTextFieldFocused)
                        .onTapGesture {
                            if !isTextFieldFocused {
                                urlEditingText = urlString
                                isTextFieldFocused = true
                            }
                        }
                        .onChange(of: isTextFieldFocused) { _, focused in
                            isURLBarFocused = focused
                        }
                    
                    HStack(spacing: 6) {
                        // Show preloading indicator when active
                        if searchPreloadManager.isPreloading {
                            ProgressView()
                                .scaleEffect(0.6)
                        }
                        
                        // Bookmark button - only show when not focused or if there's a current URL
                        if !isURLBarFocused, let currentURL = selectedTab.url {
                            Button(action: {
                                if bookmarkManager.isBookmarked(url: currentURL) {
                                    if let bookmark = bookmarkManager.getBookmark(for: currentURL) {
                                        bookmarkManager.removeBookmark(bookmark)
                                    }
                                } else {
                                    let title = selectedTab.title.isEmpty ? currentURL.host ?? currentURL.absoluteString : selectedTab.title
                                    bookmarkManager.addBookmark(title: title, url: currentURL, folderID: bookmarkManager.favoritesFolder?.id)
                                }
                            }) {
                                Image(systemName: bookmarkManager.isBookmarked(url: currentURL) ? "bookmark.fill" : "bookmark")
                                    .font(.system(size: 12))
                                    .foregroundColor(bookmarkManager.isBookmarked(url: currentURL) ? .accentColor : .secondary)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        
                        // Clear button when focused
                        if isURLBarFocused && !urlEditingText.isEmpty {
                            Button(action: {
                                urlEditingText = ""
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        
                        // Done button when focused
                        if isURLBarFocused {
                            Button(action: {
                                isTextFieldFocused = false
                                urlString = urlEditingText
                                if !urlEditingText.isEmpty {
                                    shouldNavigate = true
                                }
                            }) {
                                Text("Done")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.accentColor)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        
                        // Show loading indicator when not focused
                        if !isURLBarFocused && selectedTab.isLoading {
                            ProgressView()
                                .scaleEffect(0.6)
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
                .animation(.easeInOut(duration: 0.25), value: isURLBarFocused)
                
                // Right side buttons - hidden when URL bar is focused
                if !isURLBarFocused {
                    HStack(spacing: 8) {
                        // Pin/Unpin button
                        Button(action: {
                            if selectedTab.isPinned {
                                tabManager.unpinTab(selectedTab)
                            } else {
                                tabManager.pinTab(selectedTab)
                            }
                        }) {
                            Image(systemName: selectedTab.isPinned ? "pin.slash" : "pin")
                                .font(.system(size: 14))
                                .foregroundColor(selectedTab.isPinned ? .accentColor : .primary)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(selectedTab.url == nil)
                        
                        // Tab drawer toggle button
                        Button(action: {
                            tabManager.toggleTabDrawer()
                        }) {
                            Image(systemName: "sidebar.leading")
                                .font(.system(size: 14))
                                .foregroundColor(.primary)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // Menu button with consolidated options
                        Menu {
                            Button(action: {
                                tabManager.createNewTab()
                            }) {
                                Label("New Tab", systemImage: "plus.square")
                            }
                            
                            Button(action: {
                                // Navigate to homepage in current tab
                                if let homepage = BrowserSettings.shared.homepageURL {
                                    selectedTab.webView?.load(URLRequest(url: homepage))
                                }
                            }) {
                                Label("Home", systemImage: "house")
                            }
                            
                            Divider()
                            
                            Button(action: {
                                settings.useDesktopMode.toggle()
                            }) {
                                Label(
                                    settings.useDesktopMode ? "Request Mobile Website" : "Request Desktop Website",
                                    systemImage: settings.useDesktopMode ? "iphone" : "desktopcomputer"
                                )
                            }
                            
                            Button(action: {
                                settings.adBlockEnabled.toggle()
                                selectedTab.webView?.reload()
                            }) {
                                Label(
                                    settings.adBlockEnabled ? "Disable Ad Blocking" : "Enable Ad Blocking",
                                    systemImage: settings.adBlockEnabled ? "eye.slash" : "eye"
                                )
                            }
                            
                            // JavaScript blocking toggle for current site
                            if let currentURL = selectedTab.url {
                                Button(action: {
                                    JavaScriptBlockingManager.shared.toggleJavaScriptBlocking(for: currentURL)
                                    // Reload the page to apply the change
                                    selectedTab.webView?.reload()
                                }) {
                                    let isBlocked = JavaScriptBlockingManager.shared.isJavaScriptBlocked(for: currentURL)
                                    Label(
                                        isBlocked ? "Enable JavaScript" : "Disable JavaScript",
                                        systemImage: isBlocked ? "play.fill" : "stop.fill"
                                    )
                                }
                            }
                            
                            Divider()
                            
                            Button(action: {
                                if let url = selectedTab.url {
                                    let picker = NSSharingServicePicker(items: [url])
                                    // Present the picker relative to the Share menu item
                                    if let menuItem = NSApplication.shared.keyWindow?.contentView?.window?.contentView {
                                        picker.show(relativeTo: .zero, of: menuItem, preferredEdge: .minY)
                                    }
                                }
                            }) {
                                Label("Share", systemImage: "square.and.arrow.up")
                            }
                            .disabled(selectedTab.url == nil)
                            
                            // Perplexity options
                            if PerplexityManager.shared.isAuthenticated, let currentURL = selectedTab.url {
                                Divider()
                                
                                Button(action: {
                                    PerplexityManager.shared.performAction(
                                        .summarize,
                                        for: currentURL,
                                        title: selectedTab.title
                                    )
                                }) {
                                    Label("Summarize with Perplexity", systemImage: "doc.text.magnifyingglass")
                                }
                                
                                Button(action: {
                                    PerplexityManager.shared.performAction(
                                        .sendToPerplexity,
                                        for: currentURL,
                                        title: selectedTab.title
                                    )
                                }) {
                                    Label("Send to Perplexity", systemImage: "arrow.up.right.square")
                                }
                            }
                            
                            Divider()
                            
                            Button(action: {
                                showingSettings = true
                            }) {
                                Label("Settings", systemImage: "gear")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 14))
                                .foregroundColor(.primary)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .menuStyle(BorderlessButtonMenuStyle())
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(NSColor.windowBackgroundColor))
            .animation(.easeInOut(duration: 0.25), value: isURLBarFocused)
            
            // Enhanced suggestions with history and search
            if isURLBarFocused {
                SafariStyleSuggestionsView(
                    query: urlEditingText,
                    preloadedResult: searchPreloadManager.getPreloadedResult(for: urlEditingText),
                    onSuggestionTap: { suggestion in
                        urlEditingText = suggestion
                        urlString = suggestion
                        shouldNavigate = true
                        isTextFieldFocused = false
                    },
                    onTopResultTap: { url in
                        urlString = url.absoluteString
                        shouldNavigate = true
                        isTextFieldFocused = false
                    }
                )
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                .padding(.horizontal, 16)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .onAppear {
            urlEditingText = urlString
        }
        .onDisappear {
            searchTimer?.invalidate()
        }
    }
}

// MARK: - Safari-style Suggestions View for macOS
struct SafariStyleSuggestionsView: View {
    let query: String
    let preloadedResult: SearchPreloadManager.SearchResult?
    let onSuggestionTap: (String) -> Void
    let onTopResultTap: (URL) -> Void
    
    @StateObject private var searchSuggestionManager = SearchSuggestionsManager.shared
    @StateObject private var bookmarkManager = BookmarkManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top result from website (if available)
            if let preloadedResult = preloadedResult,
               let firstResultURL = preloadedResult.firstResultURL {
                TopResultView(
                    title: preloadedResult.firstResultTitle ?? firstResultURL.host ?? "Website",
                    url: firstResultURL,
                    onTap: { onTopResultTap(firstResultURL) }
                )
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                
                Divider()
            }
            
            // Search Suggestions (clean Safari-style, no branding)
            if !query.isEmpty && !searchSuggestionManager.suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(searchSuggestionManager.suggestions.indices, id: \.self) { index in
                        let suggestion = searchSuggestionManager.suggestions[index]
                        Button(action: { onSuggestionTap(suggestion.text) }) {
                            HStack(spacing: 12) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                                    .frame(width: 18, height: 18)
                                
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(suggestion.text)
                                        .font(.system(size: 13))
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                
                                Spacer()
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.clear)
                        .contentShape(Rectangle())
                        
                        if index < searchSuggestionManager.suggestions.count - 1 {
                            Divider()
                                .padding(.leading, 46)
                        }
                    }
                }
                
                if !getBookmarkSuggestions(for: query).isEmpty || !HistoryManager.shared.getHistorySuggestions(for: query).isEmpty {
                    Divider()
                }
            }
            
            // Bookmarks and History Section
            if !query.isEmpty {
                let historySuggestions = HistoryManager.shared.getHistorySuggestions(for: query)
                let bookmarkSuggestions = getBookmarkSuggestions(for: query)
                let combinedSuggestions = getCombinedSuggestions(bookmarkSuggestions: bookmarkSuggestions, historySuggestions: historySuggestions)
                
                if !combinedSuggestions.isEmpty {
                    SuggestionSectionView(
                        title: "Bookmarks and History",
                        suggestions: combinedSuggestions
                    )
                }
            } else {
                // Show recent history and bookmarks when no query
                let recentHistory = Array(HistoryManager.shared.recentHistory.prefix(3))
                let recentBookmarks = Array(bookmarkManager.bookmarks.prefix(3))
                
                if !recentHistory.isEmpty {
                    SuggestionSectionView(
                        title: "Recently Visited",
                        suggestions: recentHistory.map { entry in
                            SuggestionRowData(
                                text: entry.title,
                                subtitle: entry.url.host ?? entry.url.absoluteString,
                                icon: "clock",
                                action: { onTopResultTap(entry.url) }
                            )
                        }
                    )
                    
                    if !recentBookmarks.isEmpty {
                        Divider()
                    }
                }
                
                if !recentBookmarks.isEmpty {
                    SuggestionSectionView(
                        title: "Bookmarks",
                        suggestions: recentBookmarks.map { bookmark in
                            SuggestionRowData(
                                text: bookmark.title,
                                subtitle: bookmark.url.host ?? bookmark.url.absoluteString,
                                icon: "bookmark.fill",
                                action: { onTopResultTap(bookmark.url) }
                            )
                        }
                    )
                }
            }
        }
        .frame(maxHeight: 400)
        .onAppear {
            if !query.isEmpty {
                searchSuggestionManager.getSuggestions(for: query)
            }
        }
        .onChange(of: query) { _, newQuery in
            if !newQuery.isEmpty {
                searchSuggestionManager.getSuggestions(for: newQuery)
            }
        }
    }
    
    private func getBookmarkSuggestions(for query: String) -> [Bookmark] {
        let lowercaseQuery = query.lowercased()
        return bookmarkManager.bookmarks.filter { bookmark in
            bookmark.title.lowercased().contains(lowercaseQuery) ||
            bookmark.url.absoluteString.lowercased().contains(lowercaseQuery) ||
            bookmark.url.host?.lowercased().contains(lowercaseQuery) == true
        }
    }
    
    private func getCombinedSuggestions(bookmarkSuggestions: [Bookmark], historySuggestions: [HistoryEntry]) -> [SuggestionRowData] {
        var combined: [SuggestionRowData] = []
        
        // Add bookmark suggestions (up to 2)
        combined.append(contentsOf: bookmarkSuggestions.prefix(2).map { bookmark in
            SuggestionRowData(
                text: bookmark.title,
                subtitle: bookmark.url.host ?? bookmark.url.absoluteString,
                icon: "bookmark.fill",
                action: { onTopResultTap(bookmark.url) }
            )
        })
        
        // Add history suggestions (up to 2)
        combined.append(contentsOf: historySuggestions.prefix(2).map { historyEntry in
            SuggestionRowData(
                text: historyEntry.title,
                subtitle: historyEntry.url.host ?? historyEntry.url.absoluteString,
                icon: "clock",
                action: { onTopResultTap(historyEntry.url) }
            )
        })
        
        return Array(combined.prefix(4))
    }
}

// MARK: - Supporting Types
struct SuggestionRowData {
    let text: String
    let subtitle: String?
    let icon: String
    let action: () -> Void
}

#endif
