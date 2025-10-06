//
//  TabGroup.swift
//  EvoArc
//
//  Defines the TabGroup model for organizing related browser tabs together.
//  Tab groups help users organize many tabs into logical collections (e.g., "Work", "Research", "Shopping").
//
//  Architecture:
//  - TabGroupColor: Enum defining available color options for visual tab group identification
//  - TabGroup: Model class representing a collection of tabs with shared metadata
//  - Supports persistence (Codable) and CloudKit synchronization
//  - Conforms to ObservableObject for SwiftUI reactive updates

import Foundation  // Core types like UUID, Date, Codable
import SwiftUI     // Color type and UI framework
import Combine     // @Published and ObservableObject support

// MARK: - Tab Group Color Enum

/// Enumeration of available colors for tab groups.
/// Users choose a color to visually distinguish different tab groups in the UI.
/// 
/// Protocol conformances explained for Swift beginners:
/// - String: Each case has a string value (its rawValue)
/// - CaseIterable: Automatically provides .allCases array of all enum cases
/// - Identifiable: Required for SwiftUI ForEach loops, uses 'id' property
/// - Codable: Can be encoded to JSON/Plist and decoded back (for persistence)
enum TabGroupColor: String, CaseIterable, Identifiable, Codable {
    /// Color options for tab groups. The string values are used for persistence.
    /// For Swift beginners: 'case blue = "blue"' means:
    /// - 'blue' is the enum case name (used in Swift code)
    /// - "blue" is the rawValue (used when saving to disk or sending over network)
    case blue = "blue"
    case green = "green"
    case orange = "orange"
    case pink = "pink"
    case purple = "purple"
    case red = "red"
    case yellow = "yellow"
    case gray = "gray"
    case brown = "brown"
    case mint = "mint"
    case teal = "teal"
    case indigo = "indigo"
    
    /// Identifiable conformance requires an 'id' property.
    /// We use rawValue (the string) as the unique identifier.
    /// This lets SwiftUI track color selections in lists and pickers.
    var id: String { rawValue }
    
    /// Human-readable name for display in the UI.
    /// Computed property that returns capitalized versions of color names.
    var displayName: String {
        /// Switch statement matches 'self' (the current enum case) and returns appropriate string.
        /// For Swift beginners: 'self' in an enum refers to the current case value.
        switch self {
        case .blue: return "Blue"
        case .green: return "Green"
        case .orange: return "Orange"
        case .pink: return "Pink"
        case .purple: return "Purple"
        case .red: return "Red"
        case .yellow: return "Yellow"
        case .gray: return "Gray"
        case .brown: return "Brown"
        case .mint: return "Mint"
        case .teal: return "Teal"
        case .indigo: return "Indigo"
        }
    }
    
    /// Converts the enum case to a SwiftUI Color for rendering in the UI.
    /// SwiftUI's Color type has built-in cases like .blue, .green, etc.
    /// This property maps our enum to SwiftUI's color system.
    var color: Color {
        /// Return the corresponding SwiftUI Color for each case.
        switch self {
        case .blue: return .blue
        case .green: return .green
        case .orange: return .orange
        case .pink: return .pink
        case .purple: return .purple
        case .red: return .red
        case .yellow: return .yellow
        case .gray: return .gray
        case .brown: return .brown
        case .mint: return .mint
        case .teal: return .teal
        case .indigo: return .indigo
        }
    }
}

// MARK: - Tab Group Model

/// Represents a group of related browser tabs.
/// Tab groups help users organize many open tabs into logical collections.
/// 
/// Protocol conformances:
/// - ObservableObject: Allows SwiftUI views to react to changes automatically
/// - Identifiable: Required for SwiftUI lists, provides unique 'id' property
/// - Codable: Enables saving/loading from disk and JSON serialization
/// 
/// For Swift beginners:
/// - This is a reference type (class) not a value type (struct)
/// - Changes to properties automatically notify observing SwiftUI views
/// - Multiple tabs can reference the same TabGroup instance
class TabGroup: ObservableObject, Identifiable, Codable {
    // MARK: - Properties
    
    /// Unique identifier for this tab group.
    /// 'let' means this is immutable - set once during initialization, never changes.
    /// UUID ensures global uniqueness across devices and time.
    let id: UUID
    
    /// User-facing name of the tab group (e.g., "Work", "Research", "Shopping").
    /// @Published automatically notifies SwiftUI when this changes.
    /// Users can rename groups at any time.
    @Published var name: String
    
    /// The color used to visually identify this group in the UI.
    /// Each group gets a color to make them easily distinguishable.
    @Published var color: TabGroupColor
    
    /// Whether the group is currently collapsed in the UI.
    /// Collapsed groups show only their header, hiding their tabs.
    /// This helps manage screen space when many groups exist.
    @Published var isCollapsed: Bool
    
    /// Timestamp when this group was first created.
    /// Useful for sorting groups by age and tracking history.
    @Published var createdAt: Date
    
    /// Timestamp of the last modification to this group.
    /// Updated whenever name, color, or collapse state changes.
    /// Used for conflict resolution in sync scenarios.
    @Published var lastModified: Date
    
    // MARK: - CloudKit Synchronization
    
    /// Optional CloudKit record identifier for cloud sync.
    /// nil means this group hasn't been synced to iCloud yet.
    /// Once synced, this stores the CloudKit record ID for future updates.
    /// 
    /// For Swift beginners:
    /// - Optional (String?) can be nil or contain a String value
    /// - CloudKit is Apple's cloud database service
    var cloudKitRecordID: String?
    
    /// Flag indicating whether this group has local changes that need syncing to iCloud.
    /// true = changes waiting to be uploaded
    /// false = in sync with cloud (or sync is disabled)
    var needsCloudKitSync: Bool = false
    
    // MARK: - Initialization
    
    /// Creates a new tab group with specified properties.
    /// 
    /// Parameters with default values:
    /// - id: Unique identifier (default: generates new UUID)
    /// - name: Display name (required, no default)
    /// - color: Visual color (default: blue)
    /// - isCollapsed: Initial collapse state (default: false/expanded)
    /// 
    /// For Swift beginners:
    /// - Default parameter values let you call: TabGroup(name: "Work")
    /// - Without defaults, you'd need: TabGroup(id: UUID(), name: "Work", color: .blue, isCollapsed: false)
    /// - Default values make the API more convenient
    init(id: UUID = UUID(), name: String, color: TabGroupColor = .blue, isCollapsed: Bool = false) {
        /// Set immutable ID (can't change after initialization).
        self.id = id
        
        /// Set user-facing name.
        self.name = name
        
        /// Set visual color for UI display.
        self.color = color
        
        /// Set initial collapsed state.
        self.isCollapsed = isCollapsed
        
        /// Capture current timestamp for both creation and last modification.
        /// We store in a temporary 'now' variable to ensure both dates are identical.
        let now = Date()
        self.createdAt = now
        self.lastModified = now
    }
    
    // MARK: - Codable Implementation
    
    /// CodingKeys enum defines the keys used when encoding/decoding this class.
    /// Required for Codable when working with @Published properties.
    /// 
    /// For Swift beginners:
    /// - Codable protocol needs to know property names for JSON/data conversion
    /// - @Published properties don't automatically work with Codable
    /// - We must manually implement encode/decode when using @Published
    /// - CodingKeys maps Swift property names to storage keys
    enum CodingKeys: String, CodingKey {
        /// Each case corresponds to a property that should be saved/loaded.
        /// The string values (e.g., "id") are the actual keys in saved data.
        case id
        case name
        case color
        case isCollapsed
        case createdAt
        case lastModified
        case cloudKitRecordID
        case needsCloudKitSync
    }
    
    /// Decodes a TabGroup from saved data (JSON, Plist, etc.).
    /// This initializer is called when loading tab groups from disk.
    /// 
    /// 'required' means subclasses must implement this if they exist.
    /// 'throws' means this can fail and throw an error (e.g., corrupted data).
    /// 
    /// For Swift beginners:
    /// - Decoder reads data from storage format (JSON, etc.)
    /// - We extract each property using its CodingKey
    /// - 'try' is required before operations that can throw errors
    /// - If decoding fails, the error propagates up to the caller
    required init(from decoder: Decoder) throws {
        /// Get a keyed container that lets us read values by their CodingKey.
        /// 'keyedBy: CodingKeys.self' tells it to use our CodingKeys enum.
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        /// Decode each property from the container.
        /// .decode requires the type (UUID.self) and the key (.id).
        /// These operations can throw errors if data is missing or wrong type.
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        color = try container.decode(TabGroupColor.self, forKey: .color)
        isCollapsed = try container.decode(Bool.self, forKey: .isCollapsed)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        lastModified = try container.decode(Date.self, forKey: .lastModified)
        
        /// .decodeIfPresent handles optional values gracefully.
        /// Returns nil if the key doesn't exist (rather than throwing error).
        /// This maintains backward compatibility when adding new properties.
        cloudKitRecordID = try container.decodeIfPresent(String.self, forKey: .cloudKitRecordID)
        
        /// Use ?? operator to provide default value (false) if key is missing.
        needsCloudKitSync = try container.decodeIfPresent(Bool.self, forKey: .needsCloudKitSync) ?? false
    }
    
    /// Encodes this TabGroup to a data format for saving.
    /// Called when persisting tab groups to disk.
    /// 
    /// 'throws' means encoding operations can fail.
    func encode(to encoder: Encoder) throws {
        /// Get a mutable keyed container for writing values.
        /// 'var' makes it mutable (we'll be writing to it).
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        /// Encode each property into the container.
        /// Each try can throw if encoding fails (rare, but possible).
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(color, forKey: .color)
        try container.encode(isCollapsed, forKey: .isCollapsed)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(lastModified, forKey: .lastModified)
        
        /// .encodeIfPresent only writes the value if it's not nil.
        /// This keeps encoded data smaller and cleaner.
        try container.encodeIfPresent(cloudKitRecordID, forKey: .cloudKitRecordID)
        
        /// Always encode the sync flag, even if false.
        try container.encode(needsCloudKitSync, forKey: .needsCloudKitSync)
    }
    
    // MARK: - Update Method
    
    /// Updates group properties with new values.
    /// Only updates properties that are provided (non-nil parameters).
    /// Automatically updates lastModified timestamp and marks for sync.
    /// 
    /// For Swift beginners:
    /// - Optional parameters with default nil let you update just what you want
    /// - Example: group.update(name: "New Name") updates only the name
    /// - Example: group.update(color: .red, isCollapsed: true) updates both
    func update(name: String? = nil, color: TabGroupColor? = nil, isCollapsed: Bool? = nil) {
        /// 'if let' safely unwraps optional parameters.
        /// Only updates a property if a new value was provided.
        if let name = name {
            self.name = name
        }
        if let color = color {
            self.color = color
        }
        if let isCollapsed = isCollapsed {
            self.isCollapsed = isCollapsed
        }
        
        /// Always update the modification timestamp when any property changes.
        /// This helps with sync conflict resolution.
        self.lastModified = Date()
        
        /// Mark that this group needs to be synced to iCloud.
        /// The sync system will pick this up and upload changes.
        self.needsCloudKitSync = true
    }
}

// MARK: - Hashable Conformance

/// Extension adds Hashable protocol conformance to TabGroup.
/// Hashable allows TabGroups to be used in Sets and Dictionary keys.
/// 
/// For Swift beginners:
/// - Hashable requires implementing == (equality) and hash(into:) methods
/// - We use only 'id' for both because it's unique and immutable
/// - Two groups are equal if they have the same ID
extension TabGroup: Hashable {
    /// Equality operator checks if two TabGroups are the same.
    /// lhs = "left-hand side", rhs = "right-hand side" (from the == operator)
    /// 
    /// We only compare IDs because each group has a unique, immutable ID.
    /// If IDs match, they're the same group (even if other properties differ).
    static func == (lhs: TabGroup, rhs: TabGroup) -> Bool {
        lhs.id == rhs.id
    }
    
    /// Computes a hash value for this TabGroup.
    /// 'inout' means the hasher parameter is modified in place.
    /// 
    /// For Swift beginners:
    /// - Hash values are used by Sets and Dictionaries for fast lookups
    /// - We hash only the ID (consistent with our == implementation)
    /// - hasher.combine adds the ID's hash to the overall hash
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
