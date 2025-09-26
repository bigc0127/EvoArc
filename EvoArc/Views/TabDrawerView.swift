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
    @State private var showingHistory = false
    
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
        GeometryReader { geometry in
            VStack(spacing: 0) {
                drawerHandle
                headerSection
                tabsGrid
                Spacer(minLength: 0)
            }
            .frame(maxHeight: geometry.size.height)
            .edgesIgnoringSafeArea(.bottom)
            .background(drawerBackground)
            .modifier(PlatformCornerRadius())
            .themeShadow()
        }
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
        .sheet(isPresented: $showingHistory) {
            HistoryView(tabManager: tabManager)
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
                showingHistory = true
            }) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: UIScaleMetrics.iconSize(16)))
                    .foregroundColor(.accentColor)
                    .frame(width: UIScaleMetrics.buttonSize(baseSize: 44, hasLabel: false), height: UIScaleMetrics.buttonSize(baseSize: 44, hasLabel: false))
            }
            .buttonStyle(PlainButtonStyle())
            
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
            .padding(.bottom, 0)
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
            GridItem(.flexible(), spacing: 20),
            GridItem(.flexible(), spacing: 20)
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

struct TabCardStyleConfiguration {
    static let cornerRadius: CGFloat = 20
    static let contentPadding: CGFloat = 16
    static let elementSpacing: CGFloat = 12
    static let shadowRadius: CGFloat = 8
    static let shadowOpacity: Float = 0.12
    static let shadowOffset = CGSize(width: 0, height: 2)
    static let borderWidth: CGFloat = 0.5
    static let borderOpacity: CGFloat = 0.1
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
                .frame(width: 400, height: 600)
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
        ZStack {
            cardContent
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
                    handleResetGroupCreation()
                    showingNewGroupAlert = false
                },
                onCreate: {
                    handleCreateNewGroupAndAddTab()
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
        ZStack(alignment: .bottom) {
            // Thumbnail at the top
            VStack(spacing: 0) {
                TabThumbnailView(tab: tab)
                    .frame(maxWidth: .infinity)
                    .frame(height: 200) // Increased to 200pt for perfect portrait look
                    .aspectRatio(3/4, contentMode: .fill) // Portrait aspect ratio
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 3)
                    .padding(.horizontal, 6)
                    .padding(.top, 6)
                
                Spacer(minLength: 48) // Space for favicon
            }
            
            // Favicon overlaid at the bottom
            faviconBadge
                .padding(.bottom, 12)
        }
        .onTapGesture {
            if !isDragging {
                onSelect()
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isDragging)
        .contentShape(Rectangle())
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
        GeometryReader { geo in
            TabThumbnailView(tab: tab)
                .frame(width: geo.size.width, height: geo.size.width * 9/16)
                .clipped()
                .background(
                    RoundedRectangle(cornerRadius: UIScaleMetrics.scaledPadding(8))
                        .fill(Color.gray.opacity(0.1))
                )
                .clipShape(RoundedRectangle(cornerRadius: UIScaleMetrics.scaledPadding(8)))
        }
        .frame(height: UIScaleMetrics.maxDimension(basePreviewHeight))
    }
    }

private extension TabCardView {
    var faviconBadge: some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                .frame(width: 32, height: 32)
            
            if let url = tab.url?.host, let domain = url.split(separator: ".").dropLast().last {
                Text(domain.prefix(1).uppercased())
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
            } else {
                Image(systemName: "globe")
                    .font(.system(size: 14))
                    .foregroundColor(.primary)
            }
        }
        .frame(height: 32)
    }
    
    var engineIndicatorBadge: some View {
        Text(tab.browserEngine == .webkit ? "S" : "C")
            .font(.system(size: UIScaleMetrics.iconSize(10), weight: .medium))
            .foregroundColor(.white)
            .scaledFrame(width: 20, height: 20)
            .background(
                Circle()
                    .fill(tab.browserEngine == .webkit ? Color.blue.opacity(0.8) : Color.orange.opacity(0.8))
            )
    }
    
    var cardBackground: some View {
        RoundedRectangle(cornerRadius: TabCardStyleConfiguration.cornerRadius)
            .fill(Color(UIColor.systemBackground))
            .shadow(
                color: Color.black.opacity(Double(TabCardStyleConfiguration.shadowOpacity)),
                radius: TabCardStyleConfiguration.shadowRadius,
                x: TabCardStyleConfiguration.shadowOffset.width,
                y: TabCardStyleConfiguration.shadowOffset.height
            )
            .overlay(
                RoundedRectangle(cornerRadius: TabCardStyleConfiguration.cornerRadius)
                    .stroke(Color.separator.opacity(TabCardStyleConfiguration.borderOpacity),
                           lineWidth: TabCardStyleConfiguration.borderWidth)
            )
            .overlay(selectionIndicator)
    }
    
    @ViewBuilder
    private var selectionIndicator: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: TabCardStyleConfiguration.cornerRadius)
                .stroke(Color.accentColor, lineWidth: 2)
                .allowsHitTesting(false)
        }
    }
    
    var closeButtonOverlay: some View {
        Group {
            if abs(dragOffset) < 10 {
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: UIScaleMetrics.iconSize(20)))
                        .foregroundColor(.secondary)
                        .scaledFrame(width: UIScaleMetrics.buttonSize(baseSize: 44, hasLabel: false), height: UIScaleMetrics.buttonSize(baseSize: 44, hasLabel: false))
                        .background(Circle().fill(systemBackgroundColor))
                }
                .offset(x: 5, y: -5)
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.2), value: dragOffset)
            }
        }
    }
    
    var deleteIndicatorBackground: some View {
        GeometryReader { _ in
            HStack(spacing: 0) {
                if dragOffset > 0 {
                    leadingDeleteIndicator
                } else if dragOffset < 0 {
                    trailingDeleteIndicator
                }
            }
            .cornerRadius(12)
        }
    }
    
    var leadingDeleteIndicator: some View {
        Color.red.opacity(min(Double(abs(dragOffset) / swipeThreshold), 1.0))
            .overlay(
                Image(systemName: "trash.fill")
                    .foregroundColor(.white)
                    .font(.system(size: 24))
                    .frame(width: 60, alignment: .center),
                alignment: .leading
            )
    }
    
    var trailingDeleteIndicator: some View {
        Color.red.opacity(min(Double(abs(dragOffset) / swipeThreshold), 1.0))
            .overlay(
                Image(systemName: "trash.fill")
                    .foregroundColor(.white)
                    .font(.system(size: 24))
                    .frame(width: 60, alignment: .center),
                alignment: .trailing
            )
    }
    
    var dragGesture: some Gesture {
        DragGesture(minimumDistance: 20)
            .onChanged { [self] value in
                let width = value.translation.width
                let isMoving = true
                withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 1, blendDuration: 0)) {
                    self.dragOffset = width
                    self.isDragging = isMoving
                }
            }
            .onEnded { [self] value in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    if abs(value.translation.width) > swipeThreshold {
                        // Close the tab
                        self.dragOffset = value.translation.width > 0 ? 300 : -300
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            onClose()
                        }
                    } else {
                        // Snap back
                        self.dragOffset = 0
                        self.isDragging = false
                    }
                }
            }
    }
    
    func handleCreateNewGroupAndAddTab() {
        let trimmedName = newGroupName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedName.isEmpty {
            let group = tabManager.createTabGroup(name: trimmedName, color: newGroupColor)
            tabManager.addTabToGroup(tab, group: group)
            handleResetGroupCreation()
        }
    }
    
    func handleResetGroupCreation() {
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
