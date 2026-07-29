import SwiftUI

@Observable
final class PostDetailViewModel {
    var state: Loadable<PostDetail> = .idle

    func load(id: Int, force: Bool = false) async {
        if case .loaded = state, !force { return }
        state = .loading
        do {
            state = .loaded(try await TotaAPI.post(id: id))
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}

struct PostDetailView: View {
    let post: Post
    @State private var model = PostDetailViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                hero

                VStack(alignment: .leading, spacing: 16) {
                    if let excerpt = post.excerpt?.nonEmpty {
                        Text(excerpt)
                            .font(.body.weight(.medium))
                            .foregroundStyle(Brand.inkMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    switch model.state {
                    case .idle, .loading:
                        LoadingState()
                    case .failed(let message):
                        ErrorState(message: message) { Task { await model.load(id: post.id, force: true) } }
                    case .loaded(let detail):
                        if let body = detail.body, !body.isEmpty {
                            BlockContentView(blocks: body)
                        } else {
                            EmptyStateView(title: "No article body", systemImage: "doc.text")
                        }
                    }
                }
                .padding(.horizontal, Metrics.gutter)
            }
            .padding(.bottom, 36)
        }
        .background(Brand.surfaceSubtle)
        .ignoresSafeArea(edges: .top)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load(id: post.id) }
    }

    private var hero: some View {
        ZStack(alignment: .bottom) {
            RemoteImage(url: post.image?.bestHero)
                .photoFrame(height: 320)

            PhotoScrim()

            VStack(alignment: .leading, spacing: 8) {
                if let date = post.publishedAt {
                    Text(Format.stageDate(date))
                        .brandDisplay(BrandFont.eyebrow(11), tracking: 1)
                        .foregroundStyle(.white.opacity(0.9))
                }
                Text(post.title)
                    .brandDisplay(BrandFont.title1(26), tracking: 0.3)
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, Metrics.gutter)
            .padding(.top, Metrics.slant + 14)
            .padding(.bottom, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(SlantedRectangle(slant: Metrics.slant).fill(Brand.greenOnPhoto))
        }
        .frame(height: 320)
        .clipped()
    }
}
