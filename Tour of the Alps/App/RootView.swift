import SwiftUI

@Observable
final class AppModel {
    var bootstrap: Bootstrap?

    /// `/bootstrap` is the launch call: edition meta plus the content counts that say
    /// which sections have anything in them.
    func refresh() async {
        bootstrap = try? await TotaAPI.bootstrap()
    }
}

struct RootView: View {
    @State private var app = AppModel()
    @State private var sponsors = SponsorStore()
    @State private var router = AppRouter()

    var body: some View {
        TabView(selection: $router.selectedTab) {
            HomeView()
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(AppTab.home)

            StagesView(editionTitle: app.bootstrap?.edition.title)
                .tabItem { Label("Stages", systemImage: "map.fill") }
                .tag(AppTab.stages)

            StandingsView()
                .tabItem { Label("Standings", systemImage: "trophy.fill") }
                .tag(AppTab.standings)

            TeamsView()
                .tabItem { Label("Teams", systemImage: "person.3.fill") }
                .tag(AppTab.teams)

            NewsView()
                .tabItem { Label("News", systemImage: "newspaper.fill") }
                .tag(AppTab.news)
        }
        .tint(Brand.green)
        .environment(sponsors)
        .environment(router)
        .task { PushService.shared.router = router }
        .task { await app.refresh() }
        .task { await sponsors.load() }
        // Drains a link that arrived before the interface existed — the cold-start case,
        // where the notification is handled while the app is still launching.
        .task { router.consumePending() }
        .onChange(of: router.pending) { _, link in
            if link != nil { router.consumePending() }
        }
        // Links opened from outside the app (Safari, Mail, a QR code) land here.
        .onOpenURL { url in
            if let link = DeepLink(url) { router.open(link) }
        }
    }
}

#Preview {
    RootView()
}
