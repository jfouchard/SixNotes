import SwiftUI

struct NoteEditorView: View {
    let noteIndex: Int
    @EnvironmentObject var notesManager: NotesManager
    @FocusState private var isFocused: Bool
    @State private var keyboardHeight: CGFloat = 0
    @State private var showToolbar = false
    @State private var dragOffset: CGFloat = 0
    @State private var showShareSheet = false

    private let toolbarHeight: CGFloat = 44
    private let revealThreshold: CGFloat = 50

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

                    TextEditor(text: notesManager.noteBinding(for: noteIndex))
                        .font(notesManager.textFont.font)
                        .focused($isFocused)
                        .scrollContentBackground(.hidden)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                }
                .offset(y: revealedAmount - toolbarHeight)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            // Only handle vertical drags - let horizontal pass through for TabView
                            let isVertical = abs(value.translation.height) > abs(value.translation.width)
                            guard isVertical else { return }

                            // Only track downward drags when toolbar is hidden
                            if !showToolbar && value.translation.height > 0 {
                                dragOffset = value.translation.height
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

#Preview {
    NoteEditorView(noteIndex: 0)
        .environmentObject(NotesManager())
}
