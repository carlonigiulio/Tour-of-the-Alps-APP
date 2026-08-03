import SwiftUI

@Observable
final class TeamDetailViewModel {
    var state: Loadable<TeamDetail> = .idle

    func load(id: Int, force: Bool = false) async {
        if case .loaded = state, !force { return }
        state = .loading
        do {
            state = .loaded(try await TotaAPI.team(id: id))
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}

struct TeamDetailView: View {
    let team: Team
    @State private var model = TeamDetailViewModel()
    @State private var selectedRider: RosterSlot?

    private let columns = [GridItem(.adaptive(minimum: 104), spacing: 12)]

    var body: some View {
        ScrollView {
            switch model.state {
            case .idle, .loading:
                LoadingState()
            case .failed(let message):
                ErrorState(message: message) { Task { await model.load(id: team.id, force: true) } }
            case .loaded(let detail):
                content(detail)
            }
        }
        .background(Brand.surfaceSubtle)
        // The green header already states the team name — a bar title repeating the
        // three-letter code on top of it is just clutter.
        // `verbatim` keeps Xcode from extracting an empty key into the String Catalog.
        .navigationTitle(Text(verbatim: ""))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedRider) { rider in
            RiderSheet(slot: rider, teamName: team.title)
        }
        .task { await model.load(id: team.id) }
    }

    @ViewBuilder
    private func content(_ detail: TeamDetail) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            header(detail)

            if detail.manager?.nonEmpty != nil || detail.sportDirectors?.nonEmpty != nil {
                VStack(spacing: 0) {
                    if let manager = detail.manager?.nonEmpty {
                        staffRow(label: "Manager", value: manager)
                    }
                    if let directors = detail.sportDirectors?.nonEmpty {
                        Divider().overlay(Brand.hairline)
                        staffRow(label: "Sport directors", value: directors)
                    }

                }
                .padding(.horizontal, 14)
                .background(Brand.surface)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(.horizontal, Metrics.gutter)
            }

            if let body = detail.body, !body.isEmpty {
                BlockContentView(blocks: body)
                    .padding(.horizontal, Metrics.gutter)
            }

            let riders = detail.riders ?? []
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title: "Roster")
                if riders.isEmpty {
                    EmptyStateView(title: "Roster not published", systemImage: "person.3")
                } else {
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(riders) { slot in
                            Button { selectedRider = slot } label: {
                                RiderTile(slot: slot)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, Metrics.gutter)

            SponsorSection(page: .teamDetail, ref: String(team.id))
                .padding(.top, 4)
        }
        .padding(.bottom, 32)
    }

    private func header(_ detail: TeamDetail) -> some View {
        ZStack(alignment: .bottomLeading) {
            Brand.greenDeep
            VStack(alignment: .leading, spacing: 12) {
                // Square frame: the jersey artwork is portrait, but the placeholder shown
                // while it loads is a plain colour, which would otherwise stretch to the
                // full proposed width and snap back once the image arrived.
                RemoteImage(url: detail.logo?.bestFull, contentMode: .fit)
                    .frame(width: 66, height: 66)
                    .padding(10)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                Text(detail.title)
                    .brandDisplay(BrandFont.title1(28), tracking: 0.4)
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)

                if let group = detail.group {
                    Text(group.label)
                        .brandDisplay(BrandFont.eyebrow(11), tracking: 1)
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
            .padding(.horizontal, Metrics.gutter)
            .padding(.vertical, 22)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        // A page-coloured slanted block laid over the bottom of the green header cuts
        // the brand's diagonal edge into it.
        .overlay(alignment: .bottom) {
            SlantedRectangle(slant: Metrics.slant, rising: true)
                .fill(Brand.surfaceSubtle)
                .frame(height: Metrics.slant)
        }
    }

    private func staffRow(label: LocalizedStringKey, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .brandDisplay(BrandFont.eyebrow(11), tracking: 0.9)
                .foregroundStyle(Brand.green)
            Spacer(minLength: 16)
            Text(value)
                .font(.subheadline)
                .foregroundStyle(Brand.ink)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 12)
    }
}

/// Roster tile: rider photo with the dorsal number as a green slug.
struct RiderTile: View {
    let slot: RosterSlot

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topLeading) {
                RemoteImage(url: slot.photo?.bestCard)
                    .photoFrame(height: 128)
                    .background(Brand.surfaceAlt)

                if let dorsal = slot.dorsalNumber?.nonEmpty {
                    Text(dorsal)
                        .font(BrandFont.numeric(.caption, weight: .heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 3)
                        .background(Slug(skew: 5).fill(Brand.greenOnPhoto))
                        .padding(6)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 1) {
                if let given = slot.givenName {
                    Text(given)
                        .font(.caption2)
                        .foregroundStyle(Brand.inkMuted)
                        .lineLimit(1)
                }
                Text(slot.surname)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Brand.ink)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "\(slot.name), number \(slot.dorsalNumber ?? "—")"))
    }
}
