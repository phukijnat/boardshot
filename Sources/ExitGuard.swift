import Foundation

/// Puts the screenshot settings back however Boardshot ends, including a crash
/// or Force Quit, when `applicationWillTerminate` never runs.
///
/// A tiny `/bin/sh` child waits on a pipe whose write end only Boardshot holds.
/// When Boardshot dies for any reason the kernel closes that end, `cat` returns,
/// and the shell runs Boardshot's own executable with `restoreArg`, which calls
/// `ScreencaptureSettings.restore()` and exits without showing anything. It
/// skips this when another Boardshot is already running (an update relaunch),
/// since that copy manages the settings itself. After a normal quit the
/// settings are already back, so the restore finds nothing to do.
enum ExitGuard {
    static let restoreArg = "--restore-screenshot-settings"
    private static var pipe: Pipe?   // kept open for the whole run; never closed

    private static let script = """
        cat >/dev/null
        /usr/bin/pgrep -x "$2" | /usr/bin/grep -vx "$3" | /usr/bin/grep -q . && exit 0
        exec "$1" \(restoreArg)
        """

    /// Starts the watcher once. Call only after the single-instance check, so a
    /// duplicate copy that quits right away doesn't trigger it.
    static func start() {
        guard pipe == nil, let exe = Bundle.main.executablePath else { return }
        UserDefaults.standard.removeObject(forKey: "thumbnailOnExit")   // used up to 0.3.2
        let p = Pipe()
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", script, "sh", exe, ProcessInfo.processInfo.processName,
                          String(ProcessInfo.processInfo.processIdentifier)]
        task.standardInput = p
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        do { try task.run() } catch { return }
        try? p.fileHandleForReading.close()   // only the child reads
        pipe = p
    }
}
