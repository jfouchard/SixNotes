import XCTest
@testable import SixNotes

final class NoteTests: XCTestCase {

    // MARK: - Initialization Tests

    func testNoteInitializationWithDefaults() {
        let note = Note(id: 0)

        XCTAssertEqual(note.id, 0)
        XCTAssertEqual(note.content, "")
        XCTAssertEqual(note.cursorPosition, 0)
        XCTAssertNotNil(note.lastModified)
        XCTAssertEqual(note.cloudKitRecordName, "note_0")
        XCTAssertNil(note.cloudKitChangeTag)
        XCTAssertEqual(note.syncState, .neverSynced)
        XCTAssertNil(note.lastSyncAttempt)
        XCTAssertNil(note.lastSyncError)
    }

    func testNoteInitializationWithContent() {
        let note = Note(id: 3, content: "Hello, World!")

        XCTAssertEqual(note.id, 3)
        XCTAssertEqual(note.content, "Hello, World!")
        XCTAssertEqual(note.cursorPosition, 0)
        XCTAssertEqual(note.cloudKitRecordName, "note_3")
    }

    func testNoteInitializationWithCursorPosition() {
        let note = Note(id: 5, content: "Test content", cursorPosition: 42)

        XCTAssertEqual(note.id, 5)
        XCTAssertEqual(note.content, "Test content")
        XCTAssertEqual(note.cursorPosition, 42)
    }

    // MARK: - Codable Tests

    func testNoteEncodingAndDecoding() throws {
        var originalNote = Note(id: 2, content: "Test note content", cursorPosition: 10)
        originalNote.syncState = .synced
        originalNote.cloudKitChangeTag = "test-tag"

        let encoder = JSONEncoder()
        let data = try encoder.encode(originalNote)

        let decoder = JSONDecoder()
        let decodedNote = try decoder.decode(Note.self, from: data)

        XCTAssertEqual(decodedNote.id, originalNote.id)
        XCTAssertEqual(decodedNote.content, originalNote.content)
        XCTAssertEqual(decodedNote.cursorPosition, originalNote.cursorPosition)
        XCTAssertEqual(decodedNote.syncState, originalNote.syncState)
        XCTAssertEqual(decodedNote.cloudKitChangeTag, originalNote.cloudKitChangeTag)
    }

    func testNoteArrayEncodingAndDecoding() throws {
        let notes = (0..<6).map { Note(id: $0, content: "Note \($0)") }

        let encoder = JSONEncoder()
        let data = try encoder.encode(notes)

        let decoder = JSONDecoder()
        let decodedNotes = try decoder.decode([Note].self, from: data)

        XCTAssertEqual(decodedNotes.count, 6)
        for (index, note) in decodedNotes.enumerated() {
            XCTAssertEqual(note.id, index)
            XCTAssertEqual(note.content, "Note \(index)")
        }
    }

    func testNoteDecodingFromJSON() throws {
        let json = """
        {
            "id": 1,
            "content": "JSON content",
            "lastModified": 0,
            "cursorPosition": 5
        }
        """
        let data = json.data(using: .utf8)!

        let decoder = JSONDecoder()
        let note = try decoder.decode(Note.self, from: data)

        XCTAssertEqual(note.id, 1)
        XCTAssertEqual(note.content, "JSON content")
        XCTAssertEqual(note.cursorPosition, 5)
        // Migration should set default sync values
        XCTAssertEqual(note.cloudKitRecordName, "note_1")
        XCTAssertNil(note.cloudKitChangeTag)
        XCTAssertEqual(note.syncState, .neverSynced)
    }

    func testNoteMigrationFromOldFormat() throws {
        // Simulates JSON from before sync fields were added
        let legacyJSON = """
        {
            "id": 2,
            "content": "Legacy note",
            "lastModified": 1000,
            "cursorPosition": 15
        }
        """
        let data = legacyJSON.data(using: .utf8)!

        let decoder = JSONDecoder()
        let note = try decoder.decode(Note.self, from: data)

        XCTAssertEqual(note.id, 2)
        XCTAssertEqual(note.content, "Legacy note")
        XCTAssertEqual(note.cloudKitRecordName, "note_2")
        XCTAssertEqual(note.syncState, .neverSynced)
        XCTAssertNil(note.cloudKitChangeTag)
    }

    func testNoteDecodingWithSyncFields() throws {
        let json = """
        {
            "id": 1,
            "content": "Synced content",
            "lastModified": 0,
            "cursorPosition": 5,
            "cloudKitRecordName": "note_1",
            "cloudKitChangeTag": "abc123",
            "syncState": "synced",
            "lastSyncAttempt": 1609459200,
            "lastSyncError": null
        }
        """
        let data = json.data(using: .utf8)!

        let decoder = JSONDecoder()
        let note = try decoder.decode(Note.self, from: data)

        XCTAssertEqual(note.cloudKitRecordName, "note_1")
        XCTAssertEqual(note.cloudKitChangeTag, "abc123")
        XCTAssertEqual(note.syncState, .synced)
        XCTAssertNotNil(note.lastSyncAttempt)
        XCTAssertNil(note.lastSyncError)
    }

    // MARK: - Identifiable Tests

    func testNoteIdentifiable() {
        let note1 = Note(id: 0)
        let note2 = Note(id: 1)
        let note3 = Note(id: 0)

        XCTAssertEqual(note1.id, 0)
        XCTAssertEqual(note2.id, 1)
        XCTAssertEqual(note1.id, note3.id)
    }

    // MARK: - Mutability Tests

    func testNoteContentMutation() {
        var note = Note(id: 0)
        note.content = "Updated content"

        XCTAssertEqual(note.content, "Updated content")
    }

    func testNoteCursorPositionMutation() {
        var note = Note(id: 0)
        note.cursorPosition = 100

        XCTAssertEqual(note.cursorPosition, 100)
    }

    func testNoteLastModifiedMutation() {
        var note = Note(id: 0)
        let newDate = Date(timeIntervalSince1970: 1000)
        note.lastModified = newDate

        XCTAssertEqual(note.lastModified, newDate)
    }

    // MARK: - Sync State Tests

    func testNoteSyncStateMutation() {
        var note = Note(id: 0)
        XCTAssertEqual(note.syncState, .neverSynced)

        note.syncState = .pendingUpload
        XCTAssertEqual(note.syncState, .pendingUpload)

        note.syncState = .synced
        XCTAssertEqual(note.syncState, .synced)
    }

    func testNoteCloudKitChangeTagMutation() {
        var note = Note(id: 0)
        XCTAssertNil(note.cloudKitChangeTag)

        note.cloudKitChangeTag = "new-tag-123"
        XCTAssertEqual(note.cloudKitChangeTag, "new-tag-123")
    }

    func testNoteSyncErrorMutation() {
        var note = Note(id: 0)
        XCTAssertNil(note.lastSyncError)

        note.lastSyncError = "Network unavailable"
        XCTAssertEqual(note.lastSyncError, "Network unavailable")
    }
}

// MARK: - SyncState Tests

final class SyncStateTests: XCTestCase {

    func testSyncStateRawValues() {
        XCTAssertEqual(SyncState.synced.rawValue, "synced")
        XCTAssertEqual(SyncState.pendingUpload.rawValue, "pendingUpload")
        XCTAssertEqual(SyncState.pendingDownload.rawValue, "pendingDownload")
        XCTAssertEqual(SyncState.conflict.rawValue, "conflict")
        XCTAssertEqual(SyncState.neverSynced.rawValue, "neverSynced")
    }

    func testSyncStateEncodingAndDecoding() throws {
        let states: [SyncState] = [.synced, .pendingUpload, .pendingDownload, .conflict, .neverSynced]

        for state in states {
            let encoder = JSONEncoder()
            let data = try encoder.encode(state)

            let decoder = JSONDecoder()
            let decodedState = try decoder.decode(SyncState.self, from: data)

            XCTAssertEqual(decodedState, state)
        }
    }
}
