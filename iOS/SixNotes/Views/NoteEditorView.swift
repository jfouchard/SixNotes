import SwiftUI

struct NoteEditorView: View {
    let noteIndex: Int
    @EnvironmentObject var notesManager: NotesManager
    @FocusState private var isFocused: Bool
    @State private var keyboardHeight: CGFloat = 0
    @State private var showToolbar = false
    @State private var dragOffset: CGFloat = 0

    private let toolbarHeight: CGFloat = 44
    private let revealThreshold: CGFloat = 50

    private var currentNoteContent: String {
        notesManager.notes[noteIndex].content
    }

    private func presentShareSheet() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else { return }

        let activityVC = UIActivityViewController(activityItems: [currentNoteContent], applicationActivities: nil)
        activityVC.completionWithItemsHandler = { activityType, completed, returnedItems, error in
            if completed {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.interpolatingSpring(stiffness: 150, damping: 20)) {
                        dragOffset = 0
                        showToolbar = false
                    }
                }
            }
        }

        // On iPhone, UIActivityViewController is presented as a sheet with built-in dismiss
        // On iPad, it needs to be presented from a popover
        if UIDevice.current.userInterfaceIdiom == .pad {
            activityVC.popoverPresentationController?.sourceView = rootVC.view
            activityVC.popoverPresentationController?.sourceRect = CGRect(x: rootVC.view.bounds.midX, y: 100, width: 0, height: 0)
        }

        // Find the topmost presented controller
        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }
        topVC.present(activityVC, animated: true)
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
                            presentShareSheet()
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
                .simultaneousGesture(
                    DragGesture()
                        .onChanged { value in
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
    }
}

#Preview {
    NoteEditorView(noteIndex: 0)
        .environmentObject(NotesManager())
}
