import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

public enum TypingPalette {
    static var practiceSurface: Color {
        #if os(macOS)
        Color(nsColor: .controlBackgroundColor)
        #else
        Color(uiColor: .secondarySystemBackground)
        #endif
    }

    static var practiceInputBackground: Color {
        #if os(macOS)
        Color(nsColor: .textBackgroundColor)
        #else
        Color(uiColor: .systemBackground)
        #endif
    }

    // MARK: - Surfaces
    public static let windowBackground = dynamicColor(light: 0xF6F5F2, dark: 0x121316)
    public static let codeCanvas = dynamicColor(light: 0xFFFFFF, dark: 0x181A1F)
    public static let activeLine = dynamicColor(light: 0xF0F4FF, dark: 0x1F2430)

    // MARK: - Borders
    public static let subtleBorder = dynamicColor(light: 0xE4E2DD, dark: 0x282C34)
    public static let lineMatchedBorder = dynamicColor(light: 0x10B981, dark: 0x34D399)

    // MARK: - Status Indicators
    public static let statusClean = dynamicColor(light: 0x16A34A, dark: 0x4ADE80)
    public static let statusCorrected = dynamicColor(light: 0xD97706, dark: 0xFBBF24)
    public static let statusHinted = dynamicColor(light: 0x7C3AED, dark: 0xA78BFA)
    public static let statusError = dynamicColor(light: 0xDC2626, dark: 0xF87171)

    #if os(macOS)
    // AppKit counterparts for TextKit 2
    public static var nsErrorUnderline: NSColor {
        NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(red: 1.0, green: 0.42, blue: 0.42, alpha: 1.0)   // #FF6B6B warm coral
                : NSColor(red: 0.85, green: 0.22, blue: 0.23, alpha: 1.0)  // #D9383A
        }
    }

    public static var nsErrorBackgroundTint: NSColor {
        NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(red: 1.0, green: 0.42, blue: 0.42, alpha: 0.16)
                : NSColor(red: 0.85, green: 0.22, blue: 0.23, alpha: 0.12)
        }
    }
    #endif

    public static let syntaxKeyword = dynamicColor(light: 0x4C5BAD, dark: 0x82AAFF)
    public static let syntaxType = dynamicColor(light: 0x08766D, dark: 0x4FD1C5)
    public static let syntaxString = dynamicColor(light: 0x2E6C32, dark: 0xC3E88D)
    public static let syntaxNumber = dynamicColor(light: 0x9C4808, dark: 0xF78C6C)
    public static let syntaxComment = dynamicColor(light: 0x5F636F, dark: 0xA0A5AF)

    private static func dynamicColor(light: UInt32, dark: UInt32) -> Color {
        #if os(macOS)
        return Color(nsColor: NSColor(name: nil) { appearance in
            let rgb = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
            let (red, green, blue) = colorComponents(rgb)
            return NSColor(srgbRed: red, green: green, blue: blue, alpha: 1)
        })
        #else
        return Color(uiColor: UIColor { traits in
            let rgb = traits.userInterfaceStyle == .dark ? dark : light
            let (red, green, blue) = colorComponents(rgb)
            return UIColor(red: red, green: green, blue: blue, alpha: 1)
        })
        #endif
    }

    private static func colorComponents(_ rgb: UInt32) -> (CGFloat, CGFloat, CGFloat) {
        (CGFloat((rgb >> 16) & 0xff) / 255, CGFloat((rgb >> 8) & 0xff) / 255, CGFloat(rgb & 0xff) / 255)
    }
}
