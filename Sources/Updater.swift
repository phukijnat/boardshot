import AppKit
import Sparkle

/// In-app updates via Sparkle. The feed URL and public key come from Info.plist
/// (filled in by build.sh from config.sh).
final class Updater: NSObject {
    static let shared = Updater()

    // Started by start(), not here: on a first run, Sparkle would otherwise ask
    // "Check for updates automatically?" on top of the welcome window, which
    // asks the same in the user's language.
    private let controller = SPUStandardUpdaterController(startingUpdater: false,
                                                          updaterDelegate: nil,
                                                          userDriverDelegate: nil)
    private var updater: SPUUpdater { controller.updater }

    /// False when the build has no signing key yet (Sparkle would refuse updates).
    var isConfigured: Bool {
        let key = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String ?? ""
        return !key.isEmpty
    }

    private var started = false

    func start() {
        guard !started, isConfigured else { return }
        started = true
        controller.startUpdater()
    }

    var automaticallyChecks: Bool {
        get { updater.automaticallyChecksForUpdates }
        set { updater.automaticallyChecksForUpdates = newValue }
    }

    @objc func checkForUpdates() {
        start()
        NSApp.activate(ignoringOtherApps: true)
        controller.checkForUpdates(nil)
    }
}
