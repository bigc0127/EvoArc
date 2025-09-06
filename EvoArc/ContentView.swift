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
    @AppStorage("hasShownDefaultBrowserPrompt") private var hasShownDefaultBrowserPrompt: Bool = false
    @State private var showDefaultBrowserTip: Bool = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                #if os(iOS)
                // iOS Layout: URL bar at bottom with tab drawer overlay
                VStack(spacing: 0) {
                    // Web content area
                    if !tabManager.tabs.isEmpty {
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
                        BottomBarView(
                            urlString: $urlString,
                            isURLBarFocused: $isURLBarFocused,
                            tabManager: tabManager,
                            selectedTab: tabManager.selectedTab,
                            showingSettings: $showingSettings,
                            shouldNavigate: $shouldNavigate
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(.easeInOut(duration: 0.3), value: urlBarVisible)
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
                        if !tabManager.tabs.isEmpty {
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
                        
                        // Bottom URL bar (macOS style)
                        MacOSBottomBarView(
                            urlString: $urlString,
                            isURLBarFocused: $isURLBarFocused,
                            tabManager: tabManager,
                            selectedTab: tabManager.selectedTab,
                            showingSettings: $showingSettings,
                            shouldNavigate: $shouldNavigate
                        )
                        .opacity(urlBarVisible ? 1 : 0)
                        .animation(.easeInOut(duration: 0.3), value: urlBarVisible)
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
                
                // macOS hover area for tab drawer (only when not visible)
                #if os(macOS)
                if !tabManager.isTabDrawerVisible {
                    HStack {
                        if settings.tabDrawerPosition == .left {
                            Rectangle()
                                .fill(Color.clear)
                                .frame(width: 20)
                                .contentShape(Rectangle())
                                .onHover { hovering in
                                    if hovering {
                                        tabManager.toggleTabDrawer()
                                    }
                                }
                            Spacer()
                        } else {
                            Spacer()
                            Rectangle()
                                .fill(Color.clear)
                                .frame(width: 20)
                                .contentShape(Rectangle())
                                .onHover { hovering in
                                    if hovering {
                                        tabManager.toggleTabDrawer()
                                    }
                                }
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
    var selectedTab: Tab?
    @Binding var showingSettings: Bool
    @Binding var shouldNavigate: Bool
    @StateObject private var settings = BrowserSettings.shared
    
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
            if let tab = selectedTab, tab.isLoading {
                ProgressView(value: tab.estimatedProgress, total: 1.0)
                    .progressViewStyle(LinearProgressViewStyle())
                    .frame(height: 2)
            }
            
            HStack(spacing: 10) {
                // Tab indicator (swipe up to open)
                VStack(spacing: 2) {
                    Image(systemName: "chevron.compact.up")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Text("\(tabManager.tabs.count)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .frame(width: 28)
                
                // Back button
                Button(action: {
                    selectedTab?.webView?.goBack()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18))
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .disabled(!(selectedTab?.canGoBack ?? false))
                
                // Forward button
                Button(action: {
                    selectedTab?.webView?.goForward()
                }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 18))
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .disabled(!(selectedTab?.canGoForward ?? false))
                
                // URL bar
                HStack {
                    Button(action: {
                        if selectedTab?.isLoading ?? false {
                            selectedTab?.webView?.stopLoading()
                        }
                    }) {
                        Image(systemName: selectedTab?.isLoading ?? false ? "xmark" : "lock.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .disabled(!(selectedTab?.isLoading ?? false))
                    
                    TextField("Search or enter address", text: $urlString)
                        .textFieldStyle(PlainTextFieldStyle())
                        .onSubmit {
                            shouldNavigate = true
                        }
                    
                    if selectedTab?.isLoading ?? false {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Button(action: {
                            selectedTab?.webView?.reload()
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 12))
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(secondarySystemBackgroundColor)
                .cornerRadius(8)
                
                // Spacer for better touch target separation
                Spacer(minLength: 12)
                
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
                            selectedTab?.webView?.load(URLRequest(url: homepage))
                        }
                    }) {
                        Label("Home", systemImage: "house")
                    }
                    
                    Button(action: {
                        settings.useDesktopMode.toggle()
                    }) {
                        Label(
                            settings.useDesktopMode ? "Request Mobile Website" : "Request Desktop Website",
                            systemImage: settings.useDesktopMode ? "iphone" : "desktopcomputer"
                        )
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
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 20))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(systemBackgroundColor)
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

#if os(macOS)
extension Notification.Name {
    static let toggleTabDrawer = Notification.Name("toggleTabDrawer")
}
#endif

#Preview {
    ContentView()
}
