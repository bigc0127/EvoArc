//
//  PinnedTabDebugView.swift
//  EvoArc
//
//  Created on 2025-09-06.
//

import SwiftUI

struct PinnedTabDebugView: View {
    @ObservedObject private var hybridManager = HybridPinnedTabManager.shared
    @ObservedObject private var cloudKitManager = CloudKitPinnedTabManager.shared
    @ObservedObject private var safeManager = SafePinnedTabManager.shared
    
    var tabManager: TabManager?
    
    private var backgroundGray: Color {
        #if os(iOS)
        Color(UIColor.systemGray6)
        #else
        Color(NSColor.controlBackgroundColor)
        #endif
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Pinned Tabs Debug")
                .font(.headline)
            
            // Status section
            VStack(alignment: .leading, spacing: 8) {
                Text("Status")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                HStack {
                    Circle()
                        .fill(hybridManager.isUsingCloudKit ? .green : .orange)
                        .frame(width: 8, height: 8)
                    Text(hybridManager.getCurrentManagerStatus())
                        .font(.caption)
                }
                
                HStack {
                    Circle()
                        .fill(cloudKitManager.isReady ? .green : .red)
                        .frame(width: 8, height: 8)
                    Text("CloudKit Ready: \(cloudKitManager.isReady ? "Yes" : "No")")
                        .font(.caption)
                }
            }
            
            // Counts section
            VStack(alignment: .leading, spacing: 8) {
                Text("Tab Counts")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text("Pinned (Hybrid): \(hybridManager.pinnedTabs.count)")
                    .font(.caption)
                Text("Pinned (CloudKit): \(cloudKitManager.pinnedTabs.count)")
                    .font(.caption)
                Text("Pinned (Safe): \(safeManager.pinnedTabs.count)")
                    .font(.caption)
            }
            
            // Tab Group Summary
            VStack(alignment: .leading, spacing: 8) {
                Text("Tab Groups (Local)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                if let tabManager = tabManager, !tabManager.tabGroups.isEmpty {
                    Text("Groups: \(tabManager.tabGroups.count)")
                        .font(.caption)
                    ForEach(tabManager.tabGroups) { group in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(group.color.color)
                                .frame(width: 10, height: 10)
                            Text(group.name)
                                .font(.caption)
                            Spacer()
                            Text("\(tabManager.getTabsInGroup(group).count) tabs")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } else {
                    Text("No groups")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Pinned tabs list
            if !hybridManager.pinnedTabs.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Pinned Tabs")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    ForEach(hybridManager.pinnedTabs) { entity in
                        HStack {
                            Image(systemName: "pin.fill")
                                .foregroundColor(.accentColor)
                                .font(.caption)
                            Text(entity.title)
                                .font(.caption)
                            Spacer()
                            Text("\(entity.pinnedOrder)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding()
        .background(backgroundGray)
        .cornerRadius(12)
    }
}

#Preview {
    PinnedTabDebugView()
}
