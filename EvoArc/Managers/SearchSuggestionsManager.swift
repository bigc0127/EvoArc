//
//  SearchSuggestionsManager.swift
//  EvoArc
//
//  Created on 2025-09-16.
//

import Foundation
import Combine

/// Represents a search suggestion
struct SearchSuggestion: Identifiable, Hashable {
    let id: UUID = UUID()
    let text: String
    let type: SuggestionType
    
    enum SuggestionType {
        case search
        case trending
        case completion
    }
}

/// Manages search suggestions from various providers
@MainActor
final class SearchSuggestionsManager: ObservableObject {
    static let shared = SearchSuggestionsManager()
    
    // MARK: - Published Properties
    @Published private(set) var suggestions: [SearchSuggestion] = []
    @Published private(set) var isLoading = false
    
    // MARK: - Private Properties
    private var searchTask: Task<Void, Never>?
    private var debounceTask: Task<Void, Never>?
    private let maxSuggestions = 6
    private var suggestionCache: [String: [SearchSuggestion]] = [:]
    private let cacheTimeout: TimeInterval = 300 // 5 minutes
    private var lastCacheTime: [String: Date] = [:]
    private let debounceDelay: TimeInterval = 0.3 // 300ms debounce
    
    // Use Google for suggestions for stability (privacy note: only for suggestions, not actual searches)
    // When users click suggestions, they search with their configured search engine
    private let suggestionsBaseURL = "https://suggestqueries.google.com/complete/search"
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Get search suggestions for a query with debouncing
    func getSuggestions(for query: String) {
        // Cancel any existing tasks
        searchTask?.cancel()
        debounceTask?.cancel()
        
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Return empty suggestions for very short queries
        guard trimmedQuery.count >= 1 else {
            suggestions = []
            return
        }
        
        // Check cache first
        if let cachedSuggestions = getCachedSuggestions(for: trimmedQuery) {
            suggestions = cachedSuggestions
            return
        }
        
        // Debounce the search to avoid too many API calls
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(debounceDelay * 1_000_000_000))
            
            guard !Task.isCancelled else { return }
            
            // Now perform the actual search
            await performSearch(for: trimmedQuery)
        }
    }
    
    private func performSearch(for query: String) async {
        isLoading = true
        
        searchTask = Task {
            let fetchedSuggestions = await fetchSuggestions(for: query)
            
            if !Task.isCancelled {
                // Cache the results
                cacheSuggestions(fetchedSuggestions, for: query)
                suggestions = fetchedSuggestions
            }
            
            isLoading = false
        }
        
        await searchTask?.value
    }
    
    /// Clear suggestions
    func clearSuggestions() {
        searchTask?.cancel()
        debounceTask?.cancel()
        suggestions = []
        isLoading = false
    }
    
    /// Clear the suggestion cache
    func clearCache() {
        suggestionCache.removeAll()
        lastCacheTime.removeAll()
    }
    
    // MARK: - Private Methods
    
    private func fetchSuggestions(for query: String) async -> [SearchSuggestion] {
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(suggestionsBaseURL)?client=firefox&q=\(encodedQuery)") else {
            return []
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return []
            }
            
            return parseSuggestions(from: data, query: query)
        } catch {
            print("Failed to fetch search suggestions: \(error)")
            return []
        }
    }
    
    private func parseSuggestions(from data: Data, query: String) -> [SearchSuggestion] {
        do {
            // Google returns suggestions: [query, [suggestion1, suggestion2, ...], ...]
            guard let json = try JSONSerialization.jsonObject(with: data) as? [Any],
                  json.count > 1,
                  let suggestionStrings = json[1] as? [String] else {
                return []
            }
            
            var suggestions: [SearchSuggestion] = []
            
            for suggestionText in suggestionStrings.prefix(maxSuggestions) {
                let suggestion = SearchSuggestion(
                    text: suggestionText,
                    type: suggestionText.lowercased().hasPrefix(query.lowercased()) ? .completion : .search
                )
                suggestions.append(suggestion)
            }
            
            return suggestions
            
        } catch {
            print("Failed to parse search suggestions: \(error)")
            return []
        }
    }
    
    private func getCachedSuggestions(for query: String) -> [SearchSuggestion]? {
        guard let cached = suggestionCache[query],
              let cacheTime = lastCacheTime[query],
              Date().timeIntervalSince(cacheTime) < cacheTimeout else {
            return nil
        }
        
        return cached
    }
    
    private func cacheSuggestions(_ suggestions: [SearchSuggestion], for query: String) {
        suggestionCache[query] = suggestions
        lastCacheTime[query] = Date()
        
        // Clean up old cache entries to prevent memory issues
        cleanOldCacheEntries()
    }
    
    private func cleanOldCacheEntries() {
        let now = Date()
        let keysToRemove = lastCacheTime.compactMap { key, time in
            now.timeIntervalSince(time) > cacheTimeout ? key : nil
        }
        
        for key in keysToRemove {
            suggestionCache.removeValue(forKey: key)
            lastCacheTime.removeValue(forKey: key)
        }
    }
}

// MARK: - Extensions

extension SearchSuggestionsManager {
    /// Get combined suggestions (search + fallback)
    func getCombinedSuggestions(for query: String, maxResults: Int = 6) -> [SearchSuggestion] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Start with search suggestions
        var combined = Array(suggestions.prefix(maxResults))
        
        // Add fallback suggestions if we don't have enough
        if combined.count < maxResults && !trimmedQuery.isEmpty {
            let fallbackSuggestions = generateFallbackSuggestions(for: trimmedQuery)
            let needed = maxResults - combined.count
            combined.append(contentsOf: Array(fallbackSuggestions.prefix(needed)))
        }
        
        return combined
    }
    
    private func generateFallbackSuggestions(for query: String) -> [SearchSuggestion] {
        // Generate some common fallback suggestions based on the query
        var fallbacks: [SearchSuggestion] = []
        
        let lowercaseQuery = query.lowercased()
        
        // Common completions for popular sites
        let siteCompletions = [
            "google": ["google.com", "google maps", "google drive", "google docs"],
            "youtube": ["youtube.com", "youtube music", "youtube tv"],
            "facebook": ["facebook.com", "facebook login", "facebook marketplace"],
            "amazon": ["amazon.com", "amazon prime", "amazon music"],
            "apple": ["apple.com", "apple store", "apple music", "apple support"],
            "microsoft": ["microsoft.com", "microsoft office", "microsoft teams"],
            "github": ["github.com", "github desktop", "github copilot"]
        ]
        
        for (site, completions) in siteCompletions {
            if site.hasPrefix(lowercaseQuery) {
                for completion in completions {
                    if fallbacks.count >= 3 { break }
                    fallbacks.append(SearchSuggestion(text: completion, type: .completion))
                }
                break
            }
        }
        
        // Add the original query if it's not already suggested
        if !suggestions.contains(where: { $0.text.lowercased() == lowercaseQuery }) {
            fallbacks.append(SearchSuggestion(text: query, type: .search))
        }
        
        return fallbacks
    }
}