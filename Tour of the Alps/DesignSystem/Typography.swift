import SwiftUI
import CoreText

/// Type scale. Gilvar-Heavy carries the display voice (always uppercase, slight positive
/// tracking); SF Pro carries everything meant to be read.
///
/// Every Gilvar step is registered `relativeTo:` a system text style so the custom font
/// still responds to Dynamic Type instead of staying pinned at a fixed size.
///
/// The face has very compact vertical metrics, so these deliberately do *not* apply
/// `.leading(.tight)` — `brandDisplay` adds positive line spacing on top of the standard
/// leading, otherwise stacked uppercase lines collide.
enum BrandFont {
    static let postScriptName = "Gilvar-Heavy"

    static func display(_ size: CGFloat = 40) -> Font {
        .custom(postScriptName, size: size, relativeTo: .largeTitle)
    }
    static func title1(_ size: CGFloat = 30) -> Font {
        .custom(postScriptName, size: size, relativeTo: .title)
    }
    static func title2(_ size: CGFloat = 22) -> Font {
        .custom(postScriptName, size: size, relativeTo: .title2)
    }
    static func title3(_ size: CGFloat = 17) -> Font {
        .custom(postScriptName, size: size, relativeTo: .headline)
    }
    static func eyebrow(_ size: CGFloat = 13) -> Font {
        .custom(postScriptName, size: size, relativeTo: .caption)
    }

    /// Times, gaps, dorsals and points must align in columns.
    static func numeric(_ style: Font.TextStyle = .body, weight: Font.Weight = .semibold) -> Font {
        .system(style, design: .rounded).weight(weight).monospacedDigit()
    }

    /// The font is registered via `UIAppFonts` in Info.plist. This is a belt-and-braces
    /// runtime registration so a missing plist entry degrades to a warning rather than
    /// silently falling back to the system face everywhere.
    static func registerIfNeeded() {
        guard UIFont(name: postScriptName, size: 12) == nil else { return }
        guard let url = Bundle.main.url(forResource: "Gilvar", withExtension: "ttf") else {
            assertionFailure("Gilvar.ttf is missing from the bundle")
            return
        }
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }
}

extension View {
    /// Applies a Gilvar display style: uppercase, tracked, with breathing room between
    /// lines. `lineSpacing` only affects multi-line text, so it is safe to apply to every
    /// step of the scale.
    func brandDisplay(_ font: Font, tracking: CGFloat = 0.5, lineSpacing: CGFloat = 5) -> some View {
        self.font(font)
            .textCase(.uppercase)
            .tracking(tracking)
            .lineSpacing(lineSpacing)
    }
}

/// Uppercase Gilvar section header with the brand's green rule.
struct SectionHeader: View {
    private let text: Text
    private let accent: Bool

    /// Literal call sites resolve through the String Catalog.
    init(title: LocalizedStringKey, accent: Bool = true) {
        self.text = Text(title)
        self.accent = accent
    }

    /// For titles that were already localized upstream (enum labels, API content),
    /// which must not be looked up a second time.
    init(verbatim title: String, accent: Bool = true) {
        self.text = Text(title)
        self.accent = accent
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            if accent {
                Rectangle()
                    .fill(Brand.green)
                    .frame(width: 5, height: 20)
            }
            text
                .brandDisplay(BrandFont.title2(), tracking: 0.8)
                .foregroundStyle(Brand.ink)
            Spacer(minLength: 0)
        }
        .accessibilityAddTraits(.isHeader)
    }
}
