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
            }
            .frame(height: geometry.size.height + geometry.safeAreaInsets.bottom)
            .ignoresSafeArea(.container, edges: .bottom)
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
        RoundedRectangle(cornerRadius: PlatformMetrics.scaledPadding(2.5))
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
                    .font(.system(size: PlatformMetrics.iconSize(16)))
                    .foregroundColor(.accentColor)
                    .frame(width: PlatformMetrics.buttonSize(baseSize: 44, hasLabel: false), height: PlatformMetrics.buttonSize(baseSize: 44, hasLabel: false))
                    .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            
            Button(action: {
                showingBookmarks = true
            }) {
                Image(systemName: "bookmark.fill")
                    .font(.system(size: PlatformMetrics.iconSize(16)))
                    .foregroundColor(.accentColor)
                    .frame(width: PlatformMetrics.buttonSize(baseSize: 44, hasLabel: false), height: PlatformMetrics.buttonSize(baseSize: 44, hasLabel: false))
                    .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            
            Button(action: {
                showingCreateGroupSheet = true
            }) {
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: PlatformMetrics.iconSize(18)))
                    .foregroundColor(.accentColor)
                    .frame(width: PlatformMetrics.buttonSize(baseSize: 44, hasLabel: false), height: PlatformMetrics.buttonSize(baseSize: 44, hasLabel: false))
                    .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            
            Button(action: {
                tabManager.createNewTab()
            }) {
                Image(systemName: "plus")
                    .font(.system(size: PlatformMetrics.iconSize(20)))
                    .foregroundColor(.accentColor)
                    .frame(width: PlatformMetrics.buttonSize(baseSize: 44, hasLabel: false), height: PlatformMetrics.buttonSize(baseSize: 44, hasLabel: false))
                    .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
        }
        .scaledPadding(.horizontal, 20)
        .scaledPadding(.bottom, 10)
    }
    
    @ViewBuilder
    private var tabsGrid: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: PlatformMetrics.scaledPadding(20))
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