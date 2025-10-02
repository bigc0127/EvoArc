//
//  ContentView.swift
//  EvoArc
//
//  Created by Connor W. Needling on 2025-09-04.
//

import SwiftUI
import WebKit
import UIKit
import Combine

struct ContentView: View {
    // State Objects
    @StateObject private var tabManager = TabManager()
    @StateObject private var settings = BrowserSettings.shared
    @StateObject private var perplexityManager = PerplexityManager.shared
    @StateObject private var uiViewModel = UIViewModel() // ARC Like UI state
    
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
    @State private var canGoBack: Bool = false
    @State private var canGoForward: Bool = false
    
    // App Storage
    @AppStorage("hasShownDefaultBrowserPrompt") private var hasShownDefaultBrowserPrompt: Bool = false
    
    // Environment Values
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorScheme) private var colorScheme
    // MARK: - Main View
    var body: some View {
        GeometryReader { geometry in
            // Check if we're on iPhone or iPad
            if UIDevice.current.userInterfaceIdiom == .phone {
                // iPhone UI - keep original design
                iphoneLayout(geometry: geometry)
            } else {
                // iPad UI - use ARC Like UI design
                arcLikeLayout(geometry: geometry)
            }
        }
    }
    
    // MARK: - iPhone Layout (Original)
    
    @ViewBuilder
    private func iphoneLayout(geometry: GeometryProxy) -> some View {
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
        
        ZStack {
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
                    .ignoresSafeArea(edges: urlBarVisible ? [] : .bottom)
                } else if !tabManager.isInitialized {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            VStack(spacing: 16) {
                                ProgressView()
                                    .scaleEffect(1.5)
                                Text("Restoring tabs...")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        Spacer()
                    }
                } else {
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
                            showingSettings: $showingSettings,
                            shouldNavigate: $shouldNavigate,
                            selectedTab: selected,
                            tabManager: tabManager
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(.easeInOut(duration: 0.3), value: urlBarVisible)
                        .ignoresSafeArea(.keyboard)
                        .ignoresSafeArea(.container, edges: .bottom)
                    }
                }
            }
            
            // Tab drawer overlay
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
            
            // Invisible area at bottom to show URL bar when touched
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
            
            // iOS first-run default browser tooltip overlay
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
        }
        .onAppear {
            setupInitialURL()
            AdBlockManager.shared.refreshOnLaunchIfNeeded()
            if !hasShownDefaultBrowserPrompt {
                // Show one-time tip to set default browser on first run
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    withAnimation(.spring()) {
                        showDefaultBrowserTip = true
                    }
                }
            }
        }
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
    
    // MARK: - ARC Like Layout (iPad & macOS)
    
    @ViewBuilder
    private func arcLikeLayout(geometry: GeometryProxy) -> some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: uiViewModel.backgroundGradient,
                startPoint: .bottomLeading,
                endPoint: .topTrailing
            )
            .overlay {
                if colorScheme == .dark {
                    Color.black.opacity(0.5)
                }
            }
            .ignoresSafeArea()
            
            // Main layout
            HStack(spacing: 0) {
                // Sidebar (left) - only render inline when NOT floating
                if uiViewModel.sidebarPosition == "left" && uiViewModel.showSidebar && !uiViewModel.isSidebarFloating {
                    SidebarView(tabManager: tabManager, uiViewModel: uiViewModel)
                        .padding(.leading, 10)
                        .padding(.vertical, 5)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                }
                
                // Web content panel
                WebContentPanel(
                    tabManager: tabManager,
                    uiViewModel: uiViewModel,
                    urlString: $urlString,
                    shouldNavigate: $shouldNavigate,
                    urlBarVisible: $urlBarVisible,
                    onNavigate: { url in
                        urlString = url.absoluteString
                    }
                )
                .padding(.top, 5)
                .padding(.bottom, 5)
                .padding(.leading, uiViewModel.sidebarPosition == "right" || !uiViewModel.showSidebar ? 5 : 0)
                .padding(.trailing, uiViewModel.sidebarPosition == "left" || !uiViewModel.showSidebar ? 5 : 0)
                .gesture(
                    DragGesture(minimumDistance: 30)
                        .onEnded { value in
                            // Swipe navigation when sidebar is hidden
                            if !uiViewModel.showSidebar {
                                let horizontalSwipe = value.translation.width
                                let verticalSwipe = abs(value.translation.height)
                                
                                // Only handle horizontal swipes (not vertical)
                                if abs(horizontalSwipe) > verticalSwipe * 2 {
                                    if horizontalSwipe > 80 {
                                        // Swipe right - go back
                                        tabManager.selectedTab?.webView?.goBack()
                                    } else if horizontalSwipe < -80 {
                                        // Swipe left - go forward
                                        tabManager.selectedTab?.webView?.goForward()
                                    }
                                }
                            }
                        }
                )
                
                // Sidebar (right) - only render inline when NOT floating
                if uiViewModel.sidebarPosition == "right" && uiViewModel.showSidebar && !uiViewModel.isSidebarFloating {
                    SidebarView(tabManager: tabManager, uiViewModel: uiViewModel)
                        .padding(.trailing, 10)
                        .padding(.vertical, 5)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.3), value: uiViewModel.showSidebar)
            .animation(.easeInOut(duration: 0.3), value: uiViewModel.sidebarPosition)
            .overlay {
                if uiViewModel.showCommandBar {
                    Color.white.opacity(0.001)
                        .onTapGesture {
                            uiViewModel.showCommandBar = false
                            uiViewModel.commandBarText = ""
                            uiViewModel.searchSuggestions = []
                        }
                }
            }
            
            // Command bar overlay
            if uiViewModel.showCommandBar {
                CommandBarView(tabManager: tabManager, uiViewModel: uiViewModel, geo: geometry)
            }
            
            // Sidebar toggle button (top corner) - iPad/macOS
            if !uiViewModel.showSidebar {
                VStack {
                    HStack {
                        if uiViewModel.sidebarPosition == "left" {
                            // Button on left when sidebar is on left
                            sidebarToggleButton
                            Spacer()
                        } else {
                            // Button on right when sidebar is on right
                            Spacer()
                            sidebarToggleButton
                        }
                    }
                    .padding(.horizontal, 15)
                    .padding(.top, 15)
                    Spacer()
                }
            }
            
            // Navigation buttons (iPad only) - positioned based on settings
            if !uiViewModel.showSidebar && UIDevice.current.userInterfaceIdiom == .pad && !settings.hideNavigationButtonsOnIPad {
                navigationButtonsOverlay
            }
            
            // Hover area for sidebar reveal (wider area for better detection)
            // On iPad: triggers floating sidebar. On Mac: triggers inline sidebar.
            if !uiViewModel.showSidebar {
                HStack {
                    if uiViewModel.sidebarPosition == "left" {
                        Rectangle()
                            .fill(Color.clear)
                            .frame(width: 50) // Wider for easier hover detection
                            .contentShape(Rectangle())
                            .onHover { hovering in
                                if hovering {
                                    withAnimation(.easeInOut) {
                                        // iPad: use floating mode; others: use docked mode
                                        if UIDevice.current.userInterfaceIdiom == .pad {
                                            uiViewModel.isSidebarFloating = true
                                        } else {
                                            uiViewModel.isSidebarFloating = false
                                        }
                                        uiViewModel.showSidebar = true
                                    }
                                }
                            }
                        Spacer()
                    } else {
                        Spacer()
                        Rectangle()
                            .fill(Color.clear)
                            .frame(width: 50) // Wider for easier hover detection
                            .contentShape(Rectangle())
                            .onHover { hovering in
                                if hovering {
                                    withAnimation(.easeInOut) {
                                        // iPad: use floating mode; others: use docked mode
                                        if UIDevice.current.userInterfaceIdiom == .pad {
                                            uiViewModel.isSidebarFloating = true
                                        } else {
                                            uiViewModel.isSidebarFloating = false
                                        }
                                        uiViewModel.showSidebar = true
                                    }
                                }
                            }
                    }
                }
            }
            
            // Floating sidebar overlay (iPad only)
            if uiViewModel.showSidebar && uiViewModel.isSidebarFloating && UIDevice.current.userInterfaceIdiom == .pad {
                // Semi-transparent backdrop
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture {
                        withAnimation(.easeInOut) {
                            uiViewModel.showSidebar = false
                            uiViewModel.isSidebarFloating = false
                        }
                    }
                
                // Floating sidebar panel
                HStack(spacing: 0) {
                    if uiViewModel.sidebarPosition == "left" {
                        // Left-aligned floating sidebar
                        SidebarView(tabManager: tabManager, uiViewModel: uiViewModel)
                            .frame(width: uiViewModel.sidebarWidth)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
                            .padding(.leading, 10)
                            .padding(.vertical, 10)
                            .transition(.move(edge: .leading).combined(with: .opacity))
                            .onHover { hovering in
                                // Keep sidebar visible while hovering over it
                                if !hovering {
                                    // Small delay before hiding to prevent flickering
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                        withAnimation(.easeInOut) {
                                            uiViewModel.showSidebar = false
                                            uiViewModel.isSidebarFloating = false
                                        }
                                    }
                                }
                            }
                        
                        Spacer()
                    } else {
                        // Right-aligned floating sidebar
                        Spacer()
                        
                        SidebarView(tabManager: tabManager, uiViewModel: uiViewModel)
                            .frame(width: uiViewModel.sidebarWidth)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
                            .padding(.trailing, 10)
                            .padding(.vertical, 10)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                            .onHover { hovering in
                                // Keep sidebar visible while hovering over it
                                if !hovering {
                                    // Small delay before hiding to prevent flickering
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                        withAnimation(.easeInOut) {
                                            uiViewModel.showSidebar = false
                                            uiViewModel.isSidebarFloating = false
                                        }
                                    }
                                }
                            }
                    }
                }
            }
        }
        .onAppear {
            setupInitialURL()
            AdBlockManager.shared.refreshOnLaunchIfNeeded()
        }
        .sheet(isPresented: $uiViewModel.showSettings) {
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
    
    // MARK: - Helper Functions
    
    private func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString),
           UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }
    
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
    
    // MARK: - Sidebar Toggle Button
    
    private var sidebarToggleButton: some View {
        Button(action: {
            withAnimation(.easeInOut) {
                uiViewModel.isSidebarFloating = false // Manual toggle uses docked mode
                uiViewModel.showSidebar = true
            }
        }) {
            ZStack {
                // Frosted glass background with gradient tint
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 44, height: 44)
                    .overlay {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(hex: "8041E6").opacity(0.3),
                                        Color(hex: "A0F2FC").opacity(0.3)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .overlay {
                        Circle()
                            .strokeBorder(Color.white.opacity(0.4), lineWidth: 1.5)
                    }
                    .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4)
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                
                // Icon with darker color for visibility on light backgrounds
                Image(systemName: uiViewModel.sidebarPosition == "left" ? "sidebar.left" : "sidebar.right")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.black.opacity(0.75), Color.black.opacity(0.65)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: .white.opacity(0.5), radius: 1, x: 0, y: 1)
            }
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Navigation Buttons (iPad)
    
    @ViewBuilder
    private var navigationButtonsOverlay: some View {
        let position = settings.navigationButtonPosition
        
        VStack {
            if position == .topLeft || position == .topRight {
                HStack(spacing: 12) {
                    if position == .topLeft {
                        navigationButtonStack
                        Spacer()
                    } else {
                        Spacer()
                        navigationButtonStack
                    }
                }
                .padding(.horizontal, 15)
                .padding(.top, 80) // Below sidebar toggle
                Spacer()
            } else {
                Spacer()
                HStack(spacing: 12) {
                    if position == .bottomLeft {
                        navigationButtonStack
                        Spacer()
                    } else {
                        Spacer()
                        navigationButtonStack
                    }
                }
                .padding(.horizontal, 15)
                .padding(.bottom, 20)
            }
        }
    }
    
    private var navigationButtonStack: some View {
        HStack(spacing: 8) {
            if let selectedTab = tabManager.selectedTab {
                let _ = print("🟫 ContentView: Rendering nav buttons canGoBack=\(canGoBack) canGoForward=\(canGoForward)")
                // Back button
                navigationButton(
                    systemImage: "chevron.left",
                    action: { 
                        print("🟢 Back button tapped")
                        selectedTab.webView?.goBack() 
                    },
                    isEnabled: canGoBack
                )
                
                // Forward button
                navigationButton(
                    systemImage: "chevron.right",
                    action: { 
                        print("🟢 Forward button tapped")
                        selectedTab.webView?.goForward() 
                    },
                    isEnabled: canGoForward
                )
            }
        }
        .onReceive(tabManager.$selectedTab) { selectedTab in
            // Update state whenever selectedTab changes
            canGoBack = selectedTab?.canGoBack ?? false
            canGoForward = selectedTab?.canGoForward ?? false
            print("💬 onReceive selectedTab: canGoBack=\(canGoBack) canGoForward=\(canGoForward)")
        }
        .onReceive(Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()) { _ in
            // Poll for changes every 0.1 seconds as a workaround
            let newCanGoBack = tabManager.selectedTab?.canGoBack ?? false
            let newCanGoForward = tabManager.selectedTab?.canGoForward ?? false
            if newCanGoBack != canGoBack || newCanGoForward != canGoForward {
                canGoBack = newCanGoBack
                canGoForward = newCanGoForward
                print("💬 Timer update: canGoBack=\(canGoBack) canGoForward=\(canGoForward)")
            }
        }
    }
    
    private func navigationButton(systemImage: String, action: @escaping () -> Void, isEnabled: Bool) -> some View {
        Button(action: action) {
            ZStack {
                // Frosted glass background with gradient tint
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 44, height: 44)
                    .overlay {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(hex: "8041E6").opacity(isEnabled ? 0.3 : 0.1),
                                        Color(hex: "A0F2FC").opacity(isEnabled ? 0.3 : 0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .overlay {
                        Circle()
                            .strokeBorder(Color.white.opacity(isEnabled ? 0.4 : 0.2), lineWidth: 1.5)
                    }
                    .shadow(color: .black.opacity(isEnabled ? 0.15 : 0.05), radius: 12, x: 0, y: 4)
                    .shadow(color: .black.opacity(isEnabled ? 0.1 : 0.03), radius: 4, x: 0, y: 2)
                
                // Icon with darker color for visibility on light backgrounds
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color.black.opacity(isEnabled ? 0.75 : 0.3),
                                Color.black.opacity(isEnabled ? 0.65 : 0.25)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: .white.opacity(isEnabled ? 0.5 : 0.2), radius: 1, x: 0, y: 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

#Preview {
    ContentView()
}

