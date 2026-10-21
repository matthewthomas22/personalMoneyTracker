import XCTest
@testable import ExpenseTracker

final class VoiceCaptureSessionTests: XCTestCase {
    private func directory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    @MainActor
    func testMissingPaymentFollowupCompletesSameCaptureOnlyOnce() throws {
        let directory = directory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try ExpenseStore(fileURL: directory.appendingPathComponent("expenses.json"))
        let drafts = VoiceDraftStore(fileURL: directory.appendingPathComponent("draft.json"))
        let session = VoiceCaptureSession(store: store, drafts: drafts)
        let id = session.draft.id
        try store.addExpense(Expense(amount: 30000, description: "Existing purchase",
            sourceID: store.sources[0].id, channel: "QRIS", date: session.draft.capturedAt))
        let calendar = ExpenseSummary.reportingCalendar
        let components = calendar.dateComponents([.year, .month], from: session.draft.capturedAt)
        session.receive("I bought a sausage from Indomaret for 15000 rupiah")
        XCTAssertNil(session.savedExpense)
        XCTAssertFalse(session.questions.isEmpty)
        XCTAssertEqual(store.expenses.count, 1)
        XCTAssertEqual(ExpenseSummary.calculate(expenses: store.expenses, year: components.year!,
            month: components.month!, calendar: calendar).month, .amount(30000))
        XCTAssertEqual(ExpenseSummary.calculate(expenses: store.expenses, year: components.year!,
            month: components.month!, calendar: calendar).year, .amount(30000))
        XCTAssertEqual(try drafts.load()?.id, id)
        session.receive("QRIS GoPay")
        XCTAssertEqual(store.expenses.count, 2)
        XCTAssertEqual(session.savedExpense?.id, id)
        XCTAssertEqual(ExpenseSummary.calculate(expenses: store.expenses, year: components.year!,
            month: components.month!, calendar: calendar).month, .amount(45000))
        XCTAssertEqual(ExpenseSummary.calculate(expenses: store.expenses, year: components.year!,
            month: components.month!, calendar: calendar).year, .amount(45000))
        session.retry()
        session.saveManual()
        session.receive("QRIS GoPay")
        XCTAssertEqual(store.expenses.count, 2)
        XCTAssertNil(try drafts.load())
    }

    @MainActor
    func testNaturalMissingAmountAndDescriptionRepliesKeepCaptureIdentity() throws {
        for (opening, reply) in [("Lunch QRIS GoPay", "15000 rupiah"),
                                 ("15000 rupiah QRIS GoPay", "Lunch"),
                                 ("Lunch 15000 rupiah QRIS", "GoPay")] {
            let directory = directory()
            defer { try? FileManager.default.removeItem(at: directory) }
            let store = try ExpenseStore(fileURL: directory.appendingPathComponent("expenses.json"))
            let session = VoiceCaptureSession(store: store,
                drafts: VoiceDraftStore(fileURL: directory.appendingPathComponent("draft.json")))
            let id = session.draft.id
            session.receive(opening)
            XCTAssertTrue(store.expenses.isEmpty, opening)
            session.receive(reply)
            XCTAssertEqual(session.savedExpense?.id, id, opening)
            XCTAssertEqual(session.savedExpense?.amount, 15000, opening)
            XCTAssertEqual(session.savedExpense?.description, "lunch", opening)
            XCTAssertEqual(store.expenses.count, 1, opening)
        }
    }

    @MainActor
    func testConflictingFollowupNeverSilentlyReplacesKnownFields() throws {
        for (opening, reply) in [("Lunch 15000 rupiah", "Dinner QRIS GoPay"),
                                 ("Lunch 15000 rupiah using GoPay", "QRIS using NewWallet"),
                                 ("Lunch 15000 rupiah yesterday", "QRIS GoPay today")] {
            let directory = directory()
            defer { try? FileManager.default.removeItem(at: directory) }
            let store = try ExpenseStore(fileURL: directory.appendingPathComponent("expenses.json"))
            let session = VoiceCaptureSession(store: store,
                drafts: VoiceDraftStore(fileURL: directory.appendingPathComponent("draft.json")))
            session.receive(opening)
            session.receive(reply)
            XCTAssertTrue(store.expenses.isEmpty, opening)
            XCTAssertFalse(session.questions.isEmpty, opening)
            session.retry()
            XCTAssertTrue(store.expenses.isEmpty, "Retry must retain the contradiction")
        }
    }

    @MainActor
    func testAmbiguityCanBeCorrectedBySpeechInSameCapture() throws {
        let directory = directory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try ExpenseStore(fileURL: directory.appendingPathComponent("expenses.json"))
        let session = VoiceCaptureSession(store: store,
            drafts: VoiceDraftStore(fileURL: directory.appendingPathComponent("draft.json")))
        let id = session.draft.id
        session.receive("Lunch 15000 or 20000 QRIS GoPay")
        XCTAssertTrue(store.expenses.isEmpty)
        session.receive("correction lunch 15000 rupiah QRIS GoPay yesterday")
        XCTAssertEqual(session.savedExpense?.id, id)
        XCTAssertEqual(session.savedExpense?.amount, 15000)
        XCTAssertEqual(store.expenses.count, 1)
    }

    @MainActor
    func testRecognitionFailurePreservesEditableDraftWithoutSavingPartialSpeech() throws {
        let directory = directory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try ExpenseStore(fileURL: directory.appendingPathComponent("expenses.json"))
        let drafts = VoiceDraftStore(fileURL: directory.appendingPathComponent("draft.json"))
        let session = VoiceCaptureSession(store: store, drafts: drafts)
        session.recognitionFailed("Recognition failed", capturedText: "Lunch 15000 rupiah QRIS GoPay")
        XCTAssertTrue(store.expenses.isEmpty)
        XCTAssertEqual(try drafts.load()?.transcript, "Lunch 15000 rupiah QRIS GoPay")
        let reopened = VoiceCaptureSession(store: store, drafts: drafts)
        XCTAssertTrue(reopened.resumedDraft)
        reopened.draft.transcript = "Tea 10000 rupiah QRIS GoPay"
        reopened.retry()
        XCTAssertEqual(store.expenses.first?.amount, 10000)
        XCTAssertEqual(store.expenses.first?.description, "tea")
    }

    @MainActor
    func testCancelDiscardsDraftAndUnfamiliarSourceIsNotAddedWithoutConfirmation() throws {
        let directory = directory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try ExpenseStore(fileURL: directory.appendingPathComponent("expenses.json"))
        let drafts = VoiceDraftStore(fileURL: directory.appendingPathComponent("draft.json"))
        let session = VoiceCaptureSession(store: store, drafts: drafts)
        session.receive("Lunch 15000 rupiah QRIS NewWallet")
        XCTAssertNotNil(session.unfamiliarSource)
        XCTAssertEqual(store.sources.count, 3)
        XCTAssertTrue(store.expenses.isEmpty)
        XCTAssertTrue(session.cancel())
        XCTAssertFalse(session.preserve(), "A deferred UI change must not recreate a cancelled draft")
        XCTAssertNil(try drafts.load())
        XCTAssertEqual(store.sources.count, 3)
        XCTAssertTrue(store.expenses.isEmpty)
    }

    @MainActor
    func testDraftWriteFailureRetainsTextAndCannotReportSaved() throws {
        let directory = directory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try ExpenseStore(fileURL: directory.appendingPathComponent("expenses.json"))
        let drafts = VoiceDraftStore(fileURL: directory.appendingPathComponent("draft.json"),
            write: { _, _ in throw CocoaError(.fileWriteOutOfSpace) })
        let session = VoiceCaptureSession(store: store, drafts: drafts)
        session.receive("Lunch 15000 rupiah QRIS GoPay")
        XCTAssertEqual(session.draft.transcript, "Lunch 15000 rupiah QRIS GoPay")
        XCTAssertNotNil(session.errorMessage)
        XCTAssertNil(session.savedExpense)
        XCTAssertTrue(store.expenses.isEmpty)
    }

    @MainActor
    func testLocalSaveFailureCanRetrySameCaptureOnce() throws {
        let directory = directory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("expenses.json")
        _ = try ExpenseStore(fileURL: url)
        var rejectWrites = true
        let store = try ExpenseStore(fileURL: url, write: { data, url in
            if rejectWrites { throw CocoaError(.fileWriteOutOfSpace) }
            try data.write(to: url, options: .atomic)
        })
        let drafts = VoiceDraftStore(fileURL: directory.appendingPathComponent("draft.json"))
        let session = VoiceCaptureSession(store: store, drafts: drafts)
        let id = session.draft.id
        session.receive("Lunch 15000 rupiah QRIS GoPay")
        XCTAssertNil(session.savedExpense)
        XCTAssertNotNil(session.errorMessage)
        XCTAssertEqual(try drafts.load()?.id, id)
        XCTAssertTrue(store.expenses.isEmpty)
        rejectWrites = false
        session.saveManual()
        session.saveManual()
        XCTAssertEqual(store.expenses.count, 1)
        XCTAssertEqual(session.savedExpense?.id, id)
    }

    @MainActor
    func testConfirmUnfamiliarSourceAndSourceWriteFailure() throws {
        let directory = directory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("expenses.json")
        _ = try ExpenseStore(fileURL: url)
        let failing = try ExpenseStore(fileURL: url, write: { _, _ in throw CocoaError(.fileWriteOutOfSpace) })
        let drafts = VoiceDraftStore(fileURL: directory.appendingPathComponent("draft.json"))
        let session = VoiceCaptureSession(store: failing, drafts: drafts)
        session.receive("Lunch 15000 rupiah QRIS NewWallet")
        session.confirmUnfamiliarSource()
        XCTAssertNotNil(session.errorMessage)
        XCTAssertEqual(failing.sources.count, 3)
        XCTAssertTrue(failing.expenses.isEmpty)
        let working = try ExpenseStore(fileURL: url)
        let retry = VoiceCaptureSession(store: working, drafts: drafts)
        retry.retry()
        retry.confirmUnfamiliarSource()
        XCTAssertEqual(working.sources.count, 4)
        XCTAssertEqual(working.expenses.count, 1)
    }

    @MainActor
    func testDraftCleanupFailureAfterSaveDoesNotDuplicateOnRetryOrReopen() throws {
        let directory = directory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try ExpenseStore(fileURL: directory.appendingPathComponent("expenses.json"))
        let url = directory.appendingPathComponent("draft.json")
        let drafts = VoiceDraftStore(fileURL: url, remove: { _ in throw CocoaError(.fileWriteNoPermission) })
        let session = VoiceCaptureSession(store: store, drafts: drafts)
        session.receive("Lunch 15000 rupiah QRIS GoPay")
        let saved = try XCTUnwrap(session.savedExpense)
        XCTAssertTrue(session.cleanupPending)
        XCTAssertNotNil(session.errorMessage)
        XCTAssertNotNil(try drafts.load())
        session.retry()
        session.saveManual()
        XCTAssertEqual(store.expenses.count, 1)
        let normal = VoiceDraftStore(fileURL: url)
        let reopened = VoiceCaptureSession(store: store, drafts: normal)
        XCTAssertEqual(reopened.savedExpense, saved)
        XCTAssertFalse(reopened.cleanupPending)
        reopened.retry()
        reopened.saveManual()
        XCTAssertEqual(store.expenses.count, 1)
        XCTAssertNil(try normal.load())
    }

    @MainActor
    func testCorruptDraftIsPreservedWithoutOverwrite() throws {
        let directory = directory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try ExpenseStore(fileURL: directory.appendingPathComponent("expenses.json"))
        let url = directory.appendingPathComponent("draft.json")
        let original = Data("corrupt draft".utf8)
        try original.write(to: url)
        let session = VoiceCaptureSession(store: store, drafts: VoiceDraftStore(fileURL: url))
        XCTAssertFalse(session.storageAvailable)
        session.receive("Lunch 15000 rupiah QRIS GoPay")
        XCTAssertFalse(session.preserve())
        XCTAssertFalse(session.cancel())
        XCTAssertEqual(try Data(contentsOf: url), original)
        XCTAssertTrue(store.expenses.isEmpty)
    }
}
