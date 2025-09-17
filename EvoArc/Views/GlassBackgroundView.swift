import SwiftUI

#if os(iOS)
struct GlassBackgroundView: UIViewRepresentable {
    let style: UIBlurEffect.Style
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        let blurEffect = UIBlurEffect(style: style)
        let view = UIVisualEffectView(effect: blurEffect)
        return view
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        // Updates if needed
    }
}
#endif