import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var notesManager: NotesManager
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            // Swipeable note editors
            TabView(selection: $selectedTab) {
                ForEach(0..<6, id: \.self) { index in
                    NoteEditorView(noteIndex: index)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .onChange(of: selectedTab) { _, newValue in
                notesManager.selectNote(newValue)
            }

            // Custom tab bar
            HStack(spacing: 24) {
                ForEach(0..<6, id: \.self) { index in
                    Button {
                        withAnimation {
                            selectedTab = index
                        }
                        notesManager.selectNote(index)
                    } label: {
                        Circle()
                            .fill(selectedTab == index ? Color.accentColor : (notesManager.hasContent(at: index) ? Color.secondary.opacity(0.5) : Color.secondary.opacity(0.2)))
                            .frame(width: 12, height: 12)
                            .overlay {
                                if selectedTab == index {
                                    Circle()
                                        .stroke(Color.accentColor.opacity(0.3), lineWidth: 2)
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

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    MainTabView()
        .environmentObject(NotesManager())
}
