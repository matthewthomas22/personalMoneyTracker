# Personal Expense Tracking

Personal spending recorded from a person's spoken description.

## Language

**Expense**:
Money spent on a purchase, described by its amount, purpose, and payment method.
_Avoid_: Row of data

**Amount**:
The money spent on an expense, expressed in its currency.
_Avoid_: Amount used

**Description**:
A short explanation of what an expense was for, such as sausage bought at Indomaret.
_Avoid_: Purpose text

**Payment method**:
The combination of the payment channel and the payment source used for an expense, such as QRIS through GoPay.
_Avoid_: Payment source when referring to the full method

**Payment channel**:
The way a payment is made, such as QRIS.
_Avoid_: Payment source

**Payment source**:
The wallet, account, or cash used to fund an expense, such as GoPay or SeaBank.
_Avoid_: Payment channel

**Draft expense**:
An unfinished expense awaiting clarification, correction, or successful interpretation. It is excluded from recorded spending totals.
_Avoid_: Saved expense
