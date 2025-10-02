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
        return self.padding(edges, UIScaleMetrics.scaledPadding(length))
    }
    
    /// Apply scaled padding to all edges (uses UIScaleMetrics on iOS, standard padding on macOS)
    func scaledPaddingAll(_ length: CGFloat) -> some View {
        return self.padding(UIScaleMetrics.scaledPadding(length))
    }
    
    /// Apply scaled frame (uses UIScaleMetrics on iOS, standard frame on macOS)
    func scaledFrame(width: CGFloat? = nil, height: CGFloat? = nil, alignment: Alignment = .center) -> some View {
        let scaledWidth = width.map { UIScaleMetrics.scaledPadding($0) }
        let scaledHeight = height.map { UIScaleMetrics.scaledPadding($0) }
        return self.frame(width: scaledWidth, height: scaledHeight, alignment: alignment)
    }
}

// MARK: - Cross-Platform Color Helpers
