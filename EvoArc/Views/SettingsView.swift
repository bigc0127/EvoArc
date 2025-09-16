//
//  SettingsView.swift
//  EvoArc
//
//  Created on 2025-09-04.
//

/**
 * # SettingsView
 * 
 * The main settings interface for EvoArc browser, providing configuration options for
 * browsing behavior, search engines, browser appearance, and integrations.
 * 
 * ## Architecture Overview
 * 
 * ### For New Swift Developers:
 * - **@StateObject**: Creates and owns an ObservableObject instance within this view
 * - **@Environment(\.dismiss)**: Accesses the SwiftUI environment to dismiss the view
 * - **@State**: Local view state that triggers UI updates when changed
 * - **@ViewBuilder**: A function builder that constructs SwiftUI views conditionally
 * - **#if os()**: Compiler directives for platform-specific code
 * 
 * ### Key Components:
 * 1. **Platform Detection**: Automatically adapts UI layout for iOS vs macOS
 * 2. **Settings Binding**: Two-way data binding with BrowserSettings.shared
 * 3. **Form Validation**: Real-time validation for user inputs like homepage URLs
 * 4. **Integration Management**: Handles Perplexity AI integration setup
 * 
 * ## Settings Categories:
 * - **General**: Homepage configuration and basic browser settings
 * - **Website Appearance**: Desktop vs mobile site preferences
 * - **Browser Engine**: WebKit vs Blink rendering modes (macOS only)
 * - **Search Engines**: Default search provider selection with privacy focus
 * - **Pinned Tabs**: Tab persistence and sync options
 * - **Interface**: URL bar auto-hide behavior
 * - **Perplexity Integration**: AI-powered web analysis features
 * 
 * ## DNS Resolution:
 * This app now uses standard system DNS resolution. All custom DNS-over-HTTPS
 * (DOH) and ControlD integrations have been removed for simplicity.
 * 
 * ## Usage:
 * ```swift
 * .sheet(isPresented: $showingSettings) {
 *     SettingsView(tabManager: tabManager)
 * }
 * ```
 */

import SwiftUI
#if os(iOS)
import UIKit
#else
import AppKit
#endif

/// The main settings interface view for EvoArc browser configuration
struct SettingsView: View {
    /// Reference to the global browser settings singleton
    /// @StateObject ensures this view owns and observes the settings instance
    @StateObject private var settings = BrowserSettings.shared
    
    /// Reference to the Perplexity AI integration manager
    /// Handles authentication and API interaction for AI features
    @StateObject private var perplexityManager = PerplexityManager.shared
    
    /// Ad blocking manager
    @StateObject private var adBlockManager = AdBlockManager.shared
    
    /// SwiftUI environment value for dismissing this modal view
    /// Called when user taps "Done" or "Cancel" buttons
    @Environment(\.dismiss) private var dismiss
    
    /// Local state for the homepage text field to enable real-time validation
    /// Separate from settings.homepage to allow editing without immediate saves
    @State private var homepageText: String = ""
    
    /// Optional reference to the tab manager for creating new tabs
    /// Used when user clicks links within settings (like Perplexity sign-in)
    var tabManager: TabManager?
    
    private var toolbarPlacement: ToolbarItemPlacement {
        #if os(iOS)
        .navigationBarTrailing
        #else
        .primaryAction
        #endif
    }
    
    var body: some View {
        #if os(macOS)
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Settings")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // Settings content in a scrollable view
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    macOSSettingsContent
                }
                .padding(20)
            }
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(width: 600, height: 500)
        .task {
            homepageText = settings.homepage
        }
        #else
        NavigationView {
            Form {
                iOSSettingsContent
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
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
        #endif
    }
    
    @ViewBuilder
    private var macOSSettingsContent: some View {
        // General Section
        VStack(alignment: .leading, spacing: 12) {
            Text("General")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 8) {
                HStack {
                    Text("Homepage:")
                        .frame(width: 100, alignment: .leading)
                    
                    TextField("Enter URL", text: $homepageText)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled(true)
                        .onSubmit {
                            saveHomepage()
                        }
                    
                    if homepageText != settings.homepage {
                        Button("Save") {
                            saveHomepage()
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button("Cancel") {
                            homepageText = settings.homepage
                        }
                        .buttonStyle(.bordered)
                    }
                }
                
                Text("New tabs will open to this page. Default: Qwant")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 100)
            }
        }
        .padding(.vertical, 8)
        
        Divider()
        
        // Website Appearance Section
        VStack(alignment: .leading, spacing: 12) {
            Text("Website Appearance")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 8) {
                HStack {
                    Toggle("Request Desktop Website", isOn: $settings.useDesktopMode)
                    Spacer()
                }
                
                Text(currentModeDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("When enabled, websites will display their desktop version. When disabled, websites will display their mobile version.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
        
        Divider()
        
        // Browser Engine Section (macOS only)
        VStack(alignment: .leading, spacing: 12) {
            Text("Browser Engine")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 8) {
                HStack {
                    Text("Rendering Engine:")
                        .frame(width: 150, alignment: .leading)
                    
                    Picker("Engine", selection: $settings.browserEngine) {
                        ForEach(BrowserEngine.allCases, id: \.self) { engine in
                            Text(engine.displayName).tag(engine)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 300)
                    
                    Spacer()
                }
                
                Text("Choose between WebKit (Safari mode) or Blink (Chrome mode). Both use WebKit but with different configurations.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if settings.browserEngine == .blink {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                        Text("Chrome mode: Enhanced compatibility with Chrome user agent and JavaScript APIs.")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    .padding(.top, 4)
                }
            }
        }
        .padding(.vertical, 8)
        
        Divider()
        
        // Pinned Tabs Section
        VStack(alignment: .leading, spacing: 12) {
            Text("Pinned Tabs Sync")
                .font(.headline)
                .foregroundColor(.primary)
            
            PinnedTabDebugView(tabManager: tabManager)
        }
        .padding(.vertical, 8)
        
        Divider()
        
        // Tab Management Section
        VStack(alignment: .leading, spacing: 12) {
            Text("Tab Management")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 8) {
                HStack {
                    Toggle("Confirm before closing pinned tabs", isOn: $settings.confirmClosingPinnedTabs)
                    Spacer()
                }
                
                Text("Show confirmation dialog when unpinning or closing pinned tabs to prevent accidental loss.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    Toggle("Persist tab groups across launches", isOn: $settings.persistTabGroups)
                    Spacer()
                }
                
                Text("Save tab groups and restore them when the app launches. When disabled, tab groups are temporary and lost when the app closes.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    Toggle("Hide empty tab groups", isOn: $settings.hideEmptyTabGroups)
                    Spacer()
                }
                
                Text("Hide tab groups that contain no tabs from the tab drawer and sidebar. When disabled, empty groups remain visible.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // Tab Groups Management
                if let tabManager = tabManager, !tabManager.tabGroups.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Manage Tab Groups")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Spacer()
                        }
                        
                        ForEach(tabManager.tabGroups) { group in
                            HStack {
                                Circle()
                                    .fill(group.color.color)
                                    .frame(width: 12, height: 12)
                                
                                Text(group.name)
                                    .font(.system(size: 13))
                                
                                let tabCount = tabManager.getTabsInGroup(group).count
                                Text("(\(tabCount) \(tabCount == 1 ? "tab" : "tabs"))")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Button(action: {
                                    tabManager.deleteTabGroup(group, moveTabsToNoGroup: true)
                                }) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 12))
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .help("Delete group (keeps tabs)")
                            }
                            .padding(.vertical, 2)
                        }
                        
                        Text("Delete groups to clean up your organization. Tabs will be moved to 'Other Tabs' section.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 8)
                }
            }
        }
        .padding(.vertical, 8)
        
        Divider()
        
        // User Interface Section
        VStack(alignment: .leading, spacing: 12) {
            Text("User Interface")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 8) {
                HStack {
                    Toggle("Auto-hide URL Bar", isOn: $settings.autoHideURLBar)
                    Spacer()
                }
                
                #if os(macOS)
                HStack {
                    Text("Tab Drawer Position:")
                        .frame(width: 150, alignment: .leading)
                    
                    Picker("Position", selection: $settings.tabDrawerPosition) {
                        ForEach(TabDrawerPosition.allCases, id: \.self) { position in
                            Text(position.displayName).tag(position)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 150)
                    
                    Spacer()
                }
                #endif
                
                #if os(macOS)
                Text("Auto-hide hides the URL bar when scrolling down. Tab drawer position can be set to left or right side.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                #else
                Text("Auto-hide hides the URL bar when scrolling down and shows it when scrolling up or touching the bottom.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                #endif
            }
        }
        .padding(.vertical, 8)
        
        Divider()
        
        // Ad Blocking Section
        VStack(alignment: .leading, spacing: 12) {
            Text("Ad Blocking")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 8) {
                HStack {
                    Toggle("Enable Ad Blocking", isOn: $settings.adBlockEnabled)
                    Spacer()
                }
                
                if settings.adBlockEnabled {
                    VStack(alignment: .leading, spacing: 12) {
                        // Status indicator
                        HStack(spacing: 8) {
                            Image(systemName: adBlockManager.isUpdating ? "arrow.triangle.2.circlepath" : "checkmark.shield")
                                .foregroundColor(.green)
                            Text("Rules: \(adBlockManager.activeRuleCount)  Updated: \(adBlockManager.lastUpdated?.formatted(date: .abbreviated, time: .shortened) ?? "never")")
                                .font(.caption)
                                .fontWeight(.semibold)
                            Spacer()
                            Button("Update Now") { Task { await adBlockManager.updateSubscriptions(force: true) } }
                                .buttonStyle(.bordered)
                        }
                        
                        Toggle("Update lists on launch", isOn: $settings.adBlockAutoUpdateOnLaunch)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Toggle("Block JS-inserted ads (scriptlet)", isOn: $settings.adBlockScriptletEnabled)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Subscriptions:")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            
                            // Subscription selection buttons
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(AdBlockList.allCases, id: \.self) { list in
                                    Button(action: {
                                        var current = Set(settings.selectedAdBlockLists)
                                        if current.contains(list.rawValue) {
                                            current.remove(list.rawValue)
                                        } else {
                                            current.insert(list.rawValue)
                                        }
                                        settings.selectedAdBlockLists = Array(current)
                                    }) {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(list.displayName)
                                                    .font(.system(size: 13))
                                                Text(list.description)
                                                    .font(.system(size: 11))
                                                    .foregroundColor(.secondary)
                                            }
                                            Spacer()
                                            let selected = Set(settings.selectedAdBlockLists).contains(list.rawValue)
                                            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                                                .foregroundColor(selected ? .accentColor : .secondary)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        
                        // Custom list URLs (GitHub raw, etc.)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Custom Lists (one URL per line)")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .padding(.top, 10)
                            
                            TextEditor(text: Binding(
                                get: { settings.customAdBlockListURLs.joined(separator: "\n") },
                                set: { settings.customAdBlockListURLs = $0.split(separator: "\n").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty } }
                            ))
                            .frame(minHeight: 80)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.25)))
                            .font(.system(size: 12))
                            
                            Text("Paste URLs to EasyList/uBlock compatible lists (one per line). GitHub raw URLs work well.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 8)
        
        Divider()
        
        // History Section
        VStack(alignment: .leading, spacing: 12) {
            Text("Browsing History")
                .font(.headline)
                .foregroundColor(.primary)
            
            HistorySettingsView(tabManager: tabManager)
        }
        .padding(.vertical, 8)
        
        Divider()
        
        // Perplexity Section
        VStack(alignment: .leading, spacing: 12) {
            Text("Search")
                .font(.headline)
                .foregroundColor(.primary)
            
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
            .padding(.top, 4)
            
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
                Text("These engines may track searches. Consider a private engine above.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 10)
            
            // Custom engine
            VStack(alignment: .leading, spacing: 6) {
                Button(action: { settings.defaultSearchEngine = .custom }) {
                    HStack {
                        Text("Custom search engine")
                        Spacer()
                        Image(systemName: settings.defaultSearchEngine == .custom ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(settings.defaultSearchEngine == .custom ? .accentColor : .secondary)
                    }
                }
                .buttonStyle(.plain)
                
                if settings.defaultSearchEngine == .custom {
                    HStack(alignment: .top) {
                        Text("Template:")
                            .frame(width: 80, alignment: .leading)
                        TextField("https://example.com/search?q={query}", text: $settings.customSearchTemplate)
                            .textFieldStyle(.roundedBorder)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(settings.isCustomSearchTemplateValid ? Color.clear : Color.red, lineWidth: 1)
                            )
                    }
                    if let error = settings.customSearchTemplateErrorMessage {
                        HStack(spacing: 6) {
                            Image(systemName: "xmark.octagon.fill").foregroundColor(.red)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    } else if let example = settings.exampleCustomSearchURL() {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                            Text("Example: \(example.absoluteString)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    Text("Use {query} as a placeholder for the search term. Example: https://example.com/search?q={query}")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.top, 10)
            
            // Redirect toggle
            Toggle("Redirect external searches to default engine", isOn: $settings.redirectExternalSearches)
                .padding(.top, 10)
            
            Text("When enabled, URLs from Google, Bing, DuckDuckGo, etc. opened from outside EvoArc will be redirected here using your default search engine.")
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Search preloading toggle
            Toggle("Enable search result preloading", isOn: $settings.searchPreloadingEnabled)
                .padding(.top, 10)
            
            Text("When enabled, search results and first links are preloaded as you type to improve performance. Disable to reduce network usage.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
        
        // Perplexity Section
        VStack(alignment: .leading, spacing: 12) {
            Text("Perplexity Integration")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 8) {
                HStack {
                    Toggle("Enable Perplexity Features", isOn: $perplexityManager.isEnabled)
                    Spacer()
                }
                
                if perplexityManager.isEnabled {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            if perplexityManager.isAuthenticated {
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text("Signed in to Perplexity")
                                        .foregroundColor(.green)
                                }
                                
                                Spacer()
                                
                                Button("Sign Out") {
                                    perplexityManager.signOut()
                                }
                                .buttonStyle(.bordered)
                            } else {
                                VStack(alignment: .leading, spacing: 8) {
                                    Button("Sign in to Perplexity") {
                                        if let tabManager = tabManager {
                                            dismiss()
                                            tabManager.createNewTab(url: perplexityManager.loginURL)
                                        }
                                    }
                                    .buttonStyle(.borderedProminent)
                                    
                                    Button("Check Login Status") {
                                        perplexityManager.refreshAuthenticationStatus()
                                    }
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                            }
                        }
                        
                        Text("Perplexity integration allows you to quickly summarize web pages or send URLs to Perplexity for AI-powered analysis. Sign in to your Perplexity account to enable these features via right-click context menus or the browser toolbar.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 8)
        
        Divider()
        
        // About Section
        VStack(alignment: .leading, spacing: 12) {
            Text("About")
                .font(.headline)
                .foregroundColor(.primary)
            
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
        }
        .padding(.vertical, 8)
    }
    
    @ViewBuilder
    private var iOSSettingsContent: some View {
        Section {
            HStack {
                Text("Homepage")
                Spacer()
                TextField("Enter URL", text: $homepageText)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled(true)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
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
        
        Section {
            Toggle("Request Desktop Website", isOn: $settings.useDesktopMode)
            
            Text(currentModeDescription)
                .font(.caption)
                .foregroundColor(.secondary)
        } header: {
            Text("Website Appearance")
        } footer: {
            Text("When enabled, websites will display their desktop version. When disabled, websites will display their mobile version.")
                .font(.caption)
        }
        
        Section {
            Toggle("Auto-hide URL Bar", isOn: $settings.autoHideURLBar)
        } header: {
            Text("User Interface")
        } footer: {
            Text("Auto-hide hides the URL bar when scrolling down and shows it when scrolling up or touching the bottom.")
                .font(.caption)
        }
        
        Section {
            Toggle("Confirm before closing pinned tabs", isOn: $settings.confirmClosingPinnedTabs)
            Toggle("Persist tab groups across launches", isOn: $settings.persistTabGroups)
            
            // Tab Groups Management
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
                            
                            let tabCount = tabManager.getTabsInGroup(group).count
                            Text("(\(tabCount) \(tabCount == 1 ? "tab" : "tabs"))")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Button(action: {
                                tabManager.deleteTabGroup(group, moveTabsToNoGroup: true)
                            }) {
                                Image(systemName: "trash")
                                    .font(.system(size: 14))
                                    .foregroundColor(.red)
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
        }
        
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
                Text("These engines may track searches. Consider a private engine above.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Custom engine
            VStack(alignment: .leading, spacing: 6) {
                Button(action: { settings.defaultSearchEngine = .custom }) {
                    HStack {
                        Text("Custom search engine")
                        Spacer()
                        Image(systemName: settings.defaultSearchEngine == .custom ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(settings.defaultSearchEngine == .custom ? .accentColor : .secondary)
                    }
                }
                .buttonStyle(.plain)
                
                if settings.defaultSearchEngine == .custom {
                    TextField("https://example.com/search?q={query}", text: $settings.customSearchTemplate)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled(true)
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(settings.isCustomSearchTemplateValid ? Color.clear : Color.red, lineWidth: 1)
                        )
                    if let error = settings.customSearchTemplateErrorMessage {
                        HStack(spacing: 6) {
                            Image(systemName: "xmark.octagon.fill").foregroundColor(.red)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    } else if let example = settings.exampleCustomSearchURL() {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                            Text("Example: \(example.absoluteString)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    Text("Use {query} as a placeholder for the search term. Example: https://example.com/search?q={query}")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Redirect toggle
            Toggle("Redirect external searches to default engine", isOn: $settings.redirectExternalSearches)
            
            Text("When enabled, URLs from Google, Bing, DuckDuckGo, etc. opened from outside EvoArc will be redirected here using your default search engine.")
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Search preloading toggle
            Toggle("Enable search result preloading", isOn: $settings.searchPreloadingEnabled)
            
            Text("Preloads search results as you type to improve performance. May increase network usage and send partial queries to your search engine.")
                .font(.caption)
                .foregroundColor(.secondary)
        } header: {
            Text("Search")
        }
        
        // History Section (iOS)
        Section {
            HistorySettingsView(tabManager: tabManager)
        } header: {
            Text("Browsing History")
        } footer: {
            Text("Manage your browsing history and clear data as needed. All history data is stored locally on your device.")
                .font(.caption)
        }
        
        // Perplexity Section (iOS)
        Section {
            Toggle("Enable Ad Blocking", isOn: $settings.adBlockEnabled)
            
            if settings.adBlockEnabled {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Subscriptions")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .padding(.top, 8)
                    
                    // Subscription selection
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(AdBlockList.allCases, id: \.self) { list in
                            Button(action: {
                                var current = Set(settings.selectedAdBlockLists)
                                if current.contains(list.rawValue) { current.remove(list.rawValue) } else { current.insert(list.rawValue) }
                                settings.selectedAdBlockLists = Array(current)
                            }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                    Text(list.displayName)
                                        .font(.system(size: 15))
                                    Text(list.description)
                                        .font(.system(size: 13))
                                        .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                let selected = Set(settings.selectedAdBlockLists).contains(list.rawValue)
                                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(selected ? .accentColor : .secondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        
                        // Custom provider option (removed with DoH)
                        .buttonStyle(.plain)
                        
                    }
                }
                
                // Custom list URLs (GitHub raw, etc.)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Custom Lists (one URL per line)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    TextEditor(text: Binding(
                        get: { settings.customAdBlockListURLs.joined(separator: "\n") },
                        set: { settings.customAdBlockListURLs = $0.split(separator: "\n").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty } }
                    ))
                    .frame(minHeight: 80)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.25)))
                    
                    Toggle("Block JS-inserted ads (scriptlet)", isOn: $settings.adBlockScriptletEnabled)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Button(action: {
                            Task { await adBlockManager.updateSubscriptions(force: true) }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: adBlockManager.isUpdating ? "arrow.triangle.2.circlepath" : "arrow.down.circle")
                                Text(adBlockManager.isUpdating ? "Updating…" : "Update Now")
                            }
                        }
                        .disabled(adBlockManager.isUpdating)
                        
                        Spacer()
                        
                        Text("Rules: \(adBlockManager.activeRuleCount)  •  Updated: \(adBlockManager.lastUpdated?.formatted(date: .abbreviated, time: .shortened) ?? "never")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        } header: {
            Text("Ad Blocking")
        } footer: {
            if settings.adBlockEnabled {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: adBlockManager.isUpdating ? "arrow.triangle.2.circlepath" : "checkmark.shield")
                            .foregroundColor(.green)
                        Text("Rules: \(adBlockManager.activeRuleCount)  Updated: \(adBlockManager.lastUpdated?.formatted(date: .abbreviated, time: .shortened) ?? "never")")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    
                    Toggle("Update lists on launch", isOn: $settings.adBlockAutoUpdateOnLaunch)
                        .font(.caption)
                }
            }
        }
        
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
        #if os(iOS)
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
        #endif
        
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
    
    private func saveHomepage() {
        var urlToSave = homepageText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Add https:// if no scheme is present
        if !urlToSave.isEmpty && !urlToSave.contains("://") {
            urlToSave = "https://\(urlToSave)"
        }
        
        // Validate URL
        if URL(string: urlToSave) != nil || urlToSave.isEmpty {
            settings.homepage = urlToSave.isEmpty ? "https://www.google.com" : urlToSave
            homepageText = settings.homepage
        }
    }
    
    #if os(iOS)
    private func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString),
           UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }
    #endif
    
    private var currentModeDescription: String {
        let deviceType: String
        #if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .pad {
            deviceType = "iPad"
        } else {
            deviceType = "iPhone"
        }
        #else
        deviceType = "Mac"
        #endif
        
        return "Currently viewing \(settings.useDesktopMode ? "desktop" : "mobile") versions on \(deviceType)"
    }
}

#Preview {
    SettingsView()
}
