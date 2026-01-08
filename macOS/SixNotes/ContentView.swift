import SwiftUI

struct ContentView: View {
    @EnvironmentObject var notesManager: NotesManager
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 0) {
            // Title bar area
            HStack {
                Spacer()

                // 6 dots centered
                HStack(spacing: 12) {
                    ForEach(0..<6, id: \.self) { index in
                        NoteDot(
                            index: index,
                            isSelected: notesManager.selectedNoteIndex == index,
                            hasContent: notesManager.hasContent(at: index)
                        )
                        .onTapGesture {
                            notesManager.selectNote(index)
                        }
                    }
                }

                Spacer()
            }
            .frame(height: 28)

            // Note editor
            NoteEditorView()
                .environmentObject(notesManager)
        }
        .frame(minWidth: 400, minHeight: 300)
        .background(Color(NSColor.windowBackgroundColor))
        .ignoresSafeArea()
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(notesManager)
        }
        .onReceive(NotificationCenter.default.publisher(for: .showSettings)) { _ in
            showSettings = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .togglePreview)) { _ in
            PreviewWindowController.shared.toggle(notesManager: notesManager)
        }
    }
}

// Preview window controller
class PreviewWindowController {
    static let shared = PreviewWindowController()
    private var previewWindow: NSWindow?

    func toggle(notesManager: NotesManager) {
        if let window = previewWindow, window.isVisible {
            window.close()
            previewWindow = nil
        } else {
            openPreview(notesManager: notesManager)
        }
    }

    func openPreview(notesManager: NotesManager) {
        let previewView = PreviewWindowContent()
            .environmentObject(notesManager)

        let hostingView = NSHostingView(rootView: previewView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        window.contentView = hostingView
        window.title = "Markdown Preview"
        window.setFrameAutosaveName("SixNotesPreviewWindow")
        window.isReleasedWhenClosed = false

        // Position next to main window
        if let mainWindow = NSApplication.shared.windows.first {
            let mainFrame = mainWindow.frame
            window.setFrameOrigin(NSPoint(x: mainFrame.maxX + 20, y: mainFrame.minY))
        }

        window.orderFront(nil)
        previewWindow = window
    }
}

struct PreviewWindowContent: View {
    @EnvironmentObject var notesManager: NotesManager

    var body: some View {
        MarkdownPreviewView(content: notesManager.notes[notesManager.selectedNoteIndex].content)
            .environmentObject(notesManager)
            .frame(minWidth: 300, minHeight: 200)
    }
}

struct NoteDot: View {
    let index: Int
    let isSelected: Bool
    let hasContent: Bool

    static let noteColors: [Color] = [
        Color(red: 0.90, green: 0.30, blue: 0.35),  // Red
        Color(red: 0.95, green: 0.55, blue: 0.25),  // Orange
        Color(red: 0.95, green: 0.75, blue: 0.25),  // Yellow
        Color(red: 0.40, green: 0.78, blue: 0.45),  // Green
        Color(red: 0.35, green: 0.60, blue: 0.90),  // Blue
        Color(red: 0.70, green: 0.45, blue: 0.85),  // Purple
    ]

    var noteColor: Color {
        NoteDot.noteColors[index]
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(isSelected ? noteColor : (hasContent ? noteColor.opacity(0.6) : noteColor.opacity(0.2)))
                .frame(width: 10, height: 10)

            if isSelected {
                Circle()
                    .stroke(noteColor.opacity(0.4), lineWidth: 2)
                    .frame(width: 16, height: 16)
            }
        }
        .frame(width: 20, height: 20)
        .contentShape(Rectangle())
    }
}

struct NoteEditorView: View {
    @EnvironmentObject var notesManager: NotesManager

    var body: some View {
        NoteTextEditor(
            text: notesManager.currentNote,
            font: notesManager.textFont.nsFont,
            cursorPosition: notesManager.getCursorPosition(),
            onCursorChange: { position in
                notesManager.saveCursorPosition(position)
            }
        )
        .padding(16)
        .id(notesManager.selectedNoteIndex) // Force recreation when switching notes
    }
}

struct NoteTextEditor: NSViewRepresentable {
    @Binding var text: String
    var font: NSFont
    var cursorPosition: Int
    var onCursorChange: (Int) -> Void

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView

        textView.delegate = context.coordinator
        textView.font = font
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false

        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder

        // Set initial text
        textView.string = text

        // Restore cursor position and focus after a brief delay to ensure view is ready
        DispatchQueue.main.async {
            let position = min(cursorPosition, textView.string.count)
            textView.setSelectedRange(NSRange(location: position, length: 0))
            textView.scrollRangeToVisible(NSRange(location: position, length: 0))
            textView.window?.makeFirstResponder(textView)
        }

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let textView = scrollView.documentView as! NSTextView

        if textView.string != text {
            let selectedRange = textView.selectedRange()
            textView.string = text
            textView.setSelectedRange(selectedRange)
        }

        if textView.font != font {
            textView.font = font
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: NoteTextEditor

        init(_ parent: NoteTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.onCursorChange(textView.selectedRange().location)
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var notesManager: NotesManager
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Settings")
                    .font(.title2.bold())
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.escape, modifiers: [])
            }

            Divider()

            // Text Font Setting
            FontSettingRow(
                title: "Editor Font",
                fontSetting: $notesManager.textFont
            )

            Divider()

            // Code Font Setting
            FontSettingRow(
                title: "Code Font",
                fontSetting: $notesManager.codeFont
            )

            Spacer()
        }
        .padding(24)
        .frame(width: 400, height: 280)
    }
}

struct FontSettingRow: View {
    let title: String
    @Binding var fontSetting: FontSetting
    @State private var showingFontPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)

            HStack {
                Text("\(fontSetting.name), \(Int(fontSetting.size)) pt")
                    .font(fontSetting.font)
                    .lineLimit(1)

                Spacer()

                Button("Select...") {
                    showFontPanel()
                }
            }
            .padding(10)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(6)
        }
    }

    private func showFontPanel() {
        let fontManager = NSFontManager.shared
        fontManager.target = FontPanelDelegate.shared
        FontPanelDelegate.shared.callback = { newFont in
            fontSetting.name = newFont.fontName
            fontSetting.size = newFont.pointSize
        }

        let currentFont = fontSetting.nsFont
        fontManager.setSelectedFont(currentFont, isMultiple: false)

        let fontPanel = fontManager.fontPanel(true)
        fontPanel?.orderFront(nil)
    }
}

class FontPanelDelegate: NSObject {
    static let shared = FontPanelDelegate()
    var callback: ((NSFont) -> Void)?

    @objc func changeFont(_ sender: Any?) {
        guard let fontManager = sender as? NSFontManager else { return }
        let newFont = fontManager.convert(.systemFont(ofSize: 14))
        callback?(newFont)
    }
}

#Preview {
    ContentView()
        .environmentObject(NotesManager())
}
