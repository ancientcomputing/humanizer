import SwiftUI
import AppKit

/// Color scheme ported 1:1 from web/static/styles.css's :root / dark-mode CSS variables,
/// so the native app looks like the same product as the web version.
enum AppTheme {
    private static func dynamic(light: NSColor, dark: NSColor) -> Color {
        Color(NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
        })
    }

    private static func hex(_ hex: String) -> NSColor {
        var value: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&value)
        let r = Double((value >> 16) & 0xFF) / 255.0
        let g = Double((value >> 8) & 0xFF) / 255.0
        let b = Double(value & 0xFF) / 255.0
        return NSColor(red: r, green: g, blue: b, alpha: 1.0)
    }

    static let background = dynamic(light: hex("f7f6f3"), dark: hex("17140f"))
    static let panel = dynamic(light: hex("ffffff"), dark: hex("211d17"))
    static let text = dynamic(light: hex("1f1c17"), dark: hex("ece7dd"))
    static let muted = dynamic(light: hex("6b6459"), dark: hex("a89e8d"))
    static let border = dynamic(light: hex("e2ddd3"), dark: hex("3a342a"))
    static let accent = dynamic(light: hex("b5502d"), dark: hex("d9723f"))
    static let accentHover = dynamic(light: hex("9c4426"), dark: hex("e78753"))
    static let accentText = dynamic(light: hex("ffffff"), dark: hex("1c1108"))
    static let buttonBackground = dynamic(light: hex("ece8e0"), dark: hex("322c22"))
    static let buttonBackgroundHover = dynamic(light: hex("e0dbd0"), dark: hex("3d3629"))
    static let buttonBorder = dynamic(light: hex("c9c2b3"), dark: hex("574e3c"))
}
