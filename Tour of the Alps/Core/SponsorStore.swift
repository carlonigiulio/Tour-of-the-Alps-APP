import Foundation

/// Supplies the sponsor blocks for each screen.
///
/// Screens ask this store what to show on their own page; they never decide themselves.
/// That indirection is the whole point: when the sponsors endpoint ships, only
/// `load()` changes and every screen picks up placements, ordering and page assignment
/// from the server without being touched.
@MainActor
@Observable
final class SponsorStore {
    private(set) var placements: [SponsorPlacement] = []

    init() {
        placements = Self.reservedLayout
    }

    /// Blocks for one screen, in the order the source declared.
    ///
    /// `ref` identifies which instance of the screen is showing (stage number, team id…).
    /// Blocks with no `page_ref` apply to every instance; a targeted block only appears on
    /// its own.
    func placements(for page: SponsorPage, ref: String? = nil) -> [SponsorPlacement] {
        placements
            .filter { $0.page == page && $0.matches(ref: ref) }
            .sorted { $0.order < $1.order }
    }

    func load() async {
        // A failed request is not the same as "there are no sponsors". If the server was
        // unreachable the reserved layout stays in both builds, because the sponsors
        // probably exist and we simply could not fetch them.
        guard let remote = try? await TotaAPI.sponsors() else { return }

        guard remote.isEmpty else {
            placements = remote
            return
        }

        // The server explicitly says there is nothing. Release hides the sponsor sections
        // outright — an empty rectangle is worse than no section at all for a real user.
        // Debug keeps the placeholders so the layout stays visible and workable while the
        // sponsor tables are still unpopulated.
        #if DEBUG
        placements = Self.reservedLayout
        #else
        placements = []
        #endif
    }

    /// The space reserved today, mirroring the categories the race currently lists in the
    /// website footer. Slot counts match the real number of logos per category, so the
    /// layout being reserved is the layout that will eventually be filled.
    ///
    /// Category names come from the site: only "Local Authorities" is translated across
    /// languages, the other six are used in English in every locale.
    /// Computed rather than stored so the localized category names resolve on the main
    /// actor, and labelled explicitly here rather than guessed while rendering.
    private static var reservedLayout: [SponsorPlacement] {
        [
            SponsorPlacement(
                id: 1, page: .home, pageRef: nil, style: .banner, order: 0,
                categoryLabel: SponsorCategoryPreset.topPartners.label,
                sponsors: [], slotCount: 5, isReserved: true
            ),
            SponsorPlacement(
                id: 2, page: .home, pageRef: nil, style: .footer, order: 1,
                categoryLabel: nil, sponsors: [], slotCount: 0, isReserved: true
            ),
            SponsorPlacement(
                id: 3, page: .stageDetail, pageRef: nil, style: .banner, order: 0,
                categoryLabel: SponsorCategoryPreset.officialPartners.label,
                sponsors: [], slotCount: 5, isReserved: true
            ),
            SponsorPlacement(
                id: 4, page: .standingDetail, pageRef: nil, style: .strip, order: 0,
                categoryLabel: SponsorCategoryPreset.premiumPartners.label,
                sponsors: [], slotCount: 4, isReserved: true
            ),
            SponsorPlacement(
                id: 5, page: .teamDetail, pageRef: nil, style: .strip, order: 0,
                categoryLabel: SponsorCategoryPreset.officialSponsors.label,
                sponsors: [], slotCount: 5, isReserved: true
            ),
            SponsorPlacement(
                id: 6, page: .postDetail, pageRef: nil, style: .banner, order: 0,
                categoryLabel: SponsorCategoryPreset.mediaPartners.label,
                sponsors: [], slotCount: 3, isReserved: true
            ),
        ]
    }
}

/// The seven categories the race lists in its website footer, with the number of logos
/// each currently holds. Used to build the full footer block until the API supplies them.
enum SponsorCategoryPreset: String, CaseIterable, Sendable {
    case localAuthorities, topPartners, premiumPartners, officialPartners
    case officialSponsors, mediaPartners, officialSuppliers

    var label: String {
        switch self {
        case .localAuthorities: String(localized: "Local Authorities")
        case .topPartners: String(localized: "Top Partners")
        case .premiumPartners: String(localized: "Premium Partners")
        case .officialPartners: String(localized: "Official Partners")
        case .officialSponsors: String(localized: "Official Sponsors")
        case .mediaPartners: String(localized: "Media Partners")
        case .officialSuppliers: String(localized: "Official Suppliers")
        }
    }

    /// Logos currently in this category on tourofthealps.eu.
    var slotCount: Int {
        switch self {
        case .localAuthorities: 4
        case .topPartners: 5
        case .premiumPartners: 4
        case .officialPartners: 5
        case .officialSponsors: 5
        case .mediaPartners: 3
        case .officialSuppliers: 2
        }
    }
}
