# QAMVIO Flutter migration

This directory is the native Flutter migration track for QAMVIO POS.

## Phase 2 implemented
- SQLite offline database foundation
- Purchases and purchase items
- Accounts / cash ledger
- Customer / supplier / salesman loans
- Report summary
- Oil Pump foundation: tanks, nozzles schema, meter closing, litres, cash/credit, customer and salesman
- Pharmacy batch / expiry inventory foundation
- Settings and business types
- Invoice table + PDF / printing foundation

## Existing app safety
The current Android HTML/WebView app remains untouched outside this directory. Flutter migration can therefore be developed and tested without risking the production data path.

## Next engineering work
- Migrate existing Products, Sales, Customers, Suppliers and Expenses into Flutter repositories/screens.
- Add stock movements so purchases and fuel deliveries update inventory atomically.
- Add loan repayment transaction history.
- Complete oil-pump delivery/tank/nozzle/shift reconciliation.
- Add pharmacy sale validation against expiry/batch stock.
- Add full sales invoice editor and thermal-printer profiles.
- Add authentication, encrypted cloud sync/restore and migration from the existing QAMVIO encrypted backup format.
- Add Android/iOS platform folders with `flutter create .` in this directory, then CI build/release.

## Local start
```bash
cd flutter_app
flutter create .
flutter pub get
flutter run
```
