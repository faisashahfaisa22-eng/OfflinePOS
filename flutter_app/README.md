# QAMVIO POS — Flutter migration

This directory is the new native Flutter implementation of QAMVIO POS.

## Migration rules
- The existing Android/HTML app remains intact during migration.
- SQLite is the local source of truth.
- Cloud is a sync/backup layer, not a replacement for offline storage.
- Existing QAMVIO data must be imported before the legacy app is retired.
- Modules are migrated and tested one by one.

## Initial core
The first commit contains the Flutter application shell and SQLite schema for products, customers, suppliers, sales, sale items, purchases, expenses, salesmen, settings, sync queue, fuel tanks and fuel nozzles.

## Planned next slice
Authentication, existing-data importer, Products CRUD, Sales/Invoice transaction handling, then Supabase sync/restore.
