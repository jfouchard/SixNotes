import SwiftUI

@main
struct SixNotesApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var notesManager = NotesManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(notesManager)
                .onAppear {
                    configureWindow()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 600, height: 500)
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandGroup(replacing: .appSettings) {
                Button("Settings...") {
                    NotificationCenter.default.post(name: .showSettings, object: nil)
                }
                .keyboardShortcut(",", modifiers: .command)
            }
            CommandGroup(after: .toolbar) {
                Button("Show Markdown Preview") {
                    NotificationCenter.default.post(name: .togglePreview, object: nil)
                }
                .keyboardShortcut("p", modifiers: .command)
            }
            CommandMenu("Notes") {
                ForEach(0..<6, id: \.self) { index in
                    Button("Note \(index + 1)") {
                        notesManager.selectNote(index)
                    }
                    .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
                }
            }
        }
    }

    private func configureWindow() {
        DispatchQueue.main.async {
            if let window = NSApplication.shared.windows.first {
                // Remove minimize and zoom buttons (yellow and green)
                window.standardWindowButton(.miniaturizeButton)?.isHidden = true
                window.standardWindowButton(.zoomButton)?.isHidden = true

                // Enable window position/size restoration
                window.setFrameAutosaveName("SixNotesMainWindow")
            }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

extension Notification.Name {
    static let showSettings = Notification.Name("showSettings")
    static let togglePreview = Notification.Name("togglePreview")
}
