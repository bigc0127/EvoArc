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
    // State Objects
    @StateObject private var tabManager = TabManager()
    @StateObject private var settings = BrowserSettings.shared
    @StateObject private var perplexityManager = PerplexityManager.shared
    
    // State Variables
    @State private var urlString: String = ""
    @State private var isURLBarFocused: Bool = false
    @State private var dragOffset: CGSize = .zero
    @State private var showHoverArea: Bool = false
    @State private var showingSettings: Bool = false
    @State private var shouldNavigate: Bool = false
    @State private var urlBarVisible: Bool = true
    @State private var lastScrollOffset: CGFloat = 0
    @State private var showDefaultBrowserTip: Bool = false
    @State private var keyboardHeight: CGFloat = 0
    @State private var keyboardVisible: Bool = false
    
    // App Storage
    @AppStorage("hasShownDefaultBrowserPrompt") private var hasShownDefaultBrowserPrompt: Bool = false
    
    // Environment Values
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    // MARK: - Main View
    var body: some View {
        GeometryReader { geometry in
            #if os(iOS)
            // Set up keyboard observers
            let _ = NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { notification in
                if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                    keyboardHeight = keyboardFrame.height
                    keyboardVisible = true
                }
            }
            let _ = NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { _ in
                keyboardHeight = 0
                keyboardVisible = false
            }
            #endif
            ZStack {
                #if os(iOS)
                // MARK: - iOS Layout
                // URL bar at bottom with tab drawer overlay
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
                }
                
                // Bottom URL bar
                if urlBarVisible || !settings.autoHideURLBar {
                    VStack {
                        Spacer()
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
                            .ignoresSafeArea(.keyboard)
                            .ignoresSafeArea(.container, edges: .bottom)
                            .padding(.bottom, keyboardVisible ? keyboardHeight : 0)
                            .animation(.easeOut(duration: 0.25), value: keyboardHeight)
                        }
                    }
                }
                #else
                // MARK: - macOS Layout
                // Tab drawer on side, URL bar at bottom
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
                        .onTapGesture { tabManager.hideTabDrawer() }
                    
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
                
                // Invisible area at bottom to show URL bar when touched (iOS only)
                if settings.autoHideURLBar && !urlBarVisible {
                    VStack {
                        Spacer()
                        Rectangle()
                            .fill(Color.clear)
                            .frame(height: 80)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    urlBarVisible = true
                                }
                            }
                            .gesture(
                                DragGesture()
                                    .onEnded { value in
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
                
                // macOS hover area for tab drawer
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
                            RoundedRectangle(cornerRadius: UIScaleMetrics.scaledPadding(14), style: .continuous)
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
            #if os(iOS)
            .gesture(
                DragGesture(minimumDistance: 20)
                    .onEnded { value in
                        // Only process gesture if BottomBarView gesture is not active
                        if !tabManager.isGestureActive {
                            let threshold: CGFloat = -100
                            let startY = value.startLocation.y
                            let screenHeight = UIScreen.main.bounds.height
                            
                            // Check if gesture started in bottom 20% of screen
                            if startY > screenHeight * 0.8 && value.translation.height < threshold {
                                withAnimation(.spring()) {
                                    tabManager.toggleTabDrawer()
                                }
                            }
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
        .ignoresSafeArea()
    }
    
    // MARK: - Helper Functions
    
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
            // Only show URL if explicitly enabled
            if selectedTab.showURLInBar {
                urlString = selectedTab.url?.absoluteString ?? ""
            } else {
                urlString = ""
            }
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
    
    // MARK: - URL Parsing
    
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

// MARK: - macOS Extensions
#if os(macOS)
extension Notification.Name {
    static let toggleTabDrawer = Notification.Name("toggleTabDrawer")
}
#endif

#Preview {
    ContentView()
}

