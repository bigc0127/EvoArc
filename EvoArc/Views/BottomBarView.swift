//
//  BottomBarView.swift
//  EvoArc
//
//  The main bottom toolbar for the iPhone browser layout.
//  This is the PRIMARY UI COMPONENT for iPhone users - it contains the URL bar,
//  navigation buttons, tab indicator, and browser controls.
//
//  Key responsibilities:
//  1. Display and manage the URL bar (with focus states, editing, suggestions)
//  2. Provide navigation controls (back, forward, refresh)
//  3. Show tab count indicator and access to tab drawer
//  4. Handle browser actions (bookmarks, share, settings, downloads)
//  5. Support gesture navigation (swipe for history, vertical for tab drawer)
//  6. Manage keyboard interactions and layout adjustments
//
//  Design Philosophy:
//  - Compact, single-hand-friendly design for iPhone
//  - Dynamic sizing based on user's text size preferences (Dynamic Type)
//  - Smooth animations for state transitions
//  - Keyboard-aware layout (lifts above keyboard when focused)
//

import SwiftUI  // Apple's declarative UI framework
import WebKit   // Web rendering - provides WKWebView

/// The bottom toolbar view for iPhone browser layout.
///
/// **Architecture**: BottomBarView is a complex SwiftUI view that manages multiple
/// states and interactions. It uses a two-row layout:
/// - **Top row**: Navigation buttons, tab indicator, browser controls
/// - **Bottom row**: Security indicator, URL field, action buttons
///
/// **State Management**: Uses a mix of @Binding (from parent), @ObservedObject
/// (shared managers), and @State (local state) to coordinate behavior.
///
/// **Gestures**: Supports multiple simultaneous gestures:
/// - Horizontal swipe: Navigate back/forward in history
/// - Vertical swipe: Open tab drawer
/// - Tap: Various button actions
///
/// **Keyboard Handling**: Automatically adjusts layout when keyboard appears,
/// lifting the bar to remain visible above the keyboard.
struct BottomBarView: View {
    // MARK: - Properties
    // BottomBarView uses multiple property wrappers to manage state and observe changes.
    // Understanding which wrapper to use is key to building SwiftUI views.
    
    /// Tracks the current swipe gesture direction for visual feedback.
    ///
    /// **@State**: Used because this is local state owned by BottomBarView.
    /// It's not shared with other views.
    @State private var swipeDirection: SwipeDirection = .none
    
    /// The possible directions for horizontal swipe gestures.
    ///
    /// **Use case**: When the user swipes left/right on the bottom bar,
    /// we track the direction to navigate back/forward in history.
    enum SwipeDirection {
        case left   // Swipe left: go forward
        case right  // Swipe right: go back
        case none   // No active swipe
    }
    
    // MARK: Bindings (Two-way connections to parent)
    // @Binding creates a two-way connection to state owned by the parent view (ContentView).
    // BottomBarView can READ and WRITE these values, and changes propagate back to ContentView.
    //
    // @Binding vs @State:
    // - @State: This view owns the data
    // - @Binding: Parent owns the data, we can modify it
    
    /// The current URL text displayed in the URL bar.
    ///
    /// **Two-way binding**: BottomBarView can update this (when user types or navigates),
    /// and ContentView sees the change immediately.
    @Binding var urlString: String
    
    /// Whether the URL bar is currently focused (keyboard is visible).
    ///
    /// **Use case**: When true, the bottom bar layout changes:
    /// - Hides navigation/control buttons (more space for URL field)
    /// - Shows search suggestions
    /// - Lifts above keyboard
    @Binding var isURLBarFocused: Bool
    
    /// Whether the settings sheet is being displayed.
    ///
    /// **Sheet presentation**: ContentView uses this to show/hide the settings sheet.
    @Binding var showingSettings: Bool
    
    /// Triggers navigation to the current URL when set to true.
    ///
    /// **Action trigger pattern**: Setting this to true tells ContentView to navigate.
    /// ContentView resets it back to false after handling.
    @Binding var shouldNavigate: Bool
    
    /// Controls the visibility of the URL bar (for auto-hide feature).
    ///
    /// **Use case**: On iPhone with auto-hide enabled, users can manually hide
    /// the bar to maximize screen space for content.
    @Binding var urlBarVisible: Bool
    
    // MARK: Observed Objects (Passed from parent)
    // @ObservedObject is used for objects that are OWNED BY SOMEONE ELSE (usually the parent).
    // When these objects' @Published properties change, this view automatically re-renders.
    //
    // @ObservedObject vs @StateObject:
    // - @ObservedObject: Someone else owns it, we just observe it
    // - @StateObject: We own it and manage its lifecycle
    
    /// The currently selected tab.
    ///
    /// **Owned by**: TabManager (and observed by BottomBarView)
    ///
    /// **What we observe**: URL changes, loading state, estimated progress, etc.
    /// When any @Published property of Tab changes, BottomBarView re-renders.
    ///
    /// **Why ObservedObject?**: The tab is owned by TabManager, not BottomBarView.
    /// The user might switch tabs, so the object reference can change.
    @ObservedObject var selectedTab: Tab
    
    /// The tab manager (manages all tabs).
    ///
    /// **Owned by**: ContentView (passed down to BottomBarView)
    ///
    /// **What we observe**: Tab count, selected tab changes, tab drawer visibility.
    @ObservedObject var tabManager: TabManager
    
    // MARK: State Objects (Owned by this view)
    // @StateObject is used for objects that THIS VIEW creates and owns.
    // SwiftUI manages the lifecycle - the object persists across view updates.
    //
    // Most of these are singletons (shared), except SuggestionManager and KeyboardHeightManager.
    
    /// The app's settings manager (singleton).
    ///
    /// **Why @StateObject?**: Even though it's a singleton, we need SwiftUI to observe
    /// its @Published properties. @StateObject ensures proper observation lifecycle.
    @StateObject private var settings = BrowserSettings.shared
    
    /// The bookmark manager (singleton).
    ///
    /// **Use case**: Check if current URL is bookmarked, add/remove bookmarks.
    @StateObject private var bookmarkManager = BookmarkManager.shared
    
    /// The search preload manager (singleton).
    ///
    /// **Use case**: Preloads search results as user types for faster navigation.
    @StateObject private var searchPreloadManager = SearchPreloadManager.shared
    
    /// The search suggestion manager (created by this view).
    ///
    /// **Not a singleton**: Each BottomBarView gets its own SuggestionManager.
    /// Manages search suggestions displayed below the URL bar.
    @StateObject private var suggestionManager = SuggestionManager()
    
    /// The keyboard height manager (created by this view).
    ///
    /// **Not a singleton**: Observes keyboard show/hide notifications and tracks height.
    /// Used to adjust bottom bar position when keyboard appears.
    @StateObject private var keyboardManager = KeyboardHeightManager()
    
    /// The download manager (singleton).
    ///
    /// **Use case**: Access download status, show downloads sheet.
    @StateObject private var downloadManager = DownloadManager.shared
    
    // MARK: Local State Variables
    // These are simple values that BottomBarView manages internally.
    // They don't need to be shared with other views.
    
    /// The text currently being edited in the URL field.
    ///
    /// **Why separate from urlString?**: `urlString` is the "official" URL (bound to parent).
    /// `urlEditingText` is the temporary editing buffer. This allows users to type without
    /// immediately affecting the parent's state.
    ///
    /// **Pattern**: Edit in local state, commit to binding on submit.
    @State private var urlEditingText: String = ""
    
    /// Timer for debouncing search suggestions.
    ///
    /// **Optional**: Timer? can be nil when no timer is active.
    ///
    /// **Debouncing**: Instead of fetching suggestions on every keystroke,
    /// we wait for a brief pause in typing. This reduces unnecessary network requests.
    @State private var searchTimer: Timer?
    
    /// Whether the downloads sheet is being presented.
    @State private var showingDownloads = false
    
    /// Progress of the current gesture (0.0 to 1.0).
    ///
    /// **Use case**: Track swipe gesture progress for visual feedback.
    @State private var gestureProgress: CGFloat = 0
    
    /// Whether the text field has keyboard focus.
    ///
    /// **@FocusState**: Special SwiftUI property wrapper for managing focus.
    /// Different from @State - specifically for TextField/TextEditor focus.
    ///
    /// **Bidirectional**: Can be read to check focus state, or written to
    /// programmatically focus/unfocus the field.
    @FocusState private var isTextFieldFocused: Bool
    
    // MARK: Environment Values (System-provided)
    // These values come from the SwiftUI environment and reflect system settings.
    
    /// The user's preferred text size (accessibility setting).
    ///
    /// **Dynamic Type**: iOS users can adjust text size system-wide.
    /// BottomBarView respects this for accessibility.
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    /// The current color scheme (light or dark mode).
    ///
    /// **Use case**: Adjust colors and styles based on light/dark mode.
    @Environment(\.colorScheme) private var colorScheme
    
    // MARK: - Layout Constants
    // These constants define the visual design and spacing of the bottom bar.
    // Keeping them as constants (not hardcoded) makes it easy to adjust the design.
    //
    // CGFloat is the type used for all graphics/layout measurements in iOS.
    // It's a floating-point number optimized for the device's graphics system.
    
    /// Spacing between rows in the toolbar.
    ///
    /// **0 = no spacing**: Elements are tightly packed for a compact design.
    private let baseRowSpacing: CGFloat = 0
    
    /// Standard size for icons throughout the bottom bar.
    private let baseIconSize: CGFloat = 14
    
    /// Minimum width for the tab count indicator.
    private let baseTabIndicatorSize: CGFloat = 24
    
    /// Standard size for interactive buttons.
    ///
    /// **32pt**: Large enough for easy tapping (Apple recommends 44x44 minimum
    /// for touch targets, but 32 works in this compact design with padding).
    private let baseButtonSize: CGFloat = 32
    
    /// Height of the URL bar field.
    private let baseURLBarHeight: CGFloat = 48
    
    // MARK: Bottom bar container constants
    
    /// Horizontal padding around the bottom bar (distance from screen edges).
    private let bottomBarHorizontalPadding: CGFloat = 16
    
    /// Vertical padding inside the bottom bar (top and bottom).
    private let bottomBarVerticalPadding: CGFloat = 8
    
    /// Corner radius for the bottom bar's rounded rectangle.
    ///
    /// **24pt**: Creates a pronounced pill shape for modern iOS design.
    private let bottomBarCornerRadius: CGFloat = 24
    
    /// Fixed height for the bottom bar container.
    private let bottomBarHeight: CGFloat = 48
    
    /// Blur radius for the shadow beneath the bottom bar.
    private let bottomBarShadowRadius: CGFloat = 8
    
    /// Opacity of the shadow (0.0 = transparent, 1.0 = solid black).
    private let bottomBarShadowOpacity: Float = 0.1
    
    // MARK: Computed Layout Properties
    // These properties calculate values dynamically based on current state.
    
    /// Calculates the appropriate height for the suggestions list.
    ///
    /// **Dynamic sizing**: Each suggestion is 44pt tall. We multiply by the count
    /// and cap at 220pt to prevent the list from covering too much screen.
    ///
    /// **min() function**: Takes the smaller of two values. Ensures max height of 220.
    ///
    /// **Type casting**: `CGFloat(...)` converts Int to CGFloat for math operations.
    private var suggestionsHeight: CGFloat {
        min(CGFloat(suggestionManager.suggestions.count) * 44, 220)
    }
    
    /// The primary background color, adapting to light/dark mode.
    ///
    /// **systemBackground**: Apple's semantic color that automatically adjusts:
    /// - Light mode: white
    /// - Dark mode: dark gray/black
    ///
    /// **UIColor vs Color**: UIColor is UIKit's color type, Color is SwiftUI's.
    /// We bridge between them with `Color(uiColor:)`.
    private var backgroundColor: Color {
        Color(uiColor: .systemBackground)
    }
    
    /// A secondary background color for contrast against the primary.
    ///
    /// **systemSecondaryBackground**: Slightly different shade than systemBackground
    /// for layering UI elements. Also adapts to light/dark mode.
    private var secondaryBackgroundColor: Color {
        Color(uiColor: .secondarySystemBackground)
    }
    
    // MARK: - Background Material
    // This computed property creates the visual background for the bottom bar.
    // It's reusable and consistent throughout the view.
    
    /// Creates the background shape for the bottom bar with shadow and border.
    ///
    /// **@ViewBuilder**: Allows this property to return a View type.
    /// Without it, we'd need to specify the exact return type (complex here).
    ///
    /// **some View**: An opaque return type - "this returns some kind of View,
    /// but the caller doesn't need to know the exact type." This is SwiftUI's
    /// way of handling the complex nested view types.
    ///
    /// **Layer breakdown**:
    /// 1. Base: RoundedRectangle filled with backgroundColor
    /// 2. Shadow: Drop shadow for depth (below the rectangle)
    /// 3. Overlay: Subtle border stroke on top
    @ViewBuilder
    private var bottomFillBackground: some View {
        RoundedRectangle(cornerRadius: bottomBarCornerRadius)
            .fill(backgroundColor)  // Fill with adaptive background color
            // Drop shadow parameters: color, blur radius, x offset, y offset
            .shadow(color: .black.opacity(0.1), radius: bottomBarShadowRadius, x: 0, y: 4)
            .overlay {
                // Add a subtle border on top for definition
                RoundedRectangle(cornerRadius: bottomBarCornerRadius)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
            }
    }
    
    // MARK: - Main View (Body)
    // This is the entry point for BottomBarView's UI.
    // SwiftUI calls this when the view needs to render or update.
    
    /// The main body of BottomBarView - defines the complete UI structure.
    ///
    /// **Layout Strategy**:
    /// - **GeometryReader**: Provides size information for responsive layout
    /// - **ZStack**: Layers views vertically (background, then content)
    /// - **VStack**: Stacks suggestions and toolbar vertically
    ///
    /// **Keyboard Behavior**: The entire view lifts above the keyboard when
    /// the URL field is focused. This is handled by `.padding(.bottom, ...)`
    /// combined with `keyboardManager.keyboardHeight`.
    ///
    /// **Gestures**: Multiple simultaneous gestures are attached at the end:
    /// - Horizontal swipe: Navigate history
    /// - Vertical swipe: Toggle tab drawer
    /// - Tap: Various element interactions
    var body: some View {
        // GeometryReader gives us access to the view's size and position
        GeometryReader { geometry in
            // ZStack layers views on the Z-axis (front to back)
            // alignment: .bottom means child views align to the bottom
            ZStack(alignment: .bottom) {
                // Invisible background to capture taps and define the interactive area
                Color.clear
                    .ignoresSafeArea()  // Extend beyond safe area for full-screen gestures
                
                // Main content stack (suggestions + toolbar)
                VStack(spacing: baseRowSpacing) {
                    // MARK: Search Suggestions (conditional)
                    // Only show suggestions when:
                    // 1. URL bar is focused (user is typing)
                    // 2. User has typed something
                    // 3. Suggestions are available
                    if isURLBarFocused && !urlEditingText.isEmpty && !suggestionManager.suggestions.isEmpty {
                        suggestionList  // Computed property defined below
                    }
                    
                    // MARK: Main toolbar container
                    // This VStack contains the two-row toolbar design:
                    // 1. Top row: Navigation buttons, tab indicator, browser controls
                    // 2. Bottom row: Security indicator, URL field, action buttons
                VStack(spacing: baseRowSpacing) {
                        // MARK: Top Controls Row
                        // Layout: [Navigation] [Spacer] [Tab Count] [Spacer] [Controls]
                        // Navigation and controls hide when URL bar is focused to save space.
                        HStack {
                            // Left side: Back and forward buttons
                            if !isURLBarFocused {
                                navigationButtons  // Computed property (defined below)
                            }
                            
                            // Push content to edges
                            Spacer()
                            
                            // Center: Tab count indicator (always visible)
                            tabIndicator  // Computed property (defined below)
                            
                            // Push content to edges
                            Spacer()
                            
                            // Right side: Pin, reader mode, menu buttons
                            if !isURLBarFocused {
                                browserControls  // Computed property (defined below)
                            }
                        }
                        .padding(.horizontal, 12)  // Horizontal padding inside toolbar
                        
                        // MARK: Bottom URL Bar Row
                        // Layout: [Lock Icon] [URL TextField] [Bookmark/Clear/Refresh]
                        // This is the primary interaction area for navigation.
                        HStack(spacing: 8) {
                            securityIndicator  // Lock icon or stop button
                            urlField          // Text field for URL/search input
                            urlBarButtons     // Context-sensitive action buttons
                        }
                        .padding(.horizontal, 12)
                        .frame(height: baseURLBarHeight)  // Fixed height for consistency
                    }
                    // Apply styling to the entire toolbar container
                    .padding(.vertical, bottomBarVerticalPadding)
                    .background(bottomFillBackground)  // Rounded rectangle background
                    .padding(.horizontal, bottomBarHorizontalPadding)  // Space from screen edges
                    .padding(.bottom, 8)  // Space above bottom edge
                }
                .padding(.bottom, 8)  // Additional bottom spacing
                
                // MARK: Keyboard Avoidance
                // When URL bar is focused, lift the entire view above the keyboard.
                // The ternary operator checks focus state:
                // - Focused: Add padding equal to keyboard height
                // - Not focused: No extra padding
                .padding(.bottom, isURLBarFocused ? keyboardManager.keyboardHeight : 0)
                .animation(.easeOut(duration: keyboardManager.keyboardAnimationDuration), value: keyboardManager.keyboardHeight)
            }
        }
        // MARK: Gesture Handlers
        // Multiple gestures can be active simultaneously.
        // .simultaneousGesture allows gestures to coexist without conflict.
        .simultaneousGesture(horizontalSwipeGesture)  // Back/forward navigation
        .simultaneousGesture(verticalSwipeGesture)    // Tab drawer toggle
        .gesture(readerModeGesture)                    // Reader mode toggle
        
        // MARK: Animations
        // Different animations for different state changes.
        // Each .animation modifier targets specific value changes.
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: keyboardManager.keyboardHeight)
        .animation(.easeInOut(duration: 0.2), value: selectedTab.isLoading)
        .animation(.easeInOut(duration: 0.2), value: isURLBarFocused)
        .animation(.easeInOut(duration: keyboardManager.keyboardAnimationDuration), value: suggestionManager.suggestions)
        
        // MARK: Safe Area and Lifecycle
        .ignoresSafeArea(.keyboard, edges: .bottom)  // Extend below keyboard
        .onAppear {
            // Initialize editing text when view appears
            urlEditingText = urlString
        }
        .onDisappear {
            // Clean up timer to prevent memory leaks
            searchTimer?.invalidate()
        }
    }
    
    // MARK: - Subviews (UI Components)
    // These computed properties return reusable views that compose the bottom bar.
    // Breaking the UI into smaller pieces improves readability and maintainability.
    
    /// The search suggestions dropdown that appears above the URL bar.
    ///
    /// **Conditional rendering**: This view only appears when the URL bar is focused
    /// and suggestions are available (checked in the main body).
    ///
    /// **ScrollView**: Allows scrolling if there are many suggestions.
    /// `showsIndicators: false` hides the scroll bar for cleaner appearance.
    ///
    /// **SuggestionListView**: A separate view component that displays the list.
    /// Takes suggestions data and callbacks for handling user interaction.
    ///
    /// **Callbacks**: Closures (anonymous functions) passed as parameters:
    /// - `onSuggestionTapped`: Called when user selects a suggestion
    /// - `onDismiss`: Called when user wants to close suggestions
    ///
    /// **Layout modifiers**:
    /// - `.frame(height:)`: Caps the height (dynamic based on suggestion count)
    /// - `.clipped()`: Prevents content from extending beyond bounds
    /// - `.offset(y: -11)`: Moves up slightly to overlap with toolbar
    /// - `.transition`: Defines enter/exit animation
    private var suggestionList: some View {
        ScrollView(.vertical, showsIndicators: false) {
            SuggestionListView(
                suggestions: suggestionManager.suggestions,
                onSuggestionTapped: handleSuggestion,              // Function reference
                onDismiss: { suggestionManager.clearSuggestions() } // Inline closure
            )
            .background(backgroundColor)  // Solid background
            .cornerRadius(12)             // Rounded corners
            .shadow(color: .black.opacity(0.1), radius: 8)  // Drop shadow for depth
        }
        .frame(height: suggestionsHeight)  // Dynamic height based on count
        .clipped()                          // Clip overflow content
        .padding(.horizontal, 12)           // Match toolbar padding
        .offset(y: -11)                     // Slight overlap with toolbar
        .transition(.opacity.combined(with: .move(edge: .bottom)))  // Fade + slide animation
    }
    
    /// The tab count indicator in the center of the top row.
    ///
    /// **Visual design**: A chevron (up arrow) above a number showing tab count.
    /// Tapping this opens the tab drawer.
    ///
    /// **String Interpolation**: `"\(tabManager.tabs.count)"` embeds the tab count
    /// into a string. This is Swift's way of building strings from variables.
    ///
    /// **Dynamic Type Limiting**: `.dynamicTypeSize(...DynamicTypeSize.accessibility3)`
    /// caps the text size. Even if the user has very large text enabled, this indicator
    /// won't grow beyond accessibility3 size (prevents layout breaking).
    ///
    /// **contentShape**: Defines the tappable area. Without this, only the text/icon
    /// pixels would be tappable. With Rectangle(), the entire frame is tappable.
    ///
    /// **withAnimation**: Wraps the state change to animate the drawer appearance.
    private var tabIndicator: some View {
        VStack(spacing: 2) {
            // Chevron icon pointing up
            Image(systemName: "chevron.compact.up")
                .font(.system(size: 12))
                .foregroundColor(.secondary)  // Muted color
            
            // Tab count number
            Text("\(tabManager.tabs.count)")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)
                .dynamicTypeSize(...DynamicTypeSize.accessibility3)  // Cap text size growth
        }
        .frame(minWidth: baseTabIndicatorSize)  // Ensure minimum width for consistent size
        .contentShape(Rectangle())               // Make entire area tappable
        .onTapGesture {
            // Animate the tab drawer toggle
            withAnimation(.spring()) {
                tabManager.toggleTabDrawer()
            }
        }
    }
    
    /// Back and forward navigation buttons for the left side of the toolbar.
    ///
    /// **Disabled State**: Buttons are automatically disabled when navigation
    /// is not possible:
    /// - Back button: Disabled if `canGoBack` is false (no history)
    /// - Forward button: Disabled if `canGoForward` is false (at latest page)
    ///
    /// **Optional Chaining**: `selectedTab.webView?.goBack()` safely calls goBack()
    /// only if webView is not nil. The `?` is Swift's optional chaining operator.
    ///
    /// **PlainButtonStyle**: Removes default button styling for a minimal look.
    ///
    /// **Transition**: When these buttons appear/disappear (URL bar focus toggle),
    /// they fade and scale slightly for smooth animation.
    private var navigationButtons: some View {
        HStack(spacing: 6) {
            // MARK: Back Button
            Button(action: {
                // Optional chaining: safely navigate back if webView exists
                selectedTab.webView?.goBack()
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 32, height: 32)  // Fixed size for consistent tap target
                    .contentShape(Rectangle())      // Full frame is tappable
            }
            .buttonStyle(.plain)                  // Remove default button styling
            .disabled(!selectedTab.canGoBack)     // Disable if can't go back
            
            // MARK: Forward Button
            Button(action: {
                // Optional chaining: safely navigate forward if webView exists
                selectedTab.webView?.goForward()
            }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!selectedTab.canGoForward)  // Disable if can't go forward
        }
        // Transition for smooth enter/exit when URL bar focus changes
        .transition(.opacity.combined(with: .scale(scale: 0.8)))
    }
    
    private var browserControls: some View {
        HStack(spacing: 8) {
            // Hide bar button (only on iPhone with auto-hide enabled)
            #if os(iOS)
            if UIDevice.current.userInterfaceIdiom == .phone && settings.autoHideURLBar {
                Button(action: {
                    // Hide the bottom bar
                    withAnimation(.easeInOut(duration: 0.3)) {
                        urlBarVisible = false
                    }
                }) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 18))
                        .foregroundColor(.primary)
                }
            } else {
                // Pin/Unpin button (iPad or when auto-hide is off)
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
            }
            #else
            // Pin/Unpin button (macOS)
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
            #endif
            
            // Reader mode indicator
            if selectedTab.readerModeEnabled {
                Image(systemName: "textformat.size")
                    .font(.system(size: 16))
                    .foregroundColor(.accentColor)
            }
            
            // Menu button with all actions
            Menu {
                Button(action: { tabManager.createNewTab() }) {
                    Label("New Tab", systemImage: "plus.square")
                }
                
                Button(action: {
                    if let homepage = BrowserSettings.shared.homepageURL {
                        selectedTab.webView?.load(URLRequest(url: homepage))
                    }
                }) {
                    Label("Home", systemImage: "house")
                }
                
                Divider()
                
                Button(action: { settings.useDesktopMode.toggle() }) {
                    Label(
                        settings.useDesktopMode ? "Request Mobile Website" : "Request Desktop Website",
                        systemImage: settings.useDesktopMode ? "iphone" : "desktopcomputer"
                    )
                }
                
                Button(action: {
                    settings.adBlockEnabled.toggle()
                    selectedTab.webView?.reload()
                }) {
                    Label(
                        settings.adBlockEnabled ? "Disable Ad Blocking" : "Enable Ad Blocking",
                        systemImage: settings.adBlockEnabled ? "eye.slash" : "eye"
                    )
                }
                
                if let currentURL = selectedTab.url {
                    Button(action: {
                        JavaScriptBlockingManager.shared.toggleJavaScriptBlocking(for: currentURL)
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
                
                // Share action
                if let url = selectedTab.url {
                    Button(action: { presentShareSheet(for: url) }) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                }
                
                Divider()
                
                // Reader mode toggle
                Button(action: { toggleReaderMode() }) {
                    Label(
                        selectedTab.readerModeEnabled ? "Disable Reader Mode" : "Enable Reader Mode",
                        systemImage: "textformat.size"
                    )
                }
                
                Button(action: { showingSettings = true }) {
                    Label("Settings", systemImage: "gear")
                }
                
                if PerplexityManager.shared.isAuthenticated, let currentURL = selectedTab.url {
                    Divider()
                    Button(action: {
                        PerplexityManager.shared.performAction(.summarize, for: currentURL, title: selectedTab.title)
                    }) {
                        Label("Summarize with Perplexity", systemImage: "doc.text.magnifyingglass")
                    }
                    Button(action: {
                        PerplexityManager.shared.performAction(.sendToPerplexity, for: currentURL, title: selectedTab.title)
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
    
    private var securityIndicator: some View {
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
        .frame(width: 20, height: 20)
    }
    
    private var urlField: some View {
        Group {
            TextField("Search or enter address", text: $urlEditingText)
                .font(.body)
                .textFieldStyle(PlainTextFieldStyle())
                .frame(height: 32)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.leading)
                .focused($isTextFieldFocused)
                .task(id: selectedTab.url) {
                    if !isURLBarFocused {
                        if selectedTab.showURLInBar {
                            urlEditingText = selectedTab.url?.absoluteString ?? ""
                        } else {
                            urlEditingText = ""
                        }
                    }
                }
                .onChange(of: urlEditingText) { _, newValue in
                    handleURLTextChange(newValue)
                }
                .onSubmit {
                    handleURLSubmit()
                }
                .onTapGesture {
                    handleURLTap()
                }
                .onChange(of: isTextFieldFocused) { _, focused in
                    isURLBarFocused = focused
                }
        }
        .modifier(
            // Apply rainbow border only on iPhone when page is loading
            ConditionalRainbowBorder(
                isLoading: UIDevice.current.userInterfaceIdiom == .phone && selectedTab.isLoading
            )
        )
    }
    
    private var urlBarButtons: some View {
        HStack(spacing: 8) {
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
            
            if isURLBarFocused && !urlEditingText.isEmpty {
                Button(action: { urlEditingText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            
            if !isURLBarFocused {
                if selectedTab.isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                } else {
                    Button(action: { selectedTab.webView?.reload() }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12))
                    }
                }
            }
            
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
                        .dynamicTypeSize(...DynamicTypeSize.accessibility3)
                        .foregroundColor(.accentColor)
                }
            }
        }
    }
    
    // MARK: - Gestures
    
    private var horizontalSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 20)
            .onChanged { value in
                if !isURLBarFocused {
                    let horizontalAmount = value.translation.width
                    let verticalAmount = value.translation.height
                    if abs(horizontalAmount) > abs(verticalAmount) * 1.5 {
                        tabManager.isGestureActive = true
                    }
                }
            }
            .onEnded { value in
                defer { tabManager.isGestureActive = false }
                if !isURLBarFocused {
                    let horizontalAmount = value.translation.width
                    let verticalAmount = value.translation.height
                    
                    if abs(horizontalAmount) > abs(verticalAmount) * 1.5 && abs(horizontalAmount) > 50 {
                        if horizontalAmount > 0 {
                            // Swipe right: previous tab or create new tab
                            if let currentIndex = tabManager.tabs.firstIndex(where: { $0.id == selectedTab.id }) {
                                if currentIndex > 0 {
                                    withAnimation {
                                        swipeDirection = .right
                                        tabManager.selectTab(tabManager.tabs[currentIndex - 1])
                                    }
                                } else {
                                    // At first tab, create new one
                                    withAnimation {
                                        swipeDirection = .right
                                        tabManager.createNewTab()
                                    }
                                }
                            }
                        } else {
                            // Swipe left: next tab or create new tab
                            if let currentIndex = tabManager.tabs.firstIndex(where: { $0.id == selectedTab.id }) {
                                if currentIndex < tabManager.tabs.count - 1 {
                                    withAnimation {
                                        swipeDirection = .left
                                        tabManager.selectTab(tabManager.tabs[currentIndex + 1])
                                    }
                                } else {
                                    // At last tab, create new one
                                    withAnimation {
                                        swipeDirection = .left
                                        tabManager.createNewTab()
                                    }
                                }
                            }
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            swipeDirection = .none
                        }
                    }
                }
            }
    }
    
    private var verticalSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 20)
            .onChanged { value in
                if !tabManager.isGestureActive && !isURLBarFocused {
                    let verticalAmount = value.translation.height
                    let horizontalAmount = value.translation.width
                    if abs(verticalAmount) > abs(horizontalAmount) * 1.5 {
                        tabManager.isGestureActive = true
                        gestureProgress = min(1.0, abs(verticalAmount) / 100)
                    }
                } else if tabManager.isGestureActive {
                    gestureProgress = min(1.0, abs(value.translation.height) / 100)
                }
            }
            .onEnded { value in
                defer {
                    tabManager.isGestureActive = false
                    withAnimation(.spring()) {
                        gestureProgress = 0
                    }
                }
                
                if !isURLBarFocused {
                    let verticalAmount = value.translation.height
                    let horizontalAmount = value.translation.width
                    if abs(verticalAmount) > abs(horizontalAmount) * 1.5 && verticalAmount < -50 {
                        withAnimation(.spring()) {
                            tabManager.toggleTabDrawer()
                        }
                    }
                }
            }
    }
    
    private var readerModeGesture: some Gesture {
        SimultaneousGesture(
            DragGesture(minimumDistance: 20),
            DragGesture(minimumDistance: 20)
        )
        .onEnded { value in
            let verticalAmount = value.first?.translation.height ?? 0
            let horizontalAmount = value.first?.translation.width ?? 0
            if verticalAmount > abs(horizontalAmount) * 1.5 && verticalAmount > 50 {
                toggleReaderMode()
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func handleSuggestion(_ item: SuggestionItem) {
        withAnimation(.easeInOut(duration: keyboardManager.keyboardAnimationDuration)) {
            switch item.type {
            case .history, .url:
                if let url = item.url {
                    urlString = url.absoluteString
                } else {
                    urlString = item.text
                }
                shouldNavigate = true
            case .search:
                if let url = BrowserSettings.shared.searchURL(for: item.text) {
                    urlString = url.absoluteString
                    shouldNavigate = true
                } else {
                    urlString = item.text
                    shouldNavigate = true
                }
            }
            isTextFieldFocused = false
        }
    }
    
    private func handleURLTextChange(_ newValue: String) {
        searchTimer?.invalidate()
        suggestionManager.getSuggestions(for: newValue)
        if newValue.count > 2 {
            searchTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
                searchPreloadManager.preloadSearch(for: newValue)
            }
        }
    }
    
    private func handleURLSubmit() {
        urlString = urlEditingText
        shouldNavigate = true
        isTextFieldFocused = false
    }
    
    private func handleURLTap() {
        if !isTextFieldFocused {
            selectedTab.showURLInBar = true
            if let currentURL = selectedTab.webView?.url {
                urlEditingText = currentURL.absoluteString
            }
            isTextFieldFocused = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                UIApplication.shared.sendAction(#selector(UIResponder.selectAll(_:)), to: nil, from: nil, for: nil)
            }
        }
    }
    
    private func toggleReaderMode() {
        selectedTab.readerModeEnabled.toggle()
        if selectedTab.readerModeEnabled {
            selectedTab.webView?.evaluateJavaScript("""
            (function(){
              try {
                if (!document.getElementById('evoarc-reader-style')) {
                  var style = document.createElement('style');
                  style.id = 'evoarc-reader-style';
                  style.textContent = `
                    #evoarc-reader-style { display: none; }
                    .evoarc-reader body { background:#f7f7f7 !important; }
                    .evoarc-reader article, .evoarc-reader main, .evoarc-reader #content, .evoarc-reader .content, .evoarc-reader .post, .evoarc-reader .entry { max-width: 700px; margin: 0 auto; padding: 16px; background: #ffffff !important; color: #111 !important; line-height: 1.6; font-size: 19px; }
                    .evoarc-reader p { line-height: 1.7 !important; }
                    .evoarc-reader img, .evoarc-reader video, .evoarc-reader figure { max-width: 100%; height: auto; }
                    .evoarc-reader nav, .evoarc-reader header, .evoarc-reader footer, .evoarc-reader aside, .evoarc-reader .sidebar, .evoarc-reader .ads, .evoarc-reader [role='banner'], .evoarc-reader [role='navigation'], .evoarc-reader [role='complementary'] { display: none !important; }
                  `;
                  document.head.appendChild(style);
                }
                document.documentElement.classList.add('evoarc-reader');
                return true;
              } catch (e) { return false; }
            })();
            """, completionHandler: nil)
        } else {
            selectedTab.webView?.evaluateJavaScript("""
            (function(){
              try {
                var style = document.getElementById('evoarc-reader-style');
                if (style && style.parentNode) { style.parentNode.removeChild(style); }
                document.documentElement.classList.remove('evoarc-reader');
                return true;
              } catch (e) { return false; }
            })();
            """, completionHandler: nil)
        }
    }
    
    private func presentShareSheet(for url: URL) {
        let items: [Any] = [url]
        let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            if let popoverController = activityVC.popoverPresentationController {
                popoverController.sourceView = rootViewController.view
                popoverController.sourceRect = CGRect(
                    x: UIScreen.main.bounds.width / 2,
                    y: UIScreen.main.bounds.height / 2,
                    width: 0,
                    height: 0
                )
            }
            rootViewController.present(activityVC, animated: true)
        }
    }
}

// MARK: - Rainbow Border Modifier for Loading Animation

/// A conditional wrapper that only applies the rainbow border when loading is true.
/// This prevents unnecessary animation overhead when not loading.
struct ConditionalRainbowBorder: ViewModifier {
    let isLoading: Bool
    
    func body(content: Content) -> some View {
        if isLoading {
            content.modifier(RainbowBorderModifier())
        } else {
            content
        }
    }
}

/// A SwiftUI ViewModifier that adds an animated rainbow border around a view.
/// Inspired by ChatGPT's subtle pastel gradient loading effect.
/// Only applied on iPhone during page loading.
struct RainbowBorderModifier: ViewModifier {
    /// Controls the animation state
    @State private var rotation: Double = 0
    
    /// Medium saturation rainbow gradient colors with smooth transitions
    /// Balanced between soft pastels and vivid colors for a pleasant loading effect
    private let rainbowColors: [Color] = [
        Color(red: 0.78, green: 0.65, blue: 0.98),  // Soft lavender
        Color(red: 0.60, green: 0.75, blue: 1.00),  // Soft sky blue
        Color(red: 0.50, green: 0.88, blue: 0.93),  // Soft cyan
        Color(red: 0.50, green: 0.94, blue: 0.70),  // Soft mint
        Color(red: 1.00, green: 0.94, blue: 0.50),  // Soft yellow
        Color(red: 1.00, green: 0.78, blue: 0.55),  // Soft peach
        Color(red: 1.00, green: 0.60, blue: 0.70),  // Soft pink
        Color(red: 0.94, green: 0.55, blue: 0.70),  // Soft rose
        Color(red: 0.78, green: 0.65, blue: 0.98)   // Back to lavender for smooth loop
    ]
    
    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        AngularGradient(
                            colors: rainbowColors,
                            center: .center,
                            angle: .degrees(rotation)
                        ),
                        lineWidth: 2
                    )
            )
            .onAppear {
                // Start continuous rotation animation - 3 seconds per full rotation
                withAnimation(
                    .linear(duration: 3.0)
                    .repeatForever(autoreverses: false)
                ) {
                    rotation = 360
                }
            }
    }
}
