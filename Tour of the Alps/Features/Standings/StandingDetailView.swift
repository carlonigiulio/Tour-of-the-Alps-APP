import SwiftUI

@Observable
final class StandingDetailViewModel {
    var state: Loadable<StandingDetail> = .idle

    func load(id: Int, force: Bool = false) async {
        if case .loaded = state, !force { return }
        state = .loading
        do {
            state = .loaded(try await TotaAPI.standing(id: id))
        } catch {
            state = .failed(error.localizedDescription)
        }
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
                        ResultRowView(row: row, kind: detail.kind)
                            .background(index.isMultiple(of: 2) ? Brand.surface : Brand.surfaceSubtle)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
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
            Text("Rider").frame(maxWidth: .infinity, alignment: .leading)
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

    private var isLeader: Bool { row.rank == 1 }

    var body: some View {
        HStack(spacing: 10) {
            rankView
                .frame(width: 26, alignment: .leading)

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

            trailingValue
                .frame(width: 74, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
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
