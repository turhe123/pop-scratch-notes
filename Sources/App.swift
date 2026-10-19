import AppKit
import SwiftUI

/// App entry point: a menu bar extra that drives the floating scratchpad panel.
@main
struct PopScratchNotesApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @ObservedObject private var store = PageStore.shared

    var body: some Scene {
        MenuBarExtra("PopScratchNotes", systemImage: "note.text") {
            Button("Show Scratchpad") { PanelController.shared.show() }
            Button("New Page") { PanelController.shared.newPage() }
                .disabled(!store.canAddPage)
            Menu("Pages") {
                ForEach(Array(store.pages.enumerated()), id: \.element.id) { index, page in
                    Button("\(index + 1). \(page.title)\(page.pinned ? " 📌" : "")") {
                        PanelController.shared.showPage(index)
                    }
                }
            }
            Divider()
            Button("Settings…") { SettingsWindowController.shared.show() }
            Button("Support / Donate ❤️") {
                if let url = URL(string: "https://ko-fi.com/leodavidai") { NSWorkspace.shared.open(url) }
            }
            Divider()
            Button("Quit PopScratchNotes") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
        }
    }
}

/// Registers the global hotkey at launch and flushes pages to disk on quit.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        HotKeyManager.shared.onPress = { PanelController.shared.toggle() }
        HotKeyManager.shared.registerStored()
        NotificationCenter.default.addObserver(forName: .openSettingsRequest, object: nil, queue: .main) { _ in
            SettingsWindowController.shared.show()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        PageStore.shared.saveNow()
    }
}
