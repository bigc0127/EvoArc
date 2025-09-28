//
//  MacOSTabGroup.swift
//  EvoArc
//
//  Created on 2025-09-28.
//

import SwiftUI

#if os(macOS)

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

#endif