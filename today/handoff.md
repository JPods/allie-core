# Handoff — 2026-08-01

## Where We Left Off
Built the line card common behavior baseline for WC3 Big5 transaction lines. Backend: `is_complete` in quantity envelope (cancels backlog), `line_card_fields` Setting purpose, bulk inventory endpoint. Frontend: LinesCard.tsx refactored with WC2 column order (Item→Qty→BLQ→x→Desc→P→Price→Disc→DiscPrice→Ext), red backlog highlighting, selection-aware footer (Lns/Items/Lbs + Amount/Backlog), left toolbar (L/S/XR/M), four show/hide panels (Inventory, Spec, XRef, Margin). Also wrote the detail.json architecture plan to replace all 9 transaction detail .tsx files with a single JSON-driven renderer.

## Do This First Next Session
1. **Seed `line_card_fields` Settings** — one per line model (order_line, invoice_line, etc.) with locked_columns, approved_optional, footer_totals. File: management command or migration in webClerk3.
2. **Build `TransactionDetail.tsx`** — the single JSON-driven detail renderer per `~/.claude/plans/detail-json-architecture.md`. Start with Order as first model, then generalize.
3. **Test the line card** — open an Order detail, verify columns render in WC2 order, backlog highlighting works, panels open/close, selection-aware footer recalculates.
4. **Extract tab components** — pull SummaryTab, PaymentsTab, ActionsTab, etc. from existing detail .tsx files into `src/apps/transactions/components/tabs/`.
5. **Post Item IDA handler** — shared action for all `post_to_*` flows (order→PO, invoice→proposal, etc.). This is the core cross-transaction workflow.

## Open Problems
- DataGrid needs `disableReorder` and `disableAddColumn` props to enforce column lockdown (Step 12 in line card plan)
- Bulk inventory endpoint (`/api/products/items/inventory/`) untested — Item model has no dedicated `lead_time` field, reading from `config.lead_time` which may not be populated
- QuickQuote needs its own plan — separate window/process, push/pull between any transaction type
- Create PO from Order needs its own plan — vendor grouping, quantity transfer

## What Was Decided (and Why)
- **Lines are a verb, not a noun** — column count and order locked to serve the task. Users get max 2 optional columns from an approved list. Without this constraint, users build spreadsheets instead of entering orders.
- **QQ is a separate window, not a panel** — QuickQuote persists across transaction windows as a clipboard. Any transaction can push/pull. Not bound to one line card.
- **"Post item ida" is the cross-transaction action** — you post item references, not prices or costs. Target transaction applies its own pricing/costing defaults. Override checkbox available but off by default.
- **Abandon detail .tsx in favor of detail.json** — 9 detail pages are 95% identical. One renderer + layout JSON per model eliminates the duplication. Same principle as db.list replacing custom list pages.
- **Shipping tab is invoice-only** — carrier shipments stored in `metadata.shipping[{carrier, shipment_id, mass, ...}]`. Purchases have receipts (separate model), not shipping entries.
- **No T (text import) panel in line card** — deferred; not part of current scope.

## Files Changed This Session
- `webClerk3/apps/transactions/models/base_line_model.py` — Added `is_complete` to quantity envelope; cancels backlog when true
- `webClerk3/apps/core/choices.py` — Added `line_card_fields` to SETTING_PURPOSE_CHOICES
- `webClerk3/apps/products/views/item_inventory_views.py` — New: bulk inventory endpoint for line card L button
- `webClerk3/apps/products/urls.py` — Wired bulk inventory endpoint
- `React2025/src/apps/transactions/components/LinesCard.tsx` — Major refactor: WC2 columns, panels, toolbar, selection-aware footer, backlog highlighting
- `React2025/src/apps/transactions/components/panels/InventoryPanel.tsx` — New: inventory peek panel (L button)
- `React2025/src/apps/transactions/components/panels/MarginPanel.tsx` — New: margin view with selection-aware totals
- `React2025/src/apps/transactions/components/panels/SpecPanel.tsx` — New: item specification panel (S button)
- `React2025/src/apps/transactions/components/panels/XRefPanel.tsx` — New: cross-reference panel (XRef button)
- `~/.claude/plans/tender-beaming-bachman.md` — Line card plan (approved, partially implemented)
- `~/.claude/plans/detail-json-architecture.md` — detail.json architecture plan (written, not yet approved)
