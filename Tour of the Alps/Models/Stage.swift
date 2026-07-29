import Foundation

struct Bootstrap: Decodable, Sendable {
    struct Edition: Decodable, Sendable {
        let year: String
        let title: String
    }
    struct Counts: Decodable, Sendable {
        let stages: Int
        let teams: Int
        let standings: Int
        let posts: Int
        let videos: Int
    }
    let edition: Edition
    let languages: [String]
    let defaultLanguage: String
    let counts: Counts
}

enum RaceType: String, Decodable, Sendable {
    case medium, high

    var label: String {
        switch self {
        case .medium: String(localized: "Medium mountain")
        case .high: String(localized: "High mountain")
        }
    }
}

/// A city at either end of a stage. Lists return `image` as a single card URL.
struct CitySummary: Decodable, Hashable, Sendable {
    let id: Int
    let name: String
    let image: ImageSet?
}

struct Stage: Decodable, Identifiable, Hashable, Sendable {
    let id: Int
    let number: Int
    let title: String
    let km: Double
    let altitude: Int
    /// 1–4, higher is harder.
    let difficulty: Int
    let raceType: RaceType?
    let date: Date
    let hasRoute: Bool
    let departure: CitySummary
    let arrival: CitySummary

    /// The API `title` is prefixed with "Stage N/2026: ". The route reads better
    /// built from the two city names, so the raw title is only a fallback.
    var route: String { "\(departure.name) → \(arrival.name)" }

    var isCircuit: Bool { departure.id == arrival.id }
}

struct StageInfo: Decodable, Hashable, Sendable {
    let meetup: String?
    let departure: String?
    let arrival: String?
    let medicalControl: String?
    let provisioning: String?
    let tv: String?
    let gpm: String?
    let hq: String?

    /// Ordered, label-paired rows, skipping anything the source left empty.
    ///
    /// Labels match the race's own locale feed verbatim so the app reads like the
    /// roadbook — including "TV", which is the Italian *traguardo volante*
    /// (intermediate sprint) rather than television.
    var rows: [(label: String, value: String)] {
        let pairs: [(String, String?)] = [
            (String(localized: "Meetup"), meetup),
            (String(localized: "Departure"), departure),
            (String(localized: "Arrival"), arrival),
            (String(localized: "Provisioning"), provisioning),
            (String(localized: "TV"), tv),
            (String(localized: "GPM"), gpm),
            (String(localized: "Medical Control"), medicalControl),
            (String(localized: "HQ"), hq),
        ]
        return pairs.compactMap { label, value in
            guard let value, !value.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
            return (label, value)
        }
    }
}

enum DownloadKind: String, Decodable, Sendable {
    case gpx, map, profile, timetable
    case lastKm = "last_km"
    case other

    init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = DownloadKind(rawValue: raw) ?? .other
    }

    var systemImage: String {
        switch self {
        case .gpx: "point.topleft.down.to.point.bottomright.curvepath"
        case .map: "map"
        case .profile: "chart.line.uptrend.xyaxis"
        case .timetable: "clock"
        case .lastKm: "flag.checkered"
        case .other: "doc"
        }
    }
}

struct StageDownload: Decodable, Hashable, Sendable, Identifiable {
    let kind: DownloadKind
    let title: String
    let url: URL
    let size: Int?

    var id: URL { url }

    var formattedSize: String? {
        guard let size, size > 0 else { return nil }
        return ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }
}

struct StageDetail: Decodable, Identifiable, Hashable, Sendable {
    let id: Int
    let number: Int
    let title: String
    let km: Double
    let altitude: Int
    let difficulty: Int
    let raceType: RaceType?
    let date: Date
    let hasRoute: Bool
    let departure: CitySummary
    let arrival: CitySummary
    let info: StageInfo?
    let altimetry: ImageSet?
    let climbs: [ImageSet]?
    let downloads: [StageDownload]?

    var route: String { "\(departure.name) → \(arrival.name)" }
}
