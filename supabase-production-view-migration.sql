-- Migration: link orders to their artwork, add production tracking
--
-- Supports an admin "Production" view: for each order line item, show
-- exactly which vendor_products row (and therefore which logo/mockup
-- files) it came from, which colour was ordered, and a simple status/notes
-- workflow for the production team (matching the pending -> approved ->
-- goods_ordered -> shipped style pipeline already used in the MOD app).

alter table public.orders add column if not exists vendor_product_id uuid references public.vendor_products(id);
alter table public.orders add column if not exists variant_title text;
alter table public.orders add column if not exists production_status text not null default 'pending';
alter table public.orders add column if not exists production_notes text;

-- RLS already covers orders (admins full access, vendor reads own orders)
-- from the original auth migration — no new policies needed here.
