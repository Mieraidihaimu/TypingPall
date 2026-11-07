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

    // MARK: - Calm Contrast Syntax Tokens
    public static var syntaxKeyword: Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(red: 0x82/255.0, green: 0xAA/255.0, blue: 1.0, alpha: 1.0) // #82AAFF
                : NSColor(red: 0x5C/255.0, green: 0x6A/255.0, blue: 0xC4/255.0, alpha: 1.0) // #5C6AC4
        })
    }

    public static var syntaxType: Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(red: 0x4F/255.0, green: 0xD1/255.0, blue: 0xC5/255.0, alpha: 1.0) // #4FD1C5
                : NSColor(red: 0x0D/255.0, green: 0x94/255.0, blue: 0x88/255.0, alpha: 1.0) // #0D9488
        })
    }

    public static var syntaxString: Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(red: 0xC3/255.0, green: 0xE8/255.0, blue: 0x8D/255.0, alpha: 1.0) // #C3E88D
                : NSColor(red: 0x2E/255.0, green: 0x7D/255.0, blue: 0x32/255.0, alpha: 1.0) // #2E7D32
        })
    }

    public static var syntaxNumber: Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(red: 0xF7/255.0, green: 0x8C/255.0, blue: 0x6C/255.0, alpha: 1.0) // #F78C6C
                : NSColor(red: 0xB4/255.0, green: 0x53/255.0, blue: 0x09/255.0, alpha: 1.0) // #B45309
        })
    }

    public static var syntaxComment: Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(red: 0x54/255.0, green: 0x58/255.0, blue: 0x62/255.0, alpha: 1.0) // #545862
                : NSColor(red: 0x8C/255.0, green: 0x8D/255.0, blue: 0x92/255.0, alpha: 1.0) // #8C8D92
        })
    }
    #else
    static var statusCorrected: Color { .orange }
    static var syntaxKeyword: Color { .indigo }
    static var syntaxType: Color { .teal }
    static var syntaxString: Color { .green }
    static var syntaxNumber: Color { .purple }
    static var syntaxComment: Color { .secondary }
    #endif
}
