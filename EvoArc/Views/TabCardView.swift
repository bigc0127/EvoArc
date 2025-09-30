//
//  TabCardView.swift
//  EvoArc
//
//  Created on 2025-09-05.
//

import SwiftUI

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
                    .font(.system(size: PlatformMetrics.iconSize(12)))
                    .foregroundColor(.accentColor)
                    .scaledFrame(width: baseHeaderIconSize, height: baseHeaderIconSize)
            } else {
                Image(systemName: "globe")
                    .font(.system(size: PlatformMetrics.iconSize(14)))
                    .foregroundColor(.secondary)
                    .scaledFrame(width: baseHeaderIconSize, height: baseHeaderIconSize)
            }
            
            Text(tab.title)
                .font(.system(size: PlatformMetrics.iconSize(14), weight: .medium))
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
                .font(.system(size: PlatformMetrics.iconSize(12)))
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
                    RoundedRectangle(cornerRadius: PlatformMetrics.scaledPadding(8))
                        .fill(Color.gray.opacity(0.1))
                )
                .clipShape(RoundedRectangle(cornerRadius: PlatformMetrics.scaledPadding(8)))
        }
        .frame(height: PlatformMetrics.maxDimension(basePreviewHeight))
    }
}

// MARK: - Extension
private extension TabCardView {
    var faviconBadge: some View {
        // Compute the fallback initial exactly like the current implementation
        let letter: String = {
            guard let host = tab.url?.host else { return " " }
            let parts = host.split(separator: ".")
            let core = parts.dropLast().last ?? parts.last ?? Substring(host)
            return String(core.prefix(1)).uppercased()
        }()
        
        return ZStack {
            // Background circle with engine-specific border (unchanged)
            Circle()
                #if os(iOS)
                .fill(Color(UIColor.systemBackground))
                #else
                .fill(Color(NSColor.windowBackgroundColor))
                #endif
                .overlay(
                    Circle()
                        .strokeBorder(tab.browserEngine == .webkit ? Color.accentColor : .orange,
                                    lineWidth: 1.5)
                )
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                .frame(width: 32, height: 32)
            
            // New favicon view with fallback initial
            FaviconBadgeView(url: tab.url, fallbackLetter: letter, size: 20)
        }
    }
    
    var engineIndicatorBadge: some View {
        Text(tab.browserEngine == .webkit ? "S" : "C")
            .font(.system(size: PlatformMetrics.iconSize(10), weight: .medium))
            .foregroundColor(.white)
            .scaledFrame(width: 20, height: 20)
            .background(
                Circle()
                    .fill(tab.browserEngine == .webkit ? Color.blue.opacity(0.8) : Color.orange.opacity(0.8))
            )
    }
    
    var cardBackground: some View {
        RoundedRectangle(cornerRadius: TabCardStyleConfiguration.cornerRadius)
            .fill(systemBackgroundColor)
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
                        .font(.system(size: PlatformMetrics.iconSize(20)))
                        .foregroundColor(.secondary)
                        .scaledFrame(width: PlatformMetrics.buttonSize(baseSize: 44, hasLabel: false), height: PlatformMetrics.buttonSize(baseSize: 44, hasLabel: false))
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