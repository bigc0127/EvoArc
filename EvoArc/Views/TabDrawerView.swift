//
//  TabDrawerView.swift
//  EvoArc
//
//  Created on 2025-09-04.
//
//  The tab drawer/switcher UI that slides up from the bottom on iPhone.
//  Displays all open tabs in a grid layout with sections for:
//  - Pinned tabs (always at top)
//  - Tab groups (organized collections)
//  - Ungrouped tabs (remaining tabs)
//
//  Key responsibilities:
//  1. Display tabs in a scrollable 2-column grid
//  2. Show tab count, group count, and controls in header
//  3. Support tab selection, closing, and creation
//  4. Present sheets for creating groups, viewing bookmarks/history
//  5. Handle pinned tabs with confirmation dialogs
//  6. Provide smooth animations for tab transitions
//
//  Design Philosophy:
//  - Card-based UI with glassmorphism effects (iOS 26+)
//  - Dynamic Type support for accessibility
//  - Organized sections with clear visual hierarchy
//  - Smooth animations using matchedGeometryEffect
//

import SwiftUI  // Apple's declarative UI framework
import UIKit    // iOS UI framework for platform detection

// MARK: - View Modifiers

/// A custom view modifier that applies rounded corners to the top of a view.
///
/// **ViewModifier Protocol**: Allows creating reusable view transformations.
/// Instead of repeating `.cornerRadius(...)` everywhere, we encapsulate it here.
///
/// **Use case**: TabDrawerView slides up from bottom and needs rounded top corners
/// for a modern, card-like appearance.
///
/// **Platform-specific**: While named "Platform", this currently applies the same
/// style everywhere. The name suggests future platform-specific variants.
struct PlatformCornerRadius: ViewModifier {
    func body(content: Content) -> some View {
        // Apply corner radius only to top corners
        content.cornerRadius(20, corners: [.topLeft, .topRight])
    }
}

// MARK: - TabDrawerView Main Struct

/// The main tab drawer/switcher view that slides up from the bottom.
///
/// **Architecture**: TabDrawerView is a presentation layer - it doesn't manage tabs
/// itself, but displays them using data from TabManager. All tab operations
/// (create, close, select) are delegated to TabManager.
///
/// **Layout Structure**:
/// ```
/// ┌─────────────────────────────────┐
/// │  Drawer Handle (drag indicator) │
/// ├─────────────────────────────────┤
/// │  Header: Count + Action Buttons │
/// ├─────────────────────────────────┤
/// │  ┌───────────────────────────┐  │
/// │  │   Pinned Tabs (2-col)     │  │
/// │  ├───────────────────────────┤  │
/// │  │   Tab Groups (sectioned)  │  │
/// │  ├───────────────────────────┤  │
/// │  │   Other Tabs (2-col)      │  │
/// │  └───────────────────────────┘  │
/// │  ScrollView                     │
/// └─────────────────────────────────┘
/// ```
///
/// **Animations**: Uses @Namespace for hero animations - when a tab card
/// is tapped, it smoothly animates into the main view.
///
/// **Sheets**: Can present multiple modal sheets:
/// - Create tab group
/// - Bookmarks
/// - History
struct TabDrawerView: View {
    
    // MARK: - Properties
    
    /// The tab manager (passed from parent, observed for changes).
    ///
    /// **@ObservedObject**: We observe TabManager but don't own it.
    /// ContentView owns it and passes it down.
    @ObservedObject var tabManager: TabManager
    
    /// Browser settings singleton for preferences.
    @StateObject private var settings = BrowserSettings.shared
    
    /// Bookmark manager for checking bookmark status.
    @StateObject private var bookmarkManager = BookmarkManager.shared
    
    /// A namespace for coordinating animations between views.
    ///
    /// **@Namespace**: Creates a unique identifier for `matchedGeometryEffect`.
    /// When a tab card in the drawer matches a view in the main UI, SwiftUI
    /// animates smoothly between them.
    ///
    /// **How it works**: Each tab card gets `.matchedGeometryEffect(id: tab.id, in: animationNamespace)`.
    /// When the tab is selected, SwiftUI finds the matching ID and animates the transition.
    @Namespace private var animationNamespace
    
    /// The current color scheme (light or dark mode).
    @Environment(\.colorScheme) private var colorScheme
    
    /// The user's preferred text size.
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    // MARK: Sheet presentation state
    
    /// Whether the "Create Tab Group" sheet is shown.
    @State private var showingCreateGroupSheet = false
    
    /// The name for a new tab group (edited in the sheet).
    @State private var newGroupName = ""
    
    /// The color for a new tab group.
    @State private var newGroupColor: TabGroupColor = .blue
    
    /// Whether the bookmarks sheet is shown.
    @State private var showingBookmarks = false
    
    /// Whether the history sheet is shown.
    @State private var showingHistory = false
    
    // MARK: Layout Constants
    // These constants define the drawer's visual design.
    // They're called "base" because they're scaled by PlatformMetrics for Dynamic Type.
    
    /// Height of the drag handle at the top of the drawer.
    private let baseHandleHeight: CGFloat = 5
    
    /// Width of the drag handle.
    private let baseHandleWidth: CGFloat = 40
    
    /// Standard icon size for header buttons.
    private let baseIconSize: CGFloat = 18
    
    /// Spacing between elements.
    private let baseSpacing: CGFloat = 15
    
    /// Corner radius for the drawer's top corners.
    private let baseCornerRadius: CGFloat = 20
    
    /// Opacity for the glassmorphism background effect (iOS 26+).
    private let glassOpacity: CGFloat = 0.7
    
    // MARK: Computed Colors
    
    /// The primary background color for the drawer.
    ///
    /// **Custom color**: `.appBackground` is defined in the app's theme.
    /// It adapts to light/dark mode automatically.
    private var systemBackgroundColor: Color {
        .appBackground
    }
    
    /// Secondary background color for cards.
    ///
    /// **Use case**: Tab cards use this for contrast against the main background.
    private var secondarySystemBackgroundColor: Color {
        .cardBackground
    }
    
    // MARK: - Main View Body
    
    /// The main body of the tab drawer.
    ///
    /// **Layout**: GeometryReader provides size information, then a VStack layers:
    /// 1. Drawer handle (drag indicator)
    /// 2. Header section (counts + buttons)
    /// 3. Tabs grid (scrollable content)
    ///
    /// **Safe area handling**: The drawer extends into the bottom safe area
    /// (home indicator area on modern iPhones) for an edge-to-edge appearance.
    ///
    /// **Background**: On iOS 26+, uses glassmorphism. On earlier versions,
    /// uses solid color.
    var body: some View {
        // GeometryReader provides screen dimensions
        GeometryReader { geometry in
            // Main content stack
            VStack(spacing: 0) {
                drawerHandle    // Top drag indicator
                headerSection   // Counts and action buttons
                tabsGrid        // Scrollable tab grid
            }
            // Extend height to include safe area (home indicator area)
            .frame(height: geometry.size.height + geometry.safeAreaInsets.bottom)
            .ignoresSafeArea(.container, edges: .bottom)  // Draw under home indicator
            .background(drawerBackground)                  // Glassmorphism or solid color
            .modifier(PlatformCornerRadius())              // Rounded top corners
            .themeShadow()                                 // Drop shadow for depth
        }
        // MARK: Modal Sheets
        // These sheets slide up to present different interfaces.
        // They're presented based on @State bindings that act as flags.
        
        // Sheet 1: Create Tab Group
        .sheet(isPresented: $showingCreateGroupSheet) {
            NewTabGroupView(
                name: $newGroupName,                // Binding to text field
                color: $newGroupColor,              // Binding to color picker
                onCancel: {
                    // User tapped Cancel: dismiss and reset
                    showingCreateGroupSheet = false
                    newGroupName = ""
                    newGroupColor = .blue
                },
                onCreate: {
                    // User tapped Create: validate and create group
                    let trimmed = newGroupName.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        _ = tabManager.createTabGroup(name: trimmed, color: newGroupColor)
                    }
                    // Dismiss sheet and reset state
                    showingCreateGroupSheet = false
                    newGroupName = ""
                    newGroupColor = .blue
                }
            )
        }
        // Sheet 2: Bookmarks
        .sheet(isPresented: $showingBookmarks) {
            BookmarksView(tabManager: tabManager)
        }
        // Sheet 3: History
        .sheet(isPresented: $showingHistory) {
            HistoryView(tabManager: tabManager)
        }
        // MARK: Confirmation Dialog
        // iOS-style alert for confirming destructive actions.
        // Shows when user attempts to unpin a tab (if confirmClosingPinnedTabs setting is on).
        .confirmationDialog(
            "Unpin Tab",                                    // Dialog title
            isPresented: $tabManager.showUnpinConfirmation, // Controlled by TabManager
            titleVisibility: .visible                       // Show title
        ) {
            // Destructive action (red text)
            Button("Unpin", role: .destructive) {
                tabManager.confirmUnpinTab()  // User confirmed: unpin the tab
            }
            // Cancel action
            Button("Cancel", role: .cancel) {
                tabManager.cancelUnpinTab()   // User cancelled: abort unpin
            }
        } message: {
            // Explanation text shown below title
            Text("Are you sure you want to unpin this tab? It will remain open but no longer be pinned.")
        }
    }
    
    // MARK: - Subviews (UI Components)
    
    /// The drag handle at the top of the drawer.
    ///
    /// **Visual indicator**: A small horizontal bar that indicates the drawer
    /// can be dragged. Common iOS pattern for bottom sheets.
    ///
    /// **PlatformMetrics**: A utility that scales dimensions based on Dynamic Type.
    /// As the user increases text size, UI elements scale proportionally.
    ///
    /// **@ViewBuilder**: Allows this property to return a View.
    @ViewBuilder
    private var drawerHandle: some View {
        RoundedRectangle(cornerRadius: PlatformMetrics.scaledPadding(2.5))
            .fill(Color.secondaryLabel)  // System color (adapts to light/dark)
            .scaledFrame(width: baseHandleWidth, height: baseHandleHeight)  // Scaled for accessibility
            .scaledPadding(.top, 8)
            .scaledPadding(.bottom, 12)
    }
    
    /// The header section showing counts and action buttons.
    ///
    /// **Layout**: [Tab Count] • [Group Count] [Spacer] [History] [Bookmarks] [New Group] [New Tab]
    ///
    /// **Dynamic Text**: Tab/Tabs and Group/Groups use pluralization logic.
    /// Swift's ternary operator handles this: `count == 1 ? "singular" : "plural"`
    ///
    /// **Dynamic Type Capping**: Text sizes are capped at accessibility3 to prevent
    /// the header from becoming too large and breaking the layout.
    @ViewBuilder
    private var headerSection: some View {
        HStack {
            // Tab count with pluralization
            Text("\(tabManager.tabs.count) \(tabManager.tabs.count == 1 ? "Tab" : "Tabs")")
                .font(.headline)
                .foregroundColor(.primaryLabel)
                .dynamicTypeSize(...DynamicTypeSize.accessibility3)  // Cap maximum size
            
            if !tabManager.tabGroups.isEmpty {
                Text("• \(tabManager.tabGroups.count) \(tabManager.tabGroups.count == 1 ? "Group" : "Groups")")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .dynamicTypeSize(...DynamicTypeSize.accessibility3)
            }
            
            Spacer()
            
            Button(action: {
                showingHistory = true
            }) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: PlatformMetrics.iconSize(16)))
                    .foregroundColor(.accentColor)
                    .frame(width: PlatformMetrics.buttonSize(baseSize: 44, hasLabel: false), height: PlatformMetrics.buttonSize(baseSize: 44, hasLabel: false))
                    .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            
            Button(action: {
                showingBookmarks = true
            }) {
                Image(systemName: "bookmark.fill")
                    .font(.system(size: PlatformMetrics.iconSize(16)))
                    .foregroundColor(.accentColor)
                    .frame(width: PlatformMetrics.buttonSize(baseSize: 44, hasLabel: false), height: PlatformMetrics.buttonSize(baseSize: 44, hasLabel: false))
                    .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            
            Button(action: {
                showingCreateGroupSheet = true
            }) {
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: PlatformMetrics.iconSize(18)))
                    .foregroundColor(.accentColor)
                    .frame(width: PlatformMetrics.buttonSize(baseSize: 44, hasLabel: false), height: PlatformMetrics.buttonSize(baseSize: 44, hasLabel: false))
                    .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            
            Button(action: {
                tabManager.createNewTab()
            }) {
                Image(systemName: "plus")
                    .font(.system(size: PlatformMetrics.iconSize(20)))
                    .foregroundColor(.accentColor)
                    .frame(width: PlatformMetrics.buttonSize(baseSize: 44, hasLabel: false), height: PlatformMetrics.buttonSize(baseSize: 44, hasLabel: false))
                    .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
        }
        .scaledPadding(.horizontal, 20)
        .scaledPadding(.bottom, 10)
    }
    
    /// The main scrollable grid of tabs.
    ///
    /// **LazyVStack + LazyVGrid**: "Lazy" means views are only created when visible.
    /// With many tabs, this saves memory and improves performance.
    ///
    /// **Section organization**:
    /// 1. Pinned tabs (always at top, if any exist)
    /// 2. Tab groups (each group is a section, if groups exist)
    /// 3. Ungrouped tabs ("Other Tabs", if any exist)
    ///
    /// **Filtering**: Uses `.filter { !$0.isPinned }` to exclude pinned tabs
    /// from groups and ungrouped sections (they're shown in their own section).
    @ViewBuilder
    private var tabsGrid: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: PlatformMetrics.scaledPadding(20)) {
                // Pinned tabs section
                let pinnedTabs = tabManager.tabs.filter { $0.isPinned }
                if !pinnedTabs.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.accentColor)
                            Text("Pinned")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        .padding(.horizontal, 15)
                        
                        LazyVGrid(columns: gridColumns, spacing: 15) {
                            ForEach(pinnedTabs) { tab in
                                tabCardView(for: tab)
                            }
                        }
                        .padding(.horizontal, 15)
                    }
                }
                
                // Tab groups sections
                ForEach(tabManager.tabGroups) { group in
                    let groupTabs = tabManager.getTabsInGroup(group).filter { !$0.isPinned }
                    if !settings.hideEmptyTabGroups || !groupTabs.isEmpty {
                        TabGroupSectionView(
                            group: group,
                            tabs: groupTabs,
                            tabManager: tabManager,
                            gridColumns: gridColumns
                        ) { tab in
                            tabCardView(for: tab)
                        }
                    }
                }
                
                // Ungrouped tabs section
                let ungroupedTabs = tabManager.getUngroupedTabs().filter { !$0.isPinned }
                if !ungroupedTabs.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        if (!pinnedTabs.isEmpty || !tabManager.tabGroups.isEmpty) {
                            HStack {
                                Text("Other Tabs")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                            .padding(.horizontal, 15)
                        }
                        
                        LazyVGrid(columns: gridColumns, spacing: 15) {
                            ForEach(ungroupedTabs) { tab in
                                tabCardView(for: tab)
                            }
                        }
                        .padding(.horizontal, 15)
                    }
                }
            }
            .padding(.bottom, 0)
        }
    }
    
    /// Creates a tab card view for a given tab.
    ///
    /// **Separation of concerns**: TabCardView is a separate component that
    /// handles the card's appearance and interactions. This function just
    /// configures it with the appropriate data and callbacks.
    ///
    /// **matchedGeometryEffect**: This is the magic for hero animations.
    /// When a tab is selected, SwiftUI finds the matching ID in the main view
    /// and animates smoothly between drawer and main view.
    ///
    /// **Callbacks**: onSelect and onClose are closures that call TabManager methods.
    /// This keeps TabDrawerView stateless - it delegates all logic to TabManager.
    ///
    /// **Parameter**:
    /// - tab: The Tab model to display
    @ViewBuilder
    private func tabCardView(for tab: Tab) -> some View {
        TabCardView(
            tab: tab,
            isSelected: tabManager.selectedTab?.id == tab.id,  // Highlight if selected
            onSelect: {
                tabManager.selectTab(tab)  // Select tab and dismiss drawer
            },
            onClose: {
                // Animate the close action
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    tabManager.closeTab(tab)
                }
            },
            tabManager: tabManager
        )
        // Enable hero animation for this tab
        .matchedGeometryEffect(id: tab.id, in: animationNamespace)
        .id(tab.id)  // Unique identifier for SwiftUI's diffing algorithm
    }
    
    /// Defines the grid layout: 2 flexible columns.
    ///
    /// **GridItem**: Specifies column behavior in LazyVGrid.
    /// - `.flexible()`: Column expands to fill available space
    /// - `spacing: 20`: Gap between columns
    ///
    /// **Why 2 columns?**: Optimized for iPhone screens - shows enough tabs
    /// at once while maintaining readable card sizes.
    ///
    /// **Computed property**: Recalculates on each access (though the result
    /// is always the same here). Could be a `let` constant instead, but this
    /// pattern allows for future dynamic column counts based on device size.
    private var gridColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 20),  // Left column
            GridItem(.flexible(), spacing: 20)   // Right column
        ]
    }
    
    /// The background view for the drawer.
    ///
    /// **Conditional compilation**: Uses different backgrounds based on OS version.
    ///
    /// **#if os(iOS)**: Compile-time check - only includes iOS-specific code.
    ///
    /// **@available**: Runtime check for iOS version.
    /// - iOS 26.0+: Glassmorphism effect (frosted glass with blur)
    /// - Earlier versions: Solid color background
    ///
    /// **Glassmorphism**: A modern design trend using translucent layers
    /// with blur effects. Creates depth and visual interest.
    ///
    /// **ultraThinMaterial**: Apple's built-in blur effect that adapts to
    /// content behind it and light/dark mode.
    @ViewBuilder
    private var drawerBackground: some View {
        #if os(iOS)  // iOS-specific code
        if #available(iOS 26.0, *) {
            // Modern glassmorphism effect
            ZStack {
                // Base layer: Ultra-thin material (blur)
                Rectangle()
                    .fill(.ultraThinMaterial)
                // Top layer: Custom glass effect with controlled opacity
                GlassBackgroundView(style: colorScheme == .dark ? .dark : .light)
                    .opacity(glassOpacity)
            }
        } else {
            // Fallback for iOS < 26: Solid color
            systemBackgroundColor
        }
        #else
        // Non-iOS platforms: Solid color
        systemBackgroundColor
        #endif
    }
}

// MARK: - Architecture Summary for Beginners
// ============================================
//
// TabDrawerView demonstrates several important SwiftUI and iOS patterns:
//
// 1. PRESENTATION LAYER PATTERN:
//    - TabDrawerView is a "dumb" view - it displays data but doesn't manage it
//    - All tab operations are delegated to TabManager
//    - This separation of concerns makes code maintainable and testable
//
// 2. @NAMESPACE AND HERO ANIMATIONS:
//    ```swift
//    @Namespace private var animationNamespace
//    // ...
//    .matchedGeometryEffect(id: tab.id, in: animationNamespace)
//    ```
//    - Creates smooth "hero" animations between views
//    - When a tab card is tapped, it morphs into the main view
//    - SwiftUI automatically handles the complex animation math
//
// 3. LAZY LOADING OPTIMIZATION:
//    - LazyVStack and LazyVGrid only create views when visible
//    - With 100+ tabs, this prevents memory issues
//    - Pattern: Use "Lazy" containers for large scrollable lists
//
// 4. DYNAMIC TYPE SUPPORT:
//    - PlatformMetrics scales all dimensions based on user's text size
//    - .dynamicTypeSize(...) caps maximum growth to prevent layout breaking
//    - Accessibility best practice: Support Dynamic Type where possible
//
// 5. SHEET PRESENTATION:
//    ```swift
//    @State private var showingBookmarks = false
//    // ...
//    .sheet(isPresented: $showingBookmarks) { BookmarksView() }
//    ```
//    - Boolean @State controls sheet visibility
//    - Setting to true presents sheet, false dismisses it
//    - SwiftUI handles animation and presentation automatically
//
// 6. CONDITIONAL COMPILATION:
//    - #if os(iOS): Only compile for iOS
//    - @available: Check OS version at runtime
//    - Pattern: Graceful degradation for older OS versions
//
// 7. SECTION ORGANIZATION:
//    ```
//    Pinned Tabs → Tab Groups → Ungrouped Tabs
//    ```
//    - Clear visual hierarchy
//    - Sections only appear if they contain tabs
//    - Pinned tabs always at top (most important)
//
// 8. CALLBACK PATTERN:
//    ```swift
//    onSelect: { tabManager.selectTab(tab) }
//    ```
//    - Child views receive closures (callbacks) for actions
//    - Keeps data flow unidirectional
//    - Parent controls behavior, child handles presentation
//
// 9. GRID LAYOUT WITH LAZYV GRID:
//    - GridItem(.flexible()): Columns expand to fill space
//    - 2-column layout optimized for phone screens
//    - Spacing: 20pt between columns and rows
//
// 10. GLASSMORPHISM (iOS 26+):
//     - Translucent blurred background
//     - .ultraThinMaterial provides base blur
//     - Custom GlassBackgroundView adds visual richness
//     - Fallback to solid color on older devices
//
// KEY TAKEAWAYS:
// - Separate presentation (View) from logic (Manager)
// - Use @Namespace for smooth inter-view animations
// - Optimize large lists with Lazy containers
// - Support accessibility with Dynamic Type
// - Gracefully degrade features on older OS versions
// - Keep views stateless by delegating to managers
//
// This file demonstrates production-quality SwiftUI UI patterns!
