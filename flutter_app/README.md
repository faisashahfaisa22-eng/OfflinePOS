# QAMVIO POS Flutter migration

This directory is the native Flutter replacement for the legacy HTML/WebView client.

Implemented foundation:
- Offline-first SQLite database.
- Products, sales/invoice items, customers, suppliers, salesmen, purchases and expenses.
- Fuel/oil pump tank and nozzle foundation.
- Persistent settings and a cloud sync queue.
- Flutter dashboard shell and module navigation.
- Dependencies for Supabase cloud, QR/barcode scanning and QR generation.

The existing Android/WebView application remains untouched while migration proceeds, so production data is not put at risk.

Do not remove the legacy app until import/export compatibility and cloud restore have been verified against real QAMVIO backups.
