//
//  PlatformTypes.swift
//  EvoArc
//
//  Created on 2025-09-28.
//

import Foundation

#if os(iOS)
import UIKit
public typealias PlatformImage = UIImage
public typealias PlatformColor = UIColor
#else
import AppKit
public typealias PlatformImage = NSImage
public typealias PlatformColor = NSColor
#endif