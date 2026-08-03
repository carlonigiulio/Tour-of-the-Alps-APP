import SwiftUI

@Observable
final class StandingDetailViewModel {
    var state: Loadable<StandingDetail> = .idle
    /// Team jerseys keyed by team code, loaded only for the team classification.
    var jerseys: [String: ImageSet] = [:]

    func load(id: Int, force: Bool = false) async {
        if case .loaded = state, !force { return }
        state = .loading
        do {
            let detail = try await TotaAPI.standing(id: id)
            state = .loaded(detail)
            if detail.kind == .team { await loadJerseys() }
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    /// The standings feed identifies squads by `team_code`, which matches `short_name` in
    /// `/teams` for every team in the 2024 field — that is the only link between the two
    /// endpoints, so a missing code simply means no jersey rather than a broken row.
    private func loadJerseys() async {
        guard let teams = try? await TotaAPI.teams() else { return }
        jerseys = Dictionary(
            teams.compactMap { team in
                guard let code = team.shortName?.nonEmpty, let logo = team.logo else { return nil }
                return (code, logo)
            },
            uniquingKeysWith: { first, _ in first }
        )
    }
}

struct StandingDetailView: View {
    let standing: Standing
    @State private var model = StandingDetailViewModel()

    /// Per-stage classifications all share the kind label "Stage", so the bar would read
    /// just "Tappa" for all five — the number is what distinguishes them.
    private var barTitle: String {
        if let number = standing.stageNumber {
            return String(localized: "Stage \(number)")
        }
        return standing.kind.shortLabel
    }

    var body: some View {
        ScrollView {
            switch model.state {
            case .idle, .loading:
                LoadingState()
            case .failed(let message):
                ErrorState(message: message) { Task { await model.load(id: standing.id, force: true) } }
            case .loaded(let detail):
                content(detail)
            }
        }
        .background(Brand.surfaceSubtle)
        .navigationTitle(barTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load(id: standing.id) }
    }

    @ViewBuilder
    private func content(_ detail: StandingDetail) -> some View {
        let results = detail.results ?? []

        VStack(alignment: .leading, spacing: 16) {
            header

            if results.isEmpty {
                EmptyStateView(
                    title: "Not published yet",
                    message: "This classification appears once the stage result is official.",
                    systemImage: "clock"
                )
            } else {
                VStack(spacing: 0) {
                    columnHeader(detail.kind)
                    ForEach(Array(results.enumerated()), id: \.offset) { index, row in
                        ResultRowView(row: row, kind: detail.kind, jerseys: model.jerseys)
                            .background(index.isMultiple(of: 2) ? Brand.surface : Brand.surfaceSubtle)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            // Escapes the horizontal padding below so the strip aligns with the rest of
            // the app rather than being inset twice.
            SponsorSection(page: .standingDetail, ref: String(standing.id))
                .padding(.horizontal, -Metrics.gutter)
                .padding(.top, 8)
        }
        .padding(.horizontal, Metrics.gutter)
        .padding(.bottom, 32)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !standing.titleStatesKind {
                BrandChip(text: standing.kind.shortLabel)
            }
            Text(standing.title)
                .brandDisplay(BrandFont.title1(28), tracking: 0.4)
                .foregroundStyle(Brand.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    private func columnHeader(_ kind: StandingKind) -> some View {
        HStack(spacing: 10) {
            Text(verbatim: "#").frame(width: 26, alignment: .leading)
            Text(kind == .team ? LocalizedStringKey("Team") : LocalizedStringKey("Rider"))
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(kind.isPointsBased ? LocalizedStringKey("Points") : LocalizedStringKey("Time"))
                .frame(width: 74, alignment: .trailing)
        }
        .brandDisplay(BrandFont.eyebrow(10), tracking: 1)
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(Brand.greenDeep)
    }
}

/// One classification row. Leader gets the green treatment; non-finishers (OTL/DNF/DNS)
/// show their status where the rank would be.
struct ResultRowView: View {
    let row: ResultRow
    let kind: StandingKind
    /// Jersey artwork keyed by team code, supplied only for the team classification.
    var jerseys: [String: ImageSet] = [:]

    private var isLeader: Bool { row.rank == 1 }

    /// The team classification ranks squads, not riders: the API leaves `rider_name` null
    /// and puts the squad in `team_name`, so the usual two-line rider layout would render
    /// an empty primary line.
    private var isTeamRow: Bool { kind == .team }

    var body: some View {
        HStack(spacing: 10) {
            rankView
                .frame(width: 26, alignment: .leading)

            if isTeamRow {
                teamLabel
            } else {
                riderLabel
            }

            trailingValue
                .frame(width: 74, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, isTeamRow ? 8 : 10)
        .accessibilityElement(children: .combine)
    }

    private var teamLabel: some View {
        HStack(spacing: 10) {
            RemoteImage(url: jerseys[row.teamCode ?? ""]?.bestFull, contentMode: .fit)
                .frame(width: 30, height: 30)
                .padding(3)
                .background(.white, in: RoundedRectangle(cornerRadius: 7, style: .continuous))

            Text(row.teamName ?? row.teamCode ?? "—")
                .font(.subheadline.weight(isLeader ? .bold : .medium))
                .foregroundStyle(Brand.ink)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var riderLabel: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(row.riderName ?? "—")
                .font(.subheadline.weight(isLeader ? .bold : .medium))
                .foregroundStyle(Brand.ink)
                .lineLimit(1)
            HStack(spacing: 5) {
                CountryBadge(code: row.riderNat)
                Text(row.teamName ?? row.teamCode ?? "")
                    .font(.caption)
                    .foregroundStyle(Brand.inkMuted)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var rankView: some View {
        if let rank = row.rank {
            Text(verbatim: "\(rank)")
                .font(BrandFont.numeric(.subheadline, weight: .heavy))
                .foregroundStyle(isLeader ? Brand.green : Brand.ink)
        } else {
            Text(row.statusLabel ?? "—")
                .font(.caption2.weight(.bold))
                .foregroundStyle(Brand.inkMuted)
        }
    }

    @ViewBuilder
    private var trailingValue: some View {
        if kind.isPointsBased {
            Text(row.points?.nonEmpty ?? "—")
                .font(BrandFont.numeric(.subheadline, weight: .bold))
                .foregroundStyle(Brand.ink)
        } else if isLeader, let time = row.time?.nonEmpty {
            Text(time)
                .font(BrandFont.numeric(.caption, weight: .bold))
                .foregroundStyle(Brand.green)
        } else if let gap = row.gap?.nonEmpty {
            Text(gap)
                .font(BrandFont.numeric(.caption, weight: .medium))
                .foregroundStyle(Brand.inkMuted)
        } else if let time = row.time?.nonEmpty {
            Text(time)
                .font(BrandFont.numeric(.caption, weight: .medium))
                .foregroundStyle(Brand.inkMuted)
        } else {
            Text(verbatim: "—").font(.caption).foregroundStyle(Brand.inkMuted)
        }
    }
}
