//
//  SitePrivacyView.swift
//  EvoArc
//
//  An honest, at-a-glance privacy & security panel for the current page. Shows
//  real signals only (no fabricated tracker counts): connection security,
//  whether ad/tracker blocking is active, per-site JavaScript state (toggleable),
//  and whether link sanitizing is on.
//

import SwiftUI
import WebKit

struct SitePrivacyView: View {
    @ObservedObject var tabManager: TabManager
    @ObservedObject private var settings = BrowserSettings.shared
    @ObservedObject private var jsManager = JavaScriptBlockingManager.shared
    @Environment(\.dismiss) private var dismiss

    private var url: URL? { tabManager.selectedTab?.url }

    private var isSecure: Bool { url?.scheme?.lowercased() == "https" }

    private var adBlockActive: Bool {
        guard settings.adBlockEnabled else { return false }
        // The app intentionally skips ad blocking on DuckDuckGo.
        return url?.host?.contains("duckduckgo.com") != true
    }

    private var jsBlocked: Bool {
        guard let url = url else { return false }
        return jsManager.isJavaScriptBlocked(for: url)
    }

    var body: some View {
        NavigationView {
            List {
                Section {
                    HStack(spacing: 10) {
                        Image(systemName: isSecure ? "lock.fill" : "lock.open.fill")
                            .foregroundColor(isSecure ? .green : .orange)
                        VStack(alignment: .leading) {
                            Text(url?.host ?? "This Page")
                                .font(.headline)
                                .lineLimit(1)
                            Text(isSecure ? "Secure connection (HTTPS)" : "Not a secure connection")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Protections") {
                    statusRow(icon: "shield.lefthalf.filled",
                              title: "Ad & Tracker Blocking",
                              value: adBlockActive ? "On" : "Off",
                              on: adBlockActive)
                    statusRow(icon: "link",
                              title: "Link Sanitizer",
                              value: settings.stripTrackingParams ? "On" : "Off",
                              on: settings.stripTrackingParams)
                }

                if url != nil {
                    Section {
                        Toggle(isOn: Binding(
                            get: { jsBlocked },
                            set: { _ in toggleJavaScript() }
                        )) {
                            Label("Block JavaScript on this site", systemImage: "curlybraces")
                        }
                    } footer: {
                        Text("Blocking JavaScript can break some sites. The page reloads when you change this.")
                    }
                }
            }
            .navigationTitle("Site Privacy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func statusRow(icon: String, title: String, value: String, on: Bool) -> some View {
        HStack {
            Label(title, systemImage: icon)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(on ? .green : .secondary)
        }
    }

    private func toggleJavaScript() {
        guard let url = url else { return }
        jsManager.toggleJavaScriptBlocking(for: url)
        // Reload so the new JavaScript preference takes effect for this page.
        tabManager.currentWebView?.reload()
    }
}
