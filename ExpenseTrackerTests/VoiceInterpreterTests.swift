import XCTest
@testable import ExpenseTracker

final class VoiceInterpreterTests: XCTestCase {
    private let wallet = PaymentSource(name: "GoPay", aliases: ["Go Pay"])
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Jakarta")!
        return calendar
    }
    private var now: Date { calendar.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: 1))! }

    func testIndonesianAcceptanceExampleAndAlias() {
        let result = VoiceInterpreter.interpret("Beli sosis di Indomaret lima belas ribu, pakai QRIS Go Pay", sources: [wallet])
        XCTAssertTrue(result.isComplete, result.issues.joined(separator: ", "))
        XCTAssertEqual(result.amount, 15000)
        XCTAssertEqual(result.sourceID, wallet.id)
        XCTAssertEqual(result.channel, "QRIS")
        XCTAssertTrue(result.expenseDescription?.contains("sosis di indomaret") == true)
    }

    func testEnglishMissingPaymentThenMixedFollowUp() {
        let original = "I bought a sausage from Indomaret for 15.000 rupiah"
        let missing = VoiceInterpreter.interpret(original, sources: [wallet])
        XCTAssertEqual(missing.amount, 15000)
        XCTAssertNil(missing.channel)
        XCTAssertFalse(missing.isComplete)
        let completed = VoiceInterpreter.interpret(original + " QRIS GoPay", sources: [wallet])
        XCTAssertTrue(completed.isComplete)
        XCTAssertEqual(completed.amount, 15000)
    }

    func testMissingAmountDescriptionAndSourceCanBeSpokenInLaterTurns() {
        for transcript in ["Lunch QRIS GoPay\n15000 rupiah", "15000 rupiah QRIS GoPay\nLunch", "Lunch 15000 rupiah QRIS\nGoPay"] {
            let result = VoiceInterpreter.interpret(transcript, sources: [wallet])
            XCTAssertTrue(result.isComplete, transcript + " " + result.issues.joined(separator: ", "))
            XCTAssertEqual(result.amount, 15000)
            XCTAssertEqual(result.expenseDescription, "lunch")
            XCTAssertEqual(result.sourceID, wallet.id)
        }
    }

    func testRelatedItemAmountsCombineAsOnePurchase() {
        let result = VoiceInterpreter.interpret("Sosis 15 ribu dan susu 10 ribu, QRIS GoPay", sources: [wallet])
        XCTAssertTrue(result.isComplete)
        XCTAssertEqual(result.amount, 25000)
        XCTAssertTrue(result.expenseDescription?.contains("sosis") == true)
        XCTAssertTrue(result.expenseDescription?.contains("susu") == true)
    }

    func testRelativeDateUsesLocalCalendarAcrossYearBoundary() {
        let yesterday = VoiceInterpreter.interpret("Coffee fifteen thousand rupiah yesterday using QRIS GoPay", sources: [wallet], now: now, calendar: calendar)
        XCTAssertTrue(yesterday.isComplete)
        XCTAssertEqual(calendar.dateComponents([.year, .month, .day], from: yesterday.date!), DateComponents(year: 2025, month: 12, day: 31))
        let today = VoiceInterpreter.interpret("Kopi 15 ribu QRIS GoPay", sources: [wallet], now: now, calendar: calendar)
        XCTAssertEqual(today.date, calendar.startOfDay(for: now))
    }

    func testUnknownArchivedAndAmbiguousSourcesNeverAutoSave() {
        let unknown = VoiceInterpreter.interpret("Coffee 15 ribu QRIS New Wallet", sources: [wallet])
        XCTAssertEqual(unknown.unresolvedSource, "new wallet")
        XCTAssertFalse(unknown.isComplete)
        var archived = wallet
        archived.isArchived = true
        XCTAssertFalse(VoiceInterpreter.interpret("Coffee 15 ribu QRIS GoPay", sources: [archived]).isComplete)
        XCTAssertFalse(VoiceInterpreter.interpret("Coffee 15 ribu QRIS GoPay", sources: [wallet, PaymentSource(name: "Other", aliases: ["GoPay"])]).isComplete)
    }

    func testAmbiguousAmountsPaymentsAndDatesNeverAutoSave() {
        for text in [
            "Coffee -15000 rupiah QRIS GoPay", "Coffee +15000 rupiah QRIS GoPay",
            "Coffee minus 15000 rupiah QRIS GoPay", "Coffee 15,5 rupiah QRIS GoPay",
            "Coffee 15.50 rupiah QRIS GoPay", "Coffee fifteen fifteen thousand QRIS GoPay",
            "Coffee about 15 ribu QRIS GoPay", "Coffee 15 ribu or 10 ribu QRIS GoPay",
            "Coffee 15 ribu and milk 10 ribu total 25 ribu QRIS GoPay",
            "Coffee 15 ribu milk 10 ribu QRIS GoPay", "Coffee 15 ribu QRIS GoPay cash",
            "Coffee 15 ribu yesterday today QRIS GoPay", "Coffee 15 ribu last Friday QRIS GoPay",
            "2 sausages QRIS GoPay", "Two sausages 15 ribu QRIS GoPay",
            "Coffee 9223372036854775808 rupiah QRIS GoPay"
        ] {
            XCTAssertFalse(VoiceInterpreter.interpret(text, sources: [wallet]).isComplete, text)
        }
    }

    func testNumberWordsHandleHundredsAndMixedLanguage() {
        for (words, amount) in [("seratus lima puluh ribu", Int64(150000)),
                                ("two hundred fifty thousand", 250000),
                                ("dua puluh five ribu", 25000), ("one million two hundred thousand", 1200000)] {
            let result = VoiceInterpreter.interpret("Belanja \(words) QRIS GoPay", sources: [wallet])
            XCTAssertTrue(result.isComplete, words)
            XCTAssertEqual(result.amount, amount, words)
        }
    }

    func testRupiahPrefixCanTouchDigits() {
        let result = VoiceInterpreter.interpret("Kopi Rp15000 QRIS GoPay", sources: [wallet])
        XCTAssertTrue(result.isComplete)
        XCTAssertEqual(result.amount, 15000)
    }

    func testNoTextAndMissingDescriptionDoNotSave() {
        XCTAssertFalse(VoiceInterpreter.interpret("", sources: [wallet]).isComplete)
        XCTAssertFalse(VoiceInterpreter.interpret("15 ribu QRIS GoPay", sources: [wallet]).isComplete)
    }
}
