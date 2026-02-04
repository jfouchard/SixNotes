import SwiftUI

struct NoteEditorView: View {
    let noteIndex: Int
    @EnvironmentObject var notesManager: NotesManager
    @State private var keyboardHeight: CGFloat = 0
    @State private var showToolbar = false
    @State private var dragOffset: CGFloat = 0
    @State private var showShareSheet = false
    @State private var showSettings = false
    @StateObject private var textEditorCoordinator = RichTextEditorCoordinator()

    private let toolbarHeight: CGFloat = 44
    private let revealThreshold: CGFloat = 50
    private let dragResistance: CGFloat = 0.5

    private var currentNoteContent: String {
        notesManager.notes[noteIndex].content
    }

    private var isPlainText: Bool {
        notesManager.isPlainText(at: noteIndex)
    }

    private var revealedAmount: CGFloat {
        min(toolbarHeight, dragOffset)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottomTrailing) {
                VStack(spacing: 0) {
                    // Toolbar positioned above the view, revealed by note sliding down
                    ZStack {
                        // Center: Plain text toggle
                        PlainTextToggle(
                            isPlainText: Binding(
                                get: { isPlainText },
                                set: { newValue in
                                    notesManager.setPlainText(newValue, for: noteIndex)
                                }
                            )
                        )

                        // Left and right buttons
                        HStack {
                            Button {
                                showSettings = true
                            } label: {
                                Image(systemName: "gearshape")
                                    .font(.title3)
                                    .foregroundStyle(.primary)
                                    .frame(width: 44, height: 44)
                            }
                            Spacer()
                            Button {
                                textEditorCoordinator.presentFind()
                            } label: {
                                Image(systemName: "magnifyingglass")
                                    .font(.title3)
                                    .foregroundStyle(.primary)
                                    .frame(width: 44, height: 44)
                            }
                            Button {
                                showShareSheet = true
                            } label: {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.title3)
                                    .foregroundStyle(.primary)
                                    .offset(y: -1)
                                    .frame(width: 44, height: 44)
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .frame(height: toolbarHeight)
                    .background(Color(uiColor: .secondarySystemBackground))

                    RichTextEditor(
                        text: notesManager.noteBinding(for: noteIndex),
                        isPlainText: isPlainText,
                        textFont: notesManager.textFont.uiFont,
                        codeFont: notesManager.codeFont.uiFont,
                        coordinator: textEditorCoordinator
                    )
                    .id("\(noteIndex)-\(isPlainText)") // Force recreation when switching notes or plain text mode
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
                .offset(y: revealedAmount - toolbarHeight)
                .simultaneousGesture(
                    DragGesture()
                        .onChanged { value in
                            // Only track downward drags when toolbar is hidden (with resistance)
                            if !showToolbar && value.translation.height > 0 {
                                dragOffset = value.translation.height * dragResistance
                            }
                            // Track upward drags to hide toolbar
                            if showToolbar {
                                dragOffset = toolbarHeight + value.translation.height
                            }
                        }
                        .onEnded { value in
                            if dragOffset >= revealThreshold {
                                // Snap to fully revealed
                                withAnimation(.interpolatingSpring(stiffness: 150, damping: 20)) {
                                    dragOffset = toolbarHeight
                                    showToolbar = true
                                }
                            } else {
                                // Snap to hidden
                                withAnimation(.interpolatingSpring(stiffness: 150, damping: 20)) {
                                    dragOffset = 0
                                    showToolbar = false
                                }
                            }
                        }
                )

                // Done button that appears only when software keyboard is up and find panel is not visible
                if keyboardHeight > 0 && !textEditorCoordinator.isFindVisible {
                    Button {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        NotificationCenter.default.post(name: .dismissKeyboardWithAnimation, object: nil)
                    } label: {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title)
                            .foregroundStyle(.primary)
                            .padding(12)
                    }
                    .glassEffect(.regular.interactive())
                    .padding(.trailing, 16)
                    .padding(.bottom, 16)
                }
            }
            .clipped()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
            if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                keyboardHeight = keyboardFrame.height
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardHeight = 0
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [currentNoteContent])
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }
}

// MARK: - PlainTextToggle

struct PlainTextToggle: View {
    @Binding var isPlainText: Bool

    var body: some View {
        Picker("", selection: $isPlainText) {
            Text("Rich").tag(false)
            Text("Plain").tag(true)
        }
        .pickerStyle(.segmented)
        .frame(width: 110)
    }
}

// MARK: - FormattingTextView

/// Custom UITextView that supports formatting keyboard shortcuts
class FormattingTextView: UITextView {
    weak var formattingDelegate: RichTextEditorCoordinator?

    override var keyCommands: [UIKeyCommand]? {
        // Only provide formatting commands in rich text mode
        guard let delegate = formattingDelegate, !delegate.isPlainText else {
            return super.keyCommands
        }

        return [
            UIKeyCommand(input: "b", modifierFlags: .command, action: #selector(toggleBold)),
            UIKeyCommand(input: "i", modifierFlags: .command, action: #selector(toggleItalic)),
        ]
    }

    @objc private func toggleBold() {
        formattingDelegate?.toggleBold()
    }

    @objc private func toggleItalic() {
        formattingDelegate?.toggleItalic()
    }
}

// MARK: - RichTextEditor

struct RichTextEditor: UIViewRepresentable {
    @Binding var text: String
    var isPlainText: Bool
    var textFont: UIFont
    var codeFont: UIFont
    var coordinator: RichTextEditorCoordinator

    private let converter = MarkdownConverter()

    func makeUIView(context: Context) -> FormattingTextView {
        let textView = FormattingTextView()
        textView.delegate = context.coordinator
        textView.formattingDelegate = context.coordinator
        textView.backgroundColor = .clear

        // Enable find interaction (iOS 16+)
        textView.isFindInteractionEnabled = true

        // Store reference in coordinator
        context.coordinator.textView = textView
        context.coordinator.converter = converter
        context.coordinator.isPlainText = isPlainText
        context.coordinator.textFont = textFont
        context.coordinator.codeFont = codeFont
        context.coordinator.textBinding = $text
        context.coordinator.startObservingFindVisibility()

        // Configure for editing
        textView.isEditable = true
        textView.isSelectable = true
        textView.autocapitalizationType = .sentences
        textView.autocorrectionType = .default

        // Configure for plain text or rich text mode
        if isPlainText {
            textView.font = codeFont
            textView.text = text
            textView.allowsEditingTextAttributes = false
        } else {
            textView.font = textFont
            textView.allowsEditingTextAttributes = true
            // Convert markdown to attributed string for rich text editing
            let attributedContent = converter.attributedString(from: text, textFont: textFont, codeFont: codeFont)
            textView.attributedText = attributedContent
        }

        return textView
    }

    func updateUIView(_ textView: FormattingTextView, context: Context) {
        // Update coordinator state
        context.coordinator.isPlainText = isPlainText
        context.coordinator.textFont = textFont
        context.coordinator.codeFont = codeFont
        context.coordinator.textBinding = $text

        // Skip updates while the user is actively editing
        guard !context.coordinator.isUserEditing else { return }

        if isPlainText {
            // Plain text mode - just sync the string
            if textView.text != text {
                let selectedRange = textView.selectedRange
                textView.text = text
                let newPosition = min(selectedRange.location, textView.text.count)
                textView.selectedRange = NSRange(location: newPosition, length: 0)
            }
            textView.font = codeFont
        }
        // In rich text mode, we don't update from external changes during editing
        // The content is converted to markdown on save via textViewDidChange
    }

    func makeCoordinator() -> RichTextEditorCoordinator {
        coordinator
    }
}

class RichTextEditorCoordinator: NSObject, UITextViewDelegate, ObservableObject {
    weak var textView: UITextView?
    var textBinding: Binding<String>?
    var converter: MarkdownConverter?
    var isPlainText: Bool = true
    var textFont: UIFont = .systemFont(ofSize: 16)
    var codeFont: UIFont = .monospacedSystemFont(ofSize: 14, weight: .regular)
    var isUserEditing = false
    @Published var isFindVisible = false

    private var timer: Timer?
    private var conversionWorkItem: DispatchWorkItem?

    // MARK: - Formatting Actions

    func toggleBold() {
        guard !isPlainText,
              let textView = textView,
              let converter = converter else { return }

        let range = textView.selectedRange

        if range.length > 0 {
            // Selection exists - apply formatting to selected text
            let textStorage = textView.textStorage

            let isBold = converter.isBold(in: textStorage, range: range)

            if isBold {
                converter.removeBold(from: textStorage, range: range)
            } else {
                converter.applyBold(to: textStorage, range: range)
            }

            // Trigger text change handling
            textViewDidChange(textView)
        } else {
            // No selection - toggle typing attributes for future typing
            var typingAttrs = textView.typingAttributes
            let currentFont = typingAttrs[.font] as? UIFont ?? textFont

            let traits = currentFont.fontDescriptor.symbolicTraits
            let isBold = traits.contains(.traitBold)

            let newFont: UIFont
            if isBold {
                if let descriptor = currentFont.fontDescriptor.withSymbolicTraits(traits.subtracting(.traitBold)) {
                    newFont = UIFont(descriptor: descriptor, size: currentFont.pointSize)
                } else {
                    newFont = currentFont
                }
            } else {
                if let descriptor = currentFont.fontDescriptor.withSymbolicTraits(traits.union(.traitBold)) {
                    newFont = UIFont(descriptor: descriptor, size: currentFont.pointSize)
                } else {
                    newFont = currentFont
                }
            }

            typingAttrs[.font] = newFont
            textView.typingAttributes = typingAttrs
        }
    }

    func toggleItalic() {
        guard !isPlainText,
              let textView = textView,
              let converter = converter else { return }

        let range = textView.selectedRange

        if range.length > 0 {
            // Selection exists - apply formatting to selected text
            let textStorage = textView.textStorage

            let isItalic = converter.isItalic(in: textStorage, range: range)

            if isItalic {
                converter.removeItalic(from: textStorage, range: range)
            } else {
                converter.applyItalic(to: textStorage, range: range)
            }

            // Trigger text change handling
            textViewDidChange(textView)
        } else {
            // No selection - toggle typing attributes for future typing
            var typingAttrs = textView.typingAttributes
            let currentFont = typingAttrs[.font] as? UIFont ?? textFont

            let traits = currentFont.fontDescriptor.symbolicTraits
            let isItalic = traits.contains(.traitItalic)

            let newFont: UIFont
            if isItalic {
                if let descriptor = currentFont.fontDescriptor.withSymbolicTraits(traits.subtracting(.traitItalic)) {
                    newFont = UIFont(descriptor: descriptor, size: currentFont.pointSize)
                } else {
                    newFont = currentFont
                }
            } else {
                if let descriptor = currentFont.fontDescriptor.withSymbolicTraits(traits.union(.traitItalic)) {
                    newFont = UIFont(descriptor: descriptor, size: currentFont.pointSize)
                } else {
                    newFont = currentFont
                }
            }

            typingAttrs[.font] = newFont
            textView.typingAttributes = typingAttrs
        }
    }

    // MARK: - UITextViewDelegate

    func textViewDidChange(_ textView: UITextView) {
        if isPlainText {
            // Plain text mode - direct string binding
            textBinding?.wrappedValue = textView.text
        } else {
            // Rich text mode - debounce conversion to markdown
            isUserEditing = true

            conversionWorkItem?.cancel()
            let workItem = DispatchWorkItem { [weak self] in
                guard let self = self,
                      let converter = self.converter,
                      let textView = self.textView else { return }

                let markdown = converter.markdown(from: textView.attributedText)
                // Update binding on main thread
                DispatchQueue.main.async {
                    self.textBinding?.wrappedValue = markdown
                    self.isUserEditing = false
                }
            }
            conversionWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
        }
    }

    func presentFind() {
        textView?.findInteraction?.presentFindNavigator(showingReplace: false)
    }

    func startObservingFindVisibility() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.checkFindVisibility()
        }
    }

    func stopObservingFindVisibility() {
        timer?.invalidate()
        timer = nil
    }

    private func checkFindVisibility() {
        let isVisible = textView?.findInteraction?.isFindNavigatorVisible ?? false
        if isVisible != isFindVisible {
            isFindVisible = isVisible
        }
    }

    /// Immediately flush any pending text changes to storage
    func flushPendingSave() {
        conversionWorkItem?.cancel()
        conversionWorkItem = nil

        guard !isPlainText,
              let textView = textView,
              let converter = converter else { return }

        let markdown = converter.markdown(from: textView.attributedText)
        textBinding?.wrappedValue = markdown
        isUserEditing = false
    }

    deinit {
        stopObservingFindVisibility()
    }
}

#Preview {
    NoteEditorView(noteIndex: 0)
        .environmentObject(NotesManager())
}
