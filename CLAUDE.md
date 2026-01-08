# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SixNotes is a minimalist cross-platform (iOS and macOS) note-taking app built with SwiftUI. It provides exactly six persistent note slots with quick visual access via dot indicators. Data is stored locally using UserDefaults.

**Important:** This is an experimental app - see README.md disclaimer about potential data loss.

## Build Commands

### iOS
```bash
xcodebuild -project iOS/SixNotes.xcodeproj -scheme SixNotes build
```

### macOS
```bash
xcodebuild -project macOS/SixNotes.xcodeproj -scheme SixNotes build
```

Or using Swift Package Manager:
```bash
cd macOS && swift build
```

## Architecture

**Pattern:** MVVM with SwiftUI reactive state management

**Data Flow:**
1. `SixNotesApp` creates `NotesManager` as `@StateObject`
2. `NotesManager` loads/saves data from UserDefaults
3. Views observe `NotesManager` via `@EnvironmentObject`
4. Text edits trigger binding callbacks → `NotesManager.save()` → UserDefaults

**Key Components:**
- `NotesManager`: Central state coordinator handling persistence and font settings
- `Note`: Data model (id, content, lastModified, cursorPosition)
- `FontSetting`: Codable font configuration for text/code fonts

**Platform Differences:**
| Feature | iOS | macOS |
|---------|-----|-------|
| Navigation | TabView with swipe | Window with title bar dots |
| Text Editor | SwiftUI TextEditor | NSTextView wrapped in NSViewRepresentable |
| Markdown Preview | None | Separate window (Cmd+P) |
| Keyboard Shortcuts | None | Cmd+1-6 (notes), Cmd+P (preview), Cmd+, (settings) |

## Code Structure

```
iOS/SixNotes/
├── App/SixNotesApp.swift      # Entry point
├── Managers/NotesManager.swift # State management
├── Models/                     # Note.swift, FontSetting.swift
└── Views/                      # MainTabView, NoteEditorView, SettingsView

macOS/SixNotes/
├── SixNotesApp.swift          # Entry point + AppDelegate
├── ContentView.swift          # Main UI + preview controller
├── MarkdownPreviewView.swift  # Markdown rendering engine
└── NotesManager.swift         # State + models (combined file)
```

## UserDefaults Keys

- `SixNotes.notes`: JSON-encoded array of Note objects
- `SixNotes.selectedNote`: Index of currently selected note
- `SixNotes.textFont`: Text font settings
- `SixNotes.codeFont`: Code font settings

## Deployment Targets

- iOS: 16.0+
- macOS: 13.0+
- Swift: 5.0
