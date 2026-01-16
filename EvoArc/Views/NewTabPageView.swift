//
//  NewTabPageView.swift
//  EvoArc
//
//  A clean new tab page displaying a search box and quick access to bookmarks.
//  This view is shown when creating a new tab without a specific URL.
//
//  Key features:
//  1. Centered search box with elegant design
//  2. Bookmark grid display below search box
//  3. Responsive layout that adapts to device size
//  4. Smooth animations and transitions
//

import SwiftUI
import UIKit
import WebKit

/// The new tab page view that displays when users create a new tab.
///
/// **Purpose**: Provides a clean, functional starting point for browsing with:
/// - A prominent search box for easy navigation
/// - Quick access to bookmarks
/// - Elegant, minimal design
///
/// **Layout**: Uses a vertical scroll view with:
/// - Top section: Search box (centered)
/// - Bottom section: Bookmarks grid
struct NewTabPageView: View {
    // MARK: - State Objects and Environment
    
    /// Bookmark manager for accessing saved bookmarks
    @StateObject private var bookmarkManager = BookmarkManager.shared
    
    /// Browser settings for search engine configuration
    @StateObject private var settings = BrowserSettings.shared
    
    /// Current color scheme (light/dark mode)
    @Environment(\.colorScheme) private var colorScheme
    
    // MARK: - State Variables
    
    /// The text entered in the search box
    @State private var searchText: String = ""
    
    /// Whether the search box is focused
    @FocusState private var isSearchFocused: Bool
    
    // MARK: - Bindings
    
    /// Binding to URL string in parent view
    @Binding var urlString: String
    
    /// Binding to trigger navigation in parent view
    @Binding var shouldNavigate: Bool
    
    /// Tab manager for opening bookmarks
    @ObservedObject var tabManager: TabManager
    
    // MARK: - Computed Properties
    
    /// Limited set of bookmarks to display (max 12 for clean layout)
    private var displayedBookmarks: [Bookmark] {
        Array(bookmarkManager.bookmarks.prefix(12))
    }
    
    /// Number of columns for bookmark grid (based on device)
    private var gridColumns: Int {
        if UIDevice.current.userInterfaceIdiom == .pad {
            return 6  // More columns on iPad
        } else {
            return 4  // Fewer columns on iPhone
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 40) {
                    // Top spacer for vertical centering
                    Spacer()
                        .frame(height: geometry.size.height * 0.15)
                    
                    // Search section
                    searchSection
                        .padding(.horizontal, 20)
                    
                    // Bookmarks section
                    if !bookmarkManager.bookmarks.isEmpty {
                        bookmarksSection
                            .padding(.horizontal, 20)
                    }
                    
                    Spacer()
                }
                .frame(minHeight: geometry.size.height)
            }
            .background(backgroundGradient)
        }
    }
    
    // MARK: - Background Gradient
    
    /// Subtle background gradient for visual interest
    private var backgroundGradient: some View {
        LinearGradient(
            colors: colorScheme == .dark
                ? [Color.black, Color(white: 0.05)]
                : [Color(white: 0.98), Color.white],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
    
    // MARK: - Search Section
    
    /// The main search box component
    private var searchSection: some View {
        VStack(spacing: 24) {
            // App logo or title
            Image(systemName: "safari")
                .font(.system(size: 60, weight: .ultraLight))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            // Search box
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 18))
                
                TextField("new_tab_search_placeholder".localized, text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 17))
                    .focused($isSearchFocused)
                    .submitLabel(.search)
                    .onSubmit {
                        performSearch()
                    }
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(colorScheme == .dark ? Color(white: 0.15) : Color.white)
                    .shadow(
                        color: Color.black.opacity(colorScheme == .dark ? 0.4 : 0.08),
                        radius: 20,
                        x: 0,
                        y: 10
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        Color.primary.opacity(isSearchFocused ? 0.2 : 0.05),
                        lineWidth: 1.5
                    )
            )
        }
        .frame(maxWidth: 600)  // Limit width for better appearance
    }
    
    // MARK: - Bookmarks Section
    
    /// Grid of bookmark thumbnails
    private var bookmarksSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section header
            HStack {
                Text("bookmarks_title".localized)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .padding(.horizontal, 4)
            
            // Bookmark grid
            LazyVGrid(
                columns: Array(
                    repeating: GridItem(.flexible(), spacing: 16),
                    count: gridColumns
                ),
                spacing: 20
            ) {
                ForEach(displayedBookmarks) { bookmark in
                    BookmarkThumbnail(bookmark: bookmark) {
                        openBookmark(bookmark)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Helper Methods
    
    /// Performs a search or navigates to URL
    private func performSearch() {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        #if DEBUG
        print("[NewTabPage] performSearch called with: \(trimmed)")
        #endif
        
        // Format the input as a URL or search query
        guard let formattedURL = formatURL(from: trimmed) else {
            #if DEBUG
            print("[NewTabPage] Failed to format URL from: \(trimmed)")
            #endif
            return
        }
        
        #if DEBUG
        print("[NewTabPage] Formatted URL: \(formattedURL.absoluteString)")
        #endif
        
        // Mark that we should now show URLs in the bar (transitioning from new tab page)
        guard let selectedTab = tabManager.selectedTab else {
            #if DEBUG
            print("[NewTabPage] No selected tab found")
            #endif
            return
        }
        
        #if DEBUG
        print("[NewTabPage] Selected tab ID: \(selectedTab.id)")
        print("[NewTabPage] WebView exists: \(selectedTab.webView != nil)")
        #endif
        
        // Transition from new tab page to normal browsing
        selectedTab.showURLInBar = true
        
        // Navigate to the formatted URL
        if let webView = selectedTab.webView {
            #if DEBUG
            print("[NewTabPage] Loading URL in webView: \(formattedURL.absoluteString)")
            #endif
            webView.load(URLRequest(url: formattedURL))
        } else {
            #if DEBUG
            print("[NewTabPage] WebView is nil, setting tab.url instead")
            #endif
            // If webView doesn't exist yet, set the URL on the tab
            // The webView will load it when it's created
            selectedTab.url = formattedURL
            selectedTab.needsInitialLoad = true
        }
        
        // Clear search text
        searchText = ""
        
        // Dismiss keyboard
        isSearchFocused = false
    }
    
    /// Formats user input as either a URL or search query
    private func formatURL(from string: String) -> URL? {
        // If it's already a valid URL with a scheme, use it
        if let url = URL(string: string), url.scheme != nil {
            return url
        }
        
        // If it contains a dot and no spaces, treat it as a URL
        if string.contains(".") && !string.contains(" ") {
            if let url = URL(string: "https://\(string)") {
                return url
            }
        }
        
        // Otherwise, treat it as a search query
        return settings.searchURL(for: string)
    }
    
    /// Opens a bookmark in the current tab
    private func openBookmark(_ bookmark: Bookmark) {
        // Mark that we should now show URLs in the bar (transitioning from new tab page)
        if let selectedTab = tabManager.selectedTab {
            selectedTab.showURLInBar = true
            
            // Load the bookmark URL
            if let webView = selectedTab.webView {
                webView.load(URLRequest(url: bookmark.url))
            }
        }
    }
}

// MARK: - Bookmark Thumbnail Component

/// A single bookmark thumbnail with favicon and title
struct BookmarkThumbnail: View {
    let bookmark: Bookmark
    let action: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                // Favicon or placeholder
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(colorScheme == .dark ? Color(white: 0.2) : Color(white: 0.95))
                    
                    if let faviconData = bookmark.faviconData,
                       let uiImage = UIImage(data: faviconData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 32, height: 32)
                    } else {
                        Image(systemName: "globe")
                            .font(.system(size: 28))
                            .foregroundColor(.secondary.opacity(0.6))
                    }
                }
                .frame(height: 64)
                .shadow(
                    color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.05),
                    radius: 8,
                    x: 0,
                    y: 4
                )
                
                // Title
                Text(bookmark.title)
                    .font(.caption)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)
                    .frame(height: 32)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    NewTabPageView(
        urlString: .constant(""),
        shouldNavigate: .constant(false),
        tabManager: TabManager()
    )
}
