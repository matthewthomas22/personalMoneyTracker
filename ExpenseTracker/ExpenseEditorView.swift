import SwiftUI

struct ExpenseEditorView: View {
    @ObservedObject var store: ExpenseStore
    let expense: Expense
    @Environment(\.dismiss) private var dismiss
    @State private var amount: String
    @State private var description: String
    @State private var sourceID: UUID
    @State private var channel: String
    @State private var date: Date
    @State private var errorMessage: String?

    init(store: ExpenseStore, expense: Expense) {
        self.store = store
        self.expense = expense
        _amount = State(initialValue: String(expense.amount))
        _description = State(initialValue: expense.description)
        _sourceID = State(initialValue: expense.sourceID)
        _channel = State(initialValue: expense.channel)
        _date = State(initialValue: expense.date)
    }

    private var selectableSources: [PaymentSource] {
        store.sources.filter { !$0.isArchived || $0.id == expense.sourceID }
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Amount (whole rupiah)", text: $amount)
                    .keyboardType(.numberPad)
                TextField("Description", text: $description)
                Picker("Payment source", selection: $sourceID) {
                    ForEach(selectableSources) { source in
                        Text(source.name + (source.isArchived ? " (archived)" : ""))
                            .tag(source.id)
                    }
                }
                Picker("Payment channel", selection: $channel) {
                    ForEach(PaymentChannels.choices, id: \.self) { value in
                        Text(value).tag(value)
                    }
                    if !PaymentChannels.choices.contains(channel) {
                        Text(channel).tag(channel)
                    }
                }
                DatePicker("Expense date", selection: $date, displayedComponents: .date)
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                        .accessibilityIdentifier("expenseEditError")
                }
            }
            .navigationTitle("Edit expense")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save changes", action: save)
                }
            }
        }
    }

    private func save() {
        guard let value = ExpenseValidation.amount(from: amount) else {
            errorMessage = "Enter a positive whole rupiah amount without separators."
            return
        }
        var updated = expense
        updated.amount = value
        updated.description = description
        updated.sourceID = sourceID
        updated.channel = channel
        updated.date = date
        do {
            try store.updateExpense(updated)
            dismiss()
        } catch {
            // Keep both the editor and the user's correction available for retry.
            errorMessage = error.localizedDescription
        }
    }
}
