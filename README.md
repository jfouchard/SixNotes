# SixNotes
**Don't use this, this is a hacky, incomplete, reimplementation of [Tot](https://tot.rocks/) written with Claude Code.  Go buy Tot, its awesome. *

A minimalist note-taking app for iOS and macOS that provides exactly six quick-access notes.

> **Warning: This is a test/experimental application. Do not use it for anything important. Data loss may occur at any time without warning. There are no guarantees of data persistence, stability, or reliability.**

## What It Does

SixNotes takes a deliberately constrained approach to note-taking: instead of managing an ever-growing collection of notes, you have exactly six note slots available at all times. This makes it ideal for quick thoughts, temporary information, or scratchpad use.

### Features

- **Six persistent notes** - Quick access via visual dot indicators
- **Cross-platform** - Runs on both iOS and macOS
- **Auto-save** - Notes are saved automatically as you type
- **Markdown preview** (macOS) - Toggle a preview pane for formatted markdown

### Platform Differences

**iOS:**
- Swipeable interface between notes
- Touch-friendly tab bar with content indicators

**macOS:**
- Markdown preview window (Cmd+P)
- Window position remembered between sessions

## Important Disclaimer

**This is a test application only.**

- Data may be lost at any time
- There are no backups or sync features
- The app may contain bugs or unexpected behavior
- No guarantees of any kind are provided
- **Do not store anything important in this app**

Use at your own risk. This project exists purely for experimental and learning purposes.

## Technical Details

- Built with SwiftUI
- Data stored locally in UserDefaults
- No cloud sync or external data storage
