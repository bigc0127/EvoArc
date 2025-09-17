import SwiftUI
import Combine

#if os(iOS)
import UIKit

/// Information needed to handle keyboard notifications
private struct KeyboardInfo: Sendable {
    let name: Notification.Name
    let keyboardFrame: CGRect?
    let animationDuration: Double?
    let animationCurveRaw: Int?
    
    init(from notification: Notification) {
        self.name = notification.name
        let userInfo = notification.userInfo
        self.keyboardFrame = (userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue
        self.animationDuration = userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double
        self.animationCurveRaw = userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? Int
    }
}

/// Manages keyboard height and animation timing for consistent URL bar positioning
@MainActor
final class KeyboardHeightManager: ObservableObject, Sendable {
    @Published private(set) var keyboardHeight: CGFloat = 0
    @Published private(set) var keyboardAnimationDuration: Double = 0.25
    @Published private(set) var keyboardAnimationCurve: UIView.AnimationCurve = .easeInOut
    
    private var notificationObservers: [NSObjectProtocol] = []
    
    init() {
        setupKeyboardNotifications()
    }
    
    private func setupKeyboardNotifications() {
        let showObserver = NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let info = KeyboardInfo(from: notification)
            guard let weakSelf = self else { return }
            Task { @MainActor [weakSelf] in
                weakSelf.handleKeyboardNotification(info)
            }
        }
        
        let hideObserver = NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let info = KeyboardInfo(from: notification)
            guard let weakSelf = self else { return }
            Task { @MainActor [weakSelf] in
                weakSelf.handleKeyboardNotification(info)
            }
        }
        
        notificationObservers = [showObserver, hideObserver]
    }
    
    private func handleKeyboardNotification(_ info: KeyboardInfo) {
        let isShowing = info.name == UIResponder.keyboardWillShowNotification
        
        // Get keyboard height
        if let keyboardFrame = info.keyboardFrame {
            keyboardHeight = isShowing ? keyboardFrame.height : 0
        }
        
        // Get animation duration
        if let animationDuration = info.animationDuration {
            keyboardAnimationDuration = animationDuration
        }
        
        // Get animation curve
        if let animationCurveRaw = info.animationCurveRaw,
           let animationCurve = UIView.AnimationCurve(rawValue: animationCurveRaw) {
            keyboardAnimationCurve = animationCurve
        }
    }
    
    deinit {
        notificationObservers.forEach { NotificationCenter.default.removeObserver($0) }
    }
}

#else

/// Stub implementation for non-iOS platforms
final class KeyboardHeightManager: ObservableObject, Sendable {
    @Published private(set) var keyboardHeight: CGFloat = 0
    @Published private(set) var keyboardAnimationDuration: Double = 0.25
}

#endif
