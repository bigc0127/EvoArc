import SwiftUI

#if os(iOS)
/// Provides version-specific UI metrics and styles
enum UIStyleMetrics {
    static var isIOS26OrLater: Bool {
        if #available(iOS 26.0, *) {
            return true
        }
        return false
    }
    
    /// Corner radius values for different UI elements
    enum CornerRadius {
        static var bottomBar: CGFloat {
            isIOS26OrLater ? 16 : 12
        }
        
        static var urlBar: CGFloat {
            isIOS26OrLater ? 12 : 8
        }
        
        static var suggestions: CGFloat {
            isIOS26OrLater ? 14 : 8
        }
    }
    
    /// Background materials and effects
    enum BackgroundStyle {
        static var bottomBar: Material {
            isIOS26OrLater ? .ultraThinMaterial : .regular
        }
        
        static var urlBar: Material {
            isIOS26OrLater ? .regularMaterial : .thin
        }
        
        static var suggestions: Material {
            isIOS26OrLater ? .ultraThinMaterial : .regular
        }
    }
    
    /// Shadow configurations
    enum Shadow {
        static var bottomBar: (color: Color, radius: CGFloat) {
            isIOS26OrLater ? (.black.opacity(0.1), 1) : (.black.opacity(0.15), 2)
        }
        
        static var urlBar: (color: Color, radius: CGFloat) {
            isIOS26OrLater ? (.black.opacity(0.08), 1) : (.black.opacity(0.1), 2)
        }
        
        static var suggestions: (color: Color, radius: CGFloat, y: CGFloat) {
            isIOS26OrLater ? (.black.opacity(0.1), 2, 1) : (.black.opacity(0.15), 4, 2)
        }
    }
}
#endif