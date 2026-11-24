import AVFoundation
import SwiftUI

/// Black behind the page, so there's no white flash before the player draws.
extension UIColor {
    static let mtvBlack = UIColor.black
}

@main
struct WantMyMTVApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // .playback (plus UIBackgroundModes=audio) lets a video's sound keep going
        // with the screen locked, and play with the silent switch on. Only the category
        // is set: the session isn't activated at launch, so opening the app doesn't
        // stop music already playing. WebKit activates it when a video starts.
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        } catch {
            print("Failed to configure audio session: \(error)")
        }
        return true
    }
}
