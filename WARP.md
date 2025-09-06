# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Project Overview

EvoArc is a SwiftUI-based iOS/macOS application using Core Data with CloudKit integration for persistent storage. The app follows the standard Xcode project structure with a main app target and associated test targets.

## Build Commands

### Building the Application
```bash
# Build for iOS Simulator (Debug)
xcodebuild -project EvoArc.xcodeproj -scheme EvoArc -sdk iphonesimulator -configuration Debug build

# Build for macOS (Debug)
xcodebuild -project EvoArc.xcodeproj -scheme EvoArc -configuration Debug build

# Build for Release
xcodebuild -project EvoArc.xcodeproj -scheme EvoArc -configuration Release build

# Clean build folder
xcodebuild -project EvoArc.xcodeproj -scheme EvoArc clean
```

### Running Tests
```bash
# Run unit tests
xcodebuild test -project EvoArc.xcodeproj -scheme EvoArc -destination 'platform=iOS Simulator,name=iPhone 15 Pro'

# Run a specific test class
xcodebuild test -project EvoArc.xcodeproj -scheme EvoArc -only-testing:EvoArcTests/EvoArcTests -destination 'platform=iOS Simulator,name=iPhone 15 Pro'

# Run UI tests
xcodebuild test -project EvoArc.xcodeproj -scheme EvoArc -only-testing:EvoArcUITests -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

### Running in Simulator
```bash
# Open iOS Simulator
open -a Simulator

# Build and run in simulator
xcodebuild -project EvoArc.xcodeproj -scheme EvoArc -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15 Pro' run
```

### Opening in Xcode
```bash
# Open project in Xcode
open EvoArc.xcodeproj

# Open project in Xcode Beta (if using beta features)
open -a "Xcode-beta" EvoArc.xcodeproj
```

## Architecture

### Core Components

**EvoArcApp.swift**: The main application entry point using SwiftUI's @main attribute. Initializes the Core Data persistence controller and injects it into the environment.

**ContentView.swift**: The primary user interface view implementing a list-based layout with Core Data integration via @FetchRequest. Handles CRUD operations for Item entities.

**Persistence.swift**: Manages the Core Data stack using NSPersistentCloudKitContainer for automatic iCloud sync. Provides both shared production instance and preview instance for SwiftUI previews.

### Data Flow

1. **Core Data Stack**: The app uses NSPersistentCloudKitContainer which automatically syncs data across devices via CloudKit
2. **View Context**: Managed object context is injected via SwiftUI environment from the App level down to views
3. **Fetch Requests**: Views use @FetchRequest property wrapper for reactive data updates
4. **Data Operations**: All Core Data saves happen within animation blocks for smooth UI updates

### Platform Considerations

The app supports both iOS and macOS with platform-specific UI adjustments:
- iOS-specific toolbar items (EditButton) are conditionally compiled with `#if os(iOS)`
- The navigation structure adapts to the platform automatically via SwiftUI

### Test Structure

- **EvoArcTests**: Unit tests for business logic and Core Data operations
- **EvoArcUITests**: UI automation tests for user interaction flows

## Key Files

- `EvoArc.xcdatamodeld`: Core Data model defining the Item entity with timestamp attribute
- `Assets.xcassets`: Image and color assets for the application
- `EvoArc.entitlements`: App capabilities including CloudKit for data syncing
- `Info.plist`: Application configuration and metadata

## Development Notes

- The project uses automatic reference counting (ARC) and Swift's modern concurrency features
- Core Data operations should be performed on the appropriate queue/context
- The persistence controller includes comprehensive error handling with detailed comments about common failure scenarios
- Preview data is automatically generated for SwiftUI previews via the preview persistence controller
