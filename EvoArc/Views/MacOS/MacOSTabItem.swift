//
//  MacOSTabItem.swift
//  EvoArc
//
//  Created on 2025-09-28.
//

import SwiftUI

#if os(macOS)

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

#endif