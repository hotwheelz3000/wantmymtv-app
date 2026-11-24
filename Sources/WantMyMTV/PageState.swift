import Network
import Observation
import WebKit

/// Where the page is at, for the loading and offline screens.
@MainActor
@Observable
final class PageState {
    /// True once the site has loaded for the first time.
    var loaded = false
    /// True when the site couldn't load at all (no connection when the app opened).
    var offline = false

    let homeURL: URL
    @ObservationIgnored weak var webView: WKWebView?
    @ObservationIgnored private let monitor = NWPathMonitor()

    init(homeURL: URL) {
        self.homeURL = homeURL
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
        webView?.load(URLRequest(url: homeURL))
    }
}
