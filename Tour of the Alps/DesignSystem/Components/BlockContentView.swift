import SwiftUI

/// Renders the API's block content (post bodies, team and rider bios).
struct BlockContentView: View {
    let blocks: [ContentBlock]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(blocks) { block in
                switch block {
                case .paragraph(let html):
                    if let text = HTMLText.attributed(from: html) {
                        Text(text)
                            .font(.body)
                            .foregroundStyle(Brand.ink)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                case .heading(let text, let level):
                    Text(text)
                        .brandDisplay(level <= 2 ? BrandFont.title2() : BrandFont.title3())
                        .foregroundStyle(Brand.ink)
                case .image(let image):
                    VStack(alignment: .leading, spacing: 6) {
                        RemoteImage(url: image.url, contentMode: .fit)
                            .aspectRatio(image.aspectRatio ?? 1.5, contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        if let caption = image.caption?.nonEmpty {
                            Text(caption)
                                .font(.caption)
                                .foregroundStyle(Brand.inkMuted)
                        }
                    }
                case .unsupported:
                    EmptyView()
                }
            }
        }
    }
}

/// Converts the small HTML subset the CMS emits into an `AttributedString`.
///
/// This walks the tags and applies attributes directly rather than translating to
/// markdown first. Round-tripping through markdown looks simpler but corrupts real
/// content: `<strong> Trentino</strong>` becomes `** Trentino**`, which markdown refuses
/// to parse as emphasis (no space allowed after the delimiter) and renders as literal
/// asterisks — and any `*` already in the copy would be swallowed as syntax.
///
/// `NSAttributedString`'s HTML importer handles far more, but it's main-thread-only and
/// slow enough to stutter a scrolling article.
enum HTMLText {
    static func attributed(from html: String) -> AttributedString? {
        var result = AttributedString()
        var pending = ""
        var boldDepth = 0
        var italicDepth = 0
        var link: URL?

        func flushText() {
            guard !pending.isEmpty else { return }
            var piece = AttributedString(decodeEntities(pending))
            var intent: InlinePresentationIntent = []
            if boldDepth > 0 { intent.insert(.stronglyEmphasized) }
            if italicDepth > 0 { intent.insert(.emphasized) }
            if !intent.isEmpty { piece.inlinePresentationIntent = intent }
            if let link { piece.link = link }
            result += piece
            pending = ""
        }

        func handle(tag: String) {
            let isClosing = tag.hasPrefix("/")
            let body = isClosing ? String(tag.dropFirst()) : tag
            let name = body
                .prefix { !$0.isWhitespace && $0 != "/" }
                .lowercased()

            switch name {
            case "strong", "b":
                boldDepth = isClosing ? max(0, boldDepth - 1) : boldDepth + 1
            case "em", "i":
                italicDepth = isClosing ? max(0, italicDepth - 1) : italicDepth + 1
            case "a":
                link = isClosing ? nil : href(in: body)
            case "br":
                result += AttributedString("\n")
            case "p", "div":
                if isClosing { result += AttributedString("\n\n") }
            default:
                break  // Structural tag: drop it, keep whatever text it wrapped.
            }
        }

        var index = html.startIndex
        while index < html.endIndex {
            if html[index] == "<", let close = html[index...].firstIndex(of: ">") {
                flushText()
                handle(tag: String(html[html.index(after: index)..<close]))
                index = html.index(after: close)
            } else {
                pending.append(html[index])
                index = html.index(after: index)
            }
        }
        flushText()

        // Trim the trailing break left by a closing </p>.
        while let last = result.characters.last, last.isWhitespace || last.isNewline {
            result.removeSubrange(result.index(beforeCharacter: result.endIndex)..<result.endIndex)
        }
        return result.characters.isEmpty ? nil : result
    }

    private static func href(in tag: String) -> URL? {
        guard let range = tag.range(of: "href=\"") else { return nil }
        let rest = tag[range.upperBound...]
        guard let end = rest.firstIndex(of: "\"") else { return nil }
        return URL(string: String(rest[..<end]))
    }

    private static func decodeEntities(_ text: String) -> String {
        var output = text
        let named: [(String, String)] = [
            ("&nbsp;", "\u{00A0}"), ("&lt;", "<"), ("&gt;", ">"), ("&quot;", "\""),
            ("&rsquo;", "\u{2019}"), ("&lsquo;", "\u{2018}"), ("&ldquo;", "\u{201C}"),
            ("&rdquo;", "\u{201D}"), ("&ndash;", "–"), ("&mdash;", "—"), ("&hellip;", "…"),
            ("&eacute;", "é"), ("&egrave;", "è"), ("&agrave;", "à"), ("&ugrave;", "ù"),
            ("&ograve;", "ò"), ("&uuml;", "ü"), ("&ouml;", "ö"), ("&auml;", "ä"),
        ]
        for (entity, character) in named {
            output = output.replacingOccurrences(of: entity, with: character)
        }
        output = decodeNumericEntities(output)
        // Ampersand last, so a literal "&amp;lt;" doesn't become a tag delimiter.
        return output.replacingOccurrences(of: "&amp;", with: "&")
    }

    private static func decodeNumericEntities(_ text: String) -> String {
        guard text.contains("&#") else { return text }
        var output = ""
        var rest = Substring(text)
        while let start = rest.range(of: "&#"), let end = rest[start.upperBound...].firstIndex(of: ";") {
            let digits = rest[start.upperBound..<end]
            let isHex = digits.first == "x" || digits.first == "X"
            let value = UInt32(isHex ? String(digits.dropFirst()) : String(digits), radix: isHex ? 16 : 10)
            output += rest[..<start.lowerBound]
            if let value, let scalar = UnicodeScalar(value) {
                output.append(Character(scalar))
            } else {
                output += rest[start.lowerBound...end]
            }
            rest = rest[rest.index(after: end)...]
        }
        return output + rest
    }
}
