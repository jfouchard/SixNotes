import Foundation
import CloudKit

enum CloudKitSyncError: Error, LocalizedError {
    case notAuthenticated
    case networkUnavailable
    case quotaExceeded
    case serverError(String)
    case recordNotFound
    case conflictDetected(serverRecord: CKRecord, localNote: Note)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not signed in to iCloud"
        case .networkUnavailable:
            return "Network unavailable"
        case .quotaExceeded:
            return "iCloud storage quota exceeded"
        case .serverError(let message):
            return "Server error: \(message)"
        case .recordNotFound:
            return "Record not found"
        case .conflictDetected:
            return "Conflict detected"
        }
    }
}

enum CloudKitAccountStatus {
    case available
    case noAccount
    case restricted
    case couldNotDetermine
    case temporarilyUnavailable
}

@MainActor
class CloudKitSyncEngine: ObservableObject {
    static let recordType = "Note"
    static let containerIdentifier = "iCloud.org.fouchard.SixNotes"

    private let container: CKContainer
    private let privateDatabase: CKDatabase

    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var lastSyncError: String?
    @Published var accountStatus: CloudKitAccountStatus = .couldNotDetermine

    private var syncDebounceTask: Task<Void, Never>?
    private let debounceInterval: TimeInterval = 2.0

    init() {
        self.container = CKContainer(identifier: CloudKitSyncEngine.containerIdentifier)
        self.privateDatabase = container.privateCloudDatabase
    }

    // MARK: - Account Status

    func checkAccountStatus() async {
        do {
            let status = try await container.accountStatus()
            switch status {
            case .available:
                accountStatus = .available
            case .noAccount:
                accountStatus = .noAccount
            case .restricted:
                accountStatus = .restricted
            case .couldNotDetermine:
                accountStatus = .couldNotDetermine
            case .temporarilyUnavailable:
                accountStatus = .temporarilyUnavailable
            @unknown default:
                accountStatus = .couldNotDetermine
            }
            #if DEBUG
            print("[CloudKit] Account status: \(accountStatus)")
            #endif
        } catch {
            accountStatus = .couldNotDetermine
            lastSyncError = error.localizedDescription
            #if DEBUG
            print("[CloudKit] Account status check failed: \(error.localizedDescription)")
            #endif
        }
    }

    // MARK: - Subscriptions

    func setupSubscriptions() async throws {
        guard accountStatus == .available else {
            throw CloudKitSyncError.notAuthenticated
        }

        // First, ensure the schema exists by trying to create it
        await ensureSchemaExists()

        let subscriptionID = "note-changes"

        // Check if subscription already exists
        do {
            _ = try await privateDatabase.subscription(for: subscriptionID)
            return // Subscription already exists
        } catch {
            // Subscription doesn't exist, create it
        }

        let subscription = CKQuerySubscription(
            recordType: CloudKitSyncEngine.recordType,
            predicate: NSPredicate(value: true),
            subscriptionID: subscriptionID,
            options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
        )

        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo

        try await privateDatabase.save(subscription)
    }

    /// Creates the schema in development by saving a dummy record if needed
    private func ensureSchemaExists() async {
        // Try to query - if record type doesn't exist, create a record to establish schema
        let query = CKQuery(recordType: CloudKitSyncEngine.recordType, predicate: NSPredicate(value: true))

        do {
            _ = try await privateDatabase.records(matching: query, resultsLimit: 1)
            #if DEBUG
            print("[CloudKit] Schema exists")
            #endif
        } catch let error as CKError where error.code == .unknownItem {
            #if DEBUG
            print("[CloudKit] Schema doesn't exist, creating...")
            #endif
            // Record type doesn't exist - create a placeholder record to establish schema
            // This only works in Development environment
            let recordID = CKRecord.ID(recordName: "note_0")
            let record = CKRecord(recordType: CloudKitSyncEngine.recordType, recordID: recordID)
            record["content"] = "" as CKRecordValue
            record["lastModified"] = Date() as CKRecordValue
            record["cursorPosition"] = 0 as CKRecordValue

            do {
                _ = try await privateDatabase.save(record)
                #if DEBUG
                print("[CloudKit] Schema created successfully")
                #endif
            } catch {
                #if DEBUG
                print("[CloudKit] Failed to create schema: \(error.localizedDescription)")
                #endif
            }
        } catch {
            #if DEBUG
            print("[CloudKit] Schema check error: \(error.localizedDescription)")
            #endif
        }
    }

    // MARK: - Sync Operations

    func performFullSync(localNotes: [Note]) async throws -> [Note] {
        guard accountStatus == .available else {
            throw CloudKitSyncError.notAuthenticated
        }

        isSyncing = true
        defer { isSyncing = false }

        #if DEBUG
        print("[CloudKit] Starting full sync with \(localNotes.count) local notes")
        #endif

        // Fetch all records from CloudKit
        let serverRecords = try await fetchAllRecords()

        #if DEBUG
        print("[CloudKit] Fetched \(serverRecords.count) server records")
        #endif

        // Merge local and server notes
        var mergedNotes = localNotes

        for serverRecord in serverRecords {
            guard let noteIndex = extractNoteIndex(from: serverRecord.recordID.recordName) else {
                continue
            }

            guard noteIndex >= 0 && noteIndex < mergedNotes.count else {
                continue
            }

            let localNote = mergedNotes[noteIndex]
            let serverLastModified = serverRecord["lastModified"] as? Date ?? Date.distantPast

            // Last write wins conflict resolution
            if serverLastModified > localNote.lastModified {
                // Server wins - update local
                var updatedNote = noteFromRecord(serverRecord, id: noteIndex)
                updatedNote.syncState = .synced
                updatedNote.cloudKitChangeTag = serverRecord.recordChangeTag
                mergedNotes[noteIndex] = updatedNote
            } else if localNote.lastModified > serverLastModified && localNote.syncState != .synced {
                // Local wins - upload to server
                let updatedNote = try await uploadNote(localNote)
                mergedNotes[noteIndex] = updatedNote
            } else {
                // Already synced
                var updatedNote = localNote
                updatedNote.syncState = .synced
                updatedNote.cloudKitChangeTag = serverRecord.recordChangeTag
                mergedNotes[noteIndex] = updatedNote
            }
        }

        // Upload any notes that don't exist on server
        for (index, note) in mergedNotes.enumerated() {
            if note.syncState == .neverSynced || note.syncState == .pendingUpload {
                let recordName = "note_\(index)"
                let existsOnServer = serverRecords.contains { $0.recordID.recordName == recordName }

                if !existsOnServer {
                    let updatedNote = try await uploadNote(note)
                    mergedNotes[index] = updatedNote
                }
            }
        }

        lastSyncDate = Date()
        lastSyncError = nil

        return mergedNotes
    }

    func uploadNote(_ note: Note) async throws -> Note {
        guard accountStatus == .available else {
            throw CloudKitSyncError.notAuthenticated
        }

        let recordID = CKRecord.ID(recordName: note.cloudKitRecordName ?? "note_\(note.id)")
        var record: CKRecord

        // Try to fetch existing record to update
        do {
            record = try await privateDatabase.record(for: recordID)
        } catch {
            // Record doesn't exist, create new one
            record = CKRecord(recordType: CloudKitSyncEngine.recordType, recordID: recordID)
        }

        record["content"] = note.content as CKRecordValue
        record["lastModified"] = note.lastModified as CKRecordValue
        record["cursorPosition"] = note.cursorPosition as CKRecordValue

        do {
            let savedRecord = try await privateDatabase.save(record)

            var updatedNote = note
            updatedNote.syncState = .synced
            updatedNote.cloudKitChangeTag = savedRecord.recordChangeTag
            updatedNote.lastSyncAttempt = Date()
            updatedNote.lastSyncError = nil

            return updatedNote
        } catch let error as CKError {
            return try await handleCKError(error, for: note, record: record)
        }
    }

    func debouncedSync(localNotes: [Note], completion: @escaping ([Note]) -> Void) {
        syncDebounceTask?.cancel()

        syncDebounceTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(debounceInterval * 1_000_000_000))

            guard !Task.isCancelled else { return }

            do {
                let updatedNotes = try await performFullSync(localNotes: localNotes)
                completion(updatedNotes)
            } catch {
                lastSyncError = error.localizedDescription
            }
        }
    }

    func handleRemoteNotification(userInfo: [AnyHashable: Any], localNotes: [Note]) async throws -> [Note] {
        guard let notification = CKNotification(fromRemoteNotificationDictionary: userInfo) else {
            return localNotes
        }

        guard notification.subscriptionID == "note-changes" else {
            return localNotes
        }

        // Perform full sync to get latest changes
        return try await performFullSync(localNotes: localNotes)
    }

    // MARK: - Private Helpers

    private func fetchAllRecords() async throws -> [CKRecord] {
        let query = CKQuery(recordType: CloudKitSyncEngine.recordType, predicate: NSPredicate(value: true))
        var allRecords: [CKRecord] = []

        let (results, _) = try await privateDatabase.records(matching: query)

        for (_, result) in results {
            switch result {
            case .success(let record):
                allRecords.append(record)
            case .failure:
                continue
            }
        }

        return allRecords
    }

    private func extractNoteIndex(from recordName: String) -> Int? {
        let prefix = "note_"
        guard recordName.hasPrefix(prefix) else { return nil }
        return Int(recordName.dropFirst(prefix.count))
    }

    private func noteFromRecord(_ record: CKRecord, id: Int) -> Note {
        var note = Note(id: id)
        note.content = record["content"] as? String ?? ""
        note.lastModified = record["lastModified"] as? Date ?? Date()
        note.cursorPosition = record["cursorPosition"] as? Int ?? 0
        note.cloudKitRecordName = record.recordID.recordName
        note.cloudKitChangeTag = record.recordChangeTag
        note.syncState = .synced
        return note
    }

    private func handleCKError(_ error: CKError, for note: Note, record: CKRecord) async throws -> Note {
        var updatedNote = note
        updatedNote.lastSyncAttempt = Date()

        switch error.code {
        case .serverRecordChanged:
            // Conflict - server has newer version
            if let serverRecord = error.userInfo[CKRecordChangedErrorServerRecordKey] as? CKRecord {
                let serverLastModified = serverRecord["lastModified"] as? Date ?? Date.distantPast

                // Last write wins
                if note.lastModified > serverLastModified {
                    // Our change is newer, retry with server's record
                    let retryRecord = serverRecord
                    retryRecord["content"] = note.content as CKRecordValue
                    retryRecord["lastModified"] = note.lastModified as CKRecordValue
                    retryRecord["cursorPosition"] = note.cursorPosition as CKRecordValue

                    let savedRecord = try await privateDatabase.save(retryRecord)
                    updatedNote.syncState = .synced
                    updatedNote.cloudKitChangeTag = savedRecord.recordChangeTag
                    updatedNote.lastSyncError = nil
                } else {
                    // Server's change is newer, accept server version
                    updatedNote = noteFromRecord(serverRecord, id: note.id)
                }
            }
            return updatedNote

        case .networkUnavailable, .networkFailure:
            updatedNote.syncState = .pendingUpload
            updatedNote.lastSyncError = CloudKitSyncError.networkUnavailable.localizedDescription
            return updatedNote

        case .quotaExceeded:
            updatedNote.syncState = .pendingUpload
            updatedNote.lastSyncError = CloudKitSyncError.quotaExceeded.localizedDescription
            throw CloudKitSyncError.quotaExceeded

        case .notAuthenticated:
            updatedNote.syncState = .pendingUpload
            updatedNote.lastSyncError = CloudKitSyncError.notAuthenticated.localizedDescription
            throw CloudKitSyncError.notAuthenticated

        default:
            updatedNote.syncState = .pendingUpload
            updatedNote.lastSyncError = error.localizedDescription
            throw CloudKitSyncError.serverError(error.localizedDescription)
        }
    }
}
