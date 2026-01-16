import Foundation

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

    // CloudKit sync metadata
    var cloudKitRecordName: String?
    var cloudKitChangeTag: String?
    var syncState: SyncState
    var lastSyncAttempt: Date?
    var lastSyncError: String?

    init(id: Int, content: String = "", cursorPosition: Int = 0) {
        self.id = id
        self.content = content
        self.lastModified = Date()
        self.cursorPosition = cursorPosition
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

        // Sync fields with defaults for migration
        cloudKitRecordName = try container.decodeIfPresent(String.self, forKey: .cloudKitRecordName) ?? "note_\(id)"
        cloudKitChangeTag = try container.decodeIfPresent(String.self, forKey: .cloudKitChangeTag)
        syncState = try container.decodeIfPresent(SyncState.self, forKey: .syncState) ?? .neverSynced
        lastSyncAttempt = try container.decodeIfPresent(Date.self, forKey: .lastSyncAttempt)
        lastSyncError = try container.decodeIfPresent(String.self, forKey: .lastSyncError)
    }
}
