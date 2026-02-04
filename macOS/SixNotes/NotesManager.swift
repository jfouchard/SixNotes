import Foundation
import SwiftUI

enum SyncState: String, Codable {
    case synced
    case pendingUpload
    case pendingDownload
    case conflict
    case neverSynced
}

struct Note: Codable, Identifiable {
    let id: Int
    var content: String
    var lastModified: Date
    var cursorPosition: Int
    var isPlainText: Bool

    // CloudKit sync metadata
    var cloudKitRecordName: String?
    var cloudKitChangeTag: String?
    var syncState: SyncState
    var lastSyncAttempt: Date?
    var lastSyncError: String?

    init(id: Int, content: String = "", cursorPosition: Int = 0, isPlainText: Bool = false) {
        self.id = id
        self.content = content
        self.lastModified = Date()
        self.cursorPosition = cursorPosition
        self.isPlainText = isPlainText
        self.cloudKitRecordName = "note_\(id)"
        self.cloudKitChangeTag = nil
        self.syncState = .neverSynced
        self.lastSyncAttempt = nil
        self.lastSyncError = nil
    }

    // Custom decoding to support migration from old Note format
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(Int.self, forKey: .id)
        content = try container.decode(String.self, forKey: .content)
        lastModified = try container.decode(Date.self, forKey: .lastModified)
        cursorPosition = try container.decode(Int.self, forKey: .cursorPosition)
        isPlainText = try container.decodeIfPresent(Bool.self, forKey: .isPlainText) ?? false

        // Sync fields with defaults for migration
        cloudKitRecordName = try container.decodeIfPresent(String.self, forKey: .cloudKitRecordName) ?? "note_\(id)"
        cloudKitChangeTag = try container.decodeIfPresent(String.self, forKey: .cloudKitChangeTag)
        syncState = try container.decodeIfPresent(SyncState.self, forKey: .syncState) ?? .neverSynced
        lastSyncAttempt = try container.decodeIfPresent(Date.self, forKey: .lastSyncAttempt)
        lastSyncError = try container.decodeIfPresent(String.self, forKey: .lastSyncError)
    }
}

struct FontSetting: Codable, Equatable {
    var name: String
    var size: CGFloat

    static let availableFonts: [String] = {
        var fonts = ["System", "New York"]
        let monoFonts = ["SF Mono", "Menlo", "Monaco", "Courier New"]
        let additionalFonts = ["Helvetica Neue", "Georgia", "Palatino"]
        return fonts + monoFonts + additionalFonts
    }()

    static let availableMonoFonts: [String] = ["SF Mono", "Menlo", "Monaco", "Courier New"]

    static let defaultText = FontSetting(name: "System", size: 14)
    static let defaultMono = FontSetting(name: "SF Mono", size: 13)

    var font: Font {
        if name == "System" {
            return .system(size: size)
        } else if name == "New York" {
            return .system(size: size, design: .serif)
        } else {
            return .custom(name, size: size)
        }
    }

    var nsFont: NSFont {
        if name == "System" {
            return NSFont.systemFont(ofSize: size)
        } else if name == "New York" {
            return NSFont(name: "New York", size: size) ?? NSFont.systemFont(ofSize: size)
        } else {
            return NSFont(name: name, size: size) ?? NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
        }
    }
}

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

    var currentNote: Binding<String> {
        Binding(
            get: { self.notes[self.selectedNoteIndex].content },
            set: { newValue in
                self.notes[self.selectedNoteIndex].content = newValue
                self.notes[self.selectedNoteIndex].lastModified = Date()
                self.notes[self.selectedNoteIndex].syncState = .pendingUpload
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

    func saveCursorPosition(_ position: Int) {
        notes[selectedNoteIndex].cursorPosition = position
        save()
    }

    func getCursorPosition() -> Int {
        return notes[selectedNoteIndex].cursorPosition
    }

    var currentNoteIsPlainText: Bool {
        notes[selectedNoteIndex].isPlainText
    }

    func togglePlainText() {
        notes[selectedNoteIndex].isPlainText.toggle()
        notes[selectedNoteIndex].lastModified = Date()
        notes[selectedNoteIndex].syncState = .pendingUpload
        save()
        triggerDebouncedSync()
    }

    func setPlainText(_ isPlainText: Bool) {
        notes[selectedNoteIndex].isPlainText = isPlainText
        notes[selectedNoteIndex].lastModified = Date()
        notes[selectedNoteIndex].syncState = .pendingUpload
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
