# QAMVIO offline-first laptop and mobile sync plan

Status: design specification only. **Not implemented or deployed.**

## Modes
1. Laptop-only: local encrypted store, optional cloud disaster recovery.
2. Mobile-only: local encrypted store, optional cloud disaster recovery.
3. Mobile + laptop: same authenticated business workspace; incremental bidirectional sync when connected, offline transactions queued.

## Safety and invariants
- Never use a whole-database backup as a bidirectional sync primitive.
- Existing `qamvio_flutter_backups` is a disaster-recovery snapshot, not a live sync channel.
- Preserve current records and existing encrypted backup; no schema reset or destructive migration.
- All sync rows scoped by verified business/workspace membership with Supabase RLS; never trust client-provided workspace IDs alone.
- Each device gets a stable registered device ID; every mutation has a globally unique operation ID and monotonically increasing local sequence number.
- Upload operations idempotently, with server-side deduplication and transactional application.
- Use a server-issued cursor to download changes in deterministic order; acknowledge only after local transaction commits.
- Sales, inventory adjustments, transfers, cash movements and ledger postings are append-only operations. Never last-write-wins these financial events.
- Conflicts on editable catalog fields require explicit revision checks and a conflict-resolution UX.
- Prevent cross-device double-posting and negative stock according to explicit business rules.
- Offline queue is encrypted at rest and must survive app restarts.
- Local and server schema migrations must be versioned and backward compatible.
- Keep a separate verified, versioned backup and restore flow; reject empty-overwrite and show last verified successful backup time.
- Restore and first-time pairing must not upload an empty snapshot over a populated workspace.
- Avoid leaking encryption keys or private business data into logs.
- Web PWA needs a browser-compatible storage/crypto adapter; Android-only `dart:io` and `sqflite_sqlcipher` cannot be reused directly.

## Acceptance tests before release
- Laptop-only operates offline; mobile-only operates offline.
- Pair two devices; create sale on A, see it exactly once on B, including stock, payments and reports.
- Offline sales on both devices, reconnect in either order; no lost or duplicated ledger entries.
- Repeated delivery, reordered delivery, retries, interrupted uploads and restarts are idempotent.
- Concurrent edits to the same customer/product do not silently overwrite each other.
- A new empty install cannot overwrite any populated cloud backup.
- Restore a verified populated backup to a new device and compare per-table counts and financial totals.
- Wrong account/workspace cannot read or alter another business.
- Web Chrome build, Android build, and database migrations pass automated tests.
- Publish to qamvio.com only after full E2E testing and explicit production release gate.
