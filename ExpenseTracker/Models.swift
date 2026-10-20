import Foundation

struct Expense: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var amount: Int64
    var description: String
    var sourceID: UUID
    var channel: String
    var date: Date
}

struct PaymentSource: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var aliases: [String] = []
    var isArchived: Bool = false
}

enum ExpenseValidation {
    // Accept ASCII digits only: separators, signs, decimals and overflow are errors.
    static func amount(from text: String) -> Int64? {
        guard !text.isEmpty, text.utf8.allSatisfy({ (48...57).contains($0) }),
              let value = Int64(text), value > 0 else { return nil }
        return value
    }
}

enum Rupiah {
    static func string(_ amount: Int64) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "id_ID")
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return "Rp" + (formatter.string(from: NSNumber(value: amount)) ?? String(amount))
    }
}

enum PaymentChannels {
    static let choices = ["QRIS", "Cash", "Transfer", "Debit card", "Credit card"]
}