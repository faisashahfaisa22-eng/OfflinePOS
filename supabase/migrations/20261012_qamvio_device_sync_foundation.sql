-- Additive, opt-in foundation for offline-first multi-device sync.
-- This does not modify or read the existing qamvio_flutter_backups table.
-- Sync is NOT enabled until authenticated clients and conflict handling are ready.
create table if not exists public.qamvio_sync_operations (
  owner_uid uuid not null references auth.users(id) on delete cascade,
  operation_id uuid not null,
  device_id uuid not null,
  device_sequence bigint not null check (device_sequence > 0),
  entity_type text not null check (char_length(entity_type) between 1 and 80),
  entity_id text not null check (char_length(entity_id) between 1 and 160),
  operation_kind text not null check (operation_kind in ('create','update','append','delete')),
  payload jsonb not null,
  created_at timestamptz not null default now(),
  primary key (owner_uid, operation_id),
  unique (owner_uid, device_id, device_sequence)
);
create index if not exists qamvio_sync_operations_download_idx
  on public.qamvio_sync_operations(owner_uid, created_at, operation_id);
alter table public.qamvio_sync_operations enable row level security;
revoke all on public.qamvio_sync_operations from anon;
grant select, insert on public.qamvio_sync_operations to authenticated;
drop policy if exists qamvio_sync_operations_select_self on public.qamvio_sync_operations;
create policy qamvio_sync_operations_select_self
  on public.qamvio_sync_operations for select to authenticated
  using (owner_uid = (select auth.uid()));
drop policy if exists qamvio_sync_operations_insert_self on public.qamvio_sync_operations;
create policy qamvio_sync_operations_insert_self
  on public.qamvio_sync_operations for insert to authenticated
  with check (owner_uid = (select auth.uid()));
-- No update/delete policy: history is append-only.
-- IMPORTANT: This foundation is single-owner scoped. Shared staff/workspace
-- membership and encrypted payload design require further implementation.
