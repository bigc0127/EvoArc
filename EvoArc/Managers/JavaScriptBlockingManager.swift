//
//  JavaScriptBlockingManager.swift
//  EvoArc
//
//  Created on 2025-09-16.
//

import Foundation
import Combine

/// Manages per-site JavaScript blocking settings
@MainActor
final class JavaScriptBlockingManager: ObservableObject {
    static let shared = JavaScriptBlockingManager()
    
    @Published private(set) var blockedSites: Set<String> = []
    
    private let userDefaults = UserDefaults.standard
    private let blockedSitesKey = "blockedJavaScriptSites"
    
    private init() {
        loadBlockedSites()
    }
    
    /// Check if JavaScript should be blocked for a given URL
    func isJavaScriptBlocked(for url: URL) -> Bool {
        guard let host = url.host else { return false }
        return blockedSites.contains(host)
    }
    
    /// Block JavaScript for a site
    func blockJavaScript(for url: URL) {
        guard let host = url.host else { return }
        blockedSites.insert(host)
        saveBlockedSites()
    }
    
    /// Unblock JavaScript for a site
    func unblockJavaScript(for url: URL) {
        guard let host = url.host else { return }
        blockedSites.remove(host)
        saveBlockedSites()
    }
    
    /// Toggle JavaScript blocking for a site
    func toggleJavaScriptBlocking(for url: URL) {
        if isJavaScriptBlocked(for: url) {
            unblockJavaScript(for: url)
        } else {
            blockJavaScript(for: url)
        }
    }
    
    /// Get all blocked sites
    func getAllBlockedSites() -> [String] {
        return Array(blockedSites).sorted()
    }
    
    /// Clear all blocked sites
    func clearAllBlockedSites() {
        blockedSites.removeAll()
        saveBlockedSites()
    }
    
    /// Remove a specific blocked site
    func removeBlockedSite(_ host: String) {
        blockedSites.remove(host)
        saveBlockedSites()
    }
    
    // MARK: - Private Methods
    
    private func loadBlockedSites() {
        if let sitesArray = userDefaults.array(forKey: blockedSitesKey) as? [String] {
            blockedSites = Set(sitesArray)
        }
    }
    
    private func saveBlockedSites() {
        userDefaults.set(Array(blockedSites), forKey: blockedSitesKey)
    }
}