import SwiftUI

struct NoteEditorView: View {
    let noteIndex: Int
    @EnvironmentObject var notesManager: NotesManager
    @FocusState private var isFocused: Bool
    @State private var keyboardHeight: CGFloat = 0
    @State private var dragOffset: CGFloat = 0
    @State private var showShareSheet = false

    private let shareButtonRevealThreshold: CGFloat = 60
    private let maxDragOffset: CGFloat = 80

    private var currentNoteContent: String {
        notesManager.notes[noteIndex].content
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                // Pull-to-reveal share button area
                if dragOffset > 0 {
                    HStack {
                        Spacer()
                        Button {
                            showShareSheet = true
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .font(.title2)
                                .foregroundStyle(.primary)
                                .opacity(min(1.0, dragOffset / shareButtonRevealThreshold))
                        }
                        Spacer()
                    }
                    .frame(height: dragOffset)
                    .background(Color(uiColor: .systemBackground).opacity(0.8))
                }

                TextEditor(text: notesManager.noteBinding(for: noteIndex))
                    .font(notesManager.textFont.font)
                    .focused($isFocused)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        // Only allow downward drag from near the top
                        if value.startLocation.y < 100 && value.translation.height > 0 {
                            dragOffset = min(maxDragOffset, value.translation.height)
                        }
                    }
                    .onEnded { value in
                        // If dragged past threshold, show share sheet
                        if dragOffset >= shareButtonRevealThreshold {
                            showShareSheet = true
                        }
                        // Animate back to hidden
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            dragOffset = 0
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
        }
    }
}

#Preview {
    NoteEditorView(noteIndex: 0)
        .environmentObject(NotesManager())
}
