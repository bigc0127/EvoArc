//
//  PlatformMetrics.swift
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

/// Utility class to manage UI scaling factors and calculations for accessibility support
class PlatformMetrics {
    /// Maximum allowed scale factor to prevent UI elements from becoming too large
    private static let maxScaleFactor: CGFloat = 1.5
    
    /// Base padding values that will be scaled
    private static let basePaddings: [CGFloat] = [4, 8, 12, 16, 20, 24]
    
    /// Get the appropriate scale factor
    /// - Returns: A scale factor capped at the maximum allowed value
    static var defaultScaleFactor: CGFloat {
        #if os(iOS)
        let metrics = UIFontMetrics(forTextStyle: .body)
        let baseSize: CGFloat = 17 // body text base size
        let scaledSize = metrics.scaledValue(for: baseSize)
        return min(scaledSize / baseSize, maxScaleFactor)
        #else
        return 1.0 // No dynamic type on macOS
        #endif
    }
    
    /// Calculate a scaled dimension while respecting maximum limits
    /// - Parameter dimension: The base dimension to scale
    /// - Returns: The scaled dimension, capped at a reasonable maximum
    static func maxDimension(_ dimension: CGFloat) -> CGFloat {
        #if os(iOS)
        let baseScale = defaultScaleFactor
        return min(dimension * baseScale, dimension * maxScaleFactor)
        #else
        return dimension
        #endif
    }
    
    /// Get a scaled padding value based on a base padding constant
    /// - Parameter base: The base padding value to scale
    /// - Returns: A scaled padding value that maintains visual harmony
    static func scaledPadding(_ base: CGFloat) -> CGFloat {
        #if os(iOS)
        // Find the closest standard padding value
        let closestBase = basePaddings.min { abs($0 - base) < abs($1 - base) } ?? base
        let baseScale = defaultScaleFactor
        let scaled = closestBase * baseScale
        return min(scaled, closestBase * maxScaleFactor)
        #else
        return base
        #endif
    }
    
    /// Calculate appropriate button size based on content
    /// - Parameters:
    ///   - baseSize: The default button size
    ///   - hasLabel: Whether the button includes text label
    /// - Returns: A scaled button size that maintains tappability
    static func buttonSize(baseSize: CGFloat, hasLabel: Bool = false) -> CGFloat {
        #if os(iOS)
        let minimumTapTarget: CGFloat = 44 // Apple's recommended minimum
        let baseScale = defaultScaleFactor
        let scaled = baseSize * baseScale
        return max(min(scaled, baseSize * maxScaleFactor), minimumTapTarget)
        #else
        return baseSize
        #endif
    }
    
    /// Calculate icon size relative to text
    /// - Parameter baseSize: The default icon size
    /// - Returns: A scaled icon size that maintains proportion with text
    static func iconSize(_ baseSize: CGFloat) -> CGFloat {
        #if os(iOS)
        let baseScale = defaultScaleFactor
        let scaled = baseSize * baseScale
        return min(scaled, baseSize * maxScaleFactor)
        #else
        return baseSize
        #endif
    }
}

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