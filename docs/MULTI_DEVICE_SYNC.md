# QAMVIO multi-device sync — design (BETA, server side ready, app engine NOT built yet)

## Goal
Owner + workers on separate phones see the same shop data, each phone still works offline.

## Server (done): `supabase/qamvio_sync.sql`
Shops, members (owner/manager/cashier/salesman/viewer), one-time invites (hashed),
an append-only encrypted op log, an encrypted snapshot. RLS: members read; only
non-viewers insert; only the owner writes snapshots/invites. The server never sees plain data.

## App engine (NOT built — reasons)
The current database changes stock and balances with in-place deltas
(`stock = stock - qty`) and uses `INSERT OR REPLACE` widely; sale edit deletes and
re-inserts. A safe sync must therefore:
1. Log every row change through SQLite triggers into an outbox (not through app code).
2. Send counters (stock, balances, tank level) as **deltas**, never as final values,
   or two phones selling the same product offline would overwrite each other.
3. Apply remote ops with a `sync_ctl.applying` flag so triggers do not echo them back.
4. Resolve other fields by last-write-wins on `updated_at`.
5. Bootstrap a new device from the encrypted snapshot, then replay ops after `upto_seq`.
6. Derive the shop key from the owner password (PBKDF2) and share it to workers inside the invite.

This touches the shop's real money data. It cannot be compiled or run here, so it must be
built and tested on a spare phone with copied data before it goes near a live shop.

## Suggested order
1. Ship roles (done), confirm GitHub build. 2. Run the SQL in a test Supabase project.
3. Build the engine behind a "Sync (beta)" switch, default OFF, tested with two spare phones.
