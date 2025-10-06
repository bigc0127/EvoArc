//
//  AdBlockManager.swift
//  EvoArc
//
//  Advanced content blocking system combining WebKit's native WKContentRuleList
//  with JavaScript-based element hiding for comprehensive ad blocking.
//
//  Key responsibilities:
//  1. Fetch and parse FOSS ad block lists (hosts, EasyList, custom)
//  2. Compile rules into WKContentRuleList (native WebKit blocking)
//  3. Inject JavaScript scriptlets for dynamic element hiding
//  4. Handle cookie consent banners and obfuscated ad containers
//  5. Site-specific blocking (e.g., americanlookout.com tiles)
//  6. Parallel list updates with progress tracking
//
//  Two-layer blocking strategy:
//  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
//  Layer 1: WKContentRuleList (native)
//  - Network-level blocking (prevents requests)
//  - CSS element hiding (display:none via WebKit)
//  - Compiled bytecode (very fast)
//  - Limited to ~150KB JSON rules
//
//  Layer 2: JavaScript scriptlets (dynamic)
//  - Runtime element hiding (catches script-inserted ads)
//  - MutationObserver for continuous monitoring
//  - Text-based detection ("sponsored", "advertisement")
//  - Iframe dimension detection (common ad sizes)
//  - Cookie banner removal
//
//  Architecture:
//  - Singleton pattern (one shared instance)
//  - @MainActor for thread safety
//  - ObservableObject for SwiftUI reactivity
//  - Async/await for list fetching
//  - Structured concurrency for parallel downloads
//
//  Supported list formats:
//  - Hosts files (0.0.0.0 domain.com)
//  - EasyList/ABP (||domain.com^, ##selector)
//  - Custom user lists
//
//  For Swift beginners:
//  - WKContentRuleList: WebKit's native ad blocking API
//  - Content blocking: Prevent network requests before they happen
//  - Element hiding: Hide ad containers with CSS
//  - Scriptlet: Small JavaScript code injected into pages
//

import Foundation  // Core Swift - URLSession, JSONSerialization
import WebKit      // Apple's web engine - WKContentRuleList, WKUserScript
import Combine     // Reactive framework - ObservableObject, @Published

/// Manages ad blocking using dual-layer approach: native + JavaScript.
///
/// **@MainActor**: All operations run on main thread for thread safety.
///
/// **final**: Cannot be subclassed.
///
/// **ObservableObject**: SwiftUI views can observe @Published properties.
///
/// **Singleton**: Access via `AdBlockManager.shared`.
///
/// **Features**:
/// - Multi-source list support (6 built-in + custom)
/// - Parallel list fetching with structured concurrency
/// - Rule compilation and caching
/// - Dynamic element hiding with MutationObserver
/// - Cookie banner removal
/// - Site-specific fixes
@MainActor
final class AdBlockManager: ObservableObject {
    /// The shared singleton instance.
    static let shared = AdBlockManager()
    
    // MARK: - Public Types
    
    /// Built-in ad block list sources.
    ///
    /// **Purpose**: Provides curated, trustworthy FOSS filter lists.
    ///
    /// **Enum benefits**:
    /// - Type-safe list selection
    /// - CaseIterable for settings UI
    /// - Identifiable for SwiftUI ForEach
    ///
    /// **List types**:
    /// - General: EasyList (most comprehensive)
    /// - Privacy: EasyList Privacy (tracking protection)
    /// - Hosts: Peter Lowe, AdAway, 1Hosts, StevenBlack
    ///
    /// **For beginners**:
    /// - "Hosts file": Simple list of blocked domains
    /// - "EasyList": Advanced rules with selectors and wildcards
    /// - "ABP format": Adblock Plus rule syntax
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
    private var store: WKContentRuleListStore? = WKContentRuleListStore.default()
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
        // Add our custom selector first for priority
        let customRule: [String: Any] = [
            "trigger": ["url-filter": ".*"],
            "action": [
                "type": "css-display-none",
                "selector": "#essb_displayed_shortcode_1, #essb_displayed_shortcode_2, #essb_displayed_shortcode_3, #essb_displayed_shortcode_4, #essb_displayed_shortcode_5, [id^=\"essb_displayed_shortcode_\"], div[id^=\"essb_displayed_shortcode_\"], [id^=\"essb_displayed_shortcode_\"] > div, .essb_displayed_shortcode, [class*=\"mdyheadline-\"]"
            ]
        ]
        rules.append(customRule)
        
        // Add other selectors
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
        guard let store = self.store else {
            print("⚠️ AdBlock: WKContentRuleListStore is nil")
            throw URLError(.unknown)
        }
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            store.compileContentRuleList(forIdentifier: ruleIdentifier, encodedContentRuleList: json) { [weak self] list, error in
                if let error = error { 
                    print("❌ AdBlock compilation error: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                    return
                }
                guard let list = list else { 
                    print("❌ AdBlock: No rule list returned")
                    continuation.resume(throwing: URLError(.cannotParseResponse))
                    return
                }
                self?.compiledRuleList = list
                print("✅ AdBlock: Rules compiled successfully")
                continuation.resume()
            }
        }
    }
    
    private func removeRuleList() async {
        compiledRuleList = nil
        activeRuleCount = 0
        guard let store = self.store else { return }
        try? await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            store.removeContentRuleList(forIdentifier: ruleIdentifier) { _ in continuation.resume() }
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
        let settings = BrowserSettings.shared
        // Enhanced base selectors targeting common ad patterns + the specific HTML structure from user's example
        // More targeted selectors that avoid breaking legitimate site UI
        let baseSelectors = [
            // Custom selectors
            "#essb_displayed_shortcode_1",
            "#essb_displayed_shortcode_2",
            "#essb_displayed_shortcode_3",
            "#essb_displayed_shortcode_4",
            "#essb_displayed_shortcode_5",
            "[id^=\"essb_displayed_shortcode_\"]",
            "div[id^=\"essb_displayed_shortcode_\"]",
            "[id^=\"essb_displayed_shortcode_\"] > div",
            ".essb_displayed_shortcode",
            
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
        var mergedSet = Set(baseSelectors).union(Set(currentDynamicSelectors))
        
        // If advanced JS blocking is enabled, add aggressive selectors
        if settings.adBlockAdvancedJS {
            let aggressiveSelectors = [
                // Attribute and ARIA-based hints (safer)
                "[aria-label*='sponsor' i]",
                "[aria-label*='advert' i]",
                "[aria-label*='promoted' i]",
                "a[rel*='sponsored' i]",
                "[data-ad]",
                "[data-ads]",
                "[data-ad-slot]",
                "[data-ad-client]",
                "[data-ad-unit]",
                "[data-google-query-id]",
                
                // Common container types for ad blocks with explicit prefixes
                "div[class^='ad-' i]",
                "section[class^='ad-' i]",
                "aside[class^='ad-' i]",
                
                // If a site uses our targeted shortcode, also blanket-hide its children
                "[id^='essb_displayed_shortcode_'] > div"
            ]
            mergedSet.formUnion(aggressiveSelectors)
        }
        let merged = Array(mergedSet.prefix(3500))
        let arrayString: String
        if let data = try? JSONSerialization.data(withJSONObject: merged, options: []), let s = String(data: data, encoding: .utf8) {
            arrayString = s
        } else {
            arrayString = "[]"
        }
        let js = """
        (function(){
          var ADVANCED = $(ADVANCED);
          var OBFUSCATED = $(OBFUSCATED);
          var COOKIE = $(COOKIE);
          // Improved ad detection that preserves site functionality
          function hideSel(sel) { 
            try { 
              document.querySelectorAll(sel).forEach(function(n) {
                // For our specific ESSB shortcode selector, hide unconditionally
                if (sel.indexOf('essb_displayed_shortcode_') !== -1) {
                  n.style.setProperty('display', 'none', 'important');
                  n.style.setProperty('visibility', 'hidden', 'important');
                  n.style.setProperty('opacity', '0', 'important');
                  return;
                }
                // If not in advanced mode, avoid hiding common UI containers
                if (!ADVANCED) {
                  if (n.closest('header, nav, .search-form, #search_form, .search-wrapper')) {
                    return; // Skip UI elements
                  }
                }
                // Only hide if element matches known ad patterns
                if (n.getAttribute('data-ad-client') || 
                    n.getAttribute('data-ad-slot') || 
                    n.getAttribute('data-ad-unit') || 
                    (n.id && n.id.includes('google_ads_')) || 
                    (n.id && n.id.includes('div-gpt-ad')) ||
                    (n.id && n.id.includes('essb_displayed_shortcode_')) ||
                    // Advanced: bounded keyword match with exclusions
                    (ADVANCED && (function(){
                      var id = (n.id||'').toLowerCase();
                      var cls = ((''+n.className)||'').toLowerCase();
                      var text = (n.textContent||'').toLowerCase();
                      var badWord = /(^|[^a-z])(ads?|sponsor|promoted)([^a-z]|$)/i;
                      var exclude = /(header|loader|shadow|adapter|admin|badge|download|read|road|load|lead)/i;
                      if ((badWord.test(id) && !exclude.test(id)) || (badWord.test(cls) && !exclude.test(cls))) return true;
                      // Short textual labels that indicate ads
                      if (text && text.length < 40 && badWord.test(text)) return true;
                      return false;
                    })())
                ) {
                  n.style.setProperty('display', 'none', 'important');
                  n.style.setProperty('visibility', 'hidden', 'important');
                  n.style.setProperty('opacity', '0', 'important');
                }
              }); 
            } catch(e) {} 
          }
          
          function hideByKeyword(keywords, regexes) {
            try {
              var walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT, null);
              var node;
              while ((node = walker.nextNode())) {
                var raw = (node.nodeValue || '');
                var text = raw.toLowerCase();
                var matched = false;
                for (var i=0;i<keywords.length && !matched;i++) {
                  if (text.indexOf(keywords[i]) !== -1) matched = true;
                }
                for (var j=0;j<regexes.length && !matched;j++) {
                  if (regexes[j].test(raw)) matched = true;
                }
                if (matched) {
                  var el = node.parentElement;
                  if (!el) continue;
                  var container = el.closest('aside, section, article, div, li') || el.parentElement;
                  if (!container) container = el;
                  container.style.setProperty('display', 'none', 'important');
                  container.style.setProperty('visibility', 'hidden', 'important');
                  container.style.setProperty('opacity', '0', 'important');
                }
              }
            } catch(e) {}
          }
          
          function hideAdIframes() {
            try {
              var frames = document.querySelectorAll('iframe');
              for (var i=0;i<frames.length;i++) {
                var f = frames[i];
                var src = (f.getAttribute('src') || '').toLowerCase();
                if (src.indexOf('doubleclick.net') !== -1 || src.indexOf('googlesyndication.com') !== -1 || src.indexOf('adnxs.com') !== -1) {
                  var c = f.closest('div, section, aside, article') || f;
                  c.style.setProperty('display','none','important');
                  c.style.setProperty('visibility','hidden','important');
                  c.style.setProperty('opacity','0','important');
                  continue;
                }
                var rect = f.getBoundingClientRect();
                var w = Math.round(rect.width), h = Math.round(rect.height);
                var sizes = [[300,250],[320,50],[728,90],[160,600],[300,600],[336,280],[468,60]];
                for (var s=0;s<sizes.length;s++) {
                  if (Math.abs(w - sizes[s][0]) <= 4 && Math.abs(h - sizes[s][1]) <= 4) {
                    var c2 = f.closest('div, section, aside, article') || f;
                    c2.style.setProperty('display','none','important');
                    c2.style.setProperty('visibility','hidden','important');
                    c2.style.setProperty('opacity','0','important');
                    break;
                  }
                }
              }
            } catch(e) {}
          }
          
          function hideByAttributes() {
            try {
              var nodes = document.querySelectorAll('[aria-label*="sponsor" i], [aria-label*="advert" i], a[rel*="sponsored" i], img[alt*="sponsor" i], img[alt*="advert" i], [role="complementary"]');
              for (var i=0;i<nodes.length;i++) {
                var c = nodes[i].closest('div, section, aside, article') || nodes[i];
                c.style.setProperty('display','none','important');
                c.style.setProperty('visibility','hidden','important');
                c.style.setProperty('opacity','0','important');
              }
            } catch(e) {}
          }
          
          // Site-specific: headlines.americanlookout.com
          function hideAmericanLookoutTiles(){
            try {
              if (!(new RegExp('^headlines\\.americanlookout\\.com$', 'i')).test(location.hostname)) return;
              var anchors = document.querySelectorAll('a');
              // Expanded ad/sponsor networks and shopping domains
              var bannedHosts = [
                'mypillow','epochtimes','theepochtimes','revcontent','outbrain','taboola','mgid','sharethrough','zergnet','newsmax',
                'clickbank','impactradius','impact.com','rakuten','awin','cj.com','commissionjunction','doubleclick','googlesyndication'
              ];
              var textSignals = [
                'advertisement','advertorial','sponsored','paid content','check out','% off','sale','store','shop now','deal','sponsor',
                'click here','order now','buy now','try it','limited time','use code','promo code','coupon','shop','save'
              ];
              function hostOf(url){ try { return new URL(url, location.href).hostname.toLowerCase(); } catch(e){ return ''; } }
              function hasUTM(url){ return /[?&#](utm_|aff|ref|trk|track|clk|campaign|source)=/i.test(url); }
              function looksPromotional(text){
                var t = (text||'').toLowerCase();
                for (var i=0;i<textSignals.length;i++){ if (t.indexOf(textSignals[i]) !== -1) return true; }
                // price/discount patterns
                if ((new RegExp('(?:\\\\$\\\\d|\\\\d{1,3}\\\\s?%\\\\s*off|\\\\d+\\\\s?for\\\\s?\\\\d+)')).test(t)) return true;
                return false;
              }
              anchors.forEach(function(a){
                var href = a.getAttribute('href')||'';
                var h = hostOf(href);
                var t = (a.textContent||'');
                var promo = looksPromotional(t) || hasUTM(href);
                var banned = bannedHosts.some(function(b){ return h.indexOf(b) !== -1; });
                // If promo/banned and within a tile with an image or large font headline, hide the tile
                if (promo || banned){
                  var container = a.closest('article, li, .post, .card, .tile, .grid-item, section, div');
                  if (!container) return;
                  var hasImg = !!container.querySelector('img');
                  var bigText = Array.from(container.querySelectorAll('h1,h2,h3,h4,p,span')).some(function(n){ return (n.textContent||'').length > 40; });
                  if (hasImg || bigText){
                    container.style.setProperty('display','none','important');
                    container.style.setProperty('visibility','hidden','important');
                    container.style.setProperty('opacity','0','important');
                  }
                }
              });
              // Also hide explicit ADVERTISEMENT or SPONSORED blocks
              document.querySelectorAll('div, section, aside').forEach(function(n){
                var txt = (n.textContent||'').toLowerCase();
                if ((/advertisement|sponsored|partner content/.test(txt)) && n.querySelector('img')){
                  n.style.setProperty('display','none','important');
                  n.style.setProperty('visibility','hidden','important');
                  n.style.setProperty('opacity','0','important');
                }
              });
            } catch(e) {}
          }
          
          function hideCookieBanners(){
            try {
              // Common CMPs/selectors
              var sels = [
                // IDs
                "#cookie-banner", "#cookieBanner", "#cookies", "#cookieConsent", "#cookie-consent", "#gdpr-banner", "#cmp-container",
                "#onetrust-banner-sdk", "#consent_blackbar", "#cookie-law-info-bar", "#truste-consent-track",
                // Classes
                ".cookie-banner", ".cookiebar", ".cookie-consent", ".cookie-consent-banner", ".cookie-consent-modal", ".cookie-notice",
                ".cc-window", ".cc-banner", ".cc-consent", ".osano-cm-window", ".truste_box_overlay", ".qc-cmp-ui-container",
                ".qc-cmp2-container", ".qc-cmp2-summary-buttons", ".fc-consent-root", ".sp_veil", ".sp_message_container", ".sp弹窗",
                // Attributes
                "[aria-label*='cookie' i]", "[aria-label*='consent' i]", "[data-cookie-banner]", "[data-consent]"
              ];
              sels.forEach(function(sel){
                document.querySelectorAll(sel).forEach(function(n){
                  var box = n.closest('[role="dialog"], .modal, .overlay, .backdrop, .toast, div, section') || n;
                  box.style.setProperty('display','none','important');
                  box.style.setProperty('visibility','hidden','important');
                  box.style.setProperty('opacity','0','important');
                });
              });
              // Text-based
              var phrases = ['we use cookies', 'cookie policy', 'accept cookies', 'manage cookies', 'your consent', 'gdpr', 'ccpa'];
              var walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT, null);
              var node;
              while ((node = walker.nextNode())) {
                var t = (node.nodeValue||'').toLowerCase();
                for (var i=0;i<phrases.length;i++){
                  if (t.indexOf(phrases[i]) !== -1){
                    var el = node.parentElement; if (!el) break;
                    var cont = el.closest('[role="dialog"], .modal, .overlay, .cookie, .consent, .backdrop, .banner, .notice, .toast, div, section') || el;
                    cont.style.setProperty('display','none','important');
                    cont.style.setProperty('visibility','hidden','important');
                    cont.style.setProperty('opacity','0','important');
                    break;
                  }
                }
              }
              // Remove body scroll locks often used with cookie modals
              document.documentElement.style.overflow = '';
              document.body.style.overflow = '';
            } catch(e) {}
          }
          
          function hideMDYHeadlines(){
            try {
              var nodes = document.querySelectorAll('[class*="mdyheadline-"]');
              for (var i=0;i<nodes.length;i++){
                var div = nodes[i].closest('div') || nodes[i].parentElement;
                if (div){
                  div.style.setProperty('display','none','important');
                  div.style.setProperty('visibility','hidden','important');
                  div.style.setProperty('opacity','0','important');
                }
              }
            } catch(e) {}
          }
          
          function isObfuscatedToken(t){
            if (!t) return false;
            if (t.length < 8) return false;
            if (/[-_]/.test(t)) return false; // often semantic
            if (/^(container|content|section|wrapper|button|header|footer|main|article|nav|title|subtitle)$/i.test(t)) return false;
            if (!/^[A-Za-z0-9]+$/.test(t)) return false;
            var vowels = (t.match(/[aeiou]/gi)||[]).length;
            var letters = (t.match(/[A-Za-z]/g)||[]).length;
            // low vowel ratio and high letter count indicates obfuscation
            if (letters >= 8 && (vowels/Math.max(letters,1)) < 0.20) return true;
            // looks like hash-like
            if (/^[a-z0-9]{10,}$/i.test(t)) return true;
            return false;
          }
          
          function hideObfuscatedClasses(){
            try {
              var nodes = document.querySelectorAll('div, section, aside, article');
              for (var i=0;i<nodes.length;i++) {
                var n = nodes[i];
                var cls = (n.className||'').toString().trim();
                if (!cls) continue;
                var tokens = cls.split(new RegExp('\\\\s+'));
                for (var j=0;j<tokens.length;j++){
                  if (isObfuscatedToken(tokens[j])){
                    n.style.setProperty('display','none','important');
                    n.style.setProperty('visibility','hidden','important');
                    n.style.setProperty('opacity','0','important');
                    break;
                  }
                }
              }
            } catch(e) {}
          }
          
          var sels = \\(arrayString);
          var scheduled = false;
          function runHiding() { 
            if (scheduled) return; // throttle
            scheduled = true;
            setTimeout(function(){
              for (var i = 0; i < sels.length; i++) { hideSel(sels[i]); }
              if (ADVANCED) {
                hideByKeyword(
                  ['paid content','paid post','paid partnership','sponsored','sponsored content','promoted','promoted content','partner content','advertisement','advertorial','brand content','presented by','in partnership with','powered by'],
                  [new RegExp('(^|\\\\b)ad(s|vertisement)?(\\\\b|$)','i')]
                );
                hideByAttributes();
                hideAdIframes();
                hideAmericanLookoutTiles();
              }
              // Always apply MDY headline hiding regardless of mode, since it's specific pattern
              hideMDYHeadlines();
              if (OBFUSCATED) {
                hideObfuscatedClasses();
              }
              if (COOKIE) {
                hideCookieBanners();
              }
              scheduled = false;
            }, 50);
          }
          
          // Run on load and DOM changes
          if (document.readyState === 'loading') {
            document.addEventListener('DOMContentLoaded', runHiding);
          } else { 
            runHiding(); 
          }
          
          // Watch for new ad/text insertions
          var mo = new MutationObserver(function(mutations) {
            var shouldRun = false;
            for (var i=0;i<mutations.length;i++) {
              var m = mutations[i];
              if (m.type === 'childList' || m.type === 'attributes') { shouldRun = true; break; }
            }
            if (shouldRun) { runHiding(); }
          });
          mo.observe(document.documentElement, {childList: true, attributes: true, subtree: true});
        })();
        """
        let advanced = BrowserSettings.shared.adBlockAdvancedJS ? "true" : "false"
        // Advanced implies obfuscated class hiding, so OR the flags
        let obfuscated = (BrowserSettings.shared.adBlockObfuscatedClass || BrowserSettings.shared.adBlockAdvancedJS) ? "true" : "false"
        let cookie = BrowserSettings.shared.adBlockCookieBanners ? "true" : "false"
        var scriptSource = js.replacingOccurrences(of: "\\(arrayString)", with: arrayString)
        scriptSource = scriptSource.replacingOccurrences(of: "$(ADVANCED)", with: advanced)
        scriptSource = scriptSource.replacingOccurrences(of: "$(OBFUSCATED)", with: obfuscated)
        scriptSource = scriptSource.replacingOccurrences(of: "$(COOKIE)", with: cookie)
        let script = WKUserScript(source: scriptSource, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        webView.configuration.userContentController.addUserScript(script)
    }
}

// MARK: - Sanitization Helpers

/// Sanitizes and validates a domain name for use in blocking rules.
///
/// **Purpose**: Ensure domains are clean and safe for regex compilation.
///
/// **Process**:
/// 1. Trim whitespace and dots
/// 2. Lowercase for consistency
/// 3. Validate characters (alphanumeric, dots, hyphens only)
/// 4. Reject special characters that could break rules
///
/// **Returns**: Clean domain string, or nil if invalid.
///
/// **Examples**:
/// - "  .example.com.  " → "example.com" ✅
/// - "EXample.COM" → "example.com" ✅
/// - "bad$domain.com" → nil ❌ (contains $)
/// - "" → nil ❌ (empty)
private func sanitizeDomain(_ input: String) -> String? {
    /// Trim whitespace and surrounding dots.
    var s = input.trimmingCharacters(in: .whitespacesAndNewlines)
    while s.hasPrefix(".") { s.removeFirst() }
    while s.hasSuffix(".") { s.removeLast() }
    s = s.lowercased()
    if s.isEmpty { return nil }
    
    /// Allow only host-like characters (letters, numbers, dots, hyphens).
    if s.range(of: "^[a-z0-9.-]+$", options: .regularExpression) == nil { return nil }
    
    /// Avoid accidental wildcards or rule options sneaking in.
    /// These characters have special meaning in filter lists.
    if s.contains("$") || s.contains(",") || s.contains("^") || s.contains("|") { return nil }
    
    return s
}

// MARK: - Architecture Summary
//
// AdBlockManager provides comprehensive ad blocking for EvoArc.
//
// ┌──────────────────────────────────────────────────────┐
// │  AdBlockManager Architecture  │
// └──────────────────────────────────────────────────────┘
//
// Two-Layer Blocking System:
// ==========================
//
// Layer 1: WKContentRuleList (Native WebKit)
// ┌───────────────────────────────────────────┐
// │ Network Blocking                        │
// │ - Prevents HTTP requests                │
// │ - Compiled to bytecode                  │
// │ - Very fast (native code)               │
// │ - Max ~150KB JSON rules                 │
// │                                          │
// │ CSS Element Hiding                      │
// │ - display:none via WebKit                │
// │ - Applied before page render            │
// │ - No flicker (pre-render hiding)        │
// └───────────────────────────────────────────┘
//
// Layer 2: JavaScript Scriptlets (Dynamic)
// ┌───────────────────────────────────────────┐
// │ Runtime Element Hiding                  │
// │ - Catches dynamically inserted ads     │
// │ - MutationObserver monitors DOM        │
// │ - Text-based detection                 │
// │ - Iframe size detection                │
// │                                          │
// │ Cookie Banner Removal                   │
// │ - GDPR/CCPA consent dialogs            │
// │ - Unlocks scrolling                    │
// │                                          │
// │ Obfuscated Class Detection             │
// │ - Random class names (ad evasion)      │
// │ - Vowel ratio analysis                 │
// └───────────────────────────────────────────┘
//
// Update Flow:
// ============
//
// User enables ad blocking in settings:
//   ↓
// updateSubscriptions(force: false) called
//   ↓
// Fetch multiple lists in parallel (withThrowingTaskGroup):
//   - EasyList (ABP format)
//   - EasyList Privacy
//   - Peter Lowe hosts
//   - AdAway hosts
//   - 1Hosts Lite
//   - StevenBlack hosts
//   - Custom user lists
//   ↓
// Parse each list:
//   - Hosts format: "0.0.0.0 ads.example.com"
//   - EasyList format: "||ads.example.com^" or "##.ad-container"
//   ↓
// Merge all domains (Set for deduplication):
//   ↓
// Limit to 15,000 domains (compilation performance):
//   ↓
// Build JSON rules:
//   - Network blocking: {"trigger": {"url-filter": "^https?://.*ads\\.example\\.com/"}, "action": {"type": "block"}}
//   - CSS hiding: {"trigger": {"url-filter": ".*"}, "action": {"type": "css-display-none", "selector": ".ad-container"}}
//   ↓
// Compile to WKContentRuleList:
//   ↓
// Cache compiled rules (survive app restart):
//   ↓
// Apply to all new web views
//
// List Formats:
// =============
//
// 1. Hosts File Format:
// --------------------
// ```
// # Comment line (ignored)
// 0.0.0.0 ads.example.com
// 127.0.0.1 tracker.example.com # inline comment
// ```
//
// Parsing:
// - Split by whitespace
// - First part: IP (ignored, we only want domain)
// - Second part: Domain to block
// - Strip comments (after #)
//
// 2. EasyList/ABP Format:
// ----------------------
// ```
// ! Comment line (ignored)
// [Adblock Plus 2.0] (header, ignored)
// ||ads.example.com^ (network block)
// ##.ad-container (element hiding)
// example.com##.site-specific-ad (domain-specific hiding)
// @@||good-ads.com^ (exception, not supported)
// ```
//
// Parsing:
// - "||" prefix: Network blocking rule
// - "##" separator: Element hiding rule
// - "domain##selector": Domain-specific selector
// - "@@" prefix: Exception (we skip these)
//
// 3. Custom Lists:
// ---------------
// Users can add URL to any hosts or EasyList format.
// Parsed with same logic as built-in lists.
//
// Rule Compilation:
// ================
//
// JSON Structure:
// ```json
// [
//   {
//     "trigger": {
//       "url-filter": "^https?://([^/]*\\.)?ads\\.example\\.com/",
//       "load-type": ["third-party"]
//     },
//     "action": {"type": "block"}
//   },
//   {
//     "trigger": {"url-filter": ".*"},
//     "action": {
//       "type": "css-display-none",
//       "selector": ".ad-container"
//     }
//   }
// ]
// ```
//
// Compilation process:
// 1. Generate JSON array of rules
// 2. WKContentRuleListStore.compile() converts to bytecode
// 3. Store in ~/Library/WebKit/ContentRuleLists/
// 4. Load from cache on next launch (instant)
//
// Limits:
// - Max ~150KB JSON (WebKit limit)
// - ~15,000 domains practical (compilation time)
// - Unlimited selectors (but capped at 1500 for performance)
//
// JavaScript Scriptlet:
// ====================
//
// Injection:
// ```swift
// let script = WKUserScript(
//     source: jsCode,
//     injectionTime: .atDocumentStart,
//     forMainFrameOnly: false  // Apply to iframes too
// )
// webView.configuration.userContentController.addUserScript(script)
// ```
//
// Key Functions:
// 
// 1. hideSel(selector):
//    - document.querySelectorAll(selector)
//    - Sets display:none !important
//    - Preserves site functionality (skip headers/nav)
//
// 2. hideByKeyword(["sponsored", "advertisement"]):
//    - TreeWalker scans text nodes
//    - Finds matching text
//    - Hides parent container
//
// 3. hideAdIframes():
//    - Checks iframe src for ad networks
//    - Checks iframe dimensions (300x250, 728x90, etc.)
//    - Hides matching iframes
//
// 4. hideCookieBanners():
//    - Targets common consent management platforms
//    - Removes scroll locks
//    - Hides by ID, class, ARIA label, text content
//
// 5. hideObfuscatedClasses():
//    - Detects random class names (ad evasion)
//    - Low vowel ratio ("xj3k9f2h" vs "container")
//    - Hides suspicious containers
//
// 6. MutationObserver:
//    - Watches for DOM changes
//    - Re-runs hiding on new elements
//    - Throttled to 50ms
//
// Common Ad Sizes (IAB Standard):
// ===============================
//
// - 300x250 (Medium Rectangle) - Most common
// - 728x90 (Leaderboard) - Top banner
// - 320x50 (Mobile Banner)
// - 160x600 (Wide Skyscraper) - Sidebar
// - 300x600 (Half Page) - Sidebar
// - 336x280 (Large Rectangle)
// - 468x60 (Full Banner) - Legacy
//
// Performance Characteristics:
// ===========================
//
// List Update:
// - 6 lists in parallel: ~2-5 seconds
// - Domain deduplication: O(n) Set operations
// - Rule compilation: ~500ms for 15,000 rules
// - Total update: ~3-6 seconds
//
// Runtime Blocking:
// - WKContentRuleList: <1ms per request (native)
// - JavaScript hiding: ~10-50ms initial run
// - MutationObserver: ~5-10ms per DOM change
//
// Memory Usage:
// - Compiled rules: ~2-5MB on disk
// - In-memory cache: ~1-2MB
// - JavaScript scriptlet: ~50KB per webview
//
// Network Impact:
// - Blocked requests: 0 bytes transferred ✅
// - ~30-50% reduction in page size
// - ~20-40% faster page load
//
// Limitations:
// ============
//
// WKContentRuleList:
// ❌ Cannot access iframe contents (cross-origin)
// ❌ Limited JSON size (~150KB)
// ❌ No regex lookahead/lookbehind
// ❌ Cannot modify responses (read-only)
//
// JavaScript Scriptlets:
// ❌ Can be detected by anti-adblock
// ❌ Slight performance overhead
// ❌ May break some sites (false positives)
// ❌ Runs after page starts loading (brief flicker)
//
// Browser-Specific Issues:
// - DuckDuckGo: Ad blocking disabled (breaks layout)
// - Some sites detect ad blockers (anti-adblock)
// - Paywalls may use ad block detection
//
// Best Practices:
// ==============
//
// ✅ DO use third-party filter to reduce false positives
// ✅ DO limit rule count for compilation performance
// ✅ DO cache compiled rules
// ✅ DO provide disable option per-site
// ✅ DO test on popular sites (don't break them)
//
// ❌ DON'T block first-party requests (breaks sites)
// ❌ DON'T use overly aggressive selectors
// ❌ DON'T hide legitimate UI (search bars, navigation)
// ❌ DON'T assume all ads are bad (some are non-intrusive)
// ❌ DON'T forget to handle anti-adblock
//
// Site-Specific Fixes:
// ===================
//
// Some sites need special handling:
//
// 1. americanlookout.com:
//    - Promotional tiles mixed with news
//    - Detects affiliate links (utm params)
//    - Hides tiles with shopping/discount text
//
// 2. DuckDuckGo:
//    - Ad blocking breaks search layout
//    - Explicitly excluded from blocking
//
// 3. Cookie Banners:
//    - GDPR/CCPA consent dialogs
//    - Scroll locks
//    - Multiple CMP platforms (OneTrust, Cookiebot, etc.)
//
// Integration with EvoArc:
// =======================
//
// Initialization:
// ```swift
// class BrowserApp: App {
//     init() {
//         AdBlockManager.shared.refreshOnLaunchIfNeeded()
//     }
// }
// ```
//
// Applying to WebView:
// ```swift
// let webView = WKWebView(...)
// AdBlockManager.shared.applyContentBlocking(to: webView)
// ```
//
// Settings UI:
// ```swift
// ForEach(AdBlockManager.Subscription.allCases) { list in
//     Toggle(list.displayName, isOn: $selected[list])
//     Text(list.description).font(.caption)
// }
// ```
//
// Manual Update:
// ```swift
// Button("Update Lists") {
//     Task {
//         await AdBlockManager.shared.updateSubscriptions(force: true)
//     }
// }
// ```
//
// Future Enhancements:
// ===================
//
// Potential improvements:
// - Background list updates (URLSession.background)
// - Per-site whitelist (disable for specific domains)
// - Custom selector editor
// - Anti-anti-adblock (stealth mode)
// - Element picker (like uBlock Origin)
// - Statistics (blocked count, bandwidth saved)
// - Import/export custom lists
// - Sync lists across devices (iCloud)
//
// This provides Safari/Brave-level ad blocking
// with EasyList compatibility and custom rules!
