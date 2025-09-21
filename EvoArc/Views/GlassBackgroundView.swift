import SwiftUI

#if os(iOS)
struct GlassBackgroundView: UIViewRepresentable {
    let style: UIBlurEffect.Style
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        let blurEffect = UIBlurEffect(style: style)
        let view = UIVisualEffectView(effect: blurEffect)
        
        // Add vibrancy effect for the liquid glass look
        let vibrancyEffect = UIVibrancyEffect(blurEffect: blurEffect, style: .secondaryFill)
        let vibrancyView = UIVisualEffectView(effect: vibrancyEffect)
        vibrancyView.frame = view.bounds
        vibrancyView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.contentView.addSubview(vibrancyView)
        
        // Reduce the intensity for a more subtle effect
        view.alpha = 0.85
        
        return view
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        // Update vibrancy view if needed
        if let vibrancyView = uiView.contentView.subviews.first as? UIVisualEffectView {
            vibrancyView.frame = uiView.bounds
        }
    }
}
#endif