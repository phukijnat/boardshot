import AppKit
import AVKit
import UniformTypeIdentifiers

/// Trims a screen recording, like clicking the macOS thumbnail of one: a
/// window with the system player in trim mode. Trim writes the shorter clip
/// over the file (no re-encoding), keeping its creation date; Cancel or
/// closing the window leaves it as it was.
final class VideoTrim: NSObject, NSWindowDelegate {
    static let shared = VideoTrim()

    private var window: NSWindow?
    private var playerView: AVPlayerView?
    private var statusObserver: NSKeyValueObservation?
    private var url: URL?

    static func canTrim(_ url: URL) -> Bool {
        UTType(filenameExtension: url.pathExtension)?.conforms(to: .movie) ?? false
    }

    func edit(_ url: URL) {
        close()
        self.url = url
        let item = AVPlayerItem(url: url)
        let view = AVPlayerView()
        view.controlsStyle = .inline
        view.player = AVPlayer(playerItem: item)
        playerView = view

        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        let area = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: area.width * 0.6, height: area.height * 0.6),
                         styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        w.title = url.deletingPathExtension().lastPathComponent
        w.contentView = view
        w.isReleasedWhenClosed = false
        w.delegate = self
        w.setFrameOrigin(NSPoint(x: area.midX - w.frame.width / 2, y: area.midY - w.frame.height / 2))
        window = w
        NSApp.activate(ignoringOtherApps: true)
        w.makeKeyAndOrderFront(nil)

        // Trim mode can start once the clip has loaded.
        statusObserver = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            guard item.status == .readyToPlay else { return }
            DispatchQueue.main.async { self?.beginTrimming() }
        }
    }

    private func beginTrimming() {
        statusObserver = nil
        guard let view = playerView, view.canBeginTrimming else { return }
        view.beginTrimming { [weak self] result in
            guard let self else { return }
            if result == .okButton, let item = view.player?.currentItem, let url = self.url {
                self.export(item, over: url)
            } else {
                self.close()
            }
        }
    }

    /// The trim handles set the item's playback start and end.
    private func export(_ item: AVPlayerItem, over target: URL) {
        let duration = item.duration
        var start = item.reversePlaybackEndTime
        var end = item.forwardPlaybackEndTime
        if !start.isValid { start = .zero }
        if !end.isValid { end = duration }
        guard start > .zero || end < duration else { close(); return }   // nothing trimmed

        playerView?.player?.pause()
        let fm = FileManager.default
        let type: AVFileType = target.pathExtension.lowercased() == "mp4" ? .mp4 : .mov
        guard let session = AVAssetExportSession(asset: item.asset, presetName: AVAssetExportPresetPassthrough),
              let dir = try? fm.url(for: .itemReplacementDirectory, in: .userDomainMask,
                                    appropriateFor: target, create: true) else { fail(); return }
        let temp = dir.appendingPathComponent(target.lastPathComponent)
        session.outputURL = temp
        session.outputFileType = type
        session.timeRange = CMTimeRange(start: start, end: end)
        window?.title = tr("กำลังบันทึก…", "Saving…")
        session.exportAsynchronously { [weak self] in
            DispatchQueue.main.async {
                guard let self else { return }
                defer { try? FileManager.default.removeItem(at: dir) }
                guard session.status == .completed else { self.fail(); return }
                let created = (try? target.resourceValues(forKeys: [.creationDateKey]))?.creationDate
                do {
                    _ = try FileManager.default.replaceItemAt(target, withItemAt: temp)
                    if let created { try? FileManager.default.setAttributes([.creationDate: created], ofItemAtPath: target.path) }
                    self.close()
                } catch {
                    self.fail()
                }
            }
        }
    }

    private func fail() {
        NSSound.beep()
        close()
    }

    private func close() {
        statusObserver = nil
        playerView?.player?.pause()
        playerView?.player = nil
        playerView = nil
        window?.delegate = nil
        window?.close()
        window = nil
        url = nil
    }

    // Closing the window cancels.
    func windowWillClose(_ notification: Notification) {
        window?.delegate = nil
        playerView?.player?.pause()
        playerView?.player = nil
        playerView = nil
        statusObserver = nil
        window = nil
        url = nil
    }
}
