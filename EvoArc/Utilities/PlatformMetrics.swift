//
//  PlatformMetrics.swift
//  EvoArc
//
//  Created on 2025-09-28.
//

import SwiftUI

import UIKit

/// Utility class to manage UI scaling factors and calculations for accessibility support
class PlatformMetrics {
    /// Maximum allowed scale factor to prevent UI elements from becoming too large
    private static let maxScaleFactor: CGFloat = 1.5
    
    /// Base padding values that will be scaled
    private static let basePaddings: [CGFloat] = [4, 8, 12, 16, 20, 24]
    
    /// Get the appropriate scale factor
    /// - Returns: A scale factor capped at the maximum allowed value
    static var defaultScaleFactor: CGFloat {
        let metrics = UIFontMetrics(forTextStyle: .body)
        let baseSize: CGFloat = 17 // body text base size
        let scaledSize = metrics.scaledValue(for: baseSize)
        return min(scaledSize / baseSize, maxScaleFactor)
    }
    
    /// Calculate a scaled dimension while respecting maximum limits
    /// - Parameter dimension: The base dimension to scale
    /// - Returns: The scaled dimension, capped at a reasonable maximum
    static func maxDimension(_ dimension: CGFloat) -> CGFloat {
        let baseScale = defaultScaleFactor
        return min(dimension * baseScale, dimension * maxScaleFactor)
    }
    
    /// Get a scaled padding value based on a base padding constant
    /// - Parameter base: The base padding value to scale
    /// - Returns: A scaled padding value that maintains visual harmony
    static func scaledPadding(_ base: CGFloat) -> CGFloat {
        // Find the closest standard padding value
        let closestBase = basePaddings.min { abs($0 - base) < abs($1 - base) } ?? base
        let baseScale = defaultScaleFactor
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
        let baseScale = defaultScaleFactor
        let scaled = baseSize * baseScale
        return max(min(scaled, baseSize * maxScaleFactor), minimumTapTarget)
    }
    
    /// Calculate icon size relative to text
    /// - Parameter baseSize: The default icon size
    /// - Returns: A scaled icon size that maintains proportion with text
    static func iconSize(_ baseSize: CGFloat) -> CGFloat {
        let baseScale = defaultScaleFactor
        let scaled = baseSize * baseScale
        return min(scaled, baseSize * maxScaleFactor)
    }
}