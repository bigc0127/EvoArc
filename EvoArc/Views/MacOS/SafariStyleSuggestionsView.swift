//
//  SafariStyleSuggestionsView.swift
//  EvoArc
//
//  Created on 2025-09-28.
//

import SwiftUI

#if os(macOS)

struct SafariStyleSuggestionsView: View {
    let query: String
    let preloadedResult: SearchPreloadManager.SearchResult?
    let onSuggestionTap: (String) -> Void
    let onTopResultTap: (URL) -> Void
    
    @StateObject private var searchSuggestionManager = SearchSuggestionsManager.shared
    @StateObject private var bookmarkManager = BookmarkManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top result from website (if available)
            if let preloadedResult = preloadedResult,
               let firstResultURL = preloadedResult.firstResultURL {
                TopResultView(
                    title: preloadedResult.firstResultTitle ?? firstResultURL.host ?? "Website",
                    url: firstResultURL,
                    onTap: { onTopResultTap(firstResultURL) }
                )
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                
                Divider()
            }
            
            // Search Suggestions (clean Safari-style, no branding)
            if !query.isEmpty && !searchSuggestionManager.suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(searchSuggestionManager.suggestions.indices, id: \\.self) { index in
                        let suggestion = searchSuggestionManager.suggestions[index]
                        Button(action: { onSuggestionTap(suggestion.text) }) {
                            HStack(spacing: 12) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                                    .frame(width: 18, height: 18)
                                
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(suggestion.text)
                                        .font(.system(size: 13))
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                
                                Spacer()
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.clear)
                        .contentShape(Rectangle())
                        
                        if index < searchSuggestionManager.suggestions.count - 1 {
                            Divider()
                                .padding(.leading, 46)
                        }
                    }
                }
                
                if !getBookmarkSuggestions(for: query).isEmpty || !HistoryManager.shared.getHistorySuggestions(for: query).isEmpty {
                    Divider()
                }
            }
            
            // Bookmarks and History Section
            if !query.isEmpty {
                let historySuggestions = HistoryManager.shared.getHistorySuggestions(for: query)
                let bookmarkSuggestions = getBookmarkSuggestions(for: query)
                let combinedSuggestions = getCombinedSuggestions(bookmarkSuggestions: bookmarkSuggestions, historySuggestions: historySuggestions)
                
                if !combinedSuggestions.isEmpty {
                    SuggestionSectionView(
                        title: "Bookmarks and History",
                        suggestions: combinedSuggestions
                    )
                }
            } else {
                // Show recent history and bookmarks when no query
                let recentHistory = Array(HistoryManager.shared.recentHistory.prefix(3))
                let recentBookmarks = Array(bookmarkManager.bookmarks.prefix(3))
                
                if !recentHistory.isEmpty {
                    SuggestionSectionView(
                        title: "Recently Visited",
                        suggestions: recentHistory.map { entry in
                            SuggestionRowData(
                                text: entry.title,
                                subtitle: entry.url.host ?? entry.url.absoluteString,
                                icon: "clock",
                                action: { onTopResultTap(entry.url) }
                            )
                        }
                    )
                    
                    if !recentBookmarks.isEmpty {
                        Divider()
                    }
                }
                
                if !recentBookmarks.isEmpty {
                    SuggestionSectionView(
                        title: "Bookmarks",
                        suggestions: recentBookmarks.map { bookmark in
                            SuggestionRowData(
                                text: bookmark.title,
                                subtitle: bookmark.url.host ?? bookmark.url.absoluteString,
                                icon: "bookmark.fill",
                                action: { onTopResultTap(bookmark.url) }
                            )
                        }
                    )
                }
            }
        }
        .frame(maxHeight: 400)
        .onAppear {
            if !query.isEmpty {
                searchSuggestionManager.getSuggestions(for: query)
            }
        }
        .onChange(of: query) { _, newQuery in
            if !newQuery.isEmpty {
                searchSuggestionManager.getSuggestions(for: newQuery)
            }
        }
    }
    
    private func getBookmarkSuggestions(for query: String) -> [Bookmark] {
        let lowercaseQuery = query.lowercased()
        return bookmarkManager.bookmarks.filter { bookmark in
            bookmark.title.lowercased().contains(lowercaseQuery) ||
            bookmark.url.absoluteString.lowercased().contains(lowercaseQuery) ||
            bookmark.url.host?.lowercased().contains(lowercaseQuery) == true
        }
    }
    
    private func getCombinedSuggestions(bookmarkSuggestions: [Bookmark], historySuggestions: [HistoryEntry]) -> [SuggestionRowData] {
        var combined: [SuggestionRowData] = []
        
        // Add bookmark suggestions (up to 2)
        combined.append(contentsOf: bookmarkSuggestions.prefix(2).map { bookmark in
            SuggestionRowData(
                text: bookmark.title,
                subtitle: bookmark.url.host ?? bookmark.url.absoluteString,
                icon: "bookmark.fill",
                action: { onTopResultTap(bookmark.url) }
            )
        })
        
        // Add history suggestions (up to 2)
        combined.append(contentsOf: historySuggestions.prefix(2).map { historyEntry in
            SuggestionRowData(
                text: historyEntry.title,
                subtitle: historyEntry.url.host ?? historyEntry.url.absoluteString,
                icon: "clock",
                action: { onTopResultTap(historyEntry.url) }
            )
        })
        
        return Array(combined.prefix(4))
    }
}

#endif