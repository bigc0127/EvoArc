//
//  SettingsView.swift
//  EvoArc
//
//  Created on 2025-09-04.
//

import SwiftUI
#if os(iOS)
import UIKit
#else
import AppKit
#endif

struct SettingsView: View {
    @StateObject private var settings = BrowserSettings.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showingControlDSetup = false
    @State private var homepageText: String = ""
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
        
        // Search Section
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
        }
        .padding(.vertical, 8)
        Divider()
        
        // Privacy & Security Section
        VStack(alignment: .leading, spacing: 12) {
            Text("Privacy & Security")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 8) {
                HStack {
                    Text("DNS Provider:")
                        .frame(width: 120, alignment: .leading)
                    Text("ControlD")
                        .foregroundColor(.secondary)
                    Spacer()
                }
                
                HStack {
                    Text("Protection from:")
                        .frame(width: 120, alignment: .leading)
                    Text("Malware, Phishing, & Ads")
                        .foregroundColor(.secondary)
                    Spacer()
                }
                
                HStack {
                    Text("Protocol:")
                        .frame(width: 120, alignment: .leading)
                    Text("DNS over HTTPS")
                        .foregroundColor(.secondary)
                    Spacer()
                }
                
                HStack {
                    Button(action: {
                        openControlDSetup()
                    }) {
                        Label("Setup DNS Protection", systemImage: "shield.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Spacer()
                }
                
                Text("To enable DNS over HTTPS system-wide, install the DNS profile. This will route all DNS queries through ControlD's free DNS service for enhanced privacy and malware protection.")
                    .font(.caption)
                    .foregroundColor(.secondary)
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
        } header: {
            Text("Search")
        }
        
        Section {
            HStack {
                Text("DNS Provider")
                Spacer()
                Text("ControlD")
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("Protection from")
                Spacer()
                Text("Malware, Phishing, & Ads")
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("Protocol")
                Spacer()
                Text("DNS over HTTPS")
                    .foregroundColor(.secondary)
            }
            
            Button(action: {
                openControlDSetup()
            }) {
                Label("Setup DNS Protection", systemImage: "shield.fill")
                    .foregroundColor(.accentColor)
            }
        } header: {
            Text("Privacy & Security")
        } footer: {
            Text("To enable DNS over HTTPS system-wide, install the DNS profile. This will route all DNS queries through ControlD's free DNS service for enhanced privacy and malware protection.")
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
            settings.homepage = urlToSave.isEmpty ? "https://www.qwant.com" : urlToSave
            homepageText = settings.homepage
        }
    }
    
    private func openControlDSetup() {
        guard let setupURL = URL(string: "https://controld.com/free-dns") else {
            print("Error: Invalid ControlD setup URL")
            return
        }
        
        #if os(iOS)
        // On iOS, prefer opening in app, fallback to Safari
        if let tabManager = tabManager {
            dismiss()
            tabManager.createNewTab(url: setupURL)
            print("Opening ControlD setup in new tab")
        } else {
            // Fallback: Open in Safari
            if UIApplication.shared.canOpenURL(setupURL) {
                UIApplication.shared.open(setupURL)
                print("Opening ControlD setup in Safari")
            } else {
                print("Error: Cannot open ControlD setup URL")
            }
        }
        #else
        // On macOS, prefer opening in app, fallback to default browser
        if let tabManager = tabManager {
            dismiss()
            tabManager.createNewTab(url: setupURL)
            print("Opening ControlD setup in new tab")
        } else {
            // Fallback: Open in default browser
            NSWorkspace.shared.open(setupURL)
            print("Opening ControlD setup in default browser")
        }
        #endif
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
