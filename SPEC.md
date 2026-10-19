# PopScratchNotes — specification

**Tagline:** A hotkey scratchpad for throwaway notes that evaluates math inline and auto-saves every tab.

**Category:** Menu Bar Utility

**Inspired by (paid):** Antinote ($5 one-time)

**Frameworks:** SwiftUI, AppKit, Carbon, ServiceManagement, Foundation

**Donation URL (Support button):** https://ko-fi.com/leodavidai

## Spec

What the paid app does and evidence of demand. Antinote is a minimal Mac scratchpad that appears with a hotkey, accepts quick text, and has built-in calculation. The developer's site lists it at 5 dollars one-time with lifetime updates and macOS 14 support, it is also distributed through Setapp, and reviews on Mac4Ever and Yahoo Tech highlight how fast and unobtrusive it feels. It fills the gap between the clipboard and a full notes app, so it fits well beside clipboard and snippet tools. Our clean-room version, PopScratchNotes, uses original design and code.

Feature set. A global hotkey toggles a small floating note panel. The panel contains a plain text editor with auto-save and up to 20 tabs called pages, with Command plus T creating a new page and Command plus W deleting the current one after confirmation if it is not empty. Lines that look like arithmetic expressions, for example a line ending with an equals sign, get their result appended in a muted color to the right, using a safe expression evaluator built on NSExpression with a whitelist check so only digits, operators, parentheses, and decimal points are accepted. Percent and common unit words are out of scope. Pages can be pinned so the panel stays above other windows, and a copy page button puts all text on the pasteboard. A trailing word and character count appears in the footer.

UI spec. The app is a MenuBarExtra. The menu offers Show Scratchpad, New Page, Pages submenu listing titles taken from each page's first line, Settings, and Quit. The floating panel is a borderless NSPanel about 380 by 300 points that remembers its size and position per launch, with a thin tab strip at top using small numbered chips, the text editor in the middle, and a footer with counts and a pin toggle. Empty state for a new page shows placeholder text reading Start typing, end a line with equals to calculate. Settings fields: global hotkey recorder, font size slider from 11 to 22, monospaced font toggle, panel opacity slider, Close panel when it loses focus toggle, and Launch at login. Pressing Escape hides the panel without losing content.

Technical approach. Build the panel as an NSPanel subclass hosting a SwiftUI view via NSHostingView, with the nonactivating panel style and canBecomeKey overridden to true so typing works. Register the hotkey with Carbon RegisterEventHotKey, requiring no permissions. Use TextEditor bound to a model and apply the inline results by computing them per line and drawing them in an overlay column, or alternatively wrap NSTextView through NSViewRepresentable and use text attributes, which gives better alignment. Evaluate expressions by sanitizing the line, replacing a trailing equals sign, and using NSExpression with a format string inside a try block, rejecting anything that throws. Store pages as a JSON array in Application Support, writing after a 0.5 second debounce and on app termination. Use AppStorage for preferences and SMAppService.mainApp for launch at login.

Edge cases and error handling. Division by zero and invalid expressions show no result rather than an error. Very long pages of over 200 thousand characters disable inline evaluation to stay responsive. If the saved JSON cannot be decoded, keep a backup copy and start with a blank page. If the hotkey conflicts, display a message in settings. Restore the previously active app when the panel hides. Make sure the app remains usable with VoiceOver by labeling tabs and the footer controls, and respect the system light and dark appearance.
