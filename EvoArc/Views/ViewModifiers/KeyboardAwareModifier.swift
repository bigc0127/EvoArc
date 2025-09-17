import SwiftUI

/// A view modifier that adjusts content position based on keyboard height
struct KeyboardAwareModifier: ViewModifier {
    @ObservedObject var keyboardManager: KeyboardHeightManager
    let spacing: CGFloat
    
    func body(content: Content) -> some View {
        #if os(iOS)
        content
            .padding(.bottom, keyboardManager.keyboardHeight + spacing)
            .animation(
                .easeOut(duration: keyboardManager.keyboardAnimationDuration),
                value: keyboardManager.keyboardHeight
            )
        #else
        content
        #endif
    }
}

// MARK: - View Extension

extension View {
    /// Positions the view above the keyboard with the specified spacing
    /// This view modifier is intended for iOS only and has no effect on other platforms
    func keyboardAware(manager: KeyboardHeightManager, spacing: CGFloat = 0) -> some View {
        modifier(KeyboardAwareModifier(keyboardManager: manager, spacing: spacing))
    }
}
