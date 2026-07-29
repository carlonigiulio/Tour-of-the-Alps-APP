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

struct LoadingState: View {
    var body: some View {
        VStack(spacing: 12) {
            ProgressView().tint(Brand.green)
        }
        .frame(maxWidth: .infinity, minHeight: 220)
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
        .frame(maxWidth: .infinity, minHeight: 300)
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
