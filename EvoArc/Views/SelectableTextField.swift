import SwiftUI

#if os(iOS)
import UIKit
typealias PlatformViewRepresentable = UIViewRepresentable
typealias PlatformTextField = UITextField
typealias PlatformTextFieldDelegate = UITextFieldDelegate
#else
import AppKit
typealias PlatformViewRepresentable = NSViewRepresentable
typealias PlatformTextField = NSTextField
typealias PlatformTextFieldDelegate = NSTextFieldDelegate
#endif

struct SelectableTextField: PlatformViewRepresentable {
    @Binding var text: String
    var placeholder: String
    @Binding var isEditing: Bool
    var onSubmit: () -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
#if os(iOS)
    func makeUIView(context: Context) -> PlatformTextField {
    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.delegate = context.coordinator
        textField.font = .preferredFont(forTextStyle: .body)
        textField.placeholder = placeholder
        textField.clearButtonMode = .whileEditing
        textField.returnKeyType = .go
        textField.adjustsFontSizeToFitWidth = true
        textField.minimumFontSize = 12
        textField.translatesAutoresizingMaskIntoConstraints = false
        
        // Set content hugging and compression resistance
        textField.setContentHuggingPriority(.defaultLow - 1, for: .horizontal)
        textField.setContentCompressionResistancePriority(.required, for: .horizontal)
        
        // No explicit height constraint - let the parent view control the size
        
        // Add target for text changes
        textField.addTarget(context.coordinator, action: #selector(Coordinator.textFieldDidChange(_:)), for: .editingChanged)
        
        return textField
    }
    
    func updateUIView(_ uiView: UITextField, context: Context) {
        uiView.text = text
        
        // Handle focus changes
        if isEditing {
            if !uiView.isFirstResponder {
                uiView.becomeFirstResponder()
                // Select all text after becoming first responder
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    uiView.selectedTextRange = uiView.textRange(from: uiView.beginningOfDocument, to: uiView.endOfDocument)
                }
            }
        } else {
            if uiView.isFirstResponder {
                uiView.resignFirstResponder()
            }
        }
    }
    
    class Coordinator: NSObject, PlatformTextFieldDelegate {
        var parent: SelectableTextField
        
        init(_ textField: SelectableTextField) {
            self.parent = textField
        }
        
        @objc func textFieldDidChange(_ textField: UITextField) {
            parent.text = textField.text ?? ""
        }
        
        func textFieldDidBeginEditing(_ textField: UITextField) {
            parent.isEditing = true
            // Select all text when editing begins
            textField.selectedTextRange = textField.textRange(from: textField.beginningOfDocument, to: textField.endOfDocument)
        }
        
        func textFieldDidEndEditing(_ textField: UITextField) {
            parent.isEditing = false
        }
        
        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            parent.onSubmit()
            return true
        }
    }
#else
    func makeNSView(context: Context) -> PlatformTextField {
        let textField = NSTextField()
        textField.delegate = context.coordinator
        textField.font = .systemFont(ofSize: NSFont.systemFontSize)
        textField.placeholderString = placeholder
        textField.bezelStyle = .roundedBezel
        textField.translatesAutoresizingMaskIntoConstraints = false
        
        // Set content hugging and compression resistance
        textField.setContentHuggingPriority(.defaultLow - 1, for: .horizontal)
        textField.setContentCompressionResistancePriority(.required, for: .horizontal)
        
        return textField
    }
    
    func updateNSView(_ nsView: NSTextField, context: Context) {
        nsView.stringValue = text
        
        // Handle focus changes
        if isEditing {
            if !nsView.window?.firstResponder.isEqual(nsView) ?? true {
                nsView.window?.makeFirstResponder(nsView)
                // Select all text after becoming first responder
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    nsView.selectAll(nil)
                }
            }
        } else {
            if nsView.window?.firstResponder.isEqual(nsView) ?? false {
                nsView.window?.makeFirstResponder(nil)
            }
        }
    }
    
    class Coordinator: NSObject, PlatformTextFieldDelegate {
        var parent: SelectableTextField
        
        init(_ textField: SelectableTextField) {
            self.parent = textField
        }
        
        func controlTextDidChange(_ notification: Notification) {
            guard let textField = notification.object as? NSTextField else { return }
            parent.text = textField.stringValue
        }
        
        func controlTextDidBeginEditing(_ notification: Notification) {
            parent.isEditing = true
            // Select all text when editing begins
            if let textField = notification.object as? NSTextField {
                textField.selectAll(nil)
            }
        }
        
        func controlTextDidEndEditing(_ notification: Notification) {
            parent.isEditing = false
        }
        
        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                parent.onSubmit()
                return true
            }
            return false
        }
    }
#endif
}
