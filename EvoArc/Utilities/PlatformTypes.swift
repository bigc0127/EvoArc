//
//  PlatformTypes.swift
//  EvoArc
//
//  Type aliases for platform-specific types (iOS/macOS cross-platform support).
//  Allows code to use generic "Platform" types that map to correct types per platform.
//
//  For Swift beginners:
//  - typealias creates an alternate name for an existing type
//  - public means accessible from other modules/targets
//  - This pattern enables cross-platform code (same code works on iOS and macOS)

import Foundation  // Core Swift functionality
import UIKit       // iOS UI framework (includes UIImage, UIColor)

// MARK: - Platform Type Aliases

/// Platform-agnostic image type.
/// Maps to UIImage on iOS/iPadOS, NSImage on macOS.
/// 
/// For Swift beginners:
/// - UIImage is iOS's image class
/// - This alias lets you write: PlatformImage instead of #if os(iOS) UIImage #else NSImage #endif
/// - Code using PlatformImage works on both platforms without conditional compilation
public typealias PlatformImage = UIImage

/// Platform-agnostic color type.
/// Maps to UIColor on iOS/iPadOS, NSColor on macOS.
/// 
/// Both UIColor and NSColor represent colors, but they're separate classes.
/// This alias provides a unified type name across platforms.
public typealias PlatformColor = UIColor
