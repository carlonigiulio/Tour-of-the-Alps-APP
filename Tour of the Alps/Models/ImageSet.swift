import Foundation

/// The API returns image fields as a map of pre-built Cloudinary URLs, one per size
/// preset. Nested summary images (a stage's city photo, for instance) return a single
/// URL string instead, so this decodes from either shape.
struct ImageSet: Decodable, Hashable, Sendable {
    var thumb: URL?
    var card: URL?
    var hero: URL?
    var full: URL?

    init(thumb: URL? = nil, card: URL? = nil, hero: URL? = nil, full: URL? = nil) {
        self.thumb = thumb
        self.card = card
        self.hero = hero
        self.full = full
    }

    private enum CodingKeys: String, CodingKey { case thumb, card, hero, full }

    init(from decoder: any Decoder) throws {
        if let single = try? decoder.singleValueContainer(), let string = try? single.decode(String.self) {
            let url = URL(string: string)
            self.init(thumb: url, card: url, hero: url, full: url)
            return
        }
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func url(_ key: CodingKeys) -> URL? {
            (try? c.decodeIfPresent(String.self, forKey: key)).flatMap { $0.flatMap(URL.init(string:)) }
        }
        self.init(thumb: url(.thumb), card: url(.card), hero: url(.hero), full: url(.full))
    }

    /// Best available URL for a given preset, degrading through the other presets
    /// rather than rendering nothing.
    var bestCard: URL? { card ?? hero ?? full ?? thumb }
    var bestHero: URL? { hero ?? full ?? card ?? thumb }
    var bestThumb: URL? { thumb ?? card ?? full ?? hero }
    var bestFull: URL? { full ?? hero ?? card ?? thumb }
}
