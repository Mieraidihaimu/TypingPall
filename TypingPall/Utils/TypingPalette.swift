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

    #if os(macOS)
    // MARK: - Surfaces
    public static var windowBackground: Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(red: 0x12/255.0, green: 0x13/255.0, blue: 0x16/255.0, alpha: 1.0)
                : NSColor(red: 0xF6/255.0, green: 0xF5/255.0, blue: 0xF2/255.0, alpha: 1.0)
        })
    }

    public static var codeCanvas: Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(red: 0x18/255.0, green: 0x1A/255.0, blue: 0x1F/255.0, alpha: 1.0)
                : NSColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        })
    }

    public static var activeLine: Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(red: 0x1F/255.0, green: 0x24/255.0, blue: 0x30/255.0, alpha: 1.0)
                : NSColor(red: 0xF0/255.0, green: 0xF4/255.0, blue: 1.0, alpha: 1.0)
        })
    }

    // MARK: - Borders
    public static var subtleBorder: Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(red: 0x28/255.0, green: 0x2C/255.0, blue: 0x34/255.0, alpha: 1.0)
                : NSColor(red: 0xE4/255.0, green: 0xE2/255.0, blue: 0xDD/255.0, alpha: 1.0)
        })
    }

    public static var lineMatchedBorder: Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(red: 0x34/255.0, green: 0xD3/255.0, blue: 0x99/255.0, alpha: 1.0)
                : NSColor(red: 0x10/255.0, green: 0xB9/255.0, blue: 0x81/255.0, alpha: 1.0)
        })
    }

    // MARK: - Status Indicators
    public static var statusClean: Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(red: 0x4A/255.0, green: 0xDE/255.0, blue: 0x80/255.0, alpha: 1.0)
                : NSColor(red: 0x16/255.0, green: 0xA3/255.0, blue: 0x4A/255.0, alpha: 1.0)
        })
    }

    public static var statusCorrected: Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(red: 0xFB/255.0, green: 0xBF/255.0, blue: 0x24/255.0, alpha: 1.0)
                : NSColor(red: 0xD9/255.0, green: 0x77/255.0, blue: 0x06/255.0, alpha: 1.0)
        })
    }

    public static var statusHinted: Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(red: 0xA7/255.0, green: 0x8B/255.0, blue: 0xFA/255.0, alpha: 1.0)
                : NSColor(red: 0x7C/255.0, green: 0x3A/255.0, blue: 0xED/255.0, alpha: 1.0)
        })
    }

    public static var statusError: Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(red: 0xF8/255.0, green: 0x71/255.0, blue: 0x71/255.0, alpha: 1.0)
                : NSColor(red: 0xDC/255.0, green: 0x26/255.0, blue: 0x26/255.0, alpha: 1.0)
        })
    }

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

    #else
    static var statusCorrected: Color { .orange }
    #endif

    public static let syntaxKeyword = syntaxColor(light: 0x4C5BAD, dark: 0x82AAFF)
    public static let syntaxType = syntaxColor(light: 0x08766D, dark: 0x4FD1C5)
    public static let syntaxString = syntaxColor(light: 0x2E6C32, dark: 0xC3E88D)
    public static let syntaxNumber = syntaxColor(light: 0x9C4808, dark: 0xF78C6C)
    public static let syntaxComment = syntaxColor(light: 0x5F636F, dark: 0xA0A5AF)

    private static func syntaxColor(light: UInt32, dark: UInt32) -> Color {
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
