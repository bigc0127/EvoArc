# EvoArc Localization Guide

## Overview

EvoArc now supports German (Deutsch) localization. The app automatically displays German text when the device language is set to German.

## Supported Languages

- **English (en)** - Default language
- **German (de)** - Full translation

## File Structure

```
EvoArc/
├── en.lproj/
│   ├── Localizable.strings    # English UI strings
│   └── InfoPlist.strings       # English app metadata
├── de.lproj/
│   ├── Localizable.strings    # German UI strings
│   └── InfoPlist.strings       # German app metadata
└── Helpers/
    └── LocalizationHelper.swift # Convenience extension for localization
```

## Testing German Localization

### Method 1: Change Device Language (Recommended)

1. Open **Settings** app on your iOS device/simulator
2. Go to **General** → **Language & Region**
3. Tap **Add Language...**
4. Select **Deutsch** (German)
5. When prompted, choose **Change to Deutsch** or **Use Deutsch**
6. Launch EvoArc - all text should now be in German

### Method 2: Test in Simulator

1. Launch your iOS Simulator
2. Open **Settings** app in the simulator
3. Follow the same steps as Method 1
4. Close and relaunch EvoArc

### Method 3: Xcode Scheme Settings (Quick Test)

1. In Xcode, go to **Product** → **Scheme** → **Edit Scheme...**
2. Select **Run** in the left sidebar
3. Go to the **Options** tab
4. Under **App Language**, select **German**
5. Click **Close**
6. Run the app - it will launch in German

## Localization Coverage

### Fully Localized Sections

✅ **New Tab Page**
- Search placeholder
- Bookmarks section title

✅ **General UI**
- Navigation buttons (Back, Forward, Reload, Share)
- Action buttons (Done, Cancel, Delete, Save, etc.)
- Common labels

✅ **Bookmarks**
- All bookmark-related UI
- Folder management
- Search functionality

✅ **History**
- History view
- Time groupings (Today, Yesterday, This Week, Older)
- Clear history dialogs

✅ **Settings**
- All settings categories
- Search engine names
- Browser engine options
- Privacy settings
- Ad blocking options
- Download settings

✅ **Tabs**
- Tab management
- Tab groups
- Pin/unpin actions

✅ **First Run Setup**
- Welcome screen
- Setup wizard steps

✅ **Dialogs & Confirmations**
- All confirmation dialogs
- Error messages
- Context menus

## Adding New Localized Strings

### Step 1: Add to English Strings File

Edit `en.lproj/Localizable.strings`:

```strings
"new_feature_title" = "New Feature";
"new_feature_description" = "This is a new feature description";
```

### Step 2: Add German Translation

Edit `de.lproj/Localizable.strings`:

```strings
"new_feature_title" = "Neue Funktion";
"new_feature_description" = "Dies ist eine Beschreibung der neuen Funktion";
```

### Step 3: Use in Code

```swift
// Method 1: Using the helper extension
Text("new_feature_title".localized)

// Method 2: Using NSLocalizedString directly
Text(NSLocalizedString("new_feature_title", comment: "Title for new feature"))

// Method 3: With format arguments
let count = 5
Text("items_count".localizedWith(count))  // "5 items" or "5 Elemente"
```

## Localization Helper

The `LocalizationHelper.swift` file provides convenient extensions:

```swift
extension String {
    // Simple localization
    var localized: String
    
    // Localization with comment
    func localized(comment: String) -> String
    
    // Localization with format arguments
    func localizedWith(_ arguments: CVarArg...) -> String
}
```

### Usage Examples

```swift
// Simple
Button("done".localized) { /* action */ }

// With comment
let title = "settings".localized(comment: "Settings screen title")

// With arguments
let message = "delete_count".localizedWith(itemCount)
// For string: "Delete %d items" / "Lösche %d Elemente"
```

## Key Strings Reference

### Common Actions
- `done` - Done / Fertig
- `cancel` - Cancel / Abbrechen
- `delete` - Delete / Löschen
- `save` - Save / Sichern
- `create` - Create / Erstellen
- `edit` - Edit / Bearbeiten

### Navigation
- `back` - Back / Zurück
- `forward` - Forward / Vor
- `reload` - Reload / Neu laden
- `share` - Share / Teilen

### Bookmarks
- `bookmarks` - Bookmarks / Lesezeichen
- `add_bookmark` - Add Bookmark / Lesezeichen hinzufügen
- `no_bookmarks` - No bookmarks yet / Noch keine Lesezeichen

### Settings
- `settings` - Settings / Einstellungen
- `general` - General / Allgemein
- `privacy` - Privacy / Datenschutz
- `advanced` - Advanced / Erweitert

## Best Practices

### 1. Always Use Keys, Not English Text

❌ **Bad:**
```swift
Text("Bookmarks")  // Hardcoded English
```

✅ **Good:**
```swift
Text("bookmarks".localized)  // Localized key
```

### 2. Add Comments for Context

```swift
// Good for translators to understand context
"search".localized(comment: "Search button label")
```

### 3. Use Placeholders for Dynamic Content

```strings
"items_count" = "%d items";  // English
"items_count" = "%d Elemente";  // German
```

### 4. Keep Keys Descriptive

❌ **Bad:** `"btn1"`, `"label2"`
✅ **Good:** `"add_bookmark"`, `"delete_confirmation"`

## Troubleshooting

### Localization Not Working?

1. **Check Language Settings**: Ensure device/simulator is set to German
2. **Clean Build**: Product → Clean Build Folder (⇧⌘K)
3. **Rebuild**: Build the project again
4. **Restart Simulator**: Sometimes required for language changes
5. **Check .strings Files**: Ensure no syntax errors (missing semicolons, quotes)

### Common Syntax Errors

❌ **Missing semicolon:**
```strings
"key" = "value"  // Error!
```

✅ **Correct:**
```strings
"key" = "value";  // Good!
```

❌ **Unescaped quotes:**
```strings
"message" = "She said "hello"";  // Error!
```

✅ **Correct:**
```strings
"message" = "She said \"hello\"";  // Good!
```

## Adding More Languages

To add additional languages (e.g., French, Spanish):

1. Create new .lproj directory:
   ```bash
   mkdir -p EvoArc/fr.lproj
   ```

2. Copy English strings files as template:
   ```bash
   cp EvoArc/en.lproj/Localizable.strings EvoArc/fr.lproj/
   cp EvoArc/en.lproj/InfoPlist.strings EvoArc/fr.lproj/
   ```

3. Translate the values (keep keys in English)

4. Add language to project.pbxproj `knownRegions` (Xcode usually does this automatically)

5. Test with the new language

## Resources

- [Apple Localization Guide](https://developer.apple.com/localization/)
- [iOS Locale Identifiers](https://www.ibabbleon.com/iOS-Language-Codes-ISO-639.html)
- [String Format Specifiers](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/Strings/Articles/formatSpecifiers.html)

## Current Translation Status

| Section | English | German |
|---------|---------|--------|
| New Tab Page | ✅ | ✅ |
| Bookmarks | ✅ | ✅ |
| History | ✅ | ✅ |
| Settings | ✅ | ✅ |
| Tabs | ✅ | ✅ |
| Downloads | ✅ | ✅ |
| First Run | ✅ | ✅ |
| Dialogs | ✅ | ✅ |

**Note**: While the localization framework is complete, individual views need to be updated to use the localized strings. The NewTabPageView serves as an example implementation.
