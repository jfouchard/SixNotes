import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var notesManager: NotesManager
    @State private var selectedTab = 0

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
                        withAnimation {
                            selectedTab = index
                        }
                        notesManager.selectNote(index)
                    } label: {
                        Circle()
                            .fill(selectedTab == index ? noteColor : (notesManager.hasContent(at: index) ? noteColor.opacity(0.6) : noteColor.opacity(0.2)))
                            .frame(width: 12, height: 12)
                            .overlay {
                                if selectedTab == index {
                                    Circle()
                                        .stroke(noteColor.opacity(0.4), lineWidth: 2)
                                        .frame(width: 20, height: 20)
                                }
                            }
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(Color(uiColor: .systemBackground))
        }
        .onAppear {
            selectedTab = notesManager.selectedNoteIndex
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
