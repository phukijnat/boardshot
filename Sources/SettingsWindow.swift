import AppKit
import ServiceManagement

/// Button that records a new shortcut when clicked.
final class ShortcutRecorder: NSButton {
    var onRecord: ((Shortcut) -> Bool)?   // return false if it couldn't be used
    var onCancel: (() -> Void)?
    var onStart: (() -> Void)?
    private(set) var recording = false

    override var acceptsFirstResponder: Bool { true }

    func start() {
        recording = true
        title = tr("กดปุ่มที่ต้องการ…", "Press keys…")
        window?.makeFirstResponder(self)
        onStart?()
    }

    func stop(showing s: Shortcut) {
        recording = false
        title = s.display
    }

    override func mouseDown(with event: NSEvent) {
        if recording { return }
        highlight(true)
        super.mouseDown(with: event)
        highlight(false)
        start()
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard recording, event.type == .keyDown else { return super.performKeyEquivalent(with: event) }
        handle(event)
        return true
    }

    override func keyDown(with event: NSEvent) {
        guard recording else { return super.keyDown(with: event) }
        handle(event)
    }

    private func handle(_ event: NSEvent) {
        let plain = event.modifierFlags.intersection([.command, .control, .option, .shift]).isEmpty
        if event.keyCode == 53 && plain { recording = false; onCancel?(); return } // Esc
        guard let s = Shortcut(event: event) else { NSSound.beep(); return }
        if onRecord?(s) == true { recording = false } else { NSSound.beep() }
    }

    override func resignFirstResponder() -> Bool {
        if recording { recording = false; onCancel?() }
        return super.resignFirstResponder()
    }
}

final class SettingsWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private let recorder = ShortcutRecorder()
    private let errorLabel = NSTextField(labelWithString: "")
    var onManageChanged: (() -> Void)?
    var onQuit: (() -> Void)?
    var onShowWelcome: (() -> Void)?

    override init() {
        super.init()
        recorder.widthAnchor.constraint(greaterThanOrEqualToConstant: 140).isActive = true
        NotificationCenter.default.addObserver(self, selector: #selector(prefsChanged),
                                               name: .prefsChanged, object: nil)
    }

    func show() {
        if window == nil { window = makeWindow() }
        rebuild()
        window?.center()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    @objc private func prefsChanged() {
        // Rebuild texts when the language changes (but not mid-recording).
        if window?.isVisible == true, !recorder.recording { rebuild() }
    }

    private func makeWindow() -> NSWindow {
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 300),
                         styleMask: [.titled, .closable], backing: .buffered, defer: false)
        w.isReleasedWhenClosed = false
        w.delegate = self
        return w
    }

    func windowWillClose(_ notification: Notification) {
        if recorder.recording { recorder.stop(showing: Prefs.shortcut); restoreHotKey() }
    }

    private func rebuild() {
        guard let window else { return }
        window.title = tr("ตั้งค่า \(AppInfo.name)", "\(AppInfo.name) Settings")

        // Shortcut
        recorder.bezelStyle = .rounded
        recorder.title = Prefs.shortcut.display
        recorder.target = nil
        recorder.onStart = { [weak self] in
            self?.errorLabel.stringValue = ""
            HotKey.shared.unregister()   // so pressing the current combo doesn't open the panel
        }
        recorder.onCancel = { [weak self] in
            self?.recorder.stop(showing: Prefs.shortcut)
            self?.restoreHotKey()
        }
        recorder.onRecord = { [weak self] s in
            guard let self else { return false }
            if HotKey.shared.register(s) {
                Prefs.shortcut = s
                self.recorder.stop(showing: s)
                self.errorLabel.stringValue = ""
                return true
            }
            self.errorLabel.stringValue = tr("ปุ่ม \(s.display) ถูกใช้อยู่แล้ว ลองปุ่มอื่น",
                                             "\(s.display) is already in use. Try another.")
            return false
        }
        let resetBtn = NSButton(title: tr("ค่าเริ่มต้น", "Default"), target: self, action: #selector(resetShortcut))
        resetBtn.bezelStyle = .rounded
        errorLabel.textColor = .systemRed
        errorLabel.font = .systemFont(ofSize: 11)
        let shortcutRow = NSStackView(views: [recorder, resetBtn])
        shortcutRow.spacing = 8
        let shortcutCol = NSStackView(views: [shortcutRow, errorLabel])
        shortcutCol.orientation = .vertical
        shortcutCol.alignment = .leading
        shortcutCol.spacing = 4

        // Language
        let langPopup = NSPopUpButton()
        for l in Lang.allCases { langPopup.addItem(withTitle: l.label) }
        langPopup.selectItem(at: Lang.allCases.firstIndex(of: Prefs.lang) ?? 0)
        langPopup.target = self
        langPopup.action = #selector(langChanged(_:))

        // Manage screenshots
        let manage = NSButton(checkboxWithTitle: tr("เก็บ screenshot ไว้ที่ \(AppInfo.name)", "Keep screenshots in \(AppInfo.name)"),
                              target: self, action: #selector(manageChanged(_:)))
        manage.state = Prefs.manageScreenshots ? .on : .off
        let manageNote = NSTextField(wrappingLabelWithString: tr(
            "ภาพไปที่ ~/Pictures/\(AppInfo.name)\nเอาติ๊กออกหรือออกจากแอป จะคืนค่าเดิมของ Mac",
            "Screenshots go to ~/Pictures/\(AppInfo.name).\nUntick, or quit the app, to restore the Mac's original settings."))
        manageNote.font = .systemFont(ofSize: 11)
        manageNote.textColor = .secondaryLabelColor
        manageNote.preferredMaxLayoutWidth = 320

        // Thumbnail after capture
        let thumbLabel = NSTextField(labelWithString: tr("รูปเล็กหลังถ่าย", "Thumbnail after capture"))
        let thumbPopup = NSPopUpButton()
        for s in ThumbStyle.allCases { thumbPopup.addItem(withTitle: s.title) }
        thumbPopup.selectItem(at: ThumbStyle.allCases.firstIndex(of: Prefs.thumbStyle) ?? 0)
        thumbPopup.target = self
        thumbPopup.action = #selector(thumbStyleChanged(_:))
        thumbPopup.isEnabled = Prefs.manageScreenshots
        let thumbRow = NSStackView(views: [thumbLabel, thumbPopup])
        thumbRow.spacing = 8
        thumbRow.alignment = .firstBaseline
        let thumbNote = NSTextField(wrappingLabelWithString: Prefs.thumbStyle.note)
        thumbNote.font = .systemFont(ofSize: 11)
        thumbNote.textColor = .secondaryLabelColor
        thumbNote.preferredMaxLayoutWidth = 320

        let manageCol = NSStackView(views: [manage, manageNote, thumbRow, thumbNote])
        manageCol.orientation = .vertical
        manageCol.alignment = .leading
        manageCol.spacing = 4

        // Hover preview
        let hoverPreview = NSButton(checkboxWithTitle: tr("แสดงภาพใหญ่เมื่อชี้เมาส์ค้างบนรูป",
                                                          "Show a larger preview when hovering a shot"),
                                    target: self, action: #selector(hoverPreviewChanged(_:)))
        hoverPreview.state = Prefs.showHoverPreview ? .on : .off

        // Login
        let login = NSButton(checkboxWithTitle: tr("เปิดอัตโนมัติตอนเข้าเครื่อง", "Open at login"),
                             target: self, action: #selector(loginChanged(_:)))
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off

        // Menu bar icon
        let menuBar = NSButton(checkboxWithTitle: tr("แสดงไอคอนบนแถบเมนูด้านบน", "Show icon in the menu bar"),
                               target: self, action: #selector(menuBarChanged(_:)))
        menuBar.state = Prefs.showMenuBarIcon ? .on : .off
        let menuBarNote = NSTextField(wrappingLabelWithString: tr(
            "ถ้าซ่อน เปิดตั้งค่าได้จากปุ่มเฟือง ⚙ ในหน้าต่าง \(AppInfo.name) หรือกด ⌘,",
            "If hidden, open Settings from the gear button in the \(AppInfo.name) window, or press ⌘,"))
        menuBarNote.font = .systemFont(ofSize: 11)
        menuBarNote.textColor = .secondaryLabelColor
        menuBarNote.preferredMaxLayoutWidth = 320
        let menuBarCol = NSStackView(views: [menuBar, menuBarNote])
        menuBarCol.orientation = .vertical
        menuBarCol.alignment = .leading
        menuBarCol.spacing = 4

        // Updates
        let autoUpdate = NSButton(checkboxWithTitle: tr("ตรวจหาอัปเดตอัตโนมัติ", "Check for updates automatically"),
                                  target: self, action: #selector(autoUpdateChanged(_:)))
        autoUpdate.state = Updater.shared.automaticallyChecks ? .on : .off
        let checkBtn = NSButton(title: tr("ตรวจเดี๋ยวนี้", "Check Now"),
                                target: Updater.shared, action: #selector(Updater.checkForUpdates))
        checkBtn.bezelStyle = .rounded
        let versionLabel = NSTextField(labelWithString: tr("เวอร์ชัน \(AppInfo.version)", "Version \(AppInfo.version)"))
        versionLabel.font = .systemFont(ofSize: 11)
        versionLabel.textColor = .secondaryLabelColor
        let checkRow = NSStackView(views: [checkBtn, versionLabel])
        checkRow.spacing = 8
        let updateCol = NSStackView(views: [autoUpdate, checkRow])
        updateCol.orientation = .vertical
        updateCol.alignment = .leading
        updateCol.spacing = 6
        autoUpdate.isEnabled = Updater.shared.isConfigured
        checkBtn.isEnabled = Updater.shared.isConfigured

        let quitBtn = NSButton(title: tr("ออกจาก \(AppInfo.name)", "Quit \(AppInfo.name)"),
                               target: self, action: #selector(quitClicked))
        quitBtn.bezelStyle = .rounded
        let welcomeBtn = NSButton(title: tr("แสดงหน้าแนะนำอีกครั้ง", "Show Welcome Again"),
                                  target: self, action: #selector(welcomeClicked))
        welcomeBtn.bezelStyle = .rounded
        let bottomRow = NSStackView(views: [welcomeBtn, quitBtn])
        bottomRow.spacing = 8

        func label(_ s: String) -> NSTextField {
            let l = NSTextField(labelWithString: s)
            l.alignment = .right
            return l
        }
        let grid = NSGridView(views: [
            [label(tr("คีย์ลัดเปิดหน้าต่าง", "Open shortcut")), shortcutCol],
            [label(tr("ภาษา", "Language")), langPopup],
            [label(tr("Screenshot", "Screenshots")), manageCol],
            [label(tr("หน้าต่าง", "Panel")), hoverPreview],
            [NSGridCell.emptyContentView, login],
            [label(tr("แถบเมนู", "Menu bar")), menuBarCol],
            [label(tr("อัปเดต", "Updates")), updateCol],
            [NSGridCell.emptyContentView, bottomRow],
        ])
        grid.rowSpacing = 16
        grid.columnSpacing = 12
        grid.column(at: 0).xPlacement = .trailing
        grid.rowAlignment = .firstBaseline
        for r in 0..<grid.numberOfRows { grid.row(at: r).yPlacement = .top }

        let container = NSView()
        grid.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(grid)
        NSLayoutConstraint.activate([
            grid.topAnchor.constraint(equalTo: container.topAnchor, constant: 24),
            grid.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 24),
            grid.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -24),
            grid.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -24),
        ])
        window.contentView = container
        window.setContentSize(container.fittingSize)
    }

    private func restoreHotKey() { HotKey.shared.register(Prefs.shortcut) }

    @objc private func resetShortcut() {
        recorder.stop(showing: .standard)
        if HotKey.shared.register(.standard) {
            Prefs.shortcut = .standard
            errorLabel.stringValue = ""
        } else {
            errorLabel.stringValue = tr("ปุ่ม ⇧⌘Space ถูกใช้อยู่แล้ว", "⇧⌘Space is already in use.")
            restoreHotKey()
            recorder.stop(showing: Prefs.shortcut)
        }
    }

    @objc private func langChanged(_ sender: NSPopUpButton) {
        Prefs.lang = Lang.allCases[sender.indexOfSelectedItem]
    }

    @objc private func manageChanged(_ sender: NSButton) {
        Prefs.manageScreenshots = (sender.state == .on)
        onManageChanged?()
    }

    @objc private func thumbStyleChanged(_ sender: NSPopUpButton) {
        Prefs.thumbStyle = ThumbStyle.allCases[sender.indexOfSelectedItem]
        onManageChanged?()   // writes the system `show-thumbnail` setting
    }

    @objc private func hoverPreviewChanged(_ sender: NSButton) {
        Prefs.showHoverPreview = (sender.state == .on)
    }

    @objc private func menuBarChanged(_ sender: NSButton) {
        Prefs.showMenuBarIcon = (sender.state == .on)
    }

    @objc private func autoUpdateChanged(_ sender: NSButton) {
        Updater.shared.automaticallyChecks = (sender.state == .on)
    }

    @objc private func quitClicked() { onQuit?() }
    @objc private func welcomeClicked() { window?.close(); onShowWelcome?() }

    @objc private func loginChanged(_ sender: NSButton) {
        let svc = SMAppService.mainApp
        do {
            if sender.state == .on { try svc.register() } else { try svc.unregister() }
        } catch {
            sender.state = svc.status == .enabled ? .on : .off
            NSAlert(error: error).runModal()
        }
    }
}
