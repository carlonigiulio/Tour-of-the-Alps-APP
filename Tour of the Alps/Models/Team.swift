import Foundation

extension String {
    /// The API hands back empty strings rather than `null` for missing rider bio
    /// fields, so treat blank as absent everywhere it's displayed.
    var nonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

enum TeamGroup: String, Decodable, CaseIterable, Sendable {
    case worldTour, proContinental, continental, nationalTeams

    /// Wording taken from the race's own locale feed (`team.group.*`), which uses the
    /// same four names in all three languages.
    var label: String {
        switch self {
        case .worldTour: String(localized: "World Tour")
        case .proContinental: String(localized: "Pro Continental")
        case .continental: String(localized: "Continental")
        case .nationalTeams: String(localized: "National Teams")
        }
    }

    /// Presentation order, matching how the race lists its startlist.
    var sortOrder: Int {
        switch self {
        case .worldTour: 0
        case .proContinental: 1
        case .continental: 2
        case .nationalTeams: 3
        }
    }
}

struct Team: Decodable, Identifiable, Hashable, Sendable {
    let id: Int
    let shortName: String?
    let title: String
    let group: TeamGroup?
    let logo: ImageSet?
}

struct RosterSlot: Decodable, Hashable, Sendable, Identifiable {
    let dorsalNumber: String?
    let photo: ImageSet?
    let riderId: Int?
    let name: String
    let firstName: String?
    let lastName: String?
    let country: String?
    let birthDate: String?
    let height: String?
    let weight: String?
    let proSince: String?
    let wins: String?

    var id: String { dorsalNumber ?? name }

    /// The API splits the name server-side, which removes the client-side guessing that
    /// the two feeds' differing word order used to require. `name` remains the fallback
    /// if a slot ever arrives without the split.
    var surname: String { lastName?.nonEmpty ?? name }
    var givenName: String? { firstName?.nonEmpty }
}

struct TeamDetail: Decodable, Identifiable, Hashable, Sendable {
    let id: Int
    let shortName: String?
    let title: String
    let group: TeamGroup?
    let logo: ImageSet?
    let body: [ContentBlock]?
    let manager: String?
    let sportDirectors: String?
    let riders: [RosterSlot]?
}

struct Rider: Decodable, Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    let firstName: String?
    let lastName: String?
    let country: String?
    let birthDate: String?
    let height: String?
    let weight: String?
    let proSince: String?
    let wins: String?
    let bio: [ContentBlock]?
}
