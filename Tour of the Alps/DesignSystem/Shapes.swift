import SwiftUI

/// The brand's signature angular cut: a rectangle whose top edge rises to the right.
/// Used for the green blocks that sit over stage photography.
struct SlantedRectangle: Shape {
    var slant: CGFloat = Metrics.slant
    /// When false the edge falls to the right instead of rising.
    var rising: Bool = true

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let lift = min(slant, rect.height)
        if rising {
            path.move(to: CGPoint(x: rect.minX, y: rect.minY + lift))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        } else {
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + lift))
        }
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// A parallelogram, for chips and stage-number markers.
struct Slug: Shape {
    var skew: CGFloat = 8

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + skew, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - skew, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// Scrim that keeps white type legible over arbitrary photography.
struct PhotoScrim: View {
    var body: some View {
        LinearGradient(
            colors: [.black.opacity(0.0), .black.opacity(0.25), .black.opacity(0.75)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
