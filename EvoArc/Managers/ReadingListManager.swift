//
//  ReadingListManager.swift
//  EvoArc
//
//  Manages the user's Reading List — pages saved for later reading.
//
//  Mirrors the persistence approach used by HistoryManager/BookmarkManager:
//  a Codable array written as JSON to the app's Application Support directory.
//

import Foundation
import Combine

/// A single saved page in the Reading List.
struct ReadingItem: Codable, Identifiable, Hashable {
    let id: UUID
    let title: String
    let url: URL
    let dateAdded: Date

    init(id: UUID = UUID(), title: String, url: URL, dateAdded: Date = Date()) {
        self.id = id
        self.title = title.isEmpty ? (url.host ?? url.absoluteString) : title
        self.url = url
        self.dateAdded = dateAdded
    }
}

/// Stores and persists the Reading List. Runs on the main thread for UI safety.
@MainActor
final class ReadingListManager: ObservableObject {
    static let shared = ReadingListManager()

    /// All saved items, most recently added first.
    @Published private(set) var savedItems: [ReadingItem] = []

    /// File location: Application Support/EvoArc/ReadingList.json
    private var fileURL: URL {
        let paths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let directory = paths[0].appendingPathComponent("EvoArc", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("ReadingList.json")
    }

    private init() {
        load()
    }

    // MARK: - Public API

    /// Saves a page. No-ops if the URL is already saved.
    func addItem(title: String, url: URL) {
        guard !isSaved(url: url) else { return }
        let item = ReadingItem(title: title, url: url)
        savedItems.insert(item, at: 0)
        save()
    }

    /// Removes a saved item by id.
    func removeItem(id: UUID) {
        savedItems.removeAll { $0.id == id }
        save()
    }

    /// Removes every saved item.
    func clearAll() {
        savedItems.removeAll()
        save()
    }

    /// Whether a URL is already in the Reading List (compared by absolute string).
    func isSaved(url: URL) -> Bool {
        savedItems.contains { $0.url.absoluteString == url.absoluteString }
    }

    // MARK: - Persistence

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([ReadingItem].self, from: data) else {
            return
        }
        savedItems = decoded.sorted { $0.dateAdded > $1.dateAdded }
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(savedItems)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            dlog("❌ Failed to save Reading List: \(error)")
        }
    }
}
