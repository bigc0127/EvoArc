//
//  HistoryManager.swift
//  EvoArc
//
//  Created on 2025-09-16.
//

import Foundation
import Combine

/// Represents a single entry in browser history
struct HistoryEntry: Codable, Identifiable, Hashable {
    let id: UUID
    let url: URL
    let title: String
    let visitCount: Int
    let lastVisited: Date
    let favicon: String? // Base64 encoded favicon data
    
    init(url: URL, title: String, favicon: String? = nil) {
        self.id = UUID()
        self.url = url
        self.title = title.isEmpty ? url.host ?? url.absoluteString : title
        self.visitCount = 1
        self.lastVisited = Date()
        self.favicon = favicon
    }
    
    // Update existing entry with new visit
    func withNewVisit(title: String? = nil, favicon: String? = nil) -> HistoryEntry {
        return HistoryEntry(
            id: self.id,
            url: self.url,
            title: title?.isEmpty == false ? title! : self.title,
            visitCount: self.visitCount + 1,
            lastVisited: Date(),
            favicon: favicon ?? self.favicon
        )
    }
    
    private init(id: UUID, url: URL, title: String, visitCount: Int, lastVisited: Date, favicon: String?) {
        self.id = id
        self.url = url
        self.title = title
        self.visitCount = visitCount
        self.lastVisited = lastVisited
        self.favicon = favicon
    }
}

/// Manages browser history storage, retrieval, and suggestions
@MainActor
final class HistoryManager: ObservableObject {
    static let shared = HistoryManager()
    
    // MARK: - Published Properties
    @Published private(set) var recentHistory: [HistoryEntry] = []
    @Published private(set) var isLoading = false
    
    // MARK: - Private Properties
    private let maxHistoryEntries = 10000
    private let maxSuggestions = 8
    private var allHistory: [HistoryEntry] = []
    private let historyKey = "browserHistory"
    
    private init() {
        loadHistory()
    }
    
    // MARK: - Public Methods
    
    /// Add or update a history entry
    func addEntry(url: URL, title: String, favicon: String? = nil) {
        // Don't track certain URLs
        guard shouldTrackURL(url) else { return }
        
        let normalizedURL = normalizeURL(url)
        
        // Check if this URL already exists
        if let existingIndex = allHistory.firstIndex(where: { $0.url.absoluteString == normalizedURL.absoluteString }) {
            // Update existing entry
            let updatedEntry = allHistory[existingIndex].withNewVisit(title: title, favicon: favicon)
            allHistory[existingIndex] = updatedEntry
        } else {
            // Create new entry
            let newEntry = HistoryEntry(url: normalizedURL, title: title, favicon: favicon)
            allHistory.insert(newEntry, at: 0)
            
            // Trim history if needed
            if allHistory.count > maxHistoryEntries {
                allHistory = Array(allHistory.prefix(maxHistoryEntries))
            }
        }
        
        // Sort by visit frequency and recency
        sortHistory()
        updateRecentHistory()
        saveHistory()
    }
    
    /// Get history suggestions based on input text
    func getHistorySuggestions(for query: String) -> [HistoryEntry] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return Array(recentHistory.prefix(maxSuggestions))
        }
        
        let lowercaseQuery = query.lowercased()
        
        // Search in URL, title, and host
        let matches = allHistory.filter { entry in
            let url = entry.url.absoluteString.lowercased()
            let title = entry.title.lowercased()
            let host = entry.url.host?.lowercased() ?? ""
            
            return url.contains(lowercaseQuery) || 
                   title.contains(lowercaseQuery) || 
                   host.contains(lowercaseQuery) ||
                   host.hasPrefix(lowercaseQuery)
        }
        
        // Sort matches by relevance
        let sortedMatches = matches.sorted { entry1, entry2 in
            let score1 = calculateRelevanceScore(for: entry1, query: lowercaseQuery)
            let score2 = calculateRelevanceScore(for: entry2, query: lowercaseQuery)
            
            if score1 != score2 {
                return score1 > score2
            }
            
            // If scores are equal, prefer more recent visits
            return entry1.lastVisited > entry2.lastVisited
        }
        
        return Array(sortedMatches.prefix(maxSuggestions))
    }
    
    /// Clear all history
    func clearHistory() {
        allHistory.removeAll()
        recentHistory.removeAll()
        saveHistory()
    }
    
    /// Clear history entries older than specified date
    func clearHistory(olderThan date: Date) {
        allHistory = allHistory.filter { $0.lastVisited > date }
        updateRecentHistory()
        saveHistory()
    }
    
    /// Remove specific history entry
    func removeEntry(_ entry: HistoryEntry) {
        allHistory.removeAll { $0.id == entry.id }
        updateRecentHistory()
        saveHistory()
    }
    
    /// Search history with more advanced filtering
    func searchHistory(_ query: String) -> [HistoryEntry] {
        guard !query.isEmpty else { return recentHistory }
        return getHistorySuggestions(for: query)
    }
    
    // MARK: - Private Methods
    
    private func shouldTrackURL(_ url: URL) -> Bool {
        let scheme = url.scheme?.lowercased() ?? ""
        let host = url.host?.lowercased() ?? ""
        
        // Only track HTTP/HTTPS URLs
        guard scheme == "http" || scheme == "https" else { return false }
        
        // Don't track private/local addresses
        let privateHosts = ["localhost", "127.0.0.1", "0.0.0.0"]
        if privateHosts.contains(host) { return false }
        
        // Don't track empty or invalid hosts
        if host.isEmpty { return false }
        
        return true
    }
    
    private func normalizeURL(_ url: URL) -> URL {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        
        // Remove fragment identifier
        components?.fragment = nil
        
        // Remove common tracking parameters
        let trackingParams = ["utm_source", "utm_medium", "utm_campaign", "utm_term", "utm_content", 
                             "fbclid", "gclid", "ref", "referrer"]
        
        if var queryItems = components?.queryItems {
            queryItems = queryItems.filter { item in
                !trackingParams.contains { param in
                    item.name.lowercased().contains(param.lowercased())
                }
            }
            components?.queryItems = queryItems.isEmpty ? nil : queryItems
        }
        
        return components?.url ?? url
    }
    
    private func calculateRelevanceScore(for entry: HistoryEntry, query: String) -> Int {
        var score = 0
        let url = entry.url.absoluteString.lowercased()
        let title = entry.title.lowercased()
        let host = entry.url.host?.lowercased() ?? ""
        
        // Exact host match gets highest score
        if host == query {
            score += 100
        }
        
        // Host starts with query
        if host.hasPrefix(query) {
            score += 50
        }
        
        // Title starts with query
        if title.hasPrefix(query) {
            score += 40
        }
        
        // Host contains query
        if host.contains(query) {
            score += 30
        }
        
        // Title contains query
        if title.contains(query) {
            score += 20
        }
        
        // URL contains query
        if url.contains(query) {
            score += 10
        }
        
        // Boost score based on visit count (logarithmic scale)
        score += Int(log(Double(entry.visitCount + 1)) * 5)
        
        // Boost recent visits
        let daysSinceVisit = Calendar.current.dateComponents([.day], from: entry.lastVisited, to: Date()).day ?? 0
        if daysSinceVisit < 1 {
            score += 15
        } else if daysSinceVisit < 7 {
            score += 10
        } else if daysSinceVisit < 30 {
            score += 5
        }
        
        return score
    }
    
    private func sortHistory() {
        allHistory.sort { entry1, entry2 in
            // Combine recency and frequency for sorting
            let score1 = Double(entry1.visitCount) + (Date().timeIntervalSince(entry1.lastVisited) < 86400 ? 10.0 : 0.0)
            let score2 = Double(entry2.visitCount) + (Date().timeIntervalSince(entry2.lastVisited) < 86400 ? 10.0 : 0.0)
            
            if score1 != score2 {
                return score1 > score2
            }
            
            return entry1.lastVisited > entry2.lastVisited
        }
    }
    
    private func updateRecentHistory() {
        recentHistory = Array(allHistory.prefix(50)) // Keep top 50 for quick access
    }
    
    private func loadHistory() {
        isLoading = true
        defer { isLoading = false }
        
        guard let data = UserDefaults.standard.data(forKey: historyKey),
              let history = try? JSONDecoder().decode([HistoryEntry].self, from: data) else {
            return
        }
        
        allHistory = history
        sortHistory()
        updateRecentHistory()
    }
    
    private func saveHistory() {
        guard let data = try? JSONEncoder().encode(allHistory) else { return }
        UserDefaults.standard.set(data, forKey: historyKey)
    }
}

// MARK: - Extensions

extension HistoryManager {
    /// Get most visited sites
    func getMostVisitedSites(limit: Int = 10) -> [HistoryEntry] {
        return Array(allHistory.sorted { $0.visitCount > $1.visitCount }.prefix(limit))
    }
    
    /// Get recently visited sites
    func getRecentlyVisitedSites(limit: Int = 10) -> [HistoryEntry] {
        return Array(allHistory.sorted { $0.lastVisited > $1.lastVisited }.prefix(limit))
    }
    
    /// Get history statistics
    func getHistoryStats() -> (totalEntries: Int, totalVisits: Int, oldestEntry: Date?) {
        let totalEntries = allHistory.count
        let totalVisits = allHistory.reduce(0) { $0 + $1.visitCount }
        let oldestEntry = allHistory.min(by: { $0.lastVisited < $1.lastVisited })?.lastVisited
        
        return (totalEntries, totalVisits, oldestEntry)
    }
}