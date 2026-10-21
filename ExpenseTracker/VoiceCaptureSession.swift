import Foundation
import Combine

@MainActor
final class VoiceCaptureSession: ObservableObject {
    @Published var draft = VoiceDraft()
    @Published private(set) var questions: [String] = []
    @Published private(set) var errorMessage: String?
    @Published private(set) var unfamiliarSource: String?
    @Published private(set) var savedExpense: Expense?
    @Published private(set) var isSaving = false
    @Published private(set) var cleanupPending = false
    @Published private(set) var resumedDraft = false
    @Published private(set) var storageAvailable = true

    private let store: ExpenseStore
    private let drafts: VoiceDraftStore
    private let interpret: (String, [PaymentSource], Date) -> VoiceInterpretation
    private var discarded = false

    init(store: ExpenseStore, drafts: VoiceDraftStore = VoiceDraftStore(fileURL: VoiceDraftStore.defaultFileURL),
         interpret: @escaping (String, [PaymentSource], Date) -> VoiceInterpretation = {
             VoiceInterpreter.interpret($0, sources: $1, now: $2)
         }) {
        self.store = store
        self.drafts = drafts
        self.interpret = interpret
        do {
            if let existing = try drafts.load() {
                if let saved = store.expenses.first(where: { $0.id == existing.id }) {
                    savedExpense = saved
                    cleanupPending = true
                    retryCleanup()
                } else {
                    draft = existing
                    resumedDraft = true
                    questions = ["Resume this draft by editing it or recording a follow-up."]
                }
            }
        } catch {
            storageAvailable = false
            errorMessage = "Could not read the saved draft. It has been preserved. " + error.localizedDescription
        }
    }

    @discardableResult
    func preserve() -> Bool {
        guard storageAvailable, savedExpense == nil, !discarded else { return false }
        do {
            try drafts.save(draft)
            return true
        } catch {
            errorMessage = "Draft remains on screen but could not be stored. " + error.localizedDescription
            return false
        }
    }

    func receive(_ text: String) {
        guard savedExpense == nil, storageAvailable else { return }
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let correctionPrefixes = ["correction:", "correction ", "koreksi:", "koreksi "]
        if let prefix = correctionPrefixes.first(where: { value.lowercased().hasPrefix($0) }) {
            // A full spoken correction replaces uncertain wording without creating another capture.
            draft.transcript = String(value.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        } else if !draft.transcript.isEmpty, !value.isEmpty, let combined = completeMissingFields(with: value) {
            draft.transcript = combined
        } else if !value.isEmpty {
            draft.transcript += (draft.transcript.isEmpty ? "" : "\n") + value
        }
        retry()
    }

    /// Fill only missing slots. Contradictory/uncertain answers keep the ordinary clarification path.
    /// Normalize the result into editable text so a later Retry/relaunch keeps the same meaning.
    private func completeMissingFields(with answer: String) -> String? {
        var original = interpret(draft.transcript, store.sources, draft.capturedAt)
        var reply = interpret(answer, store.sources, draft.capturedAt)
        guard original.issues.isEmpty, reply.issues.isEmpty else { return nil }
        if original.sourceID == nil, original.unresolvedSource == nil,
           let source = try? PaymentSourceRules.resolve(answer, in: store.sources) {
            reply.sourceID = source.id
            reply.expenseDescription = nil
        }
        // Retain contradictory answers with an explicit uncertainty marker so Retry cannot
        // silently combine them into a different purchase. A full correction can replace it.
        let conflict = "Maybe " + draft.transcript + "\n" + answer
        if let first = original.amount, let next = reply.amount, first != next { return conflict }
        if let first = original.channel, let next = reply.channel, first != next { return conflict }
        if let first = original.sourceID, let next = reply.sourceID, first != next { return conflict }
        if let first = original.expenseDescription, let next = reply.expenseDescription,
           PaymentSourceRules.key(first) != PaymentSourceRules.key(next) { return conflict }
        if let source = reply.unresolvedSource {
            if original.sourceID != nil { return conflict }
            if let first = original.unresolvedSource,
               PaymentSourceRules.key(first) != PaymentSourceRules.key(source) { return conflict }
        }
        if original.unresolvedSource != nil && reply.sourceID != nil { return conflict }
        let captureDay = Calendar.current.startOfDay(for: draft.capturedAt)
        let explicitDate = answer.range(of: #"\b(today|yesterday|kemarin|hari ini|dua hari lalu)\b"#,
                                       options: [.regularExpression, .caseInsensitive]) != nil
        if explicitDate, let replyDate = reply.date, replyDate != original.date { return conflict }
        var filled = false
        if original.amount == nil, let amount = reply.amount { original.amount = amount; filled = true }
        if original.expenseDescription == nil, let description = reply.expenseDescription {
            original.expenseDescription = description; filled = true
        }
        if original.channel == nil, let channel = reply.channel { original.channel = channel; filled = true }
        if original.sourceID == nil, original.unresolvedSource == nil {
            if let id = reply.sourceID { original.sourceID = id; filled = true }
            else if let source = reply.unresolvedSource { original.unresolvedSource = source; filled = true }
        }
        guard filled, let date = original.date else { return nil }
        let days = Calendar.current.dateComponents([.day], from: captureDay, to: date).day
        let dateText: String
        switch days {
        case 0: dateText = "today"
        case -1: dateText = "yesterday"
        case -2: dateText = "day before yesterday"
        default: return nil
        }
        var pieces = [original.expenseDescription ?? ""]
        if let amount = original.amount { pieces.append("\(amount) rupiah") }
        pieces.append(dateText)
        let source = original.sourceID.map { store.sourceName(for: $0) } ?? original.unresolvedSource ?? ""
        if original.channel != nil || !source.isEmpty {
            pieces.append("using \(original.channel ?? "") \(source)")
        }
        return pieces.joined(separator: " ")
    }

    func recognitionFailed(_ message: String, capturedText: String) {
        guard savedExpense == nil, storageAvailable else { return }
        let value = capturedText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !value.isEmpty { draft.transcript += (draft.transcript.isEmpty ? "" : "\n") + value }
        _ = preserve()
        errorMessage = message + " Edit the captured text and Retry, type the fields, or record again."
    }

    func keepPartialSpeech(_ text: String) {
        guard savedExpense == nil, storageAvailable else { return }
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !value.isEmpty { draft.transcript += (draft.transcript.isEmpty ? "" : "\n") + value }
        _ = preserve()
    }

    func retry() {
        guard savedExpense == nil, !isSaving, storageAvailable else { return }
        errorMessage = nil
        guard preserve() else { return }
        guard !draft.transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            questions = ["No speech was captured. Type your expense or record again."]
            return
        }
        let result = interpret(draft.transcript, store.sources, draft.capturedAt)
        draft.amount = result.amount.map(String.init) ?? ""
        draft.expenseDescription = result.expenseDescription ?? ""
        draft.sourceID = result.sourceID
        draft.channel = result.channel ?? ""
        if let date = result.date { draft.date = date }
        unfamiliarSource = result.unresolvedSource
        questions = result.issues
        if result.amount == nil { questions.append("What is the total amount in whole rupiah?") }
        if result.expenseDescription == nil { questions.append("What did you buy?") }
        if result.sourceID == nil && result.unresolvedSource == nil { questions.append("Which payment source did you use?") }
        if result.channel == nil { questions.append("Which payment channel did you use, such as QRIS or Cash?") }
        if result.date == nil { questions.append("What was the expense date?") }
        guard preserve() else { return }
        if questions.isEmpty && unfamiliarSource == nil { saveManual() }
    }

    func confirmUnfamiliarSource() {
        guard let name = unfamiliarSource, storageAvailable, savedExpense == nil else { return }
        do {
            let source: PaymentSource
            if let known = try PaymentSourceRules.resolve(name, in: store.sources) { source = known }
            else { source = try store.addSource(PaymentSource(name: name)) }
            draft.sourceID = source.id
            unfamiliarSource = nil
            // Reinterpret with the now-confirmed source; all other ambiguities still block auto-save.
            retry()
        } catch { errorMessage = error.localizedDescription }
    }

    func saveManual() {
        guard savedExpense == nil, !isSaving, storageAvailable else { return }
        guard let amount = ExpenseValidation.amount(from: draft.amount), let sourceID = draft.sourceID,
              !draft.expenseDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !draft.channel.isEmpty, draft.date.timeIntervalSinceReferenceDate.isFinite else {
            errorMessage = "Complete the amount, description, payment source, channel, and date before saving."
            return
        }
        guard preserve() else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            // Reuse the persisted capture ID for every retry, including after relaunch.
            if let existing = store.expenses.first(where: { $0.id == draft.id }) {
                savedExpense = existing
            } else {
                savedExpense = try store.addExpense(Expense(id: draft.id, amount: amount,
                    description: draft.expenseDescription, sourceID: sourceID,
                    channel: draft.channel, date: draft.date))
            }
            cleanupPending = true
            retryCleanup()
        } catch {
            errorMessage = savedExpense == nil
                ? "Could not save expense. Your draft is available for retry. " + error.localizedDescription
                : "Expense saved, but draft cleanup failed. " + error.localizedDescription
        }
    }

    func retryCleanup() {
        guard savedExpense != nil else { return }
        do {
            try drafts.discard()
            draft.transcript = ""
            cleanupPending = false
            errorMessage = nil
        } catch {
            cleanupPending = true
            errorMessage = "Expense saved, but draft cleanup failed. Retry cleanup before closing. " + error.localizedDescription
        }
    }

    @discardableResult
    func cancel() -> Bool {
        guard storageAvailable, savedExpense == nil else { return false }
        do {
            try drafts.discard()
            discarded = true
            draft = VoiceDraft()
            return true
        } catch {
            errorMessage = "Could not discard draft. " + error.localizedDescription
            return false
        }
    }
}
