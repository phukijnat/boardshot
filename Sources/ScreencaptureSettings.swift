import Foundation

/// Reads and writes the system screenshot settings (`com.apple.screencapture`).
/// When "manage screenshots" is on, screenshots go to Boardshot's folder and the
/// floating thumbnail follows `Prefs.thumbStyle`: off (files land instantly) unless
/// the user picked the macOS thumbnail. Turning "manage screenshots" off in Settings
/// puts the user's original values back. Quitting the app puts back only the
/// thumbnail, so captures still show feedback; screenshots keep going to the folder.
enum ScreencaptureSettings {
    private static let domain = "com.apple.screencapture"
    /// macOS 26 and earlier read "location" for screenshots and recordings.
    /// macOS 27 reportedly reads "location-screenshot" and
    /// "location-screenrecording" instead (not yet checked on 27), so all three
    /// are written on every version; older ones ignore the new keys.
    private static let folderKeys = ["location", "location-screenshot", "location-screenrecording"]
    private static let thumbKey = "show-thumbnail"
    private static let keys = folderKeys + [thumbKey]

    // Our own storage for the user's original values.
    private static let store = UserDefaults.standard
    private static func savedKey(_ k: String) -> String { "original." + k }
    private static func savedMark(_ k: String) -> String { "originalSaved." + k }
    /// Versions before 0.2.3 marked "location" and "show-thumbnail" saved with one flag.
    private static let legacyFlag = "originalsSaved"
    private static let legacyKeys: Set<String> = ["location", "show-thumbnail"]

    private static func isSaved(_ k: String) -> Bool {
        store.bool(forKey: savedMark(k)) || (legacyKeys.contains(k) && store.bool(forKey: legacyFlag))
    }

    static func apply(folder: URL, systemThumbnail: Bool) {
        // Already set up: don't restart the system UI on every launch.
        let stale = folderKeys.filter { read($0) != folder.path }
        if stale.isEmpty, read(thumbKey) == (systemThumbnail ? "1" : "0") { return }

        // Remember each original once, so it stays the user's real value. Keys
        // added later are saved the first time they're seen; our own folder is
        // never taken as an original (macOS 27 may carry "location" over).
        for k in keys where !isSaved(k) {
            if let v = read(k), !(folderKeys.contains(k) && v == folder.path) {
                store.set(v, forKey: savedKey(k))
            } else {
                store.removeObject(forKey: savedKey(k))
            }
            store.set(true, forKey: savedMark(k))
        }
        for k in stale { defaults(["write", domain, k, "-string", folder.path]) }
        defaults(["write", domain, thumbKey, "-bool", systemThumbnail ? "true" : "false"])
        // Restarting the system UI blocks screenshots for a few seconds, so only
        // do it when a folder this macOS reads changes. The thumbnail setting is
        // read on each capture and applies without a restart.
        if stale.contains(where: { $0 == "location" || isMacOS27 }) { refreshSystemUI() }
    }

    /// Puts back what the user had before Boardshot. If nothing was saved,
    /// falls back to the macOS defaults (Desktop, thumbnail on).
    /// Whether Boardshot has changed the system settings and remembers what to put back.
    static var hasSavedOriginals: Bool { keys.contains(where: isSaved) }

    static func restore() {
        // Nothing of ours to undo (never applied, or already restored): leave the
        // user's settings alone and don't restart the system UI on every launch.
        guard hasSavedOriginals else { return }
        // A new folder key with no original of its own (it held our folder, or
        // didn't exist yet) follows the user's original "location".
        let legacyFolder = isSaved("location") ? store.string(forKey: savedKey("location")) : nil
        for k in keys {
            let own = isSaved(k) ? store.string(forKey: savedKey(k)) : nil
            let fallback = (k != "location" && folderKeys.contains(k)) ? legacyFolder : nil
            if let v = own ?? fallback {
                if k == thumbKey {
                    defaults(["write", domain, k, "-bool", isOn(v) ? "true" : "false"])
                } else {
                    defaults(["write", domain, k, "-string", v])
                }
            } else {
                defaults(["delete", domain, k])
            }
            store.removeObject(forKey: savedKey(k))
            store.removeObject(forKey: savedMark(k))
        }
        store.removeObject(forKey: legacyFlag)
        refreshSystemUI()
    }

    /// The user's own `show-thumbnail` from before Boardshot (macOS default: on).
    static var originalThumbnail: Bool {
        guard isSaved(thumbKey), let v = store.string(forKey: savedKey(thumbKey)) else { return true }
        return isOn(v)
    }

    /// Puts back only the user's original `show-thumbnail`, keeping the folder
    /// and the saved originals. Used on quit, when Boardshot's own corner
    /// thumbnail goes away. No system UI restart: the thumbnail setting applies
    /// on the next capture.
    static func restoreThumbnail() {
        defaults(["write", domain, thumbKey, "-bool", originalThumbnail ? "true" : "false"])
    }

    private static func isOn(_ v: String) -> Bool { v == "1" || v.lowercased() == "true" }

    private static var isMacOS27: Bool {
        ProcessInfo.processInfo.isOperatingSystemAtLeast(OperatingSystemVersion(majorVersion: 27, minorVersion: 0, patchVersion: 0))
    }

    private static func read(_ key: String) -> String? {
        let (code, out) = defaults(["read", domain, key])
        guard code == 0 else { return nil }
        let v = out.trimmingCharacters(in: .whitespacesAndNewlines)
        return v.isEmpty ? nil : v
    }

    private static func refreshSystemUI() {
        run("/usr/bin/killall", ["SystemUIServer"])
    }

    @discardableResult
    private static func defaults(_ args: [String]) -> (Int32, String) {
        run("/usr/bin/defaults", args)
    }

    @discardableResult
    private static func run(_ path: String, _ args: [String]) -> (Int32, String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = Pipe()
        do { try p.run() } catch { return (-1, "") }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return (p.terminationStatus, String(data: data, encoding: .utf8) ?? "")
    }
}
