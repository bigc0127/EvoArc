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
            .navigationTitle("settings".localized)
            .navigationBarTitleDisplayMode(.inline)
            .alert("advanced_blocking_warning_title".localized, isPresented: $showAdvancedJSAdblockWarning) {
                Button("ok".localized, role: .cancel) { }
            } message: {
                Text("advanced_blocking_warning_message".localized)
            }
            .toolbar {
                ToolbarItem(placement: toolbarPlacement) {
                    Button("done".localized) {
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
                        Text("homepage".localized)
                        Spacer()
                        TextField("enter_url".localized, text: $homepageText)
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
                            Button("save".localized) {
                                saveHomepage()
                            }
                            .foregroundColor(.accentColor)
                            
                            Spacer()
                            
                            Button("cancel".localized) {
                                homepageText = settings.homepage
                            }
                            .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("general".localized)
                } footer: {
                    Text("new_tabs_open_description".localized)
                        .font(.caption)
                }
                
                // Engine Section
                Section {
                    Picker("rendering_engine".localized, selection: $settings.browserEngine) {
ForEach(BrowserEngine.allCases, id: \.self) { engine in
                            Text(engine.displayName).tag(engine)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    if settings.browserEngine == .blink {
                        HStack {
                            Image(systemName: "info.circle")
                            Text("chrome_mode_info".localized)
                                .font(.caption)
                        }
                        .foregroundColor(.blue)
                    }
                } header: {
                    Text("browser_engine".localized)
                } footer: {
                    Text("browser_engine_description".localized)
                        .font(.caption)
                }
                
                // Website Appearance Section
                Section {
                    Toggle("request_desktop_website".localized, isOn: $settings.useDesktopMode)
                        .dynamicTypeSize(...DynamicTypeSize.accessibility3)
                    
                    Text(currentModeDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .dynamicTypeSize(...DynamicTypeSize.accessibility3)
                } header: {
                    Text("website_appearance".localized)
                } footer: {
                    Text("desktop_mobile_description".localized)
                        .font(.caption)
                        .dynamicTypeSize(...DynamicTypeSize.accessibility3)
                }
                
                // User Interface Section (iPhone only)
                Section {
                    Toggle("auto_hide_url_bar".localized, isOn: $settings.autoHideURLBar)
                        .dynamicTypeSize(...DynamicTypeSize.accessibility3)
                } header: {
                    Text("user_interface".localized)
                } footer: {
                    Text("auto_hide_description".localized)
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
                    Toggle("confirm_before_closing_pinned_tabs".localized, isOn: $settings.confirmClosingPinnedTabs)
                        .dynamicTypeSize(...DynamicTypeSize.accessibility3)
                    Toggle("persist_pinned_tabs_across_launches".localized, isOn: $settings.persistPinnedTabs)
                        .dynamicTypeSize(...DynamicTypeSize.accessibility3)
                    Toggle("persist_tab_groups_across_launches".localized, isOn: $settings.persistTabGroups)
                        .dynamicTypeSize(...DynamicTypeSize.accessibility3)
                    
                    if let tabManager = tabManager, !tabManager.tabGroups.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("manage_tab_groups".localized)
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
                                    Text("(\(tabCount) \(tabCount == 1 ? "tab".localized : "tabs".localized))")
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
                    Text("tab_management".localized)
                } footer: {
                    Text("tab_management_description".localized)
                        .font(.caption)
                        .dynamicTypeSize(...DynamicTypeSize.accessibility3)
                }
                
                // Search Section
                Section {
                    // Private engines
                    VStack(alignment: .leading, spacing: 6) {
                        Text("private_search_engines".localized)
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
                            Text("popular_less_private".localized)
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
                        Text("custom".localized)
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
                                TextField("template_use_query".localized, text: $settings.customSearchTemplate)
                                    .textFieldStyle(.roundedBorder)
                                    .autocorrectionDisabled(true)
                                    .textInputAutocapitalization(.never)
                                
                                if let err = settings.customSearchTemplateErrorMessage {
                                    Text(err)
                                        .font(.caption)
                                        .foregroundColor(.red)
                                } else if let example = settings.exampleCustomSearchURL() {
                                    Text("\("example".localized): \(example.absoluteString)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.top, 4)
                        }
                    }
                } header: {
                    Text("search_engine".localized)
                } footer: {
                    Text("search_engine_description".localized)
                        .font(.caption)
                }
                
                // Ad Blocking Section
                Section {
                    Toggle("enable_ad_blocking".localized, isOn: $settings.adBlockEnabled)
                    
                    // Advanced JS ad blocking toggle with warning
                    Toggle("block_advanced_js_ads".localized, isOn: Binding(
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
                    Toggle("block_obfuscated_class_names".localized, isOn: $settings.adBlockObfuscatedClass)
                        .tint(.red)
                        .disabled(settings.adBlockAdvancedJS)
                        .help(settings.adBlockAdvancedJS ? "Included with Advanced blocking" : "Hides elements whose class names look auto-generated (e.g., 'gbqfwaabe'). May over-block on some sites.")
                    
                    // Cookie consent blocking
                    Toggle("block_cookie_consent_banners".localized, isOn: $settings.adBlockCookieBanners)
                        .tint(.red)
                        .help("Hides cookie consent popups, overlays, and banners. May hide legitimate site notices.")
                    
                    if settings.adBlockEnabled {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("subscription_lists".localized)
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
                                Text("\("rules".localized): \(adBlockManager.activeRuleCount)  \("updated".localized): \(adBlockManager.lastUpdated?.formatted(date: .abbreviated, time: .shortened) ?? "never".localized)")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                }
                                
                                Spacer()
                                
                                if !adBlockManager.isUpdating {
                                    Button(action: { Task { await adBlockManager.updateSubscriptions(force: true) } }) {
                                        Label("update".localized, systemImage: "arrow.clockwise")
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                    }
                                    .foregroundColor(.accentColor)
                                }
                            }
                            .padding(.vertical, 2)
                            
                            Toggle("update_lists_on_launch".localized, isOn: $settings.adBlockAutoUpdateOnLaunch)
                                .font(.caption)
                                .padding(.top, 4)
                        }
                    }
                } header: {
                    Text("ad_blocking".localized)
                } footer: {
                    Text("ad_blocking_description".localized)
                        .font(.caption)
                }
                
                // Downloads Section
                Section {
                    Toggle("enable_downloads".localized, isOn: $settings.downloadsEnabled)
                    
                    if settings.downloadsEnabled {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("downloads_enabled_message".localized)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    } else {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("downloads_disabled_message".localized)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                    
                    Divider()
                    
                    DownloadSettingsView()
                } header: {
                    Text("downloads".localized)
                } footer: {
                    Text("downloads_description".localized)
                        .font(.caption)
                }
                
                // Perplexity Section
                Section {
                    Toggle("enable_perplexity_features".localized, isOn: $perplexityManager.isEnabled)
                    
                    if perplexityManager.isEnabled {
                        if perplexityManager.isAuthenticated {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("signed_in_to_perplexity".localized)
                                    .foregroundColor(.green)
                            }
                            
                            Button("sign_out".localized) {
                                perplexityManager.signOut()
                            }
                            .foregroundColor(.red)
                        } else {
                            Button("sign_in_to_perplexity".localized) {
                                if let tabManager = tabManager {
                                    dismiss()
                                    tabManager.createNewTab(url: perplexityManager.loginURL)
                                }
                            }
                            .foregroundColor(.accentColor)
                        }
                    }
                } header: {
                    Text("perplexity_integration".localized)
                } footer: {
                    Text("perplexity_integration_description".localized)
                        .font(.caption)
                }
                
                // Default Browser (iOS only) - Hidden until Apple approves entitlement
                // Uncomment this section once Apple has approved the default browser entitlement
                /*
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
                */
                
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