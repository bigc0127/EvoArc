//
//  AdBlockManager.swift
//  EvoArc
//
//  Lightweight content-blocking based ad blocker using WKContentRuleList.
//  Fetches FOSS host lists, converts them to WebKit content rules, and
//  applies them to all newly created web views.
//

import Foundation
import WebKit
import Combine

@MainActor
final class AdBlockManager: ObservableObject {
    static let shared = AdBlockManager()
    
    // MARK: - Public Types
    enum Subscription: String, CaseIterable, Identifiable {
        case easyList
        case easyListPrivacy
        case peterLowe
        case adAway
        case oneHostsLite
        case stevenBlack
        
        var id: String { rawValue }
        
        var displayName: String {
            switch self {
            case .easyList: return "EasyList"
            case .easyListPrivacy: return "EasyList Privacy"
            case .peterLowe: return "Peter Lowe's List"
            case .adAway: return "AdAway Hosts"
            case .oneHostsLite: return "1Hosts (Lite)"
            case .stevenBlack: return "StevenBlack (basic)"
            }
        }
        
        var description: String {
            switch self {
            case .easyList: return "General purpose ad blocking rules"
            case .easyListPrivacy: return "Additional privacy protection rules"
            case .peterLowe: return "Compact list of common ad and tracking domains"
            case .adAway: return "Mobile-focused ad and malware domains"
            case .oneHostsLite: return "Lightweight curated host list"
            case .stevenBlack: return "Combined reputable hosts list (large)"
            }
        }
        
        // Host-format list URLs (plaintext) and ABP lists
        var url: URL {
            switch self {
            case .easyList:
                return URL(string: "https://easylist.to/easylist/easylist.txt")!
            case .easyListPrivacy:
                return URL(string: "https://easylist.to/easylist/easyprivacy.txt")!
            case .peterLowe:
                return URL(string: "https://pgl.yoyo.org/adservers/serverlist.php?hostformat=hosts&showintro=0&mimetype=plaintext")!
            case .adAway:
                return URL(string: "https://adaway.org/hosts.txt")!
            case .oneHostsLite:
                return URL(string: "https://raw.githubusercontent.com/badmojr/1Hosts/master/Lite/hosts.txt")!
            case .stevenBlack:
                return URL(string: "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts")!
            }
        }
    }
    
    // MARK: - Published State
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var activeRuleCount: Int = 0
    @Published private(set) var isUpdating: Bool = false
    
    // MARK: - Storage
    private let store = WKContentRuleListStore.default()
    private let ruleIdentifier = "EvoArc-AdBlock"
    private var compiledRuleList: WKContentRuleList?
    private var cancellables = Set<AnyCancellable>()
    
    // Retain the latest selector list parsed from EasyList/custom lists for dynamic hiding
    private var currentDynamicSelectors: [String] = []
    
    private init() {}
    
    // MARK: - Lifecycle
    func refreshOnLaunchIfNeeded() {
        let settings = BrowserSettings.shared
        guard settings.adBlockEnabled, settings.adBlockAutoUpdateOnLaunch else { return }
        Task { await updateSubscriptions(force: false) }
    }
    
    // MARK: - Public API
    func updateSubscriptions(force: Bool) async {
        guard !isUpdating else { return }
        isUpdating = true
        defer { isUpdating = false }
        
        let settings = BrowserSettings.shared
        guard settings.adBlockEnabled else {
            await removeRuleList()
            return
        }
        
        let selected = settings.selectedAdBlockListsEnum
        if selected.isEmpty && settings.customAdBlockListURLs.isEmpty { await removeRuleList(); return }
        
        // Map list -> URL
        func listURL(_ list: AdBlockList) -> URL {
            switch list {
            case .easyList:
                // EasyList is in ABP format; we will parse it for selectors and domains where applicable
                return URL(string: "https://easylist.to/easylist/easylist.txt")!
            case .easyListPrivacy:
                // EasyPrivacy complements EasyList with privacy rules
                return URL(string: "https://easylist.to/easylist/easyprivacy.txt")!
            case .peterLowe:
                return URL(string: "https://pgl.yoyo.org/adservers/serverlist.php?hostformat=hosts&showintro=0&mimetype=plaintext")!
            case .adAway:
                return URL(string: "https://adaway.org/hosts.txt")!
            case .oneHostsLite:
                return URL(string: "https://raw.githubusercontent.com/badmojr/1Hosts/master/Lite/hosts.txt")!
            case .stevenBlack:
                return URL(string: "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts")!
            }
        }
        
        // Fetch lists in parallel
        let maxDomains = 15000 // keep compilation time reasonable
        do {
            let domainSets = try await withThrowingTaskGroup(of: Set<String>.self) { group -> [Set<String>] in
                for sub in selected { group.addTask { try await self.fetchHostsList(url: listURL(sub)) } }
                for custom in settings.customAdBlockListURLs {
                    if let u = URL(string: custom) { group.addTask { try await self.fetchHostsList(url: u) } }
                }
                var results: [Set<String>] = []
                for try await set in group { results.append(set) }
                return results
            }
            
            var allDomains = Set<String>()
            for set in domainSets { allDomains.formUnion(set) }
            
            // Cap to avoid extremely large rule sets
            let limited = Array(allDomains.prefix(maxDomains)).sorted()
            // Pull a small EasyList (or regional list) for element-hiding rules
            var extraSelectors: [SelectorRule] = []
            var mergedDomains = Set(limited)
            // Main EasyList
            if let elURL = URL(string: "https://easylist.to/easylist/easylist.txt") {
                if let parsed = try? await fetchAndParseEasyList(from: elURL) {
                    mergedDomains.formUnion(parsed.domains)
                    extraSelectors.append(contentsOf: parsed.selectors)
                }
            }
            // Try to parse custom lists as EasyList text for selectors
            for custom in settings.customAdBlockListURLs {
                if let u = URL(string: custom), let parsed = try? await fetchAndParseEasyList(from: u) {
                    mergedDomains.formUnion(parsed.domains)
                    extraSelectors.append(contentsOf: parsed.selectors)
                }
            }
            // Store dynamic selectors for JS scriptlet injection
            self.currentDynamicSelectors = extraSelectors.map { $0.selector }
            
            let rulesJSON = buildRules(from: Array(mergedDomains), extraSelectors: extraSelectors)
            try await compileAndInstallRules(json: rulesJSON)
            
            activeRuleCount = mergedDomains.count + extraSelectors.count
            lastUpdated = Date()
            print("✅ AdBlock: Compiled rules: domains=\(mergedDomains.count), selectors=\(extraSelectors.count)")
        } catch {
            print("❌ AdBlock update failed: \(error)")
        }
    }
    
    func applyContentBlocking(to webView: WKWebView) {
        guard BrowserSettings.shared.adBlockEnabled,
              // Don't apply AdBlock to DuckDuckGo to avoid layout issues
              webView.url?.host?.contains("duckduckgo.com") != true else { return }
        if let list = compiledRuleList {
            webView.configuration.userContentController.add(list)
        } else {
            // Attempt to load from store if already compiled previously
            store?.lookUpContentRuleList(forIdentifier: ruleIdentifier) { [weak self] list, _ in
                if let list = list {
                    self?.compiledRuleList = list
                    webView.configuration.userContentController.add(list)
                }
            }
        }
        
        // Install lightweight anti-ad scriptlet to catch script-inserted widgets if enabled
        if BrowserSettings.shared.adBlockScriptletEnabled {
            installAntiAdScript(to: webView)
        }
    }
    
    // MARK: - Private helpers
    private func fetchHostsList(url: URL) async throws -> Set<String> {
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        guard let text = String(data: data, encoding: .utf8) else { return [] }
        var domains = Set<String>()
        for rawLine in text.components(separatedBy: .newlines) {
            var line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }
            if line.hasPrefix("#") { continue }
            // Normalize tabs to space
            line = line.replacingOccurrences(of: "\t", with: " ")
            // Expected formats:
            // 0.0.0.0 domain.com
            // 127.0.0.1 domain.com
            // 0.0.0.0 domain.com # comment
            let parts = line.split(separator: " ")
            if parts.count >= 2, parts[0].contains(".") {
                var host = String(parts[1])
                if let hashIndex = host.firstIndex(of: "#") { host = String(host[..<hashIndex]).trimmingCharacters(in: .whitespaces) }
                if let clean = sanitizeDomain(host) { domains.insert(clean) }
            }
        }
        return domains
    }
    
    private func buildRules(from domains: [String], extraSelectors: [SelectorRule] = []) -> String {
        // Build a JSON array of rules. Each domain becomes a regex against request URL host.
        // We restrict to third-party loads to reduce false positives.
        var rules: [[String: Any]] = []
        rules.reserveCapacity(domains.count + extraSelectors.count)
        
        func escape(_ s: String) -> String { s.replacingOccurrences(of: ".", with: "\\.") }
        
        for raw in domains {
            guard let d = sanitizeDomain(raw) else { continue }
            let pattern = "^https?://([^/]*\\.)?\(escape(d))/"
            let rule: [String: Any] = [
                "trigger": [
                    "url-filter": pattern,
                    "load-type": ["third-party"]
                ],
                "action": ["type": "block"]
            ]
            rules.append(rule)
        }
        
        // CSS hide selectors
        for s in extraSelectors {
            var trigger: [String: Any] = ["url-filter": ".*"]
            if !s.domains.isEmpty { trigger["if-domain"] = s.domains.compactMap { sanitizeDomain($0) } }
            let rule: [String: Any] = [
                "trigger": trigger,
                "action": [
                    "type": "css-display-none",
                    "selector": s.selector
                ]
            ]
            rules.append(rule)
        }
        
        // Serialize to JSON
        let data = try! JSONSerialization.data(withJSONObject: rules, options: [])
        return String(data: data, encoding: .utf8) ?? "[]"
    }
    
    private func compileAndInstallRules(json: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            store?.compileContentRuleList(forIdentifier: ruleIdentifier, encodedContentRuleList: json) { [weak self] list, error in
                if let error = error { continuation.resume(throwing: error); return }
                guard let list = list else { continuation.resume(throwing: URLError(.cannotParseResponse)); return }
                self?.compiledRuleList = list
                continuation.resume()
            }
        }
    }
    
    private func removeRuleList() async {
        compiledRuleList = nil
        activeRuleCount = 0
        try? await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            store?.removeContentRuleList(forIdentifier: ruleIdentifier) { _ in continuation.resume() }
        }
    }
    // MARK: - EasyList parsing (subset)
    private struct SelectorRule { let selector: String; let domains: [String] }
    
    private func fetchAndParseEasyList(from url: URL) async throws -> (domains: Set<String>, selectors: [SelectorRule]) {
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        guard let text = String(data: data, encoding: .utf8) else { return ([], []) }
        return parseEasyList(text: text)
    }
    
    private func parseEasyList(text: String) -> (domains: Set<String>, selectors: [SelectorRule]) {
        var domains = Set<String>()
        var selectors: [SelectorRule] = []
        let maxSelectors = 1500
        for raw in text.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }
            if line.hasPrefix("!") || line.hasPrefix("[") { continue } // comments/headers
            if line.hasPrefix("@@") { continue } // exceptions not supported
            if line.contains("##") { // element hiding
                let parts = line.components(separatedBy: "##")
                if parts.count == 2 {
                    let left = parts[0]
                    let selector = parts[1].trimmingCharacters(in: .whitespaces)
                    if selector.isEmpty { continue }
                    if selectors.count < maxSelectors {
                        let doms = left.isEmpty ? [] : left.split(separator: ",").map { String($0) }
                        selectors.append(SelectorRule(selector: selector, domains: doms))
                    }
                }
                continue
            }
            if line.hasPrefix("||") { // network blocking by domain
                var rest = String(line.dropFirst(2))
                if let idx = rest.firstIndex(where: { ["^","/","|","$","?",",","*"].contains(String($0)) }) {
                    rest = String(rest[..<idx])
                }
                if let clean = sanitizeDomain(rest) { domains.insert(clean) }
                continue
            }
        }
        return (domains, selectors)
    }
    
    private func installAntiAdScript(to webView: WKWebView) {
        // Enhanced base selectors targeting common ad patterns + the specific HTML structure from user's example
        // More targeted selectors that avoid breaking legitimate site UI
        let baseSelectors = [
            // IFrame-based ads
            "iframe[src*='doubleclick.net']",
            "iframe[src*='googlesyndication.com']",
            "iframe[src*='adnxs.com']",
            
            // Standard ad containers
            "[id^='div-gpt-ad']",
            "[id^='google_ads_']",
            "[id^='adunit']",
            "div[class^='ad-container']",
            "div[class^='ad-wrapper']",
            "div[class^='advert-']",
            
            // Ad-tech specific attributes
            "[data-ad-client]",
            "[data-ad-slot]",
            "[data-ad-unit]",
            "[data-ad-network]",
            "[data-ad-layout]",
            "[data-google-query-id]",
            
            // Common ad network classes
            ".taboola-container",
            ".outbrain-container",
            ".ad-unit-container",
            ".sponsored-content",
            ".sponsored-post",
            
            // Video ads
            "[class*='video-ad-overlay']",
            "[class*='pre-roll-ad']",
            "[class*='mid-roll-ad']",
            
            // Specific ad tech classes (avoid general UI patterns)
            "[class*='adsbox']",
            "[class*='ad-placement']",
            "[class*='ad-slot']",
            "[class*='dfp-ad']"
        ]
        let merged = Array((Set(baseSelectors).union(Set(currentDynamicSelectors))).prefix(2500)) // Increased limit
        let arrayString: String
        if let data = try? JSONSerialization.data(withJSONObject: merged, options: []), let s = String(data: data, encoding: .utf8) {
            arrayString = s
        } else {
            arrayString = "[]"
        }
        let js = """
        (function(){
          // Improved ad detection that preserves site functionality
          function hideSel(sel) { 
            try { 
              document.querySelectorAll(sel).forEach(function(n) {
                // Check if element is likely part of site UI
                if (n.closest('header, nav, .search-form, #search_form, .search-wrapper')) {
                  return; // Skip UI elements
                }
                // Only hide if element matches known ad patterns
                if (n.getAttribute('data-ad-client') || 
                    n.getAttribute('data-ad-slot') || 
                    n.getAttribute('data-ad-unit') || 
                    n.id.includes('google_ads_') || 
                    n.id.includes('div-gpt-ad')) {
                  n.style.setProperty('display', 'none', 'important');
                  n.style.setProperty('visibility', 'hidden', 'important');
                  n.style.setProperty('opacity', '0', 'important');
                }
              }); 
            } catch(e) {} 
          }
          
          var sels = \\(arrayString);
          function runHiding() { 
            for (var i = 0; i < sels.length; i++) { 
              hideSel(sels[i]); 
            }
          }
          
          // Run on load and DOM changes
          if (document.readyState === 'loading') {
            document.addEventListener('DOMContentLoaded', runHiding);
          } else { 
            runHiding(); 
          }
          
          // Watch for new ad insertions
          var mo = new MutationObserver(function(mutations) {
            mutations.forEach(function(mutation) {
              if (mutation.type === 'childList' && mutation.addedNodes.length > 0) {
                for (var i = 0; i < mutation.addedNodes.length; i++) {
                  var node = mutation.addedNodes[i];
                  if (node.nodeType === 1 && ( // Element node
                    node.hasAttribute('data-ad-client') ||
                    node.hasAttribute('data-ad-slot') ||
                    node.id.includes('google_ads_') ||
                    node.id.includes('div-gpt-ad')
                  )) {
                    runHiding();
                    break;
                  }
                }
              }
            });
          });
          mo.observe(document.documentElement, {childList: true, subtree: true});
        })();
        """
        let scriptSource = js.replacingOccurrences(of: "\\(arrayString)", with: arrayString)
        let script = WKUserScript(source: scriptSource, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        webView.configuration.userContentController.addUserScript(script)
    }
}

// MARK: - Sanitization helpers
private func sanitizeDomain(_ input: String) -> String? {
    // Trim whitespace and surrounding dots
    var s = input.trimmingCharacters(in: .whitespacesAndNewlines)
    while s.hasPrefix(".") { s.removeFirst() }
    while s.hasSuffix(".") { s.removeLast() }
    s = s.lowercased()
    if s.isEmpty { return nil }
    // Allow only host-like characters
    if s.range(of: "^[a-z0-9.-]+$", options: .regularExpression) == nil { return nil }
    // Avoid accidental wildcards or rule options sneaking in
    if s.contains("$") || s.contains(",") || s.contains("^") || s.contains("|") { return nil }
    return s
}
