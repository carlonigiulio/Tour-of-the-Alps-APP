import SwiftUI

/// Full-bleed stage card: arrival-city photography with the brand's angled green panel
/// cutting across the bottom to carry the route and key numbers.
struct StageCard: View {
    let stage: Stage
    var height: CGFloat = 300

    var body: some View {
        ZStack(alignment: .bottom) {
            RemoteImage(url: stage.arrival.image?.bestCard)
                .photoFrame(height: height)

            PhotoScrim()

            greenPanel
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous))
        .overlay(alignment: .topLeading) { topBadges }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(
            localized: "Stage \(stage.number): \(stage.departure.name) to \(stage.arrival.name), \(Format.km(stage.km)) km, \(Format.metres(stage.altitude)) m of climbing"
        ))
    }

    private var topBadges: some View {
        HStack(spacing: 8) {
            BrandChip(text: String(localized: "Stage \(stage.number)"))
            if stage.isCircuit {
                BrandChip(text: String(localized: "Circuit"), filled: false, tint: .white)
            }
            Spacer(minLength: 0)
            Text(Format.stageDate(stage.date))
                .brandDisplay(BrandFont.eyebrow(12), tracking: 1)
                .foregroundStyle(.white)
                .shadow(radius: 4)
        }
        .padding(14)
    }

    private var greenPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(stage.route)
                .brandDisplay(BrandFont.title1(26), tracking: 0.4)
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 18) {
                stat("\(Format.km(stage.km)) KM")
                stat("\(Format.metres(stage.altitude)) M")
                DifficultyMeterOnGreen(level: stage.difficulty)
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, Metrics.slant + 12)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            SlantedRectangle(slant: Metrics.slant)
                .fill(Brand.greenOnPhoto)
        )
    }

    private func stat(_ text: String) -> some View {
        Text(text)
            .font(BrandFont.numeric(.footnote, weight: .heavy))
            .foregroundStyle(.white.opacity(0.95))
    }
}

/// Difficulty chevrons tuned for the white-on-green panel.
struct DifficultyMeterOnGreen: View {
    let level: Int

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...4, id: \.self) { index in
                Image(systemName: "chevron.up")
                    .font(.system(size: 9, weight: .black))
                    .foregroundStyle(index <= level ? Color.white : Color.white.opacity(0.35))
            }
        }
        .accessibilityElement()
        .accessibilityLabel(Text("Difficulty \(level) of 4"))
    }
}
