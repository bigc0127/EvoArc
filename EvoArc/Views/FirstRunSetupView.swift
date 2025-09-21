import SwiftUI
import Combine

// Model for managing setup pages
struct SetupPage: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let view: AnyView
}

// First run setup coordinator
class SetupCoordinator: ObservableObject {
    static let firstRunKey = "hasCompletedFirstRunSetup"
    
    var objectWillChange: ObservableObjectPublisher = ObservableObjectPublisher()
    
    @Published var currentPage = 0 {
        willSet { objectWillChange.send() }
    }
    
    @Published var showSetup: Bool {
        willSet { objectWillChange.send() }
    }
    
    let pages: [SetupPage]
    
    init() {
        // Check if this is first run
        self.showSetup = !UserDefaults.standard.bool(forKey: Self.firstRunKey)
        
        // Initialize pages
        self.pages = [
            SetupPage(
                title: "Welcome to EvoArc",
                subtitle: "A smarter way to browse",
                view: AnyView(WelcomeSetupView())
            ),
            SetupPage(
                title: "Choose Your Engine",
                subtitle: "Switch between Safari and Chrome engines with a long press",
                view: AnyView(EngineSetupView())
            ),
            SetupPage(
                title: "Navigation & Display",
                subtitle: "Customize your browsing experience",
                view: AnyView(DisplaySetupView())
            ),
            SetupPage(
                title: "Search & Privacy",
                subtitle: "Configure your search and privacy preferences",
                view: AnyView(SearchPrivacySetupView())
            ),
            SetupPage(
                title: "Tab Management",
                subtitle: "Master efficient tab organization",
                view: AnyView(TabManagementSetupView())
            ),
            SetupPage(
                title: "Gesture Controls",
                subtitle: "Navigate with intuitive gestures",
                view: AnyView(GestureSetupView())
            ),
            SetupPage(
                title: "Downloads & Media",
                subtitle: "Configure download and media preferences",
                view: AnyView(DownloadSetupView())
            ),
            SetupPage(
                title: "You're All Set!",
                subtitle: "Start browsing smarter",
                view: AnyView(SetupCompletionView())
            )
        ]
    }
    
    func completeSetup() {
        UserDefaults.standard.set(true, forKey: Self.firstRunKey)
        showSetup = false
    }
    
    func nextPage() {
        withAnimation {
            if currentPage < pages.count - 1 {
                currentPage += 1
            }
        }
    }
    
    func previousPage() {
        withAnimation {
            if currentPage > 0 {
                currentPage -= 1
            }
        }
    }
}

struct FirstRunSetupView: View {
    @StateObject private var coordinator = SetupCoordinator()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // Progress bar
                    ProgressBar(
                        current: coordinator.currentPage,
                        total: coordinator.pages.count
                    )
                    .padding(.horizontal)
                    
                    // Page content
                    TabView(selection: $coordinator.currentPage) {
                        ForEach(coordinator.pages.indices, id: \.self) { index in
                            coordinator.pages[index].view
                                .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    
                    // Navigation buttons
                    HStack {
                        if coordinator.currentPage > 0 {
                            Button("Back") {
                                coordinator.previousPage()
                            }
                            .buttonStyle(.bordered)
                        }
                        
                        Spacer()
                        
                        if coordinator.currentPage < coordinator.pages.count - 1 {
                            Button("Continue") {
                                coordinator.nextPage()
                            }
                            .buttonStyle(.borderedProminent)
                        } else {
                            Button("Get Started") {
                                coordinator.completeSetup()
                                dismiss()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .navigationBarTitle(coordinator.pages[coordinator.currentPage].title)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Skip") {
                        coordinator.completeSetup()
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Progress Bar Component
struct ProgressBar: View {
    let current: Int
    let total: Int
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .foregroundColor(.secondary.opacity(0.2))
                
                Rectangle()
                    .foregroundColor(.accentColor)
                    .frame(width: geometry.size.width * progress)
            }
        }
        .frame(height: 4)
        .cornerRadius(2)
    }
    
    private var progress: CGFloat {
        return CGFloat(current + 1) / CGFloat(total)
    }
}

// MARK: - Placeholder Setup Page Views
struct WelcomeSetupView: View {
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 100, height: 100)
                .foregroundColor(.accentColor)
            
            Text("Welcome to EvoArc")
                .font(.title)
                .padding(.top)
            
            Text("Your modern browsing experience starts here. EvoArc combines powerful features with intuitive gestures for seamless navigation.")
                .multilineTextAlignment(.center)
                .padding()
            
            VStack(alignment: .leading, spacing: 15) {
                FeatureRow(icon: "hand.tap", title: "Gesture-Based", description: "Navigate with intuitive swipes and taps")
                FeatureRow(icon: "arrow.triangle.2.circlepath.circle", title: "Dual Engines", description: "Switch between Safari and Chrome engines")
                FeatureRow(icon: "shield.checkerboard", title: "Privacy First", description: "Built-in ad blocking and tracking protection")
                FeatureRow(icon: "folder.badge.gearshape", title: "Smart Organization", description: "Efficient tab management and grouping")
            }
            .padding()
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 30)
            
            VStack(alignment: .leading) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// These will be implemented in subsequent steps
struct EngineSetupView: View {
    @StateObject private var settings = BrowserSettings.shared
    @State private var showEngineDemo = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Engine selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("Choose Your Default Engine")
                        .font(.headline)
                    
                    ForEach(BrowserEngine.allCases, id: \.self) { engine in
                        engineButton(engine)
                    }
                    
                    Text("You can always switch engines by long-pressing any tab in the tab drawer.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
                .padding()
                
                // Feature comparison
                VStack(alignment: .leading, spacing: 15) {
                    Text("Engine Features")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 15) {
                            FeatureCard(
                                title: "Safari Mode",
                                icon: "safari",
                                features: [
                                    "Native iOS performance",
                                    "Better battery life",
                                    "System-wide content blockers",
                                    "iCloud syncing support"
                                ]
                            )
                            
                            FeatureCard(
                                title: "Chrome Mode",
                                icon: "globe",
                                features: [
                                    "Chrome-compatible websites",
                                    "Advanced web features",
                                    "Enhanced site compatibility",
                                    "Chrome extension support (partial)"
                                ]
                            )
                        }
                        .padding(.horizontal)
                    }
                }
                
                // Long-press tutorial
                VStack(spacing: 15) {
                    Text("Quick Engine Switching")
                        .font(.headline)
                    
                    Image(systemName: "hand.tap.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.accentColor)
                        .padding()
                    
                    Text("Long-press any tab in the tab drawer to instantly switch between Safari and Chrome engines for that tab. Perfect for when you encounter site compatibility issues.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                }
                .padding()
                
                // Interactive demo button
                Button {
                    showEngineDemo = true
                } label: {
                    Label("Watch Demo", systemImage: "play.circle.fill")
                        .font(.headline)
                }
                .buttonStyle(.bordered)
            }
            .padding(.vertical)
        }
        .sheet(isPresented: $showEngineDemo) {
            EngineDemoView()
        }
    }
    
    private func engineButton(_ engine: BrowserEngine) -> some View {
        Button {
            settings.browserEngine = engine
        } label: {
            HStack {
                Image(systemName: engine == .webkit ? "safari" : "globe")
                    .font(.title3)
                    .foregroundColor(.accentColor)
                
                VStack(alignment: .leading) {
                    Text(engine.displayName)
                        .font(.body)
                    
                    Text(engine == .webkit ? "Best for battery life and privacy" : "Best for site compatibility")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if settings.browserEngine == engine {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
        }
        .buttonStyle(.plain)
    }
}

struct FeatureCard: View {
    let title: String
    let icon: String
    let features: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.headline)
            }
            
            ForEach(features, id: \.self) { feature in
                Label {
                    Text(feature)
                        .font(.subheadline)
                } icon: {
                    Image(systemName: "checkmark")
                        .foregroundColor(.green)
                }
            }
        }
        .padding()
        .frame(width: 250)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}

struct EngineDemoView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 25) {
                // Animated demo
                TabView {
                    demoStep(
                        title: "Find a Tab",
                        description: "Open the tab drawer to see all your tabs.",
                        animation: "arrow.up"
                    )
                    
                    demoStep(
                        title: "Long Press",
                        description: "Press and hold on any tab to open the engine menu.",
                        animation: "hand.tap.fill"
                    )
                    
                    demoStep(
                        title: "Choose Engine",
                        description: "Select Safari or Chrome mode for this tab.",
                        animation: "arrow.triangle.2.circlepath.circle"
                    )
                    
                    demoStep(
                        title: "Instant Switch",
                        description: "The page will reload using the selected engine.",
                        animation: "checkmark.circle.fill"
                    )
                }
                .tabViewStyle(.page)
                .indexViewStyle(.page(backgroundDisplayMode: .always))
                
                Button("Got It!") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .navigationTitle("Engine Switching")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func demoStep(title: String, description: String, animation: String) -> some View {
        VStack(spacing: 30) {
            Image(systemName: animation)
                .font(.system(size: 60))
                .foregroundColor(.accentColor)
            
            VStack(spacing: 8) {
                Text(title)
                    .font(.title2.bold())
                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
    }
}

struct DisplaySetupView: View {
    @StateObject private var settings = BrowserSettings.shared
    @State private var showNavigationDemo = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 25) {
                // Bottom Bar Style
                VStack(alignment: .leading, spacing: 15) {
                    Text("Bottom Bar Style")
                        .font(.headline)
                    
                    HStack(spacing: 15) {
                        displayModeCard(
                            title: "Classic",
                            description: "Traditional glass effect with stronger blur",
                            systemImage: "app.fill",
                            isSelected: !settings.useModernBottomBar
                        ) {
                            settings.useModernBottomBar = false
                        }
                        
                        displayModeCard(
                            title: "Safari Style",
                            description: "Modern transparent look with minimal blur",
                            systemImage: "safari.fill",
                            isSelected: settings.useModernBottomBar
                        ) {
                            settings.useModernBottomBar = true
                        }
                    }
                    
                    Text("Choose how your bottom bar appears. This can be changed anytime in settings.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                
                // Display Mode Section
                VStack(alignment: .leading, spacing: 15) {
                    Text("Display Mode")
                        .font(.headline)
                    
                    HStack(spacing: 15) {
                        displayModeCard(
                            title: "Mobile View",
                            description: "Optimized for mobile browsing",
                            systemImage: "iphone",
                            isSelected: !settings.useDesktopMode
                        ) {
                            settings.useDesktopMode = false
                        }
                        
                        displayModeCard(
                            title: "Desktop View",
                            description: "Full desktop experience",
                            systemImage: "desktopcomputer",
                            isSelected: settings.useDesktopMode
                        ) {
                            settings.useDesktopMode = true
                        }
                    }
                    
                    Text("This can be changed anytime in settings or per-website.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                
                // Navigation Settings
                VStack(alignment: .leading, spacing: 15) {
                    Text("Navigation Preferences")
                        .font(.headline)
                    
                    Toggle("Auto-hide URL Bar", isOn: $settings.autoHideURLBar)
                        .tint(.accentColor)
                    
                    Text("The URL bar will automatically hide when scrolling to maximize content view.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Divider()
                    
                    Toggle("Show Navigation Buttons", isOn: $settings.showNavigationButtons)
                        .tint(.accentColor)
                    
                    Text("Display back/forward buttons in the toolbar.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.secondarySystemGroupedBackground))
                )
                .padding(.horizontal)
                
                // Gesture Tutorial
                VStack(spacing: 15) {
                    Text("Navigation Gestures")
                        .font(.headline)
                    
                    Text("EvoArc is designed around natural gestures for fluid navigation:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        gestureRow(icon: "arrow.left.and.right", title: "Swipe to Navigate", description: "Swipe left/right to go back/forward")
                        gestureRow(icon: "arrow.up", title: "Tab Drawer", description: "Swipe up from bottom bar to access tabs")
                        gestureRow(icon: "hand.draw.fill", title: "Pull to Refresh", description: "Pull down to reload page")
                        gestureRow(icon: "hand.tap.fill", title: "Long Press Actions", description: "Hold links/images for options")
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.secondarySystemGroupedBackground))
                    )
                    
                    Button {
                        showNavigationDemo = true
                    } label: {
                        Label("Try Navigation Demo", systemImage: "play.circle.fill")
                            .font(.headline)
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
            }
        }
        .sheet(isPresented: $showNavigationDemo) {
            NavigationDemoView()
        }
    }
    
    private func displayModeCard(title: String, description: String, systemImage: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 30))
                    .foregroundColor(isSelected ? .white : .accentColor)
                
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.accentColor : Color(.secondarySystemGroupedBackground))
            )
        }
        .buttonStyle(.plain)
    }
    
    private func gestureRow(icon: String, title: String, description: String) -> some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 30)
            
            VStack(alignment: .leading) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct NavigationDemoView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 25) {
                TabView {
                    gestureDemo(
                        title: "Swipe to Navigate",
                        description: "Swipe from the left edge to go back, right edge to go forward.",
                        animation: "arrow.left.and.right"
                    )
                    
                    gestureDemo(
                        title: "Access Tabs",
                        description: "Swipe up from the bottom bar to open the tab drawer.",
                        animation: "arrow.up"
                    )
                    
                    gestureDemo(
                        title: "Pull to Refresh",
                        description: "Pull down and release to reload the current page.",
                        animation: "arrow.clockwise"
                    )
                    
                    gestureDemo(
                        title: "Long Press Actions",
                        description: "Touch and hold links or images for additional options.",
                        animation: "hand.point.up.left"
                    )
                    
                    gestureDemo(
                        title: "Reader Mode",
                        description: "Two-finger swipe down to enter Reader Mode.",
                        animation: "arrow.up.and.down.textformat"
                    )
                }
                .tabViewStyle(.page)
                .indexViewStyle(.page(backgroundDisplayMode: .always))
                
                Button("Got It!") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .navigationTitle("Navigation Guide")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func gestureDemo(title: String, description: String, animation: String) -> some View {
        VStack(spacing: 30) {
            Image(systemName: animation)
                .font(.system(size: 60))
                .foregroundColor(.accentColor)
            
            VStack(spacing: 8) {
                Text(title)
                    .font(.title2.bold())
                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Animated gesture hint
            Image(systemName: "hand.tap.fill")
                .font(.system(size: 40))
                .foregroundColor(.accentColor.opacity(0.5))
                .offset(x: 0, y: -20)
        }
        .padding()
    }
}

struct SearchPrivacySetupView: View {
    @StateObject private var settings = BrowserSettings.shared
    @State private var showAdvancedSettings = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 25) {
                // Search Engine Selection
                VStack(alignment: .leading, spacing: 15) {
                    Text("Choose Your Search Engine")
                        .font(.headline)
                    
                    VStack(spacing: 10) {
                        searchEngineSection(
                            title: "Privacy-Focused",
                            engines: [
                                SearchEngine.duckduckgo,
                                SearchEngine.qwant,
                                SearchEngine.startpage,
                                SearchEngine.presearch,
                                SearchEngine.ecosia
                            ]
                        )
                        
                        searchEngineSection(
                            title: "Traditional",
                            engines: [
                                SearchEngine.google,
                                SearchEngine.bing,
                                SearchEngine.yahoo,
                                SearchEngine.perplexity
                            ]
                        )
                    }
                    
                    Text("You can add a custom search engine in settings later.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                
                // Search Preloading
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Enable Search Preloading", isOn: $settings.searchPreloadingEnabled)
                        .tint(.accentColor)
                    
                    Text("Preload search results as you type for faster searching. This feature sends your search terms to the search engine in real-time.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.secondarySystemGroupedBackground))
                )
                .padding(.horizontal)
                
                // Privacy Features
                VStack(alignment: .leading, spacing: 15) {
                    Text("Privacy Protection")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    // Defaults note for ad-block lists
                    Text("Defaults: EasyList, EasyList Privacy, Peter Lowe’s List, and AdAway are enabled. You can customize these later in Settings.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    
                    VStack(spacing: 0) {
                        Toggle("Ad Blocking", isOn: $settings.adBlockEnabled)
                            .tint(.accentColor)
                            .padding()
                        
                        if settings.adBlockEnabled {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Choose Blocking Lists:")
                                    .font(.subheadline)
                                
                                ForEach(AdBlockList.allCases) { list in
                                    Toggle(isOn: .init(
                                        get: { settings.selectedAdBlockLists.contains(list.rawValue) },
                                        set: { isOn in
                                            if isOn {
                                                settings.selectedAdBlockLists.append(list.rawValue)
                                            } else {
                                                settings.selectedAdBlockLists.removeAll { $0 == list.rawValue }
                                            }
                                        }
                                    )) {
                                        VStack(alignment: .leading) {
                                            Text(list.displayName)
                                                .font(.subheadline)
                                            Text(list.description)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .tint(.accentColor)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.bottom)
                        }
                        
                        Divider()
                        
                        Toggle("Block JavaScript-Injected Ads", isOn: $settings.adBlockScriptletEnabled)
                            .tint(.accentColor)
                            .padding()
                        
                        Text("More aggressive blocking that can break some websites.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                            .padding(.bottom)
                        
                        Divider()
                        
                        Toggle("Auto-Update Block Lists", isOn: $settings.adBlockAutoUpdateOnLaunch)
                            .tint(.accentColor)
                            .padding()
                        
                        Text("Keep blocking rules up to date automatically.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                            .padding(.bottom)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.secondarySystemGroupedBackground))
                    )
                    .padding(.horizontal)
                }
            }
        }
    }
    
    private func searchEngineSection(title: String, engines: [SearchEngine]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            ForEach(engines) { engine in
                searchEngineButton(engine)
            }
        }
    }
    
    private func searchEngineButton(_ engine: SearchEngine) -> some View {
        Button {
            settings.defaultSearchEngine = engine
        } label: {
            HStack {
                Text(engine.displayName)
                    .font(.body)
                
                Spacer()
                
                if settings.defaultSearchEngine == engine {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(settings.defaultSearchEngine == engine ?
                          Color.accentColor.opacity(0.1) :
                          Color(.secondarySystemGroupedBackground))
            )
        }
        .buttonStyle(.plain)
    }
}

struct TabManagementSetupView: View {
    @StateObject private var settings = BrowserSettings.shared
    @State private var showTabTutorial = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 25) {
                // Basic Tab Management
                VStack(alignment: .leading, spacing: 15) {
                    Text("Managing Your Tabs")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        featureRow(
                            icon: "plus.circle",
                            title: "Create New Tabs",
                            description: "Tap the + button or swipe the URL bar right"
                        )
                        
                        featureRow(
                            icon: "xmark.circle",
                            title: "Close Tabs",
                            description: "Swipe a tab left or tap the X button"
                        )
                        
                        featureRow(
                            icon: "arrow.left.and.right",
                            title: "Switch Tabs",
                            description: "Swipe between tabs or use the tab drawer"
                        )
                        
                        featureRow(
                            icon: "pin",
                            title: "Pin Important Tabs",
                            description: "Long press a tab and select 'Pin'"
                        )
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.secondarySystemGroupedBackground))
                    )
                }
                .padding(.horizontal)
                
                // Tab Groups
                VStack(alignment: .leading, spacing: 15) {
                    Text("Tab Groups")
                        .font(.headline)
                    
                    Text("Organize related tabs together for better workflow.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        featureRow(
                            icon: "folder.badge.plus",
                            title: "Create Groups",
                            description: "Tap the folder icon to create a new group"
                        )
                        
                        featureRow(
                            icon: "arrow.up.and.down.and.arrow.left.and.right",
                            title: "Move Tabs",
                            description: "Drag and drop tabs between groups"
                        )
                        
                        featureRow(
                            icon: "checkmark.circle",
                            title: "Quick Switch",
                            description: "Tap a group name to switch contexts"
                        )
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.secondarySystemGroupedBackground))
                    )
                }
                .padding(.horizontal)
                
                // Tab Management Settings
                VStack(alignment: .leading, spacing: 15) {
                    Text("Tab Settings")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    VStack(spacing: 0) {
                        Toggle("Confirm Closing Pinned Tabs", isOn: $settings.confirmClosingPinnedTabs)
                            .tint(.accentColor)
                            .padding()
                        
                        Divider()
                        
                        Toggle("Remember Tab Groups", isOn: $settings.persistTabGroups)
                            .tint(.accentColor)
                            .padding()
                        
                        Text("Restore your tab groups when reopening the app.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                            .padding(.bottom)
                        
                        Divider()
                        
                        Toggle("Hide Empty Groups", isOn: $settings.hideEmptyTabGroups)
                            .tint(.accentColor)
                            .padding()
                        
                        Text("Automatically hide groups with no tabs.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                            .padding(.bottom)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.secondarySystemGroupedBackground))
                    )
                    .padding(.horizontal)
                }
                
                // Interactive Tutorial Button
                Button {
                    showTabTutorial = true
                } label: {
                    Label("Try Tab Management Demo", systemImage: "play.circle.fill")
                        .font(.headline)
                }
                .buttonStyle(.bordered)
                .padding()
            }
        }
        .sheet(isPresented: $showTabTutorial) {
            TabTutorialView()
        }
    }
    
    private func featureRow(icon: String, title: String, description: String) -> some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 30)
            
            VStack(alignment: .leading) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct TabTutorialView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 25) {
                TabView {
                    tutorialStep(
                        title: "The Tab Drawer",
                        description: "Swipe up from the bottom bar or tap the tabs button to open your tab drawer.",
                        animation: "arrow.up"
                    )
                    
                    tutorialStep(
                        title: "Managing Tabs",
                        description: "Create new tabs with the + button, close them by swiping left, or rearrange them by dragging.",
                        animation: "square.stack.3d.up"
                    )
                    
                    tutorialStep(
                        title: "Tab Groups",
                        description: "Create groups to organize related tabs together. Perfect for different projects or workflows.",
                        animation: "folder.badge.plus"
                    )
                    
                    tutorialStep(
                        title: "Quick Actions",
                        description: "Long press any tab for quick actions like pinning, closing, or changing the browser engine.",
                        animation: "hand.tap.fill"
                    )
                }
                .tabViewStyle(.page)
                .indexViewStyle(.page(backgroundDisplayMode: .always))
                
                Button("Got It!") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .navigationTitle("Tab Management")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func tutorialStep(title: String, description: String, animation: String) -> some View {
        VStack(spacing: 30) {
            Image(systemName: animation)
                .font(.system(size: 60))
                .foregroundColor(.accentColor)
            
            VStack(spacing: 8) {
                Text(title)
                    .font(.title2.bold())
                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Animated gesture hint
            if animation == "sidebar.left" {
                Image(systemName: "hand.draw")
                    .font(.system(size: 40))
                    .foregroundColor(.accentColor.opacity(0.5))
                    .offset(x: -20)
            }
        }
        .padding()
    }
}

struct GestureSetupView: View {
    @State private var showGesturePractice = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 25) {
                // Intro Section
                VStack(spacing: 10) {
                    Text("Master EvoArc's Gestures")
                        .font(.title2)
                        .multilineTextAlignment(.center)
                    
                    Text("EvoArc is designed to be intuitive and efficient with gesture-based navigation.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                
                // Navigation Gestures
                VStack(alignment: .leading, spacing: 15) {
                    Text("Page Navigation")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        gestureRow(
                            icon: "arrow.left",
                            title: "Back",
                            description: "Swipe from left edge or swipe right anywhere",
                            color: .blue
                        )
                        
                        gestureRow(
                            icon: "arrow.right",
                            title: "Forward",
                            description: "Swipe from right edge or swipe left anywhere",
                            color: .blue
                        )
                        
                        gestureRow(
                            icon: "arrow.clockwise",
                            title: "Refresh",
                            description: "Pull down and release to reload",
                            color: .blue
                        )
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.secondarySystemGroupedBackground))
                    )
                }
                .padding(.horizontal)
                
                // Tab Gestures
                VStack(alignment: .leading, spacing: 15) {
                    Text("Tab Management")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        gestureRow(
                            icon: "arrow.up",
                            title: "Tab Drawer",
                            description: "Swipe up from bottom bar to access tabs",
                            color: .orange
                        )
                        
                        gestureRow(
                            icon: "hand.tap.fill",
                            title: "Long Press Actions",
                            description: "Hold a tab for engine switching and more",
                            color: .orange
                        )
                        
                        gestureRow(
                            icon: "arrow.up.and.down.and.arrow.left.and.right",
                            title: "Drag & Drop",
                            description: "Move tabs between groups",
                            color: .orange
                        )
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.secondarySystemGroupedBackground))
                    )
                }
                .padding(.horizontal)
                
                // Content Gestures
                VStack(alignment: .leading, spacing: 15) {
                    Text("Content Interaction")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        gestureRow(
                            icon: "hand.tap",
                            title: "Long Press Content",
                            description: "Hold links/images for quick actions",
                            color: .purple
                        )
                        
                        gestureRow(
                            icon: "arrow.up.left.and.arrow.down.right",
                            title: "Pinch to Zoom",
                            description: "Zoom in/out of web content",
                            color: .purple
                        )
                        
                        gestureRow(
                            icon: "textformat.size",
                            title: "Reader Mode",
                            description: "Two-finger swipe down for reader mode",
                            color: .purple
                        )
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.secondarySystemGroupedBackground))
                    )
                }
                .padding(.horizontal)
                
                // Practice Button
                Button {
                    showGesturePractice = true
                } label: {
                    Label("Practice Gestures", systemImage: "hand.tap")
                        .font(.headline)
                }
                .buttonStyle(.bordered)
                .padding()
            }
        }
        .sheet(isPresented: $showGesturePractice) {
            GesturePracticeView()
        }
    }
    
    private func gestureRow(icon: String, title: String, description: String, color: Color) -> some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 30)
            
            VStack(alignment: .leading) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct GesturePracticeView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentStep = 0
    @State private var hasPerformedGesture = false
    
    let steps = [
        GesturePracticeStep(
            title: "Back Navigation",
            description: "Swipe from the left edge or right anywhere to go back",
            animation: "arrow.left",
            gestureHint: "←"
        ),
        GesturePracticeStep(
            title: "Forward Navigation",
            description: "Swipe from the right edge or left anywhere to go forward",
            animation: "arrow.right",
            gestureHint: "→"
        ),
        GesturePracticeStep(
            title: "Tab Drawer",
            description: "Swipe up from the bottom bar to open your tabs",
            animation: "arrow.up",
            gestureHint: "↑"
        ),
        GesturePracticeStep(
            title: "Long Press Actions",
            description: "Touch and hold items for additional options",
            animation: "hand.tap.fill",
            gestureHint: "◉"
        )
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 25) {
                TabView(selection: $currentStep) {
                    ForEach(steps.indices, id: \.self) { index in
                        practiceStep(steps[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page)
                .indexViewStyle(.page(backgroundDisplayMode: .always))
                
                if hasPerformedGesture {
                    Button(currentStep < steps.count - 1 ? "Next Gesture" : "Complete") {
                        if currentStep < steps.count - 1 {
                            withAnimation {
                                currentStep += 1
                                hasPerformedGesture = false
                            }
                        } else {
                            dismiss()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .navigationTitle("Practice Gestures")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Skip") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func practiceStep(_ step: GesturePracticeStep) -> some View {
        VStack(spacing: 30) {
            Image(systemName: step.animation)
                .font(.system(size: 60))
                .foregroundColor(.accentColor)
            
            VStack(spacing: 8) {
                Text(step.title)
                    .font(.title2.bold())
                Text(step.description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Practice area
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .frame(height: 200)
                
                Text(step.gestureHint)
                    .font(.system(size: 40))
                    .foregroundColor(.secondary)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.secondary.opacity(0.3), lineWidth: 1)
            )
            .gesture(
                DragGesture(minimumDistance: 50)
                    .onEnded { _ in
                        withAnimation {
                            hasPerformedGesture = true
                        }
                    }
            )
            .onLongPressGesture { 
                if step.animation == "hand.tap.fill" {
                    withAnimation {
                        hasPerformedGesture = true
                    }
                }
            }
        }
        .padding()
    }
}

struct GesturePracticeStep {
    let title: String
    let description: String
    let animation: String
    let gestureHint: String
}

struct DownloadSetupView: View {
    @StateObject private var settings = BrowserSettings.shared
    @State private var showDownloadDemo = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 25) {
                // Download Management
                VStack(alignment: .leading, spacing: 15) {
                    Text("Download Management")
                        .font(.headline)
                    
                    VStack(spacing: 0) {
                        Toggle("Show Download Notifications", isOn: $settings.showDownloadNotifications)
                            .tint(.accentColor)
                            .padding()
                        
                        Text("Get notified when downloads complete.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                            .padding(.bottom)
                        
                        Divider()
                        
                        Toggle("Auto-Open Downloads", isOn: $settings.autoOpenDownloads)
                            .tint(.accentColor)
                            .padding()
                        
                        Text("Automatically open non-viewable files (like .zip) when download completes.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                            .padding(.bottom)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.secondarySystemGroupedBackground))
                    )
                }
                .padding(.horizontal)
                
                // Download Features
                VStack(alignment: .leading, spacing: 15) {
                    Text("Download Features")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        featureRow(
                            icon: "square.and.arrow.down",
                            title: "Quick Downloads",
                            description: "Long press links or images to download"
                        )
                        
                        featureRow(
                            icon: "play.circle",
                            title: "Media Preview",
                            description: "Preview downloads before saving"
                        )
                        
                        featureRow(
                            icon: "folder.badge.plus",
                            title: "Smart Sorting",
                            description: "Files are sorted by type automatically"
                        )
                        
                        featureRow(
                            icon: "square.and.arrow.up",
                            title: "Share Downloads",
                            description: "Share files directly from downloads"
                        )
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.secondarySystemGroupedBackground))
                    )
                }
                .padding(.horizontal)
                
                // Media Handling
                VStack(alignment: .leading, spacing: 15) {
                    Text("Media Handling")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        featureRow(
                            icon: "play.rectangle",
                            title: "Picture in Picture",
                            description: "Videos continue playing in a floating window"
                        )
                        
                        featureRow(
                            icon: "speaker.wave.2",
                            title: "Background Audio",
                            description: "Audio continues in background"
                        )
                        
                        featureRow(
                            icon: "photo",
                            title: "Media Gallery",
                            description: "View all downloaded media in one place"
                        )
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.secondarySystemGroupedBackground))
                    )
                }
                .padding(.horizontal)
                
                // Interactive Demo Button
                Button {
                    showDownloadDemo = true
                } label: {
                    Label("Try Download Features", systemImage: "arrow.down.circle")
                        .font(.headline)
                }
                .buttonStyle(.bordered)
                .padding()
            }
        }
        .sheet(isPresented: $showDownloadDemo) {
            DownloadDemoView()
        }
    }
    
    private func featureRow(icon: String, title: String, description: String) -> some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 30)
            
            VStack(alignment: .leading) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct DownloadDemoView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 25) {
                TabView {
                    demoStep(
                        title: "Quick Downloads",
                        description: "Long press any link or media to see download options.",
                        animation: "hand.tap.fill"
                    )
                    
                    demoStep(
                        title: "Download Management",
                        description: "Access all your downloads from the downloads tab. Preview, share, or delete files.",
                        animation: "square.and.arrow.down.on.square"
                    )
                    
                    demoStep(
                        title: "Media Features",
                        description: "Picture in Picture and background audio keep your media playing even when browsing other tabs.",
                        animation: "play.rectangle"
                    )
                    
                    demoStep(
                        title: "Smart Organization",
                        description: "Downloads are automatically organized by type. Find what you need quickly.",
                        animation: "folder.badge.plus"
                    )
                }
                .tabViewStyle(.page)
                .indexViewStyle(.page(backgroundDisplayMode: .always))
                
                Button("Got It!") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .navigationTitle("Download Features")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func demoStep(title: String, description: String, animation: String) -> some View {
        VStack(spacing: 30) {
            Image(systemName: animation)
                .font(.system(size: 60))
                .foregroundColor(.accentColor)
            
            VStack(spacing: 8) {
                Text(title)
                    .font(.title2.bold())
                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
    }
}

struct SetupCompletionView: View {
    @StateObject private var settings = BrowserSettings.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                // Celebration Animation
                LottieView(name: "celebration")
                    .frame(width: 200, height: 200)
                
                // Welcome Message
                VStack(spacing: 10) {
                    Text("You're All Set!")
                        .font(.title)
                        .bold()
                    
                    Text("EvoArc is configured and ready to go. Here's a summary of your setup:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                // Settings Summary
                VStack(alignment: .leading, spacing: 20) {
                    summarySection(
                        title: "Browser Engine",
                        value: settings.browserEngine.displayName,
                        icon: settings.browserEngine == .webkit ? "safari" : "globe"
                    )
                    
                    summarySection(
                        title: "Display Mode",
                        value: settings.useDesktopMode ? "Desktop" : "Mobile",
                        icon: settings.useDesktopMode ? "desktopcomputer" : "iphone"
                    )
                    
                    summarySection(
                        title: "Search Engine",
                        value: settings.defaultSearchEngine.displayName,
                        icon: "magnifyingglass"
                    )
                    
                    summarySection(
                        title: "Privacy",
                        value: settings.adBlockEnabled ? "Ad Blocking: EasyList, EasyList Privacy, Peter Lowe’s, AdAway" : "Standard Protection",
                        icon: "shield"
                    )
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.secondarySystemGroupedBackground))
                )
                .padding(.horizontal)
                
                // Quick Access Links
                VStack(alignment: .leading, spacing: 15) {
                    Text("Quick Links")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 15) {
                            quickAccessButton(
                                title: "Gestures",
                                subtitle: "Review navigation gestures",
                                icon: "hand.tap"
                            )
                            
                            quickAccessButton(
                                title: "Privacy",
                                subtitle: "Adjust privacy settings",
                                icon: "shield.lefthalf.filled"
                            )
                            
                            quickAccessButton(
                                title: "Downloads",
                                subtitle: "Manage downloads",
                                icon: "arrow.down.circle"
                            )
                            
                            quickAccessButton(
                                title: "Help",
                                subtitle: "Get assistance",
                                icon: "questionmark.circle"
                            )
                        }
                        .padding(.horizontal)
                    }
                }
                
                // Tips Section
                VStack(alignment: .leading, spacing: 15) {
                    Text("Pro Tips")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        tipRow(
                            icon: "hand.tap.fill",
                            title: "Long Press Power",
                            description: "Long press tabs, links, and images for quick actions"
                        )
                        
                        tipRow(
                            icon: "arrow.left.and.right",
                            title: "Swipe Navigation",
                            description: "Swipe anywhere to go back and forward"
                        )
                        
                        tipRow(
                            icon: "rectangle.on.rectangle",
                            title: "Tab Groups",
                            description: "Organize tabs into groups for better workflow"
                        )
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.secondarySystemGroupedBackground))
                    )
                    .padding(.horizontal)
                }
                
                // Start Browsing Button
                Button {
                    UserDefaults.standard.set(true, forKey: SetupCoordinator.firstRunKey)
                    dismiss()
                } label: {
                    Text("Start Browsing")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                
                // Revisit Option
                Button {
                    // Reset to first page
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let window = windowScene.windows.first {
                        window.rootViewController?.dismiss(animated: true)
                    }
                } label: {
                    Text("Revisit Setup Later")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 30)
        }
    }
    
    private func summarySection(title: String, value: String, icon: String) -> some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 30)
            
            VStack(alignment: .leading) {
                Text(title)
                    .font(.headline)
                Text(value)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func quickAccessButton(title: String, subtitle: String, icon: String) -> some View {
        Button {
            // Navigate to respective section
        } label: {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.accentColor)
                
                VStack(spacing: 4) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 120)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
        }
        .buttonStyle(.plain)
    }
    
    private func tipRow(icon: String, title: String, description: String) -> some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 30)
            
            VStack(alignment: .leading) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct LottieView: View {
    let name: String
    
    var body: some View {
        Color.clear // Placeholder for actual Lottie animation
            .overlay(
                Image(systemName: "star.circle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundColor(.accentColor)
            )
    }
}

#Preview {
    FirstRunSetupView()
}