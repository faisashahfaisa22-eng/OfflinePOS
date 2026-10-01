# QAMVIO POS Flutter migration

This folder is the new native Flutter implementation. The current Android/HTML application is intentionally kept intact while migration proceeds.

## Implemented now
- Flutter application shell
- Native SQLite database qamvio_pos.db
- Products, customers, suppliers, sales, sale items, purchases, expenses, salesmen, accounts and settings tables
- Persistent offline sync queue
- Supabase email/mobile authentication foundation
- Cloud queue sync foundation
- Dashboard reading directly from SQLite

## Safety rule
Do not remove the current app until the old data importer and every business module are reproduced and tested in Flutter.

## Migration order
Inventory -> Sales/Invoice -> Customers/Suppliers -> Expenses/Accounts -> Reports -> Retail/Pharmacy/Oil Pump -> QR/Barcode/Printing -> encrypted cloud backup/restore.
