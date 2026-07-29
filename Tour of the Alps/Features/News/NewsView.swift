import SwiftUI

@Observable
final class NewsViewModel {
    var state: Loadable<[Post]> = .idle
    var videos: [Video] = []
    private var page = 1
    private var hasMore = false
    private var isLoadingMore = false

    func load(force: Bool = false) async {
        if case .loaded = state, !force { return }
        if state.value == nil { state = .loading }
        do {
            let result = try await TotaAPI.posts(page: 1)
            page = 1
            hasMore = result.hasMore
            state = .loaded(result.data)
        } catch {
            if let existing = state.value {
                state = .loaded(existing)
            } else {
                state = .failed(error.localizedDescription)
            }
        }
        videos = (try? await TotaAPI.videos()) ?? []
    }

    func loadMoreIfNeeded(current post: Post) async {
        guard hasMore, !isLoadingMore, let posts = state.value else { return }
        guard posts.suffix(3).contains(where: { $0.id == post.id }) else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        if let result = try? await TotaAPI.posts(page: page + 1) {
            page += 1
            hasMore = result.hasMore
            state = .loaded(posts + result.data)
        }
    }
}

struct NewsView: View {
    @State private var model = NewsViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                switch model.state {
                case .idle, .loading:
                    LoadingState()
                case .failed(let message):
                    ErrorState(message: message) { Task { await model.load(force: true) } }
                case .loaded(let posts):
                    content(posts)
                }
            }
            .background(Brand.surfaceSubtle)
            .navigationTitle("News")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Brand.surface, for: .navigationBar)
            .refreshable { await model.load(force: true) }
        }
        .task { await model.load() }
    }

    @ViewBuilder
    private func content(_ posts: [Post]) -> some View {
        LazyVStack(alignment: .leading, spacing: 22) {
            if !model.videos.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "#TotA TV")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(model.videos) { video in
                                VideoCard(video: video)
                            }
                        }
                        .padding(.horizontal, Metrics.gutter)
                    }
                    .padding(.horizontal, -Metrics.gutter)
                }
            }

            SectionHeader(title: "Latest")

            ForEach(posts) { post in
                NavigationLink {
                    PostDetailView(post: post)
                } label: {
                    PostCard(post: post)
                }
                .buttonStyle(.plain)
                .task { await model.loadMoreIfNeeded(current: post) }
            }
        }
        .padding(.horizontal, Metrics.gutter)
        .padding(.vertical, 16)
    }
}

struct PostCard: View {
    let post: Post

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            RemoteImage(url: post.image?.bestCard)
                .photoFrame(height: 190)

            VStack(alignment: .leading, spacing: 7) {
                Text(post.title)
                    .font(.headline)
                    .foregroundStyle(Brand.ink)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                if let excerpt = post.excerpt?.nonEmpty {
                    Text(excerpt)
                        .font(.subheadline)
                        .foregroundStyle(Brand.inkMuted)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                }

                HStack(spacing: 6) {
                    if let date = post.publishedAt {
                        Text(Format.stageDate(date))
                    }
                    if let reading = post.readingTime {
                        // Separator kept out of the string so the key stays "%lld min read"
                        // and picks up the catalog's plural variations.
                        Text(verbatim: "·")
                        Text("\(reading) min read")
                    }
                }
                .brandDisplay(BrandFont.eyebrow(10), tracking: 0.9)
                .foregroundStyle(Brand.green)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Brand.surface)
        .clipShape(RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous))
    }
}

struct VideoCard: View {
    let video: Video

    var body: some View {
        Link(destination: video.youtubeUrl ?? URL(string: "https://www.youtube.com")!) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack {
                    RemoteImage(url: video.thumbnail?.bestCard)
                        .frame(width: 250, height: 145)
                        .clipped()
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 42))
                        .foregroundStyle(.white, Brand.greenOnPhoto)
                }
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                Text(video.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Brand.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(width: 250, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
    }
}
