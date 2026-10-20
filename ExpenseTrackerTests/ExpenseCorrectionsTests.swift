import XCTest
@testable import ExpenseTracker

@MainActor
final class ExpenseCorrectionsTests: XCTestCase {
    private var directory: URL!
    private var fileURL: URL { directory.appendingPathComponent("expenses.json") }

    override func setUp() async throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        try FileManager.default.removeItem(at: directory)
    }

    private func expense(in store: ExpenseStore, date: Date = Date()) -> Expense {
        Expense(amount: 15_000, description: "Lunch", sourceID: store.sources[0].id,
                channel: "QRIS", date: date)
    }

    func testEditPersistsAllFieldsWithSameIdentityAndMovesDateGroup() throws {
        let store = try ExpenseStore(fileURL: fileURL)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 7 * 3600)!
        let december = calendar.date(from: DateComponents(year: 2026, month: 12, day: 31, hour: 23))!
        let january = calendar.date(from: DateComponents(year: 2027, month: 1, day: 1, hour: 1))!
        let original = try store.addExpense(expense(in: store, date: december))
        var correction = original
        correction.amount = 20_000
        correction.description = "Dinner"
        correction.sourceID = store.sources[1].id
        correction.channel = "Transfer"
        correction.date = january
        try store.updateExpense(correction)
        let reopened = try ExpenseStore(fileURL: fileURL)
        XCTAssertEqual(reopened.expenses, [correction])
        let groups = ExpenseHistoryGrouping.groups(expenses: reopened.expenses, calendar: calendar)
        XCTAssertEqual(groups.map(\.date), [calendar.startOfDay(for: january)])
        XCTAssertEqual(groups.first?.expenses.map(\.id), [original.id])
    }

    func testDeleteAndUndoNewestSavePersistWithoutRemovingOlderExpense() throws {
        let store = try ExpenseStore(fileURL: fileURL)
        let older = try store.addExpense(expense(in: store))
        let newest = try store.addExpense(expense(in: store, date: older.date.addingTimeInterval(-86_400)))
        // The confirmation's Undo uses the same durable deletion path as history.
        try store.deleteExpense(id: newest.id)
        XCTAssertEqual(try ExpenseStore(fileURL: fileURL).expenses, [older])
        try store.deleteExpense(id: older.id)
        XCTAssertTrue(try ExpenseStore(fileURL: fileURL).expenses.isEmpty)
        XCTAssertTrue(ExpenseHistoryGrouping.groups(expenses: store.expenses).isEmpty)
    }

    func testFailedEditDeleteAndUndoRetainPublishedAndPersistedState() throws {
        let seed = try ExpenseStore(fileURL: fileURL)
        let original = try seed.addExpense(expense(in: seed))
        let newest = try seed.addExpense(expense(in: seed))
        let store = try ExpenseStore(fileURL: fileURL, write: { _, _ in
            throw CocoaError(.fileWriteNoPermission)
        })
        let before = store.expenses
        var correction = original
        correction.amount = 25_000
        correction.date = original.date.addingTimeInterval(86_400)
        XCTAssertThrowsError(try store.updateExpense(correction))
        XCTAssertEqual(store.expenses, before)
        XCTAssertThrowsError(try store.deleteExpense(id: original.id))
        XCTAssertEqual(store.expenses, before)
        XCTAssertThrowsError(try store.deleteExpense(id: newest.id))
        XCTAssertEqual(store.expenses, before)
        XCTAssertEqual(try ExpenseStore(fileURL: fileURL).expenses, before)
    }

    func testEditingPreservesArchivedOriginalSourceButRejectsAnotherArchivedSource() throws {
        let store = try ExpenseStore(fileURL: fileURL)
        var original = try store.addExpense(expense(in: store))
        var firstSource = store.sources[0]
        firstSource.isArchived = true
        try store.updateSource(firstSource)
        var otherSource = store.sources[1]
        otherSource.isArchived = true
        try store.updateSource(otherSource)
        original.description = "Corrected lunch"
        try store.updateExpense(original)
        XCTAssertEqual(try ExpenseStore(fileURL: fileURL).expenses, [original])
        var invalid = original
        invalid.sourceID = otherSource.id
        XCTAssertThrowsError(try store.updateExpense(invalid))
        XCTAssertEqual(store.expenses, [original])
    }

    func testInvalidCorrectionAndMissingRecordCannotChangeSavedExpenses() throws {
        let store = try ExpenseStore(fileURL: fileURL)
        let original = try store.addExpense(expense(in: store))
        var invalid = original
        invalid.amount = 0
        XCTAssertThrowsError(try store.updateExpense(invalid))
        invalid = original
        invalid.description = " \n "
        XCTAssertThrowsError(try store.updateExpense(invalid))
        invalid = original
        invalid.channel = " "
        XCTAssertThrowsError(try store.updateExpense(invalid))
        invalid = original
        invalid.date = Date(timeIntervalSinceReferenceDate: .infinity)
        XCTAssertThrowsError(try store.updateExpense(invalid))
        invalid = original
        invalid.id = UUID()
        XCTAssertThrowsError(try store.updateExpense(invalid))
        XCTAssertThrowsError(try store.deleteExpense(id: invalid.id))
        XCTAssertEqual(try ExpenseStore(fileURL: fileURL).expenses, [original])
    }

    func testGroupsUseLocalDayAndNewestFirstWithoutStaleEmptyGroups() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 7 * 3600)!
        let midnight = calendar.date(from: DateComponents(year: 2027, month: 1, day: 1))!
        let sourceID = UUID()
        let before = Expense(amount: 1, description: "Before", sourceID: sourceID,
                             channel: "Cash", date: midnight.addingTimeInterval(-1))
        let after = Expense(amount: 2, description: "After", sourceID: sourceID,
                            channel: "Cash", date: midnight.addingTimeInterval(1))
        let groups = ExpenseHistoryGrouping.groups(expenses: [before, after], calendar: calendar)
        XCTAssertEqual(groups.count, 2)
        XCTAssertEqual(groups[0].expenses, [after])
        XCTAssertEqual(groups[1].expenses, [before])
        XCTAssertEqual(ExpenseHistoryGrouping.groups(expenses: [after], calendar: calendar).count, 1)
    }
}
