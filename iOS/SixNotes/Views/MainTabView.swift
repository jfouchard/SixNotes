import SwiftUI

extension Notification.Name {
    static let dismissKeyboardWithAnimation = Notification.Name("dismissKeyboardWithAnimation")
}

struct MainTabView: View {
    @EnvironmentObject var notesManager: NotesManager
    @State private var selectedTab = 0
    @State private var dotSettleOffset: CGFloat = 0
    @State private var keyboardVisible = false

    static let noteColors: [Color] = [
        Color(red: 0.70, green: 0.45, blue: 0.85),  // Purple
        Color(red: 0.35, green: 0.60, blue: 0.90),  // Blue
        Color(red: 0.40, green: 0.78, blue: 0.45),  // Green
        Color(red: 0.95, green: 0.75, blue: 0.25),  // Yellow
        Color(red: 0.95, green: 0.55, blue: 0.25),  // Orange
        Color(red: 0.90, green: 0.30, blue: 0.35),  // Red
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Note editor (no swipe navigation)
            NoteEditorView(noteIndex: selectedTab)
                .id(selectedTab)

            // Custom tab bar
            HStack(spacing: 24) {
                ForEach(0..<6, id: \.self) { index in
                    let noteColor = Self.noteColors[index]
                    Button {
                        // Dismiss keyboard first, then switch tabs
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)

                        if keyboardVisible {
                            // Keyboard is up - disable animations to prevent interference
                            var transaction = Transaction()
                            transaction.disablesAnimations = true
                            withTransaction(transaction) {
                                dotSettleOffset = -12
                                selectedTab = index
                                notesManager.selectNote(index)
                            }
                        } else {
                            // No keyboard - animate the upward movement too
                            selectedTab = index
                            notesManager.selectNote(index)
                            withAnimation(.easeOut(duration: 0.15)) {
                                dotSettleOffset = -12
                            }
                        }

                        // Animate bounce after brief delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
                                dotSettleOffset = 0
                            }
                        }
                    } label: {
                        ZStack {
                            // Outer ring
                            if selectedTab == index {
                                Circle()
                                    .stroke(noteColor.opacity(0.4), lineWidth: 2)
                                    .frame(width: 20, height: 20)
                            }
                            // Inner dot
                            Circle()
                                .fill(selectedTab == index ? noteColor : (notesManager.hasContent(at: index) ? noteColor.opacity(0.6) : noteColor.opacity(0.2)))
                                .frame(width: 12, height: 12)
                                .offset(y: selectedTab == index ? dotSettleOffset : 0)
                        }
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                        .transaction { t in t.disablesAnimations = true }
                    }
                    .buttonStyle(.plain)
                }
            }
            .transaction { t in t.disablesAnimations = true }
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(Color(uiColor: .systemBackground))
        }
        .onAppear {
            selectedTab = notesManager.selectedNoteIndex
        }
        .onReceive(NotificationCenter.default.publisher(for: .dismissKeyboardWithAnimation)) { _ in
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                dotSettleOffset = -12
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
                    dotSettleOffset = 0
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            keyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardVisible = false
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    var onComplete: ((Bool) -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(onComplete: onComplete)
    }

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.completionWithItemsHandler = context.coordinator.completionHandler
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        context.coordinator.onComplete = onComplete
    }

    class Coordinator {
        var onComplete: ((Bool) -> Void)?

        init(onComplete: ((Bool) -> Void)?) {
            self.onComplete = onComplete
        }

        lazy var completionHandler: UIActivityViewController.CompletionWithItemsHandler = { [weak self] activityType, completed, returnedItems, error in
            self?.onComplete?(completed)
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(NotesManager())
}
