//
//  SuggestionViews.swift
//  EvoArc
//
//  Created on 2025-09-16.
//

import SwiftUI
import Combine
#if os(iOS)
import UIKit
#else
import AppKit
#endif

/// Combined suggestion item that can represent either history or search suggestions
struct SuggestionItem: Identifiable, Hashable {
    let id = UUID()
    let text: String
    let subtitle: String?
    let type: SuggestionType
    let url: URL?
    let icon: String
    
    enum SuggestionType {
        case history
        case search
        case url
    }
    
    init(historyEntry: HistoryEntry) {
        self.text = historyEntry.title
        self.subtitle = historyEntry.url.host ?? historyEntry.url.absoluteString
        self.type = .history
        self.url = historyEntry.url
        self.icon = "clock"
    }
    
    init(searchSuggestion: SearchSuggestion) {
        self.text = searchSuggestion.text
        self.subtitle = nil
        self.type = .search
        self.url = nil
        self.icon = "magnifyingglass"
    }
    
    init(urlSuggestion: String) {
        self.text = urlSuggestion
        self.subtitle = nil
        self.type = .url
        self.url = URL(string: urlSuggestion.hasPrefix("http") ? urlSuggestion : "https://\(urlSuggestion)")
        self.icon = "globe"
    }
}

/// Unified suggestion list component for both iOS and macOS
struct SuggestionListView: View {
    let suggestions: [SuggestionItem]
    let onSuggestionTapped: (SuggestionItem) -> Void
    let onDismiss: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        #if os(iOS)
        iOSSuggestionList
        #else
        macOSSuggestionList
        #endif
    }
    
    // MARK: - iOS Implementation
    
    #if os(iOS)
    private var iOSSuggestionList: some View {
        VStack(spacing: 0) {
            ForEach(suggestions) { suggestion in
                Button(action: {
                    onSuggestionTapped(suggestion)
                }) {
                    SuggestionRowView(suggestion: suggestion)
                }
                .buttonStyle(PlainButtonStyle())
                
                if suggestion.id != suggestions.last?.id {
                    Divider()
                        .padding(.leading, 44)
                }
            }
        }
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(UIColor.separator), lineWidth: 0.5)
        )
    }
    #endif
    
    // MARK: - macOS Implementation
    
    #if os(macOS)
    private var macOSSuggestionList: some View {
        VStack(spacing: 1) {
            ForEach(suggestions) { suggestion in
                Button(action: {
                    onSuggestionTapped(suggestion)
                }) {
                    SuggestionRowView(suggestion: suggestion)
                }
                .buttonStyle(SuggestionButtonStyle())
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
        )
    }
    #endif
}

/// Individual suggestion row component
struct SuggestionRowView: View {
    let suggestion: SuggestionItem
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: suggestion.icon)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .frame(width: 16, height: 16)
            
            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(suggestion.text)
                    .font(.system(size: 15))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                if let subtitle = suggestion.subtitle {
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Type indicator
            if suggestion.type == .search {
                Image(systemName: "arrow.up.left")
                    .font(.system(size: 11))
                    .foregroundColor(Color.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, suggestion.subtitle != nil ? 8 : 10)
        .contentShape(Rectangle())
    }
}

// MARK: - Custom Button Styles

#if os(macOS)
struct SuggestionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                Rectangle()
                    .fill(configuration.isPressed ? Color.accentColor.opacity(0.1) : Color.clear)
            )
    }
}
#endif

// MARK: - Suggestion Manager

/// Manages combined suggestions from history and search
@MainActor
final class SuggestionManager: ObservableObject {
    @Published private(set) var suggestions: [SuggestionItem] = []
    @Published private(set) var isLoading = false
    
    private let historyManager = HistoryManager.shared
    private let searchManager = SearchSuggestionsManager.shared
    private var searchTask: Task<Void, Never>?
    
    func getSuggestions(for query: String) {
        searchTask?.cancel()
        
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedQuery.isEmpty else {
            // Show recent history when query is empty
            updateSuggestions(history: Array(historyManager.recentHistory.prefix(6)), search: [])
            return
        }
        
        isLoading = true
        
        // Get history suggestions immediately
        let historySuggestions = historyManager.getHistorySuggestions(for: trimmedQuery)
        
        // Start search suggestions task
        searchTask = Task {
            // Get search suggestions (this might take some time)
            searchManager.getSuggestions(for: trimmedQuery)
            
            // Wait a bit for search results
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            
            if !Task.isCancelled {
                updateSuggestions(
                    history: historySuggestions,
                    search: searchManager.suggestions
                )
                isLoading = false
            }
        }
        
        // Show history suggestions immediately
        updateSuggestions(history: historySuggestions, search: [])
    }
    
    func clearSuggestions() {
        searchTask?.cancel()
        suggestions = []
        isLoading = false
        searchManager.clearSuggestions()
    }
    
    private func updateSuggestions(history: [HistoryEntry], search: [SearchSuggestion]) {
        var combined: [SuggestionItem] = []
        
        // Add history suggestions first (max 3)
        for entry in history.prefix(3) {
            combined.append(SuggestionItem(historyEntry: entry))
        }
        
        // Add search suggestions (max 4)
        for suggestion in search.prefix(4) {
            // Convert to search suggestion that will use the user's default search engine
            let item = SuggestionItem(searchSuggestion: suggestion)
            combined.append(item)
        }
        
        // Check if query might be a URL
        let queryString = SearchSuggestionsManager.shared.lastQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if !queryString.isEmpty,
           !queryString.isEmpty,
           !queryString.contains(" "),
           queryString.contains(".") {
            let urlSuggestion = SuggestionItem(urlSuggestion: queryString)
            combined.insert(urlSuggestion, at: 0)
        }
        
        suggestions = combined
    }
}

// MARK: - URL Bar with Suggestions

struct URLBarWithSuggestions: View {
    @Binding var urlText: String
    @Binding var isEditing: Bool
    let placeholder: String
    let onSubmit: () -> Void
    let onSuggestionSelected: (SuggestionItem) -> Void
    
    @StateObject private var suggestionManager = SuggestionManager()
    @State private var showingSuggestions = false
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // URL Text Field
            HStack {
                TextField(placeholder, text: $urlText)
                    .focused($isTextFieldFocused)
                    .onSubmit {
                        onSubmit()
                        hideSuggestions()
                    }
                    .onChange(of: urlText) { _, newValue in
                        if isTextFieldFocused && isEditing {
                            suggestionManager.getSuggestions(for: newValue)
                            showingSuggestions = !suggestionManager.suggestions.isEmpty
                        }
                    }
                    .onChange(of: isTextFieldFocused) { _, focused in
                        isEditing = focused
                        if focused {
                            suggestionManager.getSuggestions(for: urlText)
                            showingSuggestions = !suggestionManager.suggestions.isEmpty
                        } else {
                            hideSuggestions()
                        }
                    }
            }
            
            // Suggestions
            if showingSuggestions && isEditing && !suggestionManager.suggestions.isEmpty {
                SuggestionListView(
                    suggestions: suggestionManager.suggestions,
                    onSuggestionTapped: { suggestion in
                        onSuggestionSelected(suggestion)
                        hideSuggestions()
                    },
                    onDismiss: {
                        hideSuggestions()
                    }
                )
                .padding(.top, 8)
            }
        }
    }
    
    private func hideSuggestions() {
        showingSuggestions = false
        isTextFieldFocused = false
        suggestionManager.clearSuggestions()
    }
}