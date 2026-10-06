# Sarafi / Hawala module

Menu: Dashboard drawer -> SARAFI -> Sarafi / Hawala (Admin, Manager, Cashier).

Tabs: Exchange, Hawala, Accounts (customers + partner sarafs), Rates, Daily Report.

## Accounting rules
- Nothing is stored as a running balance. Cash per currency = SUM(fx_cash), account balance = SUM(fx_ledger).
  Editing or deleting a transaction removes its own rows (by `ref_id`) and posts new ones, so balances cannot drift.
- Balance sign: positive = we hold their money (we owe them); negative = they owe us.
- Exchange: customer gives X (cash in) and receives Y (cash out). Profit is an ESTIMATE: value received minus value given at the mid rate ((buy+sell)/2).
- Hawala out: cash +(amount+commission), we owe the partner `amount`.
- Hawala in: nothing posts until "Pay out"; then cash -amount and the partner owes us amount+commission.
- Cancelling a hawala removes everything it posted.
- Deleting is Admin only. There is no Recycle Bin for Sarafi records yet.

## Tests
`flutter test integration_test` on an emulator (workflow "Accounting tests (emulator)").
