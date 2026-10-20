import SwiftUI

struct ContentView: View {
    @ObservedObject var store: ExpenseStore
    @State private var amount = ""
    @State private var description = ""
    @State private var sourceID: UUID?
    @State private var channel = ""
    @State private var date = Date()
    @State private var savedID: UUID?
    @State private var editingExpense: Expense?
    @State private var errorMessage: String?

    private var savedExpense: Expense? {
        store.expenses.first { $0.id == savedID }
    }

    var body: some View {
        TabView {
            NavigationStack {
                Form {
                    Section("New expense") {
                        TextField("Amount (whole rupiah, no separators)", text: $amount)
                            .keyboardType(.numberPad)
                        TextField("Description", text: $description)
                        PaymentSourceEntry(store: store, selection: $sourceID)
                        Picker("Payment channel", selection: $channel) {
                            Text("Choose a channel").tag("")
                            ForEach(PaymentChannels.choices, id: \.self) { choice in
                                Text(choice).tag(choice)
                            }
                        }
                        DatePicker("Expense date", selection: $date, displayedComponents: .date)
                        Button("Save expense", action: save)
                    }
                    if let expense = savedExpense {
                        Section("Saved on phone") {
                            Text(Rupiah.string(expense.amount)).font(.headline)
                            Text(expense.description)
                            Text(store.paymentMethod(for: expense))
                            Text(expense.date.formatted(date: .abbreviated, time: .omitted))
                            Button("Edit") { editingExpense = expense }
                            Button("Undo save", role: .destructive) { undo(expense) }
                            Button("Dismiss confirmation") { savedID = nil }
                        }
                    }
                    if let errorMessage {
                        Section { Text(errorMessage).foregroundStyle(.red) }
                    }
                }
                .navigationTitle("Record expense")
            }
            .tabItem { Label("Record", systemImage: "plus.circle") }
            NavigationStack { ExpenseHistoryView(store: store) }
                .tabItem { Label("History", systemImage: "list.bullet") }
        }
        .sheet(item: $editingExpense) { expense in
            ExpenseEditorView(store: store, expense: expense)
        }
    }

    private func save() {
        savedID = nil
        errorMessage = nil
        guard let value = ExpenseValidation.amount(from: amount), let sourceID else {
            errorMessage = "Enter a positive whole rupiah amount without separators and select a payment source."
            return
        }
        do {
            let expense = try store.addExpense(Expense(amount: value, description: description,
                                                      sourceID: sourceID, channel: channel, date: date))
            savedID = expense.id
            amount = ""
            description = ""
            date = Date()
        } catch {
            errorMessage = "Could not save expense. " + error.localizedDescription
        }
    }

    private func undo(_ expense: Expense) {
        do {
            try store.deleteExpense(id: expense.id)
            savedID = nil
            errorMessage = nil
        } catch {
            errorMessage = "Could not undo save. " + error.localizedDescription
        }
    }
}
