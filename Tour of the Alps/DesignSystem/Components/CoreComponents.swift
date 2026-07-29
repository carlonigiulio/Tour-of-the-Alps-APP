import SwiftUI

/// Image loader over `AsyncImage`, backed by the app's shared `URLCache` so previously
/// seen Cloudinary assets render offline.
struct RemoteImage: View {
    let url: URL?
    var contentMode: ContentMode = .fill

    var body: some View {
        AsyncImage(url: url, transaction: Transaction(animation: .easeOut(duration: 0.2))) { phase in
            switch phase {
            case .success(let image):
                image.resizable().aspectRatio(contentMode: contentMode)
            case .failure:
                Brand.surfaceAlt.overlay(
                    Image(systemName: "photo")
                        .font(.title3)
                        .foregroundStyle(Brand.inkMuted)
                )
            default:
                Brand.surfaceAlt
            }
        }
    }
}

extension View {
    /// Pins a photo to a fixed height and the *proposed* width.
    ///
    /// An aspect-fill image has no bounded ideal width, so sizing one with only
    /// `.frame(height:)` lets it report its natural width and stretch every ancestor —
    /// which, inside a ScrollView, drags the entire page wider than the screen. Sizing a
    /// clear box instead and overlaying the image keeps layout driven by the container.
    /// `alignment` decides which part survives the crop — `.top` for portrait subjects
    /// such as rider photos, whose `hero` preset is a centred 16:9 cut that would
    /// otherwise slice the head off.
    func photoFrame(height: CGFloat, alignment: Alignment = .center) -> some View {
        Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .overlay(alignment: alignment) { self }
            .clipped()
            .contentShape(Rectangle())
    }
}

/// Difficulty 1–4 as four chevrons, filled to the stage's rating.
struct DifficultyMeter: View {
    let level: Int
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...4, id: \.self) { index in
                Image(systemName: "chevron.up")
                    .font(.system(size: compact ? 8 : 10, weight: .black))
                    .foregroundStyle(index <= level ? Brand.difficulty(level) : Brand.inkMuted.opacity(0.35))
            }
        }
        .accessibilityElement()
        .accessibilityLabel(Text("Difficulty \(level) of 4"))
    }
}

/// Number over an uppercase label — the stat row under stage heroes.
struct StatTile: View {
    /// Data, so it stays a plain `String`; only `label` is UI copy.
    let value: String
    let label: LocalizedStringKey
    var tint: Color = Brand.ink

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(BrandFont.numeric(.title3, weight: .heavy))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .brandDisplay(BrandFont.eyebrow(11), tracking: 0.9)
                .foregroundStyle(Brand.inkMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// Skewed green marker used for stage numbers and category tags.
struct BrandChip: View {
    let text: String
    var filled: Bool = true
    var tint: Color = Brand.green

    var body: some View {
        Text(text)
            .brandDisplay(BrandFont.eyebrow(12), tracking: 1)
            .foregroundStyle(filled ? .white : tint)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background {
                if filled {
                    Slug().fill(tint)
                } else {
                    Slug().stroke(tint, lineWidth: 1.5)
                }
            }
    }
}

/// Country code rendered as a flag where the code maps to a region, falling back to
/// the code itself for the 3-letter UCI nationalities the results feed uses.
struct CountryBadge: View {
    let code: String?

    private static let uciToISO: [String: String] = [
        "ITA": "IT", "GER": "DE", "AUT": "AT", "SUI": "CH", "FRA": "FR", "ESP": "ES",
        "NED": "NL", "BEL": "BE", "GBR": "GB", "USA": "US", "AUS": "AU", "COL": "CO",
        "SLO": "SI", "POR": "PT", "DEN": "DK", "NOR": "NO", "SWE": "SE", "POL": "PL",
        "CZE": "CZ", "SVK": "SK", "RUS": "RU", "UKR": "UA", "JPN": "JP", "CAN": "CA",
        "NZL": "NZ", "IRL": "IE", "LUX": "LU", "ERI": "ER", "RSA": "ZA", "KAZ": "KZ",
        "EST": "EE", "LAT": "LV", "LTU": "LT", "CRO": "HR", "HUN": "HU", "ROU": "RO",
        "BUL": "BG", "GRE": "GR", "TUR": "TR", "MEX": "MX", "ARG": "AR", "BRA": "BR",
        "CHI": "CL", "ECU": "EC", "VEN": "VE", "URU": "UY", "ISR": "IL", "FIN": "FI",
    ]

    var body: some View {
        if let flag = Self.flag(for: code) {
            Text(flag).font(.system(size: 13))
        } else if let code = Self.displayCode(code) {
            Text(code)
                .font(.system(.caption2, design: .rounded).weight(.bold))
                .foregroundStyle(Brand.inkMuted)
        }
    }

    /// The results feed uses `***` as a placeholder for an unknown nationality; show
    /// nothing rather than the placeholder.
    private static func displayCode(_ code: String?) -> String? {
        guard let code = code?.nonEmpty, code.allSatisfy(\.isLetter) else { return nil }
        return code
    }

    static func flag(for code: String?) -> String? {
        guard let code = displayCode(code)?.uppercased() else { return nil }
        let iso = code.count == 3 ? uciToISO[code] : code
        guard let iso, iso.count == 2 else { return nil }
        let scalars = iso.unicodeScalars.compactMap { UnicodeScalar(127397 + $0.value) }
        guard scalars.count == 2 else { return nil }
        return String(String.UnicodeScalarView(scalars))
    }
}
