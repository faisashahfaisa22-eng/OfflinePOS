-- OfflinePOS v8.3 secure cloud state
-- Run this once in Supabase: SQL Editor -> New query -> Run

create table if not exists public.pos_cloud_state (
  owner_id uuid primary key default auth.uid(),
  data jsonb not null default '{}'::jsonb,
  auth_users jsonb not null default '[]'::jsonb,
  app_version text,
  updated_at timestamptz not null default now()
);

alter table public.pos_cloud_state enable row level security;

drop policy if exists "owner can read own pos cloud state" on public.pos_cloud_state;
create policy "owner can read own pos cloud state"
on public.pos_cloud_state
for select
to authenticated
using (owner_id = auth.uid());

drop policy if exists "owner can insert own pos cloud state" on public.pos_cloud_state;
create policy "owner can insert own pos cloud state"
on public.pos_cloud_state
for insert
to authenticated
with check (owner_id = auth.uid());

drop policy if exists "owner can update own pos cloud state" on public.pos_cloud_state;
create policy "owner can update own pos cloud state"
on public.pos_cloud_state
for update
to authenticated
using (owner_id = auth.uid())
with check (owner_id = auth.uid());

revoke all on table public.pos_cloud_state from anon;
grant select, insert, update on table public.pos_cloud_state to authenticated;
