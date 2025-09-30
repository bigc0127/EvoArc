//
//  MacOSBottomBar.swift
//  EvoArc
//
//  Created on 2025-09-28.
//

import SwiftUI
import WebKit

#if os(macOS)

struct MacOSBottomBarView: View {
    @Binding var urlString: String
    @Binding var isURLBarFocused: Bool
    @ObservedObject var tabManager: TabManager
    var selectedTab: Tab
    @Binding var showingSettings: Bool
    @Binding var shouldNavigate: Bool
    @StateObject private var settings = BrowserSettings.shared
    @StateObject private var bookmarkManager = BookmarkManager.shared
    @StateObject private var searchPreloadManager = SearchPreloadManager.shared
    @State private var urlEditingText: String = ""
    @State private var searchTimer: Timer?
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Progress bar
            if selectedTab.isLoading {
                ProgressView(value: selectedTab.estimatedProgress, total: 1.0)
                    .progressViewStyle(LinearProgressViewStyle())
                    .frame(height: 2)
            }
            
            Divider()
            
            HStack(spacing: 12) {
                // Back button
                Button(action: {
                    selectedTab.webView?.goBack()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14))
                        .foregroundColor(selectedTab.canGoBack ? .primary : .secondary)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(!selectedTab.canGoBack)
                
                // Forward button
                Button(action: {
                    selectedTab.webView?.goForward()
                }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .foregroundColor(selectedTab.canGoForward ? .primary : .secondary)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(!selectedTab.canGoForward)
                
                // Reload/Stop button
                Button(action: {
                    if selectedTab.isLoading {
                        selectedTab.webView?.stopLoading()
                    } else {
                        selectedTab.webView?.reload()
                    }
                }) {
                    Image(systemName: selectedTab.isLoading ? "xmark" : "arrow.clockwise")
                        .font(.system(size: 14))
                        .foregroundColor(.primary)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Enhanced URL bar with suggestions support
                HStack {
                    Button(action: {
                        if selectedTab.isLoading {
                            selectedTab.webView?.stopLoading()
                        }
                    }) {
                        Image(systemName: selectedTab.isLoading ? "xmark" : "lock.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .disabled(!selectedTab.isLoading)
                    
                    TextField("Search or enter address", text: $urlEditingText)
                        .textFieldStyle(PlainTextFieldStyle())
                        // URL updates happen through property updates, not Combine
                        .onTapGesture {
                            if !isTextFieldFocused {
                                // When user taps URL bar, enable URL display
                                selectedTab.showURLInBar = true
                                // Show current URL if available
                                if let currentURL = selectedTab.webView?.url {
                                    urlEditingText = currentURL.absoluteString
                                }
                                isTextFieldFocused = true
                            }
                        }
                        .onChange(of: urlEditingText) { _, newValue in
                            // Cancel previous timer
                            searchTimer?.invalidate()
                            
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
                    
                    HStack(spacing: 6) {
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
                            .buttonStyle(PlainButtonStyle())
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
                            .buttonStyle(PlainButtonStyle())
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
                            .buttonStyle(PlainButtonStyle())
                        }
                        
                        // Show loading indicator when not focused
                        if !isURLBarFocused && selectedTab.isLoading {
                            ProgressView()
                                .scaleEffect(0.6)
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
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
                                .font(.system(size: 14))
                                .foregroundColor(selectedTab.isPinned ? .accentColor : .primary)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(selectedTab.url == nil)
                        
                        // Tab drawer toggle button
                        Button(action: {
                            tabManager.toggleTabDrawer()
                        }) {
                            Image(systemName: "sidebar.leading")
                                .font(.system(size: 14))
                                .foregroundColor(.primary)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // Menu button with consolidated options
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
                            
                            Button(action: {
                                settings.adBlockEnabled.toggle()
                                selectedTab.webView?.reload()
                            }) {
                                Label(
                                    settings.adBlockEnabled ? "Disable Ad Blocking" : "Enable Ad Blocking",
                                    systemImage: settings.adBlockEnabled ? "eye.slash" : "eye"
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
                                if let url = selectedTab.url {
                                    let picker = NSSharingServicePicker(items: [url])
                                    // Present the picker relative to the Share menu item
                                    if let menuItem = NSApplication.shared.keyWindow?.contentView?.window?.contentView {
                                        picker.show(relativeTo: .zero, of: menuItem, preferredEdge: .minY)
                                    }
                                }
                            }) {
                                Label("Share", systemImage: "square.and.arrow.up")
                            }
                            .disabled(selectedTab.url == nil)
                            
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
                            
                            Divider()
                            
                            Button(action: {
                                showingSettings = true
                            }) {
                                Label("Settings", systemImage: "gear")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 14))
                                .foregroundColor(.primary)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .menuStyle(BorderlessButtonMenuStyle())
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(NSColor.windowBackgroundColor))
            .animation(.easeInOut(duration: 0.25), value: isURLBarFocused)
        }
        .onAppear {
            urlEditingText = urlString
        }
        .onDisappear {
            searchTimer?.invalidate()
        }
    }
}

#endif