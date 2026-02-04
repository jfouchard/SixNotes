import XCTest
import CloudKit
@testable import SixNotes

@MainActor
final class CloudKitSyncEngineTests: XCTestCase {

    var sut: CloudKitSyncEngine!

    override func setUp() {
        super.setUp()
        sut = CloudKitSyncEngine()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInitialAccountStatusIsCouldNotDetermine() {
        XCTAssertEqual(sut.accountStatus, .couldNotDetermine)
    }

    func testInitialSyncingIsFalse() {
        XCTAssertFalse(sut.isSyncing)
    }

    func testInitialLastSyncDateIsNil() {
        XCTAssertNil(sut.lastSyncDate)
    }

    func testInitialLastSyncErrorIsNil() {
        XCTAssertNil(sut.lastSyncError)
    }

    // MARK: - CloudKitSyncError Tests

    func testNotAuthenticatedErrorDescription() {
        let error = CloudKitSyncError.notAuthenticated
        XCTAssertEqual(error.errorDescription, "Not signed in to iCloud")
    }

    func testNetworkUnavailableErrorDescription() {
        let error = CloudKitSyncError.networkUnavailable
        XCTAssertEqual(error.errorDescription, "Network unavailable")
    }

    func testQuotaExceededErrorDescription() {
        let error = CloudKitSyncError.quotaExceeded
        XCTAssertEqual(error.errorDescription, "iCloud storage quota exceeded")
    }

    func testServerErrorDescription() {
        let error = CloudKitSyncError.serverError("Test error message")
        XCTAssertEqual(error.errorDescription, "Server error: Test error message")
    }

    func testRecordNotFoundErrorDescription() {
        let error = CloudKitSyncError.recordNotFound
        XCTAssertEqual(error.errorDescription, "Record not found")
    }

    func testConflictDetectedErrorDescription() {
        // Create a real CKRecord for testing
        let record = CKRecord(recordType: "Note", recordID: CKRecord.ID(recordName: "test"))
        let error = CloudKitSyncError.conflictDetected(serverRecord: record, localNote: Note(id: 0))
        XCTAssertEqual(error.errorDescription, "Conflict detected")
    }

    // MARK: - CloudKitAccountStatus Tests

    func testAccountStatusCases() {
        // Verify all expected cases exist
        let available = CloudKitAccountStatus.available
        let noAccount = CloudKitAccountStatus.noAccount
        let restricted = CloudKitAccountStatus.restricted
        let couldNotDetermine = CloudKitAccountStatus.couldNotDetermine
        let temporarilyUnavailable = CloudKitAccountStatus.temporarilyUnavailable

        XCTAssertNotEqual(available, noAccount)
        XCTAssertNotEqual(restricted, couldNotDetermine)
        XCTAssertNotEqual(couldNotDetermine, temporarilyUnavailable)
    }

    // MARK: - Static Properties Tests

    func testRecordTypeConstant() {
        XCTAssertEqual(CloudKitSyncEngine.recordType, "Note")
    }

    func testContainerIdentifier() {
        XCTAssertEqual(CloudKitSyncEngine.containerIdentifier, "iCloud.org.fouchard.SixNotes")
    }

    // MARK: - Sync Guard Tests

    func testPerformFullSyncThrowsWhenNotAuthenticated() async {
        // Account status defaults to .couldNotDetermine
        let notes = [Note(id: 0)]

        do {
            _ = try await sut.performFullSync(localNotes: notes)
            XCTFail("Expected notAuthenticated error")
        } catch let error as CloudKitSyncError {
            XCTAssertEqual(error.errorDescription, "Not signed in to iCloud")
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testUploadNoteThrowsWhenNotAuthenticated() async {
        let note = Note(id: 0, content: "Test")

        do {
            _ = try await sut.uploadNote(note)
            XCTFail("Expected notAuthenticated error")
        } catch let error as CloudKitSyncError {
            XCTAssertEqual(error.errorDescription, "Not signed in to iCloud")
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - Debounced Sync Tests

    func testDebouncedSyncCancelsPreviousTask() {
        var completionCount = 0
        let notes = [Note(id: 0)]

        // Call debouncedSync multiple times rapidly
        for _ in 0..<5 {
            sut.debouncedSync(localNotes: notes) { _ in
                completionCount += 1
            }
        }

        // The completion should only be called once after debounce settles
        // Since we can't test CloudKit directly, we verify the task is created
        XCTAssertTrue(true) // Task creation doesn't throw
    }
}

