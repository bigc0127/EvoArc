import SwiftUI
import WebKit

struct BottomBarView: View {
    // MARK: - Properties
    
    @State private var swipeDirection: SwipeDirection = .none
    
    enum SwipeDirection {
        case left, right, none
    }
    
    // Bindings
    @Binding var urlString: String
    @Binding var isURLBarFocused: Bool
    @Binding var showingSettings: Bool
    @Binding var shouldNavigate: Bool
    
    // Observed objects
    @ObservedObject var selectedTab: Tab
    @ObservedObject var tabManager: TabManager
    
    // State objects
    @StateObject private var settings = BrowserSettings.shared
    @StateObject private var bookmarkManager = BookmarkManager.shared
    @StateObject private var searchPreloadManager = SearchPreloadManager.shared
    @StateObject private var suggestionManager = SuggestionManager()
    @StateObject private var keyboardManager = KeyboardHeightManager()
    @StateObject private var downloadManager = DownloadManager.shared
    
    // State variables
    @State private var urlEditingText: String = ""
    @State private var searchTimer: Timer?
    @State private var showingDownloads = false
    @State private var gestureProgress: CGFloat = 0
    @FocusState private var isTextFieldFocused: Bool
    
    // Environment values
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorScheme) private var colorScheme
    
    // MARK: - Layout Constants
    
    private let baseRowSpacing: CGFloat = 0 // Remove spacing between elements
    private let baseIconSize: CGFloat = 14
    private let baseTabIndicatorSize: CGFloat = 24
    private let baseButtonSize: CGFloat = 32 // More compact buttons
    private let baseURLBarHeight: CGFloat = 48 // More compact height
    
    // Bottom bar layout constants
    private let bottomBarHorizontalPadding: CGFloat = 16
    private let bottomBarVerticalPadding: CGFloat = 8
    private let bottomBarCornerRadius: CGFloat = 24 // Increased for pill shape
    private let bottomBarHeight: CGFloat = 48 // Fixed height for compact design
    private let bottomBarShadowRadius: CGFloat = 8
    private let bottomBarShadowOpacity: Float = 0.1
    
    private var suggestionsHeight: CGFloat {
        min(CGFloat(suggestionManager.suggestions.count) * 44, 220)
    }
    
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
    
    // MARK: - Background Material
    
    @ViewBuilder
    private var bottomFillBackground: some View {
        RoundedRectangle(cornerRadius: bottomBarCornerRadius)
            .fill(Color(.systemBackground))
            .shadow(color: .black.opacity(0.1), radius: bottomBarShadowRadius, x: 0, y: 4)
            .overlay {
                RoundedRectangle(cornerRadius: bottomBarCornerRadius)
                    .stroke(Color(.separator).opacity(0.2), lineWidth: 0.5)
            }
    }
    
    // MARK: - Main View
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // Background
                Color.clear
                    .ignoresSafeArea()
                
                VStack(spacing: baseRowSpacing) {
                    // Suggestions
                    if isURLBarFocused && !urlEditingText.isEmpty && !suggestionManager.suggestions.isEmpty {
                        suggestionList
                    }
                    
                    // Main toolbar with two rows
                VStack(spacing: baseRowSpacing) {
                        if selectedTab.isLoading {
                            ProgressView(value: selectedTab.estimatedProgress, total: 1.0)
                                .progressViewStyle(LinearProgressViewStyle())
                                .frame(height: 2)
                        }
                        
                        // Top controls row
                        HStack {
                            // Left group: Navigation
                            if !isURLBarFocused && settings.showNavigationButtons {
                                navigationButtons
                            }
                            
                            Spacer()
                            
                            // Center: Tab indicator
                            tabIndicator
                            
                            Spacer()
                            
                            // Right group: Browser controls
                            if !isURLBarFocused {
                                browserControls
                            }
                        }
                        .padding(.horizontal, 12)
                        
                        // Bottom row with URL bar
                        HStack(spacing: 8) {
                            securityIndicator
                            urlField
                            urlBarButtons
                        }
                        .padding(.horizontal, 12)
                        .frame(height: baseURLBarHeight)
                    }
                    .padding(.vertical, bottomBarVerticalPadding)
                    .background(bottomFillBackground)
                    .padding(.horizontal, bottomBarHorizontalPadding)
                    .padding(.bottom, 8)
                }
                .padding(.bottom, 8)
                .keyboardAware(manager: keyboardManager)
            }
        }
        .simultaneousGesture(horizontalSwipeGesture)
        .simultaneousGesture(verticalSwipeGesture)
        .gesture(readerModeGesture)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: keyboardManager.keyboardHeight)
        .animation(.easeInOut(duration: 0.2), value: selectedTab.isLoading)
        .animation(.easeInOut(duration: 0.2), value: isURLBarFocused)
        .animation(.easeInOut(duration: keyboardManager.keyboardAnimationDuration), value: suggestionManager.suggestions)
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onAppear { urlEditingText = urlString }
        .onDisappear { searchTimer?.invalidate() }
    }
    
    // MARK: - Subviews
    
    private var suggestionList: some View {
        ScrollView(.vertical, showsIndicators: false) {
            SuggestionListView(
                suggestions: suggestionManager.suggestions,
                onSuggestionTapped: handleSuggestion,
                onDismiss: { suggestionManager.clearSuggestions() }
            )
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 8)
        }
        .frame(height: suggestionsHeight)
        .clipped()
        .padding(.horizontal, 12)
        .offset(y: -11)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }
    
    private var tabIndicator: some View {
        VStack(spacing: 2) {
            Image(systemName: "chevron.compact.up")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Text("\(tabManager.tabs.count)")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)
                .dynamicTypeSize(...DynamicTypeSize.accessibility3)
        }
        .frame(minWidth: baseTabIndicatorSize)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring()) {
                tabManager.toggleTabDrawer()
            }
        }
    }
    
    private var navigationButtons: some View {
        HStack(spacing: 6) {
            Button(action: { selectedTab.webView?.goBack() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!selectedTab.canGoBack)
            
            Button(action: { selectedTab.webView?.goForward() }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!selectedTab.canGoForward)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.8)))
    }
    
    private var browserControls: some View {
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
                            if let currentIndex = tabManager.tabs.firstIndex(where: { $0.id == selectedTab.id }),
                               currentIndex > 0 {
                                withAnimation {
                                    swipeDirection = .right
                                    tabManager.selectTab(tabManager.tabs[currentIndex - 1])
                                }
                            }
                        } else {
                            if let currentIndex = tabManager.tabs.firstIndex(where: { $0.id == selectedTab.id }),
                               currentIndex < tabManager.tabs.count - 1 {
                                withAnimation {
                                    swipeDirection = .left
                                    tabManager.selectTab(tabManager.tabs[currentIndex + 1])
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
                #if os(iOS)
                UIApplication.shared.sendAction(#selector(UIResponder.selectAll(_:)), to: nil, from: nil, for: nil)
                #else
                NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil)
                #endif
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