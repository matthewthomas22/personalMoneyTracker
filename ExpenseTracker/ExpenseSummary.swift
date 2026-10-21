import Foundation

enum ExpenseSummaryTotal: Equatable {
    case amount(Int64)
    case overflow

    var display: String {
        switch self {
        case .amount(let value): return Rupiah.string(value)
        case .overflow: return "Total exceeds the supported amount"
        }
    }
}

struct ExpenseSummary: Equatable {
    let month: ExpenseSummaryTotal
    let year: ExpenseSummaryTotal

    // Reporting uses Gregorian months in the device's local time zone, like the
    // numbered monthly reports. Inject a calendar to make boundary checks stable.
    static var reportingCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .autoupdatingCurrent
        return calendar
    }

    static func calculate(expenses: [Expense], year: Int, month: Int,
                          calendar: Calendar = reportingCalendar) -> ExpenseSummary {
        var monthly: ExpenseSummaryTotal = .amount(0)
        var yearly: ExpenseSummaryTotal = .amount(0)
        for expense in expenses {
            let components = calendar.dateComponents([.year, .month], from: expense.date)
            guard components.year == year else { continue }
            yearly = adding(expense.amount, to: yearly)
            if components.month == month {
                monthly = adding(expense.amount, to: monthly)
            }
        }
        return ExpenseSummary(month: monthly, year: yearly)
    }

    private static func adding(_ amount: Int64, to total: ExpenseSummaryTotal) -> ExpenseSummaryTotal {
        guard case .amount(let value) = total else { return .overflow }
        let sum = value.addingReportingOverflow(amount)
        return sum.overflow ? .overflow : .amount(sum.partialValue)
    }
}
