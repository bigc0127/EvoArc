# Pinned Tabs Feature

EvoArc now supports pinning tabs that persist across browser sessions and sync across devices via iCloud.

## Overview

Pinned tabs are tabs that:
- **Persist across sessions** - They automatically restore when you open the browser
- **Sync via iCloud** - Your pinned tabs appear on all your devices with EvoArc
- **Stay organized** - Pinned tabs always appear first in the tab list
- **Have visual indicators** - Pinned tabs show a pin icon instead of a globe icon
- **Are protected** - Pinned tabs require confirmation before closing

## How to Use

### Pinning a Tab

**iOS:**
1. **Via Bottom Toolbar**: Tap the pin icon in the bottom toolbar while viewing the tab you want to pin
2. **Via Tab Drawer**: Swipe up to open the tab drawer, long-press on any tab, and select "Pin Tab"

**macOS:**
1. **Via Bottom Toolbar**: Click the pin icon in the bottom toolbar while viewing the tab you want to pin  
2. **Via Sidebar**: Right-click on any tab in the sidebar and select "Pin Tab"

### Unpinning a Tab

**iOS:**
1. **Via Bottom Toolbar**: Tap the pin slash icon in the bottom toolbar while viewing a pinned tab
2. **Via Tab Drawer**: Long-press on a pinned tab and select "Unpin Tab"

**macOS:**
1. **Via Bottom Toolbar**: Click the pin slash icon in the bottom toolbar while viewing a pinned tab
2. **Via Sidebar**: Right-click on a pinned tab and select "Unpin Tab"

### Visual Indicators

- **Pin Icon**: Pinned tabs show a blue pin icon instead of the globe icon
- **Grouped Section**: Pinned tabs appear in a separate "PINNED" section at the top of the tab list
- **Button State**: The pin button in the toolbar shows filled (pinned) or slash (unpinned) states

## Technical Architecture

### Core Data Model

```swift
entity PinnedTab {
    urlString: String?     // The URL of the pinned tab
    title: String?         // The title of the pinned tab  
    isPinned: Boolean      // Always true (for data integrity)
    pinnedOrder: Int16     // Order for sorting pinned tabs
    createdAt: Date?       // When the tab was pinned
}
```

### Key Classes

**PinnedTabManager**
- Singleton that manages Core Data operations for pinned tabs
- Handles CRUD operations (create, read, update, delete)
- Observes Core Data changes and publishes updates
- Provides methods: `pinTab()`, `unpinTab()`, `isTabPinned()`

**TabManager** 
- Extended with pinned tab support
- Integrates with PinnedTabManager for persistence
- Restores pinned tabs on app launch
- Maintains pinned tabs at the front of the tabs array

**Tab Model**
- Added `isPinned: Bool` property
- Automatically checks pinned status on initialization
- Updates UI based on pinned state

### CloudKit Integration

Pinned tabs automatically sync via CloudKit because:
1. The Core Data model uses `NSPersistentCloudKitContainer`
2. The `PinnedTab` entity is marked as `syncable=\"YES\"`
3. All attributes are compatible with CloudKit data types
4. Changes are automatically pushed and pulled across devices

### State Restoration

On app launch:
1. `TabManager` initializes and calls `restorePinnedTabs()`
2. Fetches all `PinnedTab` entities sorted by `pinnedOrder`
3. Creates `Tab` instances for each pinned tab
4. Sets `isPinned = true` on restored tabs
5. Positions pinned tabs first in the tabs array

### Data Synchronization

The system uses Combine publishers to keep UI in sync:
- `PinnedTabManager` publishes `@Published var pinnedTabs: [PinnedTab]`  
- `TabManager` observes changes and updates in-memory tab states
- Core Data change notifications trigger UI updates automatically

## Implementation Details

### Pin Order Management

```swift
private func nextPinnedOrder() -> Int16 {
    let maxOrder = pinnedTabs.map { $0.pinnedOrder }.max() ?? -1
    return maxOrder + 1
}
```

### Duplicate Prevention

The system prevents pinning the same URL twice:
```swift
if pinnedTabs.contains(where: { $0.urlString == url.absoluteString }) {
    print("Tab already pinned: \(url.absoluteString)")
    return
}
```

### Tab Positioning

Pinned tabs are kept at the front of the tabs array:
```swift
private func repositionPinnedTabs() {
    tabs.sort { tab1, tab2 in
        if tab1.isPinned && !tab2.isPinned {
            return true
        } else if !tab1.isPinned && tab2.isPinned {
            return false
        } else {
            return false // Maintain existing order for same type
        }
    }
}
```

## Testing

The feature includes comprehensive unit tests covering:
- **CRUD Operations**: Pin, unpin, duplicate prevention
- **Ordering**: Pin order assignment and sorting
- **Integration**: TabManager integration with PinnedTabManager
- **Persistence**: Core Data save/load operations  
- **State Restoration**: App restart scenarios
- **UI Updates**: Reactive UI updates via Combine

Run tests with:
```bash
xcodebuild test -project EvoArc.xcodeproj -scheme EvoArc -only-testing:EvoArcTests/PinnedTabTests
```

## Migration Notes

This feature introduces a new Core Data entity (`PinnedTab`) which will trigger a lightweight Core Data migration on first launch. This migration is automatic and should not require user intervention.

The migration:
- Adds the `PinnedTab` entity to the data model
- Enables CloudKit sync for the new entity
- Preserves all existing data

## Troubleshooting

### Pinned tabs not syncing

1. Check that iCloud is enabled in Settings → [Your Name] → iCloud
2. Verify that EvoArc has iCloud permission 
3. Check iCloud storage availability
4. CloudKit sync may take a few minutes to propagate changes

### Pinned tabs not restoring

1. Check that the app has proper CloudKit entitlements
2. Verify Core Data model integrity
3. Check console logs for Core Data or CloudKit errors

### Performance considerations

- The system fetches pinned tabs only once on app launch
- UI updates are reactive and efficient via Combine publishers
- Core Data operations are performed on the main queue for UI consistency

## Future Enhancements

Potential improvements for future versions:
- **Drag & Drop Reordering**: Allow users to reorder pinned tabs manually
- **Favicon Support**: Show actual website favicons instead of generic icons  
- **Pin Groups**: Organize pinned tabs into named groups or folders
- **Pin Shortcuts**: Keyboard shortcuts for quick pin/unpin actions
- **Export/Import**: Backup and restore pinned tabs as JSON
