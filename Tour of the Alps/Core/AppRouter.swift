import SwiftUI

/// Owns which tab is showing and what each tab has pushed, so something outside the view
/// hierarchy — a tapped notification — can drive navigation.
///
/// Each tab keeps its own path: opening a stage from a notification must not wipe out
/// where the user was in, say, Teams.
@MainActor
@Observable
final class AppRouter {
    var selectedTab: AppTab = .home

    var stagesPath: [DeepLink] = []
    var standingsPath: [DeepLink] = []
    var teamsPath: [DeepLink] = []
    var newsPath: [DeepLink] = []

    /// Set when a link arrives before the UI can act on it — notably a cold start, where
    /// the notification is delivered before the first view exists. `RootView` drains it.
    private(set) var pending: DeepLink?

    func handle(_ link: DeepLink) {
        pending = link
    }

    func handle(urlString: String) {
        guard let link = DeepLink(string: urlString) else { return }
        handle(link)
    }

    /// Applies a queued link. Called once the interface is on screen.
    func consumePending() {
        guard let link = pending else { return }
        pending = nil
        open(link)
    }

    func open(_ link: DeepLink) {
        selectedTab = link.tab
        // Replace rather than append: a notification should land on its destination, not
        // bury it under whatever the user had already stacked up.
        switch link.tab {
        case .stages: stagesPath = [link]
        case .standings: standingsPath = [link]
        case .teams: teamsPath = [link]
        case .news: newsPath = [link]
        case .home: break
        }
    }
}

/// Resolves a `DeepLink` into the matching detail screen.
///
/// The detail views were built around a full model object (a `Standing`, a `Team`, a
/// `Post`) because they are normally reached by tapping a row that already has one. A
/// link carries only an id, so these wrappers fetch the detail first and rebuild the card
/// model from it. The extra request is served from the response cache when the list was
/// already loaded.
struct DeepLinkDestination: View {
    let link: DeepLink

    var body: some View {
        switch link {
        case .stage(let number):
            // Stage detail already works from a number alone.
            StageDetailView(number: number, fallbackTitle: "")
        case .standing(let id):
            StandingLoader(id: id)
        case .post(let id):
            PostLoader(id: id)
        case .team(let id):
            TeamLoader(id: id)
        }
    }
}

private struct StandingLoader: View {
    let id: Int
    @State private var state: Loadable<Standing> = .idle

    var body: some View {
        LoadedContent(state: state, retry: load) { standing in
            StandingDetailView(standing: standing)
        }
        .task { await load() }
    }

    private func load() async {
        state = .loading
        do {
            let detail = try await TotaAPI.standing(id: id)
            state = .loaded(Standing(
                id: detail.id,
                title: detail.title,
                stageNumber: detail.stageNumber,
                kind: detail.kind
            ))
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}

private struct PostLoader: View {
    let id: Int
    @State private var state: Loadable<Post> = .idle

    var body: some View {
        LoadedContent(state: state, retry: load) { post in
            PostDetailView(post: post)
        }
        .task { await load() }
    }

    private func load() async {
        state = .loading
        do {
            let detail = try await TotaAPI.post(id: id)
            state = .loaded(Post(
                id: detail.id,
                title: detail.title,
                excerpt: detail.excerpt,
                image: detail.image,
                readingTime: detail.readingTime,
                publishedAt: detail.publishedAt
            ))
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}

private struct TeamLoader: View {
    let id: Int
    @State private var state: Loadable<Team> = .idle

    var body: some View {
        LoadedContent(state: state, retry: load) { team in
            TeamDetailView(team: team)
        }
        .task { await load() }
    }

    private func load() async {
        state = .loading
        do {
            let detail = try await TotaAPI.team(id: id)
            state = .loaded(Team(
                id: detail.id,
                shortName: detail.shortName,
                title: detail.title,
                group: detail.group,
                logo: detail.logo
            ))
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}

/// Shared loading/error shell for the wrappers above.
private struct LoadedContent<Value, Content: View>: View {
    let state: Loadable<Value>
    let retry: () async -> Void
    @ViewBuilder let content: (Value) -> Content

    var body: some View {
        switch state {
        case .idle, .loading:
            LoadingState()
        case .failed(let message):
            ErrorState(message: message) { Task { await retry() } }
        case .loaded(let value):
            content(value)
        }
    }
}
