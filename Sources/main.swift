import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var store: ShotStore!
    private var panel: PanelController!
    private let settings = SettingsWindowController()
    private let corner = CornerThumb()

    static let folder = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Pictures/\(AppInfo.name)", isDirectory: true)

    func applicationDidFinishLaunching(_ note: Notification) {
        // Only one copy at a time: two copies would fight over the system
        // screenshot settings. Show the running one's panel and quit this one.
        if let other = NSRunningApplication.runningApplications(
            withBundleIdentifier: Bundle.main.bundleIdentifier ?? "").first(where: { $0 != .current }),
           let url = other.bundleURL {
            NSWorkspace.shared.openApplication(at: url, configuration: .init()) { _, _ in
                DispatchQueue.main.async { exit(0) }
            }
            return
        }

        store = ShotStore(folder: Self.folder)
        applyManageSetting()
        panel = PanelController(store: store)

        HotKey.shared.action = { [weak self] in self?.panel.toggle() }
        let ok = HotKey.shared.register(Prefs.shortcut)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = MenuBarIcon.make()
        rebuildMenu()

        // Corner thumbnail: shows after each new screenshot, closes the moment
        // the Boardshot window opens.
        panel.onWillShow = { [weak self] in self?.corner.hide() }
        corner.onClick = { [weak self] url in self?.panel.show(selecting: url) }
        store.onNewShot = { [weak self] shot in self?.showCorner(for: shot) }

        panel.onShowSettings = { [weak self] in self?.settings.show() }
        panel.onQuit = { NSApp.terminate(nil) }
        settings.onQuit = { NSApp.terminate(nil) }
        settings.onManageChanged = { [weak self] in self?.applyManageSetting() }
        NotificationCenter.default.addObserver(self, selector: #selector(prefsChanged),
                                               name: .prefsChanged, object: nil)

        if !ok {
            let a = NSAlert()
            a.messageText = tr("ใช้ปุ่ม \(Prefs.shortcut.display) ไม่ได้", "Can't use \(Prefs.shortcut.display)")
            a.informativeText = tr("มีแอปอื่นใช้ปุ่มนี้อยู่ เปลี่ยนได้ในหน้าตั้งค่า",
                                   "Another app is using it. You can change it in Settings.")
            a.addButton(withTitle: tr("เปิดตั้งค่า", "Open Settings"))
            a.addButton(withTitle: tr("ปิด", "Close"))
            if a.runModal() == .alertFirstButtonReturn { settings.show() }
        }
    }

    /// Opening the app again (Finder, Spotlight, `open`) shows the panel.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        panel?.show()   // nil while a duplicate copy is quitting
        return false
    }

    private func showCorner(for shot: Shot, retry: Bool = true) {
        guard Prefs.thumbStyle == .boardshot, Prefs.manageScreenshots, !panel.isVisible else { return }
        store.thumbnail(for: shot.url, size: CGSize(width: 440, height: 300)) { [weak self] img in
            guard let self else { return }
            if let img = img ?? NSImage(contentsOf: shot.url) {
                self.corner.show(url: shot.url, image: img)
            } else if retry {
                // File may still be being written; try once more shortly.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    self.showCorner(for: shot, retry: false)
                }
            }
        }
    }

    private func applyManageSetting() {
        if Prefs.thumbStyle != .boardshot || !Prefs.manageScreenshots { corner.hide() }
        if Prefs.manageScreenshots {
            ScreencaptureSettings.apply(folder: Self.folder, systemThumbnail: Prefs.thumbStyle.systemThumbnail)
        }
        else { ScreencaptureSettings.restore() }
    }

    @objc private func prefsChanged() { rebuildMenu() }

    // MARK: Menu bar

    private func rebuildMenu() {
        let menu = NSMenu()
        let open = NSMenuItem(title: tr("เปิด \(AppInfo.name)", "Open \(AppInfo.name)"),
                              action: #selector(openPanel), keyEquivalent: "")
        if let (key, mods) = Prefs.shortcut.menuKey {
            open.keyEquivalent = key
            open.keyEquivalentModifierMask = mods
        }
        menu.addItem(open)
        menu.addItem(NSMenuItem(title: tr("เปิดโฟลเดอร์ใน Finder", "Show Folder in Finder"),
                                action: #selector(openFolder), keyEquivalent: ""))
        let update = NSMenuItem(title: tr("ตรวจหาอัปเดต…", "Check for Updates…"),
                                action: #selector(Updater.checkForUpdates), keyEquivalent: "")
        menu.addItem(.separator())
        if Updater.shared.isConfigured { menu.addItem(update) }
        // Selector name matters: macOS 26 adds a gear icon to items whose
        // action is named like "openSettings", so avoid that name.
        menu.addItem(NSMenuItem(title: tr("ตั้งค่า…", "Settings…"),
                                action: #selector(showPrefsWindow), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: tr("ออก", "Quit"), action: #selector(quit), keyEquivalent: "q"))
        for item in menu.items { item.target = self }
        update.target = Updater.shared
        statusItem.menu = menu
        statusItem.isVisible = Prefs.showMenuBarIcon
    }

    @objc private func openPanel() { panel.show() }
    @objc private func openFolder() { NSWorkspace.shared.open(Self.folder) }
    @objc private func showPrefsWindow() { settings.show() }
    @objc private func quit() { NSApp.terminate(nil) }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
