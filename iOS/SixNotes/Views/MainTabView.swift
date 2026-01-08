import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var notesManager: NotesManager
    @State private var selectedTab = 0

    static let noteColors: [Color] = [
        Color(red: 0.90, green: 0.30, blue: 0.35),  // Red
        Color(red: 0.95, green: 0.55, blue: 0.25),  // Orange
        Color(red: 0.95, green: 0.75, blue: 0.25),  // Yellow
        Color(red: 0.40, green: 0.78, blue: 0.45),  // Green
        Color(red: 0.35, green: 0.60, blue: 0.90),  // Blue
        Color(red: 0.70, green: 0.45, blue: 0.85),  // Purple
    ]

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

#Preview {
    MainTabView()
        .environmentObject(NotesManager())
}
