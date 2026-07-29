import Foundation

struct Post: Decodable, Identifiable, Hashable, Sendable {
    let id: Int
    let title: String
    let excerpt: String?
    let image: ImageSet?
    let readingTime: Int?
    let publishedAt: Date?
}

struct PostDetail: Decodable, Identifiable, Hashable, Sendable {
    let id: Int
    let title: String
    let excerpt: String?
    let image: ImageSet?
    let readingTime: Int?
    let publishedAt: Date?
    let body: [ContentBlock]?
}

/// `/posts` is the one paginated endpoint (20 per page).
struct PostPage: Decodable, Sendable {
    struct Meta: Decodable, Sendable {
        let currentPage: Int
        let lastPage: Int
        let total: Int
    }
    let data: [Post]
    let meta: Meta?

    var hasMore: Bool {
        guard let meta else { return false }
        return meta.currentPage < meta.lastPage
    }
}

struct Video: Decodable, Identifiable, Hashable, Sendable {
    let id: Int
    let title: String
    let youtubeUrl: URL?
    let thumbnail: ImageSet?
}
