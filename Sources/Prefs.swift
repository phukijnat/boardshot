import AppKit
import Carbon

extension Notification.Name {
    static let prefsChanged = Notification.Name("PrefsChanged")
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

    static var lang: Lang {
        get {
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

    /// Whether Boardshot's own corner thumbnail appears after a screenshot (on by default).
    static var showCornerThumb: Bool {
        get { d.object(forKey: "showCornerThumb") as? Bool ?? true }
        set { d.set(newValue, forKey: "showCornerThumb"); changed() }
    }

    /// Whether the camera icon shows in the menu bar (on by default).
    static var showMenuBarIcon: Bool {
        get { d.object(forKey: "showMenuBarIcon") as? Bool ?? true }
        set { d.set(newValue, forKey: "showMenuBarIcon"); changed() }
    }

    private static func changed() {
        NotificationCenter.default.post(name: .prefsChanged, object: nil)
    }
}

/// Picks the Thai or English string for the current language.
func tr(_ th: String, _ en: String) -> String { Prefs.lang == .th ? th : en }
