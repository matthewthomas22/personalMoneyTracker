import XCTest
@testable import ExpenseTracker

final class ExpenseStoreTests: XCTestCase {
    @MainActor
    func testInitialSourcesAndExpenseSurviveReopening() throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = try ExpenseStore(fileURL: url)
        XCTAssertEqual(store.sources.map(\.name), ["GoPay", "SeaBank", "Cash"])
        let expense = Expense(amount: 15_000, description: "  Lunch  ",
                              sourceID: store.sources[0].id, channel: " QRIS ", date: Date())
        let saved = try store.addExpense(expense)
        XCTAssertEqual(saved.description, "Lunch")
        XCTAssertEqual(saved.channel, "QRIS")
        let reopened = try ExpenseStore(fileURL: url)
        XCTAssertEqual(reopened.expenses, [saved])
        XCTAssertEqual(reopened.sources, store.sources)
    }

    func testWholeRupiahValidation() {
        for text in ["", "0", "-1", "+1", "1.5", "15.000", "15,000", " 15", "１５", "9223372036854775808"] {
            XCTAssertNil(ExpenseValidation.amount(from: text), text)
        }
        XCTAssertEqual(ExpenseValidation.amount(from: "15000"), 15_000)
        XCTAssertEqual(ExpenseValidation.amount(from: String(Int64.max)), Int64.max)
    }

    @MainActor
    func testIncompleteExpensesDoNotReachDisk() throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = try ExpenseStore(fileURL: url)
        let before = try Data(contentsOf: url)
        let valid = Expense(amount: 1, description: "Lunch", sourceID: store.sources[0].id,
                            channel: "QRIS", date: Date())
        var invalids: [Expense] = []
        var value = valid; value.amount = 0; invalids.append(value)
        value = valid; value.amount = -1; invalids.append(value)
        value = valid; value.description = " \n "; invalids.append(value)
        value = valid; value.channel = " "; invalids.append(value)
        value = valid; value.sourceID = UUID(); invalids.append(value)
        value = valid; value.date = Date(timeIntervalSinceReferenceDate: .infinity); invalids.append(value)
        for expense in invalids { XCTAssertThrowsError(try store.addExpense(expense)) }
        XCTAssertTrue(store.expenses.isEmpty)
        XCTAssertEqual(try Data(contentsOf: url), before)
    }

    @MainActor
    func testWriteFailureLeavesPublishedStateAndFileUnchanged() throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let original = try ExpenseStore(fileURL: url)
        let before = try Data(contentsOf: url)
        let store = try ExpenseStore(fileURL: url, write: { _, _ in throw CocoaError(.fileWriteOutOfSpace) })
        let expense = Expense(amount: 10, description: "Tea", sourceID: original.sources[0].id,
                              channel: "QRIS", date: Date())
        XCTAssertThrowsError(try store.addExpense(expense))
        XCTAssertThrowsError(try store.addSource(PaymentSource(name: "Other")))
        XCTAssertEqual(store.expenses, [])
        XCTAssertEqual(store.sources, original.sources)
        XCTAssertEqual(try Data(contentsOf: url), before)
    }

    @MainActor
    func testCorruptFileIsNotOverwritten() throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = Data("invalid JSON".utf8)
        try data.write(to: url)
        XCTAssertThrowsError(try ExpenseStore(fileURL: url))
        XCTAssertEqual(try Data(contentsOf: url), data)
    }

    private func temporaryURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("expenses.json")
    }
}
