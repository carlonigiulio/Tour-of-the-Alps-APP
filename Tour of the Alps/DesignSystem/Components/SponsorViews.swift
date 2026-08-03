import SwiftUI

/// Wraps items onto as many rows as needed and centres each row.
///
/// `LazyVGrid` would leave a ragged last row pinned to the left — with 4 or 5 logos per
/// category that reads as a mistake. Centring each row matches how the race lays its
/// sponsors out on the website.
struct CenteredFlowLayout: Layout {
    var spacing: CGFloat = 10
    var itemWidth: CGFloat = 96
    var itemHeight: CGFloat = 54

    private func rows(count: Int, width: CGFloat) -> [Range<Int>] {
        let perRow = max(1, Int((width + spacing) / (itemWidth + spacing)))
        return stride(from: 0, to: count, by: perRow).map { start in
            start..<min(start + perRow, count)
        }
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? itemWidth
        guard !subviews.isEmpty else { return .zero }
        let rowCount = rows(count: subviews.count, width: width).count
        let height = CGFloat(rowCount) * itemHeight + CGFloat(rowCount - 1) * spacing
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in rows(count: subviews.count, width: bounds.width) {
            let n = CGFloat(row.count)
            let rowWidth = n * itemWidth + (n - 1) * spacing
            var x = bounds.minX + (bounds.width - rowWidth) / 2
            for index in row {
                subviews[index].place(
                    at: CGPoint(x: x, y: y),
                    proposal: ProposedViewSize(width: itemWidth, height: itemHeight)
                )
                x += itemWidth + spacing
            }
            y += itemHeight + spacing
        }
    }
}

/// One logo box.
///
/// Logos sit on white in both colour schemes on purpose: sponsor artwork is supplied for
/// light backgrounds and is very often solid dark ink, which would disappear against a
/// dark surface. Keeping the plate white is what makes the marks usable in dark mode.
struct SponsorSlot: View {
    var sponsor: Sponsor?
    var height: CGFloat = 54

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.white)

            if let sponsor {
                // Tight padding: several supplied assets already carry large empty
                // margins of their own, so adding much here shrinks them twice over.
                RemoteImage(url: sponsor.logo?.bestFull, contentMode: .fit)
                    .padding(6)
                    .accessibilityLabel(sponsor.name)
            } else {
                // Reserved, unfilled space: dashed outline reads as "intentionally empty"
                // rather than as a failed image.
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(
                        Brand.inkMuted.opacity(0.35),
                        style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                    )
            }
        }
        .frame(height: height)
        .accessibilityHidden(sponsor == nil)
    }
}

/// A titled row of logo boxes. Wraps onto multiple lines so a category with many logos
/// stays legible instead of shrinking each mark to nothing.
struct SponsorRow: View {
    let label: String?
    let sponsors: [Sponsor]
    let placeholderCount: Int
    var height: CGFloat = 54
    /// Fixed slot width, since the flow layout centres rows rather than stretching items.
    var minSlotWidth: CGFloat = 96

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let label, !label.isEmpty {
                Text(label)
                    .brandDisplay(BrandFont.eyebrow(11), tracking: 1.0)
                    .foregroundStyle(Brand.inkMuted)
            }

            CenteredFlowLayout(spacing: 10, itemWidth: minSlotWidth, itemHeight: height) {
                if sponsors.isEmpty {
                    ForEach(0..<placeholderCount, id: \.self) { _ in
                        SponsorSlot(height: height)
                    }
                } else {
                    ForEach(sponsors) { sponsor in
                        sponsorLink(sponsor)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func sponsorLink(_ sponsor: Sponsor) -> some View {
        if let url = sponsor.url {
            Link(destination: url) { SponsorSlot(sponsor: sponsor, height: height) }
        } else {
            SponsorSlot(sponsor: sponsor, height: height)
        }
    }
}

/// Renders whatever the store assigned to a screen. Screens embed this and stay unaware
/// of which sponsors, categories or ordering apply to them.
///
/// `styles` exists because a screen can offer more than one anchor point — the home page
/// has an inline slot mid-scroll and a full footer at the bottom — and those are physical
/// positions in the layout, not editorial decisions. Which category and which logos land
/// in each anchor still comes entirely from the store.
struct SponsorSection: View {
    let page: SponsorPage
    /// Which instance of the screen this is — stage number, team id, post id. Lets the
    /// server target a block at one stage or one team via `page_ref`.
    var ref: String? = nil
    var styles: Set<SponsorPlacementStyle> = [.banner, .strip, .footer]
    @Environment(SponsorStore.self) private var store

    var body: some View {
        let placements = store.placements(for: page, ref: ref).filter { placement in
            guard let style = placement.style else { return false }
            return styles.contains(style)
        }
        // Footer blocks are gathered rather than rendered one by one: the server is
        // expected to send one block *per category*, and each must become a row inside a
        // single "Sponsors" section, not seven repeated sections.
        let footers = placements.filter { $0.style == .footer }
        let inline = placements.filter { $0.style != .footer }

        if !placements.isEmpty {
            VStack(spacing: 20) {
                ForEach(inline) { placement in
                    if placement.style == .banner {
                        banner(placement)
                    } else {
                        strip(placement)
                    }
                }
                if !footers.isEmpty {
                    SponsorFooter(placements: footers)
                }
            }
        }
    }

    // No invented fallback label: putting a guessed category over real sponsors would
    // credit them to the wrong tier, which is worse than showing no heading at all.
    private func banner(_ p: SponsorPlacement) -> some View {
        SponsorRow(
            label: p.categoryLabel,
            sponsors: p.sponsors,
            placeholderCount: p.placeholderCount,
            height: 66,
            minSlotWidth: 100
        )
        .padding(16)
        .background(Brand.surfaceAlt, in: RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous))
        .padding(.horizontal, Metrics.gutter)
    }

    private func strip(_ p: SponsorPlacement) -> some View {
        SponsorRow(
            label: p.categoryLabel,
            sponsors: p.sponsors,
            placeholderCount: p.placeholderCount,
            height: 54,
            minSlotWidth: 86
        )
        .padding(.horizontal, Metrics.gutter)
    }
}

/// The full category stack, mirroring the race's website footer.
struct SponsorFooter: View {
    let placements: [SponsorPlacement]

    /// The seven website categories stand in only for the app's own reserved layout.
    /// Anything the server sent is rendered exactly as it came, headings included.
    private var showsReservedCategories: Bool {
        placements.allSatisfy(\.isReserved)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            SectionHeader(title: "Sponsor")
                .padding(.horizontal, Metrics.gutter)

            VStack(alignment: .leading, spacing: 20) {
                if !showsReservedCategories {
                    ForEach(placements) { placement in
                        SponsorRow(
                            label: placement.categoryLabel,
                            sponsors: placement.sponsors,
                            placeholderCount: placement.placeholderCount,
                            height: 58,
                            minSlotWidth: 90
                        )
                    }
                } else {
                    ForEach(SponsorCategoryPreset.allCases, id: \.self) { category in
                        SponsorRow(
                            label: category.label,
                            sponsors: [],
                            placeholderCount: category.slotCount,
                            height: 58,
                            minSlotWidth: 90
                        )
                    }
                }
            }
            .padding(18)
            .background(
                Brand.surfaceAlt,
                in: RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)
            )
            .padding(.horizontal, Metrics.gutter)
        }
    }
}
