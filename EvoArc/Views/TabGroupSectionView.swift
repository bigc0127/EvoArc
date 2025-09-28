//
//  TabGroupSectionView.swift
//  EvoArc
//
//  Created on 2025-09-28.
//

import SwiftUI

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
                        .font(.system(size: PlatformMetrics.iconSize(baseIconSize)))
                        .foregroundColor(.secondary)
                        .frame(width: PlatformMetrics.buttonSize(baseSize: 44, hasLabel: false), height: PlatformMetrics.buttonSize(baseSize: 44, hasLabel: false))
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: {
                    showingDeleteConfirmation = true
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: PlatformMetrics.iconSize(baseIconSize)))
                        .foregroundColor(.red)
                        .frame(width: PlatformMetrics.buttonSize(baseSize: 44, hasLabel: false), height: PlatformMetrics.buttonSize(baseSize: 44, hasLabel: false))
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 15)
            
            if !group.isCollapsed {
                LazyVGrid(columns: gridColumns, spacing: PlatformMetrics.scaledPadding(baseSpacing)) {
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