import Network
import Observation
import UIKit
import WebKit

/// A channel from the site's list.
struct Channel: Identifiable, Hashable, Decodable {
    let key: String
    let name: String
    let icon: String
    let count: Int
    var id: String { key }
}

/// A group of channels ("Curated collections", "Record labels"...).
struct ChannelSection: Identifiable, Decodable {
    let id: String
    let name: String
    let channels: [Channel]
}

/// A search result from the site's index.
struct Track: Identifiable, Hashable, Decodable {
    let id: String
    let artist: String
    let title: String
}

/// A video in the site's "Your Saved Videos" list.
struct SavedVideo: Identifiable, Hashable, Decodable {
    let id: String
    let title: String
}

/// What's on now, as the page reports it every second.
struct NowPlaying: Equatable, Decodable {
    var title = ""
    var artist = ""
    var channel = ""
    var channelName = ""
    var icon = "📺"
    var playing = false
    var videoId = ""
    var saved = false
}

/// Talks to the site through `window.__app` and keeps the native screens up to date.
@MainActor
@Observable
final class PlayerController {
    /// tv=1 is the site's own TV mode (made for its Android TV app): YouTube's controls
    /// and fullscreen button are off, popups are skipped, and it resumes the last channel.
    static let homeURL = URL(string: "https://wantmymtv.org/player.html?tv=1")!

    /// True once the player has loaded for the first time.
    var loaded = false
    /// True when the site couldn't load at all (no connection when the app opened).
    var offline = false
    var now = NowPlaying()
    /// A short message under the picture ("Saved", "Skipping...").
    var toast: String?

    @ObservationIgnored weak var webView: WKWebView?
    @ObservationIgnored private let monitor = NWPathMonitor()
    @ObservationIgnored private var toastTask: Task<Void, Never>?

    init() {
        // When the connection comes back while the offline screen is up, try again by itself.
        monitor.pathUpdateHandler = { [weak self] path in
            guard path.status == .satisfied else { return }
            Task { @MainActor in
                guard let self, self.offline else { return }
                self.retry()
            }
        }
        monitor.start(queue: DispatchQueue(label: "wantmymtv.network"))
    }

    func retry() {
        offline = false
        webView?.load(URLRequest(url: Self.homeURL))
    }

    func receive(_ body: Any) {
        guard JSONSerialization.isValidJSONObject(body),
              let data = try? JSONSerialization.data(withJSONObject: body),
              let state = try? JSONDecoder().decode(NowPlaying.self, from: data)
        else { return }
        now = state
        if !state.videoId.isEmpty { loaded = true }
    }

    // MARK: Remote

    func next() { Haptics.click(); run("window.__app.next()") }
    func previous() { Haptics.click(); run("window.__app.previous()") }
    func playPause() { Haptics.click(); now.playing.toggle(); run("window.__app.playPause()") }

    func skip() {
        Haptics.click()
        show("Skipping…")
        run("window.__app.skip()")
    }

    func tune(_ channel: Channel) {
        Haptics.thunk()
        show("\(channel.icon) \(channel.name)")
        run("window.__app.channel(\(literal(channel.key)))")
    }

    func tune(year: Int) {
        Haptics.thunk()
        show("📅 MTV \(year)")
        run("window.__app.year(\(year))")
    }

    func play(_ track: Track) {
        Haptics.click()
        run("window.__app.play(\(literal(track.id)))")
    }

    func toggleSave() {
        Haptics.click()
        Task {
            let added = await value("window.__app.save()") as? Bool ?? false
            show(added ? "♥ Saved" : "Removed from saved")
            now.saved = added
        }
    }

    func playSaved(at index: Int) { Haptics.click(); run("window.__app.playSaved(\(index))") }
    func playAllSaved() { Haptics.thunk(); run("window.__app.playAll()") }
    func removeSaved(at index: Int) { run("window.__app.remove(\(index))") }

    // MARK: Lists for the sheets

    func channels() async -> [ChannelSection] {
        await decode("window.__app.catalog()") ?? []
    }

    func years() async -> [Int] {
        await decode("window.__app.years()") ?? []
    }

    func saved() async -> [SavedVideo] {
        await decode("window.__app.saved()") ?? []
    }

    func search(_ query: String) async -> [Track] {
        guard let webView else { return [] }
        let result = try? await webView.callAsyncJavaScript(
            "return await window.__app.search(q)", arguments: ["q": query], contentWorld: .page
        )
        return decodeValue(result) ?? []
    }

    /// After a rotation, Full, or coming back from Picture in Picture: the page re-fits
    /// the video to the new size.
    func relayout() {
        webView?.evaluateJavaScript(
            "window.scrollTo(0, 0); window.dispatchEvent(new Event('resize')); undefined", completionHandler: nil
        )
    }

    var shareURL: URL? {
        now.videoId.isEmpty ? nil : URL(string: "https://www.youtube.com/watch?v=\(now.videoId)")
    }

    // MARK: Helpers

    func show(_ message: String) {
        toast = message
        toastTask?.cancel()
        toastTask = Task {
            try? await Task.sleep(for: .seconds(2))
            if !Task.isCancelled { toast = nil }
        }
    }

    private func run(_ script: String) {
        webView?.evaluateJavaScript("window.__app && \(script); undefined", completionHandler: nil)
    }

    private func value(_ script: String) async -> Any? {
        guard let webView else { return nil }
        return try? await webView.callAsyncJavaScript(
            "return window.__app ? \(script) : null", contentWorld: .page
        )
    }

    private func decode<T: Decodable>(_ script: String) async -> T? {
        decodeValue(await value(script))
    }

    private func decodeValue<T: Decodable>(_ value: Any?) -> T? {
        guard let value, JSONSerialization.isValidJSONObject(value),
              let data = try? JSONSerialization.data(withJSONObject: value)
        else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    /// A JavaScript string literal for `text`.
    private func literal(_ text: String) -> String {
        let data = (try? JSONSerialization.data(withJSONObject: [text])) ?? Data("[\"\"]".utf8)
        let array = String(decoding: data, as: UTF8.self)
        return String(array.dropFirst().dropLast())
    }
}
