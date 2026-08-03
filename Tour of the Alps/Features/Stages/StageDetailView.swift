import SwiftUI

@Observable
final class StageDetailViewModel {
    var state: Loadable<StageDetail> = .idle
    /// The matching per-stage classification, so the route and its result cross-link.
    var stageStanding: Standing?

    func load(number: Int, force: Bool = false) async {
        if case .loaded = state, !force { return }
        state = .loading
        do {
            state = .loaded(try await TotaAPI.stage(number: number))
        } catch {
            state = .failed(error.localizedDescription)
        }
        stageStanding = try? await TotaAPI.standings().first { $0.stageNumber == number }
    }
}

struct StageDetailView: View {
    let number: Int
    let fallbackTitle: String

    @State private var model = StageDetailViewModel()
    @State private var zoomedImage: URL?

    var body: some View {
        ScrollView {
            switch model.state {
            case .idle, .loading:
                LoadingState()
            case .failed(let message):
                ErrorState(message: message) { Task { await model.load(number: number, force: true) } }
            case .loaded(let stage):
                content(stage)
            }
        }
        .background(Brand.surfaceSubtle)
        .ignoresSafeArea(edges: .top)
        .navigationTitle(fallbackTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .sheet(item: $zoomedImage) { url in
            ImageViewer(url: url)
        }
        .task { await model.load(number: number) }
    }

    @ViewBuilder
    private func content(_ stage: StageDetail) -> some View {
        VStack(alignment: .leading, spacing: 26) {
            hero(stage)

            statRow(stage)
                .padding(.horizontal, Metrics.gutter)

            if let standing = model.stageStanding {
                NavigationLink {
                    StandingDetailView(standing: standing)
                } label: {
                    resultLink
                }
                .buttonStyle(.plain)
                .padding(.horizontal, Metrics.gutter)
            }

            if let altimetry = stage.altimetry?.bestFull {
                section("Profile") {
                    Button { zoomedImage = altimetry } label: {
                        RemoteImage(url: altimetry, contentMode: .fit)
                            .background(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }

            if let climbs = stage.climbs, !climbs.isEmpty {
                section("Climbs") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(Array(climbs.enumerated()), id: \.offset) { _, climb in
                                Button { zoomedImage = climb.bestFull } label: {
                                    RemoteImage(url: climb.bestFull, contentMode: .fit)
                                        .frame(width: 280, height: 170)
                                        .background(.white)
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, Metrics.gutter)
                    }
                    .padding(.horizontal, -Metrics.gutter)
                }
            }

            if let rows = stage.info?.rows, !rows.isEmpty {
                section("Informations") {
                    VStack(spacing: 0) {
                        ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                            infoRow(label: row.label, value: row.value)
                            if index < rows.count - 1 {
                                Divider().overlay(Brand.hairline)
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 4)
                    .background(Brand.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }

            if let downloads = stage.downloads, !downloads.isEmpty {
                section("Download") {
                    VStack(spacing: 8) {
                        ForEach(downloads) { download in
                            Link(destination: download.url) {
                                downloadRow(download)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            SponsorSection(page: .stageDetail, ref: String(stage.number))
        }
        .padding(.bottom, 36)
    }

    private func hero(_ stage: StageDetail) -> some View {
        ZStack(alignment: .bottom) {
            RemoteImage(url: stage.arrival.image?.bestHero)
                .photoFrame(height: 380)

            PhotoScrim()

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    BrandChip(text: String(localized: "Stage \(stage.number)"))
                    if let type = stage.raceType {
                        BrandChip(text: type.label, filled: false, tint: .white)
                    }
                }
                // Routes vary a lot in length ("Arco → Trento" vs
                // "Telfs → Martell/Val Martello"), so the headline is pinned to a single
                // line and allowed to shrink rather than wrapping mid-route.
                Text(stage.route)
                    .brandDisplay(BrandFont.display(32), tracking: 0.3)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text(Format.longDate(stage.date))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .padding(.horizontal, Metrics.gutter)
            .padding(.top, Metrics.slant + 16)
            .padding(.bottom, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(SlantedRectangle(slant: Metrics.slant).fill(Brand.greenOnPhoto))
        }
        .frame(height: 380)
        .clipped()
    }

    private func statRow(_ stage: StageDetail) -> some View {
        HStack(alignment: .top, spacing: 12) {
            StatTile(value: "\(Format.km(stage.km)) km", label: "Distance")
            StatTile(value: "\(Format.metres(stage.altitude)) m", label: "Climbing")
            VStack(alignment: .leading, spacing: 2) {
                // Sized against a hidden numeral so the chevrons share the exact line
                // box of the neighbouring stat values and the labels stay on one baseline.
                Text(verbatim: "0")
                    .font(BrandFont.numeric(.title3, weight: .heavy))
                    .hidden()
                    .overlay(alignment: .leading) {
                        DifficultyMeter(level: stage.difficulty)
                    }
                Text("Difficulty")
                    .brandDisplay(BrandFont.eyebrow(11), tracking: 0.9)
                    .foregroundStyle(Brand.inkMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(Brand.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var resultLink: some View {
        HStack {
            Image(systemName: "flag.checkered")
                .foregroundStyle(Brand.green)
            Text("Stage result")
                .brandDisplay(BrandFont.title3(15), tracking: 0.8)
                .foregroundStyle(Brand.ink)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.bold))
                .foregroundStyle(Brand.inkMuted)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Brand.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func infoRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .brandDisplay(BrandFont.eyebrow(11), tracking: 0.9)
                .foregroundStyle(Brand.green)
            Text(value)
                .font(.subheadline)
                .foregroundStyle(Brand.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
    }

    private func downloadRow(_ download: StageDownload) -> some View {
        HStack(spacing: 14) {
            Image(systemName: download.kind.systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(Circle().fill(Brand.green))

            VStack(alignment: .leading, spacing: 2) {
                Text(download.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Brand.ink)
                if let size = download.formattedSize {
                    Text(size)
                        .font(.caption)
                        .foregroundStyle(Brand.inkMuted)
                }
            }
            Spacer()
            Image(systemName: "arrow.down.circle")
                .foregroundStyle(Brand.inkMuted)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Brand.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private func section<Content: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: title)
            content()
        }
        .padding(.horizontal, Metrics.gutter)
    }
}

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

/// Pinch-to-zoom viewer for altimetry and climb profiles, which are wide and detailed.
///
/// The image is framed to the viewport rather than left to size itself: inside a
/// bidirectional `ScrollView` the proposed width is unbounded, so an aspect-fit image
/// would lay out at its full pixel size and open already massively zoomed in. Zooming
/// grows that frame, which is what makes the scroll view pannable.
struct ImageViewer: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss
    @State private var zoom: CGFloat = 1
    @GestureState private var pinch: CGFloat = 1

    private var maxZoom: CGFloat { 6 }

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                ScrollView([.horizontal, .vertical], showsIndicators: false) {
                    RemoteImage(url: url, contentMode: .fit)
                        .frame(
                            width: proxy.size.width * zoom * pinch,
                            height: proxy.size.height * zoom * pinch
                        )
                }
                // Without a centre anchor the scroll view stays pinned top-left as the
                // content grows, so zooming in lands on the blank margin of the profile
                // rather than on the chart.
                .defaultScrollAnchor(.center)
                .gesture(
                    MagnificationGesture()
                        .updating($pinch) { value, state, _ in state = value }
                        .onEnded { value in
                            zoom = min(max(zoom * value, 1), maxZoom)
                        }
                )
                .onTapGesture(count: 2) {
                    withAnimation(.easeOut(duration: 0.22)) {
                        zoom = zoom > 1 ? 1 : 3
                    }
                }
            }
            .background(.white)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .tint(Brand.green)
                }
            }
        }
    }
}
