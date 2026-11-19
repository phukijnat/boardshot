import Foundation

/// Reads and writes the system screenshot settings (`com.apple.screencapture`).
/// When "manage screenshots" is on, screenshots go to Boardshot's folder and the
/// floating thumbnail follows `Prefs.thumbStyle`: off (files land instantly) unless
/// the user picked the macOS thumbnail. Turning "manage screenshots" off in Settings
/// puts the user's original values back. Quitting the app puts back only the
/// thumbnail, so captures still show feedback; screenshots keep going to the folder.
///
/// Values are written through cfprefsd (CFPreferences), and the screenshot
/// service reads them on each capture, so nothing needs restarting: checked on
/// macOS 26 for the folder and the target.
enum ScreencaptureSettings {
    private static let domain = "com.apple.screencapture" as CFString
    /// macOS 26 and earlier read "location" for screenshots and recordings.
    /// macOS 27 reportedly reads "location-screenshot" and
    /// "location-screenrecording" instead (not yet checked on 27), so all three
    /// are written on every version; older ones ignore the new keys.
    private static let folderKeys = ["location", "location-screenshot", "location-screenrecording"]
    /// Whether a capture is saved as a file or sent to the clipboard, Preview,
    /// Mail and so on (⇧⌘5 → Options → Save to). Only files reach Boardshot, so
    /// all three are set to "file". Same split as the folder keys on macOS 27.
    private static let targetKeys = ["target", "target-screenshot", "target-screenrecording"]
    private static let fileTarget = "file"
    private static let thumbKey = "show-thumbnail"
    private static let keys = folderKeys + targetKeys + [thumbKey]

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
        let stale = folderKeys.filter { read($0) != folder.path }
        let staleTargets = targetKeys.filter { read($0) != fileTarget }
        if stale.isEmpty, staleTargets.isEmpty, read(thumbKey) == (systemThumbnail ? "1" : "0") { return }

        // Remember each original once, so it stays the user's real value. Keys
        // added later are saved the first time they're seen; our own folder is
        // never taken as an original (macOS 27 may carry "location" over). Users
        // updating from 0.3.0 get their target saved here the first time.
        for k in keys where !isSaved(k) {
            if let v = read(k), !(folderKeys.contains(k) && v == folder.path) {
                store.set(v, forKey: savedKey(k))
            } else {
                store.removeObject(forKey: savedKey(k))
            }
            store.set(true, forKey: savedMark(k))
        }
        for k in stale { write(k, folder.path) }
        for k in staleTargets { write(k, fileTarget) }
        write(thumbKey, systemThumbnail)
        synchronize()
    }

    /// Puts back what the user had before Boardshot. If nothing was saved,
    /// falls back to the macOS defaults (Desktop, thumbnail on).
    /// Whether Boardshot has changed the system settings and remembers what to put back.
    static var hasSavedOriginals: Bool { keys.contains(where: isSaved) }

    static func restore() {
        // Nothing of ours to undo (never applied, or already restored): leave the
        // user's settings alone.
        guard hasSavedOriginals else { return }
        // A new folder or target key with no original of its own (it held our
        // folder, or didn't exist yet) follows the user's original old-style key.
        func original(_ k: String) -> String? { isSaved(k) ? store.string(forKey: savedKey(k)) : nil }
        let legacyFolder = original("location"), legacyTarget = original("target")
        for k in keys {
            let fallback = k == "location" || k == "target" ? nil
                : folderKeys.contains(k) ? legacyFolder
                : targetKeys.contains(k) ? legacyTarget : nil
            if let v = original(k) ?? fallback {
                if k == thumbKey { write(k, isOn(v)) } else { write(k, v) }
            } else {
                write(k, nil)
            }
            store.removeObject(forKey: savedKey(k))
            store.removeObject(forKey: savedMark(k))
        }
        store.removeObject(forKey: legacyFlag)
        synchronize()
    }

    /// The user's own `show-thumbnail` from before Boardshot (macOS default: on).
    static var originalThumbnail: Bool {
        guard isSaved(thumbKey), let v = store.string(forKey: savedKey(thumbKey)) else { return true }
        return isOn(v)
    }

    /// Puts back only the user's original `show-thumbnail`, keeping the folder
    /// and the saved originals. Used on quit, when Boardshot's own corner
    /// thumbnail goes away. Applies on the next capture.
    static func restoreThumbnail() {
        write(thumbKey, originalThumbnail)
        synchronize()
    }

    private static func isOn(_ v: String) -> Bool { v == "1" || v.lowercased() == "true" }

    /// The value as `defaults read` prints it: booleans as "1" / "0".
    private static func read(_ key: String) -> String? {
        CFPreferencesAppSynchronize(domain)
        switch CFPreferencesCopyAppValue(key as CFString, domain) {
        case let n as NSNumber where CFGetTypeID(n) == CFBooleanGetTypeID(): return n.boolValue ? "1" : "0"
        case let n as NSNumber: return n.stringValue
        case let v as String: return v.isEmpty ? nil : v
        default: return nil
        }
    }

    /// nil removes the key, returning it to the macOS default.
    private static func write(_ key: String, _ value: Any?) {
        CFPreferencesSetAppValue(key as CFString, value as CFPropertyList?, domain)
    }

    private static func synchronize() { CFPreferencesAppSynchronize(domain) }
}
