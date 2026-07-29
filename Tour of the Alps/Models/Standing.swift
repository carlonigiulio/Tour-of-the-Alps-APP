import Foundation

enum StandingKind: String, Decodable, Sendable {
    case gc, points, kom, youth, team, combativity, stage, other

    init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = StandingKind(rawValue: raw) ?? .other
    }

    var shortLabel: String {
        switch self {
        case .gc: String(localized: "GC")
        case .points: String(localized: "Points")
        case .kom: String(localized: "KOM")
        case .youth: String(localized: "Youth")
        case .team: String(localized: "Teams")
        case .combativity: String(localized: "Combativity")
        case .stage: String(localized: "Stage")
        case .other: String(localized: "Other")
        }
    }

    var systemImage: String {
        switch self {
        case .gc: "trophy.fill"
        case .points: "bolt.fill"
        case .kom: "mountain.2.fill"
        case .youth: "sparkles"
        case .team: "person.3.fill"
        case .combativity: "flame.fill"
        case .stage: "flag.checkered"
        case .other: "list.number"
        }
    }

    /// Points-based classifications show a points column instead of time and gap.
    var isPointsBased: Bool { self == .points || self == .kom || self == .combativity }
}

struct Standing: Decodable, Identifiable, Hashable, Sendable {
    let id: Int
    let title: String
    /// Set only for per-stage results; `nil` for overall classifications.
    let stageNumber: Int?
    let kind: StandingKind

    var isOverall: Bool { stageNumber == nil }

    /// The API title usually already names the kind — "Classifica Generale", "Tappa 1:
    /// Innsbruck - Innsbruck" — so a separate kind badge next to it just repeats itself.
    var titleStatesKind: Bool {
        title.localizedCaseInsensitiveContains(kind.shortLabel)
    }
}

struct ResultRow: Decodable, Hashable, Sendable, Identifiable {
    let position: String?
    let bib: String?
    let riderName: String?
    let riderNat: String?
    let teamCode: String?
    let teamName: String?
    let time: String?
    let gap: String?
    let points: String?

    var id: String { (position ?? "") + "-" + (bib ?? "") + "-" + (riderName ?? "") }

    /// `position` arrives as "1." for finishers, or a status such as OTL/DNF/DNS.
    var rank: Int? { Int(position?.replacingOccurrences(of: ".", with: "") ?? "") }

    var statusLabel: String? { rank == nil ? position?.nonEmpty : nil }
}

struct StandingDetail: Decodable, Identifiable, Hashable, Sendable {
    let id: Int
    let title: String
    let stageNumber: Int?
    let kind: StandingKind
    let results: [ResultRow]?
}
