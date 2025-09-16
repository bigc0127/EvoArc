//
//  DoHSettingsManager.swift
//  EvoArc
//
//  DNS over HTTPS settings management and integration
//

// DoH removed: minimal stub retained for compatibility
import Foundation
import WebKit
import Combine

@MainActor
final class DoHSettingsManager: ObservableObject {
    static let shared = DoHSettingsManager()
    @Published private(set) var isActive: Bool = false
    @Published private(set) var hasPermission: Bool = false
    private init() {}
    func createWebViewConfiguration() -> WKWebViewConfiguration { WKWebViewConfiguration() }
    var statusDescription: String { "Removed" }
    var detailedStatus: String { "DNS over HTTPS has been removed. Use the new Ad Blocking feature in Settings instead." }
}
