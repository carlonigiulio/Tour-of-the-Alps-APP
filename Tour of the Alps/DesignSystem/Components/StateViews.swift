import SwiftUI

/// Loading state for a single async resource.
enum Loadable<Value> {
    case idle
    case loading
    case loaded(Value)
    case failed(String)

    var value: Value? {
        if case .loaded(let value) = self { return value }
        return nil
    }

    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }
}

/// Full-screen placeholders.
///
/// They fill the screen and paint their own background rather than sizing to their
/// content: with a `minHeight` the same state rendered differently depending on its
/// container — pinned to the top inside a `ScrollView`, vertically centred inside a
/// `Group`, and leaving the window's bare background showing above and below.
struct LoadingState: View {
    var body: some View {
        ProgressView()
            .tint(Brand.green)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Brand.surfaceSubtle)
    }
}

struct ErrorState: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundStyle(Brand.green)
            Text("Something went wrong")
                .brandDisplay(BrandFont.title2())
                .foregroundStyle(Brand.ink)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Brand.inkMuted)
                .multilineTextAlignment(.center)
            Button(action: retry) {
                Text("Retry")
                    .brandDisplay(BrandFont.title3(15), tracking: 1)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 26)
                    .padding(.vertical, 12)
                    .background(Slug().fill(Brand.green))
            }
            .buttonStyle(.plain)
        }
        .padding(Metrics.gutter)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Brand.surfaceSubtle)
    }
}

struct EmptyStateView: View {
    let title: LocalizedStringKey
    var message: LocalizedStringKey? = nil
    var systemImage: String = "tray"

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.largeTitle)
                .foregroundStyle(Brand.inkMuted)
            Text(title)
                .brandDisplay(BrandFont.title3())
                .foregroundStyle(Brand.ink)
            if let message {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(Brand.inkMuted)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(Metrics.gutter)
        .frame(maxWidth: .infinity, minHeight: 200)
    }
}
