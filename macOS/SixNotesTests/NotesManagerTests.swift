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

    // MARK: - Current Note Binding Tests (macOS specific API)

    func testCurrentNoteBindingGet() {
        sut.notes[0].content = "Test content"
        sut.selectNote(0)
        let binding = sut.currentNote

        XCTAssertEqual(binding.wrappedValue, "Test content")
    }

    func testCurrentNoteBindingSet() {
        sut.selectNote(1)
        let binding = sut.currentNote
        binding.wrappedValue = "New content"

        XCTAssertEqual(sut.notes[1].content, "New content")
    }

    func testCurrentNoteBindingSetUpdatesLastModified() {
        sut.selectNote(0)
        let originalDate = sut.notes[0].lastModified

        // Small delay to ensure date difference
        Thread.sleep(forTimeInterval: 0.01)

        let binding = sut.currentNote
        binding.wrappedValue = "Updated"

        XCTAssertGreaterThan(sut.notes[0].lastModified, originalDate)
    }

    func testCurrentNoteBindingFollowsSelection() {
        sut.notes[0].content = "Note 0"
        sut.notes[1].content = "Note 1"
        sut.notes[2].content = "Note 2"

        sut.selectNote(0)
        XCTAssertEqual(sut.currentNote.wrappedValue, "Note 0")

        sut.selectNote(1)
        XCTAssertEqual(sut.currentNote.wrappedValue, "Note 1")

        sut.selectNote(2)
        XCTAssertEqual(sut.currentNote.wrappedValue, "Note 2")
    }

    // MARK: - Cursor Position Tests (macOS specific API)

    func testSaveCursorPosition() {
        sut.selectNote(0)
        sut.saveCursorPosition(42)
        XCTAssertEqual(sut.notes[0].cursorPosition, 42)
    }

    func testGetCursorPosition() {
        sut.selectNote(3)
        sut.notes[3].cursorPosition = 100
        XCTAssertEqual(sut.getCursorPosition(), 100)
    }

    func testCursorPositionRoundTrip() {
        sut.selectNote(2)
        sut.saveCursorPosition(55)
        XCTAssertEqual(sut.getCursorPosition(), 55)
    }

    func testCursorPositionFollowsSelection() {
        sut.notes[0].cursorPosition = 10
        sut.notes[1].cursorPosition = 20
        sut.notes[2].cursorPosition = 30

        sut.selectNote(0)
        XCTAssertEqual(sut.getCursorPosition(), 10)

        sut.selectNote(1)
        XCTAssertEqual(sut.getCursorPosition(), 20)

        sut.selectNote(2)
        XCTAssertEqual(sut.getCursorPosition(), 30)
    }

    // MARK: - Persistence Tests

    func testSelectedNoteIndexPersistence() {
        sut.selectNote(4)

        // Create new manager to test loading
        let newManager = NotesManager()
        XCTAssertEqual(newManager.selectedNoteIndex, 4)
    }

    func testNoteContentPersistence() {
        sut.selectNote(0)
        let binding = sut.currentNote
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
            sut.selectNote(i)
            sut.currentNote.wrappedValue = "Note \(i)"
        }

        for i in 0..<6 {
            XCTAssertEqual(sut.notes[i].content, "Note \(i)")
            XCTAssertTrue(sut.hasContent(at: i))
        }
    }

    func testMultipleNotesPersistence() {
        for i in 0..<6 {
            sut.selectNote(i)
            sut.currentNote.wrappedValue = "Persisted Note \(i)"
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

    // MARK: - Plain Text Mode Tests

    func testCurrentNoteIsPlainTextDefault() {
        XCTAssertFalse(sut.currentNoteIsPlainText)
    }

    func testTogglePlainText() {
        sut.selectNote(0)
        XCTAssertFalse(sut.currentNoteIsPlainText)

        sut.togglePlainText()
        XCTAssertTrue(sut.currentNoteIsPlainText)

        sut.togglePlainText()
        XCTAssertFalse(sut.currentNoteIsPlainText)
    }

    func testSetPlainTextTrue() {
        sut.selectNote(0)
        sut.setPlainText(true)
        XCTAssertTrue(sut.notes[0].isPlainText)
    }

    func testSetPlainTextFalse() {
        sut.selectNote(0)
        sut.setPlainText(true)
        sut.setPlainText(false)
        XCTAssertFalse(sut.notes[0].isPlainText)
    }

    func testPlainTextModeUpdatesLastModified() {
        sut.selectNote(0)
        let originalDate = sut.notes[0].lastModified

        Thread.sleep(forTimeInterval: 0.01)

        sut.togglePlainText()
        XCTAssertGreaterThan(sut.notes[0].lastModified, originalDate)
    }

    func testPlainTextModeSetsSyncStateToPendingUpload() {
        sut.selectNote(0)
        sut.notes[0].syncState = .synced

        sut.togglePlainText()
        XCTAssertEqual(sut.notes[0].syncState, .pendingUpload)
    }

    func testPlainTextModePersistence() {
        sut.selectNote(0)
        sut.setPlainText(true)

        let newManager = NotesManager()
        XCTAssertTrue(newManager.notes[0].isPlainText)
    }

    func testPlainTextModeFollowsSelection() {
        sut.notes[0].isPlainText = true
        sut.notes[1].isPlainText = false
        sut.notes[2].isPlainText = true

        sut.selectNote(0)
        XCTAssertTrue(sut.currentNoteIsPlainText)

        sut.selectNote(1)
        XCTAssertFalse(sut.currentNoteIsPlainText)

        sut.selectNote(2)
        XCTAssertTrue(sut.currentNoteIsPlainText)
    }
}
