//
//  ThemeColors.swift
//  EvoArc
//
//  Created by Connor W. Needling on 2025-09-17.
//

import SwiftUI

/// Theme colors that automatically adapt between light and dark modes
enum ThemeColors {
    /// Base colors that adapt between modes
    static let background = Color("Background")
    static let secondaryBackground = Color("SecondaryBackground")
    static let tertiaryBackground = Color("TertiaryBackground")
    static let groupedBackground = Color("GroupedBackground")
    
    /// Text colors that adapt between modes
    static let primaryText = Color("PrimaryText")
    static let secondaryText = Color("SecondaryText")
    static let tertiaryText = Color("TertiaryText")
    
    /// UI element colors that adapt between modes
    static let separator = Color("Separator")
    static let shadow = Color("Shadow")
    static let overlay = Color("Overlay")
    
    /// Generates dynamic color that adapts to dark mode
    static func dynamic(light: Color, dark: Color) -> Color {
        return Color(uiColor: UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor(dark)
            default:
                return UIColor(light)
            }
        })
    }
}

// MARK: - Color Extension
extension Color {
    /// Creates a color that adapts between light and dark modes
    static func adaptable(light: Color, dark: Color) -> Color {
        return ThemeColors.dynamic(light: light, dark: dark)
    }
    
    /// Background colors
    // Note: appBackground and cardBackground are defined in Design/ColorExtensions.swift to avoid redeclaration.
    // Use those unified definitions across the app.
    
    static let modalBackground = ThemeColors.dynamic(
        light: Color(white: 0.96),
        dark: Color(white: 0.12)
    )
    
    static let groupedListBackground = ThemeColors.dynamic(
        light: Color(white: 0.95),
        dark: Color(white: 0.08)
    )
    
    /// Text colors
    static let primaryLabel = ThemeColors.dynamic(
        light: Color(white: 0.1),
        dark: Color(white: 0.95)
    )
    
    static let secondaryLabel = ThemeColors.dynamic(
        light: Color(white: 0.4),
        dark: Color(white: 0.7)
    )
    
    static let tertiaryLabel = ThemeColors.dynamic(
        light: Color(white: 0.6),
        dark: Color(white: 0.5)
    )
    
    /// UI element colors
    static let separator = ThemeColors.dynamic(
        light: Color(white: 0.9),
        dark: Color(white: 0.2)
    )
    
    static let shadow = ThemeColors.dynamic(
        light: Color.black.opacity(0.1),
        dark: Color.black.opacity(0.3)
    )
    
    static let overlay = ThemeColors.dynamic(
        light: Color.black.opacity(0.4),
        dark: Color.black.opacity(0.6)
    )
}

// MARK: - View Extension
extension View {
    /// Applies theme-aware shadow
    func themeShadow(radius: CGFloat = 10, y: CGFloat = 5) -> some View {
        self.shadow(color: .shadow, radius: radius, y: y)
    }
    
    /// Applies theme-aware overlay for modals/sheets
    func themeOverlay() -> some View {
        self.background(Color.overlay)
    }
}

