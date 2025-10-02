//
//  EvoArcApp.swift
//  EvoArc
//
//  Created by Connor W. Needling on 2025-09-04.
//

import SwiftUI

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
}

extension Notification.Name {
    static let firstRunCompleted = Notification.Name("FirstRunCompleted")
}
