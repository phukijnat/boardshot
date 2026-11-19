import AppKit
import AVFoundation
import UniformTypeIdentifiers

// MARK: - Window

/// Borderless floating panel that can take keyboard focus.
final class ClipPanel: NSPanel {
    var onCancel: (() -> Void)?
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    override func cancelOperation(_ sender: Any?) { onCancel?() }
}

/// Header bar that moves the window when dragged.
final class DragHeader: NSStackView {
    override func mouseDown(with event: NSEvent) { window?.performDrag(with: event) }
}

// MARK: - Grid item

final class ThumbView: NSView {
    let imageView = NSImageView()
    var onHover: ((Bool) -> Void)?
    var onMouseDown: (() -> Void)?
    var isSelected = false { didSet { updateLook() } }
    private var tracking: NSTrackingArea?

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.masksToBounds = true
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            imageView.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
        ])
        updateLook()
    }
    required init?(coder: NSCoder) { fatalError() }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let t = NSTrackingArea(rect: bounds,
                               options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                               owner: self, userInfo: nil)
        addTrackingArea(t)
        tracking = t
    }
    override func mouseEntered(with event: NSEvent) { onHover?(true) }
    override func mouseExited(with event: NSEvent) { onHover?(false) }
    override func mouseDown(with event: NSEvent) {
        onMouseDown?()
        super.mouseDown(with: event) // let the collection view handle select / drag
    }

    override func viewDidChangeEffectiveAppearance() { updateLook() }

    private func updateLook() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.backgroundColor = NSColor.quaternaryLabelColor.withAlphaComponent(0.25).cgColor
            layer?.borderWidth = isSelected ? 3 : 0
            layer?.borderColor = NSColor.controlAccentColor.cgColor
        }
    }
}

final class ThumbItem: NSCollectionViewItem {
    static let id = NSUserInterfaceItemIdentifier("ThumbItem")
    var thumb: ThumbView { view as! ThumbView }
    var url: URL?

    override func loadView() { view = ThumbView(frame: .zero) }
    override var isSelected: Bool { didSet { updateHighlight() } }
    // During box selection, AppKit sets highlightState live and only commits
    // isSelected on mouse up, so show the border from highlightState too.
    override var highlightState: NSCollectionViewItem.HighlightState { didSet { updateHighlight() } }

    private func updateHighlight() {
        switch highlightState {
        case .forSelection: thumb.isSelected = true
        case .forDeselection: thumb.isSelected = false
        default: thumb.isSelected = isSelected
        }
    }
    override func prepareForReuse() {
        super.prepareForReuse()
        thumb.imageView.image = nil
        thumb.onHover = nil
        thumb.onMouseDown = nil
        url = nil
    }
}

/// Collection view with keyboard shortcuts.
final class GridView: NSCollectionView {
    var onDelete: (() -> Void)?
    var onOpen: (() -> Void)?
    var onCopy: (() -> Void)?
    var onShowSettings: (() -> Void)?
    var onQuit: (() -> Void)?

    // No main menu in a menu-bar app, so handle ⌘A / ⌘C / ⌘, / ⌘Q here.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard event.type == .keyDown,
              event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command else {
            return super.performKeyEquivalent(with: event)
        }
        switch event.keyCode {
        case 0: selectAll(nil); return true     // A
        case 8: onCopy?(); return true          // C
        case 43: onShowSettings?(); return true // ,
        case 12: onQuit?(); return true         // Q
        default: return super.performKeyEquivalent(with: event)
        }
    }

    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        if event.clickCount == 2 { onOpen?() }
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 51, 117: onDelete?()            // delete / forward delete
        case 36, 76: onOpen?()               // return / enter
        default:
            if event.modifierFlags.contains(.command),
               event.charactersIgnoringModifiers == "c" { onCopy?(); return }
            super.keyDown(with: event)
        }
    }
}

// MARK: - Controller

final class PanelController: NSObject, NSCollectionViewDataSource, NSCollectionViewDelegate {
    private let store: ShotStore
    private let panel: ClipPanel
    private let grid = GridView()
    private let countLabel = NSTextField(labelWithString: "")
    private let emptyLabel = NSTextField(labelWithString: "")
    private let enableBtn = NSButton(title: "", target: nil, action: nil)
    private var emptyBox: NSStackView!
    private let hintLabel = NSTextField(labelWithString: "")
    private var folderBtn: NSButton!
    private var settingsBtn: NSButton!
    private var clearBtn: NSButton!
    private var header: NSView!
    private let confirmBar = NSStackView()
    private let confirmLabel = NSTextField(labelWithString: "")
    private let confirmNo = NSButton(title: "", target: nil, action: nil)
    private let confirmYes = NSButton(title: "", target: nil, action: nil)
    var onShowSettings: (() -> Void)?
    var onQuit: (() -> Void)?
    /// Turns "Keep screenshots in Boardshot" on, from the empty panel.
    var onEnableManage: (() -> Void)?
    private let preview = PreviewWindow()
    private var hoverTimer: Timer?
    private var dragging = false

    private let thumbSize = NSSize(width: 176, height: 118)

    init(store: ShotStore) {
        self.store = store
        panel = ClipPanel(contentRect: NSRect(x: 0, y: 0, width: 790, height: 540),
                          styleMask: [.borderless, .nonactivatingPanel, .resizable],
                          backing: .buffered, defer: false)
        super.init()
        buildUI()
        store.onChange = { [weak self] in self?.reload() }
        NotificationCenter.default.addObserver(self, selector: #selector(refreshTexts),
                                               name: .prefsChanged, object: nil)
        reload()
    }

    var isVisible: Bool { panel.isVisible && panel.alphaValue > 0 }

    func toggle() { isVisible ? hide() : show() }

    var onWillShow: (() -> Void)?

    func show(selecting url: URL? = nil) {
        onWillShow?()
        store.reload()
        if let url, let i = store.shots.firstIndex(where: { $0.url == url }) {
            grid.selectionIndexPaths = [IndexPath(item: i, section: 0)]
        }
        positionOnActiveScreen()
        panel.alphaValue = 1
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(grid)
        // Only touch item 0 when it exists: scrolling to a missing item crashes AppKit.
        if grid.numberOfSections > 0, grid.numberOfItems(inSection: 0) > 0 {
            let first = IndexPath(item: 0, section: 0)
            if grid.selectionIndexPaths.isEmpty { grid.selectionIndexPaths = [first] }
            grid.scrollToItems(at: [first], scrollPosition: .top)
        }
    }

    func hide() {
        cancelHover()
        if isConfirmingWipe { cancelWipe() }
        panel.orderOut(nil)
        grid.deselectAll(nil)
    }

    // MARK: UI

    private func buildUI() {
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        // Window moves only by its header, so dragging empty grid space
        // draws a selection box instead of moving the window.
        panel.isMovableByWindowBackground = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        panel.minSize = NSSize(width: 420, height: 300)
        panel.onCancel = { [weak self] in
            guard let self else { return }
            if self.isConfirmingWipe { self.cancelWipe() } else { self.hide() } // Esc
        }
        NotificationCenter.default.addObserver(self, selector: #selector(resigned),
                                               name: NSWindow.didResignKeyNotification, object: panel)

        let bg = NSVisualEffectView()
        bg.material = .hudWindow
        bg.blendingMode = .behindWindow
        bg.state = .active
        bg.wantsLayer = true
        bg.layer?.cornerRadius = 14
        bg.layer?.masksToBounds = true
        panel.contentView = bg

        let title = NSTextField(labelWithString: AppInfo.name)
        title.font = .systemFont(ofSize: 15, weight: .semibold)
        countLabel.textColor = .secondaryLabelColor
        countLabel.font = .systemFont(ofSize: 12)
        let hint = hintLabel
        hint.textColor = .tertiaryLabelColor
        hint.font = .systemFont(ofSize: 11)
        hint.lineBreakMode = .byTruncatingTail
        hint.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        folderBtn = NSButton(image: NSImage(systemSymbolName: "folder", accessibilityDescription: "Folder")!,
                             target: self, action: #selector(openFolder))
        folderBtn.isBordered = false
        settingsBtn = NSButton(image: NSImage(systemSymbolName: "gearshape", accessibilityDescription: "Settings")!,
                               target: self, action: #selector(menuShowPrefs))
        settingsBtn.isBordered = false
        clearBtn = NSButton(image: NSImage(systemSymbolName: "trash", accessibilityDescription: "Clear all")!,
                            target: self, action: #selector(wipeAllShots))
        clearBtn.isBordered = false

        let header = DragHeader(views: [title, countLabel, NSView(), hint, clearBtn, folderBtn, settingsBtn])
        header.orientation = .horizontal
        header.spacing = 8
        header.edgeInsets = NSEdgeInsets(top: 0, left: 16, bottom: 0, right: 12)

        let layout = NSCollectionViewFlowLayout()
        layout.itemSize = thumbSize
        layout.minimumInteritemSpacing = 10
        layout.minimumLineSpacing = 10
        layout.sectionInset = NSEdgeInsets(top: 4, left: 14, bottom: 14, right: 14)
        grid.collectionViewLayout = layout
        grid.isSelectable = true
        grid.allowsMultipleSelection = true
        grid.backgroundColors = [.clear]
        grid.dataSource = self
        grid.delegate = self
        grid.register(ThumbItem.self, forItemWithIdentifier: ThumbItem.id)
        grid.setDraggingSourceOperationMask(.copy, forLocal: false)
        grid.setDraggingSourceOperationMask(.copy, forLocal: true)
        grid.onDelete = { [weak self] in self?.trashSelected() }
        grid.onOpen = { [weak self] in self?.openSelected() }
        grid.onCopy = { [weak self] in self?.copySelected() }
        grid.onShowSettings = { [weak self] in self?.menuShowPrefs() }
        grid.onQuit = { [weak self] in self?.menuQuit() }

        let scroll = NSScrollView()
        scroll.documentView = grid
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true

        emptyLabel.alignment = .center
        emptyLabel.textColor = .secondaryLabelColor
        emptyLabel.font = .systemFont(ofSize: 14)
        // Shown when screenshots still go elsewhere, so Boardshot can't see them.
        enableBtn.target = self
        enableBtn.action = #selector(enableManage)
        enableBtn.bezelStyle = .rounded
        enableBtn.controlSize = .large
        emptyBox = NSStackView(views: [emptyLabel, enableBtn])
        emptyBox.orientation = .vertical
        emptyBox.spacing = 12

        // Text-only "delete all?" bar that takes the header's place.
        confirmLabel.font = .systemFont(ofSize: 13, weight: .medium)
        confirmLabel.lineBreakMode = .byTruncatingTail
        confirmLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        confirmNo.target = self
        confirmNo.action = #selector(cancelWipe)
        confirmNo.bezelStyle = .rounded
        confirmNo.keyEquivalent = "\u{1b}"
        confirmYes.target = self
        confirmYes.action = #selector(confirmWipe)
        confirmYes.bezelStyle = .rounded
        confirmYes.hasDestructiveAction = true
        confirmYes.bezelColor = .systemRed
        confirmYes.keyEquivalent = "\r"
        confirmBar.setViews([confirmLabel, NSView(), confirmNo, confirmYes], in: .leading)
        confirmBar.orientation = .horizontal
        confirmBar.spacing = 8
        confirmBar.edgeInsets = NSEdgeInsets(top: 0, left: 16, bottom: 0, right: 12)
        confirmBar.isHidden = true
        self.header = header

        for v in [header, confirmBar, scroll, emptyBox] as [NSView] {
            v.translatesAutoresizingMaskIntoConstraints = false
            bg.addSubview(v)
        }
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: bg.topAnchor),
            header.leadingAnchor.constraint(equalTo: bg.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: bg.trailingAnchor),
            header.heightAnchor.constraint(equalToConstant: 44),
            confirmBar.topAnchor.constraint(equalTo: header.topAnchor),
            confirmBar.leadingAnchor.constraint(equalTo: header.leadingAnchor),
            confirmBar.trailingAnchor.constraint(equalTo: header.trailingAnchor),
            confirmBar.bottomAnchor.constraint(equalTo: header.bottomAnchor),
            scroll.topAnchor.constraint(equalTo: header.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: bg.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: bg.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: bg.bottomAnchor),
            emptyBox.centerXAnchor.constraint(equalTo: scroll.centerXAnchor),
            emptyBox.centerYAnchor.constraint(equalTo: scroll.centerYAnchor),
        ])
    }

    private func positionOnActiveScreen() {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        guard let vf = screen?.visibleFrame else { return }
        var f = panel.frame
        f.origin.x = vf.midX - f.width / 2
        f.origin.y = vf.midY - f.height / 2 + vf.height * 0.08
        panel.setFrame(f, display: false)
    }

    private func reload() {
        let selected = Set(selectedURLs())
        grid.reloadData()
        let keep = store.shots.enumerated()
            .filter { selected.contains($0.element.url) }
            .map { IndexPath(item: $0.offset, section: 0) }
        grid.selectionIndexPaths = Set(keep)
        refreshTexts()
        emptyBox.isHidden = !store.shots.isEmpty
    }

    @objc private func enableManage() { onEnableManage?() }

    @objc private func refreshTexts() {
        let n = store.shots.count
        countLabel.stringValue = tr("\(n) รูป", n == 1 ? "1 shot" : "\(n) shots")
        hintLabel.stringValue = tr("ลากออกเพื่อใช้ · ⌘/⇧ คลิกเลือกหลายรูป · ⌫ ลบ · Esc ปิด",
                                   "Drag out to use · ⌘/⇧-click to pick several · ⌫ delete · Esc close")
        if Prefs.manageScreenshots {
            emptyLabel.stringValue = tr("ยังไม่มีภาพ\nกด ⇧⌘4 เพื่อถ่ายหน้าจอ",
                                        "No screenshots yet\nPress ⇧⌘4 to take one")
        } else {
            emptyLabel.stringValue = tr("\(AppInfo.name) ยังไม่ได้เก็บภาพ\nscreenshot ใหม่ยังไปที่เดิม จึงไม่ขึ้นที่นี่",
                                        "\(AppInfo.name) isn't keeping screenshots yet\nNew ones still go to their old folder, so they don't show here")
        }
        enableBtn.title = tr("ให้ \(AppInfo.name) เก็บภาพ", "Keep Screenshots in \(AppInfo.name)")
        enableBtn.isHidden = Prefs.manageScreenshots
        folderBtn.toolTip = tr("เปิดโฟลเดอร์ใน Finder", "Show folder in Finder")
        settingsBtn.toolTip = tr("ตั้งค่า (⌘,)", "Settings (⌘,)")
        clearBtn.toolTip = tr("ลบรูปทั้งหมด", "Delete all screenshots")
        clearBtn.isEnabled = !store.shots.isEmpty
    }

    /// Asks once, in a text-only bar in place of the header (no alert box,
    /// so no app icon), then moves every screenshot to the Trash.
    @objc private func wipeAllShots() {
        let n = store.shots.count
        guard n > 0 else { return }
        cancelHover()
        confirmLabel.stringValue = tr("ลบรูปทั้งหมด \(n) รูป? (ย้ายไปถังขยะ กู้คืนได้)",
                                      "Delete all \(n) screenshots? (moved to the Trash)")
        confirmNo.title = tr("ยกเลิก", "Cancel")
        confirmYes.title = tr("ลบทั้งหมด", "Delete All")
        header.isHidden = true
        confirmBar.isHidden = false
    }

    private var isConfirmingWipe: Bool { !confirmBar.isHidden }

    @objc private func cancelWipe() {
        confirmBar.isHidden = true
        header.isHidden = false
        panel.makeFirstResponder(grid)
    }

    @objc private func confirmWipe() {
        let urls = store.shots.map(\.url)
        cancelWipe()
        grid.deselectAll(nil)
        store.trash(urls)
    }

    @objc private func menuShowPrefs() { hide(); onShowSettings?() }
    @objc private func menuQuit() { onQuit?() }

    @objc private func resigned() {
        if !dragging { hide() }
    }

    // MARK: Actions

    private func selectedURLs() -> [URL] {
        grid.selectionIndexPaths.sorted().compactMap {
            $0.item < store.shots.count ? store.shots[$0.item].url : nil
        }
    }

    @objc private func openFolder() {
        hide()
        NSWorkspace.shared.open(store.folder)
    }

    @objc private func openSelected() {
        let urls = selectedURLs()
        guard !urls.isEmpty else { return }
        hide()
        for u in urls { NSWorkspace.shared.open(u) }
    }

    private func trashSelected() {
        let urls = selectedURLs()
        guard !urls.isEmpty else { return }
        cancelHover()
        grid.deselectAll(nil)
        store.trash(urls)
    }

    private func copySelected() {
        let urls = selectedURLs()
        guard !urls.isEmpty else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        var objects: [NSPasteboardWriting] = urls.map { $0 as NSURL }
        if urls.count == 1, let img = NSImage(contentsOf: urls[0]) { objects.insert(img, at: 0) }
        pb.writeObjects(objects)
        hide()
    }

    // MARK: Hover preview

    private func hover(_ inside: Bool, item: ThumbItem) {
        cancelHover()
        guard inside, Prefs.showHoverPreview, !dragging, let url = item.url else { return }
        hoverTimer = Timer.scheduledTimer(withTimeInterval: 0.45, repeats: false) { [weak self, weak item] _ in
            guard let self, let item, item.url == url, let win = item.view.window else { return }
            let rectInWindow = item.view.convert(item.view.bounds, to: nil)
            let onScreen = win.convertToScreen(rectInWindow)
            self.preview.show(url: url, around: onScreen, parent: self.panel)
        }
    }

    private func cancelHover() {
        hoverTimer?.invalidate()
        hoverTimer = nil
        preview.hide()
    }

    // MARK: Data source

    func collectionView(_ cv: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        store.shots.count
    }

    func collectionView(_ cv: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let item = cv.makeItem(withIdentifier: ThumbItem.id, for: indexPath) as! ThumbItem
        let shot = store.shots[indexPath.item]
        item.url = shot.url
        item.thumb.toolTip = shot.url.lastPathComponent
        item.thumb.onHover = { [weak self, weak item] inside in
            guard let self, let item else { return }
            self.hover(inside, item: item)
        }
        item.thumb.onMouseDown = { [weak self] in self?.cancelHover() }
        store.thumbnail(for: shot.url, size: thumbSize) { [weak item] img in
            guard let item, item.url == shot.url else { return }
            item.thumb.imageView.image = img
        }
        return item
    }

    // MARK: Dragging (multi-select drag comes for free)

    func collectionView(_ cv: NSCollectionView, canDragItemsAt indexPaths: Set<IndexPath>, with event: NSEvent) -> Bool {
        true
    }

    func collectionView(_ cv: NSCollectionView, pasteboardWriterForItemAt indexPath: IndexPath) -> NSPasteboardWriting? {
        store.shots[indexPath.item].url as NSURL
    }

    func collectionView(_ cv: NSCollectionView, draggingSession session: NSDraggingSession,
                        willBeginAt screenPoint: NSPoint, forItemsAt indexPaths: Set<IndexPath>) {
        dragging = true
        cancelHover()
        session.animatesToStartingPositionsOnCancelOrFail = false
        // Fade the panel out so the drop target underneath is visible.
        // The drag itself keeps going; we fully close once it ends.
        DispatchQueue.main.async {
            self.panel.alphaValue = 0
            self.panel.ignoresMouseEvents = true
        }
    }

    func collectionView(_ cv: NSCollectionView, draggingSession session: NSDraggingSession,
                        endedAt screenPoint: NSPoint, dragOperation operation: NSDragOperation) {
        dragging = false
        panel.ignoresMouseEvents = false
        hide()
        panel.alphaValue = 1
    }
}

// MARK: - Hover preview window

final class PreviewWindow {
    private let window: NSPanel
    private let imageView = NSImageView()
    private let playerView = NSView()
    private let playerLayer = AVPlayerLayer()
    private var player: AVQueuePlayer?
    private var looper: AVPlayerLooper?
    private var currentURL: URL?

    init() {
        window = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                         backing: .buffered, defer: true)
        window.level = .popUpMenu
        window.ignoresMouseEvents = true
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]

        let box = NSView()
        box.wantsLayer = true
        box.layer?.cornerRadius = 10
        box.layer?.masksToBounds = true
        box.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        imageView.imageScaling = .scaleProportionallyUpOrDown
        // Autoresizing, so the image's own size can't resize the window.
        imageView.autoresizingMask = [.width, .height]
        box.addSubview(imageView)
        playerView.wantsLayer = true
        playerView.layer = playerLayer
        playerLayer.videoGravity = .resizeAspect
        playerView.autoresizingMask = [.width, .height]
        box.addSubview(playerView)
        window.contentView = box
    }

    /// Shows an enlarged image, or a muted looping video, centred on the
    /// hovered thumbnail and clamped to the screen.
    func show(url: URL, around rect: NSRect, parent: NSWindow) {
        currentURL = url
        if let type = UTType(filenameExtension: url.pathExtension), type.conforms(to: .movie) {
            showVideo(url: url, around: rect, parent: parent)
            return
        }
        let image = NSImage(contentsOf: url) ?? NSWorkspace.shared.icon(forFile: url.path)
        guard image.size.width > 0, image.size.height > 0 else { return }
        stopVideo()
        imageView.image = image
        imageView.isHidden = false
        present(contentSize: image.size, around: rect, parent: parent)
    }

    private func showVideo(url: URL, around rect: NSRect, parent: NSWindow) {
        let asset = AVURLAsset(url: url)
        Task { @MainActor [weak self] in
            // The track's size, turned the way it plays (a recording can be rotated).
            guard let track = try? await asset.loadTracks(withMediaType: .video).first,
                  let (natural, transform) = try? await track.load(.naturalSize, .preferredTransform),
                  let self, self.currentURL == url else { return }
            let size = natural.applying(transform)
            let content = NSSize(width: abs(size.width), height: abs(size.height))
            guard content.width > 0, content.height > 0 else { return }

            self.stopVideo()
            let player = AVQueuePlayer()
            player.isMuted = true
            self.looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(asset: asset))
            self.player = player
            self.playerLayer.player = player
            self.imageView.isHidden = true
            self.playerView.isHidden = false
            self.present(contentSize: content, around: rect, parent: parent)
            player.play()
        }
    }

    private func present(contentSize: NSSize, around rect: NSRect, parent: NSWindow) {
        let screen = parent.screen ?? NSScreen.main
        let vf = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)

        let maxSide = min(640, vf.width * 0.6, vf.height * 0.7)
        let s = min(maxSide / contentSize.width, maxSide / contentSize.height, 1.0 * 2)
        var size = NSSize(width: contentSize.width * s, height: contentSize.height * s)
        size.width = max(size.width, rect.width)
        size.height = max(size.height, rect.height)

        var origin = NSPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2)
        origin.x = min(max(origin.x, vf.minX + 8), vf.maxX - size.width - 8)
        origin.y = min(max(origin.y, vf.minY + 8), vf.maxY - size.height - 8)

        window.setFrame(NSRect(origin: origin, size: size), display: true)
        window.alphaValue = 0
        window.orderFront(nil)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.12
            window.animator().alphaValue = 1
        }
    }

    private func stopVideo() {
        player?.pause()
        looper?.disableLooping()
        looper = nil
        player = nil
        playerLayer.player = nil
        playerView.isHidden = true
    }

    func hide() {
        currentURL = nil
        stopVideo()
        window.orderOut(nil)
    }
}
