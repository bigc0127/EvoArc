//
//  TabDrawerView.swift
//  EvoArc
//
//  Created on 2025-09-04.
//

import SwiftUI
#if os(iOS)
import UIKit
#else
import AppKit
#endif

struct TabDrawerView: View {
    @ObservedObject var tabManager: TabManager
    @StateObject private var settings = BrowserSettings.shared
    @StateObject private var bookmarkManager = BookmarkManager.shared
    @Namespace private var animationNamespace
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showingCreateGroupSheet = false
    @State private var newGroupName = ""
    @State private var newGroupColor: TabGroupColor = .blue
    @State private var showingBookmarks = false
    
    // Constants for base sizes that will be dynamically scaled
    private let baseHandleHeight: CGFloat = 5
    private let baseHandleWidth: CGFloat = 40
    private let baseIconSize: CGFloat = 18
    private let baseSpacing: CGFloat = 15
    private let baseCornerRadius: CGFloat = 20
    private let glassOpacity: CGFloat = 0.7
    
    private var systemBackgroundColor: Color {
        .appBackground
    }
    
    private var secondarySystemBackgroundColor: Color {
        .cardBackground
    }
    
    var body: some View {
        VStack(spacing: 0) {
            drawerHandle
            headerSection
            tabsGrid
        }
        .background(drawerBackground)
        .modifier(PlatformCornerRadius())
            .themeShadow()
        .sheet(isPresented: $showingCreateGroupSheet) {
            NewTabGroupView(
                name: $newGroupName,
                color: $newGroupColor,
                onCancel: {
                    showingCreateGroupSheet = false
                    newGroupName = ""
                    newGroupColor = .blue
                },
                onCreate: {
                    let trimmed = newGroupName.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        _ = tabManager.createTabGroup(name: trimmed, color: newGroupColor)
                    }
                    showingCreateGroupSheet = false
                    newGroupName = ""
                    newGroupColor = .blue
                }
            )
            #if os(macOS)
            .frame(minWidth: 420, minHeight: 360)
            #endif
        }
.sheet(isPresented: $showingBookmarks) {
            BookmarksView(tabManager: tabManager)
            #if os(macOS)
                .frame(minWidth: 820, minHeight: 600)
            #endif
        }
        .confirmationDialog(
            "Unpin Tab",
            isPresented: $tabManager.showUnpinConfirmation,
            titleVisibility: .visible
        ) {
            Button("Unpin", role: .destructive) {
                tabManager.confirmUnpinTab()
            }
            Button("Cancel", role: .cancel) {
                tabManager.cancelUnpinTab()
            }
        } message: {
            Text("Are you sure you want to unpin this tab? It will remain open but no longer be pinned.")
        }
    }
    
    @ViewBuilder
    private var drawerHandle: some View {
        RoundedRectangle(cornerRadius: UIScaleMetrics.scaledPadding(2.5))
            .fill(Color.secondaryLabel)
            .scaledFrame(width: baseHandleWidth, height: baseHandleHeight)
            .scaledPadding(.top, 8)
            .scaledPadding(.bottom, 12)
    }
    
    @ViewBuilder
    private var headerSection: some View {
        HStack {
            Text("\(tabManager.tabs.count) \(tabManager.tabs.count == 1 ? "Tab" : "Tabs")")
                .font(.headline)
                .foregroundColor(.primaryLabel)
                .dynamicTypeSize(...DynamicTypeSize.accessibility3)
            
            if !tabManager.tabGroups.isEmpty {
                Text("• \(tabManager.tabGroups.count) \(tabManager.tabGroups.count == 1 ? "Group" : "Groups")")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .dynamicTypeSize(...DynamicTypeSize.accessibility3)
            }
            
            Spacer()
            
            Button(action: {
                showingBookmarks = true
            }) {
                Image(systemName: "bookmark.fill")
                    .font(.system(size: UIScaleMetrics.iconSize(16)))
                    .foregroundColor(.accentColor)
.frame(width: UIScaleMetrics.buttonSize(baseSize: 44, hasLabel: false), height: UIScaleMetrics.buttonSize(baseSize: 44, hasLabel: false))
            }
            .buttonStyle(PlainButtonStyle())
            
            Button(action: {
                showingCreateGroupSheet = true
            }) {
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: UIScaleMetrics.iconSize(18)))
                    .foregroundColor(.accentColor)
                    .frame(width: UIScaleMetrics.buttonSize(baseSize: 44, hasLabel: false), height: UIScaleMetrics.buttonSize(baseSize: 44, hasLabel: false))
            }
            .buttonStyle(PlainButtonStyle())
            
            Button(action: {
                tabManager.createNewTab()
            }) {
                Image(systemName: "plus")
                    .font(.system(size: UIScaleMetrics.iconSize(20)))
                    .foregroundColor(.accentColor)
                    .frame(width: UIScaleMetrics.buttonSize(baseSize: 44, hasLabel: false), height: UIScaleMetrics.buttonSize(baseSize: 44, hasLabel: false))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .scaledPadding(.horizontal, 20)
        .scaledPadding(.bottom, 10)
    }
    
    @ViewBuilder
    private var tabsGrid: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: UIScaleMetrics.scaledPadding(20)) {
                // Pinned tabs section
                let pinnedTabs = tabManager.tabs.filter { $0.isPinned }
                if !pinnedTabs.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.accentColor)
                            Text("Pinned")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        .padding(.horizontal, 15)
                        
                        LazyVGrid(columns: gridColumns, spacing: 15) {
                            ForEach(pinnedTabs) { tab in
                                tabCardView(for: tab)
                            }
                        }
                        .padding(.horizontal, 15)
                    }
                }
                
                // Tab groups sections
                ForEach(tabManager.tabGroups) { group in
                    let groupTabs = tabManager.getTabsInGroup(group).filter { !$0.isPinned }
                    if !settings.hideEmptyTabGroups || !groupTabs.isEmpty {
                        TabGroupSectionView(
                            group: group,
                            tabs: groupTabs,
                            tabManager: tabManager,
                            gridColumns: gridColumns
                        ) { tab in
                            tabCardView(for: tab)
                        }
                    }
                }
                
                // Ungrouped tabs section
                let ungroupedTabs = tabManager.getUngroupedTabs().filter { !$0.isPinned }
                if !ungroupedTabs.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        if (!pinnedTabs.isEmpty || !tabManager.tabGroups.isEmpty) {
                            HStack {
                                Text("Other Tabs")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                            .padding(.horizontal, 15)
                        }
                        
                        LazyVGrid(columns: gridColumns, spacing: 15) {
                            ForEach(ungroupedTabs) { tab in
                                tabCardView(for: tab)
                            }
                        }
                        .padding(.horizontal, 15)
                    }
                }
            }
            .padding(.bottom, 20)
        }
    }
    
    @ViewBuilder
    private func tabCardView(for tab: Tab) -> some View {
        TabCardView(
            tab: tab,
            isSelected: tabManager.selectedTab?.id == tab.id,
            onSelect: {
                tabManager.selectTab(tab)
            },
            onClose: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    tabManager.closeTab(tab)
                }
            },
            tabManager: tabManager
        )
        .matchedGeometryEffect(id: tab.id, in: animationNamespace)
        .id(tab.id)
    }
    
    private var gridColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: UIScaleMetrics.scaledPadding(baseSpacing)),
            GridItem(.flexible(), spacing: UIScaleMetrics.scaledPadding(baseSpacing))
        ]
    }
    
    @ViewBuilder
    private var drawerBackground: some View {
        #if os(iOS)
        if #available(iOS 26.0, *) {
            ZStack {
                Rectangle()
                    .fill(.ultraThinMaterial)
                GlassBackgroundView(style: colorScheme == .dark ? .dark : .light)
                    .opacity(glassOpacity)
            }
        } else {
            systemBackgroundColor
        }
        #else
        systemBackgroundColor
        #endif
    }
    
    // Legacy createGroupSheet removed. Using NewTabGroupView instead.
    /* Removed legacy UI */
}

struct TabGroupSectionView<TabCard: View>: View {
    @ObservedObject var group: TabGroup
    let tabs: [Tab]
    let tabManager: TabManager
    let gridColumns: [GridItem]
    @ViewBuilder let tabCardView: (Tab) -> TabCard
    
    // Constants for base sizes that will be dynamically scaled
    private let baseColorIndicatorSize: CGFloat = 12
    private let baseIconSize: CGFloat = 12
    private let baseSpacing: CGFloat = 15
    
    @State private var showingDeleteConfirmation = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Circle()
                    .fill(group.color.color)
                    .scaledFrame(width: baseColorIndicatorSize, height: baseColorIndicatorSize)
                
                Text(group.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .dynamicTypeSize(...DynamicTypeSize.accessibility3)
                
                Text("(\(tabs.count))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .dynamicTypeSize(...DynamicTypeSize.accessibility3)
                
                Spacer()
                
                Button(action: {
                    withAnimation(.spring()) {
                        group.update(isCollapsed: !group.isCollapsed)
                    }
                }) {
                    Image(systemName: group.isCollapsed ? "chevron.right" : "chevron.down")
                        .font(.system(size: UIScaleMetrics.iconSize(baseIconSize)))
                        .foregroundColor(.secondary)
.frame(width: UIScaleMetrics.buttonSize(baseSize: 44, hasLabel: false), height: UIScaleMetrics.buttonSize(baseSize: 44, hasLabel: false))
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: {
                    showingDeleteConfirmation = true
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: UIScaleMetrics.iconSize(baseIconSize)))
                        .foregroundColor(.red)
                        .frame(width: UIScaleMetrics.buttonSize(baseSize: 44, hasLabel: false), height: UIScaleMetrics.buttonSize(baseSize: 44, hasLabel: false))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 15)
            
            if !group.isCollapsed {
                LazyVGrid(columns: gridColumns, spacing: UIScaleMetrics.scaledPadding(baseSpacing)) {
                    ForEach(tabs) { tab in
                        tabCardView(tab)
                    }
                }
                .padding(.horizontal, 15)
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

struct PlatformCornerRadius: ViewModifier {
    func body(content: Content) -> some View {
        #if os(iOS)
        content.cornerRadius(20, corners: [.topLeft, .topRight])
        #else
        content.cornerRadius(20)
        #endif
    }
}

struct TabCardView: View {
    let tab: Tab
    let isSelected: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
    let tabManager: TabManager
    
    // Constants for base sizes that will be dynamically scaled
    private let baseHeaderIconSize: CGFloat = 14
    private let baseCloseButtonSize: CGFloat = 20
    private let basePreviewHeight: CGFloat = 100
    private let baseCornerRadius: CGFloat = 12
    
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging: Bool = false
    @State private var showingNewGroupAlert = false
    @State private var newGroupName = ""
    @State private var newGroupColor: TabGroupColor = .blue
    
    private let swipeThreshold: CGFloat = 80
    
    private var systemBackgroundColor: Color {
        #if os(iOS)
        Color(UIColor.systemBackground)
        #else
        Color(NSColor.controlBackgroundColor)
        #endif
    }
    
    private var secondarySystemBackgroundColor: Color {
        #if os(iOS)
        Color(UIColor.secondarySystemBackground)
        #else
        Color(NSColor.controlBackgroundColor)
        #endif
    }
    
    @ViewBuilder
    private var contextMenu: some View {
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
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            cardContent
            closeButtonOverlay
        }
        .background(deleteIndicatorBackground)
        .offset(x: dragOffset)
        .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.8, blendDuration: 0), value: dragOffset)
        .simultaneousGesture(dragGesture)
        .sheet(isPresented: $showingNewGroupAlert) {
            NewTabGroupView(
                name: $newGroupName,
                color: $newGroupColor,
                onCancel: {
                    resetGroupCreation()
                    showingNewGroupAlert = false
                },
                onCreate: {
                    createNewGroupAndAddTab()
                    showingNewGroupAlert = false
                }
            )
            #if os(macOS)
            .frame(minWidth: 400, minHeight: 320)
            #endif
        }
    }
    
    @ViewBuilder
    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            headerRow
            urlText
            previewPlaceholder
        }
        .padding(12)
        .background(cardBackground)
        .onTapGesture {
            if !isDragging {
                onSelect()
            }
        }
        .contextMenu {
            contextMenu
        }
    }
    
    @ViewBuilder
    private var headerRow: some View {
        HStack(spacing: 8) {
            if tab.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: UIScaleMetrics.iconSize(12)))
                    .foregroundColor(.accentColor)
                    .scaledFrame(width: baseHeaderIconSize, height: baseHeaderIconSize)
            } else {
                Image(systemName: "globe")
                    .font(.system(size: UIScaleMetrics.iconSize(14)))
                    .foregroundColor(.secondary)
                    .scaledFrame(width: baseHeaderIconSize, height: baseHeaderIconSize)
            }
            
            Text(tab.title)
                .font(.system(size: UIScaleMetrics.iconSize(14), weight: .medium))
                .lineLimit(1)
                .foregroundColor(.primary)
                .dynamicTypeSize(...DynamicTypeSize.accessibility3)
            
            Spacer()
            engineIndicatorBadge
        }
    }
    
    @ViewBuilder
    private var urlText: some View {
        if let url = tab.url {
            Text(url.host ?? url.absoluteString)
                .font(.system(size: UIScaleMetrics.iconSize(12)))
                .foregroundColor(.secondaryLabel)
                .lineLimit(1)
                .dynamicTypeSize(...DynamicTypeSize.accessibility3)
        }
    }
    
    @ViewBuilder
    private var previewPlaceholder: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.gray.opacity(0.1))
            .scaledFrame(height: basePreviewHeight)
            .overlay(
                Image(systemName: "doc.text")
                    .font(.system(size: UIScaleMetrics.iconSize(30)))
                    .foregroundColor(.gray.opacity(0.3))
            )
    }
    
    @ViewBuilder
    private var engineIndicatorBadge: some View {
        Text(tab.browserEngine == .webkit ? "S" : "C")
            .font(.system(size: UIScaleMetrics.iconSize(10), weight: .bold))
            .foregroundColor(.white)
            .scaledFrame(width: 16, height: 16)
            .background(
                Circle()
                    .fill(tab.browserEngine == .webkit ? Color.blue : Color.orange)
            )
    }
    
    @ViewBuilder
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: UIScaleMetrics.scaledPadding(baseCornerRadius))
            .fill(secondarySystemBackgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: UIScaleMetrics.scaledPadding(baseCornerRadius))
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
    }
    
    @ViewBuilder
    private var closeButtonOverlay: some View {
        if abs(dragOffset) < 10 {
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: UIScaleMetrics.iconSize(baseCloseButtonSize)))
                    .foregroundColor(.secondary)
                    .scaledFrame(width: UIScaleMetrics.buttonSize(baseSize: 44, hasLabel: false), height: UIScaleMetrics.buttonSize(baseSize: 44, hasLabel: false))
                    .background(Circle().fill(systemBackgroundColor))
            }
            .offset(x: 5, y: -5)
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.2), value: dragOffset)
        }
    }
    
    @ViewBuilder
    private var deleteIndicatorBackground: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                if dragOffset > 0 {
                    deleteIndicator(alignment: .leading)
                } else if dragOffset < 0 {
                    deleteIndicator(alignment: .trailing)
                }
            }
            .cornerRadius(12)
        }
    }
    
    @ViewBuilder
    private func deleteIndicator(alignment: Alignment) -> some View {
        Color.red.opacity(min(Double(abs(dragOffset) / swipeThreshold), 1.0))
            .overlay(
                Image(systemName: "trash.fill")
                    .foregroundColor(.white)
                    .font(.system(size: 24))
                    .frame(width: 60, alignment: .center),
                alignment: alignment
            )
    }
    
    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 20)
            .onChanged { value in
                withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 1, blendDuration: 0)) {
                    dragOffset = value.translation.width
                    isDragging = true
                }
            }
            .onEnded { value in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    if abs(value.translation.width) > swipeThreshold {
                        // Close the tab
                        dragOffset = value.translation.width > 0 ? 300 : -300
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            onClose()
                        }
                    } else {
                        // Snap back
                        dragOffset = 0
                        isDragging = false
                    }
                }
            }
    }
    
    // Legacy newGroupSheet removed. Using NewTabGroupView instead.
    /* Removed legacy UI */
    
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
}

#if os(iOS)
// Extension for rounded corners
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
#endif
