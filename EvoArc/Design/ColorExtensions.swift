import SwiftUI

extension Color {
    static var appBackground: Color {
        #if os(iOS)
        if #available(iOS 26.0, *) {
            return .clear
        } else {
            return Color(.systemBackground)
        }
        #else
        return Color(.windowBackgroundColor)
        #endif
    }
    
    static var cardBackground: Color {
        #if os(iOS)
        if #available(iOS 26.0, *) {
            return .clear
        } else {
            return Color(.secondarySystemBackground)
        }
        #else
        return Color(.controlBackgroundColor)
        #endif
    }
    
    /// Colors optimized for iOS 26's liquid glass UI
    enum Glass {
        static var ultraThin: Material {
            if #available(iOS 26.0, *) {
                return .ultraThinMaterial
            } else {
                return .regular
            }
        }
        
        static var thin: Material {
            if #available(iOS 26.0, *) {
                return .thinMaterial
            } else {
                return .regular
            }
        }
        
        static var regular: Material {
            if #available(iOS 26.0, *) {
                return .regularMaterial
            } else {
                return .regular
            }
        }
        
        static var thick: Material {
            if #available(iOS 26.0, *) {
                return .thickMaterial
            } else {
                return .regular
            }
        }
        
        static var shadow: (opacity: Double, radius: CGFloat) {
            if #available(iOS 26.0, *) {
                return (0.1, 1)
            } else {
                return (0.15, 2)
            }
        }
    }
}

extension Color {
    struct NavigationBar {
        static var background: Color {
            #if os(iOS)
            if #available(iOS 26.0, *) {
                return .clear
            } else {
                return Color(.systemBackground)
            }
            #else
            return Color(.windowBackgroundColor)
            #endif
        }
        
        static var foreground: Color {
            #if os(iOS)
            return .primary
            #else
            return Color(.labelColor)
            #endif
        }
    }
    
    struct TabBar {
        static var background: Material {
            #if os(iOS)
            if #available(iOS 26.0, *) {
                return .ultraThinMaterial
            } else {
                return .regular
            }
            #else
            return .regular
            #endif
        }
        
        static var foreground: Color {
            #if os(iOS)
            return .primary
            #else
            return Color(.labelColor)
            #endif
        }
    }
}