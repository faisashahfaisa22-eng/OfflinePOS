# QAMVIO POS Flutter migration

This directory is the new native Flutter implementation.

Architecture:
- Flutter native UI
- SQLite (sqflite) is the offline source of truth
- Sync queue prepared for Supabase synchronization
- Supabase Auth/Cloud dependencies prepared
- WorkManager prepared for daily background backup
- Native QR/barcode dependencies prepared

The existing Android/HTML app stays intact while Flutter modules are rebuilt and tested. Do not remove the legacy app until data migration, cloud restore, invoices, reports, retail/pharmacy/fuel modules, and hardware flows pass tests.
