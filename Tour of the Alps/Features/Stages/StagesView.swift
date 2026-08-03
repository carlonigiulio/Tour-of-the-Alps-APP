import SwiftUI

@Observable
final class StagesViewModel {
    var state: Loadable<[Stage]> = .idle

    func load(force: Bool = false) async {
        if case .loaded = state, !force { return }
        if state.value == nil { state = .loading }
        do {
            state = .loaded(try await TotaAPI.stages())
        } catch {
            if let existing = state.value {
                state = .loaded(existing)
            } else {
                state = .failed(error.localizedDescription)
            }
        }
    }
}

struct StagesView: View {
    @State private var model = StagesViewModel()
    let editionTitle: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                switch model.state {
                case .idle, .loading:
                    LoadingState()
                case .failed(let message):
                    ErrorState(message: message) {
                        Task { await model.load(force: true) }
                    }
                case .loaded(let stages):
                    list(stages)
                }
            }
            .background(Brand.surfaceSubtle)
            .navigationTitle("Stages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Brand.surface, for: .navigationBar)
            .navigationDestination(for: Stage.self) { stage in
                StageDetailView(number: stage.number, fallbackTitle: stage.route)
            }
            .refreshable { await model.load(force: true) }
        }
        .task { await model.load() }
    }

    private func list(_ stages: [Stage]) -> some View {
        LazyVStack(alignment: .leading, spacing: 18) {
            header(stages)

            ForEach(stages) { stage in
                NavigationLink(value: stage) {
                    StageCard(stage: stage)
                }
                .buttonStyle(.plain)
            }

            // Cancels the list's own inset so the block lines up with the rest of the app
            // instead of being padded twice.
            SponsorSection(page: .stages)
                .padding(.horizontal, -Metrics.gutter)
                .padding(.top, 6)
        }
        .padding(.horizontal, Metrics.gutter)
        .padding(.bottom, 28)
    }

    private func header(_ stages: [Stage]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(editionTitle ?? "Tour of the Alps")
                .brandDisplay(BrandFont.display(34), tracking: 0.4)
                .foregroundStyle(Brand.ink)
                .fixedSize(horizontal: false, vertical: true)

            let totalKm = stages.reduce(0) { $0 + $1.km }
            let totalClimb = stages.reduce(0) { $0 + $1.altitude }
            Text("\(stages.count) stages · \(Format.km(totalKm)) km · \(Format.metres(totalClimb)) m of climbing")
                .font(.subheadline)
                .foregroundStyle(Brand.inkMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
        .padding(.bottom, 2)
    }
}
