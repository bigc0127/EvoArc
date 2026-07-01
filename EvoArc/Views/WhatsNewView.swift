//
//  WhatsNewView.swift
//  EvoArc
//
//  A one-time "What's New" welcome screen shown on the first launch after an
//  update that introduces new features. Gated by BrowserSettings.lastWhatsNewVersion.
//

import SwiftUI

/// One feature entry in the What's New list.
struct WhatsNewFeature: Identifiable {
    let id = UUID()
    let symbol: String
    let title: String
    let blurb: String
}

struct WhatsNewView: View {
    @Environment(\.dismiss) private var dismiss

    /// Bump this token whenever there's a new batch of features to announce.
    static let currentVersion = "2026.07-reading-sessions-find"

    /// Whether the greeter should be shown now (i.e. not yet seen for this release).
    static var shouldPresent: Bool {
        BrowserSettings.shared.lastWhatsNewVersion != currentVersion
    }

    /// Record that the current release's greeter has been shown.
    static func markSeen() {
        BrowserSettings.shared.lastWhatsNewVersion = currentVersion
    }

    static let features: [WhatsNewFeature] = [
        WhatsNewFeature(symbol: "square.stack.3d.up.fill",
                        title: "Session Manager",
                        blurb: "Save a whole set of tabs as a named session and restore your workspace anytime."),
        WhatsNewFeature(symbol: "book.fill",
                        title: "Reading List",
                        blurb: "Save articles and pages for later reading with a single tap."),
        WhatsNewFeature(symbol: "magnifyingglass",
                        title: "Find on Page",
                        blurb: "Search within any page using the native iOS find bar, with match navigation."),
        WhatsNewFeature(symbol: "checkmark.shield.fill",
                        title: "Site Privacy Panel",
                        blurb: "See a page's security, blocking, and JavaScript status — and toggle JavaScript per site."),
        WhatsNewFeature(symbol: "link",
                        title: "Link Sanitizer",
                        blurb: "Tracking parameters like utm_* and fbclid are stripped from links you tap.")
    ]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 44))
                            .foregroundStyle(.tint)
                            .padding(.top, 32)
                        Text("What's New in EvoArc")
                            .font(.largeTitle.bold())
                            .multilineTextAlignment(.center)
                        Text("Here's what's new in this update.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    VStack(spacing: 20) {
                        ForEach(Self.features) { feature in
                            HStack(alignment: .top, spacing: 16) {
                                Image(systemName: feature.symbol)
                                    .font(.title2)
                                    .foregroundStyle(.tint)
                                    .frame(width: 36, height: 36)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(feature.title)
                                        .font(.headline)
                                    Text(feature.blurb)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer(minLength: 0)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 24)
            }

            Button {
                Self.markSeen()
                dismiss()
            } label: {
                Text("Get Started")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
        .interactiveDismissDisabled(false)
        .onDisappear {
            // Ensure it's marked seen even if dismissed by swipe.
            Self.markSeen()
        }
    }
}
