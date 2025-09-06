//
//  EvoArcApp.swift
//  EvoArc
//
//  Created by Connor W. Needling on 2025-09-04.
//

import SwiftUI

@main
struct EvoArcApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        #if os(macOS)
        .commands {
            CommandGroup(after: .newItem) {
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
}

#if os(macOS)
extension Notification.Name {
    static let newTab = Notification.Name("newTab")
}
#endif
