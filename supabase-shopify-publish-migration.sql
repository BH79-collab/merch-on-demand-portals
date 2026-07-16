-- Migration: track Shopify publish state per vendor product
--
-- Supports the admin "Approve & Publish to Shopify" action — creates a real
-- Shopify product (with a composited mockup image, price = base product
-- price + $20, published live) for each of a vendor's chosen products.
-- These columns let the UI know what's already been pushed, and avoid
-- creating duplicate Shopify products on a repeat click.

alter table public.vendor_products add column if not exists front_mockup_url text;
alter table public.vendor_products add column if not exists back_mockup_url text;
alter table public.vendor_products add column if not exists shopify_product_id text;
alter table public.vendor_products add column if not exists published_at timestamptz;

-- No new Storage bucket/policies needed — mockup images reuse the existing
-- public vendor-logos bucket (path-prefixed "mockups/...") and its policies.
