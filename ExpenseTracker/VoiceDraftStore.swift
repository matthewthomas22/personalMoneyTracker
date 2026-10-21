import Foundation

/// Only the active capture is retained. Drafts are never added to ExpenseStore.
struct VoiceDraft: Codable, Equatable {
    var id = UUID()
    var capturedAt = Date()
    var transcript = ""
    var amount = ""
    var expenseDescription = ""
    var sourceID: UUID?
    var channel = ""
    var date = Date()
}

struct VoiceDraftStore {
    let fileURL: URL
    var write: (Data, URL) throws -> Void = { data, url in
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }
    var remove: (URL) throws -> Void = { try FileManager.default.removeItem(at: $0) }

    static var defaultFileURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ExpenseTracker", isDirectory: true)
            .appendingPathComponent("voice-draft.json")
    }

    func load() throws -> VoiceDraft? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        return try JSONDecoder().decode(VoiceDraft.self, from: Data(contentsOf: fileURL))
    }

    func save(_ draft: VoiceDraft) throws {
        try write(JSONEncoder().encode(draft), fileURL)
    }

    func discard() throws {
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try remove(fileURL)
        }
    }
}
