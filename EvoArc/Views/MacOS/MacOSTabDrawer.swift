//
//  MacOSTabDrawer.swift
//  EvoArc
//
//  Created on 2025-09-28.
//

import SwiftUI

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

#endif