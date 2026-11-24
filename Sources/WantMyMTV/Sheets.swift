import SwiftUI

/// The look shared by every sheet: a dark panel, a title and a Done button.
private struct SheetFrame<Content: View>: View {
    let title: String
    var detents: Set<PresentationDetent> = [.medium, .large]
    @ViewBuilder let content: Content
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            content
                .scrollContentBackground(.hidden)
                .background(Theme.panel.ignoresSafeArea())
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                            .font(Theme.label(16, weight: .bold))
                            .tint(Theme.pink)
                    }
                }
        }
        .presentationDetents(detents)
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.panel)
        .preferredColorScheme(.dark)
    }
}

private struct Placeholder: View {
    let symbol: String
    let text: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(Theme.dim)
            Text(text)
                .font(Theme.label(15))
                .foregroundStyle(Theme.dim)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }
}

// MARK: Channels

struct ChannelsSheet: View {
    let player: PlayerController
    @State private var sections: [ChannelSection]?
    @State private var filter = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        SheetFrame(title: "Channels") {
            Group {
                if let sections {
                    List {
                        ForEach(filtered(sections)) { section in
                            Section {
                                ForEach(section.channels) { channel in
                                    row(channel)
                                }
                            } header: {
                                Text(section.name)
                                    .font(Theme.led(12))
                                    .foregroundStyle(Theme.cyan)
                            }
                            .listRowBackground(Color.white.opacity(0.04))
                        }
                    }
                    .listStyle(.insetGrouped)
                    .searchable(text: $filter, prompt: "Find a channel")
                } else {
                    ProgressView().tint(Theme.pink).frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .task { sections = await player.channels() }
    }

    private func row(_ channel: Channel) -> some View {
        let on = channel.key == player.now.channel
        return Button {
            player.tune(channel)
            dismiss()
        } label: {
            HStack(spacing: 12) {
                Text(channel.icon).font(.system(size: 22)).frame(width: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(channel.name)
                        .font(Theme.label(15, weight: .bold))
                        .foregroundStyle(on ? Theme.pink : Theme.text)
                    if channel.count >= 1 {
                        Text("\(channel.count.formatted()) videos")
                            .font(Theme.label(12))
                            .foregroundStyle(Theme.dim)
                    }
                }
                Spacer()
                if on {
                    Image(systemName: "dot.radiowaves.left.and.right")
                        .foregroundStyle(Theme.pink)
                }
            }
        }
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private func filtered(_ sections: [ChannelSection]) -> [ChannelSection] {
        let query = filter.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return sections }
        return sections.compactMap { section in
            let matches = section.channels.filter { $0.name.localizedCaseInsensitiveContains(query) }
            return matches.isEmpty ? nil : ChannelSection(id: section.id, name: section.name, channels: matches)
        }
    }
}

// MARK: Time Machine

struct TimeMachineSheet: View {
    let player: PlayerController
    @State private var years: [Int]?
    @State private var decade = 1980
    @Environment(\.dismiss) private var dismiss

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 5)

    var body: some View {
        SheetFrame(title: "Time Machine") {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Set the dial. Tune into the year.")
                        .font(Theme.label(15))
                        .foregroundStyle(Theme.dim)
                    if let years, !years.isEmpty {
                        decadeDial(years)
                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(years.filter { $0 / 10 * 10 == decade }, id: \.self) { year in
                                Button {
                                    player.tune(year: year)
                                    dismiss()
                                } label: {
                                    Text(String(year))
                                        .font(Theme.led(17))
                                        .foregroundStyle(Theme.yellow)
                                        .shadow(color: Theme.yellow.opacity(0.6), radius: 4)
                                        .frame(maxWidth: .infinity, minHeight: 52)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .fill(Color.black.opacity(0.5))
                                        )
                                }
                                .buttonStyle(PressableStyle())
                            }
                        }
                        Button {
                            let pool = years.filter { $0 / 10 * 10 == decade }
                            if let year = pool.randomElement() {
                                player.tune(year: year)
                                dismiss()
                            }
                        } label: {
                            Label("Surprise me from the \(decadeName(decade))", systemImage: "shuffle")
                                .font(Theme.label(15, weight: .bold))
                                .foregroundStyle(Color.black)
                                .frame(maxWidth: .infinity, minHeight: 50)
                                .background(Theme.yellow, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(PressableStyle())
                    } else if years == nil {
                        ProgressView().tint(Theme.pink).frame(maxWidth: .infinity)
                    } else {
                        Placeholder(symbol: "clock", text: "The Time Machine is still loading. Try again in a moment.")
                    }
                }
                .padding(18)
            }
        }
        .task {
            let list = await player.years()
            years = list
            if let mid = list.first(where: { $0 >= 1980 }) ?? list.first { decade = mid / 10 * 10 }
        }
    }

    private func decadeDial(_ years: [Int]) -> some View {
        let decades = Array(Set(years.map { $0 / 10 * 10 })).sorted()
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(decades, id: \.self) { d in
                    let on = d == decade
                    Button {
                        Haptics.tick()
                        decade = d
                    } label: {
                        Text(decadeName(d))
                            .font(Theme.label(15, weight: .heavy))
                            .foregroundStyle(on ? Color.black : Theme.dim)
                            .padding(.horizontal, 16)
                            .frame(minHeight: 38)
                            .background(
                                Capsule().fill(on ? Theme.yellow : Color.white.opacity(0.06))
                                    .shadow(color: on ? Theme.yellow.opacity(0.6) : .clear, radius: 8)
                            )
                    }
                    .buttonStyle(PressableStyle())
                }
            }
        }
        .animation(.snappy, value: decade)
    }

    private func decadeName(_ d: Int) -> String {
        d < 2000 ? "\(d % 100)s" : "\(d)s"
    }
}

// MARK: Search

struct SearchSheet: View {
    let player: PlayerController
    @State private var query = ""
    @State private var results: [Track] = []
    @State private var searching = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        SheetFrame(title: "Search", detents: [.large]) {
            List {
                ForEach(results) { track in
                    Button {
                        player.play(track)
                        dismiss()
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(track.title)
                                .font(Theme.label(15, weight: .bold))
                                .foregroundStyle(Theme.text)
                            Text(track.artist)
                                .font(Theme.label(13))
                                .foregroundStyle(Theme.pink)
                        }
                    }
                    .listRowBackground(Color.white.opacity(0.04))
                }
            }
            .listStyle(.plain)
            .overlay {
                if searching && results.isEmpty {
                    ProgressView().tint(Theme.pink)
                } else if results.isEmpty {
                    Placeholder(
                        symbol: "magnifyingglass",
                        text: query.isEmpty ? "Search 113,000+ videos by artist or song." : "No videos found."
                    )
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Artist or song")
            .task(id: query) {
                let q = query.trimmingCharacters(in: .whitespaces)
                guard q.count >= 2 else { results = []; return }
                try? await Task.sleep(for: .milliseconds(300))
                if Task.isCancelled { return }
                searching = true
                let found = await player.search(q)
                if !Task.isCancelled { results = found }
                searching = false
            }
        }
    }
}

// MARK: Saved

struct SavedSheet: View {
    let player: PlayerController
    @State private var videos: [SavedVideo]?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        SheetFrame(title: "Saved") {
            Group {
                if let videos, !videos.isEmpty {
                    List {
                        Section {
                            Button {
                                player.playAllSaved()
                                dismiss()
                            } label: {
                                Label("Play all \(videos.count)", systemImage: "play.fill")
                                    .font(Theme.label(15, weight: .bold))
                                    .foregroundStyle(Theme.pink)
                            }
                            .listRowBackground(Color.white.opacity(0.04))
                        }
                        Section {
                            ForEach(Array(videos.enumerated()), id: \.offset) { index, video in
                                Button {
                                    player.playSaved(at: index)
                                    dismiss()
                                } label: {
                                    HStack(spacing: 12) {
                                        Text("\(index + 1)")
                                            .font(Theme.led(13))
                                            .foregroundStyle(Theme.dim)
                                            .frame(width: 26)
                                        Text(video.title.isEmpty ? "Video \(index + 1)" : video.title)
                                            .font(Theme.label(15, weight: .semibold))
                                            .foregroundStyle(Theme.text)
                                    }
                                }
                                .listRowBackground(Color.white.opacity(0.04))
                            }
                            .onDelete { offsets in
                                for index in offsets.sorted(by: >) { player.removeSaved(at: index) }
                                self.videos?.remove(atOffsets: offsets)
                            }
                        } footer: {
                            Text("Tap ♥ Save on the remote to add the video that's playing. Swipe left to remove.")
                                .foregroundStyle(Theme.dim)
                        }
                    }
                    .listStyle(.insetGrouped)
                } else if videos == nil {
                    ProgressView().tint(Theme.pink).frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Placeholder(symbol: "heart", text: "Nothing saved yet.\nTap ♥ Save on the remote to keep a video.")
                }
            }
        }
        .task { videos = await player.saved() }
    }
}

// MARK: About

struct AboutView: View {
    var body: some View {
        SheetFrame(title: "About", detents: [.large]) {
            ScrollView {
                VStack(spacing: 18) {
                    AppIconImage(size: 96)
                    Wordmark(size: 22)
                    Text(BuildInfo.label)
                        .font(Theme.label(13))
                        .foregroundStyle(Theme.dim)
                    Text(
                        "An unofficial app for wantmymtv.org: 113,000+ music videos, 24/7, no ads. "
                            + "Every channel, list and video comes from the site, and the videos play from YouTube. "
                            + "Video info by IMVDb."
                    )
                    .font(Theme.label(15))
                    .foregroundStyle(Theme.text)
                    .multilineTextAlignment(.center)
                    Text("Not made by or affiliated with wantmymtv.org, MTV or Paramount.")
                        .font(Theme.label(13))
                        .foregroundStyle(Theme.dim)
                        .multilineTextAlignment(.center)
                    VStack(spacing: 10) {
                        link("Open wantmymtv.org", "https://wantmymtv.org/")
                        link("Video info by IMVDb", "https://imvdb.com/")
                    }
                    .padding(.top, 6)
                    VStack(alignment: .leading, spacing: 8) {
                        tip("Swipe the picture left or right for the next or previous video.")
                        tip("Tap the picture to pause; double-tap for full screen.")
                        tip("Turn your phone sideways for a full-screen TV.")
                        tip("Leave the app mid-video and it keeps playing in Picture in Picture.")
                    }
                    .padding(.top, 8)
                }
                .padding(24)
            }
        }
    }

    private func link(_ title: String, _ url: String) -> some View {
        Link(destination: URL(string: url)!) {
            Text(title)
                .font(Theme.label(15, weight: .bold))
                .foregroundStyle(Theme.text)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private func tip(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "sparkle").foregroundStyle(Theme.cyan)
            Text(text).font(Theme.label(14)).foregroundStyle(Theme.dim)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
