import Foundation

/// A single sponsor logo.
///
/// `logo` is optional because the slots are currently unfilled: the app reserves and lays
/// out the space today, and the artwork arrives once the sponsors API exists.
struct Sponsor: Decodable, Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    let logo: ImageSet?
    let url: URL?
}

/// Which screen a placement belongs to.
///
/// The forthcoming API is expected to drive this per placement, so screens must never
/// hard-code which sponsors they show — they ask the store for their own page.
enum SponsorPage: String, Decodable, Sendable, CaseIterable {
    case home
    case stages
    case stageDetail = "stage_detail"
    case standings
    case standingDetail = "standing_detail"
    case teams
    case teamDetail = "team_detail"
    case news
    case postDetail = "post_detail"
}

/// How a placement renders. Kept deliberately small — the API picks one of these rather
/// than sending layout instructions.
enum SponsorPlacementStyle: String, Decodable, Sendable, Hashable {
    /// One prominent row, used mid-screen.
    case banner
    /// A denser row of smaller logos, used at the end of a list.
    case strip
    /// The full stack of every category, mirroring the website footer.
    case footer
}

/// Narrows a block to one instance of a screen — a specific stage or team.
///
/// The API documents this as "e.g. a stage number / team id" without pinning the type,
/// and the table is still empty, so it could arrive as a JSON number or a string. Both
/// are accepted and normalized to a string so comparisons stay uniform.
struct SponsorPageRef: Decodable, Hashable, Sendable {
    let value: String

    init(_ value: String) { self.value = value }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            value = string
        } else if let int = try? container.decode(Int.self) {
            value = String(int)
        } else {
            throw DecodingError.typeMismatch(
                SponsorPageRef.self,
                .init(codingPath: decoder.codingPath, debugDescription: "page_ref is neither string nor int")
            )
        }
    }
}

/// One sponsor block on one screen.
///
/// `order` decides the sequence when a page carries more than one block. `slotCount` is
/// what lets the layout be built before any logo exists: it says how many boxes to
/// reserve, so the spacing is already correct when `sponsors` fills in.
struct SponsorPlacement: Decodable, Identifiable, Sendable, Hashable {
    let id: Int
    /// Optional because the API declares `page` and `style` open-ended. Decoding them
    /// strictly would make one unrecognised value fail the *whole* array, silently
    /// dropping every sponsor in the app; instead an unknown block decodes with `nil`
    /// here and is simply never matched by a screen.
    let page: SponsorPage?
    /// `nil` means every instance of the page; otherwise only the matching one.
    let pageRef: SponsorPageRef?
    let style: SponsorPlacementStyle?
    let order: Int
    /// Already localized by the server, like every other piece of API text.
    let categoryLabel: String?
    let sponsors: [Sponsor]
    let slotCount: Int
    /// True only for the app's built-in reserved layout, never for server data. Lets the
    /// UI tell "space we invented to hold the design together" apart from "what the race
    /// actually sold", so a category name is never guessed on top of real sponsors.
    var isReserved: Bool = false

    /// Placeholder boxes to draw when the logos have not arrived yet.
    var placeholderCount: Int { sponsors.isEmpty ? max(slotCount, 1) : 0 }

    /// Does this block belong on the instance the screen is showing?
    func matches(ref: String?) -> Bool {
        guard let pageRef else { return true }
        return pageRef.value == ref
    }

    /// No snake_case raw values here: the shared decoder already applies
    /// `.convertFromSnakeCase`, so by this point the keys are `pageRef`, `categoryLabel`
    /// and `slotCount`. Spelling them `page_ref` etc. silently matched nothing and left
    /// every one of those three fields nil/zero.
    enum CodingKeys: String, CodingKey {
        case id, page, style, order, sponsors
        case pageRef, categoryLabel, slotCount
    }
}

// Declared in an extension so the memberwise initialiser survives for the built-in
// fallback layout.
extension SponsorPlacement {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        page = SponsorPage(rawValue: (try? c.decode(String.self, forKey: .page)) ?? "")
        pageRef = (try? c.decodeIfPresent(SponsorPageRef.self, forKey: .pageRef)) ?? nil
        style = SponsorPlacementStyle(rawValue: (try? c.decode(String.self, forKey: .style)) ?? "")
        order = (try? c.decode(Int.self, forKey: .order)) ?? 0
        categoryLabel = (try? c.decodeIfPresent(String.self, forKey: .categoryLabel)) ?? nil
        sponsors = (try? c.decode([Sponsor].self, forKey: .sponsors)) ?? []
        slotCount = (try? c.decode(Int.self, forKey: .slotCount)) ?? 0
    }
}
