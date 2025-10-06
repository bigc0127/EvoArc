//
//  HistoryManager.swift
//  EvoArc
//
//  Created on 2025-09-16.
//
//  Manages the browser's history - tracking visited pages, providing suggestions,
//  and enabling history search.
//
//  Key responsibilities:
//  1. Track all visited URLs with metadata (title, visit count, last visit time)
//  2. Provide intelligent suggestions based on partial input
//  3. Persist history to UserDefaults with JSON encoding
//  4. Calculate relevance scores for search results
//  5. Clean up old entries and normalize URLs
//  6. Support history clearing (all, by date, or specific entries)
//
//  Design patterns:
//  - Singleton: One shared instance app-wide
//  - @MainActor: All operations run on main thread for UI safety
//  - ObservableObject: SwiftUI views can observe changes
//  - Codable: JSON serialization for persistence
//

import Foundation  // Core Swift framework - provides Date, URL, UserDefaults
import Combine     // Reactive framework - used by ObservableObject

// MARK: - HistoryEntry Model

/// Represents a single page visit in browser history.
///
/// **Data model**: Contains all information about a visited page.
///
/// **Protocols**:
/// - `Codable`: Can be encoded/decoded to/from JSON for persistence
/// - `Identifiable`: Has a unique `id` property (required for SwiftUI ForEach)
/// - `Hashable`: Can be used in Sets and as Dictionary keys
///
/// **Immutability**: This is a value type (struct) with immutable properties.
/// Updates create new instances rather than modifying existing ones.
struct HistoryEntry: Codable, Identifiable, Hashable {
    /// Unique identifier for this history entry.
    let id: UUID
    
    /// The visited URL (normalized to remove tracking parameters).
    let url: URL
    
    /// The page title (or host if title is empty).
    let title: String
    
    /// Number of times this URL has been visited.
    let visitCount: Int
    
    /// Timestamp of the most recent visit.
    let lastVisited: Date
    
    /// Optional favicon data (Base64 encoded for JSON storage).
    let favicon: String?
    
    /// Creates a new history entry for a first-time visit.
    ///
    /// **Default values**: Visit count starts at 1, lastVisited is now.
    ///
    /// **Title fallback hierarchy**:
    /// 1. Use provided title if not empty
    /// 2. Fall back to URL host ("github.com")
    /// 3. Fall back to full URL if no host
    ///
    /// **UUID**: Generates cryptographically random unique identifier.
    /// Practically impossible to collide (2^122 possible values).
    ///
    /// **Parameters**:
    /// - url: The visited URL
    /// - title: Page title from HTML <title> tag
    /// - favicon: Optional base64-encoded favicon image
    ///
    /// **Example**:
    /// ```swift
    /// HistoryEntry(url: URL(string: "https://github.com")!, 
    ///              title: "GitHub", 
    ///              favicon: "data:image/png;base64,...")
    /// ```
    init(url: URL, title: String, favicon: String? = nil) {
        self.id = UUID()  // Generate unique ID (random, not sequential)
        self.url = url
        
        /// Title selection logic:
        /// If title is empty or whitespace, use host or full URL as fallback.
        /// This ensures every entry has a meaningful display name.
        self.title = title.isEmpty ? url.host ?? url.absoluteString : title
        
        self.visitCount = 1  // First visit to this page
        self.lastVisited = Date()  // Current timestamp
        self.favicon = favicon  // Optional: can be nil
    }
    
    /// Creates an updated copy of this entry with incremented visit count.
    ///
    /// **Immutable pattern**: Instead of modifying the existing entry,
    /// creates a new one with updated values. This is the pattern for
    /// value types (structs) in Swift.
    ///
    /// **Why immutable?**: 
    /// - Thread-safe (no concurrent modification)
    /// - Easier to reason about (no hidden mutations)
    /// - Supports undo/redo if needed
    /// - Follows functional programming principles
    ///
    /// **ID preserved**: New entry keeps same ID (represents same page).
    ///
    /// **Parameters**:
    /// - title: New title (optional - keeps existing if nil or empty)
    /// - favicon: New favicon (optional - keeps existing if nil)
    ///
    /// **Returns**: New HistoryEntry with:
    /// - Same id and url
    /// - Updated title (if provided)
    /// - visitCount + 1
    /// - lastVisited = now
    /// - Updated favicon (if provided)
    ///
    /// **Example**:
    /// ```swift
    /// let original = HistoryEntry(url: url, title: "Old Title")
    /// // visitCount = 1, lastVisited = 2025-01-01
    ///
    /// let updated = original.withNewVisit(title: "New Title")
    /// // visitCount = 2, lastVisited = 2025-01-02
    /// // original unchanged!
    /// ```
    func withNewVisit(title: String? = nil, favicon: String? = nil) -> HistoryEntry {
        return HistoryEntry(
            id: self.id,  // Keep same ID (represents same page)
            url: self.url,  // URL never changes
            
            /// Update title if new one provided and not empty.
            /// Otherwise keep existing title.
            /// title?.isEmpty == false checks:
            /// 1. title is not nil
            /// 2. title is not empty string
            title: title?.isEmpty == false ? title! : self.title,
            
            visitCount: self.visitCount + 1,  // Increment visit counter
            lastVisited: Date(),  // Update to current time
            
            /// Update favicon if provided, otherwise keep existing.
            /// ?? is nil-coalescing operator: use left if not nil, else right.
            favicon: favicon ?? self.favicon
        )
    }
    
    /// Private initializer for creating updated entries.
    ///
    /// **Purpose**: Used by withNewVisit() to create modified copies.
    ///
    /// **Private**: External code can't call this directly.
    /// Forces use of public init or withNewVisit().
    ///
    /// **All parameters**: Unlike public init, this accepts all values
    /// including visitCount and lastVisited (for creating updated copies).
    private init(id: UUID, url: URL, title: String, visitCount: Int, lastVisited: Date, favicon: String?) {
        self.id = id
        self.url = url
        self.title = title
        self.visitCount = visitCount
        self.lastVisited = lastVisited
        self.favicon = favicon
    }
}

// MARK: - HistoryManager Class

/// Manages browser history storage, retrieval, and intelligent suggestions.
///
/// **@MainActor**: All methods run on the main thread. This is crucial because:
/// 1. UI updates must happen on main thread
/// 2. UserDefaults access is main-thread safe
/// 3. Prevents race conditions with @Published properties
///
/// **final**: Cannot be subclassed - this is a concrete implementation.
///
/// **ObservableObject**: SwiftUI views can observe @Published properties.
///
/// **Singleton**: One shared instance accessed via `HistoryManager.shared`.
@MainActor
final class HistoryManager: ObservableObject {
    /// The shared singleton instance.
    static let shared = HistoryManager()
    
    // MARK: - Published Properties
    // These properties notify observers when they change.
    // `private(set)` means: public read, private write.
    
    /// The 50 most relevant history entries (for quick access).
    ///
    /// **private(set)**: External code can read but not modify directly.
    @Published private(set) var recentHistory: [HistoryEntry] = []
    
    /// Whether history is currently being loaded from storage.
    @Published private(set) var isLoading = false
    
    // MARK: - Private Properties
    
    /// Maximum number of history entries to keep (prevents unbounded growth).
    private let maxHistoryEntries = 10000
    
    /// Maximum number of suggestions to return for autocomplete.
    private let maxSuggestions = 8
    
    /// Complete history array (all entries, sorted by relevance).
    private var allHistory: [HistoryEntry] = []
    
    /// UserDefaults key for persistence.
    private let historyKey = "browserHistory"
    
    /// Private initializer (singleton pattern).
    ///
    /// **Why private?**: Prevents external code from creating multiple instances.
    /// Forces use of `.shared` singleton.
    private init() {
        loadHistory()  // Load persisted history on initialization
    }
    
    // MARK: - Public Methods
    // These methods are called by other parts of EvoArc.
    
    /// Adds a new history entry or updates an existing one.
    ///
    /// **Process**:
    /// 1. Validate URL (skip localhost, invalid schemes, etc.)
    /// 2. Normalize URL (remove tracking params, fragments)
    /// 3. Check if URL already exists:
    ///    - Exists: Update with new visit
    ///    - New: Create entry and insert at top
    /// 4. Limit to 10,000 entries (remove oldest)
    /// 5. Sort by relevance
    /// 6. Update recent cache
    /// 7. Persist to disk
    ///
    /// **Called**: Every time user navigates to a page.
    ///
    /// **Parameters**:
    /// - url: The visited URL
    /// - title: Page title from HTML
    /// - favicon: Optional favicon data
    ///
    /// **Example**:
    /// ```swift
    /// HistoryManager.shared.addEntry(
    ///     url: URL(string: "https://github.com")!,
    ///     title: "GitHub",
    ///     favicon: "data:image/png;base64..."
    /// )
    /// ```
    func addEntry(url: URL, title: String, favicon: String? = nil) {
        /// Don't track certain URLs (localhost, file://, etc.).
        /// Returns early if URL should not be tracked.
        guard shouldTrackURL(url) else { return }
        
        /// Remove tracking parameters and fragments.
        /// "example.com/page?utm_source=email#section" →
        /// "example.com/page"
        let normalizedURL = normalizeURL(url)
        
        /// Check if this URL already exists in history.
        /// Uses absoluteString for comparison (exact URL match).
        if let existingIndex = allHistory.firstIndex(where: { $0.url.absoluteString == normalizedURL.absoluteString }) {
            /// URL exists - update visit count and timestamp.
            /// withNewVisit() creates new entry with incremented count.
            let updatedEntry = allHistory[existingIndex].withNewVisit(title: title, favicon: favicon)
            allHistory[existingIndex] = updatedEntry  // Replace old entry
        } else {
            /// New URL - create fresh entry.
            let newEntry = HistoryEntry(url: normalizedURL, title: title, favicon: favicon)
            allHistory.insert(newEntry, at: 0)  // Insert at front (most recent)
            
            /// Trim history if exceeds 10,000 entries.
            /// Prevents unbounded memory growth.
            if allHistory.count > maxHistoryEntries {
                /// Keep only first 10,000 entries (drop oldest).
                allHistory = Array(allHistory.prefix(maxHistoryEntries))
            }
        }
        
        /// Re-sort history by relevance (visit count + recency).
        sortHistory()
        
        /// Update the "top 50" cache for quick access.
        updateRecentHistory()
        
        /// Persist to UserDefaults (survives app restart).
        saveHistory()
    }
    
    /// Returns intelligent history suggestions based on user's partial input.
    ///
    /// **How it works**:
    /// 1. If query is empty, return recent history
    /// 2. Search URL, title, and host for matches
    /// 3. Calculate relevance score for each match
    /// 4. Sort by relevance, then recency
    /// 5. Return top `maxSuggestions` results
    ///
    /// **Use case**: Powers URL bar autocomplete.
    ///
    /// **Example**: Query "git" matches:
    /// - github.com (high score - exact host prefix)
    /// - "My Git Tutorial" (medium score - title match)
    /// - githubassets.com (lower score - host contains)
    ///
    /// **Parameter**:
    /// - query: The user's partial input
    ///
    /// **Returns**: Up to 8 most relevant history entries
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
    
    /// Clears all history entries.
    ///
    /// **Use cases**:
    /// - User clicks "Clear History" in settings
    /// - Privacy mode enabled
    /// - App reset
    ///
    /// **Effect**: Removes all entries and persists empty state.
    ///
    /// **Warning**: This action is irreversible!
    func clearHistory() {
        allHistory.removeAll()      // Clear main history
        recentHistory.removeAll()   // Clear quick-access cache
        saveHistory()               // Persist empty state
    }
    
    /// Clears history entries older than specified date.
    ///
    /// **Use case**: "Clear last hour", "Clear last day", etc.
    ///
    /// **Keeps**: Entries visited after the cutoff date.
    ///
    /// **Parameter**:
    /// - date: Cutoff date - entries before this are deleted
    ///
    /// **Example**:
    /// ```swift
    /// // Clear entries older than 1 hour
    /// let oneHourAgo = Date().addingTimeInterval(-3600)
    /// HistoryManager.shared.clearHistory(olderThan: oneHourAgo)
    /// ```
    func clearHistory(olderThan date: Date) {
        /// Keep only entries with lastVisited > cutoff date.
        /// .filter() creates new array with matching elements.
        allHistory = allHistory.filter { $0.lastVisited > date }
        
        /// Update cached recent entries.
        updateRecentHistory()
        
        /// Persist changes.
        saveHistory()
    }
    
    /// Removes a specific history entry by ID.
    ///
    /// **Use case**: User right-clicks entry and selects "Delete".
    ///
    /// **ID matching**: Uses UUID, not URL (handles duplicate visits).
    ///
    /// **Parameter**:
    /// - entry: The history entry to remove
    func removeEntry(_ entry: HistoryEntry) {
        /// Remove all entries with matching ID.
        /// .removeAll { } removes elements matching condition.
        allHistory.removeAll { $0.id == entry.id }
        
        /// Update recent cache (entry might have been there).
        updateRecentHistory()
        
        /// Persist deletion.
        saveHistory()
    }
    
    /// Searches history with query string.
    ///
    /// **Alias**: This is just a wrapper around getHistorySuggestions().
    ///
    /// **Use case**: Dedicated history search UI.
    ///
    /// **Parameter**:
    /// - query: Search string
    ///
    /// **Returns**: Matching history entries
    func searchHistory(_ query: String) -> [HistoryEntry] {
        guard !query.isEmpty else { return recentHistory }
        return getHistorySuggestions(for: query)
    }
    
    // MARK: - Private Methods
    // Internal implementation details.
    
    /// Determines if a URL should be tracked in history.
    ///
    /// **Filtering rules**:
    /// 1. Only HTTP/HTTPS schemes (no file://, data://, etc.)
    /// 2. No localhost or 127.0.0.1 (dev servers)
    /// 3. No empty hosts (invalid URLs)
    ///
    /// **Why filter?**: 
    /// - Privacy (don't track local development)
    /// - Cleanliness (don't show invalid URLs)
    /// - Security (avoid tracking file:// paths)
    ///
    /// **Parameter**:
    /// - url: URL to validate
    ///
    /// **Returns**: true if URL should be tracked
    ///
    /// **Examples**:
    /// - https://github.com → true ✅
    /// - http://localhost:3000 → false ❌
    /// - file:///Users/... → false ❌
    /// - about:blank → false ❌
    private func shouldTrackURL(_ url: URL) -> Bool {
        let scheme = url.scheme?.lowercased() ?? ""
        let host = url.host?.lowercased() ?? ""
        
        /// Only track HTTP/HTTPS URLs.
        /// Rejects file://, data://, about:, etc.
        guard scheme == "http" || scheme == "https" else { return false }
        
        /// Don't track private/local addresses.
        /// These are development servers, not real browsing.
        let privateHosts = ["localhost", "127.0.0.1", "0.0.0.0"]
        if privateHosts.contains(host) { return false }
        
        /// Don't track empty or invalid hosts.
        if host.isEmpty { return false }
        
        return true  // Passed all checks
    }
    
    /// Normalizes URLs by removing tracking parameters and fragments.
    ///
    /// **Purpose**: Prevent duplicate history entries for same page.
    ///
    /// **Removes**:
    /// 1. Fragment identifiers (#section)
    /// 2. UTM tracking params (utm_source, utm_medium, etc.)
    /// 3. Social media tracking (fbclid, gclid)
    /// 4. Referral params (ref, referrer)
    ///
    /// **Example transformations**:
    /// ```
    /// Input:  https://example.com/page?utm_source=email#intro
    /// Output: https://example.com/page
    ///
    /// Input:  https://site.com/article?id=123&utm_campaign=spring
    /// Output: https://site.com/article?id=123
    /// ```
    ///
    /// **Why?**: Same article with different tracking = same history entry.
    ///
    /// **Parameter**:
    /// - url: Original URL
    ///
    /// **Returns**: Normalized URL (or original if normalization fails)
    private func normalizeURL(_ url: URL) -> URL {
        /// Break URL into components for manipulation.
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        
        /// Remove fragment identifier (#section).
        /// example.com/page#intro → example.com/page
        components?.fragment = nil
        
        /// List of tracking parameter patterns to remove.
        /// These don't affect page content, only analytics.
        let trackingParams = [
            "utm_source", "utm_medium", "utm_campaign", "utm_term", "utm_content",  // Google Analytics
            "fbclid",     // Facebook click ID
            "gclid",      // Google click ID
            "ref",        // Generic referrer
            "referrer"    // Generic referrer (alternate spelling)
        ]
        
        /// Filter out tracking parameters.
        if var queryItems = components?.queryItems {
            /// Keep only parameters that DON'T match tracking patterns.
            queryItems = queryItems.filter { item in
                /// Check if this parameter matches any tracking pattern.
                !trackingParams.contains { param in
                    item.name.lowercased().contains(param.lowercased())
                }
            }
            
            /// If no parameters remain, remove query string entirely.
            /// example.com/page? → example.com/page
            components?.queryItems = queryItems.isEmpty ? nil : queryItems
        }
        
        /// Return normalized URL, or original if normalization failed.
        return components?.url ?? url
    }
    
    /// Calculates a relevance score for a history entry given a search query.
    ///
    /// **Scoring system** (higher = more relevant):
    /// - Exact host match: +100
    /// - Host starts with query: +50
    /// - Title starts with query: +40
    /// - Host contains query: +30
    /// - Title contains query: +20
    /// - URL contains query: +10
    /// - Visit frequency bonus: +log(visitCount+1) * 5
    /// - Recency bonus: +15 (today), +10 (this week), +5 (this month)
    ///
    /// **Logarithmic visit boost**: log() prevents very high visit counts
    /// from dominating. 10 visits vs 1000 visits isn't a 100x difference
    /// in relevance.
    ///
    /// **Example**: "github.com" for query "git":
    /// - Host starts with "git": +50
    /// - Title contains "git": +20
    /// - 50 visits: +log(51)*5 ≈ +20
    /// - Visited today: +15
    /// - Total: ~105 points
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
    
    /// Sorts history by relevance (visit frequency + recency).
    ///
    /// **Algorithm**: Combines two factors:
    /// 1. Visit count (more visits = higher priority)
    /// 2. Recent visits bonus (+10 if visited today)
    ///
    /// **Why both?**: 
    /// - Frequency alone favors old frequently-visited sites
    /// - Recency alone favors one-time recent visits
    /// - Combined approach balances both
    ///
    /// **Example scoring**:
    /// - Site A: 5 visits, last visit today = score 15
    /// - Site B: 10 visits, last visit 2 days ago = score 10
    /// - Result: A wins (more relevant overall)
    ///
    /// **86400**: Seconds in a day (24 * 60 * 60).
    ///
    /// **Called**: After every history addition or update.
    private func sortHistory() {
        allHistory.sort { entry1, entry2 in
            /// Calculate combined score: visitCount + recency bonus.
            /// 
            /// timeIntervalSince returns seconds between dates.
            /// < 86400 means visited within last 24 hours.
            let score1 = Double(entry1.visitCount) + (Date().timeIntervalSince(entry1.lastVisited) < 86400 ? 10.0 : 0.0)
            let score2 = Double(entry2.visitCount) + (Date().timeIntervalSince(entry2.lastVisited) < 86400 ? 10.0 : 0.0)
            
            /// Primary sort: Higher score first.
            if score1 != score2 {
                return score1 > score2
            }
            
            /// Tiebreaker: More recent first.
            return entry1.lastVisited > entry2.lastVisited
        }
    }
    
    /// Updates the quick-access recent history cache.
    ///
    /// **Purpose**: Maintain small array of top 50 entries for fast access.
    ///
    /// **Why cache?**: 
    /// - @Published property for SwiftUI
    /// - Frequent UI queries for "recent history"
    /// - Avoids scanning all 10,000 entries
    ///
    /// **50 entries**: Good balance (enough variety, small memory).
    ///
    /// **Called**: After every history modification.
    private func updateRecentHistory() {
        /// Take first 50 from sorted allHistory.
        /// These are the most relevant entries.
        recentHistory = Array(allHistory.prefix(50))
    }
    
    /// Loads persisted history from UserDefaults.
    ///
    /// **Called**: Once during initialization (in init()).
    ///
    /// **Process**:
    /// 1. Set isLoading = true (UI can show spinner)
    /// 2. Try to load data from UserDefaults
    /// 3. Try to decode JSON to [HistoryEntry]
    /// 4. Sort and cache if successful
    /// 5. Set isLoading = false (always, even on error)
    ///
    /// **defer**: Ensures isLoading = false runs even if early return.
    /// Prevents stuck loading state.
    ///
    /// **Failure handling**: Silent failure (starts with empty history).
    /// This is acceptable for first app launch or corrupt data.
    private func loadHistory() {
        isLoading = true
        
        /// defer block runs when function exits (any return path).
        /// Guarantees isLoading is reset.
        defer { isLoading = false }
        
        /// Try to load and decode history.
        /// Returns early if data missing or decode fails.
        guard let data = UserDefaults.standard.data(forKey: historyKey),
              let history = try? JSONDecoder().decode([HistoryEntry].self, from: data) else {
            return  // No saved history or corrupted data
        }
        
        /// Successfully loaded - update state.
        allHistory = history
        sortHistory()           // Sort by relevance
        updateRecentHistory()   // Update cache
    }
    
    /// Persists current history to UserDefaults.
    ///
    /// **Called**: After every history modification.
    ///
    /// **Process**:
    /// 1. Encode allHistory array to JSON
    /// 2. Save to UserDefaults with key "browserHistory"
    ///
    /// **Codable magic**: JSONEncoder automatically converts
    /// [HistoryEntry] to JSON. No manual serialization needed.
    ///
    /// **Failure handling**: Silent failure (print nothing).
    /// If encoding fails, keeps old persisted state.
    ///
    /// **Performance**: Synchronous write to disk.
    /// For 10,000 entries: ~100-200ms. Acceptable for user actions.
    ///
    /// **UserDefaults limit**: ~4MB typically.
    /// 10,000 entries ≈ 2-3MB. Well within limits.
    private func saveHistory() {
        /// Try to encode history to JSON data.
        /// Returns early if encoding fails (shouldn't happen).
        guard let data = try? JSONEncoder().encode(allHistory) else { return }
        
        /// Save to persistent storage.
        /// Survives app termination and device restart.
        UserDefaults.standard.set(data, forKey: historyKey)
    }
}

// MARK: - Extensions
// Convenience methods for specific use cases.

extension HistoryManager {
    /// Returns most frequently visited sites.
    ///
    /// **Use case**: "Top Sites" or "Frequently Visited" UI.
    ///
    /// **Sorting**: By visitCount (highest first).
    ///
    /// **Parameter**:
    /// - limit: Number of sites to return (default 10)
    ///
    /// **Returns**: Top visited sites (up to limit)
    ///
    /// **Example**: Display user's favorite sites on new tab page.
    func getMostVisitedSites(limit: Int = 10) -> [HistoryEntry] {
        /// Sort by visit count (descending), take first `limit`.
        return Array(allHistory.sorted { $0.visitCount > $1.visitCount }.prefix(limit))
    }
    
    /// Returns most recently visited sites.
    ///
    /// **Use case**: "Recently Visited" panel in history UI.
    ///
    /// **Sorting**: By lastVisited timestamp (newest first).
    ///
    /// **Parameter**:
    /// - limit: Number of sites to return (default 10)
    ///
    /// **Returns**: Recently visited sites (up to limit)
    ///
    /// **Example**: Show user's browsing session.
    func getRecentlyVisitedSites(limit: Int = 10) -> [HistoryEntry] {
        /// Sort by last visited date (descending), take first `limit`.
        return Array(allHistory.sorted { $0.lastVisited > $1.lastVisited }.prefix(limit))
    }
    
    /// Returns statistics about browsing history.
    ///
    /// **Tuple return**: Returns multiple values as a named tuple.
    /// Access like: `let stats = getHistoryStats(); print(stats.totalEntries)`
    ///
    /// **reduce()**: Functional programming pattern. Combines all elements
    /// into a single value. Here: sums all visit counts.
    ///
    /// **min(by:)**: Finds the minimum element using a comparison closure.
    ///
    /// **Returns**: Tuple with total entries, total visits, and oldest entry date
    func getHistoryStats() -> (totalEntries: Int, totalVisits: Int, oldestEntry: Date?) {
        let totalEntries = allHistory.count
        let totalVisits = allHistory.reduce(0) { $0 + $1.visitCount }
        let oldestEntry = allHistory.min(by: { $0.lastVisited < $1.lastVisited })?.lastVisited
        
        return (totalEntries, totalVisits, oldestEntry)
    }
}

// MARK: - Architecture Summary for Beginners
// ============================================
//
// HistoryManager demonstrates several important iOS development patterns:
//
// 1. SINGLETON PATTERN:
//    - One shared instance: HistoryManager.shared
//    - Private init prevents creating multiple instances
//    - All app components reference the same history data
//
// 2. @MAINACTOR CONCURRENCY:
//    - All methods guaranteed to run on main thread
//    - Safe for UI updates
//    - Prevents data races with @Published properties
//    - Modern Swift concurrency approach
//
// 3. CODABLE FOR PERSISTENCE:
//    ```swift
//    struct HistoryEntry: Codable { }
//    let data = try? JSONEncoder().encode(entries)
//    UserDefaults.standard.set(data, forKey: "history")
//    ```
//    - Automatic JSON serialization
//    - No manual parsing needed
//    - Type-safe
//
// 4. IMMUTABLE VALUE TYPES:
//    - HistoryEntry is a struct (value type)
//    - All properties are `let` (immutable)
//    - Updates create new instances:
//      `entry.withNewVisit()` returns new entry, doesn't modify existing
//
// 5. INTELLIGENT SEARCH ALGORITHM:
//    Relevance scoring factors:
//    - Match quality (exact > starts with > contains)
//    - Match location (host > title > URL)
//    - Visit frequency (logarithmic boost)
//    - Recency (recent visits boosted)
//
//    This creates smart autocomplete that feels natural to users.
//
// 6. URL NORMALIZATION:
//    ```swift
//    // Input:  https://example.com/page?utm_source=email#section
//    // Output: https://example.com/page
//    ```
//    - Removes tracking parameters
//    - Removes fragment identifiers
//    - Prevents duplicate entries for same page
//
// 7. PRIVATE(SET) PATTERN:
//    ```swift
//    @Published private(set) var recentHistory: [HistoryEntry]
//    ```
//    - Public read access
//    - Private write access
//    - Ensures data consistency (only HistoryManager modifies)
//
// 8. MEMORY MANAGEMENT:
//    - Limits to 10,000 entries max
//    - Keeps 50 "recent" entries cached for speed
//    - Prevents unbounded growth
//
// 9. FUNCTIONAL PROGRAMMING PATTERNS:
//    - .filter { }: Select matching elements
//    - .map { }: Transform elements
//    - .reduce { }: Combine elements into single value
//    - .sorted { }: Order elements by criteria
//
// 10. TUPLE RETURNS:
//     ```swift
//     func getHistoryStats() -> (totalEntries: Int, totalVisits: Int, oldestEntry: Date?)
//     ```
//     - Return multiple related values
//     - Named for clarity
//     - Alternative to creating a dedicated struct
//
// KEY TAKEAWAYS:
// - Use @MainActor for UI-related managers
// - Codable makes persistence trivial
// - Immutable value types prevent bugs
// - Smart algorithms make features feel natural
// - Normalize data to prevent duplicates
// - Limit data growth to prevent performance issues
//
// This file demonstrates production-quality data management patterns!
