import AppKit
import Combine

/// A single scratch page (tab) in the panel.
struct Page: Codable, Identifiable, Equatable {
    var id = UUID()
    var text = ""
    var pinned = false

    /// Title used in menus: the first non-empty line, truncated.
    var title: String {
        let first = text.split(whereSeparator: \.isNewline).first.map(String.init)?
            .trimmingCharacters(in: .whitespaces) ?? ""
        if first.isEmpty { return "Empty page" }
        return first.count > 40 ? String(first.prefix(40)) + "…" : first
    }
}

/// Owns all pages, the selected page, and debounced JSON persistence in Application Support.
final class PageStore: ObservableObject {
    static let shared = PageStore()
    static let maxPages = 20

    @Published var pages: [Page] = [Page()] { didSet { scheduleSave() } }
    @Published var selectedIndex = 0

    private var saveWork: DispatchWorkItem?
    private let fileURL: URL

    private init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("PopScratchNotes", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("pages.json")
        load()
    }

    var current: Page { pages[safeIndex] }
    private var safeIndex: Int { min(max(selectedIndex, 0), pages.count - 1) }

    /// Binding-friendly accessor for the current page's text.
    var currentText: String {
        get { current.text }
        set { if pages[safeIndex].text != newValue { pages[safeIndex].text = newValue } }
    }

    var canAddPage: Bool { pages.count < Self.maxPages }

    func addPage() {
        guard canAddPage else { NSSound.beep(); return }
        pages.append(Page())
        selectedIndex = pages.count - 1
    }

    /// Removes the current page; the last remaining page is cleared instead.
    func deleteCurrentPage() {
        if pages.count == 1 {
            pages[0] = Page()
        } else {
            pages.remove(at: safeIndex)
            selectedIndex = min(safeIndex, pages.count - 1)
        }
    }

    func togglePin() { pages[safeIndex].pinned.toggle() }

    func select(_ index: Int) {
        guard pages.indices.contains(index) else { return }
        selectedIndex = index
    }

    func copyCurrent() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(current.text, forType: .string)
    }

    // MARK: Persistence

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        do {
            let decoded = try JSONDecoder().decode([Page].self, from: data)
            if !decoded.isEmpty { pages = Array(decoded.prefix(Self.maxPages)) }
        } catch {
            // Keep the unreadable file for manual recovery and start fresh.
            let stamp = Int(Date().timeIntervalSince1970)
            let backup = fileURL.deletingLastPathComponent().appendingPathComponent("pages-corrupt-\(stamp).json")
            try? FileManager.default.moveItem(at: fileURL, to: backup)
            pages = [Page()]
        }
        saveWork?.cancel()
    }

    private func scheduleSave() {
        saveWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.saveNow() }
        saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    /// Writes immediately (used on termination and by the debounce).
    func saveNow() {
        saveWork?.cancel()
        saveWork = nil
        guard let data = try? JSONEncoder().encode(pages) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
