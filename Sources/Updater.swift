import AppKit
import Sparkle

/// In-app updates via Sparkle. The feed URL and public key come from Info.plist
/// (filled in by build.sh from config.sh).
final class Updater: NSObject {
    static let shared = Updater()

    private let controller = SPUStandardUpdaterController(startingUpdater: true,
                                                          updaterDelegate: nil,
                                                          userDriverDelegate: nil)
    private var updater: SPUUpdater { controller.updater }

    /// False when the build has no signing key yet (Sparkle would refuse updates).
    var isConfigured: Bool {
        let key = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String ?? ""
        return !key.isEmpty
    }

    var automaticallyChecks: Bool {
        get { updater.automaticallyChecksForUpdates }
        set { updater.automaticallyChecksForUpdates = newValue }
    }

    @objc func checkForUpdates() {
        NSApp.activate(ignoringOtherApps: true)
        controller.checkForUpdates(nil)
    }
}
