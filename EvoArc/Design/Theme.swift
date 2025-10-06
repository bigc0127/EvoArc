//
//  Theme.swift
//  EvoArc
//
//  Central theme configuration defining colors, layouts, and materials.
//  Provides a single source of truth for the app's visual design system.
//
//  For Swift beginners:
//  - Namespacing pattern using nested structs
//  - static let means constants accessible without creating instances
//  - Material is SwiftUI's blur/translucency effect system

import SwiftUI

// MARK: - Theme Configuration

/// Central theme configuration for EvoArc's visual design.
/// Uses nested structs to organize related constants.
/// 
/// For Swift beginners:
/// - struct (not class) because we only need a namespace, not instances
/// - All properties are static (accessed via Theme.property)
/// - No init() needed since we never create Theme objects
struct Theme {
    // MARK: - Colors
    
    /// Primary background color for the app.
    /// References Color extension in ColorExtensions.swift.
    static let appBackground = Color.appBackground
    
    /// Background color for cards and panels.
    static let cardBackground = Color.cardBackground
    
    // MARK: - Layout Constants
    
    /// Layout measurements for consistent spacing and sizing.
    /// Nested struct groups related constants.
    struct Layout {
        /// Corner radius for floating UI bars (smooth rounded corners).
        /// CGFloat is Core Graphics' floating-point type.
        static let floatingBarCornerRadius: CGFloat = 16
        
        /// Shadow blur radius for floating bars.
        static let floatingBarShadowRadius: CGFloat = 10
        
        /// Shadow opacity (0.0 = invisible, 1.0 = solid).
        /// Float is used here for graphics APIs.
        static let floatingBarShadowOpacity: Float = 0.1
        
        /// Horizontal padding inside floating bars.
        static let floatingBarHorizontalPadding: CGFloat = 16
        
        /// Vertical padding inside floating bars.
        static let floatingBarVerticalPadding: CGFloat = 8
    }
    
    // MARK: - Material Effects
    
    /// Blur/translucency materials for iOS.
    /// Materials create that signature iOS frosted-glass effect.
    /// 
    /// For Swift beginners:
    /// - Material is SwiftUI's blur effect system
    /// - #if os(iOS) enables iOS-specific code
    /// - #available checks iOS version for new APIs
    struct Materials {
        /// iOS-specific material definitions with version checking.
        #if os(iOS)
        /// Material for bottom toolbar.
        /// Uses newer API on iOS 26+, falls back on older versions.
        /// 
        /// For Swift beginners:
        /// - The = { }() pattern immediately executes the closure
        /// - This runs once at app launch to determine which material to use
        /// - The * in #available means "and all later versions"
        static let bottomBar: Material = {
            if #available(iOS 26.0, *) {
                return .regularMaterial
            } else {
                return .regular
            }
        }()
        
        /// Opacity for floating bars (0.0 = transparent, 1.0 = opaque).
        static let floatingBarOpacity: Double = 0.85
        
        /// Border opacity for floating bars.
        static let floatingBarBorderOpacity: Double = 0.1
        
        /// Material for URL bar.
        static let urlBar: Material = {
            if #available(iOS 26.0, *) {
                return .regularMaterial
            } else {
                return .regular
            }
        }()
        
        /// Material for search suggestions (thinner blur for readability).
        static let suggestions: Material = {
            if #available(iOS 26.0, *) {
                return .thinMaterial
            } else {
                return .regular
            }
        }()
        #else
        /// macOS fallbacks (Materials work differently on macOS).
        static let bottomBar: Material = .regular
        static let urlBar: Material = .regular
        static let suggestions: Material = .regular
        #endif
    }
    
    // MARK: - Navigation Bar Theme
    
    /// Colors for navigation bar elements.
    struct Navigation {
        /// Navigation bar background color.
        static let background = Color.NavigationBar.background
        
        /// Navigation bar text/icon color.
        static let foreground = Color.NavigationBar.foreground
        
        /// Accent color for tappable elements.
        static let tint = Color.accentColor
    }
    
    // MARK: - Tab Bar Theme
    
    /// Colors for tab bar elements.
    struct TabBar {
        /// Tab bar background color.
        static let background = Color.TabBar.background
        
        /// Tab bar text/icon color.
        static let foreground = Color.TabBar.foreground
        
        /// Accent color for selected tab.
        static let selectedTint = Color.accentColor
    }
}

// Material styles are organized in Theme.Materials above.
