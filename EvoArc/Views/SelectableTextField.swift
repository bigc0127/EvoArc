import SwiftUI
import UIKit

struct SelectableTextField: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String
    @Binding var isEditing: Bool
    var onSubmit: () -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
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
    
    class Coordinator: NSObject, UITextFieldDelegate {
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
}