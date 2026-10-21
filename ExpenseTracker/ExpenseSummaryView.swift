import SwiftUI

struct ExpenseSummaryView: View {
    @ObservedObject var store: ExpenseStore
    @State private var selectedYear = ExpenseSummary.reportingCalendar.component(.year, from: Date())
    @State private var selectedMonth = ExpenseSummary.reportingCalendar.component(.month, from: Date())

    var body: some View {
        let calendar = ExpenseSummary.reportingCalendar
        let totals = ExpenseSummary.calculate(expenses: store.expenses, year: selectedYear,
                                              month: selectedMonth, calendar: calendar)
        Form {
            Section("Period") {
                Picker("Month", selection: $selectedMonth) {
                    ForEach(1...12, id: \.self) { month in
                        Text(calendar.monthSymbols[month - 1]).tag(month)
                    }
                }
                Stepper(value: $selectedYear, in: 1...9999) {
                    Text("Year \(String(selectedYear))")
                }
                .accessibilityValue(String(selectedYear))
            }
            Section("\(calendar.monthSymbols[selectedMonth - 1]) \(String(selectedYear))") {
                Text(totals.month.display).font(.title2)
                    .accessibilityLabel("Monthly total: \(totals.month.display)")
            }
            Section("Year \(String(selectedYear))") {
                Text(totals.year.display).font(.title2)
                    .accessibilityLabel("Yearly total: \(totals.year.display)")
            }
            Section {
                Text("Saved expenses on this phone, by expense date. Drafts are excluded. Periods use the Gregorian calendar and this device's time zone.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Summary")
    }
}
