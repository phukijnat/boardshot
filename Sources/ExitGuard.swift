import Foundation

/// Brings the macOS thumbnail back however Boardshot ends, including a crash or
/// Force Quit, when `applicationWillTerminate` never runs.
///
/// A tiny `/bin/sh` child waits on a pipe whose write end only Boardshot holds.
/// When Boardshot dies for any reason the kernel closes that end, `cat` returns,
/// and the shell writes the value Boardshot last left in its own defaults
/// (`thumbnailOnExit`; absent means leave the setting alone). It skips the write
/// when another Boardshot is already running (an update relaunch), since that
/// copy manages the setting itself. After a normal quit it writes the same value
/// `applicationWillTerminate` just wrote, which is harmless.
enum ExitGuard {
    private static let key = "thumbnailOnExit"
    private static var pipe: Pipe?   // kept open for the whole run; never closed

    private static let script = """
        cat >/dev/null
        v=$(/usr/bin/defaults read "$1" \(key) 2>/dev/null) || exit 0
        /usr/bin/pgrep -x "$2" | /usr/bin/grep -vx "$3" | /usr/bin/grep -q . && exit 0
        /usr/bin/defaults write com.apple.screencapture show-thumbnail -bool "$v"
        """

    /// Starts the watcher once. Call only after the single-instance check, so a
    /// duplicate copy that quits right away doesn't trigger it.
    static func start() {
        guard pipe == nil, let bundleID = Bundle.main.bundleIdentifier else { return }
        let p = Pipe()
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", script, "sh", bundleID, ProcessInfo.processInfo.processName,
                          String(ProcessInfo.processInfo.processIdentifier)]
        task.standardInput = p
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        do { try task.run() } catch { return }
        try? p.fileHandleForReading.close()   // only the child reads
        pipe = p
    }

    /// What `show-thumbnail` should become if Boardshot dies: the user's value,
    /// or nil to leave it alone (screenshots not managed, or the macOS
    /// thumbnail is already the one in use).
    static func arm(_ thumbnail: Bool?) {
        let d = UserDefaults.standard
        if let thumbnail { d.set(thumbnail ? "true" : "false", forKey: key) }
        else { d.removeObject(forKey: key) }
    }
}
