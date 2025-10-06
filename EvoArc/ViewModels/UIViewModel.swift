//
//  UIViewModel.swift
//  EvoArc
//
//  Manages UI state for the Arc-like browser interface.
//
//  Key responsibilities:
//  1. Command bar visibility and search text
//  2. Sidebar state (width, position, visibility)
//  3. Search suggestions from Google API
//  4. Settings panel visibility
//  5. Theme colors and gradients
//
//  Architecture:
//  - ObservableObject for SwiftUI reactivity
//  - @Published for transient state (resets on app restart)
//  - @AppStorage for persistent state (saved to UserDefaults)
//  - Async/await for network requests
//
//  For Swift beginners:
//  - ViewModel = "Model for the View" (holds UI state)
//  - Separates UI state from business logic
//  - SwiftUI views observe this to update automatically
//

import SwiftUI  // Apple's UI framework - ObservableObject, @AppStorage, Color
import Combine  // Reactive framework - @Published property wrapper

/// Manages state for the Arc-inspired browser UI.
///
/// **ObservableObject**: SwiftUI views can observe this for automatic updates.
///
/// **State categories**:
/// - Transient (@Published): Lost on app restart (command bar, hover state)
/// - Persistent (@AppStorage): Saved to UserDefaults (sidebar settings)
///
/// **Arc-like UI**: Inspired by Arc browser's interface:
/// - Command bar for quick actions
/// - Collapsible sidebar for tabs/bookmarks
/// - Clean, minimal aesthetic
class UIViewModel: ObservableObject {
    // MARK: - Command Bar State
    // The command bar is a popup for quick navigation/search.
    
    /// Whether the command bar is currently visible.
    ///
    /// **@Published**: SwiftUI views observing this automatically update.
    ///
    /// **Transient**: Resets to false on app restart.
    ///
    /// **Use case**: Show/hide command palette (Cmd+K style interface).
    @Published var showCommandBar: Bool = false
    
    /// Current text in the command bar search field.
    ///
    /// **Binding**: SwiftUI TextField binds to this for two-way updates.
    ///
    /// **Use case**: User types search query or URL.
    @Published var commandBarText: String = ""
    
    /// Array of search suggestions from Google API.
    ///
    /// **Updated**: Asynchronously when commandBarText changes.
    ///
    /// **Display**: Shows as dropdown below command bar.
    ///
    /// **Example**: User types "swift" → ["swift programming", "swift tutorial", ...]
    @Published var searchSuggestions: [String] = []
    
    // MARK: - Sidebar State
    // The sidebar shows tabs, bookmarks, and navigation.
    
    /// Private storage for sidebar width (persisted).
    ///
    /// **@AppStorage**: Automatically saves to UserDefaults.
    ///
    /// **Key**: "sidebarWidth" in UserDefaults.
    ///
    /// **Why Double?**: @AppStorage doesn't support CGFloat directly.
    /// We convert to CGFloat in the public computed property.
    ///
    /// **Default**: 300 points (reasonable sidebar width).
    @AppStorage("sidebarWidth") private var _sidebarWidth: Double = 300
    
    /// Whether the sidebar is currently visible.
    ///
    /// **Persistent**: Survives app restarts.
    ///
    /// **Default**: true (sidebar shown by default).
    ///
    /// **Use case**: Toggle button to show/hide sidebar.
    @AppStorage("showSidebar") var showSidebar: Bool = true
    
    /// Which side of the screen the sidebar appears on.
    ///
    /// **Values**: "left" or "right"
    ///
    /// **Persistent**: User preference saved.
    ///
    /// **Use case**: User can customize sidebar position.
    @AppStorage("sidebarPosition") var sidebarPosition: String = "left"
    
    /// Whether sidebar auto-hides when not in use.
    ///
    /// **Auto-hide behavior**: Sidebar appears on hover, hides when mouse leaves.
    ///
    /// **Use case**: Maximize screen space for content.
    @AppStorage("autoHideSidebar") var autoHideSidebar: Bool = false
    
    /// Whether sidebar is in floating overlay mode (iPad only).
    ///
    /// **Floating mode**: Sidebar appears as overlay on top of content.
    ///
    /// **Regular mode**: Sidebar pushes content to the side.
    ///
    /// **Transient**: Resets on app restart.
    @Published var isSidebarFloating: Bool = false
    
    /// Public accessor for sidebar width with CGFloat type.
    ///
    /// **Computed property**: Converts between Double (@AppStorage) and CGFloat (SwiftUI).
    ///
    /// **get**: Reads from _sidebarWidth, converts to CGFloat.
    ///
    /// **set**: Converts from CGFloat, writes to _sidebarWidth.
    ///
    /// **Why needed?**: SwiftUI layout uses CGFloat, but @AppStorage requires Double/Int/String.
    var sidebarWidth: CGFloat {
        get { CGFloat(_sidebarWidth) }
        set { _sidebarWidth = Double(newValue) }
    }
    
    /// Controls sidebar animation offset.
    ///
    /// **Purpose**: Used for slide-in/slide-out animations.
    ///
    /// **Type**: Bool used as animation trigger.
    @Published var sidebarOffset: Bool = true
    
    /// ID of the currently hovered item (tab, bookmark, etc.).
    ///
    /// **Empty string**: No item is hovered.
    ///
    /// **Use case**: Highlight hovered items, show action buttons on hover.
    ///
    /// **Example**: Hovering over tab shows close button.
    @Published var hoveringID: String = ""
    
    // MARK: - Settings Panel
    
    /// Whether the settings panel is currently visible.
    ///
    /// **Transient**: Settings close on app restart.
    ///
    /// **Use case**: Toggle settings sheet/panel.
    @Published var showSettings: Bool = false
    
    // MARK: - Theme Colors
    
    /// Hex color codes for background gradient.
    ///
    /// **Format**: Array of hex strings without # prefix.
    ///
    /// **Gradient**: Blends from first color to last.
    ///
    /// **Current**: Purple-blue gradient ("8041E6" → "A0F2FC").
    ///
    /// **Future**: Could support multiple "spaces" with different gradients.
    let backgroundGradientColors: [String] = ["8041E6", "A0F2FC"]
    
    /// Computed property converting hex strings to SwiftUI Colors.
    ///
    /// **map**: Transforms each hex string into a Color.
    ///
    /// **Color(hex:)**: Extension that parses hex color codes.
    ///
    /// **Returns**: Array of Color objects ready for LinearGradient.
    ///
    /// **Example usage**:
    /// ```swift
    /// LinearGradient(colors: viewModel.backgroundGradient, ...)
    /// ```
    var backgroundGradient: [Color] {
        backgroundGradientColors.map { Color(hex: $0) }
    }
    
    /// Text color for foreground elements.
    ///
    /// **Value**: White (#ffffff) for contrast on gradient.
    ///
    /// **Computed**: Converts hex to Color on each access.
    var textColor: Color {
        Color(hex: "ffffff")
    }
    
    // MARK: - Search Suggestions
    // Methods for fetching autocomplete suggestions from Google.
    
    /// Fetches search suggestions from Google's API.
    ///
    /// **async**: This function is asynchronous (doesn't block the UI).
    ///
    /// **Process**:
    /// 1. Check if search text is not empty
    /// 2. Fetch XML from Google's toolbar API
    /// 3. Parse XML to extract suggestions
    /// 4. Update searchSuggestions on main thread
    ///
    /// **Main thread safety**: Uses MainActor.run for UI updates.
    ///
    /// **Error handling**: Gracefully fails (no suggestions shown).
    ///
    /// **Called**: When commandBarText changes (user types).
    func updateSearchSuggestions() async {
        /// Early return if search text is empty.
        /// No point in fetching suggestions for empty query.
        guard !commandBarText.isEmpty else {
            /// Clear suggestions on main thread.
            /// MainActor.run ensures UI updates happen on main thread.
            await MainActor.run {
                searchSuggestions = []
            }
            return
        }
        
        /// Fetch XML response from Google.
        if let xml = await fetchXML(searchRequest: commandBarText) {
            /// Parse XML to extract suggestion strings.
            let suggestions = formatXML(from: xml)
            
            /// Update UI on main thread.
            /// @Published properties must be updated on main thread.
            await MainActor.run {
                searchSuggestions = suggestions
            }
        }
    }
    
    /// Fetches XML suggestions from Google's toolbar API.
    ///
    /// **private**: Internal implementation detail.
    ///
    /// **async**: Network request doesn't block.
    ///
    /// **Returns**: XML string or nil if request fails.
    ///
    /// **API endpoint**: Google's toolbar completion service.
    /// - Used by Google Toolbar for browser autocomplete
    /// - Public API, no authentication required
    /// - Returns XML format (not JSON)
    ///
    /// **Parameter**:
    /// - searchRequest: User's search query
    ///
    /// **Example**:
    /// Query "swift" returns XML with suggestions like:
    /// ```xml
    /// <suggestion data="swift programming"/>
    /// <suggestion data="swift tutorial"/>
    /// ```
    private func fetchXML(searchRequest: String) async -> String? {
        /// URL-encode spaces as + signs.
        /// Example: "swift programming" → "swift+programming"
        let encodedSearch = searchRequest.replacingOccurrences(of: " ", with: "+")
        
        /// Build Google toolbar API URL.
        /// - q: Search query
        /// - output: toolbar (XML format)
        /// - hl: Language hint (en = English)
        guard let url = URL(string: "https://toolbarqueries.google.com/complete/search?q=\(encodedSearch)&output=toolbar&hl=en") else {
            return nil
        }
        
        do {
            /// Perform network request.
            /// URLSession.shared.data(from:) is async - waits for response.
            let (data, _) = try await URLSession.shared.data(from: url)
            
            /// Convert Data to String.
            /// .utf8 encoding is standard for text responses.
            return String(data: data, encoding: .utf8)
        } catch {
            /// Network error (no connection, timeout, etc.)
            /// Log error and return nil (suggestions won't show).
            print("Fetch error: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Parses XML to extract suggestion strings.
    ///
    /// **Simple parser**: Uses string searching instead of full XML parser.
    ///
    /// **Why not XMLParser?**: For this simple use case, string searching
    /// is faster and has fewer dependencies.
    ///
    /// **XML format**: Looks for `data="..."` attributes.
    ///
    /// **Example input**:
    /// ```xml
    /// <suggestion data="swift programming"/>
    /// <suggestion data="swift tutorial"/>
    /// ```
    ///
    /// **Example output**: ["swift programming", "swift tutorial"]
    ///
    /// **Parameter**:
    /// - input: XML string from Google API
    ///
    /// **Returns**: Array of suggestion strings
    private func formatXML(from input: String) -> [String] {
        /// Array to accumulate found suggestions.
        var results = [String]()
        
        /// Track current position in string (for sequential searching).
        var currentIndex = input.startIndex
        
        /// Loop: Find each occurrence of data="..."
        while let startIndex = input[currentIndex...].range(of: "data=\"")?.upperBound {
            /// Get substring starting after 'data="'
            let remainingSubstring = input[startIndex...]
            
            /// Find closing quote.
            if let endIndex = remainingSubstring.range(of: "\"")?.lowerBound {
                /// Extract text between quotes.
                /// This is the suggestion string.
                let attributeValue = input[startIndex..<endIndex]
                results.append(String(attributeValue))
                
                /// Move past this match to find next suggestion.
                currentIndex = endIndex
            } else {
                /// No closing quote found - malformed XML.
                /// Stop parsing.
                break
            }
        }
        
        return results
    }
}

// MARK: - Comparable Extension

/// Extension adding clamping utility to all Comparable types.
///
/// **Comparable**: Types that can be ordered (<, >, ==).
/// Examples: Int, Double, CGFloat, Date
///
/// **Use case**: Ensure values stay within valid ranges.
extension Comparable {
    /// Clamps this value to the specified range.
    ///
    /// **Clamping**: Constrains a value to stay within bounds.
    ///
    /// **How it works**:
    /// - If value < lowerBound → returns lowerBound
    /// - If value > upperBound → returns upperBound
    /// - Otherwise → returns value unchanged
    ///
    /// **Parameter**:
    /// - range: Valid range (e.g., 0...100)
    ///
    /// **Returns**: Clamped value within range
    ///
    /// **Example**:
    /// ```swift
    /// let width = userInput.clamped(to: 200...500)
    /// // If userInput = 150 → returns 200 (min)
    /// // If userInput = 350 → returns 350 (in range)
    /// // If userInput = 600 → returns 500 (max)
    /// ```
    ///
    /// **Use in EvoArc**: Limit sidebar width to reasonable range.
    func clamped(to range: ClosedRange<Self>) -> Self {
        /// max(self, range.lowerBound): Ensure value >= lower bound
        /// min(..., range.upperBound): Ensure result <= upper bound
        /// Combined: Clamps to range
        min(max(self, range.lowerBound), range.upperBound)
    }
}

// MARK: - Architecture Summary
//
// UIViewModel manages all UI state for the Arc-like interface.
//
// ┌──────────────────────────────────────────────────┐
// │  UIViewModel State Management  │
// └──────────────────────────────────────────────────┘
//
// State Categories:
// =================
//
// Transient (@Published):
// - showCommandBar: Command palette visibility
// - commandBarText: Search/command input
// - searchSuggestions: API results
// - isSidebarFloating: Overlay mode
// - sidebarOffset: Animation state
// - hoveringID: Hover tracking
// - showSettings: Settings panel
//
// Persistent (@AppStorage):
// - sidebarWidth: User-adjusted width
// - showSidebar: Visibility preference
// - sidebarPosition: Left/right placement
// - autoHideSidebar: Auto-hide behavior
//
// Why this split?
// - Transient: Session-specific (don't save)
// - Persistent: User preferences (save to disk)
//
// Search Suggestions Flow:
// ========================
//
//  User types in command bar
//         ↓
//  commandBarText updates
//         ↓
//  updateSearchSuggestions() called (async)
//         ↓
//  fetchXML() requests Google API
//         ↓
//  Receive XML response
//         ↓
//  formatXML() parses suggestions
//         ↓
//  Update searchSuggestions on main thread
//         ↓
//  SwiftUI automatically shows dropdown
//
// Threading:
// - Network request: Background (async/await)
// - UI updates: Main thread (MainActor.run)
//
// SwiftUI Integration:
// ===================
//
// Views observe UIViewModel:
//
// struct CommandBar: View {
//     @ObservedObject var uiViewModel: UIViewModel
//     
//     var body: some View {
//         if uiViewModel.showCommandBar {
//             VStack {
//                 TextField("Search", text: $uiViewModel.commandBarText)
//                 
//                 ForEach(uiViewModel.searchSuggestions) { suggestion in
//                     Text(suggestion)
//                 }
//             }
//         }
//     }
// }
//
// When showCommandBar changes:
// 1. UIViewModel posts objectWillChange
// 2. SwiftUI marks CommandBar as needing update
// 3. body recomputes
// 4. UI animates in/out
//
// @AppStorage Mechanics:
// =====================
//
// @AppStorage("key") var property: Type = default
//
// Reads:
// - First access checks UserDefaults for "key"
// - If found, uses that value
// - If not found, uses default
//
// Writes:
// - Every property change saves to UserDefaults
// - Automatic, no manual save needed
// - Persists between app launches
//
// Type restrictions:
// - Bool, Int, Double, String, Data, URL
// - NOT: CGFloat (use Double wrapper)
// - NOT: Custom types (use Codable + Data)
//
// Performance Characteristics:
// ===========================
//
// Search suggestions:
// - Network latency: ~100-300ms
// - Parsing: <1ms (simple XML)
// - Update frequency: On each keystroke
// - Debouncing: Could add delay to reduce requests
//
// Sidebar resizing:
// - Width updates: Real-time during drag
// - @AppStorage save: Every change (fast)
// - UI updates: 60fps smooth
//
// Memory usage:
// - UIViewModel: ~1KB (small)
// - Search suggestions: ~5-10KB (string array)
// - Total: Negligible
//
// Arc Browser Inspiration:
// ========================
//
// Similarities:
// ✓ Command bar (Cmd+K)
// ✓ Collapsible sidebar
// ✓ Spaces with custom colors
// ✓ Clean, minimal aesthetic
// ✓ Keyboard-first navigation
//
// Differences:
// - Arc: macOS-specific, extensive animations
// - EvoArc: iPad-focused, simpler implementation
// - Arc: Multiple spaces with separate gradients
// - EvoArc: Single space (for now)
//
// Best Practices:
// ==============
//
// ✅ DO use @Published for UI state
// ✅ DO use @AppStorage for user preferences
// ✅ DO update UI on main thread (MainActor)
// ✅ DO use async/await for network requests
// ✅ DO clamp user inputs to valid ranges
//
// ❌ DON'T save transient state to disk
// ❌ DON'T block main thread with network requests
// ❌ DON'T directly manipulate UserDefaults (use @AppStorage)
// ❌ DON'T forget to handle network errors
// ❌ DON'T spam API with too many requests
//
// Integration with EvoArc:
// =======================
//
// UIViewModel coordinates:
// - CommandBarView: Search and navigation
// - SidebarView: Tab/bookmark management
// - WebContentPanel: Main browsing area
// - SettingsView: Preferences
//
// This provides Arc-inspired UI with iPad optimization.
