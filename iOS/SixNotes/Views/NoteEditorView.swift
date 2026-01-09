import SwiftUI

struct NoteEditorView: View {
    let noteIndex: Int
    @EnvironmentObject var notesManager: NotesManager
    @FocusState private var isFocused: Bool
    @State private var keyboardHeight: CGFloat = 0
    @State private var showToolbar = false
    @State private var dragOffset: CGFloat = 0
    @State private var showShareSheet = false
    @State private var findInteraction: UIFindInteraction?

    private let toolbarHeight: CGFloat = 44
    private let revealThreshold: CGFloat = 50
    private let dragResistance: CGFloat = 0.5

    private var currentNoteContent: String {
        notesManager.notes[noteIndex].content
    }

    private var revealedAmount: CGFloat {
        min(toolbarHeight, dragOffset)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottomTrailing) {
                VStack(spacing: 0) {
                    // Toolbar positioned above the view, revealed by note sliding down
                    HStack {
                        Spacer()
                        Button {
                            findInteraction?.presentFindNavigator(showingReplace: false)
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
                                .frame(width: 44, height: 44)
                        }
                    }
                    .padding(.horizontal, 8)
                    .frame(height: toolbarHeight)
                    .background(Color(uiColor: .secondarySystemBackground))

                    FindableTextEditor(
                        text: notesManager.noteBinding(for: noteIndex),
                        font: notesManager.textFont.uiFont,
                        onFindInteraction: { interaction in
                            findInteraction = interaction
                        }
                    )
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

                // Done button that appears only when software keyboard is up
                if keyboardHeight > 0 {
                    Button {
                        isFocused = false
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
    }
}

// MARK: - FindableTextEditor

struct FindableTextEditor: UIViewRepresentable {
    @Binding var text: String
    var font: UIFont
    var onFindInteraction: (UIFindInteraction?) -> Void

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.font = font
        textView.backgroundColor = .clear
        textView.text = text

        // Enable find interaction (iOS 16+)
        textView.isFindInteractionEnabled = true
        onFindInteraction(textView.findInteraction)

        // Configure for editing
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsEditingTextAttributes = false
        textView.autocapitalizationType = .sentences
        textView.autocorrectionType = .default

        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        if textView.text != text {
            let selectedRange = textView.selectedRange
            textView.text = text
            // Restore selection if possible
            if selectedRange.location <= text.count {
                textView.selectedRange = selectedRange
            }
        }

        if textView.font != font {
            textView.font = font
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: FindableTextEditor

        init(_ parent: FindableTextEditor) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
        }
    }
}

#Preview {
    NoteEditorView(noteIndex: 0)
        .environmentObject(NotesManager())
}
