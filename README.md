# TermMD

A native macOS app that pairs a Markdown editor with an embedded terminal running [Claude Code](https://claude.ai/claude-code) — so you can write, edit, and have Claude modify your files without leaving the app.

![macOS](https://img.shields.io/badge/macOS-13.0+-blue) ![Swift](https://img.shields.io/badge/Swift-5.9-orange) ![License](https://img.shields.io/badge/license-MIT-green)

## What is this?

TermMD is a split-pane editor designed for a specific workflow:

1. **Left pane**: A full PTY terminal (powered by [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm))
2. **Right pane**: A Markdown editor with line numbers

The magic happens when you select text in the editor and right-click **"Send to Claude"** — it injects a natural-language prompt into the terminal with your file path, line numbers, and selected code. Claude Code can then read and edit your file directly.

## Features

- **Integrated Terminal**: Real PTY-backed shell (zsh by default) with full keyboard support
- **Markdown Editor**: Monospaced text editing with line number gutter
- **Send to Claude**: Select text → right-click → send context to Claude Code CLI
- **Auto-start Claude**: Opening a file automatically starts Claude Code in that directory
- **File Watching**: Detects external file changes (like when Claude edits your file) and auto-reloads
- **Conflict Resolution**: If you have unsaved changes when the file changes on disk, shows a banner to Reload or Ignore

## Keyboard Shortcuts

| Action | Shortcut |
|--------|----------|
| New File | ⌘N |
| Open File | ⌘O |
| Save | ⌘S |
| Save As | ⇧⌘S |
| Run Claude | ⌃⌘R |
| Send to Claude (with line refs) | ⇧⌘↩ |
| Focus Terminal | ⌘1 |
| Focus Editor | ⌘2 |
| Settings | ⌘, |

## Requirements

- macOS 13.0 or later
- [Claude Code CLI](https://claude.ai/claude-code) installed and available in your PATH
- Xcode 15+ (for building from source)

## Building from Source

```bash
git clone https://github.com/mchtab/TermMD.git
cd TermMD
xcodebuild -scheme TermMD -configuration Release build
```

The built app will be in `DerivedData/TermMD-*/Build/Products/Release/TermMD.app`

Or open `TermMD.xcodeproj` in Xcode and build directly.

## How "Send to Claude" Works

When you select text and use "Send to Claude (with line refs)", TermMD:

1. Auto-saves your file (if enabled in settings)
2. Builds a prompt like:
   ```
   I am working on the file: /path/to/your/file.md
   
   The selected text at lines 5-10 is:
   
   ```
   your selected code here
   ```
   
   Please read this file first, then make the following change: 
   ```
3. Injects this into the terminal as input to Claude Code
4. Focuses the terminal so you can type your change request

Claude Code then reads the file, understands the context, and can edit it directly on disk. TermMD detects the change and reloads automatically.

## Settings

Access via ⌘, or the gear icon:

- **Claude Command**: The CLI command to run (default: `claude`)
- **Shell Path**: Which shell to use in the terminal (default: `/bin/zsh`)
- **Auto-save before Send**: Automatically save before sending context to Claude (default: ON)

## Why TermMD?

If you use Claude Code CLI to edit files, you typically:
1. Open a file in your editor
2. Switch to terminal, run `claude`
3. Copy-paste file paths and code snippets
4. Switch back to editor to see changes

TermMD eliminates this context-switching. Everything is in one window, and the "Send to Claude" feature handles the prompt engineering for you.

## Tech Stack

- **SwiftUI** with AppKit bridging for the editor (NSTextView) and terminal
- **[SwiftTerm](https://github.com/migueldeicaza/SwiftTerm)** for the PTY terminal emulator
- **CryptoKit** for SHA-256 file change detection

## License

MIT

## Credits

Built with [Claude Code](https://claude.ai/claude-code) — yes, this app was largely written by Claude itself.
