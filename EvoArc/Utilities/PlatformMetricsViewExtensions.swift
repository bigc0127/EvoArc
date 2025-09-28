//
//  PlatformMetricsViewExtensions.swift
//  EvoArc
//
//  Created on 2025-09-28.
//

import SwiftUI

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

// MARK: - View Extension for Scaling
extension View {
    /// Apply scaling to frame dimensions
    /// - Parameters:
    ///   - width: The base width to scale
    ///   - height: The base height to scale
    /// - Returns: View with scaled frame
    func scaledFrame(width: CGFloat? = nil, height: CGFloat? = nil) -> some View {
        let scaledWidth = width.map { PlatformMetrics.maxDimension($0) }
        let scaledHeight = height.map { PlatformMetrics.maxDimension($0) }
        return frame(width: scaledWidth, height: scaledHeight)
    }
    
    /// Apply scaled padding
    /// - Parameter base: The base padding value to scale
    /// - Returns: View with scaled padding
    func scaledPadding(_ base: CGFloat) -> some View {
        padding(PlatformMetrics.scaledPadding(base))
    }
    
    /// Apply scaled padding to specific edges
    /// - Parameters:
    ///   - edges: The edges to apply padding to
    ///   - base: The base padding value to scale
    /// - Returns: View with scaled padding on specified edges
    func scaledPadding(_ edges: Edge.Set = .all, _ base: CGFloat) -> some View {
        padding(edges, PlatformMetrics.scaledPadding(base))
    }
}