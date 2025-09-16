//
//  DoHSettingsManager.swift (Stub)
//  EvoArc
//
//  DNS over HTTPS has been removed from EvoArc. This file provides a minimal
//  stub to satisfy references that may still exist in views. All APIs are no-op.
//

#if false
import Foundation
import WebKit
import Combine

@MainActor
final class DoHSettingsManager_Deprecated: ObservableObject {
    static let shared = DoHSettingsManager_Deprecated()
    @Published private(set) var isActive: Bool = false
    @Published private(set) var hasPermission: Bool = false
    private init() {}
    func createWebViewConfiguration() -> WKWebViewConfiguration { WKWebViewConfiguration() }
    var statusDescription: String { "Removed" }
    var detailedStatus: String { "DNS over HTTPS has been removed. Use the new Ad Blocking feature in Settings instead." }
}
#endif
