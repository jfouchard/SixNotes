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
                    appDelegate.notesManager = notesManager
                    configureWindow()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 600, height: 500)
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandGroup(after: .toolbar) {
                Button("Show Markdown Preview") {
                    NotificationCenter.default.post(name: .togglePreview, object: nil)
                }
                .keyboardShortcut("p", modifiers: .command)

                Divider()

                Button(notesManager.currentNoteIsPlainText ? "Show Rich Text" : "Show Plain Text") {
                    notesManager.setPlainText(!notesManager.currentNoteIsPlainText)
                }
                .keyboardShortcut("t", modifiers: [.command, .shift])
            }
            CommandMenu("Notes") {
                ForEach(0..<6, id: \.self) { index in
                    Button("Note \(index + 1)") {
                        notesManager.selectNote(index)
                    }
                    .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
                }
            }
            // Enable Edit > Find menu with Cmd+F
            TextEditingCommands()
        }

        Settings {
            SettingsView()
                .environmentObject(notesManager)
        }
    }

    private func configureWindow() {
        DispatchQueue.main.async {
            if let window = NSApplication.shared.windows.first {
                // Remove minimize and zoom buttons (yellow and green)
                window.standardWindowButton(.miniaturizeButton)?.isHidden = true
                window.standardWindowButton(.zoomButton)?.isHidden = true
            }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var notesManager: NotesManager?
    private let windowFrameKey = "SixNotes.mainWindowFrame"

    func applicationDidFinishLaunching(_ notification: Notification) {
        registerForPushNotifications()

        // Disable window tabbing system-wide for this app
        NSWindow.allowsAutomaticWindowTabbing = false

        // Configure main window
        DispatchQueue.main.async {
            if let window = NSApplication.shared.windows.first {
                window.delegate = self
                window.tabbingMode = .disallowed
                // Restore saved frame if available
                if let frameString = UserDefaults.standard.string(forKey: self.windowFrameKey) {
                    window.setFrame(NSRectFromString(frameString), display: true)
                }
            }
        }
    }

    func windowDidResize(_ notification: Notification) {
        saveWindowFrame()
    }

    func windowDidMove(_ notification: Notification) {
        saveWindowFrame()
    }

    private func saveWindowFrame() {
        if let window = NSApplication.shared.windows.first {
            let frameString = NSStringFromRect(window.frame)
            UserDefaults.standard.set(frameString, forKey: windowFrameKey)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Flush any pending text editor saves before quitting
        NoteTextEditor.Coordinator.flushAll()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            // Reopen the main window when dock icon is clicked and no windows are visible
            for window in sender.windows {
                window.makeKeyAndOrderFront(self)
                return true
            }
        }
        return true
    }

    private func registerForPushNotifications() {
        NSApplication.shared.registerForRemoteNotifications()
    }

    func application(_ application: NSApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // CloudKit handles its own subscription-based notifications
    }

    func application(_ application: NSApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Failed to register for remote notifications: \(error)")
    }

    func application(_ application: NSApplication, didReceiveRemoteNotification userInfo: [String: Any]) {
        Task { @MainActor in
            guard let notesManager = notesManager else { return }
            await notesManager.handleRemoteNotification(userInfo: userInfo)
        }
    }
}

extension Notification.Name {
    static let togglePreview = Notification.Name("togglePreview")
}
