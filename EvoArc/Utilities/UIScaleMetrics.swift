//
//  UIScaleMetrics.swift
//  EvoArc
//
//  Created by Connor W. Needling on 2025-09-17.
//

import SwiftUI

#if os(iOS)
/// Utility class to manage UI scaling factors and calculations for accessibility support
class UIScaleMetrics {
    /// Maximum allowed scale factor to prevent UI elements from becoming too large
    private static let maxScaleFactor: CGFloat = 1.5
    
    /// Base padding values that will be scaled
    private static let basePaddings: [CGFloat] = [4, 8, 12, 16, 20, 24]
    
    /// Get the appropriate scale factor for a given text style
    /// - Parameter textStyle: The SwiftUI text style to calculate scaling for
    /// - Returns: A scale factor capped at the maximum allowed value
    static func scaleFactor(for textStyle: Font.TextStyle) -> CGFloat {
        let metrics = UIFontMetrics(forTextStyle: textStyle.uiKit)
        let baseSize: CGFloat = textStyle.baseSize
        let scaledSize = metrics.scaledValue(for: baseSize)
        return min(scaledSize / baseSize, maxScaleFactor)
    }
    
    /// Calculate a scaled dimension while respecting maximum limits
    /// - Parameter dimension: The base dimension to scale
    /// - Returns: The scaled dimension, capped at a reasonable maximum
    static func maxDimension(_ dimension: CGFloat) -> CGFloat {
        let baseScale = scaleFactor(for: .body)
        return min(dimension * baseScale, dimension * maxScaleFactor)
    }
    
    /// Get a scaled padding value based on a base padding constant
    /// - Parameter base: The base padding value to scale
    /// - Returns: A scaled padding value that maintains visual harmony
    static func scaledPadding(_ base: CGFloat) -> CGFloat {
        // Find the closest standard padding value
        let closestBase = basePaddings.min { abs($0 - base) < abs($1 - base) } ?? base
        let baseScale = scaleFactor(for: .body)
        let scaled = closestBase * baseScale
        return min(scaled, closestBase * maxScaleFactor)
    }
    
    /// Calculate appropriate button size based on content
    /// - Parameters:
    ///   - baseSize: The default button size
    ///   - hasLabel: Whether the button includes text label
    /// - Returns: A scaled button size that maintains tappability
    static func buttonSize(baseSize: CGFloat, hasLabel: Bool = false) -> CGFloat {
        let minimumTapTarget: CGFloat = 44 // Apple's recommended minimum
        let baseScale = scaleFactor(for: hasLabel ? .callout : .body)
        let scaled = baseSize * baseScale
        return max(min(scaled, baseSize * maxScaleFactor), minimumTapTarget)
    }
    
    /// Calculate icon size relative to text
    /// - Parameter baseSize: The default icon size
    /// - Returns: A scaled icon size that maintains proportion with text
    static func iconSize(_ baseSize: CGFloat) -> CGFloat {
        let baseScale = scaleFactor(for: .body)
        let scaled = baseSize * baseScale
        return min(scaled, baseSize * maxScaleFactor)
    }
}

// MARK: - Font.TextStyle Extensions
extension Font.TextStyle {
    /// Convert SwiftUI text style to UIKit equivalent
    var uiKit: UIFont.TextStyle {
        switch self {
        case .largeTitle: return .largeTitle
        case .title: return .title1
        case .title2: return .title2
        case .title3: return .title3
        case .headline: return .headline
        case .subheadline: return .subheadline
        case .body: return .body
        case .callout: return .callout
        case .footnote: return .footnote
        case .caption: return .caption1
        case .caption2: return .caption2
        @unknown default: return .body
        }
    }
    
    /// Base point size for each text style
    var baseSize: CGFloat {
        switch self {
        case .largeTitle: return 34
        case .title: return 28
        case .title2: return 22
        case .title3: return 20
        case .headline: return 17
        case .subheadline: return 15
        case .body: return 17
        case .callout: return 16
        case .footnote: return 13
        case .caption: return 12
        case .caption2: return 11
        @unknown default: return 17
        }
    }
}

// MARK: - View Extension for Dynamic Type
extension View {
    /// Apply scaling to frame dimensions
    /// - Parameters:
    ///   - width: The base width to scale
    ///   - height: The base height to scale
    /// - Returns: View with scaled frame
    func scaledFrame(width: CGFloat? = nil, height: CGFloat? = nil) -> some View {
        let scaledWidth = width.map { UIScaleMetrics.maxDimension($0) }
        let scaledHeight = height.map { UIScaleMetrics.maxDimension($0) }
        return frame(width: scaledWidth, height: scaledHeight)
    }
    
    /// Apply scaled padding
    /// - Parameter base: The base padding value to scale
    /// - Returns: View with scaled padding
    func scaledPadding(_ base: CGFloat) -> some View {
        padding(UIScaleMetrics.scaledPadding(base))
    }
    
    /// Apply scaled padding to specific edges
    /// - Parameters:
    ///   - edges: The edges to apply padding to
    ///   - base: The base padding value to scale
    /// - Returns: View with scaled padding on specified edges
    func scaledPadding(_ edges: Edge.Set = .all, _ base: CGFloat) -> some View {
        padding(edges, UIScaleMetrics.scaledPadding(base))
    }
}
#endif