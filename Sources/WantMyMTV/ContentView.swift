import SwiftUI
import UIKit

enum AppSheet: String, Identifiable {
    case channels, timeMachine, search, saved, about
    var id: String { rawValue }
}

struct ContentView: View {
    @State private var player = PlayerController()
    @State private var sheet: AppSheet?
    @State private var fullScreen = false
    @State private var showsFloatingRemote = false
    @State private var hideRemoteTask: Task<Void, Never>?

    var body: some View {
        GeometryReader { geo in
            let landscape = geo.size.width > geo.size.height
            let full = landscape || fullScreen
            ZStack {
                Color.clear.onChange(of: geo.size) { player.relayout() }
                Theme.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    if !full {
                        header
                            .padding(.horizontal, 18)
                            .padding(.bottom, 12)
                    }

                    screen(full: full)
                        .frame(height: full ? nil : geo.size.width * 9 / 16)
                        .frame(maxHeight: full ? .infinity : nil)

                    if !full {
                        ScrollView {
                            VStack(spacing: 16) {
                                NowPlayingCard(player: player) { sheet = .channels }
                                Remote(player: player, sheet: $sheet) {
                                    withAnimation(.snappy) { fullScreen = true }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                            .padding(.bottom, 24)
                        }
                        .scrollBounceBehavior(.basedOnSize)
                    }
                }
                .ignoresSafeArea(edges: full ? .all : [])

                if player.offline {
                    OfflineView { player.retry() }
                        .transition(.opacity)
                } else if !player.loaded {
                    LoadingView()
                        .transition(.opacity)
                }
            }
        }
        .onChange(of: fullScreen) { player.relayout() }
        .statusBarHidden(fullScreen)
        .persistentSystemOverlays(fullScreen ? .hidden : .automatic)
        .animation(.easeOut(duration: 0.35), value: player.loaded)
        .animation(.easeOut(duration: 0.25), value: player.offline)
        .sheet(item: $sheet) { which in
            switch which {
            case .channels: ChannelsSheet(player: player)
            case .timeMachine: TimeMachineSheet(player: player)
            case .search: SearchSheet(player: player)
            case .saved: SavedSheet(player: player)
            case .about: AboutView()
            }
        }
    }

    private var header: some View {
        HStack {
            Wordmark(size: 24, alignment: .leading)
            Spacer()
            Button {
                Haptics.click()
                sheet = .about
            } label: {
                Image(systemName: "info.circle")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Theme.dim)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("About")
        }
        .padding(.top, 4)
    }

    /// The video, with swipe and tap on top (the site's own page stays hidden underneath).
    private func screen(full: Bool) -> some View {
        ZStack {
            WebView(state: player)
            Scanlines(spacing: 3, opacity: 0.12)

            // Takes the touches, so YouTube's own overlay never shows.
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture(count: 2) {
                    guard !full || fullScreen else { return }
                    Haptics.click()
                    withAnimation(.snappy) { fullScreen.toggle() }
                }
                .onTapGesture {
                    if full { flashRemote() } else { player.playPause() }
                }
                .gesture(
                    DragGesture(minimumDistance: 30).onEnded { value in
                        let dx = value.translation.width
                        guard abs(dx) > abs(value.translation.height) else { return }
                        if dx < 0 { player.next() } else { player.previous() }
                    }
                )

            if let toast = player.toast {
                Text(toast)
                    .font(Theme.label(14, weight: .bold))
                    .foregroundStyle(Theme.text)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.top, full ? 24 : 10)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .allowsHitTesting(false)
            }

            if full && showsFloatingRemote {
                FloatingRemote(player: player, canExit: fullScreen) {
                    withAnimation(.snappy) { fullScreen = false; showsFloatingRemote = false }
                }
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 28)
                .transition(.opacity)
            }
        }
        .clipped()
        .background(Color.black)
        .animation(.snappy, value: player.toast)
        .animation(.easeOut(duration: 0.2), value: showsFloatingRemote)
    }

    private func flashRemote() {
        showsFloatingRemote.toggle()
        hideRemoteTask?.cancel()
        guard showsFloatingRemote else { return }
        hideRemoteTask = Task {
            try? await Task.sleep(for: .seconds(4))
            if !Task.isCancelled { showsFloatingRemote = false }
        }
    }
}

// MARK: Now playing

private struct NowPlayingCard: View {
    let player: PlayerController
    let onChannel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: { Haptics.click(); onChannel() }) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(player.now.playing ? Theme.red : Theme.dim)
                        .frame(width: 7, height: 7)
                        .shadow(color: Theme.red, radius: player.now.playing ? 4 : 0)
                    Text(channelLabel)
                        .font(Theme.led(12))
                        .foregroundStyle(Theme.yellow)
                        .lineLimit(1)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Theme.dim)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(Theme.navy).overlay(Capsule().strokeBorder(Theme.deep, lineWidth: 1)))
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel("Channel: \(channelLabel). Change channel")

            Text(player.now.title.isEmpty ? "Tuning in…" : player.now.title)
                .font(Theme.display(24))
                .foregroundStyle(Theme.text)
                .outlined(1, drop: 2)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .contentTransition(.opacity)
            Text(player.now.artist.isEmpty ? " " : player.now.artist)
                .font(Theme.label(17, weight: .bold))
                .foregroundStyle(Theme.salmon)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.easeInOut(duration: 0.25), value: player.now)
    }

    private var channelLabel: String {
        let name = player.now.channelName.isEmpty ? "MTV REWIND" : player.now.channelName
        return "\(player.now.icon) \(name.uppercased())"
    }
}

// MARK: Remote

private struct Remote: View {
    let player: PlayerController
    @Binding var sheet: AppSheet?
    let onFull: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 22) {
                RoundButton(symbol: "backward.fill", size: 58, style: .light, label: "Previous") {
                    player.previous()
                }
                RoundButton(
                    symbol: player.now.playing ? "pause.fill" : "play.fill",
                    size: 76, style: .enter, label: player.now.playing ? "Pause" : "Play"
                ) {
                    player.playPause()
                }
                RoundButton(symbol: "forward.fill", size: 58, style: .light, label: "Next") {
                    player.next()
                }
            }
            .padding(.top, 4)

            HStack(spacing: 10) {
                PillButton(
                    symbol: player.now.saved ? "heart.fill" : "heart",
                    title: player.now.saved ? "Saved" : "Save",
                    highlighted: player.now.saved
                ) { player.toggleSave() }
                if let url = player.shareURL {
                    ShareLink(item: url, subject: Text(shareText), message: Text(shareText)) {
                        PillLabel(symbol: "square.and.arrow.up", title: "Share")
                    }
                    .buttonStyle(PressableStyle())
                    .simultaneousGesture(TapGesture().onEnded { Haptics.click() })
                } else {
                    PillButton(symbol: "square.and.arrow.up", title: "Share") {}
                        .disabled(true)
                }
                PillButton(symbol: "exclamationmark.arrow.triangle.2.circlepath", title: "Skip") {
                    player.skip()
                }
                PillButton(symbol: "arrow.up.left.and.arrow.down.right", title: "Full") {
                    Haptics.click()
                    onFull()
                }
            }

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                BigTile(symbol: "tv", title: "Channels", tint: Theme.sky) { open(.channels) }
                BigTile(symbol: "clock.arrow.circlepath", title: "Time Machine", tint: Theme.yellow) {
                    open(.timeMachine)
                }
                BigTile(symbol: "magnifyingglass", title: "Search", tint: Theme.pink) { open(.search) }
                BigTile(symbol: "heart.text.square", title: "Saved", tint: Theme.salmon) { open(.saved) }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(LinearGradient(colors: [Theme.deep, Theme.navy], startPoint: .top, endPoint: .bottom))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(Theme.royal, lineWidth: 1.5)
                )
        )
    }

    private var shareText: String {
        [player.now.artist, player.now.title].filter { !$0.isEmpty }.joined(separator: " – ")
    }

    private func open(_ which: AppSheet) {
        Haptics.click()
        sheet = which
    }
}

/// Prev / play / next over the picture in full screen; tap the picture to show it.
private struct FloatingRemote: View {
    let player: PlayerController
    let canExit: Bool
    let onExit: () -> Void

    var body: some View {
        HStack(spacing: 18) {
            RoundButton(symbol: "backward.fill", size: 50, style: .light, label: "Previous") {
                player.previous()
            }
            RoundButton(
                symbol: player.now.playing ? "pause.fill" : "play.fill",
                size: 62, style: .enter, label: player.now.playing ? "Pause" : "Play"
            ) { player.playPause() }
            RoundButton(symbol: "forward.fill", size: 50, style: .light, label: "Next") {
                player.next()
            }
            if canExit {
                RoundButton(
                    symbol: "arrow.down.right.and.arrow.up.left", size: 50, style: .light,
                    label: "Exit full screen"
                ) {
                    Haptics.click()
                    onExit()
                }
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: Capsule())
    }
}

struct RoundButton: View {
    enum Style { case enter, light }

    let symbol: String
    var size: CGFloat = 56
    var style: Style = .light
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size * 0.36, weight: .heavy))
                .foregroundStyle(style == .enter ? Theme.text : Theme.ink)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: size, height: size)
                .background(face)
        }
        .buttonStyle(PressableStyle(scale: 0.9))
        .accessibilityLabel(label)
    }

    /// Enter-button style (pink to blue, yellow ring) or light blue, both with a dark
    /// outline and a hard drop shadow.
    @ViewBuilder private var face: some View {
        switch style {
        case .enter:
            Circle()
                .fill(Theme.enter)
                .overlay(Circle().strokeBorder(Theme.yellow, lineWidth: size * 0.07))
                .overlay(Circle().strokeBorder(Theme.ink, lineWidth: 2))
                .background(Circle().fill(Theme.purple).offset(y: 4))
                .background(Circle().strokeBorder(Theme.ink, lineWidth: 2).offset(y: 4))
        case .light:
            Circle()
                .fill(Theme.lightBlue)
                .overlay(Circle().strokeBorder(Theme.ink, lineWidth: 2))
                .background(Circle().fill(Theme.ink).offset(y: 3))
        }
    }
}

struct PillLabel: View {
    let symbol: String
    let title: String
    var highlighted = false

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
            Text(title)
                .font(Theme.label(10, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .foregroundStyle(highlighted ? Theme.ink : Theme.text)
        .frame(maxWidth: .infinity, minHeight: 48)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(highlighted ? Theme.salmon : Theme.navy)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(highlighted ? Theme.ink : Theme.royal.opacity(0.6), lineWidth: 1)
                )
        )
    }
}

struct PillButton: View {
    let symbol: String
    let title: String
    var highlighted = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            PillLabel(symbol: symbol, title: title, highlighted: highlighted)
        }
        .buttonStyle(PressableStyle())
    }
}

private struct BigTile: View {
    let symbol: String
    let title: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 26)
                Text(title)
                    .font(Theme.label(15, weight: .bold))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Theme.navy)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Theme.royal.opacity(0.6), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PressableStyle())
    }
}

// MARK: Loading and offline

/// The icon on black with a spinner, until the player loads.
private struct LoadingView: View {
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(spacing: 28) {
                AppIconImage()
                Wordmark(size: 22)
                ProgressView()
                    .tint(Theme.pink)
                    .controlSize(.large)
            }
        }
    }
}

private struct OfflineView: View {
    let retry: () -> Void

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(spacing: 18) {
                AppIconImage()
                    .opacity(0.6)
                Text(L10n.offlineTitle)
                    .font(.title2.bold())
                    .foregroundStyle(Theme.text)
                Text(L10n.offlineMessage)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.dim)
                Button(action: retry) {
                    Text(L10n.retry)
                        .font(.headline)
                        .padding(.horizontal, 36)
                        .padding(.vertical, 12)
                        .background(Theme.enter, in: Capsule())
                        .overlay(Capsule().strokeBorder(Theme.yellow, lineWidth: 3))
                        .foregroundStyle(Color.white)
                }
                .padding(.top, 6)
            }
            .padding(32)
        }
    }
}

struct AppIconImage: View {
    var size: CGFloat = 120

    private static let image: UIImage? = Bundle.module
        .path(forResource: "LaunchIcon", ofType: "png")
        .flatMap { UIImage(contentsOfFile: $0) }

    var body: some View {
        if let image = Self.image {
            Image(uiImage: image)
                .resizable()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.225, style: .continuous))
        }
    }
}
