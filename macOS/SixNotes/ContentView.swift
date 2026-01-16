import SwiftUI

struct ContentView: View {
    @EnvironmentObject var notesManager: NotesManager
    @State private var isWindowFocused = true

    private var currentNoteContent: String {
        notesManager.notes[notesManager.selectedNoteIndex].content
    }

    var body: some View {
        VStack(spacing: 0) {
            // Title bar area - aligned with traffic lights
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

                // Share button
                ShareButton(content: currentNoteContent)
                    .padding(.trailing, 8)
            }
            .padding(.top, 5)
            .opacity(isWindowFocused ? 1.0 : 0.4)
            .animation(.easeInOut(duration: 0.2), value: isWindowFocused)

            // Note editor
            NoteEditorView()
                .environmentObject(notesManager)
        }
        .frame(minWidth: 400, minHeight: 300)
        .background(Color(NSColor.windowBackgroundColor))
        .ignoresSafeArea()
        .onReceive(NotificationCenter.default.publisher(for: .togglePreview)) { _ in
            PreviewWindowController.shared.toggle(notesManager: notesManager)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            isWindowFocused = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { _ in
            // Only dim if no window in our app is key (e.g., switched to another app)
            DispatchQueue.main.async {
                isWindowFocused = NSApp.keyWindow != nil
            }
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

    private var currentNoteContent: String {
        notesManager.notes[notesManager.selectedNoteIndex].content
    }

    var body: some View {
        MarkdownPreviewView(content: currentNoteContent)
            .environmentObject(notesManager)
            .frame(minWidth: 300, minHeight: 200)
    }
}

struct ShareButton: View {
    let content: String

    var body: some View {
        Button {
            share()
        } label: {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
    }

    private func share() {
        let picker = NSSharingServicePicker(items: [content])
        if let contentView = NSApp.keyWindow?.contentView {
            let rect = NSRect(x: contentView.bounds.maxX - 40, y: contentView.bounds.maxY - 28, width: 1, height: 1)
            picker.show(relativeTo: rect, of: contentView, preferredEdge: .minY)
        }
    }
}

struct NoteDot: View {
    let index: Int
    let isSelected: Bool
    let hasContent: Bool

    static let noteColors: [Color] = [
        Color(red: 0.70, green: 0.45, blue: 0.85),  // Purple
        Color(red: 0.35, green: 0.60, blue: 0.90),  // Blue
        Color(red: 0.40, green: 0.78, blue: 0.45),  // Green
        Color(red: 0.95, green: 0.75, blue: 0.25),  // Yellow
        Color(red: 0.95, green: 0.55, blue: 0.25),  // Orange
        Color(red: 0.90, green: 0.30, blue: 0.35),  // Red
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

        // Add text insets for padding while keeping scrollbar at window edge
        textView.textContainerInset = NSSize(width: 16, height: 16)

        // Enable Find Bar (system find and replace)
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true

        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder

        // Store reference for find operations
        context.coordinator.textView = textView

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
        weak var textView: NSTextView?

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
    var body: some View {
        TabView {
            GeneralSettingsTab()
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }

            SyncSettingsTab()
                .tabItem {
                    Label("iCloud", systemImage: "icloud")
                }
        }
        .frame(width: 450, height: 200)
    }
}

struct GeneralSettingsTab: View {
    @EnvironmentObject var notesManager: NotesManager

    var body: some View {
        Form {
            FontSettingRow(
                title: "Editor Font",
                fontSetting: $notesManager.textFont
            )

            FontSettingRow(
                title: "Code Font",
                fontSetting: $notesManager.codeFont
            )
        }
        .formStyle(.grouped)
    }
}

struct SyncSettingsTab: View {
    @EnvironmentObject var notesManager: NotesManager

    private var accountStatusText: String {
        switch notesManager.syncEngine.accountStatus {
        case .available:
            return "Available"
        case .noAccount:
            return "No iCloud Account"
        case .restricted:
            return "Restricted"
        case .couldNotDetermine:
            return "Unknown"
        case .temporarilyUnavailable:
            return "Temporarily Unavailable"
        }
    }

    private var accountStatusColor: Color {
        switch notesManager.syncEngine.accountStatus {
        case .available:
            return .green
        case .noAccount, .restricted:
            return .red
        case .couldNotDetermine, .temporarilyUnavailable:
            return .orange
        }
    }

    var body: some View {
        Form {
            Section {
                Toggle("iCloud Sync", isOn: $notesManager.isSyncEnabled)

                if notesManager.isSyncEnabled {
                    HStack {
                        Text("Account")
                        Spacer()
                        Text(accountStatusText)
                            .foregroundColor(accountStatusColor)
                    }

                    HStack {
                        Text("Status")
                        Spacer()
                        SyncStatusView(
                            isSyncing: notesManager.isSyncing,
                            lastSyncDate: notesManager.lastSyncDate,
                            syncError: notesManager.syncError
                        )
                    }

                    Button {
                        Task {
                            await notesManager.performSync()
                        }
                    } label: {
                        HStack {
                            Text("Sync Now")
                            Spacer()
                            if notesManager.isSyncing {
                                ProgressView()
                                    .scaleEffect(0.5)
                            }
                        }
                    }
                    .disabled(notesManager.isSyncing)
                }
            }
        }
        .formStyle(.grouped)
    }
}

struct SyncStatusView: View {
    let isSyncing: Bool
    let lastSyncDate: Date?
    let syncError: String?

    var body: some View {
        HStack(spacing: 6) {
            if isSyncing {
                ProgressView()
                    .scaleEffect(0.5)
                Text("Syncing...")
                    .foregroundColor(.secondary)
            } else if let error = syncError {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text(error)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            } else if let date = lastSyncDate {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text(date.formatted(.relative(presentation: .named)))
                    .foregroundColor(.secondary)
            } else {
                Text("Never synced")
                    .foregroundColor(.secondary)
            }
        }
        .font(.caption)
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
