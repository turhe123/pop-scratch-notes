import AppKit
import Combine
import SwiftUI

/// Borderless, non-activating floating panel that can still become key so typing works.
final class ScratchPanel: NSPanel {
    var keyHandler: ((NSEvent) -> Bool)?

    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 380, height: 300),
                   styleMask: [.borderless, .nonactivatingPanel, .resizable, .fullSizeContentView],
                   backing: .buffered, defer: false)
        isFloatingPanel = true
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        minSize = NSSize(width: 260, height: 180)
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        setAccessibilityLabel("PopScratchNotes scratchpad")
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if keyHandler?(event) == true { return true }
        return super.performKeyEquivalent(with: event)
    }
}

/// Shows/hides the panel, handles keyboard shortcuts, pinning, focus loss, and frame persistence.
final class PanelController: NSObject, NSWindowDelegate {
    static let shared = PanelController()

    private let store = PageStore.shared
    private lazy var panel: ScratchPanel = makePanel()
    private var previousApp: NSRunningApplication?
    private var presentingAlert = false
    private var cancellables = Set<AnyCancellable>()
    private let frameKey = "panelFrame"

    var isVisible: Bool { panel.isVisible }

    func toggle() { isVisible && panel.isKeyWindow ? hide() : show() }

    func show() {
        if let front = NSWorkspace.shared.frontmostApplication, front != NSRunningApplication.current {
            previousApp = front
        }
        applyAppearanceSettings()
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    func hide() {
        guard panel.isVisible else { return }
        panel.orderOut(nil)
        store.saveNow()
        previousApp?.activate()
        previousApp = nil
    }

    func newPage() { store.addPage(); show() }

    func showPage(_ index: Int) { store.select(index); show() }

    /// Re-reads opacity and pin state; called on show and whenever settings change.
    func applyAppearanceSettings() {
        let opacity = UserDefaults.standard.object(forKey: "panelOpacity") as? Double ?? 1.0
        panel.alphaValue = CGFloat(min(max(opacity, 0.3), 1.0))
        panel.level = store.current.pinned ? .floating : .normal
    }

    /// Asks before deleting a non-empty page.
    func confirmDelete() {
        guard !store.current.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            store.deleteCurrentPage(); return
        }
        let alert = NSAlert()
        alert.messageText = "Delete this page?"
        alert.informativeText = "“\(store.current.title)” will be removed. This can’t be undone."
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        alert.buttons.first?.hasDestructiveAction = true
        presentingAlert = true
        let response = alert.runModal()
        presentingAlert = false
        if response == .alertFirstButtonReturn { store.deleteCurrentPage() }
        panel.makeKeyAndOrderFront(nil)
    }

    private func makePanel() -> ScratchPanel {
        let panel = ScratchPanel()
        let root = ScratchView(store: store, onHide: { [weak self] in self?.hide() },
                               onDeleteRequest: { [weak self] in self?.confirmDelete() })
        let hosting = NSHostingView(rootView: root)
        hosting.autoresizingMask = [.width, .height]
        panel.contentView = hosting
        panel.delegate = self
        panel.keyHandler = { [weak self] in self?.handleKey($0) ?? false }
        if let saved = UserDefaults.standard.string(forKey: frameKey) {
            let frame = NSRectFromString(saved)
            if frame.width >= 260, frame.height >= 180,
               NSScreen.screens.contains(where: { $0.visibleFrame.intersects(frame) }) {
                panel.setFrame(frame, display: false)
            } else { panel.center() }
        } else { panel.center() }
        store.$pages.combineLatest(store.$selectedIndex)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.applyAppearanceSettings() }
            .store(in: &cancellables)
        return panel
    }

    /// Panel-level shortcuts. Edit shortcuts are routed explicitly because accessory apps lack an Edit menu.
    private func handleKey(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard flags.contains(.command), let key = event.charactersIgnoringModifiers?.lowercased() else { return false }
        let shift = flags.contains(.shift)
        func send(_ action: String) -> Bool { NSApp.sendAction(Selector(action), to: nil, from: panel) }
        switch key {
        case "t": store.addPage(); return true
        case "w": confirmDelete(); return true
        case "x": return send("cut:")
        case "c": return send("copy:")
        case "v": return send("paste:")
        case "a": return send("selectAll:")
        case "z": return send(shift ? "redo:" : "undo:")
        case ",": NotificationCenter.default.post(name: .openSettingsRequest, object: nil); return true
        default:
            if let n = Int(key), (1...9).contains(n) { store.select(n - 1); return true }
            return false
        }
    }

    // MARK: NSWindowDelegate

    func windowDidResignKey(_ notification: Notification) {
        guard !presentingAlert, panel.isVisible, !store.current.pinned,
              UserDefaults.standard.bool(forKey: "closeOnFocusLoss") else { return }
        panel.orderOut(nil)
        store.saveNow()
        previousApp = nil
    }

    func windowDidMove(_ notification: Notification) { saveFrame() }
    func windowDidResize(_ notification: Notification) { saveFrame() }

    private func saveFrame() {
        UserDefaults.standard.set(NSStringFromRect(panel.frame), forKey: frameKey)
    }
}

extension Notification.Name {
    static let openSettingsRequest = Notification.Name("PopScratchNotesOpenSettings")
}
