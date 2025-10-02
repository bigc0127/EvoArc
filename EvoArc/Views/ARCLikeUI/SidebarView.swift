//
//  SidebarView.swift
//  EvoArc
//
//  ARC Like UI sidebar with tab management
//

import SwiftUI
import WebKit
import Combine

struct SidebarView: View {
    @ObservedObject var tabManager: TabManager
    @ObservedObject var uiViewModel: UIViewModel
    @StateObject private var bookmarkManager = BookmarkManager.shared
    @StateObject private var settings = BrowserSettings.shared
    
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var dragOffset: CGFloat = 0
    @State private var startWidth: CGFloat?
    @State private var hoverSearch = false
    @State private var showingBookmarks = false
    @State private var showingHistory = false
    @State private var showingNewGroupSheet = false
    @State private var newGroupName = ""
    @State private var newGroupColor: TabGroupColor = .blue
    @State private var canGoBack: Bool = false
    @State private var canGoForward: Bool = false
    
    var body: some View {
        HStack(spacing: 0) {
            // Drag to resize: Right side
            if uiViewModel.sidebarPosition == "right" {
                resizeHandle
            }
            
            // Main sidebar content
            VStack(spacing: 0) {
                Spacer().frame(height: 0)
                
                // Toolbar with navigation buttons
                toolbarButtons
                
                // Search/URL bar
                searchBar
                
                // Tabs section
                ScrollView {
                    VStack(spacing: 12) {
                        // Pinned tabs
                        pinnedTabsSection
                        
                        // Tab groups
                        tabGroupsSection
                        
                        // New tab button
                        newTabButton
                        
                        // Ungrouped tabs
                        ungroupedTabsSection
                    }
                    .padding(.vertical, 10)
                }
                
                // Bottom controls
                bottomControls
            }
            .frame(width: uiViewModel.sidebarWidth + dragOffset)
            .clipped()
            
            // Drag to resize: Left side
            if uiViewModel.sidebarPosition == "left" {
                resizeHandle
            }
        }
    }
    
    // MARK: - Subviews
    
    private var resizeHandle: some View {
        ZStack {
            Rectangle()
                .fill(Color.gray.opacity(0.001))
                .frame(width: 15)
                .contentShape(Rectangle())
            
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.25))
                .frame(width: 5, height: 30)
        }
        .contentShape(Rectangle())
        .gesture(resizeDragGesture)
    }
    
    private var toolbarButtons: some View {
        HStack {
            Spacer()
            
            Button(action: { 
                uiViewModel.isSidebarFloating = false // When manually closing, clear floating mode
                uiViewModel.showSidebar.toggle() 
            }) {
                buttonBackground(id: "sidebarToggle", systemImage: "sidebar.left")
            }
            
            Spacer()
            
            Button(action: { tabManager.selectedTab?.webView?.goBack() }) {
                buttonBackground(id: "goBack", systemImage: "arrow.left")
            }
            .disabled(!canGoBack)
            
            Button(action: { tabManager.selectedTab?.webView?.goForward() }) {
                buttonBackground(id: "goForward", systemImage: "arrow.right")
            }
            .disabled(!canGoForward)
            
            Button {
                guard let webView = tabManager.selectedTab?.webView else { return }
                if webView.isLoading {
                    webView.stopLoading()
                }
                webView.reload()
            } label: {
                buttonBackground(id: "reload", systemImage: "arrow.clockwise")
            }
        }
        .padding(.horizontal, 8)
        .onReceive(tabManager.$selectedTab) { selectedTab in
            canGoBack = selectedTab?.canGoBack ?? false
            canGoForward = selectedTab?.canGoForward ?? false
        }
        .onReceive(Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()) { _ in
            let newCanGoBack = tabManager.selectedTab?.canGoBack ?? false
            let newCanGoForward = tabManager.selectedTab?.canGoForward ?? false
            if newCanGoBack != canGoBack || newCanGoForward != canGoForward {
                canGoBack = newCanGoBack
                canGoForward = newCanGoForward
            }
        }
    }
    
    private var searchBar: some View {
        Button {
            withAnimation {
                uiViewModel.showCommandBar.toggle()
            }
        } label: {
            HStack {
                if hoverSearch {
                    Image(systemName: tabManager.selectedTab?.url != nil ? "lock.fill" : "magnifyingglass")
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundStyle(uiViewModel.textColor.opacity(0.5))
                    
                    Text(hoverSearch ? (tabManager.selectedTab?.url?.absoluteString ?? "Search or Enter URL") : "")
                        .lineLimit(1)
                        .foregroundStyle(uiViewModel.textColor.opacity(0.5))
                    
                    Spacer()
                } else {
                    Spacer()
                    Image(systemName: "magnifyingglass")
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundStyle(uiViewModel.textColor.opacity(0.5))
                    Spacer()
                }
            }
            .padding(.horizontal, 15)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white.opacity(hoverSearch ? 0.25 : 0.15))
            )
            .onHover { hovering in
                withAnimation {
                    hoverSearch = hovering
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }
    
    private var pinnedTabsSection: some View {
        Group {
            let pinnedTabs = tabManager.tabs.filter { $0.isPinned }
            if !pinnedTabs.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 12))
                            .foregroundColor(uiViewModel.textColor.opacity(0.7))
                        Text("Pinned")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(uiViewModel.textColor)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    
                    ForEach(pinnedTabs) { tab in
                        TabRowView(
                            tab: tab,
                            isSelected: tabManager.selectedTab?.id == tab.id,
                            textColor: uiViewModel.textColor,
                            onSelect: { tabManager.selectTab(tab) },
                            onClose: { tabManager.closeTab(tab) },
                            tabManager: tabManager
                        )
                    }
                }
            }
        }
    }
    
    private var tabGroupsSection: some View {
        ForEach(tabManager.tabGroups) { group in
            let groupTabs = tabManager.getTabsInGroup(group).filter { !$0.isPinned }
            if !settings.hideEmptyTabGroups || !groupTabs.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Circle()
                            .fill(group.color.color)
                            .frame(width: 8, height: 8)
                        Text(group.name)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(uiViewModel.textColor)
                        Spacer()
                        Text("\(groupTabs.count)")
                            .font(.caption)
                            .foregroundColor(uiViewModel.textColor.opacity(0.6))
                    }
                    .padding(.horizontal, 12)
                    
                    ForEach(groupTabs) { tab in
                        TabRowView(
                            tab: tab,
                            isSelected: tabManager.selectedTab?.id == tab.id,
                            textColor: uiViewModel.textColor,
                            groupColor: group.color.color,
                            onSelect: { tabManager.selectTab(tab) },
                            onClose: { tabManager.closeTab(tab) },
                            tabManager: tabManager
                        )
                    }
                }
            }
        }
    }
    
    private var newTabButton: some View {
        Button {
            uiViewModel.showCommandBar.toggle()
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .foregroundStyle(Color.white.opacity(uiViewModel.hoveringID == "newTab" ? 0.5 : 0.0))
                    .frame(height: 50)
                HStack {
                    Label("New Tab", systemImage: "plus")
                        .foregroundStyle(uiViewModel.textColor)
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .padding(.leading, 10)
                    Spacer()
                }
            }
            .foregroundStyle(uiViewModel.textColor)
            .onHover { hovering in
                withAnimation {
                    uiViewModel.hoveringID = hovering ? "newTab" : ""
                }
            }
        }
        .padding(.horizontal, 12)
    }
    
    private var ungroupedTabsSection: some View {
        Group {
            let ungroupedTabs = tabManager.getUngroupedTabs().filter { !$0.isPinned }
            if !ungroupedTabs.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    if !tabManager.tabs.filter({ $0.isPinned }).isEmpty || !tabManager.tabGroups.isEmpty {
                        HStack {
                            Text("Other Tabs")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(uiViewModel.textColor)
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                    }
                    
                    ForEach(ungroupedTabs) { tab in
                        TabRowView(
                            tab: tab,
                            isSelected: tabManager.selectedTab?.id == tab.id,
                            textColor: uiViewModel.textColor,
                            onSelect: { tabManager.selectTab(tab) },
                            onClose: { tabManager.closeTab(tab) },
                            tabManager: tabManager
                        )
                    }
                }
            }
        }
    }
    
    private var bottomControls: some View {
        HStack {
            Button(action: { uiViewModel.showSettings = true }) {
                buttonBackground(id: "settings", systemImage: "gearshape")
            }
            
            Spacer()
            
            Button(action: { showingNewGroupSheet = true }) {
                buttonBackground(id: "newGroup", systemImage: "folder.badge.plus")
            }
            
            Button(action: { showingBookmarks = true }) {
                buttonBackground(id: "bookmarks", systemImage: "bookmark.fill")
            }
            
            Button(action: { showingHistory = true }) {
                buttonBackground(id: "history", systemImage: "clock.arrow.circlepath")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .sheet(isPresented: $showingBookmarks) {
            BookmarksView(tabManager: tabManager)
        }
        .sheet(isPresented: $showingHistory) {
            HistoryView(tabManager: tabManager)
        }
        .sheet(isPresented: $showingNewGroupSheet) {
            NewTabGroupView(
                name: $newGroupName,
                color: $newGroupColor,
                onCancel: {
                    showingNewGroupSheet = false
                    newGroupName = ""
                    newGroupColor = .blue
                },
                onCreate: {
                    let trimmed = newGroupName.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        _ = tabManager.createTabGroup(name: trimmed, color: newGroupColor)
                    }
                    showingNewGroupSheet = false
                    newGroupName = ""
                    newGroupColor = .blue
                }
            )
        }
    }
    
    // MARK: - Helpers
    
    private func buttonBackground(id: String, systemImage: String) -> some View {
        ZStack {
            Color.white.opacity(uiViewModel.hoveringID == id ? 0.25 : 0.0)
            
            Image(systemName: systemImage)
                .resizable()
                .scaledToFit()
                .frame(width: 20, height: 20)
                .foregroundStyle(uiViewModel.textColor)
                .opacity(uiViewModel.hoveringID == id ? 1.0 : 0.5)
        }
        .frame(width: 40, height: 40)
        .cornerRadius(7)
        .onHover { hovering in
            withAnimation {
                uiViewModel.hoveringID = hovering ? id : ""
            }
        }
    }
    
    private var resizeDragGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .onChanged { value in
                if startWidth == nil {
                    startWidth = uiViewModel.sidebarWidth
                }
                
                let dragAmount = value.translation.width
                let multiplier: CGFloat = uiViewModel.sidebarPosition == "right" ? -1 : 1
                let newWidth = (startWidth ?? uiViewModel.sidebarWidth) + (dragAmount * multiplier)
                
                dragOffset = newWidth.clamped(to: 250...600) - uiViewModel.sidebarWidth
            }
            .onEnded { value in
                let dragAmount = value.translation.width
                let multiplier: CGFloat = uiViewModel.sidebarPosition == "right" ? -1 : 1
                let finalWidth = ((startWidth ?? uiViewModel.sidebarWidth) + (dragAmount * multiplier)).clamped(to: 250...600)
                
                uiViewModel.sidebarWidth = finalWidth
                dragOffset = 0
                startWidth = nil
            }
    }
}

// MARK: - Tab Row View

struct TabRowView: View {
    let tab: Tab
    let isSelected: Bool
    let textColor: Color
    var groupColor: Color?
    let onSelect: () -> Void
    let onClose: () -> Void
    @ObservedObject var tabManager: TabManager
    
    @State private var isHovering = false
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging: Bool = false
    @State private var showingNewGroupAlert = false
    @State private var newGroupName = ""
    @State private var newGroupColor: TabGroupColor = .blue
    
    private let swipeThreshold: CGFloat = 80
    private let actionButtonWidth: CGFloat = 70
    
    var body: some View {
        ZStack(alignment: .trailing) {
            // Background action buttons (revealed on swipe)
            actionButtons
            
            // Main tab row content
            tabRowContent
                .offset(x: dragOffset)
                .animation(.spring(response: 0.35, dampingFraction: 0.85, blendDuration: 0.25), value: dragOffset)
                .gesture(swipeGesture)
                .simultaneousGesture(tapGesture)
        }
        .padding(.horizontal, 12)
        .sheet(isPresented: $showingNewGroupAlert) {
            NewTabGroupView(
                name: $newGroupName,
                color: $newGroupColor,
                onCancel: {
                    handleResetGroupCreation()
                    showingNewGroupAlert = false
                },
                onCreate: {
                    handleCreateNewGroupAndAddTab()
                    showingNewGroupAlert = false
                    dragOffset = 0
                }
            )
        }
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private var actionButtons: some View {
        HStack(spacing: 0) {
            // Pin/Unpin button
            Button(action: {
                if tab.isPinned {
                    tabManager.requestUnpinTab(tab)
                } else {
                    tabManager.pinTab(tab)
                }
                withAnimation {
                    dragOffset = 0
                }
            }) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.accentColor)
                    Image(systemName: tab.isPinned ? "pin.slash.fill" : "pin.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 16, weight: .semibold))
                }
                .frame(width: actionButtonWidth, height: 44)
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel(tab.isPinned ? "Unpin Tab" : "Pin Tab")
            
            // Close/Delete button
            Button(action: {
                withAnimation {
                    onClose()
                }
            }) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.red)
                    Image(systemName: "xmark")
                        .foregroundColor(.white)
                        .font(.system(size: 16, weight: .semibold))
                }
                .frame(width: actionButtonWidth, height: 44)
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel("Close Tab")
        }
        .opacity(dragOffset < -20 ? 1.0 : 0.0)
    }
    
    @ViewBuilder
    private var tabRowContent: some View {
        Button(action: {
            if dragOffset == 0 {
                onSelect()
            }
        }) {
            HStack(spacing: 10) {
                // Favicon or placeholder
                if let url = tab.url {
                    AsyncImage(url: URL(string: "https://www.google.com/s2/favicons?domain=\(url.host ?? "")&sz=32")) { image in
                        image.resizable()
                    } placeholder: {
                        Image(systemName: "globe")
                            .foregroundColor(.gray)
                    }
                    .frame(width: 16, height: 16)
                } else {
                    Image(systemName: "globe")
                        .frame(width: 16, height: 16)
                        .foregroundColor(.gray)
                }
                
                // Pin indicator
                if tab.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.accentColor)
                }
                
                // Group color indicator
                if let groupColor = groupColor {
                    Circle()
                        .fill(groupColor)
                        .frame(width: 6, height: 6)
                }
                
                // Title
                Text(tab.title)
                    .font(.body)
                    .lineLimit(1)
                    .foregroundColor(textColor)
                
                Spacer()
                
                // Close button (visible on hover or selection)
                if (isHovering || isSelected) && dragOffset == 0 {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(textColor.opacity(0.7))
                            .frame(width: 20, height: 20)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(isSelected ? 0.25 : (isHovering ? 0.15 : 0.0)))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(
                                tab.browserEngine == .webkit ? Color.accentColor : .orange,
                                lineWidth: 1.5
                            )
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            isHovering = hovering
        }
        .contentShape(Rectangle())
        .contextMenu {
            contextMenuContent
        }
    }
    
    @ViewBuilder
    private var contextMenuContent: some View {
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
    
    // MARK: - Gestures
    
    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                let translation = value.translation.width
                // Only allow left swipe (negative offset)
                if translation < 0 {
                    withAnimation(.interactiveSpring()) {
                        dragOffset = translation
                        isDragging = true
                    }
                }
            }
            .onEnded { value in
                let translation = value.translation.width
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    if translation < -swipeThreshold {
                        // Snap to reveal buttons
                        dragOffset = -(actionButtonWidth * 2)
                    } else {
                        // Snap back
                        dragOffset = 0
                    }
                    isDragging = false
                }
            }
    }
    
    private var tapGesture: some Gesture {
        TapGesture()
            .onEnded { _ in
                if dragOffset != 0 {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        dragOffset = 0
                    }
                }
            }
    }
    
    // MARK: - Helpers
    
    private func handleCreateNewGroupAndAddTab() {
        let trimmedName = newGroupName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedName.isEmpty {
            let group = tabManager.createTabGroup(name: trimmedName, color: newGroupColor)
            tabManager.addTabToGroup(tab, group: group)
            handleResetGroupCreation()
        }
    }
    
    private func handleResetGroupCreation() {
        newGroupName = ""
        newGroupColor = .blue
    }
}
