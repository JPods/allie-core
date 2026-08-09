# Handoff — 2026-08-08 (Session 3)

## Where We Left Off
WC2 tally salvage + transaction architecture session. Major WC2 code review (15+ methods). Built: Report model script fields (migration 0034), address verification supervisor (3-tier with geocoding), ZIP-driven tax calc (tax_lookup.py + customer_defaults wiring + tax_service Connection staged), BOM 3-depth rollup, pricing chain overhaul (catalogs, per-level qty breaks, margin warning not enforcement), early payment discount (creates real Payment record), write-off difference (same pattern). Two readmes + two Alice Dashboard Document records (pricing-architecture, payment-application). Returns decided = negative invoices. Transaction gap analysis: 8 items remaining.

## Do This First Next Session
1. **Seed tax rate Settings** — create `us_state_tax_rates` and `zip_to_state` Setting records with real data for all 50 states + DC. Either a seed script or WC_HQ sync.
2. **Test address verification** — call `verify_address()` with a real address, verify lat/lng comes back from Nominatim, verify carrier fallback works.
3. **Wire Terms → finance** — when Terms model is applied to a transaction, populate `finance.discount_days` and `finance.discount_rate` from the Term record so early payment discount calc can fire.
4. **20/200-60-20/100 Report records** — create the margin velocity reports for Alice, Product, and Support dashboards.
5. **Credit check on save** — wire `credit_utilization()` to fire during transaction save when customer is assigned.

## Open Problems
- Alice's vector store is stale — she doesn't know about PaymentApplication, BOM, or inventory models that already exist. Needs refresh.
- Denormalize stack `push_to_stack()` not atomic under high concurrency (from session 2, still open).
- Import pipeline backend endpoints still TODO (from session 1).
- FileUploadPanel `/wcapi/upload/` endpoint not built yet (from session 1).
- `finance.write_off_gl_account` needs a Setting default so users don't set it per invoice.
- Catalog pricing tests needed for `_resolve_catalog_price()` and universal % logic.
- Early payment discount creates a discount Payment then calls `_apply_one` recursively — needs testing to confirm the recursive application doesn't trigger another discount check.

## What Was Decided (and Why)
- **TallyMaster → Report records with 3 script fields** — script_before (setup), script_during (business logic), script_after (results/notifications). Built-in reports lock before/after, users customize during.
- **Returns = negative invoices** — credit_note invoice type, negative quantities. No separate RMA model. Same conversion chain, same totals, same GL.
- **Every dollar = a Payment record** — cash, discounts, write-offs all create Payment records with their own GL posting. No silent total adjustments.
- **Margin floor = WARNING only** — system never overrides user's price. `below_margin_floor` flag for UI display.
- **ZIP drives tax** — ZIP → state → rate. Setting from WC_HQ carries rates. Local TaxJurisdiction overrides.
- **BOM depth is user's choice** — 1 (kit), 2 (one level of intermediates), 0 (all levels to leaf). Inventory decision, not math decision.
- **Lat/lng on every address** — required for desktop-hosted local commerce proximity search. Nominatim provides free geocoding without carrier accounts.
- **Qty breaks carry per-level columns** — `{"min_qty": 25, "retail": 11.00, "wholesale_pct": 33.3}`. Dollar wins, percentage from base. Better than WC2's PriceMatrix table.
- **Catalog pricing is Step 0** — highest priority in resolution chain. Item-specific catalog price skips entire standard chain. Universal % applies after standard chain resolves.
- **Commission deferred** — future/maybe list. Too messy for now.
- **ConsolidateRecs eliminated** — uuid + bundles replace merge operations. No more walking every table to swap IDs.
- **GL: gross debits/credits** — stored separately, net computed for display only. Standard accounting practice.
- **AR aging: fixed 30/60/90 + future-due** — same boundaries WC2 used for 20+ years. No configuration needed.
