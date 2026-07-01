//
//  SessionManager.swift
//  EvoArc
//
//  Save and restore whole browsing sessions (a named set of tabs). Lets users
//  capture a workspace of tabs and bring it back later.
//
//  Persistence mirrors HistoryManager: a Codable array written as JSON to the
//  app's Application Support directory.
//

import Foundation
import Combine

/// A lightweight snapshot of a single tab within a saved session.
struct TabSnapshot: Codable, Hashable {
    let urlString: String
    let title: String
    let engine: String        // BrowserEngine rawValue ("webkit" / "blink")
    let isPinned: Bool
    let groupID: String?      // UUID string of the tab's group, if any

    var url: URL? { URL(string: urlString) }
}

/// A named, restorable collection of tabs.
struct BrowserSession: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    let dateCreated: Date
    var dateModified: Date
    let tabs: [TabSnapshot]
    let selectedIndex: Int

    var tabCount: Int { tabs.count }
}

@MainActor
final class SessionManager: ObservableObject {
    static let shared = SessionManager()

    /// All saved sessions, most recently modified first.
    @Published private(set) var sessions: [BrowserSession] = []

    private var fileURL: URL {
        let paths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let directory = paths[0].appendingPathComponent("EvoArc", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("Sessions.json")
    }

    private init() {
        load()
    }

    // MARK: - Save

    /// Captures the current tabs as a new named session.
    /// Skips the empty "new tab page" placeholder tabs (nothing to restore).
    @discardableResult
    func saveSession(name: String, tabManager: TabManager) -> Bool {
        var snapshots: [TabSnapshot] = []
        var selectedIndex = 0

        for tab in tabManager.tabs {
            guard let urlString = tab.url?.absoluteString,
                  !urlString.isEmpty,
                  urlString != "evoarc://newtab" else { continue }
            if tab.id == tabManager.selectedTab?.id {
                selectedIndex = snapshots.count
            }
            snapshots.append(TabSnapshot(
                urlString: urlString,
                title: tab.title,
                engine: tab.browserEngine.rawValue,
                isPinned: tab.isPinned,
                groupID: tab.groupID?.uuidString
            ))
        }

        guard !snapshots.isEmpty else { return false }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let now = Date()
        let session = BrowserSession(
            id: UUID(),
            name: trimmedName.isEmpty ? defaultSessionName() : trimmedName,
            dateCreated: now,
            dateModified: now,
            tabs: snapshots,
            selectedIndex: selectedIndex
        )
        sessions.insert(session, at: 0)
        save()
        return true
    }

    private func defaultSessionName() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return "Session — \(formatter.string(from: Date()))"
    }

    // MARK: - Restore

    /// Opens all tabs from a session. Group assignments are preserved only when the
    /// referenced group still exists; otherwise the tab is restored ungrouped.
    func restoreSession(_ session: BrowserSession, into tabManager: TabManager) {
        var tabsToSelect: Tab?
        for (index, snap) in session.tabs.enumerated() {
            guard let url = snap.url else { continue }
            let engine = BrowserEngine(rawValue: snap.engine)
            var groupID: UUID? = nil
            if let groupString = snap.groupID,
               let candidate = UUID(uuidString: groupString),
               tabManager.tabGroups.contains(where: { $0.id == candidate }) {
                groupID = candidate
            }
            let tab = tabManager.createRestoredTab(
                title: snap.title,
                url: url,
                isPinned: snap.isPinned,
                groupID: groupID,
                engine: engine
            )
            if index == session.selectedIndex {
                tabsToSelect = tab
            }
        }
        if let tab = tabsToSelect {
            tabManager.selectTab(tab)
        }
    }

    // MARK: - Manage

    func deleteSession(id: UUID) {
        sessions.removeAll { $0.id == id }
        save()
    }

    func renameSession(id: UUID, to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let index = sessions.firstIndex(where: { $0.id == id }) else { return }
        sessions[index].name = trimmed
        sessions[index].dateModified = Date()
        sessions.sort { $0.dateModified > $1.dateModified }
        save()
    }

    func clearAll() {
        sessions.removeAll()
        save()
    }

    // MARK: - Persistence

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([BrowserSession].self, from: data) else {
            return
        }
        sessions = decoded.sorted { $0.dateModified > $1.dateModified }
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(sessions)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            dlog("❌ Failed to save Sessions: \(error)")
        }
    }
}
