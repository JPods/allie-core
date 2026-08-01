# Handoff — 2026-08-01 (Session 3)

## Where We Left Off
TransactionDetail.tsx is rendering at `/td/order/34` — JSON-driven, three-column header (Customer | Ship To | Order), line card with L/S/XR/M toolbar, 8 tabs. Line card has WC2 column order with compact labels (c, remain, pl, %, disc price), alternating row shading, selection-aware footer, red backlog highlighting. ShoppingCart.tsx built at `/cart`. `dt_needed` field added to TransactionBaseModel and migrated. Bill is napping — everything pushed to persistence.

## Do This First Next Session
1. **Fix `useDetailLayout` query** — Setting #480 isn't loading; falls back to default layout. Debug `getRecords('setting', {parent_model: 'order', purpose: 'detail_layout'})`. Check console for `[useDetailLayout]` logs.
2. **Fix transaction save 500** — `Pending` model missing `data` field in `line_item_service.py:1073`. Blocks saving orders from UI.
3. **Format epoch dates** — `dt_created` shows as raw epoch ms. Need date formatter in HeaderRenderer.
4. **Customer FK display** — shows `5498` instead of company name. Resolve FK to display name.
5. **Wire ShoppingCart** — `/cart` renders empty state. Needs cart context/state management.

## Open Problems
- Transaction save 500 — `Pending.objects.create(data=...)` fails. Pre-existing bug.
- Layout cache doesn't clear on Setting update — needs hard refresh.
- Duplicate BB401_clone line on order 34 — data issue from SQL seeding.
- `/td/` route in public routes for debugging — move inside PrivateRoute when stable.

## What Was Decided (and Why)
- **`lineKey`: id → line_number → idx** — line_number can duplicate; id is unique.
- **Compact line labels** — c, remain, pl, %, disc price. Bill requested violation of field-name-as-label rule for line cards.
- **`_expand` removed** — notes in LineDetailsModal, not inline. `hideToolbar` on line card DataGrid.
- **Three-column header** — `layout: 'three-column'` with Customer | Ship To | Order. Dot-notation for JSON sub-fields.
- **`dt_needed` BigIntegerField** — UTC epoch ms (Axiom 14). On TransactionBaseModel, all types.
- **QQ separate window** — not a panel. Own plan needed.
- **Post item ida** — cross-transaction action posts references, not prices. Target applies own defaults.
- **Alice STEM shopping** — dedicated session. DFRobot, Ozobot sourcing.

## Files Changed This Session
- `webClerk3/apps/transactions/models/base_line_model.py` — `is_complete` in quantity envelope
- `webClerk3/apps/transactions/models/base_transaction_model.py` — `dt_needed` field
- `webClerk3/apps/transactions/migrations/0024_add_dt_needed.py` — Migration
- `webClerk3/apps/core/choices.py` — `line_card_fields` Setting purpose
- `webClerk3/apps/products/views/item_inventory_views.py` — Bulk inventory endpoint
- `webClerk3/apps/products/urls.py` — Wired endpoint
- `webClerk3/apps/core/management/commands/seed_detail_layouts.py` — Seed command
- `React2025/src/apps/transactions/components/LinesCard.tsx` — Full refactor
- `React2025/src/apps/transactions/components/TransactionDetail.tsx` — JSON-driven renderer
- `React2025/src/apps/transactions/components/ShoppingCart.tsx` — Customer cart
- `React2025/src/apps/transactions/components/panels/*.tsx` — 4 panels
- `React2025/src/hooks/useDetailLayout.ts` — Layout Setting hook
- `React2025/src/apps/transactions/utils/lineHelpers.ts` — lineKey fix
- `React2025/src/components/common/DataGrid.tsx` — Alternating row shading
- `React2025/src/routes/Router.tsx` — `/td/` and `/cart` routes
