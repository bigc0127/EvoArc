//
//  BookmarkManager.swift
//  EvoArc
//
//  Created on 2025-09-16.
//

import Foundation
import SwiftUI
import Combine

// MARK: - Bookmark Models

struct Bookmark: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var url: URL
    var folderID: UUID?
    let dateAdded: Date
    var dateModified: Date
    var faviconData: Data?
    
    init(title: String, url: URL, folderID: UUID? = nil, faviconData: Data? = nil) {
        self.id = UUID()
        self.title = title
        self.url = url
        self.folderID = folderID
        self.dateAdded = Date()
        self.dateModified = Date()
        self.faviconData = faviconData
    }
}

struct BookmarkFolder: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    let dateCreated: Date
    var dateModified: Date
    
    init(name: String) {
        self.id = UUID()
        self.name = name
        self.dateCreated = Date()
        self.dateModified = Date()
    }
}

// MARK: - BookmarkManager

class BookmarkManager: ObservableObject {
    static let shared = BookmarkManager()
    
    @Published var bookmarks: [Bookmark] = []
    @Published var folders: [BookmarkFolder] = []
    @Published var isLoading = false
    
    private let userDefaults = UserDefaults.standard
    private let bookmarksKey = "SavedBookmarks"
    private let foldersKey = "BookmarkFolders"
    
    private init() {
        loadBookmarks()
    }
    
    // MARK: - Persistence
    
    private func saveBookmarks() {
        do {
            let bookmarksData = try JSONEncoder().encode(bookmarks)
            let foldersData = try JSONEncoder().encode(folders)
            
            userDefaults.set(bookmarksData, forKey: bookmarksKey)
            userDefaults.set(foldersData, forKey: foldersKey)
            
            print("📚 Saved \(bookmarks.count) bookmarks and \(folders.count) folders")
        } catch {
            print("❌ Failed to save bookmarks: \(error)")
        }
    }
    
    private func loadBookmarks() {
        isLoading = true
        
        // Load folders first
        if let foldersData = userDefaults.data(forKey: foldersKey) {
            do {
                folders = try JSONDecoder().decode([BookmarkFolder].self, from: foldersData)
            } catch {
                print("❌ Failed to load bookmark folders: \(error)")
                folders = []
            }
        }
        
        // Load bookmarks
        if let bookmarksData = userDefaults.data(forKey: bookmarksKey) {
            do {
                bookmarks = try JSONDecoder().decode([Bookmark].self, from: bookmarksData)
            } catch {
                print("❌ Failed to load bookmarks: \(error)")
                bookmarks = []
            }
        }
        
        print("📚 Loaded \(bookmarks.count) bookmarks and \(folders.count) folders")
        
        // Create default "Favorites" folder if none exist
        if folders.isEmpty {
            _ = createFolder(name: "Favorites")
        }
        
        isLoading = false
    }
    
    // MARK: - Bookmark Operations
    
    func addBookmark(title: String, url: URL, folderID: UUID? = nil) {
        // Check if bookmark already exists
        if bookmarks.contains(where: { $0.url == url }) {
            print("📚 Bookmark already exists for URL: \(url)")
            return
        }
        
        let bookmark = Bookmark(title: title, url: url, folderID: folderID)
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            bookmarks.append(bookmark)
        }
        
        saveBookmarks()
        
        print("📚 Added bookmark: \(title) -> \(url)")
    }
    
    func removeBookmark(_ bookmark: Bookmark) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            bookmarks.removeAll { $0.id == bookmark.id }
        }
        
        saveBookmarks()
        
        print("📚 Removed bookmark: \(bookmark.title)")
    }
    
    func updateBookmark(_ bookmark: Bookmark, title: String? = nil, folderID: UUID? = nil) {
        guard let index = bookmarks.firstIndex(where: { $0.id == bookmark.id }) else { return }
        
        if let title = title {
            bookmarks[index].title = title
        }
        
        if folderID != nil {
            bookmarks[index].folderID = folderID
        }
        
        bookmarks[index].dateModified = Date()
        
        saveBookmarks()
        
        print("📚 Updated bookmark: \(bookmarks[index].title)")
    }
    
    func isBookmarked(url: URL) -> Bool {
        return bookmarks.contains { $0.url == url }
    }
    
    func getBookmark(for url: URL) -> Bookmark? {
        return bookmarks.first { $0.url == url }
    }
    
    // MARK: - Folder Operations
    
    func createFolder(name: String) -> BookmarkFolder {
        let folder = BookmarkFolder(name: name)
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            folders.append(folder)
        }
        
        saveBookmarks()
        
        print("📚 Created folder: \(name)")
        return folder
    }
    
    func removeFolder(_ folder: BookmarkFolder, moveBookmarksToFolder: UUID? = nil) {
        // Move or remove bookmarks in this folder
        let bookmarksInFolder = bookmarks.filter { $0.folderID == folder.id }
        
        for bookmark in bookmarksInFolder {
            updateBookmark(bookmark, folderID: moveBookmarksToFolder)
        }
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            folders.removeAll { $0.id == folder.id }
        }
        
        saveBookmarks()
        
        print("📚 Removed folder: \(folder.name)")
    }
    
    func renameFolder(_ folder: BookmarkFolder, newName: String) {
        guard let index = folders.firstIndex(where: { $0.id == folder.id }) else { return }
        
        folders[index].name = newName
        folders[index].dateModified = Date()
        
        saveBookmarks()
        
        print("📚 Renamed folder to: \(newName)")
    }
    
    // MARK: - Query Operations
    
    func getBookmarks(in folder: BookmarkFolder) -> [Bookmark] {
        return bookmarks.filter { $0.folderID == folder.id }
    }
    
    func getUngroupedBookmarks() -> [Bookmark] {
        return bookmarks.filter { $0.folderID == nil }
    }
    
    func searchBookmarks(query: String) -> [Bookmark] {
        guard !query.isEmpty else { return bookmarks }
        
        let lowercasedQuery = query.lowercased()
        return bookmarks.filter {
            $0.title.lowercased().contains(lowercasedQuery) ||
            $0.url.absoluteString.lowercased().contains(lowercasedQuery) ||
            $0.url.host?.lowercased().contains(lowercasedQuery) == true
        }
    }
    
    var favoritesFolder: BookmarkFolder? {
        return folders.first { $0.name == "Favorites" }
    }
    
    // MARK: - Import/Export (Future enhancement)
    
    func exportBookmarks() -> String? {
        // HTML bookmarks format for future implementation
        return nil
    }
    
    func importBookmarks(from data: Data) {
        // Import from HTML or JSON for future implementation
    }
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let bookmarkAdded = Notification.Name("bookmarkAdded")
    static let bookmarkRemoved = Notification.Name("bookmarkRemoved")
}