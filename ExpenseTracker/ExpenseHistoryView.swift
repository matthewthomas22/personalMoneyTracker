import SwiftUI

struct ExpenseDateGroup: Identifiable {
    let date: Date
    let expenses: [Expense]
    var id: Date { date }
}

enum ExpenseHistoryGrouping {
    static func groups(expenses: [Expense], calendar: Calendar = .current) -> [ExpenseDateGroup] {
        Dictionary(grouping: expenses) { calendar.startOfDay(for: $0.date) }
            .map { date, values in
                ExpenseDateGroup(date: date, expenses: values.sorted {
                    if $0.date != $1.date { return $0.date > $1.date }
                    return $0.id.uuidString < $1.id.uuidString
                })
            }
            .sorted { $0.date > $1.date }
    }
}

struct ExpenseHistoryView: View {
    @ObservedObject var store: ExpenseStore
    @Environment(\.calendar) private var calendar
    @State private var editingExpense: Expense?
    @State private var pendingDeletion: Expense?
    @State private var errorMessage: String?

    var body: some View {
        List {
            if store.expenses.isEmpty {
                Text("No saved expenses yet.").foregroundStyle(.secondary)
            }
            ForEach(ExpenseHistoryGrouping.groups(expenses: store.expenses, calendar: calendar)) { group in
                Section(group.date.formatted(date: .complete, time: .omitted)) {
                    ForEach(group.expenses) { expense in
                        Button {
                            editingExpense = expense
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(Rupiah.string(expense.amount)).font(.headline)
                                Text(expense.description)
                                Text(store.paymentMethod(for: expense))
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }
                            .foregroundStyle(.primary)
                        }
                        .accessibilityHint("Edit expense")
                        .swipeActions {
                            Button("Delete", role: .destructive) { pendingDeletion = expense }
                            Button("Edit") { editingExpense = expense }.tint(.blue)
                        }
                        .contextMenu {
                            Button("Edit") { editingExpense = expense }
                            Button("Delete", role: .destructive) { pendingDeletion = expense }
                        }
                    }
                }
            }
        }
        .navigationTitle("History")
        .sheet(item: $editingExpense) { expense in
            ExpenseEditorView(store: store, expense: expense)
        }
        .confirmationDialog("Delete this expense?", isPresented: Binding(
            get: { pendingDeletion != nil },
            set: { if !$0 { pendingDeletion = nil } }
        ), titleVisibility: .visible) {
            if let expense = pendingDeletion {
                Button("Delete expense", role: .destructive) { delete(expense) }
            }
            Button("Cancel", role: .cancel) { pendingDeletion = nil }
        }
        .alert("Could not delete expense", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func delete(_ expense: Expense) {
        do {
            try store.deleteExpense(id: expense.id)
            pendingDeletion = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
