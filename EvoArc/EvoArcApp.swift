//
//  EvoArcApp.swift
//  EvoArc
//
//  Created by Connor W. Needling on 2025-09-04.
//

import SwiftUI
import UniformTypeIdentifiers

@main
struct EvoArcApp: App {
    @StateObject private var tabManager = TabManager()
    @State private var showFirstRunSetup = !UserDefaults.standard.bool(forKey: SetupCoordinator.firstRunKey)
    
    var body: some Scene {
        WindowGroup {
            ZStack(alignment: .bottom) {
                ContentView()
                    .onOpenURL { url in
                        // Handle URLs opened from other apps
                        handleIncomingURL(url)
                    }
                    .sheet(isPresented: $showFirstRunSetup, onDismiss: {
                        // Recompute in case user dismissed without completing
                        showFirstRunSetup = !UserDefaults.standard.bool(forKey: SetupCoordinator.firstRunKey)
                    }) {
                        FirstRunSetupView()
                    }
                    .onReceive(NotificationCenter.default.publisher(for: .firstRunCompleted)) { _ in
                        // Close setup immediately when we get a completion signal
                        showFirstRunSetup = false
                        UserDefaults.standard.set(true, forKey: SetupCoordinator.firstRunKey)
                    }
                
                DownloadProgressOverlay(isPresented: .constant(false))
            }
                .handlesExternalEvents(preferring: Set(["com.evoarc.browser.openURL"]), allowing: Set(["com.evoarc.browser.openURL"]))
        }
        #if os(macOS)
        .commands {
            // Add Commands menu item for URL handling
            CommandGroup(after: .newItem) {
                Button("Open URL...") {
                    handleOpenURLDialog()
                }
                .keyboardShortcut("L", modifiers: [.command])
                
                Button("New Tab") {
                    NotificationCenter.default.post(name: .newTab, object: nil)
                }
                .keyboardShortcut("t", modifiers: .command)
                
                Button("Show Tabs") {
                    NotificationCenter.default.post(name: .toggleTabDrawer, object: nil)
                }
                .keyboardShortcut("y", modifiers: [.command, .shift])
            }
        }
        #endif
    }
    
    private func handleIncomingURL(_ url: URL) {
        if url.scheme == "evoarc" {
            // Handle our custom scheme
            if let urlString = url.host,
               let decodedURL = URL(string: urlString) {
                tabManager.createNewTab(url: decodedURL)
            }
        } else {
            // Handle direct URLs
            tabManager.createNewTab(url: url)
        }
    }
    
    #if os(macOS)
    private func handleOpenURLDialog() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [UTType.url, UTType.html, UTType.text]
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                // If it's a local file, create a file:// URL
                if url.scheme == nil || url.scheme == "file" {
                    tabManager.createNewTab(url: url)
                } else if let urlString = try? String(contentsOf: url),
                          let webURL = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)) {
                    // If it's a .url file or text file containing a URL, open that URL
                    tabManager.createNewTab(url: webURL)
                }
            }
        }
    }
    #endif
}

extension Notification.Name {
    static let firstRunCompleted = Notification.Name("FirstRunCompleted")
    #if os(macOS)
    static let newTab = Notification.Name("newTab")
    #endif
}
