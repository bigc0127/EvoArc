//
//  TapIntentDetector.swift
//  EvoArc
//
//  Created on 2025-10-06.
//
//  This utility helps differentiate between intentional taps on web content
//  (like buttons, links, cookie consent forms) versus taps on empty areas meant
//  to reveal the hidden bottom bar.
//
//  User Intent Philosophy:
//  When a user taps in the bottom area of the screen while the bottom bar is hidden,
//  we need to infer their intent:
//  1. Are they trying to reveal the bottom bar? (tap on empty/background area)
//  2. Are they trying to click a webpage element? (tap on button/link/form)
//
//  Solution: Use JavaScript to inspect the element at the tap point and determine
//  if it's interactive (clickable) before deciding whether to show the bottom bar.

import Foundation
import WebKit

/// Utility for detecting user intent when tapping on web content
@available(iOS 13.0, *)
struct TapIntentDetector {
    
    // MARK: - JavaScript Element Detection
    
    /// JavaScript function that determines if an element at given coordinates is interactive.
    ///
    /// This function:
    /// 1. Gets the element at the specified x,y coordinates using `document.elementFromPoint`
    /// 2. Walks up the DOM tree examining each ancestor
    /// 3. Returns `true` if it finds any interactive element:
    ///    - Standard interactive tags: A, BUTTON, INPUT, SELECT, TEXTAREA, details
    ///    - Elements with onclick handlers
    ///    - Elements with role="button"
    ///    - Elements with cursor: pointer style
    /// 4. Returns `false` if only non-interactive elements are found
    ///
    /// **Why this approach?**
    /// Modern web pages often have complex interactive elements that aren't just `<button>` tags.
    /// Cookie consent forms, custom navigation bars, and other UI elements might use `<div>`
    /// tags with click handlers or pointer cursors. We need to detect all these cases.
    private static let jsElementDetectionFunction = """
    (function() {
        // Main detection function
        function isInteractiveAtPoint(x, y) {
            // Get the topmost element at this coordinate
            const element = document.elementFromPoint(x, y);
            if (!element) {
                return false;
            }
            
            // Walk up the DOM tree examining each ancestor
            let current = element;
            while (current) {
                const tagName = current.tagName ? current.tagName.toUpperCase() : '';
                
                // Check 1: Interactive HTML tags
                if (['A', 'BUTTON', 'INPUT', 'SELECT', 'TEXTAREA', 'DETAILS'].includes(tagName)) {
                    return true;
                }
                
                // Check 2: Elements with onclick handlers
                // Note: getAttribute captures both inline onclick and event listeners
                if (current.onclick || current.getAttribute('onclick')) {
                    return true;
                }
                
                // Check 3: ARIA role="button" (accessibility pattern)
                const role = current.getAttribute('role');
                if (role === 'button' || role === 'link') {
                    return true;
                }
                
                // Check 4: Computed cursor style
                // Many interactive elements have cursor: pointer
                try {
                    const style = window.getComputedStyle(current);
                    if (style && style.cursor === 'pointer') {
                        return true;
                    }
                } catch (e) {
                    // Ignore style computation errors
                }
                
                // Move up to parent
                current = current.parentElement;
            }
            
            // No interactive elements found in the hierarchy
            return false;
        }
        
        // Export the function for Swift to call
        return isInteractiveAtPoint;
    })();
    """
    
    // MARK: - Public API
    
    /// Determines if the tap at the given point hits an interactive web element.
    ///
    /// This method converts the tap point from view coordinates to page coordinates,
    /// then executes JavaScript to inspect the DOM element at that location.
    ///
    /// **Use case**: When the bottom bar is hidden and the user taps near the bottom
    /// of the screen, call this method to decide whether to show the bar (tap on empty area)
    /// or let the web page handle the tap (tap on button/link).
    ///
    /// **Coordinate conversion**:
    /// - `tapPointInView` is in the WKWebView's coordinate space
    /// - We convert to page coordinates by accounting for scroll offset and scaling
    ///
    /// **Timeout handling**:
    /// - JavaScript evaluation has a 100ms timeout to avoid UI lag
    /// - If timeout occurs, we default to `false` (treat as empty area, show bar)
    ///
    /// **Thread safety**:
    /// - `completion` is always called on the main thread
    /// - Safe to update UI based on the result
    ///
    /// - Parameters:
    ///   - webView: The web view to inspect
    ///   - tapPointInView: The tap location in the web view's coordinate space
    ///   - completion: Called with `true` if an interactive element was hit, `false` otherwise
    static func isInteractiveHit(
        in webView: WKWebView,
        tapPointInView: CGPoint,
        completion: @escaping (Bool) -> Void
    ) {
        // Convert tap point from view coordinates to page coordinates
        // The user might have scrolled, so we need to account for that
        let scrollView = webView.scrollView
        let pageX = (tapPointInView.x + scrollView.contentOffset.x) / scrollView.zoomScale
        let pageY = (tapPointInView.y + scrollView.contentOffset.y) / scrollView.zoomScale
        
        // Build the JavaScript code to execute
        // Format: Define function, then call it with our coordinates
        let jsCode = """
        \(jsElementDetectionFunction)
        isInteractiveAtPoint(\(pageX), \(pageY));
        """
        
        // Track if we've already completed (for timeout handling)
        var hasCompleted = false
        let completionQueue = DispatchQueue.main
        
        // Set up timeout: if JavaScript doesn't respond in 100ms, assume non-interactive
        // This prevents UI lag if the page is frozen or slow
        completionQueue.asyncAfter(deadline: .now() + 0.1) {
            if !hasCompleted {
                hasCompleted = true
                completion(false) // Timeout: treat as non-interactive, show bar
            }
        }
        
        // Execute JavaScript and process result
        webView.evaluateJavaScript(jsCode) { result, error in
            completionQueue.async {
                guard !hasCompleted else { return }
                hasCompleted = true
                
                // Check for errors
                if let error = error {
                    print("⚠️ TapIntentDetector: JS evaluation failed - \(error.localizedDescription)")
                    // On error, assume non-interactive (safe default: show bar)
                    completion(false)
                    return
                }
                
                // Parse result: JavaScript returns a boolean
                if let isInteractive = result as? Bool {
                    print("ℹ️ TapIntentDetector: Tap at (\(Int(pageX)), \(Int(pageY))) is \(isInteractive ? "INTERACTIVE" : "empty area")")
                    completion(isInteractive)
                } else {
                    // Unexpected result type
                    print("⚠️ TapIntentDetector: Unexpected JS result type: \(String(describing: result))")
                    completion(false)
                }
            }
        }
    }
}
