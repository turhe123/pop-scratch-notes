# PopScratchNotes

A hotkey scratchpad for throwaway notes that evaluates math inline and auto-saves every tab.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue)
![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange)
![License MIT](https://img.shields.io/badge/License-MIT-green)
![Release](https://img.shields.io/github/v/release/turhe123/pop-scratch-notes)

## Why

PopScratchNotes is a free, open-source, 100% native, backend-free alternative to paid utilities in the *Menu Bar Utility* category. It was inspired by Antinote ($5 one-time), and it aims at the same gap between the clipboard and a full notes app: press a hotkey, jot something down, get on with your day. There is no account, no server and no network access. Your notes stay in a JSON file on your Mac.

## Features

- **Global hotkey** (default `⌃⌥Space`) toggles a small floating panel. The shortcut is configurable in Settings and registered through Carbon `RegisterEventHotKey`. If another app already uses it, Settings shows a message.
- **Inline math**: end a line with `=` (for example `12 * (3 + 4) =`) and the result appears in a muted color to the right of the line. Supports `+ - * /`, `x`/`×`, `÷`, parentheses, decimals and a leading minus. Input is whitelisted and grammar-checked before it reaches `NSExpression`. Invalid input and division by zero show no result. Percent and units are not supported.
- **Up to 20 pages (tabs)**, shown as numbered chips. `⌘T` adds a page, `⌘W` deletes the current one (with a confirmation if it isn't empty), and `⌘1`–`⌘9` jump to a page.
- **Auto-save**: pages are written as JSON to `~/Library/Application Support/PopScratchNotes/pages.json` after a 0.5 s debounce, when the panel hides, and on quit. If the file can't be decoded, it is kept as `pages-corrupt-<timestamp>.json` and you start with a blank page.
- **Pin a page** so the panel floats above other windows; unpinned pages can optionally close when the panel loses focus.
- **Copy page** button puts the whole page on the pasteboard.
- **Footer** shows word and character counts. For pages over 200,000 characters, inline math is switched off to stay responsive, and the footer says so.
- **Menu bar item**: Show Scratchpad, New Page, a Pages submenu (titled by each page's first line), Settings…, Support / Donate ❤️, Quit.
- **Settings**: hotkey recorder, font size (11–22 pt), monospaced font toggle, panel opacity (30–100%), close-on-focus-loss, launch at login.
- **Escape** hides the panel without losing content, and the previously active app is brought back to the front.
- The panel is resizable and remembers its size and position. It follows the system light/dark appearance, and tabs and footer controls have VoiceOver labels.

## Screenshots

_Screenshots coming soon._

## Install

1. Download `PopScratchNotes-macOS.zip` from the [latest release](https://github.com/turhe123/pop-scratch-notes/releases/latest).
2. Unzip it and move `PopScratchNotes.app` to `/Applications`.
3. Because the app is open source and not notarized, remove the quarantine attribute:

   ```bash
   xattr -cr /Applications/PopScratchNotes.app
   ```

4. Right-click the app and choose **Open** the first time you launch it.

## Build from source

Requires macOS 14+ and Xcode with Swift 5.9 or newer.

```bash
brew install xcodegen
xcodegen generate
xcodebuild -project PopScratchNotes.xcodeproj -scheme PopScratchNotes -configuration Release -derivedDataPath ./build build
```

The app is produced at `build/Build/Products/Release/PopScratchNotes.app`.

## Permissions

PopScratchNotes asks for no privacy permissions. In particular, it does **not** request Accessibility, Screen Recording or Microphone access, and it makes no network connections.

- **Global hotkey**: uses Carbon `RegisterEventHotKey`, which needs no permission.
- **Launch at login** (optional): uses `SMAppService`. macOS may ask you to approve it under System Settings › General › Login Items.
- **Support / Donate button**: opens the Ko-fi page in your default browser.

## Support ❤️

PopScratchNotes is free and always will be. If it saves you some time, you can help keep the work going:

[Support Or (Leo) Davidai ❤️](https://ko-fi.com/leodavidai)

## License

MIT © Or Davidai Bachar
