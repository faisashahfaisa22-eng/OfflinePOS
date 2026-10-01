# QAMVIO POS Flutter migration

This folder is the new Flutter implementation. The existing HTML/WebView Android app remains intact while features are migrated and tested.

Implemented now: Flutter application shell, SQLite offline database, foreign keys, WAL mode, durable sync queue, core POS schema, oil/fuel schema, and a dashboard that reads SQLite directly.

Migration rule: local SQLite commits first. Cloud sync mirrors data afterward and must never be the only copy.

Next: authentication and Supabase sync, inventory CRUD, sales and invoices, ledgers, expenses/accounts, oil pump workflows, reports, QR/barcode, and printing.
