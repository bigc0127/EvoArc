import SwiftUI
import UIKit

/// The main settings interface view for EvoArc browser configuration
struct SettingsView: View {
    /// Reference to the global browser settings singleton
    /// @StateObject ensures this view owns and observes the settings instance
    @ObservedObject private var settings = BrowserSettings.shared
    @ObservedObject private var perplexityManager = PerplexityManager.shared
    @ObservedObject private var adBlockManager = AdBlockManager.shared
    @ObservedObject private var downloadManager = DownloadManager.shared
    @StateObject private var uiViewModel = UIViewModel()
    
    // Constants for base sizes that will be dynamically scaled
    private let baseIconSize: CGFloat = 16
    private let baseSpacing: CGFloat = 12
    private let baseFormPadding: CGFloat = 20
    
    /// SwiftUI environment value for dismissing this modal view
@Environment(\.dismiss) private var dismiss
    
    /// Local state for the homepage text field to enable real-time validation
    @State private var homepageText: String = ""
    
    /// Optional reference to the tab manager for creating new tabs
    var tabManager: TabManager?
    
    @State private var showAdvancedJSAdblockWarning: Bool = false
    
    private var toolbarPlacement: ToolbarItemPlacement {
        .navigationBarTrailing
    }
    
    var body: some View {
        NavigationView {
            Form {
                settingsContent
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Warning: Advanced ad blocking may break some websites", isPresented: $showAdvancedJSAdblockWarning) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Turning on advanced JS-injected ad blocking is more aggressive and can hide parts of some websites. You can disable it here anytime.")
            }
            .toolbar {
                ToolbarItem(placement: toolbarPlacement) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            homepageText = settings.homepage
        }
    }
    
    @ViewBuilder
    private var settingsContent: some View {
                // General Section
                Section {
                    HStack {
                        Text("Homepage")
                        Spacer()
                        TextField("Enter URL", text: $homepageText)
                            .textFieldStyle(.roundedBorder)
                            .autocorrectionDisabled(true)
                            .textInputAutocapitalization(.never)
                            .frame(maxWidth: 200)
                            .onSubmit {
                                saveHomepage()
                            }
                    }
                    
                    if homepageText != settings.homepage {
                        HStack {
                            Button("Save") {
                                saveHomepage()
                            }
                            .foregroundColor(.accentColor)
                            
                            Spacer()
                            
                            Button("Cancel") {
                                homepageText = settings.homepage
                            }
                            .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("General")
                } footer: {
                    Text("New tabs will open to this page. Default: Qwant")
                        .font(.caption)
                }
                
                // Engine Section
                Section {
                    Picker("Rendering Engine", selection: $settings.browserEngine) {
ForEach(BrowserEngine.allCases, id: \.self) { engine in
                            Text(engine.displayName).tag(engine)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    if settings.browserEngine == .blink {
                        HStack {
                            Image(systemName: "info.circle")
                            Text("Chrome mode: Enhanced compatibility")
                                .font(.caption)
                        }
                        .foregroundColor(.blue)
                    }
                } header: {
                    Text("Browser Engine")
                } footer: {
                    Text("Choose between Safari mode (WebKit) or Chrome mode (enhanced WebKit with Chrome features)")
                        .font(.caption)
                }
                
                // Website Appearance Section
                Section {
                    Toggle("Request Desktop Website", isOn: $settings.useDesktopMode)
                        .dynamicTypeSize(...DynamicTypeSize.accessibility3)
                    
                    Text(currentModeDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .dynamicTypeSize(...DynamicTypeSize.accessibility3)
                } header: {
                    Text("Website Appearance")
                } footer: {
                    Text("When enabled, websites will display their desktop version. When disabled, websites will display their mobile version.")
                        .font(.caption)
                        .dynamicTypeSize(...DynamicTypeSize.accessibility3)
                }
                
                // User Interface Section (iPhone only)
                Section {
                    Toggle("Auto-hide URL Bar", isOn: $settings.autoHideURLBar)
                        .dynamicTypeSize(...DynamicTypeSize.accessibility3)
                } header: {
                    Text("User Interface")
                } footer: {
                    Text("Auto-hide hides the URL bar when scrolling down. Navigation buttons can be hidden to save space with large text sizes.")
                        .font(.caption)
                        .dynamicTypeSize(...DynamicTypeSize.accessibility3)
                }
                
                // Sidebar & Layout Section (iPad & macOS only)
                #if !os(iOS) || targetEnvironment(macCatalyst)
                Section {
                    Picker("Sidebar Position", selection: $uiViewModel.sidebarPosition) {
                        Text("Left").tag("left")
                        Text("Right").tag("right")
                    }
                    .pickerStyle(.segmented)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Sidebar Width")
                            Spacer()
                            Text("\(Int(uiViewModel.sidebarWidth))")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                        Slider(value: $uiViewModel.sidebarWidth, in: 200...400, step: 10)
                    }
                    
                    Toggle("Auto-hide Sidebar", isOn: $uiViewModel.autoHideSidebar)
                        .dynamicTypeSize(...DynamicTypeSize.accessibility3)
                    
                    // iPad-specific: Navigation button position when sidebar is hidden
                    if UIDevice.current.userInterfaceIdiom == .pad {
                        Divider()
                            .padding(.vertical, 8)
                        
                        Toggle("Hide navigation buttons when sidebar is hidden", isOn: $settings.hideNavigationButtonsOnIPad)
                            .dynamicTypeSize(...DynamicTypeSize.accessibility3)
                        
                        if !settings.hideNavigationButtonsOnIPad {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Navigation Buttons Position")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                Text("When sidebar is hidden")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Picker("Navigation Buttons", selection: $settings.navigationButtonPosition) {
                                    ForEach(NavigationButtonPosition.allCases) { position in
                                        Text(position.displayName).tag(position)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }
                        }
                    }
                } header: {
                    Text("Sidebar & Layout")
                } footer: {
                    if UIDevice.current.userInterfaceIdiom == .pad {
                        Text("Configure the sidebar position, width, and auto-hide behavior. The sidebar shows tabs, groups, and navigation. When sidebar is hidden, back/forward navigation buttons appear at your chosen corner position.")
                            .font(.caption)
                            .dynamicTypeSize(...DynamicTypeSize.accessibility3)
                    } else {
                        Text("Configure the sidebar position, width, and auto-hide behavior. The sidebar shows tabs, groups, and navigation. Auto-hide reveals sidebar on hover.")
                            .font(.caption)
                            .dynamicTypeSize(...DynamicTypeSize.accessibility3)
                    }
                }
                #endif
                
                // Tab Management Section
                Section {
                    Toggle("Confirm before closing pinned tabs", isOn: $settings.confirmClosingPinnedTabs)
                        .dynamicTypeSize(...DynamicTypeSize.accessibility3)
                    Toggle("Persist tab groups across launches", isOn: $settings.persistTabGroups)
                        .dynamicTypeSize(...DynamicTypeSize.accessibility3)
                    
                    if let tabManager = tabManager, !tabManager.tabGroups.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Manage Tab Groups")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .padding(.top, 8)
                            
                            ForEach(tabManager.tabGroups) { group in
                                HStack {
                                    Circle()
                                        .fill(group.color.color)
                                        .frame(width: 12, height: 12)
                                    
                                    Text(group.name)
                                        .font(.system(size: 15))
                                        .dynamicTypeSize(...DynamicTypeSize.accessibility3)
                                    
                                    let tabCount = tabManager.getTabsInGroup(group).count
                                    Text("(\(tabCount) \(tabCount == 1 ? "tab" : "tabs"))")
                                        .font(.system(size: 13))
                                        .foregroundColor(.secondary)
                                        .dynamicTypeSize(...DynamicTypeSize.accessibility3)
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        tabManager.deleteTabGroup(group, moveTabsToNoGroup: true)
                                    }) {
                                        Image(systemName: "trash")
                                            .font(.system(size: 14))
                                            .foregroundColor(.red)
                                            .frame(width: 44, height: 44)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                } header: {
                    Text("Tab Management")
                } footer: {
                    Text("Pinned tab confirmation prevents accidental unpinning. Tab group persistence saves your groups between app launches. Delete groups to clean up organization - tabs will be kept.")
                        .font(.caption)
                        .dynamicTypeSize(...DynamicTypeSize.accessibility3)
                }
                
                // Search Section
                Section {
                    // Private engines
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Private search engines")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
ForEach([SearchEngine.qwant, .startpage, .presearch, .duckduckgo, .ecosia], id: \.self) { engine in
                            Button(action: { settings.defaultSearchEngine = engine }) {
                                HStack {
                                    Text(engine.displayName)
                                    Spacer()
                                    Image(systemName: settings.defaultSearchEngine == engine ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(settings.defaultSearchEngine == engine ? .accentColor : .secondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    // Less private engines
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Text("Popular (less private)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.yellow)
                        }
ForEach([SearchEngine.perplexity, .google, .bing, .yahoo], id: \.self) { engine in
                            Button(action: { settings.defaultSearchEngine = engine }) {
                                HStack {
                                    Text(engine.displayName)
                                    Spacer()
                                    Image(systemName: settings.defaultSearchEngine == engine ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(settings.defaultSearchEngine == engine ? .accentColor : .secondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    // Custom search engine
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Custom")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Button(action: { settings.defaultSearchEngine = .custom }) {
                            HStack {
                                Text(SearchEngine.custom.displayName)
                                Spacer()
                                Image(systemName: settings.defaultSearchEngine == .custom ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(settings.defaultSearchEngine == .custom ? .accentColor : .secondary)
                            }
                        }
                        .buttonStyle(.plain)
                        
                        if settings.defaultSearchEngine == .custom {
                            VStack(alignment: .leading, spacing: 6) {
                                TextField("Template (use {query})", text: $settings.customSearchTemplate)
                                    .textFieldStyle(.roundedBorder)
                                    .autocorrectionDisabled(true)
                                    .textInputAutocapitalization(.never)
                                
                                if let err = settings.customSearchTemplateErrorMessage {
                                    Text(err)
                                        .font(.caption)
                                        .foregroundColor(.red)
                                } else if let example = settings.exampleCustomSearchURL() {
                                    Text("Example: \(example.absoluteString)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.top, 4)
                        }
                    }
                } header: {
                    Text("Search Engine")
                } footer: {
                    Text("Choose your default search engine. Private engines don't track your search history. For custom engines, use {query} as placeholder for search terms.")
                        .font(.caption)
                }
                
                // Ad Blocking Section
                Section {
                    Toggle("Enable Ad Blocking", isOn: $settings.adBlockEnabled)
                    
                    // Advanced JS ad blocking toggle with warning
                    Toggle("Block advanced JS-injected ads", isOn: Binding(
                        get: { settings.adBlockAdvancedJS },
                        set: { newValue in
                            settings.adBlockAdvancedJS = newValue
                            if newValue {
                                // Advanced mode implies class obfuscation; disable separate toggle
                                settings.adBlockObfuscatedClass = false
                                showAdvancedJSAdblockWarning = true
                            }
                        }
                    ))
                    .tint(.red)
                    
                    // Aggressive obfuscated class blocking
                    Toggle("Block elements with obfuscated class names", isOn: $settings.adBlockObfuscatedClass)
                        .tint(.red)
                        .disabled(settings.adBlockAdvancedJS)
                        .help(settings.adBlockAdvancedJS ? "Included with Advanced blocking" : "Hides elements whose class names look auto-generated (e.g., 'gbqfwaabe'). May over-block on some sites.")
                    
                    // Cookie consent blocking
                    Toggle("Block cookie consent banners", isOn: $settings.adBlockCookieBanners)
                        .tint(.red)
                        .help("Hides cookie consent popups, overlays, and banners. May hide legitimate site notices.")
                    
                    if settings.adBlockEnabled {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Subscription Lists")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.top, 4)
                            
                            ForEach(AdBlockManager.Subscription.allCases, id: \.self) { subscription in
                                Toggle(subscription.displayName, isOn: Binding(
                                    get: { settings.selectedAdBlockLists.contains(subscription.rawValue) },
                                    set: { isEnabled in
                                        if isEnabled {
                                            settings.selectedAdBlockLists.append(subscription.rawValue)
                                        } else {
                                            settings.selectedAdBlockLists.removeAll(where: { $0 == subscription.rawValue })
                                        }
                                    }
                                ))
                                .font(.subheadline)
                                .padding(.vertical, 4)
                            }
                            
                            HStack {
                                HStack(spacing: 6) {
                                Image(systemName: adBlockManager.isUpdating ? "arrow.triangle.2.circlepath" : "checkmark.shield")
                                    .foregroundColor(.green)
                                Text("Rules: \(adBlockManager.activeRuleCount)  Updated: \(adBlockManager.lastUpdated?.formatted(date: .abbreviated, time: .shortened) ?? "never")")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                }
                                
                                Spacer()
                                
                                if !adBlockManager.isUpdating {
                                    Button(action: { Task { await adBlockManager.updateSubscriptions(force: true) } }) {
                                        Label("Update", systemImage: "arrow.clockwise")
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                    }
                                    .foregroundColor(.accentColor)
                                }
                            }
                            .padding(.vertical, 2)
                            
                            Toggle("Update lists on launch", isOn: $settings.adBlockAutoUpdateOnLaunch)
                                .font(.caption)
                                .padding(.top, 4)
                        }
                    }
                } header: {
                    Text("Ad Blocking")
                } footer: {
                    Text("Block ads, trackers, and other unwanted content. Different lists target different types of content.")
                        .font(.caption)
                }
                
                // Downloads Section
                Section {
                    Toggle("Enable Downloads", isOn: $settings.downloadsEnabled)
                    
                    if settings.downloadsEnabled {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Downloads enabled - you will be asked to confirm each download")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    } else {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("Downloads are disabled - enable to save files from websites")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                    
                    Divider()
                    
                    DownloadSettingsView()
                } header: {
                    Text("Downloads")
                } footer: {
                    Text("Downloads are disabled by default for App Store compliance. When enabled, you will be asked to confirm each download individually (similar to Safari). Toggle on to enable file downloads from websites.")
                        .font(.caption)
                }
                
                // Perplexity Section
                Section {
                    Toggle("Enable Perplexity Features", isOn: $perplexityManager.isEnabled)
                    
                    if perplexityManager.isEnabled {
                        if perplexityManager.isAuthenticated {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Signed in to Perplexity")
                                    .foregroundColor(.green)
                            }
                            
                            Button("Sign Out") {
                                perplexityManager.signOut()
                            }
                            .foregroundColor(.red)
                        } else {
                            Button("Sign in to Perplexity") {
                                if let tabManager = tabManager {
                                    dismiss()
                                    tabManager.createNewTab(url: perplexityManager.loginURL)
                                }
                            }
                            .foregroundColor(.accentColor)
                        }
                    }
                } header: {
                    Text("Perplexity Integration")
                } footer: {
                    Text("Perplexity integration allows you to quickly summarize web pages or send URLs to Perplexity for AI-powered analysis. Sign in to your Perplexity account to enable these features via right-click context menus or the browser toolbar.")
                        .font(.caption)
                }
                
                // Default Browser (iOS only)
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Button(action: openAppSettings) {
                            Label("Set as Default Browser", systemImage: "checkmark.seal")
                                .foregroundColor(.accentColor)
                        }
                        Text("Opens iOS Settings for EvoArc so you can choose it as the Default Browser App.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Default Browser")
                }
                
                // About Section
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Default Settings by Device:")
                            .font(.caption)
                            .fontWeight(.semibold)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: "iphone")
                                    .frame(width: 20)
                                Text("iPhone: Mobile websites")
                            }
                            .font(.caption)
                            
                            HStack {
                                Image(systemName: "ipad")
                                    .frame(width: 20)
                                Text("iPad: Desktop websites")
                            }
                            .font(.caption)
                            
                            HStack {
                                Image(systemName: "desktopcomputer")
                                    .frame(width: 20)
                                Text("Mac: Desktop websites")
                            }
                            .font(.caption)
                        }
                        .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("About")
                }
    }
    
    private var currentModeDescription: String {
        if let device = UIDevice.current.userInterfaceIdiom.deviceDescription {
            return "Your \(device) will \(settings.useDesktopMode ? "always" : "never") request desktop websites by default."
        }
        return ""
    }
    
    private func saveHomepage() {
        settings.homepage = homepageText
    }
    
    private func openAppSettings() {
        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsURL)
        }
    }
}

private extension UIUserInterfaceIdiom {
    var deviceDescription: String? {
        switch self {
        case .phone: return "iPhone"
        case .pad: return "iPad"
        default: return nil
        }
    }
}