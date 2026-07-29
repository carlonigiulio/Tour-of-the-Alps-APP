import SwiftUI

@Observable
final class RiderViewModel {
    var rider: Rider?

    /// The roster slot already carries the personal fields; this only adds the bio,
    /// and only when the slot is actually linked to a rider record.
    func load(id: Int?) async {
        guard let id else { return }
        rider = try? await TotaAPI.rider(id: id)
    }
}

struct RiderSheet: View {
    let slot: RosterSlot
    let teamName: String

    @State private var model = RiderViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    hero
                    stats
                    if let bio = model.rider?.bio, !bio.isEmpty {
                        BlockContentView(blocks: bio)
                            .padding(.horizontal, Metrics.gutter)
                    }
                }
                .padding(.bottom, 32)
            }
            .background(Brand.surfaceSubtle)
            .ignoresSafeArea(edges: .top)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.white, .black.opacity(0.35))
                            .font(.title2)
                    }
                }
            }
        }
        .task { await model.load(id: slot.riderId) }
    }

    private var hero: some View {
        ZStack(alignment: .bottom) {
            // `full` rather than `hero` on purpose: rider photos are portraits, and any
            // landscape preset has to throw away most of the frame. `hero` now centres on
            // the face (thanks to g_faces), but cropping 16:9 and then filling this nearly
            // square box magnifies it to a head-only shot. The uncropped original filled
            // from the top keeps head and shoulders.
            RemoteImage(url: slot.photo?.bestFull)
                .photoFrame(height: 340, alignment: .top)

            PhotoScrim()

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    if let dorsal = slot.dorsalNumber?.nonEmpty {
                        BrandChip(text: dorsal)  // A number, not copy — no localization.
                    }
                    CountryBadge(code: slot.country)
                        .font(.title3)
                }
                if let given = slot.givenName {
                    Text(given)
                        .font(.headline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.9))
                }
                Text(slot.surname)
                    .brandDisplay(BrandFont.display(34), tracking: 0.3)
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                Text(teamName)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
            }
            .padding(.horizontal, Metrics.gutter)
            .padding(.top, Metrics.slant + 14)
            .padding(.bottom, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(SlantedRectangle(slant: Metrics.slant).fill(Brand.greenOnPhoto))
        }
        .frame(height: 340)
        .clipped()
    }

    /// Only renders the fields the source actually filled in — the API returns empty
    /// strings for whatever it doesn't have.
    @ViewBuilder
    private var stats: some View {
        // Labels follow the race's own locale feed (`rider.*`).
        let entries: [(key: String, label: LocalizedStringKey, value: String)] = [
            ("birth", "Birthdate", slot.birthDate?.nonEmpty.map { Format.birthDate($0) }),
            ("height", "Height", slot.height?.nonEmpty.map { "\($0) cm" }),
            ("weight", "Weight", slot.weight?.nonEmpty.map { "\($0) kg" }),
            ("pro", "Professional since", slot.proSince?.nonEmpty),
            ("wins", "Wins", slot.wins?.nonEmpty),
        ].compactMap { key, label, value in value.map { (key, label, $0) } }

        if !entries.isEmpty {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 12)], spacing: 14) {
                ForEach(entries, id: \.key) { entry in
                    StatTile(value: entry.value, label: entry.label)
                }
            }
            .padding(16)
            .background(Brand.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(.horizontal, Metrics.gutter)
        }
    }
}
