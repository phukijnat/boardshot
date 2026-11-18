import Foundation

/// Reads and writes the system screenshot settings (`com.apple.screencapture`).
/// When "manage screenshots" is on, screenshots go to Boardshot's folder and the
/// floating thumbnail follows `Prefs.thumbStyle`: off (files land instantly) unless
/// the user picked the macOS thumbnail. Turning "manage screenshots" off in Settings
/// puts the user's original values back. Quitting the app puts back only the
/// thumbnail, so captures still show feedback; screenshots keep going to the folder.
enum ScreencaptureSettings {
    private static let domain = "com.apple.screencapture"
    private static let keys = ["location", "show-thumbnail"]

    // Our own storage for the user's original values.
    private static let store = UserDefaults.standard
    private static let savedFlag = "originalsSaved"
    private static func savedKey(_ k: String) -> String { "original." + k }

    static func apply(folder: URL, systemThumbnail: Bool) {
        // Already set up: don't restart the system UI on every launch.
        let locationChanges = read("location") != folder.path
        if !locationChanges, read("show-thumbnail") == (systemThumbnail ? "1" : "0") { return }

        // Only remember originals once, so they stay the user's real values.
        if !store.bool(forKey: savedFlag) {
            for k in keys {
                if let v = read(k) { store.set(v, forKey: savedKey(k)) }
                else { store.removeObject(forKey: savedKey(k)) }
            }
            store.set(true, forKey: savedFlag)
        }
        defaults(["write", domain, "location", "-string", folder.path])
        defaults(["write", domain, "show-thumbnail", "-bool", systemThumbnail ? "true" : "false"])
        // Restarting the system UI blocks screenshots for a few seconds, so only
        // do it when the folder changes. The thumbnail setting is read on each
        // capture and applies without a restart.
        if locationChanges { refreshSystemUI() }
    }

    /// Puts back what the user had before Boardshot. If nothing was saved,
    /// falls back to the macOS defaults (Desktop, thumbnail on).
    static func restore() {
        for k in keys {
            if store.bool(forKey: savedFlag), let v = store.string(forKey: savedKey(k)) {
                if k == "show-thumbnail" {
                    let on = (v == "1" || v.lowercased() == "true")
                    defaults(["write", domain, k, "-bool", on ? "true" : "false"])
                } else {
                    defaults(["write", domain, k, "-string", v])
                }
            } else {
                defaults(["delete", domain, k])
            }
            store.removeObject(forKey: savedKey(k))
        }
        store.set(false, forKey: savedFlag)
        refreshSystemUI()
    }

    /// Puts back only the user's original `show-thumbnail` (macOS default: on),
    /// keeping the folder and the saved originals. Used on quit, when Boardshot's
    /// own corner thumbnail goes away. No system UI restart: the thumbnail
    /// setting applies on the next capture.
    static func restoreThumbnail() {
        var on = true
        if store.bool(forKey: savedFlag), let v = store.string(forKey: savedKey("show-thumbnail")) {
            on = (v == "1" || v.lowercased() == "true")
        }
        defaults(["write", domain, "show-thumbnail", "-bool", on ? "true" : "false"])
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
