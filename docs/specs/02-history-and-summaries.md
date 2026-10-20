# History and Summaries

## Confirmed Behavior

- Group saved expenses by date. Show amount, description, and combined payment method as the primary presentation.
- Support editing and deletion, plus Edit and Undo in the save confirmation.
- Provide a Summary screen in the same app with month/year selection, the selected month's total, and the selected year's total.
- Calculate from local saved expenses by expense date, including pending uploads and excluding drafts.
- Update totals after edits, deletion, or Undo. Date edits change the corresponding month/year totals.
- No charts, budgets, or category analysis in version one.

## Acceptance Criteria

| ID | Scenario | Expected result |
|---|---|---|
| HIS-01 | Open history with multiple days of spending | Group by expense date; show amount, description, and payment method. |
| HIS-02 | Edit amount, description, or payment method | Update history and make the corresponding Sheets update eligible for synchronization. |
| HIS-03 | Delete an expense or Undo a new save | Remove its local spending contribution and reconcile any corresponding Sheets row. |
| SUM-01 | Save Rp15.000 and Rp10.000 in one month | Monthly total is Rp25.000. |
| SUM-02 | Add Rp30.000 in another month of the same year | Year total is Rp55.000; each month retains its own total. |
| SUM-03 | Add a draft and a saved pending-upload expense | Exclude the draft; include the saved expense exactly once. |
| SUM-04 | Edit Rp15.000 to Rp20.000, then delete Rp10.000 | Relevant totals increase by Rp5.000, then decrease by Rp10.000. |
| SUM-05 | Move an expense from December 2026 to January 2027 | Remove its contribution from December/2026 and add it to January/2027. |
| SUM-06 | Switch selected month or year | Show that period's total based on expense dates, independent of upload dates. |

## Validation Notes

Use an independently calculated expense set and exercise month/year boundaries offline. No detailed visual layout or chart system has been selected.
