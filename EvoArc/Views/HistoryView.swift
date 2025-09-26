import SwiftUI

struct HistoryView: View {
    @ObservedObject var tabManager: TabManager
    @Environment(\.dismiss) private var dismiss
    @StateObject private var historyManager = HistoryManager.shared
    @State private var searchText = ""
    
    private var filteredHistory: [HistoryEntry] {
        if searchText.isEmpty {
            return historyManager.recentHistory
        } else {
            return historyManager.searchHistory(searchText)
        }
    }
    
    var body: some View {
        NavigationView {
            historyList
                .searchable(text: $searchText, prompt: "Search history")
                .navigationTitle("History")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                    
                    ToolbarItem(placement: .navigationBarLeading) {
                        Menu {
                            Button(role: .destructive, action: {
                                historyManager.clearHistory()
                            }) {
                                Label("Clear History", systemImage: "trash")
                            }
                        } label: {
                            Label("More", systemImage: "ellipsis.circle")
                        }
                    }
                }
        }
        #if os(iOS)
        .navigationViewStyle(.stack)
        #endif
    }
    
    private var historyList: some View {
        List {
            ForEach(filteredHistory, id: \.id) { item in
                historyRow(for: item)
            }
        }
    }
    
    private func historyRow(for item: HistoryEntry) -> some View {
        Button(action: {
            tabManager.createNewTab(url: item.url)
            dismiss()
        }) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.headline)
                    .lineLimit(1)
                Text(item.url.absoluteString)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                Text(item.lastVisited, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(action: {
                tabManager.createNewTab(url: item.url)
                dismiss()
            }) {
                Label("Open in New Tab", systemImage: "plus.square")
            }
            
            Button(action: {
                historyManager.removeEntry(item)
            }) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}