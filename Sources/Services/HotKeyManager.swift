import AppKit
import Carbon

/// Registers a single system-wide hotkey through Carbon's RegisterEventHotKey (no permissions needed).
final class HotKeyManager {
    static let shared = HotKeyManager()

    static let keyCodeKey = "hotKeyCode"
    static let modifiersKey = "hotKeyModifiers"
    /// Default: ⌃⌥Space.
    static let defaultKeyCode = UInt32(kVK_Space)
    static let defaultModifiers = UInt32(controlKey | optionKey)

    var onPress: (() -> Void)?
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    private init() {}

    /// Registers the stored (or default) hotkey. Returns an error message on conflict.
    @discardableResult
    func registerStored() -> String? {
        let defaults = UserDefaults.standard
        let code = defaults.object(forKey: Self.keyCodeKey) as? Int ?? Int(Self.defaultKeyCode)
        let mods = defaults.object(forKey: Self.modifiersKey) as? Int ?? Int(Self.defaultModifiers)
        return register(keyCode: UInt32(code), modifiers: UInt32(mods))
    }

    /// Replaces the current hotkey. Returns a human-readable message if registration failed.
    func register(keyCode: UInt32, modifiers: UInt32) -> String? {
        installHandlerIfNeeded()
        if let ref = hotKeyRef { UnregisterEventHotKey(ref); hotKeyRef = nil }
        let id = EventHotKeyID(signature: OSType(0x5053_4E54), id: 1) // 'PSNT'
        let status = RegisterEventHotKey(keyCode, modifiers, id, GetApplicationEventTarget(), 0, &hotKeyRef)
        if status == noErr { return nil }
        hotKeyRef = nil
        if status == OSStatus(eventHotKeyExistsErr) {
            return "That shortcut is already used by another app. Please choose a different one."
        }
        return "Could not register the shortcut (error \(status))."
    }

    private func installHandlerIfNeeded() {
        guard handlerRef == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            DispatchQueue.main.async { HotKeyManager.shared.onPress?() }
            return noErr
        }, 1, &spec, nil, &handlerRef)
    }

    /// Converts AppKit modifier flags into Carbon modifier bits.
    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var result: UInt32 = 0
        if flags.contains(.command) { result |= UInt32(cmdKey) }
        if flags.contains(.option) { result |= UInt32(optionKey) }
        if flags.contains(.control) { result |= UInt32(controlKey) }
        if flags.contains(.shift) { result |= UInt32(shiftKey) }
        return result
    }

    /// Human-readable description such as "⌃⌥Space".
    static func describe(keyCode: UInt32, modifiers: UInt32) -> String {
        var s = ""
        if modifiers & UInt32(controlKey) != 0 { s += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { s += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { s += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { s += "⌘" }
        let names: [Int: String] = [kVK_Space: "Space", kVK_Return: "↩", kVK_Tab: "⇥", kVK_Escape: "⎋",
                                    kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6"]
        if let name = names[Int(keyCode)] { return s + name }
        return s + (keyName(for: keyCode) ?? "Key \(keyCode)")
    }

    /// Resolves a virtual key code to its character in the current keyboard layout.
    private static func keyName(for keyCode: UInt32) -> String? {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let ptr = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else { return nil }
        let data = Unmanaged<CFData>.fromOpaque(ptr).takeUnretainedValue() as Data
        var deadKeys: UInt32 = 0
        var chars = [UniChar](repeating: 0, count: 4)
        var length = 0
        let status = data.withUnsafeBytes { raw -> OSStatus in
            guard let layout = raw.bindMemory(to: UCKeyboardLayout.self).baseAddress else { return -1 }
            return UCKeyTranslate(layout, UInt16(keyCode), UInt16(kUCKeyActionDisplay), 0, UInt32(LMGetKbdType()),
                                  OptionBits(kUCKeyTranslateNoDeadKeysBit), &deadKeys, 4, &length, &chars)
        }
        guard status == noErr, length > 0 else { return nil }
        return String(utf16CodeUnits: chars, count: length).uppercased()
    }
}
