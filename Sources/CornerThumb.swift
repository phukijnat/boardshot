import AppKit
import UniformTypeIdentifiers

/// Boardshot's own "floating thumbnail": after a screenshot, a small preview
/// slides in at the bottom-right of the screen the mouse is on. The file is
/// already saved, so it can be dragged out, clicked to edit (like the macOS
/// thumbnail), right-clicked for more, or
/// closed at any moment without losing anything.
final class CornerThumb: NSObject, NSDraggingSource {
    var onClick: ((URL) -> Void)?
    /// Opens the Boardshot window on this shot (right-click menu).
    var onShowInBoardshot: ((URL) -> Void)?
    /// Opens the shot in Markup (right-click menu).
    var onMarkup: ((URL) -> Void)?
    /// Moves the shot to the Trash (right-click menu).
    var onTrash: ((URL) -> Void)?

    private let window: NSPanel
    private let view = CornerThumbView()
    private var url: URL?
    private var timer: Timer?
    private let visibleFor: TimeInterval = 5
    private let margin: CGFloat = 20

    override init() {
        window = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                         backing: .buffered, defer: true)
        super.init()
        window.level = .statusBar
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.contentView = view
        view.owner = self
    }

    var isVisible: Bool { window.isVisible }

    func show(url: URL, image: NSImage) {
        guard image.size.width > 0, image.size.height > 0 else { return }
        self.url = url
        view.imageView.image = image

        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        guard let vf = screen?.visibleFrame else { return }

        let maxW: CGFloat = 220, maxH: CGFloat = 150
        let s = min(maxW / image.size.width, maxH / image.size.height)
        let size = NSSize(width: max(80, image.size.width * s), height: max(50, image.size.height * s))
        let final = NSRect(x: vf.maxX - size.width - margin, y: vf.minY + margin,
                           width: size.width, height: size.height)

        // Place it directly in the corner and fade in. (Animating the frame from
        // off-screen didn't run, leaving it stuck past the edge or on the
        // neighbouring display.)
        window.setFrame(final, display: true)
        window.alphaValue = 0
        window.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.18
            window.animator().alphaValue = 1
        }
        restartTimer(visibleFor)
    }

    /// Closes at once (used when the Boardshot window opens).
    func hide() {
        timer?.invalidate()
        timer = nil
        window.orderOut(nil)
        url = nil
    }

    private func slideOut() {
        timer?.invalidate()
        guard window.isVisible else { hide(); return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.2
            window.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            guard let self, self.window.alphaValue == 0 else { return } // re-shown meanwhile
            self.hide()
        })
    }

    private func restartTimer(_ t: TimeInterval) {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: t, repeats: false) { [weak self] _ in
            self?.slideOut()
        }
    }

    // MARK: Events from the view

    fileprivate func hovered(_ inside: Bool) {
        if inside { timer?.invalidate() } else { restartTimer(2) }
    }

    fileprivate func clicked() {
        guard let url else { return }
        hide()
        onClick?(url)
    }

    fileprivate func swipedAway() { slideOut() }

    // MARK: Right-click menu (the same choices as the macOS thumbnail's)

    fileprivate func showMenu(with event: NSEvent) {
        guard let url else { return }
        timer?.invalidate()
        let menu = NSMenu()
        menu.autoenablesItems = false
        func add(_ title: String, _ enabled: Bool = true, _ action: @escaping () -> Void) {
            let item = NSMenuItem(title: title, action: #selector(MenuAction.run), keyEquivalent: "")
            let box = MenuAction(action)
            item.target = box
            item.representedObject = box   // the menu item keeps its target alive
            item.isEnabled = enabled
            menu.addItem(item)
        }
        let isMovie = UTType(filenameExtension: url.pathExtension)?.conforms(to: .movie) ?? false

        add(tr("บันทึกไปที่ Desktop", "Save to Desktop")) { [weak self] in self?.saveCopy(url, to: .desktopDirectory) }
        add(tr("บันทึกไปที่ Documents", "Save to Documents")) { [weak self] in self?.saveCopy(url, to: .documentDirectory) }
        add(tr("บันทึกไปที่ Clipboard", "Save to Clipboard")) { [weak self] in self?.copyToClipboard(url) }
        menu.addItem(.separator())

        for (name, title) in [(NSSharingService.Name.composeEmail, "Mail"), (.composeMessage, "Messages")] {
            let service = NSSharingService(named: name)
            add(tr("เปิดใน \(title)", "Open in \(title)"), service?.canPerform(withItems: [url]) ?? false) { [weak self] in
                service?.perform(withItems: [url])
                self?.hide()
            }
        }
        let apps = isMovie ? [("com.apple.QuickTimePlayerX", "QuickTime Player"), ("com.apple.Photos", "Photos")]
                           : [("com.apple.Preview", "Preview"), ("com.apple.Photos", "Photos")]
        for (id, title) in apps {
            guard let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) else { continue }
            add(tr("เปิดใน \(title)", "Open in \(title)")) { [weak self] in
                NSWorkspace.shared.open([url], withApplicationAt: app, configuration: NSWorkspace.OpenConfiguration())
                self?.hide()
            }
        }
        menu.addItem(.separator())

        if Markup.canEdit(url) {
            add("Markup") { [weak self] in
                self?.hide()
                self?.onMarkup?(url)
            }
        }
        add(tr("แสดงใน Finder", "Show in Finder")) { [weak self] in
            NSWorkspace.shared.activateFileViewerSelecting([url])
            self?.hide()
        }
        add(tr("แสดงใน \(AppInfo.name)", "Show in \(AppInfo.name)")) { [weak self] in
            self?.hide()
            self?.onShowInBoardshot?(url)
        }
        add(tr("ลบ", "Delete")) { [weak self] in
            self?.hide()
            self?.onTrash?(url)
        }
        add(tr("ปิด", "Close")) { [weak self] in self?.slideOut() }

        NSMenu.popUpContextMenu(menu, with: event, for: view)
        // Nothing chosen (or the action ran without closing it): carry on as after a hover.
        if window.isVisible, window.alphaValue > 0 { restartTimer(2) }
    }

    /// Copies the file (Boardshot keeps its own), adding " 2", " 3"… if the name is taken.
    private func saveCopy(_ url: URL, to dir: FileManager.SearchPathDirectory) {
        hide()
        let fm = FileManager.default
        guard let folder = fm.urls(for: dir, in: .userDomainMask).first else { return }
        let base = url.deletingPathExtension().lastPathComponent, ext = url.pathExtension
        var dest = folder.appendingPathComponent(url.lastPathComponent)
        var n = 2
        while fm.fileExists(atPath: dest.path) {
            dest = folder.appendingPathComponent("\(base) \(n)").appendingPathExtension(ext)
            n += 1
        }
        do { try fm.copyItem(at: url, to: dest) } catch { NSSound.beep() }
    }

    private func copyToClipboard(_ url: URL) {
        hide()
        let pb = NSPasteboard.general
        pb.clearContents()
        var objects: [NSPasteboardWriting] = [url as NSURL]
        if let img = NSImage(contentsOf: url) { objects.insert(img, at: 0) }
        pb.writeObjects(objects)
    }

    fileprivate func beginDrag(with event: NSEvent) {
        guard let url else { return }
        timer?.invalidate()
        let item = NSDraggingItem(pasteboardWriter: url as NSURL)
        item.setDraggingFrame(view.bounds, contents: view.imageView.image)
        let session = view.beginDraggingSession(with: [item], event: event, source: self)
        session.animatesToStartingPositionsOnCancelOrFail = false
        DispatchQueue.main.async { self.window.alphaValue = 0 }
    }

    // MARK: NSDraggingSource

    func draggingSession(_ session: NSDraggingSession,
                         sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation { .copy }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint,
                         operation: NSDragOperation) {
        hide()
        window.alphaValue = 1
    }
}

/// Runs a closure from a menu item.
private final class MenuAction: NSObject {
    private let action: () -> Void
    init(_ action: @escaping () -> Void) { self.action = action }
    @objc func run() { action() }
}

private final class CornerThumbView: NSView {
    weak var owner: CornerThumb?
    let imageView = NSImageView()
    private var downEvent: NSEvent?
    private var dragged = false
    private var scrollX: CGFloat = 0

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.cornerRadius = 10
        layer?.masksToBounds = true
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.white.withAlphaComponent(0.25).cgColor
        imageView.imageScaling = .scaleProportionallyUpOrDown
        // Plain autoresizing, not Auto Layout: with constraints the image's own
        // size grew the window past the corner (and off the screen).
        imageView.frame = bounds
        imageView.autoresizingMask = [.width, .height]
        addSubview(imageView)
        addTrackingArea(NSTrackingArea(rect: .zero,
                                       options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                       owner: self, userInfo: nil))
    }
    required init?(coder: NSCoder) { fatalError() }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseEntered(with event: NSEvent) { owner?.hovered(true) }
    override func mouseExited(with event: NSEvent) { owner?.hovered(false) }

    override func rightMouseDown(with event: NSEvent) { owner?.showMenu(with: event) }

    override func mouseDown(with event: NSEvent) {
        if event.modifierFlags.contains(.control) { owner?.showMenu(with: event); return }
        downEvent = event
        dragged = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard !dragged, let down = downEvent else { return }
        let dx = event.locationInWindow.x - down.locationInWindow.x
        let dy = event.locationInWindow.y - down.locationInWindow.y
        if hypot(dx, dy) > 4 {
            dragged = true
            owner?.beginDrag(with: down)
        }
    }

    override func mouseUp(with event: NSEvent) {
        if !dragged, downEvent != nil { owner?.clicked() }
        downEvent = nil
    }

    /// Two-finger swipe to the right dismisses it, like the system thumbnail.
    override func scrollWheel(with event: NSEvent) {
        if event.phase == .began { scrollX = 0 }
        scrollX += event.scrollingDeltaX
        if scrollX < -40 || scrollX > 40 { scrollX = 0; owner?.swipedAway() }
    }
}
