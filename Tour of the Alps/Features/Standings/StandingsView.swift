import SwiftUI

@Observable
final class StandingsViewModel {
    var state: Loadable<[Standing]> = .idle

    func load(force: Bool = false) async {
        if case .loaded = state, !force { return }
        if state.value == nil { state = .loading }
        do {
            state = .loaded(try await TotaAPI.standings())
        } catch {
            if let existing = state.value {
                state = .loaded(existing)
            } else {
                state = .failed(error.localizedDescription)
            }
        }
    }
}

struct StandingsView: View {
    private enum Scope: CaseIterable {
        case overall
        case stages

        var label: LocalizedStringKey {
            switch self {
            case .overall: "Overall"
            case .stages: "By stage"
            }
        }
    }

    @State private var model = StandingsViewModel()
    @Environment(AppRouter.self) private var router
    @State private var scope: Scope = .overall

    var body: some View {
        @Bindable var router = router
        return NavigationStack(path: $router.standingsPath) {
            Group {
                switch model.state {
                case .idle, .loading:
                    LoadingState()
                case .failed(let message):
                    ErrorState(message: message) { Task { await model.load(force: true) } }
                case .loaded(let standings):
                    list(standings)
                }
            }
            .background(Brand.surfaceSubtle)
            .navigationTitle("Standings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Brand.surface, for: .navigationBar)
            .navigationDestination(for: DeepLink.self) { DeepLinkDestination(link: $0) }
        }
        .task { await model.load() }
    }

    private func list(_ standings: [Standing]) -> some View {
        let filtered = standings.filter { scope == .overall ? $0.isOverall : !$0.isOverall }

        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Picker("Scope", selection: $scope) {
                    ForEach(Scope.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)

                if filtered.isEmpty {
                    EmptyStateView(
                        title: "No classifications yet",
                        message: "Results are published after each stage.",
                        systemImage: "trophy"
                    )
                } else {
                    VStack(spacing: 10) {
                        ForEach(filtered) { standing in
                            NavigationLink {
                                StandingDetailView(standing: standing)
                            } label: {
                                row(standing)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                SponsorSection(page: .standings)
                    .padding(.horizontal, -Metrics.gutter)
                    .padding(.top, 6)
            }
            .padding(.horizontal, Metrics.gutter)
            .padding(.vertical, 16)
        }
        .refreshable { await model.load(force: true) }
    }

    private func row(_ standing: Standing) -> some View {
        HStack(spacing: 14) {
            Image(systemName: standing.kind.systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(SlantedRectangle(slant: 6).fill(Brand.green))

            VStack(alignment: .leading, spacing: 3) {
                Text(standing.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Brand.ink)
                    .multilineTextAlignment(.leading)
                if !standing.titleStatesKind {
                    Text(standing.kind.shortLabel)
                        .brandDisplay(BrandFont.eyebrow(10), tracking: 0.9)
                        .foregroundStyle(Brand.inkMuted)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.bold))
                .foregroundStyle(Brand.inkMuted)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Brand.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
