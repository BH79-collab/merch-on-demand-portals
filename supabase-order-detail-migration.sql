-- Migration: order pricing display + fulfillment tracking
--
-- Trimmed down from an earlier draft that also captured customer name/
-- email/shipping address/subtotal/shipping cost — not needed, ShipStation
-- already handles the customer-facing/shipping side once Shopify marks an
-- order fulfilled. This just adds what Production actually needs: a
-- human-readable order number, per-unit pricing, and fulfillment state.

alter table public.orders add column if not exists order_number text;
alter table public.orders add column if not exists unit_price numeric;

alter table public.orders add column if not exists fulfillment_status text not null default 'unfulfilled';
alter table public.orders add column if not exists tracking_number text;
alter table public.orders add column if not exists tracking_company text;
alter table public.orders add column if not exists fulfilled_at timestamptz;
