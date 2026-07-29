import SwiftUI

@Observable
final class HomeViewModel {
    var bootstrap: Bootstrap?
    var stages: [Stage] = []
    var gc: StandingDetail?
    var gcStanding: Standing?
    var latest: [Post] = []
    var videos: [Video] = []
    var isLoading = false
    var errorMessage: String?

    /// The stage to lead with: the next one still to be raced, or — once the edition is
    /// over — the final one.
    var featuredStage: Stage? {
        let now = Date()
        return stages.first { $0.date >= now } ?? stages.last
    }

    var featuredLabel: LocalizedStringKey {
        guard let stage = featuredStage else { return "Stages" }
        return stage.date >= Date() ? "Next stage" : "Final stage"
    }

    func load(force: Bool = false) async {
        if !stages.isEmpty && !force { return }
        isLoading = stages.isEmpty
        errorMessage = nil

        // Independent endpoints, fetched concurrently so the home screen settles in one pass.
        async let bootstrapTask = try? await TotaAPI.bootstrap()
        async let stagesTask = try? await TotaAPI.stages()
        async let standingsTask = try? await TotaAPI.standings()
        async let postsTask = try? await TotaAPI.posts(page: 1)
        async let videosTask = try? await TotaAPI.videos()

        bootstrap = await bootstrapTask
        let loadedStages = await stagesTask ?? []
        stages = loadedStages
        latest = Array((await postsTask)?.data.prefix(3) ?? [])
        videos = Array((await videosTask)?.prefix(6) ?? [])

        if let standing = (await standingsTask)?.first(where: { $0.kind == .gc }) {
            gcStanding = standing
            gc = try? await TotaAPI.standing(id: standing.id)
        }

        isLoading = false
        if loadedStages.isEmpty {
            errorMessage = String(localized: "Can't reach the server. Check your connection.")
        }
    }
}

struct HomeView: View {
    @State private var model = HomeViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                if model.isLoading {
                    LoadingState()
                } else if let error = model.errorMessage, model.stages.isEmpty {
                    ErrorState(message: error) { Task { await model.load(force: true) } }
                } else {
                    content
                }
            }
            .background(Brand.surfaceSubtle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .ignoresSafeArea(edges: .top)
            .refreshable { await model.load(force: true) }
        }
        .task { await model.load() }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 28) {
            masthead

            if let stage = model.featuredStage {
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: model.featuredLabel)
                    NavigationLink {
                        StageDetailView(number: stage.number, fallbackTitle: stage.route)
                    } label: {
                        StageCard(stage: stage, height: 280)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, Metrics.gutter)
            }

            if let gc = model.gc, let rows = gc.results, !rows.isEmpty, let standing = model.gcStanding {
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "General classification")
                    VStack(spacing: 0) {
                        ForEach(Array(rows.prefix(3).enumerated()), id: \.offset) { index, row in
                            ResultRowView(row: row, kind: .gc)
                                .background(index.isMultiple(of: 2) ? Brand.surface : Brand.surfaceSubtle)
                        }
                        NavigationLink {
                            StandingDetailView(standing: standing)
                        } label: {
                            HStack {
                                Text("Full classification")
                                    .brandDisplay(BrandFont.eyebrow(11), tracking: 1)
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption.weight(.bold))
                            }
                            .foregroundStyle(Brand.green)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(Brand.surface)
                        }
                        .buttonStyle(.plain)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .padding(.horizontal, Metrics.gutter)
            }

            if !model.latest.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "Latest news")
                    ForEach(model.latest) { post in
                        NavigationLink {
                            PostDetailView(post: post)
                        } label: {
                            PostCard(post: post)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Metrics.gutter)
            }

            if !model.videos.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "#TotA TV")
                        .padding(.horizontal, Metrics.gutter)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(model.videos) { VideoCard(video: $0) }
                        }
                        .padding(.horizontal, Metrics.gutter)
                    }
                }
            }
        }
        .padding(.bottom, 36)
    }

    /// Edition masthead over the opening stage's photography.
    private var masthead: some View {
        ZStack(alignment: .bottom) {
            RemoteImage(url: model.stages.first?.arrival.image?.bestHero)
                .photoFrame(height: 300)

            PhotoScrim()

            VStack(alignment: .leading, spacing: 6) {
                Text(model.bootstrap?.edition.year ?? "2026")
                    .brandDisplay(BrandFont.eyebrow(13), tracking: 2)
                    .foregroundStyle(.white.opacity(0.9))
                Text(model.bootstrap?.edition.title ?? "Tour of the Alps")
                    .brandDisplay(BrandFont.display(38), tracking: 0.3)
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                if let counts = model.bootstrap?.counts {
                    Text("\(counts.stages) stages · \(counts.teams) teams")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
            .padding(.horizontal, Metrics.gutter)
            .padding(.top, Metrics.slant + 18)
            .padding(.bottom, 22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(SlantedRectangle(slant: Metrics.slant).fill(Brand.greenOnPhoto))
        }
        .frame(height: 300)
        .clipped()
    }
}
