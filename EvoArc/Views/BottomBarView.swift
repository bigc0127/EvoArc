import SwiftUI
import WebKit

// FIX: Ensure all braces match.
struct BottomBarView: View {
    // State variable to track swipe direction
    @State private var swipeDirection: SwipeDirection = .none
    
    enum SwipeDirection {
        case left, right, none
    }
    @Binding var urlString: String
    @Binding var isURLBarFocused: Bool
    @ObservedObject var tabManager: TabManager
    @ObservedObject var selectedTab: Tab
    @Binding var showingSettings: Bool
    @Binding var shouldNavigate: Bool
    @StateObject private var settings = BrowserSettings.shared
    @StateObject private var bookmarkManager = BookmarkManager.shared
    @StateObject private var searchPreloadManager = SearchPreloadManager.shared
    @StateObject private var suggestionManager = SuggestionManager()
    @StateObject private var keyboardManager = KeyboardHeightManager()
    @State private var urlEditingText: String = ""
    @State private var searchTimer: Timer?
    @State private var showingDownloads = false
    @FocusState private var isTextFieldFocused: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var downloadManager = DownloadManager.shared
    @State private var gestureProgress: CGFloat = 0

    private var suggestionsHeight: CGFloat {
        min(CGFloat(suggestionManager.suggestions.count) * 44, 220)
    }

    // Constants for base sizes that will be dynamically scaled
    private let baseIconSize: CGFloat = 15  // Reduced by 25% from original 20
    private let baseTabIndicatorSize: CGFloat = 24  // Reduced by 25% from original 32
    private let baseButtonSize: CGFloat = 36  // Reduced by 25% from original 48
    private let baseURLBarHeight: CGFloat = 58  // Reduced by 25% from original 77
    // Visual style constants

    private var scaledIconSize: CGFloat { baseIconSize * dynamicTypeSize.customScaleFactor }
    private var scaledTabIndicatorSize: CGFloat { baseTabIndicatorSize * dynamicTypeSize.customScaleFactor }
    private var scaledButtonSize: CGFloat { baseButtonSize * dynamicTypeSize.customScaleFactor }
    private var scaledURLBarHeight: CGFloat { baseURLBarHeight * dynamicTypeSize.customScaleFactor }

    private var backgroundColor: Color {
        #if os(iOS)
        Color(uiColor: .systemBackground)
        #else
        Color(NSColor.controlBackgroundColor)
        #endif
    }

    private var secondaryBackgroundColor: Color {
        #if os(iOS)
        Color(uiColor: .secondarySystemBackground)
        #else
        Color(NSColor.controlBackgroundColor)
        #endif
    }
    
    // Background material that matches the bottom bar look and can fill to the bottom edge
    @ViewBuilder
    private var bottomFillBackground: some View {
        #if os(iOS)
        if #available(iOS 26.0, *) {
            ZStack {
                Rectangle()
                    .fill(settings.useModernBottomBar ? .regularMaterial : .ultraThinMaterial)
                    .opacity(settings.useModernBottomBar ? 0.7 : 0.95)
                GlassBackgroundView(style: colorScheme == .dark ? .dark : .light)
                    .opacity(settings.useModernBottomBar ? 0.08 : 0.65)
                    .blur(radius: settings.useModernBottomBar ? 0.1 : 1.2)
            }
            .overlay {
                Rectangle()
                    .stroke(Color.white.opacity(settings.useModernBottomBar ? 0.08 : 0.15),
                            lineWidth: settings.useModernBottomBar ? 0.2 : 0.3)
            }
        } else {
            backgroundColor
        }
        #else
        backgroundColor
        #endif
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // Background filler
                Color.clear
                    .ignoresSafeArea()

                // Bottom-aligned stack containing suggestions and toolbar so they move together with the keyboard
                VStack(spacing: 8) {
                    // Suggestions anchored just above the URL bar
                    if isURLBarFocused && !urlEditingText.isEmpty && !suggestionManager.suggestions.isEmpty {
                        ScrollView(.vertical, showsIndicators: false) {
                            SuggestionListView(
                                suggestions: suggestionManager.suggestions,
                                onSuggestionTapped: { item in
                                    withAnimation(.easeInOut(duration: keyboardManager.keyboardAnimationDuration)) {
                                        switch item.type {
                                        case .history:
                                            if let url = item.url {
                                                urlString = url.absoluteString
                                            } else {
                                                urlString = item.text
                                            }
                                            shouldNavigate = true
                                        case .url:
                                            if let url = item.url {
                                                urlString = url.absoluteString
                                            } else {
                                                urlString = item.text
                                            }
                                            shouldNavigate = true
                                        case .search:
                                            // Build search URL using user's selected search engine
                                            if let url = BrowserSettings.shared.searchURL(for: item.text) {
                                                urlString = url.absoluteString
                                                shouldNavigate = true
                                            } else {
                                                // Fallback to raw text navigation
                                                urlString = item.text
                                                shouldNavigate = true
                                            }
                                        }
                                        isTextFieldFocused = false
                                    }
                                },
                                onDismiss: {
                                    suggestionManager.clearSuggestions()
                                }
                            )
            .background(Color(.systemBackground))
            .gesture(
                DragGesture(minimumDistance: 30)
                    .onEnded { value in
                        let horizontalAmount = value.translation.width
                        
                        if abs(horizontalAmount) > 50 { // Threshold for swipe
                            if horizontalAmount > 0 {
                                // Swipe right - go to previous tab
                                if let currentIndex = tabManager.tabs.firstIndex(where: { $0.id == selectedTab.id }),
                                   currentIndex > 0 {
                                    withAnimation {
                                        swipeDirection = .right
                                        tabManager.selectTab(tabManager.tabs[currentIndex - 1])
                                    }
                                }
                            } else {
                                // Swipe left - go to next tab
                                if let currentIndex = tabManager.tabs.firstIndex(where: { $0.id == selectedTab.id }),
                                   currentIndex < tabManager.tabs.count - 1 {
                                    withAnimation {
                                        swipeDirection = .left
                                        tabManager.selectTab(tabManager.tabs[currentIndex + 1])
                                    }
                                }
                            }
                            
                            // Reset swipe direction after a delay
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                swipeDirection = .none
                            }
                        }
                    }
            )
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.1), radius: 8)
                        }
                        .frame(height: suggestionsHeight)
                        .clipped()
                        .padding(.horizontal, 12)
                        .offset(y: -11)  // Reduced by 25% from -15 to maintain proper spacing with shorter bar
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    // Toolbar and progress
                    VStack(spacing: 0) {
                        // Progress bar
                        if selectedTab.isLoading {
                            ProgressView(value: selectedTab.estimatedProgress, total: 1.0)
                                .progressViewStyle(LinearProgressViewStyle())
                                .frame(height: 2)
                        }

                        // Main toolbar
                        VStack(spacing: 0) {
                            HStack(spacing: UIScaleMetrics.scaledPadding(10)) {
                                // Tab indicator (swipe up to open) - always visible
                                VStack(spacing: UIScaleMetrics.scaledPadding(2)) {
                                    Image(systemName: "chevron.compact.up")
                                        .font(.system(size: UIScaleMetrics.iconSize(12)))
                                        .foregroundColor(.secondary)
                                    Text("\(tabManager.tabs.count)")
                                        .font(.system(size: UIScaleMetrics.iconSize(10), weight: .semibold))
                                        .foregroundColor(.secondary)
                                        .dynamicTypeSize(...DynamicTypeSize.accessibility3)
                                }
                                .frame(minWidth: UIScaleMetrics.maxDimension(baseTabIndicatorSize))
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    withAnimation(.spring()) {
                                        tabManager.toggleTabDrawer()
                                    }
                                }

                                // Navigation buttons - hidden when URL bar is focused or disabled in settings
                                if !isURLBarFocused && settings.showNavigationButtons {
                                    HStack(spacing: UIScaleMetrics.scaledPadding(8)) {
                                        // Back button
                                        Button(action: {
                                            selectedTab.webView?.goBack()
                                        }) {
                                            Image(systemName: "chevron.left")
                                                .font(.system(size: UIScaleMetrics.iconSize(baseIconSize)))
                                                .frame(width: UIScaleMetrics.maxDimension(baseButtonSize), height: UIScaleMetrics.maxDimension(baseButtonSize))
                                                .contentShape(Rectangle())
                                        }
                                        .disabled(!selectedTab.canGoBack)

                                        // Forward button
                                        Button(action: {
                                            selectedTab.webView?.goForward()
                                        }) {
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: UIScaleMetrics.iconSize(baseIconSize)))
                                                .frame(width: UIScaleMetrics.maxDimension(baseButtonSize), height: UIScaleMetrics.maxDimension(baseButtonSize))
                                                .contentShape(Rectangle())
                                        }
                                        .disabled(!selectedTab.canGoForward)
                                    }
                                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
                                }

                                // URL bar - expanded when focused
                                HStack(spacing: UIScaleMetrics.scaledPadding(10)) {
                                    if !isURLBarFocused && settings.showNavigationButtons {
                                        Button(action: {
                                            if selectedTab.isLoading {
                                                selectedTab.webView?.stopLoading()
                                            }
                                        }) {
                                            Image(systemName: selectedTab.isLoading ? "xmark" : "lock.fill")
                                                .font(.system(size: UIScaleMetrics.iconSize(12)))
                                                .foregroundColor(.secondary)
                                        }
                                        .disabled(!selectedTab.isLoading)
                                        .frame(width: 20, height: 20)
                                    }

                                    TextField("Search or enter address", text: $urlEditingText)
                                        .font(.body)
                                        .textFieldStyle(PlainTextFieldStyle())
                                        .frame(height: 28)
                                        .frame(maxWidth: .infinity)
                                        .multilineTextAlignment(.center)
                                        .focused($isTextFieldFocused)
                                        .task(id: selectedTab.url) {
                                            if !isURLBarFocused {
                                                // Only show URL if explicitly enabled
                                                if selectedTab.showURLInBar {
                                                    urlEditingText = selectedTab.url?.absoluteString ?? ""
                                                } else {
                                                    urlEditingText = ""
                                                }
                                            }
                                        }
                                        .onChange(of: urlEditingText) { _, newValue in
                                            searchTimer?.invalidate()
                                            suggestionManager.getSuggestions(for: newValue)
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
                                        .onTapGesture {
                                            if !isTextFieldFocused {
                                                // When user taps URL bar, enable URL display
                                                selectedTab.showURLInBar = true
                                                // Show current URL if available
                                                if let currentURL = selectedTab.webView?.url {
                                                    urlEditingText = currentURL.absoluteString
                                                }
                                                isTextFieldFocused = true
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                                    #if os(iOS)
                                                    UIApplication.shared.sendAction(#selector(UIResponder.selectAll(_:)), to: nil, from: nil, for: nil)
                                                    #else
                                                    NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil)
                                                    #endif
                                                }
                                            }
                                        }
                                        .onChange(of: isTextFieldFocused) { _, focused in
                                            isURLBarFocused = focused
                                        }

                                    HStack(spacing: 8) {
                                        // Bookmark button
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
                                                        .font(.system(size: UIScaleMetrics.iconSize(12)))
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
                                                    .font(.system(size: UIScaleMetrics.iconSize(14), weight: .semibold))
                                                    .dynamicTypeSize(...DynamicTypeSize.accessibility3)
                                                    .foregroundColor(.accentColor)
                                            }
                                        }
                                    }
                                }
                                .scaledPadding(.horizontal, 10)
                                .scaledPadding(.vertical, 8)
                                .frame(minHeight: UIScaleMetrics.maxDimension(baseURLBarHeight))
                                .contentShape(Rectangle())  // Make entire URL bar tappable
                                .background {
                                    #if os(iOS)
                                    if #available(iOS 26.0, *) {
                                        RoundedRectangle(cornerRadius: UIScaleMetrics.scaledPadding(12), style: .continuous)
                                            .fill(.thinMaterial)
                                            .overlay {
                                                GlassBackgroundView(style: colorScheme == .dark ? .dark : .light)
                                                    .opacity(0.2)
                                            }
                                            .overlay {
                                                RoundedRectangle(cornerRadius: UIScaleMetrics.scaledPadding(12), style: .continuous)
                                                    .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                                            }
                                            .shadow(color: .black.opacity(0.15), radius: 1, x: 0, y: 0.5)
                                    } else {
                                        RoundedRectangle(cornerRadius: UIScaleMetrics.scaledPadding(8))
                                            .fill(secondaryBackgroundColor)
                                    }
                                    #else
                                    RoundedRectangle(cornerRadius: UIScaleMetrics.scaledPadding(8))
                                        .fill(secondaryBackgroundColor)
                                    #endif
                                }

                                // Right side buttons - hidden when URL bar is focused
                                if !isURLBarFocused {
                                    HStack(spacing: UIScaleMetrics.scaledPadding(8)) {
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

                                        // Reader mode indicator
                                        if selectedTab.readerModeEnabled {
                                            Image(systemName: "textformat.size")
                                                .font(.system(size: 16))
                                                .foregroundColor(.accentColor)
                                        }

                                        // Menu button
                                        Menu {
                                            Button(action: {
                                                tabManager.createNewTab()
                                            }) {
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

                                            Button(action: {
                                                guard let url = selectedTab.url else { return }
                                                let items: [Any] = [url]
                                                let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)
                                                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                                                   let window = windowScene.windows.first,
                                                   let rootViewController = window.rootViewController {
                                                    if let popoverController = activityVC.popoverPresentationController {
                                                        popoverController.sourceView = rootViewController.view
                                                        popoverController.sourceRect = CGRect(x: UIScreen.main.bounds.width / 2,
                                                                                             y: UIScreen.main.bounds.height / 2,
                                                                                             width: 0,
                                                                                             height: 0)
                                                    }
                                                    rootViewController.present(activityVC, animated: true)
                                                }
                                            }) {
                                                Label("Share", systemImage: "square.and.arrow.up")
                                            }
                                            .disabled(selectedTab.url == nil)

                                            Divider()

                                            Button(action: {
                                                // Toggle reader mode using two-finger swipe handler
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
                                            }) {
                                                Label(selectedTab.readerModeEnabled ? "Disable Reader Mode" : "Enable Reader Mode",
                                                      systemImage: "textformat.size")
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
                            }
                            .scaledPadding(.horizontal, 12)
                            .scaledPadding(.vertical, 10)
                        // Add horizontal swipe gesture for tab switching
                        .simultaneousGesture(
                            DragGesture(minimumDistance: 20)
                                .onChanged { value in
                                    // Only track horizontal gesture when not in text editing mode
                                    if !isURLBarFocused {
                                        let horizontalAmount = value.translation.width
                                        let verticalAmount = value.translation.height
                                        
                                        // Check if gesture is primarily horizontal
                                        if abs(horizontalAmount) > abs(verticalAmount) * 1.5 {
                                            tabManager.isGestureActive = true
                                        }
                                    }
                                }
                                .onEnded { value in
                                    defer { tabManager.isGestureActive = false }
                                    
                                    // Only process horizontal swipes when not in text editing mode
                                    if !isURLBarFocused {
                                        let horizontalAmount = value.translation.width
                                        let verticalAmount = value.translation.height
                                        
                                        // Check if the gesture is primarily horizontal
                                        if abs(horizontalAmount) > abs(verticalAmount) * 1.5 && abs(horizontalAmount) > 50 {
                                            if horizontalAmount > 0 {
                                                // Swipe right - go to previous tab
                                                if let currentIndex = tabManager.tabs.firstIndex(where: { $0.id == selectedTab.id }),
                                                   currentIndex > 0 {
                                                    withAnimation {
                                                        swipeDirection = .right
                                                        tabManager.selectTab(tabManager.tabs[currentIndex - 1])
                                                    }
                                                }
                                            } else {
                                                // Swipe left - go to next tab
                                                if let currentIndex = tabManager.tabs.firstIndex(where: { $0.id == selectedTab.id }),
                                                   currentIndex < tabManager.tabs.count - 1 {
                                                    withAnimation {
                                                        swipeDirection = .left
                                                        tabManager.selectTab(tabManager.tabs[currentIndex + 1])
                                                    }
                                                }
                                            }
                                            
                                            // Reset swipe direction after a delay
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                                swipeDirection = .none
                                            }
                                        }
                                    }
                                }
                        )
                        // Add vertical swipe gesture for tab drawer
                        .simultaneousGesture(
                            DragGesture(minimumDistance: 20)
                                .onChanged { value in
                                    // Only activate gesture if not already active and not in text editing mode
                                    if !tabManager.isGestureActive && !isURLBarFocused {
                                        let verticalAmount = value.translation.height
                                        let horizontalAmount = value.translation.width
                                        
                                        // Check if gesture is primarily vertical
                                        if abs(verticalAmount) > abs(horizontalAmount) * 1.5 {
                                            tabManager.isGestureActive = true
                                            // Update gesture progress
                                            gestureProgress = min(1.0, abs(verticalAmount) / 100)
                                        }
                                    } else if tabManager.isGestureActive {
                                        // Continue updating progress if gesture is active
                                        gestureProgress = min(1.0, abs(value.translation.height) / 100)
                                    }
                                }
                                .onEnded { value in
                                    // Always deactivate gesture on end
                                    defer {
                                        tabManager.isGestureActive = false
                                        withAnimation(.spring()) {
                                            gestureProgress = 0
                                        }
                                    }

                                    // Only process gesture if not in text editing mode
                                    if !isURLBarFocused {
                                        let verticalAmount = value.translation.height
                                        let horizontalAmount = value.translation.width
                                        
                                        // Check if gesture is primarily vertical and significant
                                        if abs(verticalAmount) > abs(horizontalAmount) * 1.5 && verticalAmount < -50 {
                                            withAnimation(.spring()) {
                                                tabManager.toggleTabDrawer()
                                            }
                                        }
                                    }
                                }
                        )
                            // Add two-finger swipe down gesture for reader mode
                            .gesture(
                                DragGesture(minimumDistance: 20)
                                    .simultaneously(with: DragGesture(minimumDistance: 20))
                                    .onEnded { value in
                                        let verticalAmount = value.first?.translation.height ?? 0
                                        let horizontalAmount = value.first?.translation.width ?? 0
                                        
                                        // Check if the gesture is primarily vertical and downward
                                        if verticalAmount > abs(horizontalAmount) * 1.5 && verticalAmount > 50 {
                                            // Toggle reader mode
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
                                    }
                            )
                            .background {
                                #if os(iOS)
                                if #available(iOS 26.0, *) {
                                    ZStack {
                                        Rectangle()
                                            .fill(settings.useModernBottomBar ? .regularMaterial : .ultraThinMaterial)
                                            .opacity(settings.useModernBottomBar ? 0.7 : 0.95)
                                        GlassBackgroundView(style: colorScheme == .dark ? .dark : .light)
                                            .opacity(settings.useModernBottomBar ? 0.08 : 0.65)
                                            .blur(radius: settings.useModernBottomBar ? 0.1 : 1.2)
                                    }
                                    .overlay {
                                        Rectangle()
                                            .stroke(Color.white.opacity(settings.useModernBottomBar ? 0.08 : 0.15), 
                                                    lineWidth: settings.useModernBottomBar ? 0.2 : 0.3)
                                    }
                                } else {
                                    backgroundColor
                                }
                                #else
                                backgroundColor
                                #endif
                            }
.frame(height: baseURLBarHeight)
                        }
                        
                        // Fill the gap to the bottom with matching material without affecting layout
                        .background {
                            bottomFillBackground
                                .ignoresSafeArea(.container, edges: .bottom)
                        }
                    }
                    .padding(.bottom, 8)
                }
                .keyboardAware(manager: keyboardManager)
            }
        }
        .animation(.easeInOut(duration: keyboardManager.keyboardAnimationDuration), value: isURLBarFocused)
        .animation(.easeInOut(duration: keyboardManager.keyboardAnimationDuration), value: suggestionManager.suggestions)
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onAppear {
            urlEditingText = urlString
        }
        .onDisappear {
            searchTimer?.invalidate()
        }
    }
}
