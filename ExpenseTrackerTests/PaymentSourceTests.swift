import XCTest
@testable import ExpenseTracker

final class PaymentSourceTests: XCTestCase {
    func testKnownAliasResolvesWithWhitespaceAndCaseNormalization() throws {
        let source = PaymentSource(name: "GoPay", aliases: ["Go Pay"])
        XCTAssertEqual(try PaymentSourceRules.resolve("  GO  PAY\n", in: [source])?.id, source.id)
        XCTAssertNil(try PaymentSourceRules.resolve("Unfamiliar wallet", in: [source]))
    }

    func testOwnNameAndAliasesCannotCollide() {
        XCTAssertThrowsError(try PaymentSourceRules.validate(sources: [
            PaymentSource(name: "GoPay", aliases: [" gopay "])
        ]))
        XCTAssertThrowsError(try PaymentSourceRules.validate(sources: [
            PaymentSource(name: "Wallet", aliases: ["Pocket", " pocket "])
        ]))
    }

    func testArchivedNamesAndAliasesRemainReserved() {
        let archived = PaymentSource(name: "GoPay", aliases: ["Wallet"], isArchived: true)
        for candidate in [PaymentSource(name: "wallet"), PaymentSource(name: "Other", aliases: ["GOPAY"])] {
            XCTAssertThrowsError(try PaymentSourceRules.validate(sources: [archived, candidate]))
        }
        XCTAssertThrowsError(try PaymentSourceRules.resolve("wallet", in: [archived]))
    }

    func testAmbiguousInputDoesNotResolveArbitrarily() {
        XCTAssertThrowsError(try PaymentSourceRules.resolve("wallet", in: [
            PaymentSource(name: "One", aliases: ["wallet"]),
            PaymentSource(name: "Two", aliases: ["Wallet"])
        ]))
    }

    func testBlankValuesRejectedAndRenameRetainsIdentity() throws {
        XCTAssertThrowsError(try PaymentSourceRules.validate(sources: [PaymentSource(name: " \n")]))
        XCTAssertThrowsError(try PaymentSourceRules.validate(sources: [PaymentSource(name: "Wallet", aliases: [" "])]))
        let original = PaymentSource(name: "Old")
        var renamed = original
        renamed.name = " New  Wallet "
        let result = try PaymentSourceRules.normalized(renamed, in: [original])
        XCTAssertEqual(result.id, original.id)
        XCTAssertEqual(result.name, "New Wallet")
    }

    @MainActor
    func testStoreRejectsAliasConflictsAndPersistsRenameArchiveWithHistory() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("expenses.json")
        let store = try ExpenseStore(fileURL: url)
        let source = try store.addSource(PaymentSource(name: "Personal wallet", aliases: ["Pocket"]))
        XCTAssertThrowsError(try store.addSource(PaymentSource(name: "Own collision", aliases: ["own COLLISION"])))
        XCTAssertThrowsError(try store.addSource(PaymentSource(name: "Repeated aliases", aliases: ["Repeat", "REPEAT"])))
        XCTAssertThrowsError(try store.addSource(PaymentSource(name: "pocket")))
        XCTAssertThrowsError(try store.addSource(PaymentSource(name: "Other", aliases: ["POCKET"])))
        let expense = Expense(amount: 15000, description: "Lunch", sourceID: source.id, channel: "QRIS", date: Date())
        try store.addExpense(expense)
        var renamed = source
        renamed.name = "Renamed wallet"
        renamed.isArchived = true
        try store.updateSource(renamed)
        XCTAssertThrowsError(try store.deleteSource(id: source.id))
        XCTAssertThrowsError(try store.addSource(PaymentSource(name: "Pocket")))
        let reloaded = try ExpenseStore(fileURL: url)
        XCTAssertEqual(reloaded.expenses.first?.sourceID, source.id)
        XCTAssertEqual(reloaded.sourceName(for: source.id), "Renamed wallet")
        XCTAssertEqual(reloaded.sources.first { $0.id == source.id }?.isArchived, true)
        XCTAssertFalse(reloaded.activeSources.contains { $0.id == source.id })
        XCTAssertTrue(reloaded.paymentMethod(for: expense).contains("QRIS"))
        XCTAssertTrue(reloaded.paymentMethod(for: expense).contains("Renamed wallet"))
    }

    @MainActor
    func testUnusedSourceCanBeRemoved() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("expenses.json")
        let store = try ExpenseStore(fileURL: url)
        let added = try store.addSource(PaymentSource(name: "Temporary"))
        try store.deleteSource(id: added.id)
        XCTAssertFalse(try ExpenseStore(fileURL: url).sources.contains { $0.id == added.id })
    }

    @MainActor
    func testSourceMutationFailureDoesNotPublishChanges() throws {
        enum WriteFailure: Error { case diskFull }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        var failWrites = false
        let store = try ExpenseStore(fileURL: url, write: { _, _ in
            if failWrites { throw WriteFailure.diskFull }
        })
        let before = store.sources
        failWrites = true
        XCTAssertThrowsError(try store.addSource(PaymentSource(name: "New wallet")))
        var changed = before[0]
        changed.name = "Renamed"
        XCTAssertThrowsError(try store.updateSource(changed))
        XCTAssertThrowsError(try store.deleteSource(id: before[0].id))
        XCTAssertEqual(store.sources, before)
    }

    @MainActor
    func testLoadRejectsAmbiguousAliasesIncludingArchivedSources() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        struct Snapshot: Encodable {
            let version = 1
            let expenses: [Expense] = []
            let sources: [PaymentSource]
        }
        let snapshot = Snapshot(sources: [
            PaymentSource(name: "One", aliases: ["Pocket"], isArchived: true),
            PaymentSource(name: "Two", aliases: ["pocket"])
        ])
        try JSONEncoder().encode(snapshot).write(to: url)
        XCTAssertThrowsError(try ExpenseStore(fileURL: url))
    }
}
