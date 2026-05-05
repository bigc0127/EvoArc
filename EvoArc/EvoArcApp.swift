//
//  EvoArcApp.swift
//  EvoArc
//
//  The main entry point for the EvoArc browser application.
//  This file defines the app's lifecycle, initial setup, and root view hierarchy.
//
//  For Swift beginners:
//  - @main marks this as the app's entry point (like main() in other languages)
//  - The App protocol defines the structure of a SwiftUI application
//  - SwiftUI manages the app lifecycle automatically (no AppDelegate needed in simple cases)

import SwiftUI

// MARK: - Main Application Structure

/// The @main attribute tells Swift this is the application's entry point.
/// When you launch the app, Swift automatically calls this struct's body property.
/// Think of this as the "main()" function in other programming languages.
@main
struct EvoArcApp: App {
    // MARK: - State Management
    
    /// @StateObject creates and owns a TabManager instance for this app.
    /// This is a property wrapper that:
    /// 1. Creates the object once when the app launches
    /// 2. Keeps it alive for the app's entire lifetime
    /// 3. Automatically updates the UI when the TabManager's @Published properties change
    /// 
    /// TabManager is responsible for managing all browser tabs, their state, and persistence.
    @StateObject private var tabManager = TabManager()
    
    /// @State stores simple value types that can change over time.
    /// This boolean controls whether the first-run setup screen is shown.
    /// 
    /// How it works:
    /// - On first launch, SetupCoordinator.firstRunKey won't exist in UserDefaults
    /// - UserDefaults.bool returns false for non-existent keys
    /// - The ! negates it, so showFirstRunSetup becomes true
    /// - After setup completes, the key is set to true, preventing future displays
    @State private var showFirstRunSetup = !UserDefaults.standard.bool(forKey: SetupCoordinator.firstRunKey)
    
    // MARK: - Scene Configuration
    
    /// The body property defines the app's scene structure.
    /// Scene is a protocol that represents a part of your app's UI that can exist in a window.
    /// The 'some Scene' return type means "returns something that conforms to Scene protocol".
    /// Swift's type inference figures out the exact type automatically.
    var body: some Scene {
        /// WindowGroup creates a scene that can have multiple windows (important for iPad/Mac).
        /// On iPhone, it typically shows one window. On iPad/Mac, users can create multiple windows
        /// of your app, each with independent state.
        WindowGroup {
            /// ZStack layers views on top of each other (Z-axis stacking).
            /// .bottom alignment means child views align to the bottom of the stack.
            /// This is used here to overlay the download progress indicator at the bottom.
            ZStack(alignment: .bottom) {
                /// ContentView is the main browser interface.
                /// It contains the web view, URL bar, tabs, and all primary browser UI.
                /// Pass our TabManager instance to ContentView so they share the same instance.
                ContentView(tabManager: tabManager)
                    /// .sheet presents a modal view that slides up from the bottom.
                    /// isPresented: binds to our @State variable ($ creates a Binding)
                    /// onDismiss: called when the sheet is dismissed by swiping down
                    .sheet(isPresented: $showFirstRunSetup, onDismiss: {
                        /// Recheck UserDefaults in case the user dismissed the sheet
                        /// without completing setup (by swiping down instead of tapping Done).
                        /// This ensures we show setup again on next launch if incomplete.
                        showFirstRunSetup = !UserDefaults.standard.bool(forKey: SetupCoordinator.firstRunKey)
                    }) {
                        /// FirstRunSetupView is the initial setup screen shown on first app launch.
                        /// It guides users through choosing settings like search engine, homepage, etc.
                        FirstRunSetupView()
                    }
                    /// .onReceive listens for system-wide notifications using NotificationCenter.
                    /// This is part of the Combine framework for reactive programming.
                    /// When .firstRunCompleted notification fires, this closure executes.
                    .onReceive(NotificationCenter.default.publisher(for: .firstRunCompleted)) { _ in
                        /// Immediately hide the setup screen when setup completes successfully.
                        /// We also save this completion to UserDefaults so setup doesn't show again.
                        showFirstRunSetup = false
                        UserDefaults.standard.set(true, forKey: SetupCoordinator.firstRunKey)
                    }
                
                /// DownloadProgressOverlay shows download progress at the bottom of the screen.
                /// .constant(false) creates a Binding that never changes (always false).
                /// This is used here as a placeholder - the actual download state is managed elsewhere.
                DownloadProgressOverlay(isPresented: .constant(false))
            }
                /// .onOpenURL handles URLs from external sources at the root level
                .onOpenURL { url in
                    #if DEBUG
                    dlog("[EvoArcApp] Root view onOpenURL called with: \(url.absoluteString)")
                    #endif
                    handleIncomingURL(url)
                }
                /// .handlesExternalEvents configures how this scene responds to external events.
                /// This is important for deep linking and URL schemes.
                /// - preferring: Events this scene prefers to handle (gets priority)
                /// - allowing: Events this scene is allowed to handle
                /// Our custom URL scheme "com.evoarc.browser.openURL" is registered here.
                .handlesExternalEvents(preferring: Set(["com.evoarc.browser.openURL"]), allowing: Set(["com.evoarc.browser.openURL"]))
        }
    }
    
    // MARK: - URL Handling
    
    /// Processes URLs that come from external sources (other apps, system, etc.).
    /// This method is called when a URL is opened with EvoArc.
    ///
    /// For Swift beginners:
    /// - 'private' means this method is only accessible within this file
    /// - The underscore '_' parameter label means callers don't use a label: handleIncomingURL(url)
    /// - URL is a Foundation struct representing a web address or file location
    private func handleIncomingURL(_ url: URL) {
        #if DEBUG
        dlog("[EvoArcApp] handleIncomingURL called with: \(url.absoluteString)")
        #endif
        
        /// Check if the URL uses our custom scheme "evoarc://"
        if url.scheme == "evoarc" {
            #if DEBUG
            dlog("[EvoArcApp] Detected evoarc:// scheme")
            #endif
            
            guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
                #if DEBUG
                dlog("[EvoArcApp] Failed to parse URL components")
                #endif
                return
            }
            
            // Handle evoarc://open-url?url=<url> (from share extension)
            if components.host == "open-url",
               let urlString = components.queryItems?.first(where: { $0.name == "url" })?.value,
               let targetURL = URL(string: urlString) {
                #if DEBUG
                dlog("[EvoArcApp] Opening URL from share extension: \(targetURL.absoluteString)")
                #endif
                tabManager.createNewTab(url: targetURL)
                return
            }
            
            // Handle evoarc://search?q=<query> (search from share extension)
            if components.host == "search",
               let query = components.queryItems?.first(where: { $0.name == "q" })?.value,
               let searchURL = BrowserSettings.shared.searchURL(for: query) {
                #if DEBUG
                dlog("[EvoArcApp] Performing search from share extension: \(query)")
                #endif
                tabManager.createNewTab(url: searchURL)
                return
            }
            
            // Legacy: evoarc://open (check App Groups)
            if components.host == "open" {
                #if DEBUG
                dlog("[EvoArcApp] Legacy share extension trigger, checking App Group")
                #endif
                checkForPendingSharedURL()
                return
            }
            
            #if DEBUG
            dlog("[EvoArcApp] Unknown evoarc URL format: \(url.absoluteString)")
            #endif
        } else {
            #if DEBUG
            dlog("[EvoArcApp] Standard URL scheme: \(url.scheme ?? "none")")
            #endif
            /// For standard http:// or https:// URLs, open directly.
            tabManager.createNewTab(url: url)
        }
    }
    
    /// Checks App Group UserDefaults for pending shared URL from share extension
    private func checkForPendingSharedURL() {
        let appGroupID = "group.com.ConnorNeedling.EvoArcBrowser"
        guard let sharedDefaults = UserDefaults(suiteName: appGroupID) else {
            #if DEBUG
            dlog("[EvoArcApp] ERROR: Failed to access App Group UserDefaults")
            #endif
            return
        }
        
        guard let urlString = sharedDefaults.string(forKey: "pendingSharedURL"),
              let url = URL(string: urlString) else {
            #if DEBUG
            dlog("[EvoArcApp] No pending shared URL found")
            #endif
            return
        }
        
        // Check timestamp to ensure URL is recent (within last 5 seconds)
        let timestamp = sharedDefaults.double(forKey: "pendingSharedURLTimestamp")
        let age = Date().timeIntervalSince1970 - timestamp
        
        if age > 5.0 {
            #if DEBUG
            dlog("[EvoArcApp] Pending URL is too old (\(age)s), ignoring")
            #endif
            // Clear the old URL
            sharedDefaults.removeObject(forKey: "pendingSharedURL")
            sharedDefaults.removeObject(forKey: "pendingSharedURLTimestamp")
            return
        }
        
        #if DEBUG
        dlog("[EvoArcApp] Found pending shared URL: \(urlString)")
        #endif
        
        // Clear the pending URL
        sharedDefaults.removeObject(forKey: "pendingSharedURL")
        sharedDefaults.removeObject(forKey: "pendingSharedURLTimestamp")
        sharedDefaults.synchronize()
        
        // Open the URL
        tabManager.createNewTab(url: url)
    }
}

// MARK: - Notification Extensions

/// Extension adds new static properties to Notification.Name.
/// This is a Swift feature for organizing related constants.
/// 
/// For Swift beginners:
/// - Extensions let you add functionality to existing types without modifying their source
/// - static properties belong to the type itself, not instances
/// - Notification.Name is used throughout iOS for event broadcasting
extension Notification.Name {
    /// Custom notification posted when the first-run setup completes successfully.
    /// Other parts of the app can listen for this to trigger post-setup actions.
    /// 
    /// The string "FirstRunCompleted" is the unique identifier for this notification.
    static let firstRunCompleted = Notification.Name("FirstRunCompleted")
}
