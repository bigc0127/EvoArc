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
                .searchable(text: $searchText, prompt: "search_history".localized)
                .navigationTitle("history".localized)
                .toolbar {
                    #if os(iOS)
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("done".localized) { dismiss() }
                    }
                    ToolbarItem(placement: .navigationBarLeading) {
                        Menu {
                            Button(role: .destructive, action: { historyManager.clearHistory() }) {
                                Label("clear_history".localized, systemImage: "trash")
                            }
                        } label: {
                            Label("More", systemImage: "ellipsis.circle")
                        }
                    }
                    #else
                    ToolbarItem(placement: .confirmationAction) {
                        Button("done".localized) { dismiss() }
                    }
                    ToolbarItem(placement: .automatic) {
                        Menu {
                            Button(role: .destructive, action: { historyManager.clearHistory() }) {
                                Label("clear_history".localized, systemImage: "trash")
                            }
                        } label: {
                            Label("More", systemImage: "ellipsis.circle")
                        }
                    }
                    #endif
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
                Label("open_in_new_tab".localized, systemImage: "plus.square")
            }
            
            Button(action: {
                historyManager.removeEntry(item)
            }) {
                Label("delete".localized, systemImage: "trash")
            }
        }
    }
}