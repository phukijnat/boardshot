import Carbon

/// One global hotkey via Carbon (needs no Accessibility permission).
/// Can be re-registered when the user picks a new shortcut.
final class HotKey {
    static let shared = HotKey()
    var action: (() -> Void)?
    private var ref: EventHotKeyRef?
    private var handler: EventHandlerRef?

    private init() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            DispatchQueue.main.async { HotKey.shared.action?() }
            return noErr
        }, 1, &spec, nil, &handler)
    }

    /// Returns false if the shortcut is already taken by something else.
    @discardableResult
    func register(_ s: Shortcut) -> Bool {
        unregister()
        let id = EventHotKeyID(signature: OSType(0x434C_5053), id: 1) // "CLPS"
        let status = RegisterEventHotKey(s.keyCode, s.modifiers, id,
                                         GetApplicationEventTarget(), 0, &ref)
        if status != noErr { ref = nil }
        return status == noErr
    }

    func unregister() {
        if let ref { UnregisterEventHotKey(ref) }
        ref = nil
    }
}
