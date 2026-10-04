-- QAMVIO multi-device sync — server side (BETA, not yet used by the app)
-- Run once in Supabase > SQL Editor. Data in `payload` is encrypted by the app
-- (AES-GCM); the server only sees opaque blobs and who may read/write them.

create table if not exists qamvio_shops (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  name text,
  created_at timestamptz not null default now()
);

create table if not exists qamvio_shop_members (
  shop_id uuid not null references qamvio_shops(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('owner','manager','cashier','salesman','viewer')),
  created_at timestamptz not null default now(),
  primary key (shop_id, user_id)
);

create table if not exists qamvio_shop_invites (
  code_hash text primary key,            -- sha256 of the invite code
  shop_id uuid not null references qamvio_shops(id) on delete cascade,
  role text not null check (role in ('manager','cashier','salesman','viewer')),
  expires_at timestamptz not null,
  used_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);

create table if not exists qamvio_sync_ops (
  seq bigint generated always as identity primary key,
  shop_id uuid not null references qamvio_shops(id) on delete cascade,
  device_id text not null,
  author uuid not null default auth.uid(),
  op_id text not null,                   -- client-generated, makes pushes idempotent
  payload text not null,                 -- encrypted op
  created_at timestamptz not null default now(),
  unique (shop_id, op_id)
);
create index if not exists qamvio_sync_ops_shop_seq on qamvio_sync_ops (shop_id, seq);

create table if not exists qamvio_sync_snapshots (
  shop_id uuid primary key references qamvio_shops(id) on delete cascade,
  upto_seq bigint not null default 0,
  payload text not null,                 -- encrypted full snapshot
  updated_at timestamptz not null default now()
);

alter table qamvio_shops enable row level security;
alter table qamvio_shop_members enable row level security;
alter table qamvio_shop_invites enable row level security;
alter table qamvio_sync_ops enable row level security;
alter table qamvio_sync_snapshots enable row level security;

create or replace function qamvio_is_member(p_shop uuid) returns boolean
language sql security definer set search_path = public as $$
  select exists (select 1 from qamvio_shop_members where shop_id = p_shop and user_id = auth.uid());
$$;

create or replace function qamvio_can_write(p_shop uuid) returns boolean
language sql security definer set search_path = public as $$
  select exists (select 1 from qamvio_shop_members
                 where shop_id = p_shop and user_id = auth.uid() and role <> 'viewer');
$$;

create or replace function qamvio_is_owner(p_shop uuid) returns boolean
language sql security definer set search_path = public as $$
  select exists (select 1 from qamvio_shops where id = p_shop and owner_id = auth.uid());
$$;

drop policy if exists shops_read on qamvio_shops;
create policy shops_read on qamvio_shops for select using (qamvio_is_member(id));

drop policy if exists members_read on qamvio_shop_members;
create policy members_read on qamvio_shop_members for select using (qamvio_is_member(shop_id));
drop policy if exists members_owner_delete on qamvio_shop_members;
create policy members_owner_delete on qamvio_shop_members for delete using (qamvio_is_owner(shop_id));

drop policy if exists invites_owner on qamvio_shop_invites;
create policy invites_owner on qamvio_shop_invites for all
  using (qamvio_is_owner(shop_id)) with check (qamvio_is_owner(shop_id));

drop policy if exists ops_read on qamvio_sync_ops;
create policy ops_read on qamvio_sync_ops for select using (qamvio_is_member(shop_id));
drop policy if exists ops_insert on qamvio_sync_ops;
create policy ops_insert on qamvio_sync_ops for insert
  with check (qamvio_can_write(shop_id) and author = auth.uid());

drop policy if exists snap_read on qamvio_sync_snapshots;
create policy snap_read on qamvio_sync_snapshots for select using (qamvio_is_member(shop_id));
drop policy if exists snap_owner_write on qamvio_sync_snapshots;
create policy snap_owner_write on qamvio_sync_snapshots for all
  using (qamvio_is_owner(shop_id)) with check (qamvio_is_owner(shop_id));

-- Owner creates a shop (becomes owner member).
create or replace function qamvio_create_shop(p_name text) returns uuid
language plpgsql security definer set search_path = public as $$
declare v uuid;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  insert into qamvio_shops(owner_id, name) values (auth.uid(), p_name) returning id into v;
  insert into qamvio_shop_members(shop_id, user_id, role) values (v, auth.uid(), 'owner');
  return v;
end $$;

-- Owner creates a one-time invite; the app shows the raw code, only its hash is stored.
create or replace function qamvio_create_invite(p_shop uuid, p_code_hash text, p_role text, p_hours int default 48)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not qamvio_is_owner(p_shop) then raise exception 'owner only'; end if;
  insert into qamvio_shop_invites(code_hash, shop_id, role, expires_at)
  values (p_code_hash, p_shop, p_role, now() + make_interval(hours => p_hours));
end $$;

-- Worker joins with the invite code (worker has their own Supabase account).
create or replace function qamvio_join_shop(p_code_hash text) returns uuid
language plpgsql security definer set search_path = public as $$
declare inv qamvio_shop_invites;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  select * into inv from qamvio_shop_invites
   where code_hash = p_code_hash and used_by is null and expires_at > now() for update;
  if not found then raise exception 'invalid or expired code'; end if;
  insert into qamvio_shop_members(shop_id, user_id, role) values (inv.shop_id, auth.uid(), inv.role)
  on conflict (shop_id, user_id) do update set role = excluded.role;
  update qamvio_shop_invites set used_by = auth.uid() where code_hash = p_code_hash;
  return inv.shop_id;
end $$;

grant execute on function qamvio_create_shop(text), qamvio_create_invite(uuid,text,text,int),
  qamvio_join_shop(text) to authenticated;
