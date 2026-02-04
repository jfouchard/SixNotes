import Foundation
import SwiftUI

@MainActor
class NotesManager: ObservableObject {
    @Published var notes: [Note]
    @Published var selectedNoteIndex: Int {
        didSet {
            UserDefaults.standard.set(selectedNoteIndex, forKey: selectedNoteKey)
        }
    }
    @Published var textFont: FontSetting {
        didSet {
            if let encoded = try? JSONEncoder().encode(textFont) {
                UserDefaults.standard.set(encoded, forKey: textFontKey)
            }
        }
    }
    @Published var codeFont: FontSetting {
        didSet {
            if let encoded = try? JSONEncoder().encode(codeFont) {
                UserDefaults.standard.set(encoded, forKey: codeFontKey)
            }
        }
    }

    // Sync properties
    @Published var isSyncEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isSyncEnabled, forKey: syncEnabledKey)
            if isSyncEnabled {
                Task { await initializeSync() }
                startPeriodicSync()
            } else {
                stopPeriodicSync()
            }
        }
    }
    @Published var isSyncing: Bool = false
    @Published var lastSyncDate: Date?
    @Published var syncError: String?

    let syncEngine: CloudKitSyncEngine

    private let saveKey = "SixNotes.notes"
    private let selectedNoteKey = "SixNotes.selectedNote"
    private let textFontKey = "SixNotes.textFont"
    private let codeFontKey = "SixNotes.codeFont"
    private let syncEnabledKey = "SixNotes.syncEnabled"

    init() {
        self.syncEngine = CloudKitSyncEngine()

        // Load notes
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let decoded = try? JSONDecoder().decode([Note].self, from: data) {
            self.notes = decoded
        } else {
            self.notes = (0..<6).map { Note(id: $0) }
        }

        // Load selected note index
        let savedIndex = UserDefaults.standard.integer(forKey: selectedNoteKey)
        self.selectedNoteIndex = (0..<6).contains(savedIndex) ? savedIndex : 0

        // Load text font
        if let data = UserDefaults.standard.data(forKey: textFontKey),
           let font = try? JSONDecoder().decode(FontSetting.self, from: data) {
            self.textFont = font
        } else {
            self.textFont = .defaultText
        }

        // Load code font
        if let data = UserDefaults.standard.data(forKey: codeFontKey),
           let font = try? JSONDecoder().decode(FontSetting.self, from: data) {
            self.codeFont = font
        } else {
            self.codeFont = .defaultMono
        }

        // Load sync preference
        self.isSyncEnabled = UserDefaults.standard.bool(forKey: syncEnabledKey)

        #if DEBUG
        print("[NotesManager] Init - isSyncEnabled: \(isSyncEnabled)")
        #endif

        // Initialize sync if enabled
        if isSyncEnabled {
            Task { await initializeSync() }
        }

        // Start periodic sync for development (push notifications may not work in simulator)
        startPeriodicSync()
    }

    private var periodicSyncTimer: Timer?

    private func startPeriodicSync() {
        periodicSyncTimer?.invalidate()
        guard isSyncEnabled else { return }
        periodicSyncTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, self.isSyncEnabled else { return }
                #if DEBUG
                print("[NotesManager] Periodic sync check")
                #endif
                await self.performSync()
            }
        }
    }

    private func stopPeriodicSync() {
        periodicSyncTimer?.invalidate()
        periodicSyncTimer = nil
    }

    // MARK: - Note Operations

    func noteBinding(for index: Int) -> Binding<String> {
        Binding(
            get: { self.notes[index].content },
            set: { newValue in
                self.notes[index].content = newValue
                self.notes[index].lastModified = Date()
                self.notes[index].syncState = .pendingUpload
                self.save()
                self.triggerDebouncedSync()
            }
        )
    }

    func selectNote(_ index: Int) {
        guard index >= 0 && index < 6 else { return }
        selectedNoteIndex = index
    }

    func hasContent(at index: Int) -> Bool {
        guard index >= 0 && index < notes.count else { return false }
        return !notes[index].content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func saveCursorPosition(_ position: Int, for index: Int) {
        notes[index].cursorPosition = position
        save()
    }

    func getCursorPosition(for index: Int) -> Int {
        return notes[index].cursorPosition
    }

    func isPlainText(at index: Int) -> Bool {
        guard index >= 0 && index < notes.count else { return false }
        return notes[index].isPlainText
    }

    func setPlainText(_ isPlainText: Bool, for index: Int) {
        guard index >= 0 && index < notes.count else { return }
        notes[index].isPlainText = isPlainText
        notes[index].lastModified = Date()
        notes[index].syncState = .pendingUpload
        save()
        triggerDebouncedSync()
    }

    func togglePlainText(for index: Int) {
        guard index >= 0 && index < notes.count else { return }
        notes[index].isPlainText.toggle()
        notes[index].lastModified = Date()
        notes[index].syncState = .pendingUpload
        save()
        triggerDebouncedSync()
    }

    // MARK: - Persistence

    private func save() {
        if let encoded = try? JSONEncoder().encode(notes) {
            UserDefaults.standard.set(encoded, forKey: saveKey)
        }
    }

    // MARK: - Sync Operations

    private func initializeSync() async {
        #if DEBUG
        print("[NotesManager] initializeSync called")
        #endif

        await syncEngine.checkAccountStatus()

        #if DEBUG
        print("[NotesManager] Account status: \(syncEngine.accountStatus)")
        #endif

        guard syncEngine.accountStatus == .available else {
            syncError = "iCloud not available"
            #if DEBUG
            print("[NotesManager] iCloud not available, aborting sync init")
            #endif
            return
        }

        do {
            try await syncEngine.setupSubscriptions()
            #if DEBUG
            print("[NotesManager] Subscriptions set up, performing initial sync")
            #endif
            await performSync()
        } catch {
            syncError = error.localizedDescription
            #if DEBUG
            print("[NotesManager] Sync init error: \(error.localizedDescription)")
            #endif
        }
    }

    func performSync() async {
        guard isSyncEnabled else { return }
        guard syncEngine.accountStatus == .available else {
            syncError = "iCloud not available"
            return
        }

        isSyncing = true
        syncError = nil

        do {
            let updatedNotes = try await syncEngine.performFullSync(localNotes: notes)
            notes = updatedNotes
            save()
            lastSyncDate = Date()
            syncError = nil
        } catch {
            syncError = error.localizedDescription
        }

        isSyncing = false
    }

    private func triggerDebouncedSync() {
        guard isSyncEnabled else {
            #if DEBUG
            print("[NotesManager] triggerDebouncedSync skipped - sync not enabled")
            #endif
            return
        }

        #if DEBUG
        print("[NotesManager] triggerDebouncedSync called - will sync in 2 seconds")
        #endif

        syncEngine.debouncedSync(localNotes: notes) { [weak self] updatedNotes in
            guard let self = self else { return }
            #if DEBUG
            print("[NotesManager] Debounced sync completed")
            #endif
            Task { @MainActor in
                self.notes = updatedNotes
                self.save()
                self.lastSyncDate = Date()
            }
        }
    }

    func handleRemoteNotification(userInfo: [AnyHashable: Any]) async {
        guard isSyncEnabled else { return }

        do {
            let updatedNotes = try await syncEngine.handleRemoteNotification(
                userInfo: userInfo,
                localNotes: notes
            )
            notes = updatedNotes
            save()
            lastSyncDate = Date()
        } catch {
            syncError = error.localizedDescription
        }
    }
}
