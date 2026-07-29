import SwiftUI

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }

    /// Resolves per colour scheme without needing an asset catalog entry.
    static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(UIColor { traits in
            UIColor(Color(hex: traits.userInterfaceStyle == .dark ? dark : light))
        })
    }
}

/// Brand tokens extracted from tourofthealps.eu.
///
/// The brand green (`#57A005`) is too dark to read on dark surfaces, so the token keeps
/// its name and shifts value by scheme — call sites never branch on colour scheme.
enum Brand {
    static let green = Color.adaptive(light: 0x57A005, dark: 0x6FBF14)
    static let greenDeep = Color.adaptive(light: 0x407900, dark: 0x57A005)
    /// Fixed green for use on top of photography, where the backdrop is dark in both schemes.
    static let greenOnPhoto = Color(hex: 0x57A005)

    static let ink = Color.adaptive(light: 0x2A2A37, dark: 0xF4F4F7)
    static let inkMuted = Color.adaptive(light: 0x9797B0, dark: 0x8E8EA8)

    static let surface = Color.adaptive(light: 0xFFFFFF, dark: 0x16161C)
    static let surfaceAlt = Color.adaptive(light: 0xF0F2F4, dark: 0x1F1F27)
    static let surfaceSubtle = Color.adaptive(light: 0xFAFAFB, dark: 0x23232C)

    static let hairline = Color.adaptive(light: 0xE4E7EB, dark: 0x30303C)

    /// Difficulty 1–4 ramps from the deep green through to the brand green.
    static func difficulty(_ level: Int) -> Color {
        switch level {
        case ...1: Color(hex: 0x8DC63F)
        case 2: Color(hex: 0x6FB012)
        case 3: Color(hex: 0x57A005)
        default: Color(hex: 0x407900)
        }
    }
}

enum Metrics {
    static let gutter: CGFloat = 20
    static let cardRadius: CGFloat = 18
    /// Rise of the signature angled edge, in points.
    static let slant: CGFloat = 28
}
