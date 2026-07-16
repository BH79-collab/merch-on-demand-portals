-- Migration: move vendor/admin login onto Supabase Auth
--
-- Run this once in the Supabase SQL editor (Project > SQL Editor > New query).
-- Column/table names below match what index.html, onboarding.html and payout.html
-- already reference (vendors.id/email/status/plan/payout_rate, orders.vendor_id,
-- payments.vendor_id, subscriptions.vendor_id). Adjust if your live schema differs
-- — this repo has no prior migrations to diff against, so double-check column names
-- against the actual table definitions before running.

-- 1. Link each vendor row to its Supabase Auth user.
alter table public.vendors
  add column if not exists auth_user_id uuid references auth.users(id);

create unique index if not exists vendors_auth_user_id_key
  on public.vendors(auth_user_id);

-- 2. Lock down the vendor-facing tables with RLS. Without this, the anon key
--    embedded in the client can already read/write every vendor's data —
--    signInWithPassword alone does not restrict query results.
alter table public.vendors      enable row level security;
alter table public.orders       enable row level security;
alter table public.payments     enable row level security;
alter table public.subscriptions enable row level security;

-- Admins (app_metadata.role = 'admin', set via Dashboard > Authentication > Users,
-- never by the client) can do anything.
create policy "admins full access to vendors" on public.vendors
  for all using (auth.jwt() -> 'app_metadata' ->> 'role' = 'admin')
  with check (auth.jwt() -> 'app_metadata' ->> 'role' = 'admin');

create policy "admins full access to orders" on public.orders
  for all using (auth.jwt() -> 'app_metadata' ->> 'role' = 'admin')
  with check (auth.jwt() -> 'app_metadata' ->> 'role' = 'admin');

create policy "admins full access to payments" on public.payments
  for all using (auth.jwt() -> 'app_metadata' ->> 'role' = 'admin')
  with check (auth.jwt() -> 'app_metadata' ->> 'role' = 'admin');

create policy "admins full access to subscriptions" on public.subscriptions
  for all using (auth.jwt() -> 'app_metadata' ->> 'role' = 'admin')
  with check (auth.jwt() -> 'app_metadata' ->> 'role' = 'admin');

-- Vendors can read/update only their own row, and read only their own orders/payments.
create policy "vendor reads own row" on public.vendors
  for select using (auth_user_id = auth.uid());

create policy "vendor updates own row" on public.vendors
  for update using (auth_user_id = auth.uid())
  with check (auth_user_id = auth.uid());

create policy "vendor reads own orders" on public.orders
  for select using (
    vendor_id in (select id from public.vendors where auth_user_id = auth.uid())
  );

create policy "vendor reads own payments" on public.payments
  for select using (
    vendor_id in (select id from public.vendors where auth_user_id = auth.uid())
  );

-- 3. Backfill note: no existing vendor rows need auth_user_id populated
--    (pre-launch, no real vendor accounts yet per project decision).
