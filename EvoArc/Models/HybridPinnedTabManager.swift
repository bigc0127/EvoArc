//
//  HybridPinnedTabManager.swift
//  EvoArc
//
//  Created on 2025-09-06.
//  Combines CloudKit sync with safe local fallback
//

import Foundation
import SwiftUI
import Combine

class HybridPinnedTabManager: ObservableObject {
    static let shared = HybridPinnedTabManager()
    
    @Published var pinnedTabs: [PinnedTabEntity] = []
    
    private let cloudKitManager: CloudKitPinnedTabManager
    private let safeManager: SafePinnedTabManager
    private var cancellables = Set<AnyCancellable>()
    
    // Track which manager is currently active
    @Published private(set) var isUsingCloudKit: Bool = false
    
    private init() {
        self.cloudKitManager = CloudKitPinnedTabManager.shared
        self.safeManager = SafePinnedTabManager.shared
        
        setupManagers()
    }
    
    // MARK: - Public Methods
    
    func pinTab(url: URL, title: String) {
        if isUsingCloudKit {
            cloudKitManager.pinTab(url: url, title: title)
        } else {
            safeManager.pinTab(url: url, title: title)
            // Convert to entity for consistency
            let entity = PinnedTabEntity(
                urlString: url.absoluteString,
                title: title,
                isPinned: true,
                createdAt: Date(),
                pinnedOrder: Int16(pinnedTabs.count)
            )
            pinnedTabs.append(entity)
        }
    }
    
    func unpinTab(url: URL) {
        if isUsingCloudKit {
            cloudKitManager.unpinTab(url: url)
        } else {
            safeManager.unpinTab(url: url)
            pinnedTabs.removeAll { $0.urlString == url.absoluteString }
        }
    }
    
    func isTabPinned(url: URL) -> Bool {
        if isUsingCloudKit {
            return cloudKitManager.isTabPinned(url: url)
        } else {
            return safeManager.isTabPinned(url: url)
        }
    }
    
    func reorderPinnedTabs(_ entities: [PinnedTabEntity]) {
        pinnedTabs = entities
        
        if isUsingCloudKit {
            cloudKitManager.reorderPinnedTabs(entities)
        }
        // SafeManager doesn't support ordering, so we just update local state
    }
    
    // MARK: - Private Methods
    
    private func setupManagers() {
        // Start with safe manager immediately
        syncFromSafeManager()
        
        // Monitor CloudKit manager readiness
        cloudKitManager.$isReady
            .sink { [weak self] isReady in
                if isReady {
                    self?.switchToCloudKit()
                }
            }
            .store(in: &cancellables)
        
        // Monitor CloudKit data changes
        cloudKitManager.$pinnedTabs
            .sink { [weak self] entities in
                if self?.isUsingCloudKit == true {
                    self?.pinnedTabs = entities
                }
            }
            .store(in: &cancellables)
        
        // Monitor safe manager changes (fallback)
        safeManager.$pinnedTabs
            .sink { [weak self] urlStrings in
                if self?.isUsingCloudKit == false {
                    self?.syncFromSafeManager()
                }
            }
            .store(in: &cancellables)
    }
    
    private func switchToCloudKit() {
        print("🔄 Switching to CloudKit sync...")
        
        // Migrate existing data from safe manager to CloudKit
        migrateToCloudKit()
        
        // Switch active manager
        isUsingCloudKit = true
        pinnedTabs = cloudKitManager.pinnedTabs
        
        print("✅ Now using CloudKit sync")
    }
    
    private func migrateToCloudKit() {
        // Get existing URLs from safe manager
        let existingURLs = safeManager.pinnedTabs
        let cloudKitURLs = Set(cloudKitManager.pinnedTabs.map { $0.urlString })
        
        // Add any URLs that aren't in CloudKit yet
        for urlString in existingURLs {
            if !cloudKitURLs.contains(urlString), let url = URL(string: urlString) {
                cloudKitManager.pinTab(url: url, title: "Migrated Tab")
                print("🔄 Migrated tab to CloudKit: \(urlString)")
            }
        }
    }
    
    private func syncFromSafeManager() {
        let urlStrings = safeManager.pinnedTabs
        pinnedTabs = urlStrings.enumerated().map { index, urlString in
            PinnedTabEntity(
                urlString: urlString,
                title: "Pinned Tab",
                isPinned: true,
                createdAt: Date(),
                pinnedOrder: Int16(index)
            )
        }
    }
    
    // MARK: - Debug Methods
    
    func getCurrentManagerStatus() -> String {
        if isUsingCloudKit {
            return "CloudKit (Ready: \(cloudKitManager.isReady), Count: \(cloudKitManager.pinnedTabs.count))"
        } else {
            return "SafeManager (Count: \(safeManager.pinnedTabs.count))"
        }
    }
}
