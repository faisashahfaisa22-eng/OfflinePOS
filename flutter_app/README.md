# QAMVIO POS — Flutter migration

This branch is the new native Flutter implementation. The existing Android/HTML app on main remains untouched while Flutter reaches feature parity.

## Implemented
- Native Flutter shell and Material UI
- Native SQLite database (schema v2)
- Products, inventory, customers, suppliers
- Sales/invoices and sale items
- Purchases and purchase items
- Expenses, accounts and account transactions
- Salesmen, loans and loan payments
- Pharmacy batch/expiry data
- Oil pump tanks, nozzles, shifts and fuel sales
- Settings
- Email/mobile Supabase authentication
- Per-user full SQLite cloud backup and restore through qamvio_flutter_backups
- Server-side history for the previous 20 Flutter cloud backup versions
- GitHub Actions Flutter analyze/test/release APK workflow

## Still to migrate before replacing the production app
The complete screens and business logic from the HTML version: CRUD forms, invoice line editor/printing, reports, retail/pharmacy/oil workflows, QR/barcode UX, localization, permissions/roles, old HTML-data importer, automatic scheduled background backup, and end-to-end recovery tests.

## Safety
Do not uninstall the current production QAMVIO app yet. The Flutter branch uses a new SQLite database and is a migration build until old-data import and feature parity are verified.
