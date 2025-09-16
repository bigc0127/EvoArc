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
    
    private init() {
        // Minimal, crash-safe initialization
    }
    
    func pinTab(url: URL, title: String) {
        if !pinnedTabs.contains(url.absoluteString) {
            pinnedTabs.append(url.absoluteString)
            print("✅ Pinned tab: \(title)")
        }
    }
    
    func unpinTab(url: URL) {
        pinnedTabs.removeAll { $0 == url.absoluteString }
        print("📌 Unpinned tab: \(url.absoluteString)")
    }
    
    func isTabPinned(url: URL) -> Bool {
        return pinnedTabs.contains(url.absoluteString)
    }
}
