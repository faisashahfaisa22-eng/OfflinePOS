-- QAMVIO license foundation. Run in Supabase SQL editor.
create extension if not exists pgcrypto;
create table if not exists public.licenses (
 id uuid primary key default gen_random_uuid(),
 customer_name text not null,
 code_hash text not null unique,
 max_devices integer not null default 1 check (max_devices between 1 and 100),
 expires_at timestamptz,
 status text not null default 'active' check (status in ('active','blocked')),
 created_at timestamptz not null default now()
);
create table if not exists public.license_devices (
 id uuid primary key default gen_random_uuid(),
 license_id uuid not null references public.licenses(id) on delete cascade,
 device_hash text not null,
 activated_at timestamptz not null default now(),
 last_seen_at timestamptz,
 revoked_at timestamptz,
 unique(license_id,device_hash)
);
create table if not exists public.license_attempts (
 id bigint generated always as identity primary key,
 license_id uuid references public.licenses(id) on delete set null,
 device_hash text,
 outcome text not null,
 created_at timestamptz not null default now()
);
create index if not exists license_devices_active_idx on public.license_devices(license_id) where revoked_at is null;
create index if not exists license_attempts_created_idx on public.license_attempts(created_at desc);
alter table public.licenses enable row level security;
alter table public.license_devices enable row level security;
alter table public.license_attempts enable row level security;
-- No policies: anon/authenticated clients cannot directly read or modify licensing data.
-- Activation and administration must run in authenticated server-side Edge Functions.
-- Store only SHA-256 hashes of high-entropy activation codes, never plaintext.
