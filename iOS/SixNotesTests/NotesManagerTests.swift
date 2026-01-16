import XCTest
@testable import SixNotes

@MainActor
final class NotesManagerTests: XCTestCase {

    var sut: NotesManager!

    // UserDefaults keys for cleanup
    private let saveKey = "SixNotes.notes"
    private let selectedNoteKey = "SixNotes.selectedNote"
    private let textFontKey = "SixNotes.textFont"
    private let codeFontKey = "SixNotes.codeFont"
    private let syncEnabledKey = "SixNotes.syncEnabled"

    override func setUp() {
        super.setUp()
        // Clear UserDefaults before each test
        clearUserDefaults()
        sut = NotesManager()
    }

    override func tearDown() {
        clearUserDefaults()
        sut = nil
        super.tearDown()
    }

    private func clearUserDefaults() {
        UserDefaults.standard.removeObject(forKey: saveKey)
        UserDefaults.standard.removeObject(forKey: selectedNoteKey)
        UserDefaults.standard.removeObject(forKey: textFontKey)
        UserDefaults.standard.removeObject(forKey: codeFontKey)
        UserDefaults.standard.removeObject(forKey: syncEnabledKey)
    }

    // MARK: - Initialization Tests

    func testInitializationCreates6EmptyNotes() {
        XCTAssertEqual(sut.notes.count, 6)
        for (index, note) in sut.notes.enumerated() {
            XCTAssertEqual(note.id, index)
            XCTAssertEqual(note.content, "")
        }
    }

    func testInitializationDefaultSelectedIndex() {
        XCTAssertEqual(sut.selectedNoteIndex, 0)
    }

    func testInitializationDefaultTextFont() {
        XCTAssertEqual(sut.textFont, FontSetting.defaultText)
    }

    func testInitializationDefaultCodeFont() {
        XCTAssertEqual(sut.codeFont, FontSetting.defaultMono)
    }

    // MARK: - Note Selection Tests

    func testSelectNoteValidIndex() {
        sut.selectNote(3)
        XCTAssertEqual(sut.selectedNoteIndex, 3)
    }

    func testSelectNoteFirstIndex() {
        sut.selectNote(2)
        sut.selectNote(0)
        XCTAssertEqual(sut.selectedNoteIndex, 0)
    }

    func testSelectNoteLastIndex() {
        sut.selectNote(5)
        XCTAssertEqual(sut.selectedNoteIndex, 5)
    }

    func testSelectNoteNegativeIndexIgnored() {
        sut.selectNote(2)
        sut.selectNote(-1)
        XCTAssertEqual(sut.selectedNoteIndex, 2)
    }

    func testSelectNoteTooHighIndexIgnored() {
        sut.selectNote(2)
        sut.selectNote(6)
        XCTAssertEqual(sut.selectedNoteIndex, 2)

        sut.selectNote(100)
        XCTAssertEqual(sut.selectedNoteIndex, 2)
    }

    // MARK: - hasContent Tests

    func testHasContentEmptyNote() {
        XCTAssertFalse(sut.hasContent(at: 0))
    }

    func testHasContentWithContent() {
        sut.notes[0].content = "Hello"
        XCTAssertTrue(sut.hasContent(at: 0))
    }

    func testHasContentWhitespaceOnly() {
        sut.notes[0].content = "   \n\t  "
        XCTAssertFalse(sut.hasContent(at: 0))
    }

    func testHasContentWithWhitespaceAndText() {
        sut.notes[0].content = "  Hello  "
        XCTAssertTrue(sut.hasContent(at: 0))
    }

    func testHasContentInvalidIndexNegative() {
        XCTAssertFalse(sut.hasContent(at: -1))
    }

    func testHasContentInvalidIndexTooHigh() {
        XCTAssertFalse(sut.hasContent(at: 10))
    }

    // MARK: - Note Binding Tests

    func testNoteBindingGet() {
        sut.notes[2].content = "Test content"
        let binding = sut.noteBinding(for: 2)

        XCTAssertEqual(binding.wrappedValue, "Test content")
    }

    func testNoteBindingSet() {
        let binding = sut.noteBinding(for: 1)
        binding.wrappedValue = "New content"

        XCTAssertEqual(sut.notes[1].content, "New content")
    }

    func testNoteBindingSetUpdatesLastModified() {
        let originalDate = sut.notes[0].lastModified

        // Small delay to ensure date difference
        Thread.sleep(forTimeInterval: 0.01)

        let binding = sut.noteBinding(for: 0)
        binding.wrappedValue = "Updated"

        XCTAssertGreaterThan(sut.notes[0].lastModified, originalDate)
    }

    // MARK: - Cursor Position Tests

    func testSaveCursorPosition() {
        sut.saveCursorPosition(42, for: 0)
        XCTAssertEqual(sut.notes[0].cursorPosition, 42)
    }

    func testGetCursorPosition() {
        sut.notes[3].cursorPosition = 100
        XCTAssertEqual(sut.getCursorPosition(for: 3), 100)
    }

    func testCursorPositionRoundTrip() {
        sut.saveCursorPosition(55, for: 2)
        XCTAssertEqual(sut.getCursorPosition(for: 2), 55)
    }

    // MARK: - Persistence Tests

    func testSelectedNoteIndexPersistence() {
        sut.selectNote(4)

        // Create new manager to test loading
        let newManager = NotesManager()
        XCTAssertEqual(newManager.selectedNoteIndex, 4)
    }

    func testNoteContentPersistence() {
        let binding = sut.noteBinding(for: 0)
        binding.wrappedValue = "Persisted content"

        // Create new manager to test loading
        let newManager = NotesManager()
        XCTAssertEqual(newManager.notes[0].content, "Persisted content")
    }

    func testTextFontPersistence() {
        sut.textFont = FontSetting(name: "Georgia", size: 20)

        // Create new manager to test loading
        let newManager = NotesManager()
        XCTAssertEqual(newManager.textFont.name, "Georgia")
        XCTAssertEqual(newManager.textFont.size, 20)
    }

    func testCodeFontPersistence() {
        sut.codeFont = FontSetting(name: "Monaco", size: 12)

        // Create new manager to test loading
        let newManager = NotesManager()
        XCTAssertEqual(newManager.codeFont.name, "Monaco")
        XCTAssertEqual(newManager.codeFont.size, 12)
    }

    func testInvalidSelectedIndexFallsBackToZero() {
        // Save an invalid index directly to UserDefaults
        UserDefaults.standard.set(99, forKey: selectedNoteKey)

        let newManager = NotesManager()
        XCTAssertEqual(newManager.selectedNoteIndex, 0)
    }

    func testNegativeSelectedIndexFallsBackToZero() {
        // Save a negative index directly to UserDefaults
        UserDefaults.standard.set(-5, forKey: selectedNoteKey)

        let newManager = NotesManager()
        XCTAssertEqual(newManager.selectedNoteIndex, 0)
    }

    // MARK: - Multiple Notes Tests

    func testMultipleNotesContent() {
        for i in 0..<6 {
            let binding = sut.noteBinding(for: i)
            binding.wrappedValue = "Note \(i)"
        }

        for i in 0..<6 {
            XCTAssertEqual(sut.notes[i].content, "Note \(i)")
            XCTAssertTrue(sut.hasContent(at: i))
        }
    }

    func testMultipleNotesPersistence() {
        for i in 0..<6 {
            let binding = sut.noteBinding(for: i)
            binding.wrappedValue = "Persisted Note \(i)"
        }

        let newManager = NotesManager()
        for i in 0..<6 {
            XCTAssertEqual(newManager.notes[i].content, "Persisted Note \(i)")
        }
    }

    // MARK: - Sync State Tests

    func testInitializationDefaultSyncDisabled() {
        XCTAssertFalse(sut.isSyncEnabled)
    }

    func testSyncEnabledPersistence() {
        sut.isSyncEnabled = true

        let newManager = NotesManager()
        XCTAssertTrue(newManager.isSyncEnabled)
    }
}
