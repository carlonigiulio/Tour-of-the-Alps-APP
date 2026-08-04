import Foundation

/// A destination the app can be opened at from outside — today a push notification,
/// tomorrow a link in an email or a QR code.
///
/// Wire format is `tota://<type>/<id>`, e.g. `tota://stage/3`.
///
/// Note the stage case carries a **number**, not a database id: the API itself is
/// `/stages/{number}`, and in the 2026 data the two differ (stage 5 has `id: 1`), so
/// taking the id here would silently open the wrong stage.
enum DeepLink: Hashable, Sendable {
    case stage(number: Int)
    case standing(id: Int)
    case post(id: Int)
    case team(id: Int)

    static let scheme = "tota"

    /// Parses a link, returning `nil` for anything unrecognised so an unknown or
    /// malformed value from the server is ignored rather than crashing or misrouting.
    init?(_ url: URL) {
        guard url.scheme?.lowercased() == Self.scheme else { return nil }

        // Both `tota://stage/3` and `tota:///stage/3` appear in the wild depending on how
        // the link was composed, so take the type from the host and fall back to the path.
        var parts = [url.host, url.path]
            .compactMap { $0 }
            .flatMap { $0.split(separator: "/") }
            .map(String.init)

        guard parts.count >= 2 else { return nil }
        let type = parts.removeFirst().lowercased()
        guard let value = Int(parts.removeFirst()) else { return nil }

        switch type {
        case "stage", "stages": self = .stage(number: value)
        case "standing", "standings", "results": self = .standing(id: value)
        case "post", "posts", "news": self = .post(id: value)
        case "team", "teams": self = .team(id: value)
        default: return nil
        }
    }

    init?(string: String) {
        guard let url = URL(string: string.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return nil
        }
        self.init(url)
    }

    /// Which tab has to be showing for this destination to make sense.
    var tab: AppTab {
        switch self {
        case .stage: .stages
        case .standing: .standings
        case .team: .teams
        case .post: .news
        }
    }
}

/// Tabs, as a type so a deep link can select one without relying on an index.
enum AppTab: Hashable, Sendable {
    case home, stages, standings, teams, news
}
