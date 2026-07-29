import Foundation

enum APIError: LocalizedError {
    case badStatus(Int)
    case decoding(any Error)
    case transport(any Error)

    var errorDescription: String? {
        switch self {
        case .badStatus(404): String(localized: "Not found.")
        case .badStatus(let code): String(localized: "The server responded with error \(code).")
        case .decoding: String(localized: "The server sent unexpected data.")
        case .transport: String(localized: "Can't reach the server. Check your connection.")
        }
    }
}

/// Disk cache of raw JSON responses. Content is static and refreshed sporadically
/// server-side, so a successful response stays valid until the next one replaces it —
/// which also makes the app usable offline.
actor ResponseCache {
    static let shared = ResponseCache()

    private let directory: URL = {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("api-responses", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private func file(for key: String) -> URL {
        let safe = key.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? key
        return directory.appendingPathComponent(safe)
    }

    func data(for key: String) -> Data? { try? Data(contentsOf: file(for: key)) }

    func store(_ data: Data, for key: String) {
        try? data.write(to: file(for: key), options: .atomic)
    }
}

final class APIClient {
    static let shared = APIClient()

    private let session: URLSession
    private let decoder: JSONDecoder

    init(session: URLSession = .shared) {
        self.session = session
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    /// Fetches and decodes `path`, appending the current language. On a transport failure
    /// it falls back to the last cached body for the same request; a decodable cached
    /// response is preferred over surfacing an error the user can't act on.
    func get<T: Decodable>(_ path: String, query: [URLQueryItem] = [], as type: T.Type) async throws -> T {
        var components = URLComponents(
            url: AppConfig.apiBaseURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = query + [URLQueryItem(name: "lang", value: Language.current.rawValue)]
        let url = components.url!
        let key = components.string ?? path

        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse else { throw APIError.badStatus(-1) }
            guard (200..<300).contains(http.statusCode) else { throw APIError.badStatus(http.statusCode) }
            let value = try decoder.decode(T.self, from: data)
            await ResponseCache.shared.store(data, for: key)
            return value
        } catch let error as DecodingError {
            throw APIError.decoding(error)
        } catch let error as APIError {
            throw error
        } catch {
            if let cached = await ResponseCache.shared.data(for: key),
               let value = try? decoder.decode(T.self, from: cached) {
                return value
            }
            throw APIError.transport(error)
        }
    }
}

/// Envelope used by every list and detail endpoint.
struct Envelope<T: Decodable>: Decodable {
    let data: T
}

/// Typed surface over the endpoints in `Server/docs/API.md`.
enum TotaAPI {
    private static var client: APIClient { .shared }

    static func bootstrap() async throws -> Bootstrap {
        try await client.get("bootstrap", as: Bootstrap.self)
    }

    static func stages() async throws -> [Stage] {
        try await client.get("stages", as: Envelope<[Stage]>.self).data
    }

    static func stage(number: Int) async throws -> StageDetail {
        try await client.get("stages/\(number)", as: Envelope<StageDetail>.self).data
    }

    static func teams() async throws -> [Team] {
        try await client.get("teams", as: Envelope<[Team]>.self).data
    }

    static func team(id: Int) async throws -> TeamDetail {
        try await client.get("teams/\(id)", as: Envelope<TeamDetail>.self).data
    }

    static func rider(id: Int) async throws -> Rider {
        try await client.get("riders/\(id)", as: Envelope<Rider>.self).data
    }

    static func standings() async throws -> [Standing] {
        try await client.get("standings", as: Envelope<[Standing]>.self).data
    }

    static func standing(id: Int) async throws -> StandingDetail {
        try await client.get("standings/\(id)", as: Envelope<StandingDetail>.self).data
    }

    static func posts(page: Int = 1) async throws -> PostPage {
        try await client.get("posts", query: [URLQueryItem(name: "page", value: String(page))], as: PostPage.self)
    }

    static func post(id: Int) async throws -> PostDetail {
        try await client.get("posts/\(id)", as: Envelope<PostDetail>.self).data
    }

    static func videos() async throws -> [Video] {
        try await client.get("videos", as: Envelope<[Video]>.self).data
    }
}
