import AppKit
import Carbon

extension Notification.Name {
    static let prefsChanged = Notification.Name("PrefsChanged")
}

/// The thumbnail shown after a screenshot.
enum ThumbStyle: String, CaseIterable {
    /// Boardshot's corner thumbnail. The file is saved right away.
    case boardshot
    /// The macOS floating thumbnail, with its Markup editor. macOS only saves
    /// the file once the thumbnail goes away (about 5 seconds, or a swipe).
    case macOS
    /// No thumbnail. The file is saved right away.
    case none

    /// Whether the system's `show-thumbnail` setting should be on.
    var systemThumbnail: Bool { self == .macOS }

    // Texts shared by Settings and the first-launch window, so they stay the same.

    var title: String {
        switch self {
        case .boardshot: return tr("ของ \(AppInfo.name)", "\(AppInfo.name)'s")
        case .macOS: return tr("ของ macOS", "macOS")
        case .none: return tr("ไม่แสดง", "None")
        }
    }

    /// One-paragraph explanation, for Settings.
    var note: String {
        switch self {
        case .boardshot:
            return tr("ขึ้นที่มุมขวาล่างของจอที่เมาส์อยู่ ไฟล์เข้าทันที",
                      "Shows in the bottom-right of the screen the mouse is on. The file is saved right away.")
        case .macOS:
            return tr("คลิกเพื่อแก้ไขด้วย Markup ของ Mac ได้ แต่ไฟล์จะเข้า \(AppInfo.name) หลังรูปเล็กหายไป (ราว 5 วินาที หรือปัดออกเพื่อให้เข้าทันที) และ macOS อาจไม่แสดงรูปเล็กเมื่อแคปจากจอที่สอง",
                      "Click it to edit with the Mac's Markup. The file reaches \(AppInfo.name) only after the thumbnail goes away (about 5 seconds, or swipe it away to save now). macOS may not show it for captures on a second display.")
        case .none:
            return tr("ไม่มีรูปเล็ก ไฟล์เข้าทันที", "No thumbnail. The file is saved right away.")
        }
    }

    /// What it's good at, in one short line (first-launch cards).
    var pro: String {
        switch self {
        case .boardshot: return tr("ภาพเข้า \(AppInfo.name) ทันที คลิกเพื่อเปิดดู หรือลากไปใช้ได้เลย",
                                   "Lands in \(AppInfo.name) instantly. Click to open it, or drag it straight into an app.")
        case .macOS: return tr("คลิกเพื่อขีดเขียนหรือครอปภาพด้วย Markup ของ Mac",
                               "Click to draw on it or crop it with the Mac's Markup.")
        case .none: return tr("ไม่มีอะไรเด้งขึ้นมา ภาพเข้าทันที", "Nothing pops up. Lands right away.")
        }
    }

    /// What you give up, in one short line (first-launch cards).
    var con: String {
        switch self {
        case .boardshot: return tr("ไม่มีเครื่องมือขีดเขียน", "No drawing tools.")
        case .macOS: return tr("ภาพเข้าช้าราว 5 วินาที หรือจนกว่าจะปัดรูปเล็กทิ้ง และอาจไม่ขึ้นเมื่อแคปจากจอที่สอง",
                               "Lands about 5 seconds later, or once you swipe it away. May not show on a second display.")
        case .none: return tr("ไม่เห็นว่าแคปติดหรือยัง", "No sign the capture worked.")
        }
    }
}

enum Lang: String, CaseIterable {
    case th, en
    var label: String { self == .th ? "ไทย" : "English" }
}

/// A global shortcut: Carbon key code + Carbon modifiers, plus a label like "⇧⌘Space".
struct Shortcut: Codable, Equatable {
    var keyCode: UInt32
    var modifiers: UInt32
    var display: String

    static let standard = Shortcut(keyCode: UInt32(kVK_Space),
                                   modifiers: UInt32(cmdKey | shiftKey),
                                   display: "⇧⌘Space")

    /// Builds a shortcut from a key press; nil if it has no ⌘/⌃/⌥ (unless it's an F-key).
    init?(event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        var mods: UInt32 = 0
        var label = ""
        if flags.contains(.control) { mods |= UInt32(controlKey); label += "⌃" }
        if flags.contains(.option) { mods |= UInt32(optionKey); label += "⌥" }
        if flags.contains(.shift) { mods |= UInt32(shiftKey); label += "⇧" }
        if flags.contains(.command) { mods |= UInt32(cmdKey); label += "⌘" }
        let code = UInt32(event.keyCode)
        let isFKey = Shortcut.fKeys[code] != nil
        guard isFKey || flags.contains(.command) || flags.contains(.control) || flags.contains(.option),
              let name = Shortcut.keyName(code) else { return nil }
        self.init(keyCode: code, modifiers: mods, display: label + name)
    }

    init(keyCode: UInt32, modifiers: UInt32, display: String) {
        self.keyCode = keyCode; self.modifiers = modifiers; self.display = display
    }

    /// Key equivalent for an NSMenuItem, when the key is a plain character.
    var menuKey: (String, NSEvent.ModifierFlags)? {
        guard let name = Shortcut.keyName(keyCode) else { return nil }
        let key: String
        if keyCode == UInt32(kVK_Space) { key = " " }
        else if name.count == 1 { key = name.lowercased() }
        else { return nil }
        var f: NSEvent.ModifierFlags = []
        if modifiers & UInt32(cmdKey) != 0 { f.insert(.command) }
        if modifiers & UInt32(shiftKey) != 0 { f.insert(.shift) }
        if modifiers & UInt32(optionKey) != 0 { f.insert(.option) }
        if modifiers & UInt32(controlKey) != 0 { f.insert(.control) }
        return (key, f)
    }

    private static let fKeys: [UInt32: String] = [
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
        98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12",
    ]
    private static let special: [UInt32: String] = [
        49: "Space", 36: "↩", 48: "⇥", 51: "⌫", 117: "⌦", 53: "Esc",
        123: "←", 124: "→", 125: "↓", 126: "↑", 115: "Home", 119: "End",
        116: "PgUp", 121: "PgDn",
    ]

    /// Name of a key on the US-style layout, so a Thai input source still shows "S", not "ห".
    static func keyName(_ code: UInt32) -> String? {
        if let n = fKeys[code] ?? special[code] { return n }
        guard let src = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue(),
              let ptr = TISGetInputSourceProperty(src, kTISPropertyUnicodeKeyLayoutData) else { return nil }
        let data = Unmanaged<CFData>.fromOpaque(ptr).takeUnretainedValue() as Data
        var dead: UInt32 = 0
        var chars = [UniChar](repeating: 0, count: 4)
        var len = 0
        let status = data.withUnsafeBytes { raw -> OSStatus in
            let layout = raw.bindMemory(to: UCKeyboardLayout.self).baseAddress!
            return UCKeyTranslate(layout, UInt16(code), UInt16(kUCKeyActionDisplay), 0,
                                  UInt32(LMGetKbdType()), OptionBits(kUCKeyTranslateNoDeadKeysBit),
                                  &dead, chars.count, &len, &chars)
        }
        guard status == noErr, len > 0 else { return nil }
        let s = String(utf16CodeUnits: chars, count: len).uppercased()
        return s.trimmingCharacters(in: .whitespaces).isEmpty ? nil : s
    }
}

/// User preferences, stored in UserDefaults.
enum Prefs {
    private static let d = UserDefaults.standard

    /// Language for a preview window only; never saved.
    static var langOverride: Lang?

    static var lang: Lang {
        get {
            if let langOverride { return langOverride }
            if let raw = d.string(forKey: "lang"), let l = Lang(rawValue: raw) { return l }
            return Locale.preferredLanguages.first?.hasPrefix("th") == true ? .th : .en
        }
        set { d.set(newValue.rawValue, forKey: "lang"); changed() }
    }

    static var shortcut: Shortcut {
        get {
            guard let data = d.data(forKey: "shortcut"),
                  let s = try? JSONDecoder().decode(Shortcut.self, from: data) else { return .standard }
            return s
        }
        set { d.set(try? JSONEncoder().encode(newValue), forKey: "shortcut"); changed() }
    }

    /// Whether Boardshot redirects screenshots to its folder (on by default).
    static var manageScreenshots: Bool {
        get { d.object(forKey: "manageScreenshots") as? Bool ?? true }
        set { d.set(newValue, forKey: "manageScreenshots"); changed() }
    }

    /// Which thumbnail appears after a screenshot (Boardshot's by default).
    /// Older versions stored an on/off `showCornerThumb`; "off" carries over as `.none`.
    static var thumbStyle: ThumbStyle {
        get {
            if let raw = d.string(forKey: "thumbStyle"), let s = ThumbStyle(rawValue: raw) { return s }
            return d.object(forKey: "showCornerThumb") as? Bool == false ? .none : .boardshot
        }
        set { d.set(newValue.rawValue, forKey: "thumbStyle"); changed() }
    }

    /// Whether hovering a thumbnail in the panel shows a larger preview (on by default).
    static var showHoverPreview: Bool {
        get { d.object(forKey: "showHoverPreview") as? Bool ?? true }
        set { d.set(newValue, forKey: "showHoverPreview"); changed() }
    }

    /// Whether the camera icon shows in the menu bar (on by default).
    static var showMenuBarIcon: Bool {
        get { d.object(forKey: "showMenuBarIcon") as? Bool ?? true }
        set { d.set(newValue, forKey: "showMenuBarIcon"); changed() }
    }

    /// Whether the first-launch window was finished (or skipped as an existing user).
    static var onboardingDone: Bool {
        get { d.bool(forKey: "onboardingDone") }
        set {
            d.set(newValue, forKey: "onboardingDone")
            if newValue { d.removeObject(forKey: "onboardingPending") }
        }
    }

    /// Decides once whether this person needs the first-launch window, and
    /// returns true while they still do. Someone who used Boardshot before the
    /// window existed (Sparkle marks every launch; an applied or chosen setting
    /// leaves traces too) is never shown it. The decision is saved, because
    /// Sparkle marks the first launch too: closing the window early must not
    /// make the next launch look like an old user's.
    static func needsOnboarding() -> Bool {
        if onboardingDone { return false }
        if d.bool(forKey: "onboardingPending") { return true }
        let usedBefore = d.bool(forKey: "SUHasLaunchedBefore") || d.object(forKey: "manageScreenshots") != nil
            || ScreencaptureSettings.hasSavedOriginals
        if usedBefore { onboardingDone = true; return false }
        d.set(true, forKey: "onboardingPending")
        // Not managed until the user agrees, so the panel and Settings say so.
        d.set(false, forKey: "manageScreenshots")
        return true
    }

    private static func changed() {
        NotificationCenter.default.post(name: .prefsChanged, object: nil)
    }
}

/// Picks the Thai or English string for the current language.
func tr(_ th: String, _ en: String) -> String { Prefs.lang == .th ? th : en }
