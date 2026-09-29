-- QAMVIO POS encrypted cloud backup store
-- Run once in Supabase SQL editor or apply as a migration.

create table if not exists public.qamvio_cloud_backups (
  user_id uuid primary key references auth.users(id) on delete cascade,
  payload jsonb not null,
  updated_at timestamptz not null default now()
);

alter table public.qamvio_cloud_backups enable row level security;

drop policy if exists "qamvio_select_own_backup" on public.qamvio_cloud_backups;
create policy "qamvio_select_own_backup"
on public.qamvio_cloud_backups
for select
to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "qamvio_insert_own_backup" on public.qamvio_cloud_backups;
create policy "qamvio_insert_own_backup"
on public.qamvio_cloud_backups
for insert
to authenticated
with check ((select auth.uid()) = user_id);

drop policy if exists "qamvio_update_own_backup" on public.qamvio_cloud_backups;
create policy "qamvio_update_own_backup"
on public.qamvio_cloud_backups
for update
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

drop policy if exists "qamvio_delete_own_backup" on public.qamvio_cloud_backups;
create policy "qamvio_delete_own_backup"
on public.qamvio_cloud_backups
for delete
to authenticated
using ((select auth.uid()) = user_id);

revoke all on table public.qamvio_cloud_backups from anon;
grant select, insert, update, delete on table public.qamvio_cloud_backups to authenticated;
