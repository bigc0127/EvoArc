//
//  ContentView.swift
//  EvoArc
//
//  Created by Connor W. Needling on 2025-09-04.
//

import SwiftUI
import WebKit
#if os(iOS)
import UIKit
#else
import AppKit
#endif
import Combine

struct ContentView: View {
    @StateObject private var tabManager = TabManager()
    @State private var urlString: String = ""
    @State private var isURLBarFocused: Bool = false
    @State private var dragOffset: CGSize = .zero
    @State private var showHoverArea: Bool = false
    @State private var showingSettings: Bool = false
    @State private var shouldNavigate: Bool = false
    @State private var urlBarVisible: Bool = true
    @State private var lastScrollOffset: CGFloat = 0
    @StateObject private var settings = BrowserSettings.shared
    @StateObject private var perplexityManager = PerplexityManager.shared
    @AppStorage("hasShownDefaultBrowserPrompt") private var hasShownDefaultBrowserPrompt: Bool = false
    @State private var showDefaultBrowserTip: Bool = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                #if os(iOS)
                // iOS Layout: URL bar at bottom with tab drawer overlay
                VStack(spacing: 0) {
                    // Web content area
                    if !tabManager.tabs.isEmpty && tabManager.isInitialized {
                        TabViewContainer(
                            tabManager: tabManager,
                            urlString: $urlString,
                            shouldNavigate: $shouldNavigate,
                            urlBarVisible: $urlBarVisible,
                            onNavigate: { url in
                                urlString = url.absoluteString
                            },
                            autoHideEnabled: settings.autoHideURLBar
                        )
                        .ignoresSafeArea(edges: .horizontal)
                        .ignoresSafeArea(edges: urlBarVisible ? [] : .bottom) // Expand to bottom when URL bar is hidden
                    } else if !tabManager.isInitialized {
                        // Loading state during initialization
                        VStack {
                            Spacer()
                            ProgressView()
                                .scaleEffect(1.5)
                                .padding()
                            Text("Restoring tabs...")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    } else {
                        // Empty state
                        VStack {
                            Spacer()
                            Image(systemName: "globe")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                            Text("No tab selected")
                                .font(.headline)
                                .foregroundColor(.gray)
                            Spacer()
                        }
                    }
                    
                    // Bottom URL bar and controls - conditionally included in layout
                    if urlBarVisible || !settings.autoHideURLBar {
                        if let selected = tabManager.selectedTab {
                            BottomBarView(
                                urlString: $urlString,
                                isURLBarFocused: $isURLBarFocused,
                                tabManager: tabManager,
                                selectedTab: selected,
                                showingSettings: $showingSettings,
                                shouldNavigate: $shouldNavigate
                            )
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .animation(.easeInOut(duration: 0.3), value: urlBarVisible)
                        }
                    }
                }
                #else
                // macOS Layout: Tab drawer on side, URL bar at bottom
                HStack(spacing: 0) {
                    // Side tab drawer (left or right based on setting)
                    if settings.tabDrawerPosition == .left && tabManager.isTabDrawerVisible {
                        MacOSTabDrawerView(tabManager: tabManager)
                            .frame(width: 300)
                            .transition(.move(edge: .leading))
                    }
                    
                    // Main content area
                    VStack(spacing: 0) {
                        // Web content area
                        if !tabManager.tabs.isEmpty && tabManager.isInitialized {
                            TabViewContainer(
                                tabManager: tabManager,
                                urlString: $urlString,
                                shouldNavigate: $shouldNavigate,
                                urlBarVisible: $urlBarVisible,
                                onNavigate: { url in
                                    urlString = url.absoluteString
                                },
                                autoHideEnabled: settings.autoHideURLBar
                            )
                            .ignoresSafeArea(edges: urlBarVisible || !settings.autoHideURLBar ? [] : .bottom) // Expand to bottom when URL bar is hidden
                        } else if !tabManager.isInitialized {
                            // Loading state during initialization
                            VStack {
                                Spacer()
                                ProgressView()
                                    .scaleEffect(1.5)
                                    .padding()
                                Text("Restoring tabs...")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                        } else {
                            // Empty state
                            VStack {
                                Spacer()
                                Image(systemName: "globe")
                                    .font(.system(size: 60))
                                    .foregroundColor(.gray)
                                Text("No tab selected")
                                    .font(.headline)
                                    .foregroundColor(.gray)
                                Spacer()
                            }
                        }
                        
                        // Bottom URL bar (macOS style) - conditionally included in layout
                        if urlBarVisible || !settings.autoHideURLBar {
                            if let selected = tabManager.selectedTab {
                                MacOSBottomBarView(
                                    urlString: $urlString,
                                    isURLBarFocused: $isURLBarFocused,
                                    tabManager: tabManager,
                                    selectedTab: selected,
                                    showingSettings: $showingSettings,
                                    shouldNavigate: $shouldNavigate
                                )
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                                .animation(.easeInOut(duration: 0.3), value: urlBarVisible)
                            }
                        }
                    }
                    
                    // Side tab drawer (right side)
                    if settings.tabDrawerPosition == .right && tabManager.isTabDrawerVisible {
                        MacOSTabDrawerView(tabManager: tabManager)
                            .frame(width: 300)
                            .transition(.move(edge: .trailing))
                    }
                }
                #endif
                
                // Tab drawer overlay (iOS only)
                #if os(iOS)
                if tabManager.isTabDrawerVisible {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture {
                            tabManager.hideTabDrawer()
                        }
                    
                    VStack {
                        Spacer()
                        TabDrawerView(tabManager: tabManager)
                            .frame(maxHeight: geometry.size.height * 0.7)
                            .transition(.move(edge: .bottom))
                            .offset(y: dragOffset.height > 0 ? dragOffset.height : 0)
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        if value.translation.height > 0 {
                                            dragOffset = value.translation
                                        }
                                    }
                                    .onEnded { value in
                                        if value.translation.height > 100 {
                                            tabManager.hideTabDrawer()
                                        }
                                        dragOffset = .zero
                                    }
                            )
                    }
                }
                #endif
                
                // Invisible area at bottom to show URL bar when touched (iOS only)
                #if os(iOS)
                if settings.autoHideURLBar && !urlBarVisible {
                    VStack {
                        Spacer()
                        Rectangle()
                            .fill(Color.clear)
                            .frame(height: 80) // Increased height for easier access
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    urlBarVisible = true
                                }
                            }
                            .gesture(
                                DragGesture()
                                    .onEnded { value in
                                        // Swipe up from bottom to show URL bar
                                        if value.translation.height < -20 {
                                            withAnimation(.easeInOut(duration: 0.3)) {
                                                urlBarVisible = true
                                            }
                                        }
                                    }
                            )
                    }
                }
                #endif
                
                // Invisible area at bottom to show URL bar when hovered (macOS only)
                #if os(macOS)
                if settings.autoHideURLBar && !urlBarVisible {
                    VStack {
                        Spacer()
                        Rectangle()
                            .fill(Color.clear)
                            .frame(height: 80) // Height for hover detection
                            .contentShape(Rectangle())
                            .onHover { hovering in
                                if hovering {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        urlBarVisible = true
                                    }
                                }
                            }
                    }
                }
                #endif
                
                // macOS hover area for tab drawer (only when not visible)
                #if os(macOS)
                if !tabManager.isTabDrawerVisible {
                    HStack {
                        if settings.tabDrawerPosition == .left {
                            Rectangle()
                                .fill(Color.clear)
                                .frame(width: 20)
                                .contentShape(Rectangle())
                                .overlay(
                                    GeometryReader { geo in
                                        VStack(spacing: 0) {
                                            Rectangle()
                                                .fill(Color.clear)
                                                .frame(width: 20, height: geo.size.height * 0.8)
                                                .contentShape(Rectangle())
                                                .onHover { hovering in
                                                    if hovering { tabManager.toggleTabDrawer() }
                                                }
                                            Spacer(minLength: geo.size.height * 0.2)
                                        }
                                    }
                                )
                            Spacer()
                        } else {
                            Spacer()
                            Rectangle()
                                .fill(Color.clear)
                                .frame(width: 20)
                                .contentShape(Rectangle())
                                .overlay(
                                    GeometryReader { geo in
                                        VStack(spacing: 0) {
                                            Rectangle()
                                                .fill(Color.clear)
                                                .frame(width: 20, height: geo.size.height * 0.8)
                                                .contentShape(Rectangle())
                                                .onHover { hovering in
                                                    if hovering { tabManager.toggleTabDrawer() }
                                                }
                                            Spacer(minLength: geo.size.height * 0.2)
                                        }
                                    }
                                )
                        }
                    }
                }
                #endif
                
                // iOS first-run default browser tooltip overlay
                #if os(iOS)
                if showDefaultBrowserTip {
                    Color.black.opacity(0.45)
                        .ignoresSafeArea()
                        .transition(.opacity)
                    
                    VStack {
                        Spacer()
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 10) {
                                Image(systemName: "safari")
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundColor(.accentColor)
                                Text("Make EvoArc your default browser")
                                    .font(.headline)
                            }
                            Text("Open iOS Settings to set EvoArc as your Default Browser App. This lets links from other apps open here automatically.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            HStack(spacing: 10) {
                                Button(action: {
                                    openAppSettings()
                                    hasShownDefaultBrowserPrompt = true
                                    withAnimation { showDefaultBrowserTip = false }
                                }) {
                                    HStack {
                                        Image(systemName: "gear")
                                        Text("Open Settings")
                                            .fontWeight(.semibold)
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                                
                                Button(action: {
                                    hasShownDefaultBrowserPrompt = true
                                    withAnimation { showDefaultBrowserTip = false }
                                }) {
                                    Text("Not now")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color(UIColor.systemBackground))
                                .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
                        )
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                #endif
            }
.onAppear {
                setupInitialURL()
                AdBlockManager.shared.refreshOnLaunchIfNeeded()
                #if os(iOS)
                if !hasShownDefaultBrowserPrompt {
                    // Show one-time tip to set default browser on first run
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        withAnimation(.spring()) {
                            showDefaultBrowserTip = true
                        }
                    }
                }
                #endif
            }
        }
        #if os(iOS)
        .gesture(
            DragGesture()
                .onEnded { value in
                    // Swipe up from bottom to show tab drawer
                    if value.translation.height < -100 {
                        // Check if swipe started from bottom area
                        tabManager.toggleTabDrawer()
                    }
                }
        )
        #endif
        #if os(macOS)
        .onReceive(NotificationCenter.default.publisher(for: .toggleTabDrawer)) { _ in
            tabManager.toggleTabDrawer()
        }
        .onReceive(NotificationCenter.default.publisher(for: .newTab)) { _ in
            tabManager.createNewTab()
        }
        #endif
.sheet(isPresented: $showingSettings) {
            SettingsView(tabManager: tabManager)
        }
        .sheet(item: $perplexityManager.currentRequest) { request in
            PerplexityModalView(request: request, onDismiss: {
                perplexityManager.dismissModal()
            })
        }
        .onChange(of: tabManager.selectedTab?.id) {
            // Update URL bar when switching tabs
            setupInitialURL()
        }
        .onOpenURL { incomingURL in
            handleIncomingURL(incomingURL)
        }
}
    
    #if os(iOS)
    private func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString),
           UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }
    #endif
    
    private func setupInitialURL() {
        if let selectedTab = tabManager.selectedTab {
            urlString = selectedTab.url?.absoluteString ?? ""
        }
    }
    
    private func handleIncomingURL(_ url: URL) {
        // If redirect is disabled, just open the incoming URL in a new tab
        guard settings.redirectExternalSearches else {
            tabManager.createNewTab(url: url)
            return
        }
        
        if let query = extractSearchQuery(from: url),
           let target = BrowserSettings.shared.searchURL(for: query) {
            tabManager.createNewTab(url: target)
        } else {
            tabManager.createNewTab(url: url)
        }
    }
    
    private func extractSearchQuery(from url: URL) -> String? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        let host = (components.host ?? "").lowercased()
        let path = components.path.lowercased()
        let items = components.queryItems ?? []
        func value(for key: String) -> String? {
            items.first { $0.name.lowercased() == key }?.value
        }
        
// Google: https://www.google.com/search?q=... or /url?q=...
        if host.contains("google.") && (path.hasPrefix("/search") || path.hasPrefix("/url")) {
            return value(for: "q")
        }
        
// DuckDuckGo: https://duckduckgo.com/?q=...
        if host.contains("duckduckgo.") {
            return value(for: "q")
        }
        
// Bing: https://www.bing.com/search?q=...
        if host.contains("bing.") {
            return value(for: "q")
        }
        
        // Yahoo: https://search.yahoo.com/search?p=...
        if host.contains("yahoo.") {
return value(for: "p")
        }
        
// Qwant: https://www.qwant.com/?q=...
        if host.contains("qwant.") {
            return value(for: "q")
        }
        
// Startpage: https://www.startpage.com/sp/search?q=...
        if host.contains("startpage.") {
            return value(for: "q")
        }
        
// Presearch: https://presearch.com/search?q=...
        if host.contains("presearch") {
            return value(for: "q")
        }
        
// Ecosia: https://www.ecosia.org/search?q=...
        if host.contains("ecosia.") {
            return value(for: "q")
        }
        
        // Perplexity: https://www.perplexity.ai/search?q=... (sometimes 'query')
        if host.contains("perplexity.ai") {
return value(for: "q") ?? value(for: "query")
        }
        
// Yandex: https://yandex.com/search/?text=...
        if host.contains("yandex.") {
            return value(for: "text") ?? value(for: "q")
        }
        
        return nil
    }
}

struct BottomBarView: View {
    @Binding var urlString: String
    @Binding var isURLBarFocused: Bool
    @ObservedObject var tabManager: TabManager
    @ObservedObject var selectedTab: Tab
    @Binding var showingSettings: Bool
    @Binding var shouldNavigate: Bool
    @StateObject private var settings = BrowserSettings.shared
    @StateObject private var bookmarkManager = BookmarkManager.shared
    @StateObject private var searchPreloadManager = SearchPreloadManager.shared
    @State private var urlEditingText: String = ""
    @State private var searchTimer: Timer?
    @FocusState private var isTextFieldFocused: Bool
    
    private var systemBackgroundColor: Color {
        #if os(iOS)
        Color(UIColor.systemBackground)
        #else
        Color(NSColor.controlBackgroundColor)
        #endif
    }
    
    private var secondarySystemBackgroundColor: Color {
        #if os(iOS)
        Color(UIColor.secondarySystemBackground)
        #else
        Color(NSColor.controlBackgroundColor)
        #endif
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Progress bar
            if selectedTab.isLoading {
                ProgressView(value: selectedTab.estimatedProgress, total: 1.0)
                    .progressViewStyle(LinearProgressViewStyle())
                    .frame(height: 2)
            }
            
            HStack(spacing: 10) {
                // Tab indicator (swipe up to open) - always visible
                VStack(spacing: 2) {
                    Image(systemName: "chevron.compact.up")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Text("\(tabManager.tabs.count)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .frame(width: 28)
                
                // Navigation buttons - hidden when URL bar is focused
                if !isURLBarFocused {
                    HStack(spacing: 8) {
                        // Back button
                        Button(action: {
                            selectedTab.webView?.goBack()
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 18))
                                .frame(width: 36, height: 36)
                                .contentShape(Rectangle())
                        }
                        .disabled(!selectedTab.canGoBack)
                        
                        // Forward button
                        Button(action: {
                            selectedTab.webView?.goForward()
                        }) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 18))
                                .frame(width: 36, height: 36)
                                .contentShape(Rectangle())
                        }
                        .disabled(!selectedTab.canGoForward)
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
                }
                
                // URL bar - expanded when focused
                HStack {
                    Button(action: {
                        if selectedTab.isLoading {
                            selectedTab.webView?.stopLoading()
                        }
                    }) {
                        Image(systemName: selectedTab.isLoading ? "xmark" : "lock.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .disabled(!selectedTab.isLoading)
                    
                    TextField("Search or enter address", text: $urlEditingText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .onReceive(selectedTab.$url) { newURL in
                            if !isURLBarFocused {
                                urlEditingText = newURL?.absoluteString ?? ""
                            }
                        }
                        .onChange(of: urlEditingText) { _, newValue in
                            // Cancel previous timer
                            searchTimer?.invalidate()
                            
                            // Trigger search suggestions immediately (with debouncing in manager)
                            SearchSuggestionsManager.shared.getSuggestions(for: newValue)
                            
                            // Preload search results after a delay
                            if newValue.count > 2 {
                                searchTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
                                    searchPreloadManager.preloadSearch(for: newValue)
                                }
                            }
                        }
                        .onSubmit {
                            urlString = urlEditingText
                            shouldNavigate = true
                            isTextFieldFocused = false
                        }
                        .focused($isTextFieldFocused)
                        .onTapGesture {
                            if !isTextFieldFocused {
                                urlEditingText = urlString
                                isTextFieldFocused = true
                            }
                        }
                        .onChange(of: isTextFieldFocused) { _, focused in
                            isURLBarFocused = focused
                        }
                    
                    HStack(spacing: 8) {
                        // Show preloading indicator when active
                        if searchPreloadManager.isPreloading {
                            ProgressView()
                                .scaleEffect(0.6)
                        }
                        
                        // Bookmark button - only show when not focused or if there's a current URL
                        if !isURLBarFocused, let currentURL = selectedTab.url {
                            Button(action: {
                                if bookmarkManager.isBookmarked(url: currentURL) {
                                    if let bookmark = bookmarkManager.getBookmark(for: currentURL) {
                                        bookmarkManager.removeBookmark(bookmark)
                                    }
                                } else {
                                    let title = selectedTab.title.isEmpty ? currentURL.host ?? currentURL.absoluteString : selectedTab.title
                                    bookmarkManager.addBookmark(title: title, url: currentURL, folderID: bookmarkManager.favoritesFolder?.id)
                                }
                            }) {
                                Image(systemName: bookmarkManager.isBookmarked(url: currentURL) ? "bookmark.fill" : "bookmark")
                                    .font(.system(size: 12))
                                    .foregroundColor(bookmarkManager.isBookmarked(url: currentURL) ? .accentColor : .secondary)
                            }
                        }
                        
                        // Clear button when focused
                        if isURLBarFocused && !urlEditingText.isEmpty {
                            Button(action: {
                                urlEditingText = ""
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // Reload/stop button - only show when not focused
                        if !isURLBarFocused {
                            if selectedTab.isLoading {
                                ProgressView()
                                    .scaleEffect(0.7)
                            } else {
                                Button(action: {
                                    selectedTab.webView?.reload()
                                }) {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.system(size: 12))
                                }
                            }
                        }
                        
                        // Done button when focused
                        if isURLBarFocused {
                            Button(action: {
                                isTextFieldFocused = false
                                urlString = urlEditingText
                                if !urlEditingText.isEmpty {
                                    shouldNavigate = true
                                }
                            }) {
                                Text("Done")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(secondarySystemBackgroundColor)
                .cornerRadius(8)
                .animation(.easeInOut(duration: 0.25), value: isURLBarFocused)
                
                // Right side buttons - hidden when URL bar is focused
                if !isURLBarFocused {
                    HStack(spacing: 8) {
                        // Pin/Unpin button
                        Button(action: {
                            if selectedTab.isPinned {
                                tabManager.unpinTab(selectedTab)
                            } else {
                                tabManager.pinTab(selectedTab)
                            }
                        }) {
                            Image(systemName: selectedTab.isPinned ? "pin.slash" : "pin")
                                .font(.system(size: 18))
                                .foregroundColor(selectedTab.isPinned ? .accentColor : .primary)
                        }
                        .disabled(selectedTab.url == nil)
                        
                        // Menu button
                        Menu {
                            Button(action: {
                                tabManager.createNewTab()
                            }) {
                                Label("New Tab", systemImage: "plus.square")
                            }
                            
                            Button(action: {
                                // Navigate to homepage in current tab
                                if let homepage = BrowserSettings.shared.homepageURL {
                                    selectedTab.webView?.load(URLRequest(url: homepage))
                                }
                            }) {
                                Label("Home", systemImage: "house")
                            }
                            
                            Divider()
                            
                            Button(action: {
                                settings.useDesktopMode.toggle()
                            }) {
                                Label(
                                    settings.useDesktopMode ? "Request Mobile Website" : "Request Desktop Website",
                                    systemImage: settings.useDesktopMode ? "iphone" : "desktopcomputer"
                                )
                            }
                            
                            // JavaScript blocking toggle for current site
                            if let currentURL = selectedTab.url {
                                Button(action: {
                                    JavaScriptBlockingManager.shared.toggleJavaScriptBlocking(for: currentURL)
                                    // Reload the page to apply the change
                                    selectedTab.webView?.reload()
                                }) {
                                    let isBlocked = JavaScriptBlockingManager.shared.isJavaScriptBlocked(for: currentURL)
                                    Label(
                                        isBlocked ? "Enable JavaScript" : "Disable JavaScript",
                                        systemImage: isBlocked ? "play.fill" : "stop.fill"
                                    )
                                }
                            }
                            
                            Divider()
                            
                            Button(action: {
                                // Share functionality
                            }) {
                                Label("Share", systemImage: "square.and.arrow.up")
                            }
                            
                            Button(action: {
                                showingSettings = true
                            }) {
                                Label("Settings", systemImage: "gear")
                            }
                            
                            // Note: Preloaded search results option removed from ellipsis menu to prevent duplication
                            
                            // Perplexity options
                            if PerplexityManager.shared.isAuthenticated, let currentURL = selectedTab.url {
                                Divider()
                                
                                Button(action: {
                                    PerplexityManager.shared.performAction(
                                        .summarize,
                                        for: currentURL,
                                        title: selectedTab.title
                                    )
                                }) {
                                    Label("Summarize with Perplexity", systemImage: "doc.text.magnifyingglass")
                                }
                                
                                Button(action: {
                                    PerplexityManager.shared.performAction(
                                        .sendToPerplexity,
                                        for: currentURL,
                                        title: selectedTab.title
                                    )
                                }) {
                                    Label("Send to Perplexity", systemImage: "arrow.up.right.square")
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 20))
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(systemBackgroundColor)
            .animation(.easeInOut(duration: 0.25), value: isURLBarFocused)
            
            // Enhanced suggestions with history and search - Safari-style clean interface
            if isURLBarFocused {
                EnhancedSuggestionsView(
                    query: urlEditingText,
                    preloadedResult: searchPreloadManager.getPreloadedResult(for: urlEditingText),
                    onSuggestionTap: { suggestion in
                        urlEditingText = suggestion
                        urlString = suggestion
                        shouldNavigate = true
                        isTextFieldFocused = false
                    },
                    onTopResultTap: { url in
                        urlString = url.absoluteString
                        shouldNavigate = true
                        isTextFieldFocused = false
                    }
                )
                .background(secondarySystemBackgroundColor)
                .cornerRadius(8)
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                .padding(.horizontal, 12)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .onAppear {
            urlEditingText = urlString
        }
        .onDisappear {
            searchTimer?.invalidate()
        }
    }
    
    private func formatURL(from string: String) -> URL? {
        // Check if it's already a valid URL
        if let url = URL(string: string), url.scheme != nil {
            return url
        }
        
        // Check if it looks like a domain
        if string.contains(".") && !string.contains(" ") {
            if let url = URL(string: "https://\(string)") {
                return url
            }
        }
        
        // Otherwise, treat it as a search query using the selected default search engine
        let searchQuery = string
        return BrowserSettings.shared.searchURL(for: searchQuery)
    }
    
}

struct SearchSuggestionsView: View {
    let query: String
    let suggestions: [String]
    let preloadedResult: SearchPreloadManager.SearchResult?
    let onSuggestionTap: (String) -> Void
    let onTopResultTap: (URL) -> Void
    
    private var systemBackgroundColor: Color {
        #if os(iOS)
        Color(UIColor.systemBackground)
        #else
        Color(NSColor.controlBackgroundColor)
        #endif
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top search result (if available)
            if let preloadedResult = preloadedResult,
               let firstResultURL = preloadedResult.firstResultURL {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "1.circle.fill")
                            .foregroundColor(.accentColor)
                            .font(.system(size: 14))
                        Text("Top Result")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    
                    Button(action: {
                        onTopResultTap(firstResultURL)
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(preloadedResult.firstResultTitle ?? firstResultURL.host ?? "Website")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.leading)
                                    .lineLimit(2)
                                
                                Text(firstResultURL.host ?? firstResultURL.absoluteString)
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(systemBackgroundColor.opacity(0.5))
                
                Divider()
            }
            
            // Search suggestions
            ForEach(suggestions, id: \.self) { suggestion in
                Button(action: {
                    onSuggestionTap(suggestion)
                }) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        
                        Text(suggestion)
                            .font(.system(size: 14))
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        // Highlight matching part
                        if suggestion.lowercased().contains(query.lowercased()) {
                            Image(systemName: "arrow.up.left")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.clear)
                .contentShape(Rectangle())
                
                if suggestion != suggestions.last {
                    Divider()
                        .padding(.leading, 32)
                }
            }
        }
        .frame(maxHeight: 300)
    }
}

struct EnhancedSuggestionsView: View {
    let query: String
    let preloadedResult: SearchPreloadManager.SearchResult?
    let onSuggestionTap: (String) -> Void
    let onTopResultTap: (URL) -> Void
    
    @StateObject private var suggestionManager = SuggestionManager()
    @StateObject private var searchSuggestionManager = SearchSuggestionsManager.shared
    @StateObject private var bookmarkManager = BookmarkManager.shared
    
    private var systemBackgroundColor: Color {
        #if os(iOS)
        Color(UIColor.systemBackground)
        #else
        Color(NSColor.controlBackgroundColor)
        #endif
    }
    
    private var secondarySystemBackgroundColor: Color {
        #if os(iOS)
        Color(UIColor.secondarySystemBackground)
        #else
        Color(NSColor.controlBackgroundColor)
        #endif
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top result from website (if available)
            if let preloadedResult = preloadedResult,
               let firstResultURL = preloadedResult.firstResultURL {
                TopResultView(
                    title: preloadedResult.firstResultTitle ?? firstResultURL.host ?? "Website",
                    url: firstResultURL,
                    onTap: { onTopResultTap(firstResultURL) }
                )
                .background(systemBackgroundColor.opacity(0.5))
                
                Divider()
            }
            
            // Search Suggestions (privacy-focused via DuckDuckGo, but searches use user's preferred engine)
            if !query.isEmpty && !searchSuggestionManager.suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    // No section header for search suggestions - match Safari's clean look
                    ForEach(searchSuggestionManager.suggestions.indices, id: \.self) { index in
                        let suggestion = searchSuggestionManager.suggestions[index]
                        Button(action: { onSuggestionTap(suggestion.text) }) {
                            HStack(spacing: 12) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 16))
                                    .foregroundColor(.secondary)
                                    .frame(width: 20, height: 20)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(suggestion.text)
                                        .font(.system(size: 17))
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                
                                Spacer()
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.clear)
                        .contentShape(Rectangle())
                        
                        if index < searchSuggestionManager.suggestions.count - 1 {
                            Divider()
                                .padding(.leading, 48)
                        }
                    }
                }
                
                if !getBookmarkSuggestions(for: query).isEmpty || !HistoryManager.shared.getHistorySuggestions(for: query).isEmpty {
                    Divider()
                }
            }
            
            // Bookmarks and History Section
            if !query.isEmpty {
                let historySuggestions = HistoryManager.shared.getHistorySuggestions(for: query)
                let bookmarkSuggestions = getBookmarkSuggestions(for: query)
                let combinedSuggestions = getCombinedSuggestions(bookmarkSuggestions: bookmarkSuggestions, historySuggestions: historySuggestions)
                
                if !combinedSuggestions.isEmpty {
                    SuggestionSectionView(
                        title: "Bookmarks and History",
                        suggestions: combinedSuggestions
                    )
                }
            } else {
                // Show recent history and bookmarks when no query
                let recentHistory = Array(HistoryManager.shared.recentHistory.prefix(3))
                let recentBookmarks = Array(bookmarkManager.bookmarks.prefix(3))
                
                if !recentHistory.isEmpty {
                    SuggestionSectionView(
                        title: "Recently Visited",
                        suggestions: recentHistory.map { entry in
                            SuggestionRowData(
                                text: entry.title,
                                subtitle: entry.url.host ?? entry.url.absoluteString,
                                icon: "clock",
                                action: { onTopResultTap(entry.url) }
                            )
                        }
                    )
                    
                    if !recentBookmarks.isEmpty {
                        Divider()
                    }
                }
                
                if !recentBookmarks.isEmpty {
                    SuggestionSectionView(
                        title: "Bookmarks",
                        suggestions: recentBookmarks.map { bookmark in
                            SuggestionRowData(
                                text: bookmark.title,
                                subtitle: bookmark.url.host ?? bookmark.url.absoluteString,
                                icon: "bookmark.fill",
                                action: { onTopResultTap(bookmark.url) }
                            )
                        }
                    )
                }
            }
        }
        .frame(maxHeight: 400)
        .onAppear {
            if !query.isEmpty {
                searchSuggestionManager.getSuggestions(for: query)
                suggestionManager.getSuggestions(for: query)
            }
        }
        .onChange(of: query) { _, newQuery in
            if !newQuery.isEmpty {
                searchSuggestionManager.getSuggestions(for: newQuery)
                suggestionManager.getSuggestions(for: newQuery)
            }
        }
    }
    
    private func getBookmarkSuggestions(for query: String) -> [Bookmark] {
        let lowercaseQuery = query.lowercased()
        return bookmarkManager.bookmarks.filter { bookmark in
            bookmark.title.lowercased().contains(lowercaseQuery) ||
            bookmark.url.absoluteString.lowercased().contains(lowercaseQuery) ||
            bookmark.url.host?.lowercased().contains(lowercaseQuery) == true
        }
    }
    
    private func getCombinedSuggestions(bookmarkSuggestions: [Bookmark], historySuggestions: [HistoryEntry]) -> [SuggestionRowData] {
        var combined: [SuggestionRowData] = []
        
        // Add bookmark suggestions (up to 2)
        combined.append(contentsOf: bookmarkSuggestions.prefix(2).map { bookmark in
            SuggestionRowData(
                text: bookmark.title,
                subtitle: bookmark.url.host ?? bookmark.url.absoluteString,
                icon: "bookmark.fill",
                action: { onTopResultTap(bookmark.url) }
            )
        })
        
        // Add history suggestions (up to 2)
        combined.append(contentsOf: historySuggestions.prefix(2).map { historyEntry in
            SuggestionRowData(
                text: historyEntry.title,
                subtitle: historyEntry.url.host ?? historyEntry.url.absoluteString,
                icon: "clock",
                action: { onTopResultTap(historyEntry.url) }
            )
        })
        
        return Array(combined.prefix(4))
    }
}

struct TopResultView: View {
    let title: String
    let url: URL
    let onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "1.circle.fill")
                    .foregroundColor(.accentColor)
                    .font(.system(size: 14))
                Text("Top Result")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
            }
            
            Button(action: onTap) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                        
                        Text(url.host ?? url.absoluteString)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

struct SuggestionRowData {
    let text: String
    let subtitle: String?
    let icon: String
    let action: () -> Void
}

struct SuggestionSectionView: View {
    let title: String
    let suggestions: [SuggestionRowData]
    
    private var secondarySystemBackgroundColor: Color {
        #if os(iOS)
        Color(UIColor.secondarySystemBackground)
        #else
        Color(NSColor.controlBackgroundColor)
        #endif
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header
            HStack {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(secondarySystemBackgroundColor.opacity(0.5))
            
            // Suggestions
            ForEach(suggestions.indices, id: \.self) { index in
                let suggestion = suggestions[index]
                Button(action: suggestion.action) {
                    HStack(spacing: 12) {
                        Image(systemName: suggestion.icon)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .frame(width: 20, height: 20)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(suggestion.text)
                                .font(.system(size: 15))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            
                            if let subtitle = suggestion.subtitle {
                                Text(subtitle)
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        
                        Spacer()
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal, 16)
                .padding(.vertical, suggestion.subtitle != nil ? 8 : 10)
                .background(Color.clear)
                .contentShape(Rectangle())
                
                if index < suggestions.count - 1 {
                    Divider()
                        .padding(.leading, 48)
                }
            }
        }
    }
}

#if os(macOS)
extension Notification.Name {
    static let toggleTabDrawer = Notification.Name("toggleTabDrawer")
}
#endif

#Preview {
    ContentView()
}
