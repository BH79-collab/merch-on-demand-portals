-- Migration: structured vendor product/logo storage
--
-- Replaces the current approach of embedding base64 logo images inside
-- vendors.notes (JSON text) — one test row already hit ~69KB from a single
-- logo. Real files go into Supabase Storage; placement/product selection
-- goes into a proper table so vendors can view and edit their setup later.

create table if not exists public.vendor_products (
  id              uuid primary key default gen_random_uuid(),
  vendor_id       uuid not null references public.vendors(id) on delete cascade,
  product_id      text not null,
  colours         text[] not null default '{}',
  sizes           text[] not null default '{}',
  front_logo_url  text,
  back_logo_url   text,
  front_placement jsonb,
  back_placement  jsonb,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  unique (vendor_id, product_id)
);

alter table public.vendor_products enable row level security;

create policy "vendor reads own products" on public.vendor_products
  for select using (
    vendor_id in (select id from public.vendors where auth_user_id = auth.uid())
  );

create policy "vendor inserts own products" on public.vendor_products
  for insert with check (
    vendor_id in (select id from public.vendors where auth_user_id = auth.uid())
  );

create policy "vendor updates own products" on public.vendor_products
  for update using (
    vendor_id in (select id from public.vendors where auth_user_id = auth.uid())
  ) with check (
    vendor_id in (select id from public.vendors where auth_user_id = auth.uid())
  );

create policy "vendor deletes own products" on public.vendor_products
  for delete using (
    vendor_id in (select id from public.vendors where auth_user_id = auth.uid())
  );

create policy "admins full access to vendor_products" on public.vendor_products
  for all using (auth.jwt() -> 'app_metadata' ->> 'role' = 'admin')
  with check (auth.jwt() -> 'app_metadata' ->> 'role' = 'admin');

-- Storage bucket for logo files. Public read (they're used in <image> tags
-- across onboarding, the vendor portal and the admin print-zone editor).
-- Uploads are allowed with just the anon key: the onboarding wizard uploads
-- a logo during the Design step, *before* the vendor's Supabase Auth account
-- exists yet (signup happens later, at checkout) — gating writes on
-- auth.role()='authenticated' would break that. Logo images aren't
-- sensitive data, so this trade-off is acceptable, consistent with the
-- rest of this app's current security posture.
insert into storage.buckets (id, name, public)
values ('vendor-logos', 'vendor-logos', true)
on conflict (id) do nothing;

create policy "anyone can view vendor logos" on storage.objects
  for select using (bucket_id = 'vendor-logos');

create policy "anyone can upload vendor logos" on storage.objects
  for insert with check (bucket_id = 'vendor-logos');

create policy "anyone can update vendor logos" on storage.objects
  for update using (bucket_id = 'vendor-logos') with check (bucket_id = 'vendor-logos');

create policy "anyone can delete vendor logos" on storage.objects
  for delete using (bucket_id = 'vendor-logos');
