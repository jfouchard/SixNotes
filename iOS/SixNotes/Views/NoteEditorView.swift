import SwiftUI

struct NoteEditorView: View {
    let noteIndex: Int
    @EnvironmentObject var notesManager: NotesManager
    @FocusState private var isFocused: Bool
    @State private var keyboardHeight: CGFloat = 0
    @State private var showShareSheet = false
    @State private var showToolbar = false
    @State private var dragOffset: CGFloat = 0

    private let toolbarHeight: CGFloat = 44
    private let revealThreshold: CGFloat = 50

    private var currentNoteContent: String {
        notesManager.notes[noteIndex].content
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottomTrailing) {
                VStack(spacing: 0) {
                    // Revealed toolbar
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
                    .frame(height: showToolbar ? toolbarHeight : (dragOffset > 0 ? min(toolbarHeight, dragOffset) : 0))
                    .background(Color(uiColor: .secondarySystemBackground))
                    .opacity(showToolbar ? 1.0 : min(1.0, dragOffset / revealThreshold))
                    .clipped()

                    TextEditor(text: notesManager.noteBinding(for: noteIndex))
                        .font(notesManager.textFont.font)
                        .focused($isFocused)
                        .scrollContentBackground(.hidden)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                }
                .simultaneousGesture(
                    DragGesture()
                        .onChanged { value in
                            // Only track downward drags when toolbar is hidden
                            if !showToolbar && value.translation.height > 0 {
                                dragOffset = value.translation.height
                            }
                            // Track upward drags to hide toolbar
                            if showToolbar && value.translation.height < -20 {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    showToolbar = false
                                }
                            }
                        }
                        .onEnded { value in
                            if !showToolbar && dragOffset >= revealThreshold {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    showToolbar = true
                                }
                            }
                            dragOffset = 0
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
            ShareSheet(items: [currentNoteContent]) { completed in
                if completed {
                    withAnimation(.easeOut(duration: 0.2)) {
                        showToolbar = false
                    }
                }
            }
        }
    }
}

#Preview {
    NoteEditorView(noteIndex: 0)
        .environmentObject(NotesManager())
}
