import SwiftUI
import UIKit

struct ContentView: View {
    @State private var state = PageState(homeURL: URL(string: "https://wantmymtv.org/player.html")!)

    var body: some View {
        ZStack {
            // Fills the status bar and home indicator areas with black.
            Color(uiColor: .mtvBlack)
                .ignoresSafeArea()
            // The page stays below the status bar, but runs to the bottom edge
            // (under the home indicator), so there's no empty strip under the guide.
            WebView(state: state)
                .ignoresSafeArea(edges: .bottom)

            if state.offline {
                OfflineView { state.retry() }
                    .transition(.opacity)
            } else if !state.loaded {
                LoadingView()
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.35), value: state.loaded)
        .animation(.easeOut(duration: 0.25), value: state.offline)
    }
}

/// The icon on black with a spinner, until the player loads.
private struct LoadingView: View {
    var body: some View {
        ZStack {
            Color(uiColor: .mtvBlack).ignoresSafeArea()
            VStack(spacing: 28) {
                AppIconImage()
                ProgressView()
                    .tint(.white)
                    .controlSize(.large)
            }
        }
    }
}

private struct OfflineView: View {
    let retry: () -> Void

    var body: some View {
        ZStack {
            Color(uiColor: .mtvBlack).ignoresSafeArea()
            VStack(spacing: 18) {
                AppIconImage()
                    .opacity(0.6)
                Text(L10n.offlineTitle)
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                Text(L10n.offlineMessage)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.7))
                Button(action: retry) {
                    Text(L10n.retry)
                        .font(.headline)
                        .padding(.horizontal, 36)
                        .padding(.vertical, 12)
                        .background(Color.white, in: Capsule())
                        .foregroundStyle(Color(uiColor: .mtvBlack))
                }
                .padding(.top, 6)
            }
            .padding(32)
        }
    }
}

private struct AppIconImage: View {
    private static let image: UIImage? = Bundle.module
        .path(forResource: "LaunchIcon", ofType: "png")
        .flatMap { UIImage(contentsOfFile: $0) }

    var body: some View {
        if let image = Self.image {
            Image(uiImage: image)
                .resizable()
                .frame(width: 120, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 27, style: .continuous))
        }
    }
}
