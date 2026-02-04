# SixNotes

**Don't use this, this is a hacky, incomplete, reimplementation of [Tot](https://tot.rocks/) written with Claude Code. Go buy Tot, it's awesome.**

A minimalist note-taking app for iOS and macOS that provides exactly six quick-access notes.

> **Warning: This is a test/experimental application. Do not use it for anything important. Data loss may occur at any time without warning. There are no guarantees of data persistence, stability, or reliability.**

## What It Does

SixNotes takes a deliberately constrained approach to note-taking: instead of managing an ever-growing collection of notes, you have exactly six note slots available at all times. This makes it ideal for quick thoughts, temporary information, or scratchpad use.

### Features

- **Six persistent notes** - Quick access via color-coded dot indicators
- **Cross-platform** - Native apps for iOS and macOS
- **Auto-save** - Notes are saved automatically as you type
- **Rich text editing** - Bold, italic, headers, lists, and code blocks via markdown syntax
- **Plain text mode** - Toggle per-note to disable rich text formatting
- **iCloud sync** (optional) - Sync notes across devices via CloudKit
- **Customizable fonts** - Choose text and code fonts with adjustable sizes

### Platform Differences

**iOS:**
- Tap dot indicators to switch between notes
- Drag-to-reveal formatting toolbar
- Share notes via system share sheet

**macOS:**
- Keyboard shortcuts for quick note switching (Cmd+1 through Cmd+6)
- Markdown preview window (Cmd+P)
- Toggle plain text mode (Cmd+Shift+T)
- Window position remembered between sessions
- Settings via Preferences (Cmd+,)

## Important Disclaimer

**This is a test application only.**

- Data may be lost at any time
- iCloud sync is experimental and may have issues
- The app may contain bugs or unexpected behavior
- No guarantees of any kind are provided
- **Do not store anything important in this app**

Use at your own risk. This project exists purely for experimental and learning purposes.

## Technical Details

- Built with SwiftUI
- Data stored locally in UserDefaults
- Optional CloudKit sync to iCloud private database
- iOS 16.0+ / macOS 13.0+
