# Proxy change needed: `/vendor/save` (and the Stripe webhook) must store `auth_user_id`

Context: `onboarding.html` now creates the vendor's login account client-side via
`supabase.auth.signUp({ email, password })` *before* starting Stripe Checkout (see
`handleCheckout` in `onboarding.html`). The resulting Supabase Auth user id is now
included as `authUserId` everywhere vendor data is sent to the proxy. The proxy needs
to persist that id onto the vendor's row so `index.html` can look vendors up by
`auth_user_id` instead of by email.

No endpoint URLs, auth flow, or request paths are changing — this is additive: one
new field in, one new column set on write.

## 1. `POST /vendor/save` — add `authUserId` to the request, store it

This is the fallback save, called client-side after a successful Stripe redirect
(`onboarding.html`, "Handle Stripe Checkout return"). Body now looks like:

```json
{
  "meta": {
    "vendorName": "Rivera Designs",
    "category": "Fashion",
    "email": "jake@example.com",
    "authUserId": "3f2504e0-4f89-11d3-9a0c-0305e82c3301",
    "firstName": "Jake",
    "lastName": "Rivera",
    "phone": "+61 400 000 000",
    "street": "123 Main Street",
    "suburb": "Melbourne",
    "state": "VIC",
    "postcode": "3000",
    "country": "Australia",
    "bankName": "Commonwealth Bank",
    "bsb": "062-000",
    "accountNumber": "12345678",
    "accountName": "Jake Rivera",
    "planId": "starter",
    "productSlots": "[...]"
  },
  "email": "jake@example.com",
  "authUserId": "3f2504e0-4f89-11d3-9a0c-0305e82c3301",
  "sessionId": "cs_test_...",
  "subscriptionId": null
}
```

`authUserId` is included both top-level (for convenience, matching the existing
top-level `email`) and inside `meta`. It **may be `null`** — treat that as "sign-up
failed or was skipped" and fall back to whatever the endpoint currently does when a
vendor record can't be linked to an auth user (e.g. log and alert, don't silently
drop the row).

**Required change:** when inserting/upserting the vendor row, also set:

```sql
auth_user_id = :authUserId
```

Upsert key should be `email` (as today) if a row may already exist; on conflict,
still write `auth_user_id` even if the rest of the row is unchanged, so a retried
save doesn't leave it null.

## 2. Stripe Checkout `metadata` — same field, same handling

`POST /stripe/checkout` already receives a `metadata` object built from the same
`meta` structure above (see `handleCheckout`), so `authUserId` flows through there
too. If the proxy's Stripe webhook handler (`checkout.session.completed`) is the
*primary* path that writes the vendor row (with `/vendor/save` only as fallback),
apply the identical `auth_user_id = metadata.authUserId` write there. Note Stripe
Checkout session metadata values must be flat strings — if the proxy currently
JSON-stringifies the whole `meta` object into one metadata field rather than
spreading it into individual keys, no change is needed there; just parse
`authUserId` back out same as the other fields.

## 3. Important: this write needs the Supabase **service-role** key, not the anon key

Once `supabase-auth-migration.sql` is applied, Row Level Security is enabled on
`vendors` and there is **no INSERT policy for the anon/authenticated role** —
vendor rows are only ever created by the trusted backend. If the proxy is already
using a service-role key for its Supabase writes (likely, since it already writes
vendor rows today), no change needed here beyond making sure this particular write
also goes through that same service-role client. If it's currently using the anon
key for this write, that will now fail closed once RLS is on — flag that before
migrating.

## 4. Nothing else changes

- `/stripe/subscribe` (used by `index.html` for plan upgrades) is untouched.
- Vendor login no longer goes through the proxy at all — `index.html` calls
  `supabase.auth.signInWithPassword()` directly from the browser.
