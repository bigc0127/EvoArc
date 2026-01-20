//
//  SafePinnedTabManager.swift
//  EvoArc
//
//  Created on 2025-09-06.
//  Minimal implementation to prevent Xcode crashes
//

import Foundation
import SwiftUI
import Combine

class SafePinnedTabManager: ObservableObject {
    static let shared = SafePinnedTabManager()
    
    @Published var pinnedTabs: [String] = [] // Just store URLs as strings for now
    
    private let persistenceKey = "safe_pinned_tabs"
    
    private init() {
        loadPinnedTabs()
    }
    
    func pinTab(url: URL, title: String) {
        if !pinnedTabs.contains(url.absoluteString) {
            pinnedTabs.append(url.absoluteString)
            savePinnedTabs()
            print("✅ Pinned tab: \(title)")
        }
    }
    
    func unpinTab(url: URL) {
        pinnedTabs.removeAll { $0 == url.absoluteString }
        savePinnedTabs()
        print("📌 Unpinned tab: \(url.absoluteString)")
    }
    
    func isTabPinned(url: URL) -> Bool {
        return pinnedTabs.contains(url.absoluteString)
    }
    
    // MARK: - Persistence
    
    private func savePinnedTabs() {
        UserDefaults.standard.set(pinnedTabs, forKey: persistenceKey)
    }
    
    private func loadPinnedTabs() {
        if let saved = UserDefaults.standard.array(forKey: persistenceKey) as? [String] {
            pinnedTabs = saved
        }
    }
}
