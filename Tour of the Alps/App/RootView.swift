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

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Home", systemImage: "house.fill") }

            StagesView(editionTitle: app.bootstrap?.edition.title)
                .tabItem { Label("Stages", systemImage: "map.fill") }

            StandingsView()
                .tabItem { Label("Standings", systemImage: "trophy.fill") }

            TeamsView()
                .tabItem { Label("Teams", systemImage: "person.3.fill") }

            NewsView()
                .tabItem { Label("News", systemImage: "newspaper.fill") }
        }
        .tint(Brand.green)
        .task { await app.refresh() }
    }
}

#Preview {
    RootView()
}
