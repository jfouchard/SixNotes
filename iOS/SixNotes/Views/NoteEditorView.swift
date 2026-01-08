import SwiftUI

struct NoteEditorView: View {
    let noteIndex: Int
    @EnvironmentObject var notesManager: NotesManager
    @FocusState private var isFocused: Bool
    @State private var keyboardHeight: CGFloat = 0

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            TextEditor(text: notesManager.noteBinding(for: noteIndex))
                .font(notesManager.textFont.font)
                .focused($isFocused)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 16)
                .padding(.top, 8)

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
    }
}

#Preview {
    NoteEditorView(noteIndex: 0)
        .environmentObject(NotesManager())
}
