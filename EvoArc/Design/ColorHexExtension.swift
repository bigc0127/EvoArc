//
//  ColorHexExtension.swift
//  EvoArc
//
//  Extends SwiftUI's Color type with hex string support and utility methods.
//  Allows designers to specify colors using familiar hex codes like "#FF5733".
//
//  Features:
//  - Parse hex strings in multiple formats (RGB, RRGGBB, AARRGGBB)
//  - Convert colors back to hex strings
//  - Determine if a color is dark (for choosing readable text colors)
//
//  For Swift beginners:
//  - Extensions add functionality to existing types without modifying their source
//  - Color is a SwiftUI struct representing colors
//  - Hex colors are a common web/design format (e.g., "#FF5733" = orange)

import SwiftUI  // Color type that we're extending

// MARK: - Color Hex Extension

/// Extension that adds hex string initialization and utility methods to SwiftUI's Color.
extension Color {
    // MARK: - Hex String Initialization
    
    /// Creates a Color from a hexadecimal string.
    /// Supports multiple hex formats for flexibility:
    /// - "RGB" (3 chars): Each digit represents a color channel (e.g., "F00" = red)
    /// - "RRGGBB" (6 chars): Standard web hex format (e.g., "FF5733" = orange)
    /// - "AARRGGBB" (8 chars): With alpha/opacity channel (e.g., "80FF5733" = semi-transparent orange)
    /// 
    /// Prefix characters (#, 0x) are automatically stripped.
    /// Invalid hex strings default to black (#000000).
    /// 
    /// Examples:
    /// - Color(hex: "#FF5733") - Orange
    /// - Color(hex: "F00") - Red
    /// - Color(hex: "0x00FF00") - Green
    /// 
    /// For Swift beginners:
    /// - init is a special method that creates new instances
    /// - This custom initializer lets you write: Color(hex: "FF5733")
    /// - The original Color initializers still work (e.g., Color.red)
    init(hex: String) {
        /// Strip any non-alphanumeric characters (removes #, 0x, spaces, etc.).
        /// CharacterSet.alphanumerics.inverted matches everything EXCEPT letters and numbers.
        /// This cleans input like "#FF5733" to "FF5733".
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        
        /// Parse the hex string into an unsigned 64-bit integer.
        /// UInt64 is large enough to hold even 8-character hex values.
        /// 'var' because we'll write into it via the & parameter.
        var int: UInt64 = 0
        
        /// Scanner parses strings looking for specific patterns.
        /// scanHexInt64(&int) reads hexadecimal digits and stores the result in 'int'.
        /// The & passes the variable's address so Scanner can write to it (in-out parameter).
        Scanner(string: hex).scanHexInt64(&int)
        
        /// Declare variables for alpha (opacity), red, green, and blue channels.
        /// UInt64 holds integer values from 0-255 for each channel.
        /// We declare all four in one line for clarity.
        let a, r, g, b: UInt64
        
        /// Extract ARGB values based on hex string length.
        /// Different formats have different bit layouts:
        /// - 3 chars: RGB, 4 bits per channel (e.g., "F0A" = #FF00AA)
        /// - 6 chars: RRGGBB, 8 bits per channel (e.g., "FF00AA")
        /// - 8 chars: AARRGGBB, 8 bits per channel with alpha (e.g., "80FF00AA")
        switch hex.count {
        case 3:
            /// 3-character hex: each digit represents a channel (4-bit).
            /// Example: "F0A" means R=F, G=0, B=A
            /// 
            /// Bit operations explained:
            /// - (int >> 8): Shift right 8 bits to get the first digit
            /// - (int >> 4 & 0xF): Shift right 4 bits and mask to get middle digit
            /// - (int & 0xF): Mask to get last digit
            /// - * 17: Convert 4-bit value (0-15) to 8-bit (0-255) by multiplying
            ///   Example: 0xF * 17 = 15 * 17 = 255
            /// 
            /// (a, r, g, b) = tuple assignment sets all four variables at once.
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
            
        case 6:
            /// 6-character hex: standard RRGGBB format.
            /// Example: "FF00AA" means R=FF, G=00, B=AA
            /// 
            /// Bit operations:
            /// - int >> 16: Shift right 16 bits to get RR
            /// - int >> 8 & 0xFF: Shift right 8 bits and mask to get GG
            /// - int & 0xFF: Mask to get BB
            /// - 0xFF = 255 in hex, masks to get lowest 8 bits
            /// 
            /// Alpha defaults to 255 (fully opaque).
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
            
        case 8:
            /// 8-character hex: AARRGGBB format with alpha channel.
            /// Example: "80FF00AA" means A=80, R=FF, G=00, B=AA
            /// 
            /// Bit operations extract each byte (8 bits) from the 32-bit integer.
            /// Same pattern as 6-char but with alpha extracted from highest bits.
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
            
        default:
            /// Invalid length - default to black (0,0,0) with full opacity (255).
            /// This handles edge cases like empty strings or odd lengths.
            (a, r, g, b) = (255, 0, 0, 0)
        }
        /// Initialize the Color using the extracted ARGB values.
        /// Color's initializer expects values in 0.0-1.0 range, so we divide by 255.
        /// 
        /// For Swift beginners:
        /// - self.init calls another initializer on the same type
        /// - .sRGB specifies the color space (standard RGB)
        /// - Double(r) / 255 converts 0-255 integer to 0.0-1.0 float
        /// - 'opacity' is the alpha/transparency channel (1.0 = opaque, 0.0 = transparent)
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    // MARK: - Hex String Conversion
    
    /// Converts this Color to a hexadecimal string representation.
    /// Returns a 6-character hex string (RRGGBB format) without alpha channel.
    /// 
    /// Example: Color.red.toHex() returns "FF0000"
    /// 
    /// For Swift beginners:
    /// - func means this is a method (function on a type)
    /// - () -> String means takes no parameters and returns a String
    /// - Methods can access 'self' (the Color instance they're called on)
    func toHex() -> String {
        /// Convert SwiftUI Color to UIKit UIColor for component extraction.
        /// SwiftUI's Color doesn't provide direct RGB access, but UIColor does.
        let uiColor = UIColor(self)
        
        /// Declare variables to receive the color components.
        /// CGFloat is the graphics framework's floating-point type.
        /// Initialize to 0 as a safe default.
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        
        /// Extract RGB and alpha values from the UIColor.
        /// getRed writes values into our variables via & (in-out parameters).
        /// Values are in 0.0-1.0 range.
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        
        /// Format as hex string.
        /// 
        /// String formatting explained:
        /// - format: "%02X%02X%02X" is a format template
        /// - %02X means: format as hexadecimal (%X), 2 digits wide (02)
        /// - Three %02X patterns create RRGGBB format
        /// - Int(r * 255) converts 0.0-1.0 back to 0-255 integer
        /// 
        /// Example: r=1.0, g=0.0, b=0.5 -> "FF0080"
        return String(format: "%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
    
    // MARK: - Brightness Detection
    
    /// Determines if this color is dark or light.
    /// Useful for choosing readable text colors (light text on dark bg, dark text on light bg).
    /// 
    /// Parameter threshold: Brightness value below which color is considered "dark" (default 0.75).
    ///   - Lower threshold = more colors considered "light"
    ///   - Higher threshold = more colors considered "dark"
    ///   - Range: 0.0 (black) to 1.0 (white)
    /// 
    /// Returns: true if color is dark, false if light.
    /// 
    /// Example uses:
    /// - Color.black.isDark() returns true
    /// - Color.white.isDark() returns false
    /// - Color.blue.isDark() depends on shade and threshold
    func isDark(threshold: Double = 0.75) -> Bool {
        /// Convert to UIColor to access color components.
        let uiColor = UIColor(self)
        
        /// Declare variables for red, green, blue, alpha components.
        /// Each on separate line for clarity.
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        
        /// Extract RGB values (0.0-1.0 range).
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        
        /// Calculate perceived brightness using luminance formula.
        /// 
        /// This formula accounts for human eye sensitivity:
        /// - Eyes are most sensitive to green (coefficient 0.587)
        /// - Moderately sensitive to red (0.299)
        /// - Least sensitive to blue (0.114)
        /// 
        /// The coefficients sum to 1.0 (0.299 + 0.587 + 0.114 = 1.0)
        /// Result is a value from 0.0 (black) to 1.0 (white)
        /// 
        /// This is the ITU-R BT.601 luminance formula, standard for digital color.
        let brightness = (0.299 * r + 0.587 * g + 0.114 * b)
        
        /// Compare brightness to threshold.
        /// If brightness is below threshold, color is dark.
        /// Example: brightness=0.3, threshold=0.75 -> 0.3 < 0.75 -> true (dark)
        return brightness < threshold
    }
}
