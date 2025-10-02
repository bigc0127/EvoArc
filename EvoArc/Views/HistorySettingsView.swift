import SwiftUI

/// A view component for managing browser history settings and displaying history entries
struct HistorySettingsView: View {
    @StateObject private var historyManager = HistoryManager.shared
    @State private var showingHistory = false
    @State private var searchText = ""
    @State private var showingClearConfirmation = false
    @State private var selectedTimeRange: TimeRange = .all
    @State private var showingDeleteEntryConfirmation: HistoryEntry?
    
    // Optional TabManager reference for opening history items
    var tabManager: TabManager?
    
    // Time range options for clearing history
    enum TimeRange: String, CaseIterable, Identifiable {
        case hour = "Last Hour"
        case day = "Last 24 Hours"
        case week = "Last Week"
        case month = "Last Month"
        case all = "All Time"
        
        var id: String { rawValue }
        
        var date: Date {
            let now = Date()
            switch self {
            case .hour:
                return Calendar.current.date(byAdding: .hour, value: -1, to: now) ?? now
            case .day:
                return Calendar.current.date(byAdding: .day, value: -1, to: now) ?? now
            case .week:
                return Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now
            case .month:
                return Calendar.current.date(byAdding: .month, value: -1, to: now) ?? now
            case .all:
                return Date.distantPast
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // History stats
            historyStats
            
            // Actions
            historyActions
            
            // History list (if showing)
            if showingHistory {
                VStack(alignment: .leading, spacing: 8) {
                    // Search field
                    
                    // History list
                    ScrollView {
                        LazyVStack(spacing: 4) {
                            let entries = searchText.isEmpty ? historyManager.recentHistory : historyManager.searchHistory(searchText)
                            
                            ForEach(entries) { entry in
                                HistoryEntryRow(
                                    entry: entry,
                                    onRemove: { showingDeleteEntryConfirmation = entry },
                                    onTap: { openHistoryEntry(entry) }
                                )
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                
                                if entry.id != entries.last?.id {
                                    Divider()
                                }
                            }
                        }
                    }
                    .frame(height: 300)
                }
            }
        }
        // Clear history confirmation
        .confirmationDialog(
            "Clear Browsing History",
            isPresented: $showingClearConfirmation,
            titleVisibility: .visible
        ) {
            ForEach(TimeRange.allCases) { range in
                Button(range.rawValue) {
                    if range == .all {
                        historyManager.clearHistory()
                    } else {
                        historyManager.clearHistory(olderThan: range.date)
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone.")
        }
        // Delete entry confirmation
        .confirmationDialog(
            "Remove History Entry",
            isPresented: .init(
                get: { showingDeleteEntryConfirmation != nil },
                set: { if !$0 { showingDeleteEntryConfirmation = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let entry = showingDeleteEntryConfirmation {
                Button("Remove", role: .destructive) {
                    historyManager.removeEntry(entry)
                    showingDeleteEntryConfirmation = nil
                }
                Button("Cancel", role: .cancel) {
                    showingDeleteEntryConfirmation = nil
                }
            }
        } message: {
            if let entry = showingDeleteEntryConfirmation {
                Text("\(entry.title)\n\(entry.url.absoluteString)")
            }
        }
    }
    
    private var historyStats: some View {
        let stats = historyManager.getHistoryStats()
        
        return VStack(alignment: .leading, spacing: 4) {
            Text("History Statistics")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            HStack(spacing: 16) {
                StatView(
                    title: "Total Sites",
                    value: "\(stats.totalEntries)",
                    icon: "globe"
                )
                
                StatView(
                    title: "Total Visits",
                    value: "\(stats.totalVisits)",
                    icon: "arrow.forward"
                )
                
                if let oldest = stats.oldestEntry {
                    StatView(
                        title: "Since",
                        value: oldest.formatted(.dateTime.month().year()),
                        icon: "calendar"
                    )
                }
            }
        }
    }
    
    private var historyActions: some View {
        HStack(spacing: 12) {
            Button(action: { showingHistory.toggle() }) {
                Label(showingHistory ? "Hide History" : "View History", systemImage: showingHistory ? "eye.slash" : "eye")
            }
            .buttonStyle(.bordered)
            
            Button(action: { showingClearConfirmation = true }) {
                Label("Clear History", systemImage: "trash")
            }
            .buttonStyle(.bordered)
            .foregroundColor(.red)
        }
    }
    
    private func openHistoryEntry(_ entry: HistoryEntry) {
        guard let tabManager = tabManager else { return }
        tabManager.createNewTab(url: entry.url)
    }
}

// MARK: - Supporting Views

private struct StatView: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(title)
                    .font(.system(size: 12))
            }
            .foregroundColor(.secondary)
            
            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)
        }
    }
}

private struct SearchBar: View {
    @Binding var text: String
    let placeholder: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
            
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

#Preview {
    HistorySettingsView()
        .padding()
}