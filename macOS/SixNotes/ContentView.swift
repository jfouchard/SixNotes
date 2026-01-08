import SwiftUI

struct ContentView: View {
    @EnvironmentObject var notesManager: NotesManager
    @State private var showSettings = false

    private var currentNoteContent: String {
        notesManager.notes[notesManager.selectedNoteIndex].content
    }

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

                // Share button
                ShareButton(content: currentNoteContent)
                    .padding(.trailing, 8)
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

    private var currentNoteContent: String {
        notesManager.notes[notesManager.selectedNoteIndex].content
    }

    var body: some View {
        VStack(spacing: 0) {
            MarkdownPreviewView(content: currentNoteContent)
                .environmentObject(notesManager)

            // Footer bar with share button
            HStack {
                Spacer()
                ShareButton(
                    content: currentNoteContent,
                    textFont: notesManager.textFont.nsFont,
                    codeFont: notesManager.codeFont.nsFont,
                    asRichText: true
                )
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(minWidth: 300, minHeight: 200)
    }
}

struct ShareButton: View {
    let content: String
    var textFont: NSFont = .systemFont(ofSize: 14)
    var codeFont: NSFont = .monospacedSystemFont(ofSize: 13, weight: .regular)
    var asRichText: Bool = false

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
        let itemToShare: Any = asRichText ? renderMarkdownToAttributedString() : content
        let picker = NSSharingServicePicker(items: [itemToShare])
        if let contentView = NSApp.keyWindow?.contentView {
            let rect = NSRect(x: contentView.bounds.maxX - 40, y: contentView.bounds.maxY - 28, width: 1, height: 1)
            picker.show(relativeTo: rect, of: contentView, preferredEdge: .minY)
        }
    }

    private func renderMarkdownToAttributedString() -> NSAttributedString {
        let result = NSMutableAttributedString()
        let lines = content.components(separatedBy: "\n")
        var inCodeBlock = false
        var codeBlockLines: [String] = []

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 4

        for line in lines {
            if line.hasPrefix("```") {
                if inCodeBlock {
                    let code = codeBlockLines.joined(separator: "\n")
                    let codeAttr = NSMutableAttributedString(string: code + "\n\n", attributes: [
                        .font: codeFont,
                        .backgroundColor: NSColor.secondaryLabelColor.withAlphaComponent(0.1),
                        .paragraphStyle: paragraphStyle
                    ])
                    result.append(codeAttr)
                    codeBlockLines = []
                    inCodeBlock = false
                } else {
                    inCodeBlock = true
                }
                continue
            }

            if inCodeBlock {
                codeBlockLines.append(line)
                continue
            }

            if line.hasPrefix("######") {
                appendHeader(to: result, text: String(line.dropFirst(6)), scale: 1.1, weight: .semibold)
            } else if line.hasPrefix("#####") {
                appendHeader(to: result, text: String(line.dropFirst(5)), scale: 1.15, weight: .semibold)
            } else if line.hasPrefix("####") {
                appendHeader(to: result, text: String(line.dropFirst(4)), scale: 1.2, weight: .bold)
            } else if line.hasPrefix("###") {
                appendHeader(to: result, text: String(line.dropFirst(3)), scale: 1.3, weight: .bold)
            } else if line.hasPrefix("##") {
                appendHeader(to: result, text: String(line.dropFirst(2)), scale: 1.5, weight: .bold)
            } else if line.hasPrefix("#") {
                appendHeader(to: result, text: String(line.dropFirst(1)), scale: 1.8, weight: .bold)
            } else if line.hasPrefix(">") {
                let text = line.dropFirst(1).trimmingCharacters(in: .whitespaces)
                let blockquoteStyle = NSMutableParagraphStyle()
                blockquoteStyle.firstLineHeadIndent = 12
                blockquoteStyle.headIndent = 12
                blockquoteStyle.lineSpacing = 4
                let attr = NSAttributedString(string: text + "\n", attributes: [
                    .font: textFont,
                    .foregroundColor: NSColor.secondaryLabelColor,
                    .paragraphStyle: blockquoteStyle
                ])
                result.append(attr)
            } else if line.hasPrefix("- ") || line.hasPrefix("* ") {
                let text = String(line.dropFirst(2))
                let listStyle = NSMutableParagraphStyle()
                listStyle.firstLineHeadIndent = 0
                listStyle.headIndent = 16
                listStyle.lineSpacing = 4
                result.append(NSAttributedString(string: "• ", attributes: [
                    .font: textFont,
                    .paragraphStyle: listStyle
                ]))
                appendInlineMarkdown(to: result, text: text + "\n")
            } else if line.trimmingCharacters(in: .whitespaces) == "---" {
                result.append(NSAttributedString(string: "―――――――――――――――――――\n", attributes: [
                    .font: textFont,
                    .foregroundColor: NSColor.separatorColor
                ]))
            } else if !line.isEmpty {
                appendInlineMarkdown(to: result, text: line + "\n")
            } else {
                result.append(NSAttributedString(string: "\n"))
            }
        }

        return result
    }

    private func appendHeader(to result: NSMutableAttributedString, text: String, scale: CGFloat, weight: NSFont.Weight) {
        let headerFont = NSFont.systemFont(ofSize: textFont.pointSize * scale, weight: weight)
        let headerStyle = NSMutableParagraphStyle()
        headerStyle.lineSpacing = 4
        headerStyle.paragraphSpacingBefore = 8
        let attr = NSAttributedString(string: text.trimmingCharacters(in: .whitespaces) + "\n", attributes: [
            .font: headerFont,
            .paragraphStyle: headerStyle
        ])
        result.append(attr)
    }

    private func appendInlineMarkdown(to result: NSMutableAttributedString, text: String) {
        if let attributed = try? NSAttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            let mutable = NSMutableAttributedString(attributedString: attributed)
            mutable.enumerateAttribute(.font, in: NSRange(location: 0, length: mutable.length)) { value, range, _ in
                if let existingFont = value as? NSFont {
                    let traits = NSFontManager.shared.traits(of: existingFont)
                    var newFont = textFont
                    if traits.contains(.boldFontMask) && traits.contains(.italicFontMask) {
                        newFont = NSFontManager.shared.convert(textFont, toHaveTrait: [.boldFontMask, .italicFontMask])
                    } else if traits.contains(.boldFontMask) {
                        newFont = NSFontManager.shared.convert(textFont, toHaveTrait: .boldFontMask)
                    } else if traits.contains(.italicFontMask) {
                        newFont = NSFontManager.shared.convert(textFont, toHaveTrait: .italicFontMask)
                    }
                    mutable.addAttribute(.font, value: newFont, range: range)
                } else {
                    mutable.addAttribute(.font, value: textFont, range: range)
                }
            }
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineSpacing = 4
            mutable.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: mutable.length))
            result.append(mutable)
        } else {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineSpacing = 4
            result.append(NSAttributedString(string: text, attributes: [
                .font: textFont,
                .paragraphStyle: paragraphStyle
            ]))
        }
    }
}

struct NoteDot: View {
    let index: Int
    let isSelected: Bool
    let hasContent: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(isSelected ? Color.accentColor : (hasContent ? Color.secondary.opacity(0.5) : Color.secondary.opacity(0.2)))
                .frame(width: 10, height: 10)

            if isSelected {
                Circle()
                    .stroke(Color.accentColor.opacity(0.3), lineWidth: 2)
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
