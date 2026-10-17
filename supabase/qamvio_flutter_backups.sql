create table if not exists public.qamvio_flutter_backups (
  user_id uuid primary key references auth.users(id) on delete cascade,
  payload jsonb not null,
  updated_at timestamptz not null default now()
);

alter table public.qamvio_flutter_backups enable row level security;

drop policy if exists "flutter_backup_select_own" on public.qamvio_flutter_backups;
create policy "flutter_backup_select_own" on public.qamvio_flutter_backups
for select to authenticated using ((select auth.uid()) = user_id);

drop policy if exists "flutter_backup_insert_own" on public.qamvio_flutter_backups;
create policy "flutter_backup_insert_own" on public.qamvio_flutter_backups
for insert to authenticated with check ((select auth.uid()) = user_id);

drop policy if exists "flutter_backup_update_own" on public.qamvio_flutter_backups;
create policy "flutter_backup_update_own" on public.qamvio_flutter_backups
for update to authenticated using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);
