import SwiftUI

/// The SwiftUI content of the floating panel: numbered page chips, the editor, and a footer.
struct ScratchView: View {
    @ObservedObject var store: PageStore
    var onHide: () -> Void
    var onDeleteRequest: () -> Void

    @AppStorage("fontSize") private var fontSize = 14.0
    @AppStorage("monospaced") private var monospaced = false
    @State private var copied = false

    var body: some View {
        VStack(spacing: 0) {
            tabStrip
            Divider().opacity(0.5)
            NoteEditor(text: Binding(get: { store.currentText }, set: { store.currentText = $0 }),
                       fontSize: fontSize, monospaced: monospaced, onEscape: onHide)
                .id(store.current.id)
            Divider().opacity(0.5)
            footer
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.separator, lineWidth: 0.5))
    }

    private var tabStrip: some View {
        HStack(spacing: 4) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(Array(store.pages.enumerated()), id: \.element.id) { index, page in
                        let selected = index == store.selectedIndex
                        Button { store.select(index) } label: {
                            Text("\(index + 1)")
                                .font(.system(size: 11, weight: selected ? .semibold : .regular).monospacedDigit())
                                .frame(minWidth: 18, minHeight: 18)
                                .background(Capsule().fill(selected ? Color.accentColor.opacity(0.85) : Color.primary.opacity(0.08)))
                                .foregroundStyle(selected ? Color.white : Color.primary)
                        }
                        .buttonStyle(.plain)
                        .help(page.title)
                        .accessibilityLabel("Page \(index + 1): \(page.title)")
                        .accessibilityAddTraits(selected ? .isSelected : [])
                    }
                }
                .padding(.horizontal, 8)
            }
            Button { store.addPage() } label: { Image(systemName: "plus") }
                .buttonStyle(.borderless)
                .disabled(!store.canAddPage)
                .help("New page (⌘T)")
                .accessibilityLabel("New page")
            Button(action: onDeleteRequest) { Image(systemName: "trash") }
                .buttonStyle(.borderless)
                .help("Delete page (⌘W)")
                .accessibilityLabel("Delete page")
                .padding(.trailing, 8)
        }
        .frame(height: 28)
    }

    private var footer: some View {
        let text = store.current.text
        let words = text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
        return HStack(spacing: 10) {
            Text("\(words) words · \(text.count) chars")
                .font(.system(size: 11).monospacedDigit())
                .foregroundStyle(.secondary)
                .accessibilityLabel("\(words) words, \(text.count) characters")
            if text.utf16.count > CalcTextView.evaluationLimit {
                Text("Math off (long page)").font(.system(size: 10)).foregroundStyle(.tertiary)
            }
            Spacer()
            Button {
                store.copyCurrent()
                copied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { copied = false }
            } label: { Image(systemName: copied ? "checkmark" : "doc.on.doc") }
                .buttonStyle(.borderless)
                .help("Copy page")
                .accessibilityLabel("Copy page to clipboard")
            Button { store.togglePin() } label: {
                Image(systemName: store.current.pinned ? "pin.fill" : "pin")
            }
                .buttonStyle(.borderless)
                .help(store.current.pinned ? "Unpin (stop floating above other windows)" : "Pin above other windows")
                .accessibilityLabel(store.current.pinned ? "Unpin page" : "Pin page")
        }
        .padding(.horizontal, 10)
        .frame(height: 26)
    }
}
