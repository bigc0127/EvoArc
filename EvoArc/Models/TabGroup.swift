//
//  TabGroup.swift
//  EvoArc
//
//  Created on 2025-09-06.
//

import Foundation
import SwiftUI
import Combine

enum TabGroupColor: String, CaseIterable, Identifiable, Codable {
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
    
    var id: String { rawValue }
    
    var displayName: String {
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
    
    var color: Color {
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

class TabGroup: ObservableObject, Identifiable, Codable {
    let id: UUID
    @Published var name: String
    @Published var color: TabGroupColor
    @Published var isCollapsed: Bool
    @Published var createdAt: Date
    @Published var lastModified: Date
    
    // For CloudKit sync
    var cloudKitRecordID: String?
    var needsCloudKitSync: Bool = false
    
    init(id: UUID = UUID(), name: String, color: TabGroupColor = .blue, isCollapsed: Bool = false) {
        self.id = id
        self.name = name
        self.color = color
        self.isCollapsed = isCollapsed
        let now = Date()
        self.createdAt = now
        self.lastModified = now
    }
    
    // MARK: - Codable
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case color
        case isCollapsed
        case createdAt
        case lastModified
        case cloudKitRecordID
        case needsCloudKitSync
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        color = try container.decode(TabGroupColor.self, forKey: .color)
        isCollapsed = try container.decode(Bool.self, forKey: .isCollapsed)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        lastModified = try container.decode(Date.self, forKey: .lastModified)
        cloudKitRecordID = try container.decodeIfPresent(String.self, forKey: .cloudKitRecordID)
        needsCloudKitSync = try container.decodeIfPresent(Bool.self, forKey: .needsCloudKitSync) ?? false
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(color, forKey: .color)
        try container.encode(isCollapsed, forKey: .isCollapsed)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(lastModified, forKey: .lastModified)
        try container.encodeIfPresent(cloudKitRecordID, forKey: .cloudKitRecordID)
        try container.encode(needsCloudKitSync, forKey: .needsCloudKitSync)
    }
    
    func update(name: String? = nil, color: TabGroupColor? = nil, isCollapsed: Bool? = nil) {
        if let name = name {
            self.name = name
        }
        if let color = color {
            self.color = color
        }
        if let isCollapsed = isCollapsed {
            self.isCollapsed = isCollapsed
        }
        self.lastModified = Date()
        self.needsCloudKitSync = true
    }
}

extension TabGroup: Hashable {
    static func == (lhs: TabGroup, rhs: TabGroup) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
