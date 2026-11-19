import AppKit
import UniformTypeIdentifiers

/// Opens a screenshot in macOS's own Markup editor (the one the system
/// thumbnail opens), through the sharing service that editor registers.
/// On Done (or Cancel → Save) the editor hands back the edited image (on
/// macOS 26 an item provider holding a PNG) and we write it over the file.
final class Markup: NSObject, NSSharingServiceDelegate {
    static let shared = Markup()
    private static let service = NSSharingService.Name("com.apple.MarkupUI.Markup")

    private var editing: URL?

    /// An invisible window for the editor to open over. With no window to
    /// share from, macOS puts the editor in a corner of some screen.
    private lazy var anchor: NSWindow = {
        let w = NSWindow(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: true)
        w.isOpaque = false
        w.backgroundColor = .clear
        w.ignoresMouseEvents = true
        w.isReleasedWhenClosed = false
        w.collectionBehavior = [.transient, .ignoresCycle, .moveToActiveSpace]
        w.level = .floating
        return w
    }()

    static func canEdit(_ url: URL) -> Bool {
        UTType(filenameExtension: url.pathExtension)?.conforms(to: .image) ?? false
    }

    func edit(_ url: URL) {
        guard let service = NSSharingService(named: Self.service), service.canPerform(withItems: [url]) else {
            NSWorkspace.shared.open(url)   // no Markup on this Mac: Preview is the next best thing
            return
        }
        editing = url
        service.delegate = self
        let mouse = NSEvent.mouseLocation
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) ?? NSScreen.main {
            let area = screen.visibleFrame
            anchor.setFrame(area.insetBy(dx: area.width * 0.1, dy: area.height * 0.1), display: false)
        }
        anchor.orderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        service.perform(withItems: [url])
        tidyEditor()
    }

    // MARK: NSSharingServiceDelegate

    func sharingService(_ s: NSSharingService, sourceFrameOnScreenForShareItem item: Any) -> NSRect { anchor.frame }

    func sharingService(_ s: NSSharingService, sourceWindowForShareItems items: [Any],
                        sharingContentScope: UnsafeMutablePointer<NSSharingService.SharingContentScope>) -> NSWindow? {
        anchor
    }

    /// Done: the edited image comes back as a URL, an image or an item provider.
    func sharingService(_ s: NSSharingService, didShareItems items: [Any]) {
        guard let target = editing, let item = items.first else { return }
        editing = nil
        switch item {
        case let url as URL:
            if url.standardizedFileURL != target.standardizedFileURL {
                save((try? Data(contentsOf: url)), over: target)
            }
        case let image as NSImage:
            save(image.tiffRepresentation, over: target)
        case let provider as NSItemProvider:
            load(provider, over: target)
        default:
            NSSound.beep()
        }
    }

    /// Cancel, or the editor failed.
    func sharingService(_ s: NSSharingService, didFailToShareItems items: [Any], error: Error) {
        editing = nil
    }

    // MARK: Tidying the editor

    /// Opened this way, Markup comes as three windows of ours: the editor
    /// (`SHKRemoteWindow`), a blurred backdrop (`SHKBlurWindow`) sized for the
    /// whole anchor, which shows as a grey band right of the editor, and a
    /// dimming shadow (`SHKDimAndShadowWindow`) around that backdrop, which
    /// doubles the editor's own shadow. Seen on macOS 26. While the editor is
    /// open: centre it once, keep the backdrop to the editor's frame, and hide
    /// the extra shadow. Found by class name, so if a later macOS renames them
    /// this does nothing and Markup looks as it does untouched. The editor is
    /// left where it is after that: moving it (tried by dragging its top bar)
    /// lagged and left Cancel and Done not responding.
    private var tidying: Timer?

    private func tidyEditor() {
        tidying?.invalidate()
        let start = Date()
        var seen = false, centred = false
        let timer = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            let windows = NSApp.windows.filter(\.isVisible)
            guard let editor = windows.first(where: { $0.className.contains("RemoteWindow") }) else {
                // Closed (or never showed up): drop the anchor and stop.
                if seen || Date().timeIntervalSince(start) > 10 {
                    self.anchor.orderOut(nil)
                    timer.invalidate()
                    self.tidying = nil
                }
                return
            }
            seen = true
            if !centred, let area = editor.screen?.visibleFrame {
                centred = true
                editor.hasShadow = true
                editor.setFrameOrigin(NSPoint(x: (area.midX - editor.frame.width / 2).rounded(),
                                              y: (area.midY - editor.frame.height / 2).rounded()))
            }
            for w in windows where w !== editor {
                if w.className.contains("BlurWindow"), w.frame != editor.frame {
                    w.setFrame(editor.frame, display: true)
                } else if w.className.contains("DimAndShadowWindow"), w.alphaValue > 0 {
                    w.alphaValue = 0
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        tidying = timer
    }

    private func load(_ provider: NSItemProvider, over target: URL) {
        let types = provider.registeredTypeIdentifiers
        if types.contains(UTType.fileURL.identifier) {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                let data = url.flatMap { try? Data(contentsOf: $0) }
                DispatchQueue.main.async { self.save(data, over: target) }
            }
            return
        }
        let own = UTType(filenameExtension: target.pathExtension)?.identifier
        guard let type = types.first(where: { $0 == own })
                ?? types.first(where: { UTType($0)?.conforms(to: .image) == true }) else { return }
        provider.loadDataRepresentation(forTypeIdentifier: type) { data, _ in
            DispatchQueue.main.async { self.save(data, over: target) }
        }
    }

    // MARK: Writing back

    /// Markup returns a loosely compressed PNG (often twice the size, and PNG
    /// even for a JPEG or HEIC), so it is encoded again in the file's own
    /// format. The file is swapped in place, keeping its creation date (its
    /// spot in the grid) and the screenshot metadata macOS attached to it.
    private func save(_ data: Data?, over target: URL) {
        guard let data else { NSSound.beep(); return }
        let fm = FileManager.default
        let created = (try? target.resourceValues(forKeys: [.creationDateKey]))?.creationDate
        do {
            let dir = try fm.url(for: .itemReplacementDirectory, in: .userDomainMask,
                                 appropriateFor: target, create: true)
            let temp = dir.appendingPathComponent(target.lastPathComponent)
            try Self.reencode(data, like: target).write(to: temp)
            _ = try fm.replaceItemAt(target, withItemAt: temp)
            try? fm.removeItem(at: dir)
            if let created { try? fm.setAttributes([.creationDate: created], ofItemAtPath: target.path) }
        } catch {
            NSSound.beep()
        }
    }

    private static func reencode(_ data: Data, like target: URL) -> Data {
        let type = (UTType(filenameExtension: target.pathExtension) ?? .png).identifier as CFString
        let out = NSMutableData()
        guard let src = CGImageSourceCreateWithData(data as CFData, nil),
              let dest = CGImageDestinationCreateWithData(out, type, 1, nil) else { return data }
        CGImageDestinationAddImageFromSource(dest, src, 0, nil)
        return CGImageDestinationFinalize(dest) ? out as Data : data
    }
}



