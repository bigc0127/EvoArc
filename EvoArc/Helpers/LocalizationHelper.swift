//
//  LocalizationHelper.swift
//  EvoArc
//
//  Helper extension for easier localization throughout the app.
//  Provides a convenient way to localize strings without verbose NSLocalizedString calls.
//

import Foundation

/// Extension to make localization more convenient
extension String {
    /// Returns the localized version of this string
    ///
    /// Usage:
    /// ```swift
    /// Text("bookmarks".localized)
    /// // Instead of: Text(NSLocalizedString("bookmarks", comment: ""))
    /// ```
    var localized: String {
        NSLocalizedString(self, comment: "")
    }
    
    /// Returns the localized version of this string with a specific comment
    ///
    /// Usage:
    /// ```swift
    /// let text = "bookmarks".localized(comment: "Title for bookmarks section")
    /// ```
    func localized(comment: String) -> String {
        NSLocalizedString(self, comment: comment)
    }
    
    /// Returns the localized version with format arguments
    ///
    /// Usage:
    /// ```swift
    /// let message = "delete_items_count".localizedWith(count)
    /// // For string: "Delete %d items"
    /// ```
    func localizedWith(_ arguments: CVarArg...) -> String {
        String(format: NSLocalizedString(self, comment: ""), arguments: arguments)
    }
}
