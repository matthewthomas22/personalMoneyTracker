import SwiftUI

@MainActor
struct VoiceCaptureView: View {
    @ObservedObject var store: ExpenseStore
    @StateObject private var session: VoiceCaptureSession
    @StateObject private var speech = SpeechCapture()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var locale = "id-ID"
    @State private var keyboardMode = false
    @State private var deliveredSave = false
    let onSaved: (Expense) -> Void
    let onKeyboard: () -> Void

    init(store: ExpenseStore, onSaved: @escaping (Expense) -> Void = { _ in },
         onKeyboard: @escaping () -> Void = {}) {
        self.store = store
        self.onSaved = onSaved
        self.onKeyboard = onKeyboard
        _session = StateObject(wrappedValue: VoiceCaptureSession(store: store))
    }

    var body: some View {
        NavigationStack {
            Form {
                if let error = session.errorMessage {
                    Section { Text(error).foregroundStyle(.red) }
                }
                if let expense = session.savedExpense {
                    Section("Saved on phone") {
                        Text(Rupiah.string(expense.amount))
                        Text(expense.description)
                        Text(store.paymentMethod(for: expense))
                        if session.cleanupPending {
                            Button("Retry draft cleanup") { session.retryCleanup() }
                        }
                    }
                } else if session.storageAvailable {
                    Section(session.resumedDraft ? "Resume draft" : "Voice expense") {
                        Picker("Recognition language", selection: $locale) {
                            Text("Indonesian / mixed").tag("id-ID")
                            Text("English / mixed").tag("en-US")
                        }.disabled(speech.isProcessing)
                        if speech.isListening {
                            Text("Listening…").accessibilityIdentifier("voiceListening")
                            Text(speech.transcript)
                            Button("Done") { speech.finish() }
                        } else {
                            if speech.isProcessing { Text("Preparing or finishing recognition…") }
                            Button(session.draft.transcript.isEmpty ? "Record" : "Record a follow-up") {
                                Task { await speech.start(localeIdentifier: locale) }
                            }.disabled(session.isSaving || speech.isProcessing)
                        }
                        Button("Switch to keyboard") {
                            if speech.isProcessing { session.keepPartialSpeech(speech.transcript) }
                            speech.cancel()
                            keyboardMode = true
                        }
                        Text("Speech recognition may use Apple’s servers. Audio is not archived by this app. Draft text stays on this phone until saved or cancelled.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if !session.questions.isEmpty {
                        Section("Please clarify") {
                            ForEach(Array(session.questions.enumerated()), id: \.offset) { _, question in
                                Text(question)
                            }
                            Text("Answer by recording a follow-up, edit the captured text and Retry, or correct the fields below and Save.")
                                .font(.caption)
                            Text("To replace an unclear amount, date, or payment, say ‘correction’ (or ‘koreksi’) and restate the complete expense. This keeps the same capture.")
                                .font(.caption)
                        }
                    }
                    Section("Captured text · editable draft") {
                        TextEditor(text: $session.draft.transcript)
                            .frame(minHeight: 100)
                            .accessibilityIdentifier("voiceDraftText")
                        Button("Retry interpretation") { session.retry() }
                            .disabled(speech.isProcessing || session.isSaving)
                    }
                    if let name = session.unfamiliarSource {
                        Section("Unfamiliar payment source") {
                            Text("Add \(name) as a payment source?")
                            Button("Add \(name)") { session.confirmUnfamiliarSource() }
                                .disabled(speech.isProcessing)
                            Text("To use an existing source instead, choose it below and Save. Nothing is added until you confirm.")
                                .font(.caption)
                        }
                    }
                    Section(keyboardMode ? "Keyboard entry" : "Review or correct fields") {
                        TextField("Amount (whole rupiah)", text: $session.draft.amount)
                            .keyboardType(.numberPad)
                        TextField("Description", text: $session.draft.expenseDescription)
                        PaymentSourceEntry(store: store, selection: $session.draft.sourceID)
                        Picker("Payment channel", selection: $session.draft.channel) {
                            Text("Choose a channel").tag("")
                            ForEach(PaymentChannels.choices, id: \.self) { Text($0).tag($0) }
                        }
                        DatePicker("Expense date", selection: $session.draft.date, displayedComponents: .date)
                        Button("Save expense") { session.saveManual() }
                            .disabled(speech.isProcessing || session.isSaving)
                    }
                    Button("Keep draft and return to main keyboard form") {
                        if speech.isProcessing { session.keepPartialSpeech(speech.transcript) }
                        speech.cancel()
                        if session.preserve() { onKeyboard(); dismiss() }
                    }
                }
            }
            .navigationTitle("Voice entry")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if session.savedExpense == nil {
                        Button("Cancel", role: .destructive) {
                            speech.cancel()
                            if session.cancel() { dismiss() }
                        }
                    }
                }
                if !session.storageAvailable {
                    ToolbarItem(placement: .confirmationAction) { Button("Close") { dismiss() } }
                }
            }
            .disabled(session.isSaving)
        }
        .interactiveDismissDisabled()
        .task {
            speech.onFinished = { session.receive($0) }
            speech.onFailure = { message in
                session.recognitionFailed(message, capturedText: speech.transcript)
            }
            if session.savedExpense != nil { deliverSaveWhenClean() }
            else if session.storageAvailable && !session.resumedDraft {
                await speech.start(localeIdentifier: locale)
            }
        }
        .onChange(of: session.draft) { _, _ in _ = session.preserve() }
        .onChange(of: session.savedExpense) { _, expense in
            if expense != nil { speech.cancel(); deliverSaveWhenClean() }
        }
        .onChange(of: session.cleanupPending) { _, _ in deliverSaveWhenClean() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active && speech.isProcessing {
                session.keepPartialSpeech(speech.transcript)
                speech.cancel()
            }
        }
        .onDisappear {
            speech.cancel()
            speech.onFinished = nil
            speech.onFailure = nil
        }
    }

    private func deliverSaveWhenClean() {
        guard !deliveredSave, !session.cleanupPending, let expense = session.savedExpense else { return }
        deliveredSave = true
        onSaved(expense)
        dismiss()
    }
}
