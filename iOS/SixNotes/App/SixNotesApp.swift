import SwiftUI

@main
struct SixNotesApp: App {
    @StateObject private var notesManager = NotesManager()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(notesManager)
        }
    }
}
