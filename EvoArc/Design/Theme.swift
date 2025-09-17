import SwiftUI

struct Theme {
    // Primary colors
    static let appBackground = Color.appBackground
    static let cardBackground = Color.cardBackground
    
    // Material styles
    struct Materials {
        #if os(iOS)
        static let bottomBar: Material = {
            if #available(iOS 26.0, *) {
                return .ultraThinMaterial
            } else {
                return .regular
            }
        }()
        
        static let urlBar: Material = {
            if #available(iOS 26.0, *) {
                return .regularMaterial
            } else {
                return .regular
            }
        }()
        
        static let suggestions: Material = {
            if #available(iOS 26.0, *) {
                return .thinMaterial
            } else {
                return .regular
            }
        }()
        #else
        static let bottomBar: Material = .regular
        static let urlBar: Material = .regular
        static let suggestions: Material = .regular
        #endif
    }
    
    // UI Element specific colors
    struct Navigation {
        static let background = Color.NavigationBar.background
        static let foreground = Color.NavigationBar.foreground
        static let tint = Color.accentColor
    }
    
    struct TabBar {
        static let background = Color.TabBar.background
        static let foreground = Color.TabBar.foreground
        static let selectedTint = Color.accentColor
    }
}

// Material styles now moved into Theme.Materials
