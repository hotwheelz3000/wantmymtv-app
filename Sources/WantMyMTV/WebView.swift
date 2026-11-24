import SwiftUI
import UIKit
import WebKit

struct WebView: UIViewRepresentable {
    let state: PlayerController

    func makeCoordinator() -> Coordinator {
        Coordinator(state: state)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        // Videos play in the page (not forced fullscreen), start without an extra tap,
        // and can go to AirPlay or Picture in Picture.
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.allowsAirPlayForMediaPlayback = true
        configuration.allowsPictureInPictureMediaPlayback = true
        configuration.websiteDataStore = .default()
        // No web fullscreen: iOS's fullscreen video window sat on top of the app and
        // took every tap. The app's Full button and landscape mode do the job instead.
        configuration.preferences.isElementFullscreenEnabled = false

        let controller = configuration.userContentController
        controller.addUserScript(
            WKUserScript(source: AppScripts.page, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        )
        controller.addUserScript(
            WKUserScript(source: AppScripts.noZoom, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        )
        // The site turned into just the picture, with the app's API on window.__app.
        controller.addUserScript(
            WKUserScript(source: AppScripts.main, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        )
        controller.add(context.coordinator, name: AppScripts.mediaHandler)
        controller.add(context.coordinator, name: AppScripts.stateHandler)

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = false
        // No peek-and-pop link previews: feels like an app, not a browser.
        webView.allowsLinkPreview = false
        // Transparent until the page paints, so black shows instead of white.
        webView.isOpaque = false
        webView.backgroundColor = .mtvBlack
        webView.scrollView.backgroundColor = .mtvBlack
        webView.underPageBackgroundColor = .mtvBlack
        // No extra space added at the bottom for the home indicator: the page fills it.
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.alwaysBounceHorizontal = false
        webView.scrollView.showsHorizontalScrollIndicator = false
        webView.scrollView.pinchGestureRecognizer?.isEnabled = false
        webView.scrollView.isScrollEnabled = false
        // The page never gets touches: the app's own controls drive it, so YouTube's
        // overlay and fullscreen button can't take over.
        webView.isUserInteractionEnabled = false

        context.coordinator.webView = webView
        state.webView = webView
        webView.load(URLRequest(url: PlayerController.homeURL))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: AppScripts.mediaHandler)
        webView.configuration.userContentController.removeScriptMessageHandler(forName: AppScripts.stateHandler)
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        let state: PlayerController
        weak var webView: WKWebView?
        /// The page or embedded player whose video is playing, for Picture in Picture.
        private var playingFrame: WKFrameInfo?
        /// The last frame that reported any video, playing or not, so a video iOS put in
        /// Picture in Picture by itself can still be brought back.
        private var mediaFrame: WKFrameInfo?
        private var inPiP = false
        private var observers: [NSObjectProtocol] = []

        init(state: PlayerController) {
            self.state = state
            super.init()
            let center = NotificationCenter.default
            // Leaving the app with a video playing: keep it going in Picture in Picture.
            observers.append(center.addObserver(
                forName: UIApplication.willResignActiveNotification, object: nil, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.enterPiP() }
            })
            // Back in the app: put the video back in the page.
            observers.append(center.addObserver(
                forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.exitPiP() }
            })
        }

        // MARK: Playback

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            if message.name == AppScripts.stateHandler {
                state.receive(message.body)
                return
            }
            guard let body = message.body as? [String: Any], let playing = body["playing"] as? Bool else { return }
            mediaFrame = message.frameInfo
            if playing {
                playingFrame = message.frameInfo
            } else if playingFrame?.securityOrigin.host == message.frameInfo.securityOrigin.host {
                playingFrame = nil
            }
            // The screen stays on while a video plays, and sleeps normally once it stops.
            UIApplication.shared.isIdleTimerDisabled = playingFrame != nil
        }

        private func enterPiP() {
            guard let webView, let frame = playingFrame else { return }
            webView.evaluateJavaScript(
                "window.__mtvPiP ? window.__mtvPiP(true) : false", in: frame, in: .page
            ) { [weak self] result in
                if case .success(let value) = result, (value as? Bool) == true { self?.inPiP = true }
            }
        }

        /// Back in the app: always put the video back in the page, whatever started
        /// Picture in Picture (the app, iOS or the player), then let the page re-fit it.
        private func exitPiP() {
            inPiP = false
            guard let webView else { return }
            for frame in [playingFrame, mediaFrame].compactMap({ $0 }) {
                webView.evaluateJavaScript("window.__mtvPiP && window.__mtvPiP(false)", in: frame, in: .page)
            }
            state.relayout()
        }

        // MARK: Navigation

        /// wantmymtv.org and its subdomains stay in the app.
        private func isInternal(_ url: URL) -> Bool {
            guard let host = url.host?.lowercased() else { return true }
            return host == "wantmymtv.org" || host.hasSuffix(".wantmymtv.org")
        }

        private func isWebScheme(_ url: URL) -> Bool {
            let scheme = url.scheme?.lowercased() ?? ""
            return ["http", "https", "about", "blob", "data"].contains(scheme)
        }

        private func openExternally(_ url: URL) {
            UIApplication.shared.open(url)
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction
        ) async -> WKNavigationActionPolicy {
            guard let url = navigationAction.request.url else { return .allow }

            // mailto:, tel:, App Store links, etc.
            if !isWebScheme(url) {
                openExternally(url)
                return .cancel
            }

            // The embedded YouTube players load normally.
            let isMainFrame = navigationAction.targetFrame?.isMainFrame ?? true
            guard isMainFrame else { return .allow }

            // Links you tap that leave the site (YouTube, IMVDb) open in Safari or their app.
            if !isInternal(url)
                && (navigationAction.targetFrame == nil || navigationAction.navigationType == .linkActivated)
            {
                openExternally(url)
                return .cancel
            }
            return .allow
        }

        // window.open / target=_blank: the site's pages stay here, others go to Safari.
        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            if let url = navigationAction.request.url {
                if isInternal(url) && isWebScheme(url) {
                    webView.load(navigationAction.request)
                } else {
                    openExternally(url)
                }
            }
            return nil
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.scrollView.pinchGestureRecognizer?.isEnabled = false
            state.offline = false
            // The loading screen fades once the first video reports in, or after a few
            // seconds at most (a video that needs a tap to start, say).
            DispatchQueue.main.asyncAfter(deadline: .now() + 6) { [weak self] in
                MainActor.assumeIsolated { self?.state.loaded = true }
            }
        }

        /// Nothing loaded at all (no connection when the app opened): show the offline screen.
        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
        ) {
            if (error as NSError).code == NSURLErrorCancelled { return }
            guard !state.loaded, webView.backForwardList.currentItem == nil else { return }
            state.offline = true
        }

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            playingFrame = nil
            mediaFrame = nil
            UIApplication.shared.isIdleTimerDisabled = false
            webView.reload()
        }
    }
}
