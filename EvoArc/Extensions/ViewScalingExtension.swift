//
//  ViewScalingExtension.swift
//  EvoArc
//
//  Cross-platform view scaling helpers
//

import SwiftUI

// MARK: - View Extensions for Cross-Platform Scaling

extension View {
    /// Apply scaled padding to specific edges (uses UIScaleMetrics on iOS, standard padding on macOS)
    func scaledPadding(_ edges: Edge.Set, _ length: CGFloat) -> some View {
        #if os(iOS)
        return self.padding(edges, UIScaleMetrics.scaledPadding(length))
        #else
        return self.padding(edges, length)
        #endif
    }
    
    /// Apply scaled padding to all edges (uses UIScaleMetrics on iOS, standard padding on macOS)
    func scaledPaddingAll(_ length: CGFloat) -> some View {
        #if os(iOS)
        return self.padding(UIScaleMetrics.scaledPadding(length))
        #else
        return self.padding(length)
        #endif
    }
    
    /// Apply scaled frame (uses UIScaleMetrics on iOS, standard frame on macOS)
    func scaledFrame(width: CGFloat? = nil, height: CGFloat? = nil, alignment: Alignment = .center) -> some View {
        #if os(iOS)
        let scaledWidth = width.map { UIScaleMetrics.scaledPadding($0) }
        let scaledHeight = height.map { UIScaleMetrics.scaledPadding($0) }
        return self.frame(width: scaledWidth, height: scaledHeight, alignment: alignment)
        #else
        return self.frame(width: width, height: height, alignment: alignment)
        #endif
    }
}

// MARK: - Cross-Platform Color Helpers

#if os(macOS)
extension Color {
    /// Create Color from UIColor-style semantic colors (macOS compatibility)
    static func uiColor(_ nsColor: NSColor) -> Color {
        return Color(nsColor: nsColor)
    }
}

/// Compatibility shim for UIColor on macOS
typealias UIColor = NSColor
#endif