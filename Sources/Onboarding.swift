import AppKit
import ServiceManagement

/// First-launch window. Asks before changing any macOS setting, lets the user
/// pick the thumbnail, has them take one screenshot, and shows how to open
/// Boardshot again. Four steps in one window; closing it early changes nothing
/// that wasn't agreed to, and it comes back on the next launch.
final class OnboardingController: NSObject, NSWindowDelegate {
    enum Step: Int { case welcome, thumbnail, tryIt, done }

    // Hooks into the app. A preview (screenshots of each step for docs) sets none.
    var onKeep: (() -> Void)?           // "Keep screenshots in Boardshot" on, applied
    var onDecline: (() -> Void)?        // leave the screenshot folder where it is
    var onThumbChanged: (() -> Void)?   // Prefs.thumbStyle changed, apply it
    var onShowSettings: (() -> Void)?
    var onFinish: ((_ openPanel: Bool, _ autoUpdate: Bool) -> Void)?
    var shortcutWorks = true
    var autoUpdateOn = true

    private let preview: Bool
    private var window: NSWindow?
    private var step: Step = .welcome
    private var confirmingDecline = false
    private var declined = false
    private var captured: NSImage?
    private var loginOn: Bool
    private var loginNeedsApproval = false

    private let width: CGFloat = 600
    private let height: CGFloat = 500

    init(preview: Bool = false) {
        self.preview = preview
        // Ticked by default the first time; afterwards it shows the real state.
        loginOn = SMAppService.mainApp.status == .enabled || (Self.inApplications && !Prefs.onboardingDone)
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(rebuild),
                                               name: .prefsChanged, object: nil)
    }

    var isVisible: Bool { window?.isVisible == true }

    func show(at step: Step = .welcome) {
        self.step = step
        // A fresh run each time (Settings → Show Welcome Again reuses this window).
        confirmingDecline = false
        declined = false
        captured = nil
        loginNeedsApproval = false
        if window == nil {
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: width, height: height),
                             styleMask: [.titled, .closable, .fullSizeContentView],
                             backing: .buffered, defer: false)
            w.titlebarAppearsTransparent = true
            w.titleVisibility = .hidden
            w.isReleasedWhenClosed = false
            w.delegate = self
            window = w
        }
        rebuild()
        window?.center()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    /// For previews: show a later state without going through the steps.
    func previewState(confirming: Bool = false, declined: Bool = false, captured: NSImage? = nil,
                      needsApproval: Bool = false) {
        confirmingDecline = confirming
        self.declined = declined
        self.captured = captured
        loginNeedsApproval = needsApproval
        rebuild()
    }

    /// A new screenshot reached Boardshot's folder.
    func shotArrived(_ image: NSImage) {
        guard isVisible, step == .tryIt, captured == nil else { return }
        captured = image
        rebuild()
    }

    var windowNumber: Int { window?.windowNumber ?? 0 }

    // MARK: Layout

    @objc private func rebuild() {
        guard let window else { return }
        window.title = tr("ยินดีต้อนรับสู่ \(AppInfo.name)", "Welcome to \(AppInfo.name)")

        let root = NSView()
        let body: NSView
        let buttons: [NSButton]
        switch step {
        case .welcome where confirmingDecline: (body, buttons) = confirmStep()
        case .welcome: (body, buttons) = welcomeStep()
        case .thumbnail: (body, buttons) = thumbnailStep()
        case .tryIt: (body, buttons) = tryStep()
        case .done: (body, buttons) = doneStep()
        }

        let lang = NSSegmentedControl(labels: Lang.allCases.map(\.label), trackingMode: .selectOne,
                                      target: self, action: #selector(langChanged(_:)))
        lang.selectedSegment = Lang.allCases.firstIndex(of: Prefs.lang) ?? 0
        lang.controlSize = .small

        let dots = NSStackView(views: (0..<4).map { i in Dot(on: i == step.rawValue) })
        dots.spacing = 6

        let buttonRow = NSStackView(views: buttons)
        buttonRow.spacing = 10
        let footer = NSStackView(views: [dots, NSView(), buttonRow])
        footer.orientation = .horizontal

        for v in [lang, body, footer] as [NSView] {
            v.translatesAutoresizingMaskIntoConstraints = false
            root.addSubview(v)
        }
        NSLayoutConstraint.activate([
            lang.topAnchor.constraint(equalTo: root.topAnchor, constant: 10),
            lang.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -14),
            body.centerXAnchor.constraint(equalTo: root.centerXAnchor),
            body.centerYAnchor.constraint(equalTo: root.centerYAnchor, constant: -22),
            body.widthAnchor.constraint(equalToConstant: width - 80),
            body.topAnchor.constraint(greaterThanOrEqualTo: lang.bottomAnchor, constant: 8),
            body.bottomAnchor.constraint(lessThanOrEqualTo: footer.topAnchor, constant: -16),
            footer.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 24),
            footer.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -20),
            footer.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -20),
        ])
        window.contentView = root
        window.setContentSize(NSSize(width: width, height: height))
        // Return presses the primary button of this step ("Skip" is not one).
        let skipping = step == .tryIt && captured == nil
        window.defaultButtonCell = skipping ? nil : buttons.last?.cell as? NSButtonCell
    }

    private func welcomeStep() -> (NSView, [NSButton]) {
        let icon = NSImageView(image: NSApp.applicationIconImage ?? NSImage())
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.widthAnchor.constraint(equalToConstant: 76).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 76).isActive = true

        let box = Box(views: [
            heading(tr("ให้ \(AppInfo.name) เก็บ screenshot ไหม?", "Let \(AppInfo.name) keep your screenshots?"), size: 14),
            text(tr("\(AppInfo.name) แสดงได้เฉพาะภาพในโฟลเดอร์ของมัน (~/Pictures/\(AppInfo.name)) จึงต้องเปลี่ยนที่เก็บ screenshot ของ Mac มาไว้ที่นี่ และปิดรูปเล็กของ Mac เพื่อให้ภาพเข้าทันที เปลี่ยนกลับได้ตลอดในหน้าตั้งค่า แล้วค่าเดิมจะกลับมา",
                    "\(AppInfo.name) can only show screenshots in its own folder (~/Pictures/\(AppInfo.name)), so it saves your Mac's screenshots there, and turns off the Mac's thumbnail so they land at once. You can switch back any time in Settings, and your old settings return."),
                 width: width - 120),
        ])
        let body = column([
            icon,
            heading(tr("ยินดีต้อนรับสู่ \(AppInfo.name)", "Welcome to \(AppInfo.name)"), size: 24),
            text(tr("เก็บ screenshot ทุกภาพไว้ในหน้าต่างเดียว เรียกดู ลากไปใช้ หรือลบทิ้งได้ด้วยคีย์บอร์ด",
                    "Every screenshot in one window. Bring it up, drag one out, or clear them away from the keyboard."),
                 width: width - 120, center: true),
            box,
        ], spacing: 14, gap: (after: 2, size: 20))

        let later = button(tr("ใช้ที่เดิมไว้ก่อน", "Keep My Current Folder"), #selector(askDecline))
        let keep = button(tr("ใช้ \(AppInfo.name) เก็บภาพ", "Keep Screenshots in \(AppInfo.name)"), #selector(keep))
        return (body, [later, keep])
    }

    private func confirmStep() -> (NSView, [NSButton]) {
        let icon = symbol("exclamationmark.triangle.fill", size: 40, color: .systemOrange)
        let body = column([
            icon,
            heading(tr("ใช้ที่เดิมใช่ไหม?", "Keep your current folder?"), size: 22),
            text(tr("ถ้าใช้ที่เดิม \(AppInfo.name) จะมองไม่เห็นภาพใหม่ และหน้าต่าง \(AppInfo.name) จะว่างตลอด จนกว่าจะเปิดใช้ในหน้าตั้งค่า",
                    "Then \(AppInfo.name) can't see new screenshots, and its window stays empty until you turn this on in Settings."),
                 width: width - 140, center: true),
        ], spacing: 14)
        let stay = button(tr("ใช้ที่เดิมต่อ", "Keep Current Folder"), #selector(decline))
        let keep = button(tr("ให้ \(AppInfo.name) เก็บภาพ", "Keep Screenshots in \(AppInfo.name)"), #selector(keep))
        return (body, [stay, keep])
    }

    private func thumbnailStep() -> (NSView, [NSButton]) {
        let current = Prefs.thumbStyle
        let ours = Card(style: .boardshot, symbol: "rectangle.inset.bottomright.filled",
                        badge: tr("แนะนำ", "Recommended"), selected: current == .boardshot) { [weak self] in
            self?.pick(.boardshot)
        }
        let mac = Card(style: .macOS, symbol: "pencil.tip.crop.circle",
                       badge: nil, selected: current == .macOS) { [weak self] in self?.pick(.macOS) }
        let cards = NSStackView(views: [ours, mac])
        cards.spacing = 14
        cards.distribution = .fillEqually
        cards.alignment = .top
        cards.widthAnchor.constraint(equalToConstant: width - 80).isActive = true

        let noneTitle = current == .none
            ? tr("✓ ไม่แสดงรูปเล็ก", "✓ No thumbnail")
            : tr("ไม่แสดงรูปเล็กเลย", "No thumbnail at all")
        let none = LinkButton(title: noneTitle, target: self, action: #selector(pickNone))

        let body = column([
            heading(tr("เลือกรูปเล็กหลังแคป", "Choose the thumbnail after a capture"), size: 22),
            text(tr("รูปเล็กที่เด้งขึ้นที่มุมจอหลังกด ⇧⌘4", "The small preview that pops up in the corner after ⇧⌘4."),
                 width: width - 120, center: true),
            cards,
            none,
            note(tr("เปลี่ยนได้ทีหลังในหน้าตั้งค่า", "You can change this later in Settings.")),
        ], spacing: 12, gap: (after: 1, size: 18))
        let back = button(tr("ย้อนกลับ", "Back"), #selector(goBack))
        let next = button(tr("ถัดไป", "Next"), #selector(goNext))
        return (body, [back, next])
    }

    private func tryStep() -> (NSView, [NSButton]) {
        let keys = NSStackView(views: ["⇧", "⌘", "4"].map { KeyCap($0, size: 30) })
        keys.spacing = 8
        keys.setHuggingPriority(.required, for: .horizontal)

        var items: [NSView] = [
            heading(tr("ลองแคปจอดู", "Try taking a screenshot"), size: 22),
            keys,
            text(tr("กดพร้อมกัน แล้วลากคลุมส่วนไหนของจอก็ได้", "Press them together, then drag over any part of the screen."),
                 width: width - 120, center: true),
        ]
        if let captured {
            let img = NSImageView(image: captured)
            img.imageScaling = .scaleProportionallyDown
            img.wantsLayer = true
            img.layer?.cornerRadius = 8
            img.layer?.masksToBounds = true
            img.widthAnchor.constraint(lessThanOrEqualToConstant: 260).isActive = true
            img.heightAnchor.constraint(equalToConstant: 130).isActive = true
            let ok = NSStackView(views: [
                symbol("checkmark.circle.fill", size: 18, color: .systemGreen),
                heading(tr("เจอแล้ว! ภาพนี้อยู่ใน \(AppInfo.name) แล้ว", "Got it! This one is in \(AppInfo.name) now."), size: 14),
            ])
            ok.spacing = 6
            items += [img, ok]
        } else {
            let spin = NSProgressIndicator()
            spin.style = .spinning
            spin.controlSize = .small
            spin.startAnimation(nil)
            let wait = NSStackView(views: [spin, text(tr("รอภาพ…", "Waiting for a screenshot…"), width: 300)])
            wait.spacing = 8
            items.append(wait)
            if Prefs.thumbStyle == .macOS {
                items.append(note(tr("รูปเล็กของ Mac ทำให้ภาพเข้าช้าราว 5 วินาที ปัดรูปเล็กทิ้งเพื่อให้เข้าทันที",
                                     "With the Mac's thumbnail, it arrives about 5 seconds later. Swipe the thumbnail away to save it now.")))
            }
        }
        let body = column(items, spacing: 14, gap: (after: 0, size: 18))
        let back = button(tr("ย้อนกลับ", "Back"), #selector(goBack))
        let next = captured == nil
            ? button(tr("ข้าม", "Skip"), #selector(goNext))
            : button(tr("ถัดไป", "Next"), #selector(goNext))
        return (body, [back, next])
    }

    private func doneStep() -> (NSView, [NSButton]) {
        var rows: [NSView] = []

        let keyCap = KeyCap(Prefs.shortcut.display, size: 20)
        if shortcutWorks {
            rows.append(row(keyCap, text(tr("กดเพื่อเปิดหน้าต่าง \(AppInfo.name) ได้ทุกเมื่อ ลองกดดูก็ได้",
                                            "Opens the \(AppInfo.name) window any time. Try it now."), width: 330)))
        } else {
            let warn = text(tr("มีแอปอื่นใช้ปุ่มนี้อยู่ เลยเปิดด้วยปุ่มนี้ไม่ได้", "Another app uses this shortcut, so it can't open \(AppInfo.name)."),
                            width: 330)
            warn.textColor = .systemRed
            let change = NSButton(title: tr("เปลี่ยนปุ่มลัด…", "Change Shortcut…"), target: self, action: #selector(showSettings))
            change.bezelStyle = .rounded
            change.controlSize = .small
            let col = NSStackView(views: [warn, change])
            col.orientation = .vertical
            col.alignment = .leading
            col.spacing = 6
            rows.append(row(keyCap, col))
        }

        let icon = NSImageView(image: MenuBarIcon.make())
        icon.contentTintColor = .labelColor
        let iconCap = KeyCap(nil, size: 20)
        iconCap.addCentered(icon)
        rows.append(row(iconCap, text(tr("หรือคลิกไอคอนนี้บนแถบเมนูด้านบนขวาของจอ",
                                         "Or click this icon in the menu bar at the top right of the screen."), width: 330)))

        if declined {
            let warn = row(symbol("exclamationmark.triangle.fill", size: 18, color: .systemOrange),
                           text(tr("\(AppInfo.name) ยังไม่ได้เก็บภาพ เปิดได้ในหน้าตั้งค่า หรือจากหน้าต่าง \(AppInfo.name)",
                                   "\(AppInfo.name) isn't keeping screenshots yet. Turn it on in Settings or from the \(AppInfo.name) window."),
                                width: 330))
            rows.append(warn)
        }

        let login = NSButton(checkboxWithTitle: tr("เปิด \(AppInfo.name) อัตโนมัติตอนเข้าเครื่อง",
                                                   "Open \(AppInfo.name) automatically at login"),
                             target: self, action: #selector(loginChanged(_:)))
        login.state = loginOn ? .on : .off
        var loginItems: [NSView] = [login]
        if !Self.inApplications {
            login.isEnabled = false
            login.state = .off
            loginItems.append(note(tr("ย้ายแอปไปไว้ในโฟลเดอร์ Applications ก่อน ถึงจะเปิดอัตโนมัติได้",
                                      "Move the app to the Applications folder first to open it at login.")))
        } else if loginNeedsApproval {
            loginItems.append(note(tr("macOS ต้องให้คุณอนุญาตก่อน เปิด \(AppInfo.name) ใน System Settings → General → Login Items",
                                      "macOS needs your OK first: turn on \(AppInfo.name) in System Settings → General → Login Items.")))
            let open = NSButton(title: tr("เปิด System Settings", "Open System Settings"), target: self, action: #selector(openLoginItems))
            open.bezelStyle = .rounded
            open.controlSize = .small
            loginItems.append(open)
        }
        let updates = NSButton(checkboxWithTitle: tr("ตรวจหาอัปเดตอัตโนมัติ", "Check for updates automatically"),
                               target: self, action: #selector(updatesChanged(_:)))
        updates.state = autoUpdateOn ? .on : .off
        loginItems.append(updates)
        let loginCol = NSStackView(views: loginItems)
        loginCol.orientation = .vertical
        loginCol.alignment = .leading
        loginCol.spacing = 6

        let list = NSStackView(views: rows + [row(NSView(), loginCol)])
        list.orientation = .vertical
        list.alignment = .leading
        list.spacing = 16
        list.setCustomSpacing(24, after: rows.last!)

        let body = column([
            symbol("checkmark.seal.fill", size: 40, color: .controlAccentColor),
            heading(tr("พร้อมใช้แล้ว", "You're all set"), size: 22),
            list,
        ], spacing: 14, gap: (after: 1, size: 22))
        let back = button(tr("ย้อนกลับ", "Back"), #selector(goBack))
        let start = button(tr("เริ่มใช้งาน", "Start Using \(AppInfo.name)"), #selector(finish))
        return (body, [back, start])
    }

    // MARK: Actions

    @objc private func langChanged(_ sender: NSSegmentedControl) {
        let l = Lang.allCases[sender.selectedSegment]
        if preview { Prefs.langOverride = l; rebuild() } else { Prefs.lang = l }   // posts prefsChanged
    }

    @objc private func askDecline() { confirmingDecline = true; rebuild() }

    @objc private func keep() {
        declined = false
        confirmingDecline = false
        onKeep?()
        step = .thumbnail
        rebuild()
    }

    @objc private func decline() {
        declined = true
        confirmingDecline = false
        onDecline?()
        step = .done
        rebuild()
    }

    private func pick(_ s: ThumbStyle) {
        if preview { return }
        Prefs.thumbStyle = s   // posts prefsChanged, which rebuilds
        onThumbChanged?()
    }

    @objc private func pickNone() { pick(.none) }

    @objc private func goBack() {
        switch step {
        case .welcome: break
        case .thumbnail: step = .welcome
        case .tryIt: step = .thumbnail
        case .done: step = declined ? .welcome : .tryIt
        }
        rebuild()
    }

    @objc private func goNext() {
        if let next = Step(rawValue: step.rawValue + 1) { step = next }
        rebuild()
    }

    @objc private func showSettings() { onShowSettings?() }

    @objc private func loginChanged(_ sender: NSButton) {
        loginOn = sender.state == .on
        loginNeedsApproval = false
    }

    @objc private func updatesChanged(_ sender: NSButton) { autoUpdateOn = sender.state == .on }

    @objc private func openLoginItems() { SMAppService.openSystemSettingsLoginItems() }

    @objc private func finish() {
        if !preview, Self.inApplications {
            let svc = SMAppService.mainApp
            if loginOn, svc.status != .enabled {
                try? svc.register()
                // First press: say what macOS still needs. A second press goes on.
                if svc.status == .requiresApproval, !loginNeedsApproval {
                    loginNeedsApproval = true
                    rebuild()
                    return
                }
            } else if !loginOn, svc.status == .enabled || svc.status == .requiresApproval {
                try? svc.unregister()
            }
        }
        if !preview { Prefs.onboardingDone = true }
        window?.close()
        onFinish?(!declined, autoUpdateOn)
    }

    // MARK: Helpers

    private static var inApplications: Bool {
        let path = Bundle.main.bundlePath
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return path.hasPrefix("/Applications/") || path.hasPrefix(home + "/Applications/")
    }

    /// Centered column; `gap` adds extra room after the view at `after`.
    private func column(_ views: [NSView], spacing: CGFloat, gap: (after: Int, size: CGFloat)? = nil) -> NSStackView {
        let s = NSStackView(views: views)
        s.orientation = .vertical
        s.alignment = .centerX
        s.spacing = spacing
        if let gap, views.indices.contains(gap.after) { s.setCustomSpacing(gap.size, after: views[gap.after]) }
        return s
    }

    private func row(_ lead: NSView, _ trail: NSView) -> NSStackView {
        // Fixed-width slot so the texts line up; the key keeps its own width, right-aligned.
        let lw = NSView()
        lead.translatesAutoresizingMaskIntoConstraints = false
        lw.addSubview(lead)
        NSLayoutConstraint.activate([
            lw.widthAnchor.constraint(equalToConstant: 140),
            lead.trailingAnchor.constraint(equalTo: lw.trailingAnchor),
            lead.topAnchor.constraint(equalTo: lw.topAnchor),
            lead.bottomAnchor.constraint(equalTo: lw.bottomAnchor),
            lead.leadingAnchor.constraint(greaterThanOrEqualTo: lw.leadingAnchor),
        ])
        let r = NSStackView(views: [lw, trail])
        r.spacing = 14
        r.alignment = .centerY
        return r
    }

    private func heading(_ s: String, size: CGFloat) -> NSTextField {
        let l = NSTextField(wrappingLabelWithString: s)
        l.font = .systemFont(ofSize: size, weight: size >= 20 ? .bold : .semibold)
        l.alignment = .center
        l.isSelectable = false
        return l
    }

    private func text(_ s: String, width: CGFloat, center: Bool = false) -> NSTextField {
        let l = NSTextField(wrappingLabelWithString: s)
        l.font = .systemFont(ofSize: 13)
        l.textColor = .secondaryLabelColor
        l.alignment = center ? .center : .natural
        l.preferredMaxLayoutWidth = width
        l.isSelectable = false
        return l
    }

    private func note(_ s: String) -> NSTextField {
        let l = text(s, width: width - 140, center: true)
        l.font = .systemFont(ofSize: 11)
        l.textColor = .tertiaryLabelColor
        return l
    }

    private func symbol(_ name: String, size: CGFloat, color: NSColor) -> NSImageView {
        let cfg = NSImage.SymbolConfiguration(pointSize: size, weight: .regular)
        let v = NSImageView(image: NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(cfg) ?? NSImage())
        v.contentTintColor = color
        return v
    }

    private func button(_ title: String, _ action: Selector) -> NSButton {
        let b = NSButton(title: title, target: self, action: action)
        b.bezelStyle = .rounded
        b.controlSize = .large
        return b
    }

    func windowWillClose(_ notification: Notification) {
        Prefs.langOverride = nil
    }
}

// MARK: - Small views

/// Text button that reads as a link: link colour, underlined, pointing-hand cursor.
private final class LinkButton: NSButton {
    convenience init(title: String, target: AnyObject, action: Selector) {
        self.init(frame: .zero)
        self.target = target
        self.action = action
        isBordered = false
        setButtonType(.momentaryChange)
        attributedTitle = NSAttributedString(string: title, attributes: [
            .foregroundColor: NSColor.linkColor,
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .font: NSFont.systemFont(ofSize: 12),
        ])
        setAccessibilityRole(.link)
    }
    override func resetCursorRects() { addCursorRect(bounds, cursor: .pointingHand) }
}

/// Step indicator dot.
private final class Dot: NSView {
    private let on: Bool
    init(on: Bool) {
        self.on = on
        super.init(frame: .zero)
        wantsLayer = true
        widthAnchor.constraint(equalToConstant: 7).isActive = true
        heightAnchor.constraint(equalToConstant: 7).isActive = true
    }
    required init?(coder: NSCoder) { fatalError() }
    override var wantsUpdateLayer: Bool { true }
    override func updateLayer() {
        layer?.cornerRadius = 3.5
        layer?.backgroundColor = (on ? NSColor.controlAccentColor : NSColor.tertiaryLabelColor).cgColor
    }
}

/// Rounded panel behind a group of views.
private final class Box: NSView {
    init(views: [NSView]) {
        super.init(frame: .zero)
        wantsLayer = true
        let s = NSStackView(views: views)
        s.orientation = .vertical
        s.alignment = .centerX
        s.spacing = 6
        s.translatesAutoresizingMaskIntoConstraints = false
        addSubview(s)
        NSLayoutConstraint.activate([
            s.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            s.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14),
            s.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
            s.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -18),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }
    override var wantsUpdateLayer: Bool { true }
    override func updateLayer() {
        layer?.cornerRadius = 10
        layer?.backgroundColor = NSColor.quaternaryLabelColor.withAlphaComponent(0.08).cgColor
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.cgColor
    }
}

/// A key drawn like a keyboard key.
private final class KeyCap: NSView {
    init(_ label: String?, size: CGFloat) {
        super.init(frame: .zero)
        wantsLayer = true
        heightAnchor.constraint(equalToConstant: size * 1.9).isActive = true
        widthAnchor.constraint(greaterThanOrEqualToConstant: size * 1.9).isActive = true
        // As narrow as its label allows; never stretched by the row around it.
        setContentHuggingPriority(.required, for: .horizontal)
        let tight = widthAnchor.constraint(equalToConstant: size * 1.9)
        tight.priority = .defaultLow
        tight.isActive = true
        if let label {
            let l = NSTextField(labelWithString: label)
            l.font = .systemFont(ofSize: size, weight: .medium)
            l.alignment = .center
            addCentered(l, padding: size * 0.6)
        }
    }
    required init?(coder: NSCoder) { fatalError() }

    func addCentered(_ v: NSView, padding: CGFloat = 0) {
        v.translatesAutoresizingMaskIntoConstraints = false
        addSubview(v)
        NSLayoutConstraint.activate([
            v.centerXAnchor.constraint(equalTo: centerXAnchor),
            v.centerYAnchor.constraint(equalTo: centerYAnchor),
            v.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: padding),
            v.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -padding),
        ])
    }

    override var wantsUpdateLayer: Bool { true }
    override func updateLayer() {
        layer?.cornerRadius = 8
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.cgColor
        layer?.shadowOpacity = 0.12
        layer?.shadowRadius = 1
        layer?.shadowOffset = CGSize(width: 0, height: -1)
    }
}

/// A clickable choice: icon, title, optional badge, one line for and one against.
private final class Card: NSView {
    private let selected: Bool
    private let onClick: () -> Void

    init(style: ThumbStyle, symbol: String, badge: String?, selected: Bool, onClick: @escaping () -> Void) {
        self.selected = selected
        self.onClick = onClick
        super.init(frame: .zero)
        wantsLayer = true

        let cfg = NSImage.SymbolConfiguration(pointSize: 30, weight: .regular)
        let icon = NSImageView(image: NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?
            .withSymbolConfiguration(cfg) ?? NSImage())
        icon.contentTintColor = selected ? .controlAccentColor : .secondaryLabelColor

        let title = NSTextField(labelWithString: style.title)
        title.font = .systemFont(ofSize: 15, weight: .semibold)
        var head: [NSView] = [title]
        if let badge {
            let b = NSTextField(labelWithString: " \(badge) ")
            b.font = .systemFont(ofSize: 10, weight: .semibold)
            b.textColor = .white
            b.wantsLayer = true
            b.drawsBackground = true
            b.backgroundColor = .controlAccentColor
            b.layer?.cornerRadius = 4
            b.layer?.masksToBounds = true
            head.append(b)
        }
        let headRow = NSStackView(views: head)
        headRow.spacing = 6

        func line(_ mark: String, _ s: String, _ color: NSColor) -> NSView {
            let m = NSTextField(labelWithString: mark)
            m.font = .systemFont(ofSize: 12, weight: .bold)
            m.textColor = color
            let t = NSTextField(wrappingLabelWithString: s)
            t.font = .systemFont(ofSize: 12)
            t.textColor = .secondaryLabelColor
            t.isSelectable = false
            t.preferredMaxLayoutWidth = 200
            let r = NSStackView(views: [m, t])
            r.alignment = .firstBaseline
            r.spacing = 6
            return r
        }

        let s = NSStackView(views: [icon, headRow, line("✓", style.pro, .systemGreen), line("–", style.con, .secondaryLabelColor)])
        s.orientation = .vertical
        s.alignment = .leading
        s.spacing = 8
        s.setCustomSpacing(12, after: headRow)
        s.translatesAutoresizingMaskIntoConstraints = false
        addSubview(s)
        NSLayoutConstraint.activate([
            s.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            s.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -16),
            s.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            s.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            heightAnchor.constraint(greaterThanOrEqualToConstant: 170),
        ])
        setAccessibilityRole(.radioButton)
        setAccessibilityLabel(style.title)
        setAccessibilityValue(selected)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func mouseDown(with event: NSEvent) { onClick() }
    override func accessibilityPerformPress() -> Bool { onClick(); return true }
    override func resetCursorRects() { addCursorRect(bounds, cursor: .pointingHand) }

    override var wantsUpdateLayer: Bool { true }
    override func updateLayer() {
        layer?.cornerRadius = 12
        layer?.borderWidth = selected ? 2 : 1
        layer?.borderColor = (selected ? NSColor.controlAccentColor : NSColor.separatorColor).cgColor
        layer?.backgroundColor = (selected ? NSColor.controlAccentColor.withAlphaComponent(0.08)
                                           : NSColor.quaternaryLabelColor.withAlphaComponent(0.05)).cgColor
    }
}

// MARK: - Preview

/// Opens the first-launch window in one state, for screenshots in docs and
/// reviews: `BOARDSHOT_ONBOARDING_PREVIEW=<state>`, where state is welcome,
/// confirm, thumbnail, try, try-done, done, done-declined or done-approval.
/// Optional: `BOARDSHOT_PREVIEW_LANG=th|en`, `BOARDSHOT_PREVIEW_DARK=1`.
/// Prints `window <number>` for `screencapture -l`. Changes no setting.
enum OnboardingPreview {
    private static var controller: OnboardingController?

    static func show(_ state: String) {
        let env = ProcessInfo.processInfo.environment
        if let raw = env["BOARDSHOT_PREVIEW_LANG"], let l = Lang(rawValue: raw) { Prefs.langOverride = l }
        if env["BOARDSHOT_PREVIEW_DARK"] == "1" { NSApp.appearance = NSAppearance(named: .darkAqua) }
        let c = OnboardingController(preview: true)
        controller = c
        let step: OnboardingController.Step
        switch state {
        case "thumbnail": step = .thumbnail
        case "try", "try-done": step = .tryIt
        case "done", "done-declined", "done-approval": step = .done
        default: step = .welcome
        }
        c.show(at: step)
        c.previewState(confirming: state == "confirm",
                       declined: state == "done-declined",
                       captured: state == "try-done" ? NSApp.applicationIconImage : nil,
                       needsApproval: state == "done-approval")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            FileHandle.standardOutput.write("window \(c.windowNumber)\n".data(using: .utf8)!)
        }
    }
}
