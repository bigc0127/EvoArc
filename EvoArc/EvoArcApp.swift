//
//  EvoArcApp.swift
//  EvoArc
//
//  Created by Connor W. Needling on 2025-09-04.
//

import SwiftUI
import CoreData

@main
struct EvoArcApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
