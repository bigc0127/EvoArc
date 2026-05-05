//
//  HybridPinnedTabManager.swift
//  EvoArc
//
//  Thin facade over CloudKitPinnedTabManager. The original two-tier
//  (UserDefaults + CloudKit) hybrid was removed once CloudKit-backed
//  Core Data became the single source of truth; legacy UserDefaults
//  pins migrate on first launch (see CloudKitPinnedTabManager).
//

import Foundation
import SwiftUI
import Combine

class HybridPinnedTabManager: ObservableObject {
    static let shared = HybridPinnedTabManager()

    @Published var pinnedTabs: [PinnedTabEntity] = []
    @Published private(set) var isUsingCloudKit: Bool = false

    private let cloudKitManager: CloudKitPinnedTabManager
    private var cancellables = Set<AnyCancellable>()

    private init() {
        self.cloudKitManager = CloudKitPinnedTabManager.shared

        cloudKitManager.$pinnedTabs
            .receive(on: DispatchQueue.main)
            .assign(to: \.pinnedTabs, on: self)
            .store(in: &cancellables)

        cloudKitManager.$isReady
            .receive(on: DispatchQueue.main)
            .assign(to: \.isUsingCloudKit, on: self)
            .store(in: &cancellables)
    }

    func pinTab(url: URL, title: String) {
        cloudKitManager.pinTab(url: url, title: title)
    }

    func unpinTab(url: URL) {
        cloudKitManager.unpinTab(url: url)
    }

    func isTabPinned(url: URL) -> Bool {
        cloudKitManager.isTabPinned(url: url)
    }

    func reorderPinnedTabs(_ entities: [PinnedTabEntity]) {
        cloudKitManager.reorderPinnedTabs(entities)
    }

    func getCurrentManagerStatus() -> String {
        "CloudKit (Ready: \(cloudKitManager.isReady), Count: \(cloudKitManager.pinnedTabs.count))"
    }
}
