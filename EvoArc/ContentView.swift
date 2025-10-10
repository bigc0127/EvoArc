//
//  ContentView.swift
//  EvoArc
//
//  Created by Connor W. Needling on 2025-09-04.
//
//  This is the ROOT VIEW of the EvoArc browser app - the main container that
//  orchestrates all UI components, browser functionality, and user interactions.
//  It adapts between iPhone and iPad/Mac layouts dynamically.
//

// MARK: - Import Explanation for Beginners
import SwiftUI   // Apple's declarative UI framework - used for all views and layouts
import WebKit    // Web rendering engine - provides WKWebView for displaying web content
import UIKit     // iOS/iPadOS UI framework - used for device detection and system integration
import Combine   // Reactive programming framework - used for observing state changes (though not heavily used here)

// MARK: - What is ContentView?
// ContentView is the root SwiftUI view for EvoArc. It:
// 1. Manages the browser's tab system through TabManager
// 2. Adapts UI between iPhone (bottom bar) and iPad (sidebar) layouts
// 3. Handles URL navigation, settings, and user interactions
// 4. Coordinates with managers for browser settings, ad blocking, and Perplexity AI integration
//
// Key Swift/SwiftUI Concepts:
// - @StateObject: Creates and owns an observable object for the view's lifetime
// - @State: Creates mutable state that triggers view updates when changed
// - @AppStorage: Persists simple values to UserDefaults automatically
// - @Environment: Reads system-provided values (color scheme, dynamic type, etc.)
// - GeometryReader: A view that provides size and position information
// - @ViewBuilder: Allows functions to return multiple view types conditionally

/// The root view of the EvoArc browser application.
///
/// **Architecture**: ContentView acts as a coordinator, managing multiple child views
/// and state objects. It doesn't contain much business logic - instead, it delegates
/// to managers and child views.
///
/// **Adaptive Layout**: Uses `UIDevice.current.userInterfaceIdiom` to detect device type
/// and render either:
/// - iPhone: Bottom URL bar with traditional browser UI
/// - iPad/Mac: Arc-inspired sidebar interface with command bar
///
/// **State Management**: Uses property wrappers to observe and react to changes:
/// - @StateObject for owned, long-lived objects
/// - @State for local, view-specific mutable state
/// - @AppStorage for persistent user preferences
struct ContentView: View {
    
    // MARK: - State Objects (Long-lived, Observable)
    // These are objects that ContentView owns and observes for changes.
    // When their @Published properties change, ContentView automatically re-renders.
    //
    // @StateObject vs @ObservedObject:
    // - @StateObject: View OWNS the object (creates and manages its lifetime)
    // - @ObservedObject: View OBSERVES an object owned by someone else
    // Use @StateObject for objects created in this view, @ObservedObject for passed-in objects.
    
    /// The tab manager - handles all browser tabs, their state, and persistence.
    ///
    /// **What it does**: Manages the list of open tabs, which tab is selected,
    /// tab creation/deletion, and saving/restoring tabs between app launches.
    ///
    /// **Important**: This TabManager is passed from EvoArcApp (not created here)
    /// to ensure there's only ONE TabManager instance for the entire app.
    /// This allows share extension URLs to work properly.
    @ObservedObject var tabManager: TabManager
    
    /// The browser settings singleton - provides access to all user preferences.
    ///
    /// **Singleton Pattern**: `BrowserSettings.shared` ensures only one instance
    /// exists app-wide. All parts of the app reference the same settings object.
    @StateObject private var settings = BrowserSettings.shared
    
    /// The Perplexity AI manager - handles AI search integration.
    ///
    /// **What it does**: Manages requests to Perplexity AI (an AI-powered search engine)
    /// and displays results in a modal.
    @StateObject private var perplexityManager = PerplexityManager.shared
    
    /// The UI view model - manages iPad/Mac Arc-like UI state (sidebar, command bar, etc.).
    ///
    /// **iPad-specific**: This is primarily used for the iPad/Mac layout.
    /// Contains state for sidebar visibility, position, command bar, etc.
    @StateObject private var uiViewModel = UIViewModel()
    
    // MARK: - State Variables (Local, View-specific)
    // These are simple values that ContentView manages directly.
    // When they change, SwiftUI automatically re-renders affected parts of the view.
    //
    // @State Property Wrapper Explanation:
    // @State tells SwiftUI to manage storage for these values and watch for changes.
    // When a @State variable changes, SwiftUI re-computes the view's body.
    // Always mark @State as private - it's internal to this view.
    
    /// The text displayed in the URL bar.
    ///
    /// **Binding**: This is passed to child views using `$urlString` (a Binding),
    /// allowing them to read AND write the value.
    @State private var urlString: String = ""
    
    /// Whether the URL bar is currently focused (keyboard is up).
    ///
    /// **Use case**: Controls keyboard behavior and URL bar appearance.
    @State private var isURLBarFocused: Bool = false
    
    /// The current drag offset for the tab drawer.
    ///
    /// **CGSize Explanation**: A struct with width and height properties.
    /// Used to track gesture movement for dismissing the tab drawer.
    @State private var dragOffset: CGSize = .zero
    
    /// Whether to show the hover area for revealing hidden UI (currently unused).
    @State private var showHoverArea: Bool = false
    
    /// Whether the settings sheet is presented (iPhone layout).
    @State private var showingSettings: Bool = false
    
    /// Triggers navigation to the current URL when set to true.
    ///
    /// **Pattern**: This is a common SwiftUI pattern for triggering actions
    /// based on state changes. Child views set this to true to navigate.
    @State private var shouldNavigate: Bool = false
    
    /// Whether the URL bar is visible (for auto-hide feature).
    ///
    /// **Auto-hide**: If enabled in settings, the URL bar hides when scrolling
    /// and shows when the user taps the bottom of the screen.
    @State private var urlBarVisible: Bool = true
    
    /// The last recorded scroll offset (for auto-hide detection).
    ///
    /// **CGFloat**: A floating-point number type used for graphics/layout measurements.
    @State private var lastScrollOffset: CGFloat = 0
    
    /// Whether to show the "set as default browser" tip on first launch.
    @State private var showDefaultBrowserTip: Bool = false
    
    /// The current keyboard height (when keyboard is visible).
    ///
    /// **Use case**: Adjust layout to prevent keyboard from covering important UI.
    @State private var keyboardHeight: CGFloat = 0
    
    /// Whether the keyboard is currently visible.
    @State private var keyboardVisible: Bool = false
    
    /// Whether the web view can navigate backward (used for iPad nav buttons).
    @State private var canGoBack: Bool = false
    
    /// Whether the web view can navigate forward (used for iPad nav buttons).
    @State private var canGoForward: Bool = false
    
    // MARK: - App Storage (Persistent Preferences)
    // @AppStorage automatically saves values to UserDefaults (iOS's key-value storage).
    // Changes persist between app launches.
    //
    // @AppStorage vs @State:
    // - @State: Value exists only while the view is alive
    // - @AppStorage: Value persists to disk automatically
    
    /// Tracks whether we've shown the default browser prompt to the user.
    ///
    /// **Purpose**: Only show the prompt once on first launch, not every time.
    ///
    /// **UserDefaults Key**: "hasShownDefaultBrowserPrompt" - this is the key
    /// used to store/retrieve the value from UserDefaults.
    @AppStorage("hasShownDefaultBrowserPrompt") private var hasShownDefaultBrowserPrompt: Bool = false
    
    // MARK: - Environment Values (System-provided)
    // @Environment reads values provided by the SwiftUI environment.
    // These are system-level settings that change based on user preferences or device state.
    //
    // Environment vs State:
    // - @State: You control and modify the value
    // - @Environment: System provides the value (read-only in most cases)
    
    /// The current dynamic type size (user's text size preference in Settings).
    ///
    /// **Accessibility**: iOS users can adjust text size system-wide.
    /// Apps should respect this for accessibility. ContentView doesn't currently
    /// use this, but it's available for future layout adjustments.
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    /// The current color scheme (light or dark mode).
    ///
    /// **Use case**: ContentView uses this to adjust the iPad background gradient
    /// overlay (darker in dark mode).
    ///
    /// **ColorScheme**: An enum with cases `.light` and `.dark`.
    @Environment(\.colorScheme) private var colorScheme
    // MARK: - Main View (Entry Point)
    // This is ContentView's `body` property - SwiftUI calls this to render the view.
    // It's a computed property that returns a View.
    //
    // View Protocol Explanation:
    // All SwiftUI views must conform to the View protocol, which requires a `body` property.
    // The body describes what the view looks like and how it behaves.
    
    /// The main body of ContentView - adapts layout based on device type.
    ///
    /// **Architecture Decision**: EvoArc uses different UI paradigms for different devices:
    /// - **iPhone**: Traditional mobile browser with bottom URL bar and compact layout
    /// - **iPad/Mac**: Arc-inspired interface with sidebar, command bar, and spacious layout
    ///
    /// **GeometryReader Explanation**: A container view that provides access to its size
    /// and position through a `GeometryProxy` parameter. Child layouts use this to adapt
    /// to available space.
    ///
    /// **Device Detection**: `UIDevice.current.userInterfaceIdiom` returns:
    /// - `.phone` for iPhones
    /// - `.pad` for iPads
    /// - `.mac` for Mac Catalyst apps
    var body: some View {
        // GeometryReader provides size information to child views
        GeometryReader { geometry in
            // Device-specific layout branching
            if UIDevice.current.userInterfaceIdiom == .phone {
                // iPhone: Traditional mobile browser UI with bottom bar
                iphoneLayout(geometry: geometry)
            } else {
                // iPad/Mac: Arc-inspired UI with sidebar and command bar
                arcLikeLayout(geometry: geometry)
            }
        }
    }
    
    // MARK: - iPhone Layout (Original Mobile Browser UI)
    // This function returns the complete iPhone layout as a View.
    // It uses a ZStack to layer multiple UI elements (web content, URL bar, overlays).
    //
    // @ViewBuilder Explanation:
    // This attribute allows the function to return different view types and use
    // SwiftUI's declarative syntax (if/else, ForEach, etc.) directly.
    // Without @ViewBuilder, you'd need to wrap everything in AnyView or return a single type.
    
    /// Constructs the iPhone-specific browser layout.
    ///
    /// **Layout Strategy**: Uses ZStack to layer views on top of each other:
    /// 1. Bottom layer: Web content (TabViewContainer)
    /// 2. Middle layer: Bottom URL bar (BottomBarView)
    /// 3. Top layers: Tab drawer overlay, default browser tip, gesture areas
    ///
    /// **Keyboard Handling**: Sets up NotificationCenter observers to track keyboard
    /// visibility and adjust layout accordingly.
    ///
    /// **Parameter**:
    /// - geometry: Provides screen size for responsive layout calculations
    @ViewBuilder
    private func iphoneLayout(geometry: GeometryProxy) -> some View {
        // MARK: Keyboard Observers
        // These observers watch for keyboard show/hide notifications from iOS.
        // When the keyboard appears, we need to adjust the layout to prevent it
        // from covering important UI elements.
        //
        // NotificationCenter Pattern:
        // iOS uses NotificationCenter to broadcast system events. We register
        // observers that execute closure blocks when specific notifications occur.
        //
        // `let _ = ...` Explanation:
        // This executes the code and discards the return value (the observer object).
        // We don't need to keep a reference since the observer is automatically removed
        // when the view disappears.
        
        // Observer 1: Keyboard will show
        let _ = NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillShowNotification,  // Notification name
            object: nil,                                         // No specific object filter
            queue: .main                                         // Execute on main thread (UI updates)
        ) { notification in
            // Extract keyboard frame from notification's userInfo dictionary
            if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                keyboardHeight = keyboardFrame.height  // Store keyboard height
                keyboardVisible = true                 // Mark keyboard as visible
            }
        }
        
        // Observer 2: Keyboard will hide
        let _ = NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillHideNotification,  // Notification name
            object: nil,                                        // No specific object filter
            queue: .main                                        // Execute on main thread
        ) { _ in
            keyboardHeight = 0        // Reset keyboard height
            keyboardVisible = false   // Mark keyboard as hidden
        }
        
        // MARK: Main Layout Stack
        // ZStack layers views on the Z-axis (front to back).
        // Order matters: later views appear on top of earlier ones.
        ZStack {
            // Bottom layer: Main content area
            VStack(spacing: 0) {
                // MARK: Web Content Area
                // This section displays the actual web content or placeholder states.
                // Three possible states:
                // 1. Normal: Tabs exist and are initialized → show web content
                // 2. Loading: Tabs are being restored → show loading spinner
                // 3. Empty: No tabs exist → show empty state
                
                // State 1: Normal - Display web content
                if !tabManager.tabs.isEmpty && tabManager.isInitialized {
                    // TabViewContainer wraps WKWebView and handles web rendering
                    TabViewContainer(
                        tabManager: tabManager,             // Manager for tab state
                        urlString: $urlString,              // $ creates a Binding (two-way)
                        shouldNavigate: $shouldNavigate,    // Trigger for navigation
                        urlBarVisible: $urlBarVisible,      // Controls URL bar auto-hide
                        onNavigate: { url in
                            // Closure called when navigation occurs
                            // Updates the URL bar to show the new URL
                            urlString = url.absoluteString
                        },
                        autoHideEnabled: settings.autoHideURLBar  // User preference
                    )
                    // ignoresSafeArea: Extends content into system areas (notch, home indicator)
                    .ignoresSafeArea(edges: .horizontal)  // Extend to screen edges horizontally
                    .ignoresSafeArea(edges: urlBarVisible ? [] : .bottom)  // Extend to bottom only when URL bar is hidden
                    
                // State 2: Loading - Show restoration progress
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
                            urlBarVisible: $urlBarVisible,
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
                        let startY = value.startLocation.y
                        let screenHeight = UIScreen.main.bounds.height
                        let verticalTranslation = value.translation.height
                        
                        // Check if gesture started in bottom 20% of screen
                        if startY > screenHeight * 0.8 {
                            // Swipe up: either show bar or toggle tab drawer
                            if verticalTranslation < -50 {
                                // Short swipe up: show bottom bar if hidden
                                if settings.autoHideURLBar && !urlBarVisible {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        urlBarVisible = true
                                    }
                                }
                            } else if verticalTranslation < -100 {
                                // Long swipe up: toggle tab drawer
                                withAnimation(.spring()) {
                                    tabManager.toggleTabDrawer()
                                }
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
                .highPriorityGesture(
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
            checkForPendingSharedURL()
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
    // These private methods provide reusable functionality for ContentView.
    
    /// Opens the iOS Settings app to EvoArc's settings page.
    ///
    /// **Use case**: Called when the user taps "Open Settings" in the default browser prompt.
    ///
    /// **UIApplication Explanation**: A singleton object (`UIApplication.shared`) that
    /// represents the app itself and provides system-level functionality.
    ///
    /// **openSettingsURLString**: A special URL scheme (app-settings:) that opens Settings.
    ///
    /// **Optional Chaining**: The `if let` safely unwraps the optional URL, and the
    /// `canOpenURL` check ensures the URL is valid before attempting to open it.
    private func openAppSettings() {
        // Create a URL for the Settings app
        if let url = URL(string: UIApplication.openSettingsURLString),
           UIApplication.shared.canOpenURL(url) {  // Verify the URL can be opened
            UIApplication.shared.open(url)  // Open Settings
        }
    }
    
    /// Initializes the URL bar text based on the currently selected tab.
    ///
    /// **Purpose**: Called when ContentView appears and when the selected tab changes.
    /// Updates the `urlString` state to reflect the current tab's URL.
    ///
    /// **Design Note**: Some tabs (like new tab pages) don't show their URL in the bar.
    /// The `showURLInBar` property controls this behavior.
    ///
    /// **Optional Chaining**: Uses `selectedTab?.url?.absoluteString` to safely
    /// navigate through potentially nil values. The `??` operator provides a default ("").
    private func setupInitialURL() {
        if let selectedTab = tabManager.selectedTab {
            // Only show URL if the tab wants to display it (not all tabs do)
            if selectedTab.showURLInBar {
                // Convert the URL to a string, or use empty string if URL is nil
                urlString = selectedTab.url?.absoluteString ?? ""
            } else {
                // Hide the URL for this tab (e.g., new tab page)
                urlString = ""
            }
        }
    }
    
    /// Handles URLs opened externally (from other apps or Safari).
    ///
    /// **Use case**: When another app opens a link in EvoArc, or when the user
    /// shares a URL to EvoArc, this function is called.
    ///
    /// **Feature**: If "Redirect External Searches" is enabled in settings, EvoArc
    /// intercepts search engine URLs and redirects them to the user's preferred
    /// search engine. For example, Google searches can be redirected to DuckDuckGo.
    ///
    /// **Guard Statement**: An early exit pattern. If the condition is false,
    /// execute the code and return early. This avoids deep nesting.
    ///
    /// **Parameter**:
    /// - url: The incoming URL from another app
    private func handleIncomingURL(_ url: URL) {
        print("[ContentView] handleIncomingURL called with: \(url.absoluteString)")
        
        // Check if this is from share extension
        if url.scheme == "evoarc" {
            print("[ContentView] Detected evoarc:// scheme, delegating to EvoArcApp handler")
            // Don't handle custom schemes here - let EvoArcApp handle them
            return
        }
        
        // Check if redirect feature is disabled
        guard settings.redirectExternalSearches else {
            // Redirect is off: just open the URL as-is in a new tab
            print("[ContentView] Opening URL directly (no redirect): \(url.absoluteString)")
            tabManager.createNewTab(url: url)
            return  // Exit early
        }
        
        // Redirect is on: try to extract a search query
        if let query = extractSearchQuery(from: url),  // Extract query from URL
           let target = BrowserSettings.shared.searchURL(for: query) {  // Build new search URL
            // Successfully extracted query and built target URL
            print("[ContentView] Redirecting search query: \(query)")
            tabManager.createNewTab(url: target)  // Open redirected search
        } else {
            // Couldn't extract a query (not a search URL) - open original URL
            print("[ContentView] Opening URL (not a search): \(url.absoluteString)")
            tabManager.createNewTab(url: url)
        }
    }
    
    /// Checks App Group UserDefaults for pending shared URL from share extension
    private func checkForPendingSharedURL() {
        let appGroupID = "group.com.ConnorNeedling.EvoArcBrowser"
        guard let sharedDefaults = UserDefaults(suiteName: appGroupID) else {
            return
        }
        
        guard let urlString = sharedDefaults.string(forKey: "pendingSharedURL"),
              let url = URL(string: urlString) else {
            return
        }
        
        // Check timestamp to ensure URL is recent (within last 10 seconds)
        let timestamp = sharedDefaults.double(forKey: "pendingSharedURLTimestamp")
        let age = Date().timeIntervalSince1970 - timestamp
        
        if age > 10.0 {
            // Clear the old URL
            sharedDefaults.removeObject(forKey: "pendingSharedURL")
            sharedDefaults.removeObject(forKey: "pendingSharedURLTimestamp")
            return
        }
        
        print("[ContentView] Found pending shared URL: \(urlString)")
        
        // Clear the pending URL
        sharedDefaults.removeObject(forKey: "pendingSharedURL")
        sharedDefaults.removeObject(forKey: "pendingSharedURLTimestamp")
        sharedDefaults.synchronize()
        
        // Open the URL
        tabManager.createNewTab(url: url)
    }
    
    // MARK: - URL Parsing (Search Query Extraction)
    // This section contains logic to extract search queries from various search engines.
    // It's used for the "redirect external searches" feature.
    
    /// Extracts a search query from a search engine URL.
    ///
    /// **Purpose**: When EvoArc receives a search URL from another app (e.g., a Google
    /// search), this function extracts the query text so it can be redirected to
    /// the user's preferred search engine.
    ///
    /// **Supported Search Engines**: Google, DuckDuckGo, Bing, Yahoo, Qwant, Startpage,
    /// Presearch, Ecosia, Perplexity, Yandex.
    ///
    /// **URL Structure**: Search engine URLs typically have a query parameter:
    /// - Google: `https://google.com/search?q=swift+programming`
    /// - DuckDuckGo: `https://duckduckgo.com/?q=swift+programming`
    /// The parameter name varies by engine (usually `q`, but sometimes `p` or `text`).
    ///
    /// **Returns**: The extracted query string, or `nil` if the URL isn't a recognized
    /// search engine or doesn't contain a query.
    ///
    /// **Parameter**:
    /// - url: The URL to parse
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
        .frame(width: 64, height: 64) // Larger hit area for easier touch
        .contentShape(Rectangle()) // Define the entire frame as tappable
        .onTapGesture {
            withAnimation(.easeInOut) {
                uiViewModel.isSidebarFloating = false // Manual toggle uses docked mode
                uiViewModel.showSidebar = true
            }
        }
        .zIndex(100) // Ensure button is above hover detection areas
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
    ContentView(tabManager: TabManager())
}

// MARK: - Architecture Summary for Beginners
// ============================================
//
// ContentView is the HEART of the EvoArc browser app. Here's how it all fits together:
//
// 1. STATE MANAGEMENT HIERARCHY:
//    ┌─────────────────────────────────────────┐
//    │         ContentView (Root)              │  ← You are here
//    │  - Owns TabManager, Settings, etc.      │
//    │  - Coordinates all child views          │
//    └─────────────────────────────────────────┘
//              │
//              ├─ iPhone Layout               iPad/Mac Layout ─┐
//              │                                                 │
//    ┌─────────▼────────────┐               ┌─────────────────▼────────┐
//    │  BottomBarView       │               │  SidebarView             │
//    │  TabViewContainer    │               │  CommandBarView          │
//    │  TabDrawerView       │               │  WebContentPanel         │
//    └──────────────────────┘               └──────────────────────────┘
//
// 2. PROPERTY WRAPPER DECISION TREE:
//    When should you use each wrapper?
//
//    @State
//    ├─ Use for: Simple, local view state (Bool, String, Int, etc.)
//    ├─ Lifetime: Exists only while view is alive
//    ├─ Example: urlBarVisible, showingSettings
//    └─ Rule: Always private, owned by this view
//
//    @StateObject
//    ├─ Use for: Objects (classes) this view creates and owns
//    ├─ Lifetime: Managed by this view, persists across view updates
//    ├─ Example: tabManager, uiViewModel
//    └─ Rule: View creates the object (using initializer)
//
//    @ObservedObject (not used in ContentView, but related)
//    ├─ Use for: Objects passed in from parent or elsewhere
//    ├─ Lifetime: Managed by someone else
//    └─ Example: Would be used if TabManager was created elsewhere
//
//    @AppStorage
//    ├─ Use for: User preferences that persist between launches
//    ├─ Lifetime: Permanent (stored in UserDefaults)
//    ├─ Example: hasShownDefaultBrowserPrompt
//    └─ Rule: Automatically saves to disk
//
//    @Environment
//    ├─ Use for: System-provided values (color scheme, size classes, etc.)
//    ├─ Lifetime: Managed by system
//    ├─ Example: colorScheme, dynamicTypeSize
//    └─ Rule: Read-only in most cases
//
// 3. KEY SWIFTUI CONCEPTS DEMONSTRATED:
//
//    Bindings ($):
//    - The $ prefix creates a two-way binding to a state variable
//    - Example: $urlString allows child views to read AND write urlString
//    - Without $: Child can only read (one-way)
//    - With $: Child can read and write (two-way)
//
//    @ViewBuilder:
//    - Allows functions to return different view types
//    - Enables SwiftUI's declarative syntax (if/else) in function bodies
//    - Used extensively in iphoneLayout() and arcLikeLayout()
//
//    GeometryReader:
//    - Provides size and position information to child views
//    - ContentView uses it to detect screen size for responsive layouts
//    - Pattern: GeometryReader { geometry in ... }
//
//    ZStack, VStack, HStack:
//    - ZStack: Layers views front-to-back (Z-axis)
//    - VStack: Stacks views vertically (top to bottom)
//    - HStack: Stacks views horizontally (left to right)
//
//    View Modifiers:
//    - .onAppear { }: Executes when view appears
//    - .onChange(of:) { }: Executes when value changes
//    - .sheet(isPresented:) { }: Presents modal sheets
//    - .gesture() { }: Adds gesture recognizers
//    - .transition() { }: Animates view appearance/disappearance
//
// 4. ADAPTIVE LAYOUT STRATEGY:
//
//    Device Detection:
//    ```
//    if UIDevice.current.userInterfaceIdiom == .phone {
//        iphoneLayout()  // Bottom bar, compact UI
//    } else {
//        arcLikeLayout() // Sidebar, spacious UI
//    }
//    ```
//
//    Why separate layouts?
//    - iPhone: Limited screen space → bottom URL bar, vertical focus
//    - iPad: Ample space → sidebar navigation, Arc-like command bar
//    - Different interaction paradigms: touch vs cursor/keyboard
//
// 5. DATA FLOW (How information moves through ContentView):
//
//    User Action → State Change → UI Update
//    ─────────────────────────────────────────
//    Example: User taps a tab in the drawer
//
//    1. User taps → TabDrawerView calls tabManager.selectTab()
//    2. TabManager updates @Published var selectedTab
//    3. ContentView observes change (via @StateObject)
//    4. SwiftUI re-renders ContentView.body
//    5. setupInitialURL() updates urlString
//    6. URL bar displays new URL
//
//    This is called "unidirectional data flow" - data flows one direction:
//    Action → State → View
//
// 6. COMMON PITFALLS & TIPS FOR BEGINNERS:
//
//    ❌ Don't: Create @StateObject in a subview for an object created elsewhere
//    ✅ Do: Use @StateObject in the view that creates the object
//
//    ❌ Don't: Mutate @State variables from outside the view
//    ✅ Do: Pass Bindings ($variable) to allow child views to mutate
//
//    ❌ Don't: Perform heavy work directly in body
//    ✅ Do: Use .onAppear, .task, or .onChange to trigger async work
//
//    ❌ Don't: Create new Timer/NotificationCenter observers in body
//    ✅ Do: Set them up in .onAppear or in an initializer
//
// 7. FILE ORGANIZATION PATTERN:
//    - Property declarations at top (state, observed objects)
//    - Main body property (entry point)
//    - Layout functions (iphoneLayout, arcLikeLayout)
//    - Helper functions (setup, URL handling)
//    - Computed view properties (buttons, overlays)
//
// 8. RELATED FILES TO STUDY NEXT:
//    - TabManager.swift: How tabs are managed and persisted
//    - BrowserSettings.swift: User preferences and storage
//    - BottomBarView.swift: iPhone URL bar implementation
//    - SidebarView.swift: iPad sidebar implementation
//    - TabViewContainer.swift: Web view wrapper and scroll handling
//
// 9. DEBUGGING TIPS:
//    - Use print() statements to trace state changes
//    - SwiftUI's Live Preview for rapid iteration
//    - Xcode's View Hierarchy debugger to inspect layout
//    - Look for @Published properties in manager classes (TabManager, etc.)
//
// This file demonstrates real-world SwiftUI architecture in a production app.
// Study the patterns here to understand how large SwiftUI apps are structured!

