import SwiftUI

struct EngineModeBorder: ViewModifier {
    let engineType: BrowserEngine
    
    var engineColor: Color {
        switch engineType {
        case .webkit:
            return .blue
        case .blink:
            return .orange
        }
    }
    
    func body(content: Content) -> some View {
        content
            .overlay(
                Circle()
                    .stroke(engineColor, lineWidth: 1)
            )
            .background(Color(.systemBackground).opacity(0.8))
            .shadow(color: .black.opacity(0.1), radius: 1)
    }
}

extension View {
    func engineModeBorder(_ engine: BrowserEngine) -> some View {
        modifier(EngineModeBorder(engineType: engine))
    }
}