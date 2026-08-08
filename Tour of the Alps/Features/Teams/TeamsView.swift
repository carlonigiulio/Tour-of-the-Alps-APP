import SwiftUI

@Observable
final class TeamsViewModel {
    var state: Loadable<[Team]> = .idle

    /// Teams arrive ordered by group then sort; regroup for sectioned display.
    var sections: [(group: TeamGroup?, teams: [Team])] {
        guard let teams = state.value else { return [] }
        let grouped = Dictionary(grouping: teams, by: { $0.group })
        return grouped
            .sorted { ($0.key?.sortOrder ?? 99) < ($1.key?.sortOrder ?? 99) }
            .map { (group: $0.key, teams: $0.value) }
    }

    func load(force: Bool = false) async {
        if case .loaded = state, !force { return }
        if state.value == nil { state = .loading }
        do {
            state = .loaded(try await TotaAPI.teams())
        } catch {
            if let existing = state.value {
                state = .loaded(existing)
            } else {
                state = .failed(error.localizedDescription)
            }
        }
    }
}

struct TeamsView: View {
    @State private var model = TeamsViewModel()
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router
        return NavigationStack(path: $router.teamsPath) {
            Group {
                switch model.state {
                case .idle, .loading:
                    LoadingState()
                case .failed(let message):
                    ErrorState(message: message) { Task { await model.load(force: true) } }
                case .loaded:
                    ScrollView { sections }
                        .refreshable { await model.load(force: true) }
                }
            }
            .background(Brand.surfaceSubtle)
            .navigationTitle("Teams")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Brand.surface, for: .navigationBar)
            .navigationDestination(for: DeepLink.self) { DeepLinkDestination(link: $0) }
        }
        .task { await model.load() }
    }

    private var sections: some View {
        LazyVStack(alignment: .leading, spacing: 24, pinnedViews: []) {
            ForEach(Array(model.sections.enumerated()), id: \.offset) { _, section in
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(verbatim: section.group?.label ?? String(localized: "Teams"))
                    VStack(spacing: 8) {
                        ForEach(section.teams) { team in
                            NavigationLink {
                                TeamDetailView(team: team)
                            } label: {
                                row(team)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            SponsorSection(page: .teams)
                .padding(.horizontal, -Metrics.gutter)
                .padding(.top, 6)
        }
        .padding(.horizontal, Metrics.gutter)
        .padding(.vertical, 16)
    }

    private func row(_ team: Team) -> some View {
        HStack(spacing: 14) {
            RemoteImage(url: team.logo?.bestThumb, contentMode: .fit)
                .frame(width: 46, height: 46)
                .padding(5)
                .background(Brand.surfaceAlt)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(team.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Brand.ink)
                    .multilineTextAlignment(.leading)
                if let short = team.shortName?.nonEmpty {
                    Text(short)
                        .brandDisplay(BrandFont.eyebrow(10), tracking: 1)
                        .foregroundStyle(Brand.green)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.bold))
                .foregroundStyle(Brand.inkMuted)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Brand.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
