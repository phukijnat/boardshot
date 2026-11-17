import AppKit

/// Boardshot's own "floating thumbnail": after a screenshot, a small preview
/// slides in at the bottom-right of the screen the mouse is on. The file is
/// already saved, so it can be dragged out, clicked to open Boardshot, or
/// closed at any moment without losing anything.
final class CornerThumb: NSObject, NSDraggingSource {
    var onClick: ((URL) -> Void)?

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

    override func mouseDown(with event: NSEvent) {
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
        if !dragged { owner?.clicked() }
        downEvent = nil
    }

    /// Two-finger swipe to the right dismisses it, like the system thumbnail.
    override func scrollWheel(with event: NSEvent) {
        if event.phase == .began { scrollX = 0 }
        scrollX += event.scrollingDeltaX
        if scrollX < -40 || scrollX > 40 { scrollX = 0; owner?.swipedAway() }
    }
}
