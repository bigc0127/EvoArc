//
//  URLSanitizer.swift
//  EvoArc
//
//  Strips common tracking/analytics query parameters (utm_*, fbclid, gclid, …)
//  from URLs before navigation, for a small privacy win. Purely functional —
//  no state, no persistence.
//

import Foundation

enum URLSanitizer {
    /// Exact-match tracking parameter names to remove.
    private static let exactParams: Set<String> = [
        "fbclid", "gclid", "dclid", "gclsrc", "msclkid", "mc_eid", "mc_cid",
        "igshid", "twclid", "yclid", "wickedid", "vero_id", "oly_anon_id",
        "oly_enc_id", "_hsenc", "_hsmi", "hsctatracking", "mkt_tok",
        "ref_src", "ref_url", "spm"
    ]

    /// Prefix-match tracking parameter families to remove (e.g. any "utm_*").
    private static let prefixParams: [String] = [
        "utm_", "pk_", "piwik_", "matomo_", "ga_", "__hs"
    ]

    /// Returns the URL with tracking parameters removed, plus the names removed.
    /// If nothing is removed (or the URL can't be decomposed) the original URL is returned.
    static func sanitize(_ url: URL) -> (url: URL, removed: [String]) {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let items = components.queryItems, !items.isEmpty else {
            return (url, [])
        }

        var removed: [String] = []
        let kept = items.filter { item in
            if isTracking(item.name) {
                removed.append(item.name)
                return false
            }
            return true
        }

        guard !removed.isEmpty else { return (url, []) }

        components.queryItems = kept.isEmpty ? nil : kept
        // Fall back to the original URL if recomposition somehow fails.
        return (components.url ?? url, removed)
    }

    private static func isTracking(_ name: String) -> Bool {
        let lower = name.lowercased()
        if exactParams.contains(lower) { return true }
        return prefixParams.contains { lower.hasPrefix($0) }
    }
}
