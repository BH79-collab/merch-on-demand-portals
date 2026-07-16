-- Migration: per-product DTF print zone configuration
--
-- Run this once in the Supabase SQL editor. Lets an admin define a custom
-- print-placement box (in the 200x220 SVG viewBox coordinate space used by
-- both onboarding.html's design canvas and the admin Print Zones editor)
-- for each product/side, overriding the generic default box.

create table if not exists public.print_zones (
  id          uuid primary key default gen_random_uuid(),
  product_id  text not null,
  side        text not null check (side in ('front','back')),
  x           numeric not null,
  y           numeric not null,
  w           numeric not null,
  h           numeric not null,
  updated_at  timestamptz not null default now(),
  unique (product_id, side)
);

alter table public.print_zones enable row level security;

-- Onboarding is a public, unauthenticated wizard — it needs to read zone
-- data with the anon key. Zone coordinates aren't sensitive.
create policy "anyone can read print zones" on public.print_zones
  for select using (true);

-- Only admins (app_metadata.role = 'admin') can create/edit/delete zones.
create policy "admins manage print zones" on public.print_zones
  for all using (auth.jwt() -> 'app_metadata' ->> 'role' = 'admin')
  with check (auth.jwt() -> 'app_metadata' ->> 'role' = 'admin');
