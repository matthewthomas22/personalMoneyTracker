import Foundation
import Combine

@MainActor
final class ExpenseStore: ObservableObject {
    @Published private(set) var expenses: [Expense]
    @Published private(set) var sources: [PaymentSource]

    enum StoreError: LocalizedError {
        case invalidExpense, invalidSource, notFound, sourceInUse, unsupportedVersion
        var errorDescription: String? {
            switch self {
            case .invalidExpense: return "Enter a positive whole rupiah amount, description, active payment source, channel, and valid date."
            case .invalidSource: return "A payment source needs a unique name."
            case .notFound: return "This record no longer exists."
            case .sourceInUse: return "This source is used by an expense. Archive it instead."
            case .unsupportedVersion: return "This data file requires a newer version of the app."
            }
        }
    }

    private struct Snapshot: Codable {
        var version = 1
        var expenses: [Expense]
        var sources: [PaymentSource]
    }
    private let fileURL: URL
    private let write: (Data, URL) throws -> Void

    static func defaultFileURL() throws -> URL {
        try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                    appropriateFor: nil, create: true)
            .appendingPathComponent("ExpenseTracker", isDirectory: true)
            .appendingPathComponent("expenses.json")
    }

    // Injecting the writer lets tests exercise disk failures before any published mutation.
    init(fileURL: URL, write: @escaping (Data, URL) throws -> Void = { data, url in
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }) throws {
        self.fileURL = fileURL
        self.write = write
        if FileManager.default.fileExists(atPath: fileURL.path) {
            let snapshot = try JSONDecoder().decode(Snapshot.self, from: Data(contentsOf: fileURL))
            guard snapshot.version == 1 else { throw StoreError.unsupportedVersion }
            try Self.validate(snapshot)
            expenses = snapshot.expenses
            sources = snapshot.sources
        } else {
            let snapshot = Snapshot(expenses: [], sources: [
                PaymentSource(name: "GoPay"), PaymentSource(name: "SeaBank"), PaymentSource(name: "Cash")
            ])
            try write(JSONEncoder().encode(snapshot), fileURL)
            expenses = snapshot.expenses
            sources = snapshot.sources
        }
    }

    var activeSources: [PaymentSource] { sources.filter { !$0.isArchived } }
    func sourceName(for id: UUID) -> String { sources.first { $0.id == id }?.name ?? "Unknown source" }
    func paymentMethod(for expense: Expense) -> String { "\(expense.channel) · \(sourceName(for: expense.sourceID))" }

    @discardableResult
    func addExpense(_ expense: Expense) throws -> Expense {
        guard !expenses.contains(where: { $0.id == expense.id }) else { throw StoreError.invalidExpense }
        let value = try normalized(expense)
        try persist(expenses: expenses + [value], sources: sources)
        return value
    }

    func updateExpense(_ expense: Expense) throws {
        guard let index = expenses.firstIndex(where: { $0.id == expense.id }) else { throw StoreError.notFound }
        let value = try normalized(expense, previous: expenses[index])
        var next = expenses
        next[index] = value
        try persist(expenses: next, sources: sources)
    }

    func deleteExpense(id: UUID) throws {
        guard expenses.contains(where: { $0.id == id }) else { throw StoreError.notFound }
        try persist(expenses: expenses.filter { $0.id != id }, sources: sources)
    }

    @discardableResult
    func addSource(_ source: PaymentSource) throws -> PaymentSource {
        guard !sources.contains(where: { $0.id == source.id }) else { throw StoreError.invalidSource }
        let value = normalized(source)
        try persist(expenses: expenses, sources: sources + [value])
        return value
    }

    func updateSource(_ source: PaymentSource) throws {
        guard let index = sources.firstIndex(where: { $0.id == source.id }) else { throw StoreError.notFound }
        var next = sources
        next[index] = normalized(source)
        try persist(expenses: expenses, sources: next)
    }

    func deleteSource(id: UUID) throws {
        guard sources.contains(where: { $0.id == id }) else { throw StoreError.notFound }
        guard !expenses.contains(where: { $0.sourceID == id }) else { throw StoreError.sourceInUse }
        try persist(expenses: expenses, sources: sources.filter { $0.id != id })
    }

    private func normalized(_ expense: Expense, previous: Expense? = nil) throws -> Expense {
        var value = expense
        value.description = value.description.trimmingCharacters(in: .whitespacesAndNewlines)
        value.channel = value.channel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard sources.contains(where: { $0.id == value.sourceID && (!$0.isArchived || previous?.sourceID == $0.id) }) else {
            throw StoreError.invalidExpense
        }
        return value
    }

    private func normalized(_ source: PaymentSource) -> PaymentSource {
        var value = source
        value.name = value.name.trimmingCharacters(in: .whitespacesAndNewlines)
        value.aliases = value.aliases.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        return value
    }

    private static func validate(_ snapshot: Snapshot) throws {
        try PaymentSourceRules.validate(sources: snapshot.sources)
        guard Set(snapshot.sources.map(\.id)).count == snapshot.sources.count,
              Set(snapshot.sources.map { $0.name.lowercased() }).count == snapshot.sources.count,
              snapshot.sources.allSatisfy({ !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            throw StoreError.invalidSource
        }
        guard Set(snapshot.expenses.map(\.id)).count == snapshot.expenses.count,
              snapshot.expenses.allSatisfy({ expense in
                  expense.amount > 0 && !expense.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                  && !expense.channel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                  && expense.date.timeIntervalSinceReferenceDate.isFinite
                  && snapshot.sources.contains(where: { $0.id == expense.sourceID })
              }) else { throw StoreError.invalidExpense }
    }

    private func persist(expenses: [Expense], sources: [PaymentSource]) throws {
        let snapshot = Snapshot(expenses: expenses, sources: sources)
        try Self.validate(snapshot)
        let data = try JSONEncoder().encode(snapshot)
        try write(data, fileURL)
        self.expenses = expenses
        self.sources = sources
    }
}
