import XCTest
@testable import ExpenseTracker

@MainActor
final class ExpenseSummaryTests: XCTestCase {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 7 * 3600)!
        return value
    }

    private func date(_ year: Int, _ month: Int, _ day: Int = 1) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private func expense(_ amount: Int64, _ date: Date, sourceID: UUID = UUID()) -> Expense {
        Expense(amount: amount, description: "Purchase", sourceID: sourceID, channel: "Cash", date: date)
    }

    private func summary(_ expenses: [Expense], year: Int = 2026, month: Int = 10) -> ExpenseSummary {
        ExpenseSummary.calculate(expenses: expenses, year: year, month: month, calendar: calendar)
    }

    func testSelectedMonthAndYearIncludeOnlyTheirSavedExpenses() {
        let expenses = [expense(15_000, date(2026, 10)), expense(10_000, date(2026, 10, 20)),
                        expense(30_000, date(2026, 11)), expense(90_000, date(2027, 10))]
        XCTAssertEqual(summary(expenses), ExpenseSummary(month: .amount(25_000), year: .amount(55_000)))
        XCTAssertEqual(summary(expenses, month: 11).month, .amount(30_000))
        XCTAssertEqual(summary(expenses, year: 2027).year, .amount(90_000))
        XCTAssertEqual(summary(expenses, month: 9).month, .amount(0))
        XCTAssertEqual(summary([], year: 2025), ExpenseSummary(month: .amount(0), year: .amount(0)))
    }

    func testLocalMidnightSeparatesMonthsAndYearsRatherThanUTCDate() {
        let midnight = date(2027, 1)
        let expenses = [expense(15_000, midnight.addingTimeInterval(-1)), expense(10_000, midnight)]
        XCTAssertEqual(summary(expenses, year: 2026, month: 12),
                       ExpenseSummary(month: .amount(15_000), year: .amount(15_000)))
        XCTAssertEqual(summary(expenses, year: 2027, month: 1),
                       ExpenseSummary(month: .amount(10_000), year: .amount(10_000)))
    }

    func testSaveEditDateMoveDeleteAndUndoUpdateDurableTotals() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileURL = directory.appendingPathComponent("expenses.json")
        let store = try ExpenseStore(fileURL: fileURL)
        let sourceID = store.sources[0].id
        var first = try store.addExpense(expense(15_000, date(2026, 10), sourceID: sourceID))
        let second = try store.addExpense(expense(10_000, date(2026, 10), sourceID: sourceID))
        XCTAssertEqual(summary(store.expenses).month, .amount(25_000))
        first.amount = 20_000
        try store.updateExpense(first)
        XCTAssertEqual(summary(store.expenses).year, .amount(30_000))
        try store.deleteExpense(id: second.id)
        XCTAssertEqual(summary(store.expenses).month, .amount(20_000))
        first.date = date(2027, 1)
        try store.updateExpense(first)
        XCTAssertEqual(summary(store.expenses).year, .amount(0))
        XCTAssertEqual(summary(store.expenses, year: 2027, month: 1).month, .amount(20_000))
        let reopened = try ExpenseStore(fileURL: fileURL)
        XCTAssertEqual(summary(reopened.expenses, year: 2027, month: 1).year, .amount(20_000))
        // Undo uses the same deletion path as the save confirmation.
        try reopened.deleteExpense(id: first.id)
        XCTAssertEqual(summary(try ExpenseStore(fileURL: fileURL).expenses, year: 2027, month: 1).year, .amount(0))
    }

    func testFailedWriteDoesNotChangeTotals() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileURL = directory.appendingPathComponent("expenses.json")
        let seed = try ExpenseStore(fileURL: fileURL)
        let original = try seed.addExpense(expense(15_000, date(2026, 10), sourceID: seed.sources[0].id))
        let store = try ExpenseStore(fileURL: fileURL, write: { _, _ in throw CocoaError(.fileWriteNoPermission) })
        var correction = original
        correction.amount = 20_000
        XCTAssertThrowsError(try store.updateExpense(correction))
        XCTAssertThrowsError(try store.deleteExpense(id: original.id))
        XCTAssertEqual(summary(store.expenses).month, .amount(15_000))
    }

    func testOverflowIsExplicitAndIndependentBetweenMonthAndYear() {
        let expenses = [expense(Int64.max, date(2026, 10)), expense(1, date(2026, 11))]
        XCTAssertEqual(summary(expenses), ExpenseSummary(month: .amount(Int64.max), year: .overflow))
        XCTAssertEqual(summary(expenses + [expense(1, date(2026, 10))]).month, .overflow)
        XCTAssertEqual(summary(expenses, month: 11).month, .amount(1))
    }
}
