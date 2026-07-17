-- Migration: per-colour mockup images for Shopify publishing
--
-- Supports generating one mockup per colour variant (not just a single
-- generic front/back image), so each colour on the storefront shows the
-- logo actually composited on that colour, matching the base product's
-- own colour photography.

alter table public.vendor_products add column if not exists colour_mockups jsonb;
-- Shape: {"Army": {"front": "https://...", "back": "https://..."}, "Black": {...}, ...}
