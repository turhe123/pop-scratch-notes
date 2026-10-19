import AppKit
import ServiceManagement
import SwiftUI

/// Preferences: hotkey, font, opacity, focus behaviour, launch at login, and support link.
struct SettingsView: View {
    @AppStorage("fontSize") private var fontSize = 14.0
    @AppStorage("monospaced") private var monospaced = false
    @AppStorage("panelOpacity") private var panelOpacity = 1.0
    @AppStorage("closeOnFocusLoss") private var closeOnFocusLoss = false
    @AppStorage(HotKeyManager.keyCodeKey) private var keyCode = Int(HotKeyManager.defaultKeyCode)
    @AppStorage(HotKeyManager.modifiersKey) private var modifiers = Int(HotKeyManager.defaultModifiers)

    @State private var recording = false
    @State private var monitor: Any?
    @State private var hotKeyMessage: String?
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginMessage: String?

    var body: some View {
        Form {
            Section("Shortcut") {
                LabeledContent("Show / hide scratchpad") {
                    Button(recording ? "Press keys… (Esc to cancel)" :
                            HotKeyManager.describe(keyCode: UInt32(keyCode), modifiers: UInt32(modifiers))) {
                        recording ? stopRecording() : startRecording()
                    }
                    .accessibilityLabel("Global shortcut, currently \(HotKeyManager.describe(keyCode: UInt32(keyCode), modifiers: UInt32(modifiers)))")
                }
                if let hotKeyMessage {
                    Text(hotKeyMessage).font(.caption).foregroundStyle(.red)
                }
            }
            Section("Editor") {
                LabeledContent("Font size: \(Int(fontSize)) pt") {
                    Slider(value: $fontSize, in: 11...22, step: 1).frame(width: 180)
                }
                Toggle("Monospaced font", isOn: $monospaced)
            }
            Section("Panel") {
                LabeledContent("Opacity: \(Int(panelOpacity * 100))%") {
                    Slider(value: $panelOpacity, in: 0.3...1.0).frame(width: 180)
                }
                .onChange(of: panelOpacity) { PanelController.shared.applyAppearanceSettings() }
                Toggle("Close panel when it loses focus", isOn: $closeOnFocusLoss)
                Text("Pinned pages always stay visible above other windows.").font(.caption).foregroundStyle(.secondary)
            }
            Section("General") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { setLaunchAtLogin(launchAtLogin) }
                if let loginMessage {
                    Text(loginMessage).font(.caption).foregroundStyle(.secondary)
                }
            }
            Section {
                HStack {
                    Button("Support / Donate ❤️") {
                        if let url = URL(string: "https://ko-fi.com/leodavidai") { NSWorkspace.shared.open(url) }
                    }
                    Spacer()
                    Text("PopScratchNotes \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .fixedSize(horizontal: false, vertical: true)
        .onDisappear { stopRecording() }
    }

    private func startRecording() {
        recording = true
        hotKeyMessage = nil
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { stopRecording(); return nil }
            let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
            guard !flags.intersection([.command, .option, .control]).isEmpty else {
                hotKeyMessage = "Include at least one of ⌘, ⌥ or ⌃."
                return nil
            }
            let newCode = UInt32(event.keyCode)
            let newMods = HotKeyManager.carbonModifiers(from: flags)
            if let error = HotKeyManager.shared.register(keyCode: newCode, modifiers: newMods) {
                hotKeyMessage = error
                HotKeyManager.shared.registerStored()
            } else {
                keyCode = Int(newCode)
                modifiers = Int(newMods)
            }
            stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        recording = false
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            loginMessage = SMAppService.mainApp.status == .requiresApproval
                ? "Approve PopScratchNotes in System Settings › General › Login Items." : nil
        } catch {
            loginMessage = "Couldn’t update login item: \(error.localizedDescription)"
        }
    }
}

/// Hosts SettingsView in a regular AppKit window (reliable for menu-bar-only apps).
final class SettingsWindowController {
    static let shared = SettingsWindowController()
    private var window: NSWindow?

    func show() {
        if window == nil {
            let hosting = NSHostingController(rootView: SettingsView())
            let win = NSWindow(contentViewController: hosting)
            win.title = "PopScratchNotes Settings"
            win.styleMask = [.titled, .closable]
            win.isReleasedWhenClosed = false
            win.center()
            window = win
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
