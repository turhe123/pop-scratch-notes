import AppKit
import SwiftUI

/// NSTextView subclass that draws calculation results to the right of lines ending in "="
/// and a placeholder when empty.
final class CalcTextView: NSTextView {
    static let evaluationLimit = 200_000
    var onEscape: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { onEscape?(); return }
        super.keyDown(with: event)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let layoutManager, let textContainer else { return }
        let baseFont = font ?? NSFont.systemFont(ofSize: 13)
        let origin = textContainerOrigin

        if string.isEmpty {
            let attrs: [NSAttributedString.Key: Any] = [.font: baseFont, .foregroundColor: NSColor.placeholderTextColor]
            let x = origin.x + textContainer.lineFragmentPadding
            ("Start typing, end a line with = to calculate" as NSString).draw(at: NSPoint(x: x, y: origin.y), withAttributes: attrs)
            return
        }
        let text = string as NSString
        guard text.length <= Self.evaluationLimit else { return }

        let attrs: [NSAttributedString.Key: Any] = [.font: baseFont, .foregroundColor: NSColor.secondaryLabelColor]
        let visibleGlyphs = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)
        let visibleChars = layoutManager.characterRange(forGlyphRange: visibleGlyphs, actualGlyphRange: nil)
        let scanRange = text.lineRange(for: visibleChars)

        text.enumerateSubstrings(in: scanRange, options: [.byLines]) { line, lineRange, _, _ in
            guard let line, line.contains("="),
                  let result = Calculator.result(for: line), lineRange.length > 0 else { return }
            let lastGlyph = layoutManager.glyphIndexForCharacter(at: NSMaxRange(lineRange) - 1)
            let fragment = layoutManager.lineFragmentUsedRect(forGlyphAt: lastGlyph, effectiveRange: nil)
            let label = " \(result)" as NSString
            let point = NSPoint(x: fragment.maxX + origin.x + 4, y: fragment.minY + origin.y)
            label.draw(at: point, withAttributes: attrs)
        }
    }

    override func didChangeText() {
        super.didChangeText()
        needsDisplay = true
    }
}

/// SwiftUI wrapper around a scrollable CalcTextView bound to the current page text.
struct NoteEditor: NSViewRepresentable {
    @Binding var text: String
    var fontSize: Double
    var monospaced: Bool
    var onEscape: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = CalcTextView.scrollableTextView()
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        let textView = CalcTextView(frame: scroll.contentView.bounds)
        textView.autoresizingMask = [.width]
        textView.isVerticallyResizable = true
        textView.textContainer?.widthTracksTextView = true
        textView.drawsBackground = false
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.textContainerInset = NSSize(width: 6, height: 8)
        textView.delegate = context.coordinator
        textView.setAccessibilityLabel("Scratch page text")
        scroll.documentView = textView
        apply(to: textView)
        textView.string = text
        DispatchQueue.main.async { textView.window?.makeFirstResponder(textView) }
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let textView = scroll.documentView as? CalcTextView else { return }
        apply(to: textView)
        if textView.string != text {
            textView.string = text
            textView.undoManager?.removeAllActions()
            textView.setSelectedRange(NSRange(location: (text as NSString).length, length: 0))
        }
        textView.needsDisplay = true
    }

    private func apply(to textView: CalcTextView) {
        let size = CGFloat(fontSize)
        let font = monospaced ? NSFont.monospacedSystemFont(ofSize: size, weight: .regular) : NSFont.systemFont(ofSize: size)
        if textView.font != font {
            textView.font = font
            textView.typingAttributes = [.font: font, .foregroundColor: NSColor.textColor]
        }
        textView.textColor = .textColor
        textView.onEscape = onEscape
    }

    /// Pushes edits from the text view back into the model.
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: NoteEditor
        init(_ parent: NoteEditor) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }
    }
}
