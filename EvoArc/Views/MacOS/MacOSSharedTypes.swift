//
//  MacOSSharedTypes.swift
//  EvoArc
//
//  Created on 2025-09-28.
//

import SwiftUI

#if os(macOS)

struct SuggestionRowData {
    let text: String
    let subtitle: String?
    let icon: String
    let action: () -> Void
}

#endif