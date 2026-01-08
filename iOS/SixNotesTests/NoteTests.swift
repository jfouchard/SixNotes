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
    }

    func testNoteInitializationWithContent() {
        let note = Note(id: 3, content: "Hello, World!")

        XCTAssertEqual(note.id, 3)
        XCTAssertEqual(note.content, "Hello, World!")
        XCTAssertEqual(note.cursorPosition, 0)
    }

    func testNoteInitializationWithCursorPosition() {
        let note = Note(id: 5, content: "Test content", cursorPosition: 42)

        XCTAssertEqual(note.id, 5)
        XCTAssertEqual(note.content, "Test content")
        XCTAssertEqual(note.cursorPosition, 42)
    }

    // MARK: - Codable Tests

    func testNoteEncodingAndDecoding() throws {
        let originalNote = Note(id: 2, content: "Test note content", cursorPosition: 10)

        let encoder = JSONEncoder()
        let data = try encoder.encode(originalNote)

        let decoder = JSONDecoder()
        let decodedNote = try decoder.decode(Note.self, from: data)

        XCTAssertEqual(decodedNote.id, originalNote.id)
        XCTAssertEqual(decodedNote.content, originalNote.content)
        XCTAssertEqual(decodedNote.cursorPosition, originalNote.cursorPosition)
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
}
