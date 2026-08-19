# Handoff — 2026-08-18

## Where We Left Off

Flight simulator at `/flight-simulator` is functional: select list with 8 simulation types, auto-loads training item qqBB200 (id=244, on_hand=100), creates qq-prefixed proposals with Riverside Sports customer, adds line items, saves with pending record creation. The save chain works end-to-end: line saves via `/wcapi/save/`, pending record creates with `on_p: 15`, and pending was manually applied to `item.quantity`. The **ledger display** on the left panel needs rework to show the row-by-row story (item state -> pending -> updated item state -> next transaction -> pending -> updated item state) through the full lifecycle: proposal -> order -> invoice -> purchase -> receive.

## Do This First Next Session

1. **Rework `get_flight_ledger`** (`apps/products/services/inventory_flight_sim.py`) — The left panel shows **impact at every transaction**, not a summary. Row pattern: item state (starting quantities) -> pending (what this transaction changes: +15 on_p) -> item state (quantities after pending applied) -> next transaction's pending -> item state after that. Each row shows type, ida, and all quantity columns. The user watches the numbers change at every step. This is the core teaching tool.
2. **Fix pending auto-processing** — `apply_pending_for_item` (inventory_pending.py) returns 0 applied because it doesn't recognize the flat-dict `changes` format from `LineItemService`. The processor expects `[{field, old, new}]` list but gets `{on_p: 15.0, ...}` dict. Celery dispatches but nothing processes.
3. **Extend flight sim through order/invoice/purchase** — After proposal works, the user converts to order (on_p down, on_so up), then invoice (on_so down, on_hand down, GL entries), then purchase (on_po up), then receive (on_po down, on_hand up). Each step adds rows to the ledger.
4. **Clean up test data** — Delete duplicate item 421 (qqbb200-DELETED), clean up qq-fs-proposal-* records from testing. Reset qqBB200 quantity to on_hand=100 all others zero.
5. **Fix AI Assistant overlay** — The floating AI Assistant button intercepts clicks on the item search "Add" button in the flight sim. Z-index or positioning conflict.

## Open Problems

- Pending records don't auto-process — Celery task dispatches but `apply_pending_for_item` doesn't recognize the flat-dict changes format
- `/wcapi/transaction/save/` returns intermittent 404 from browser (works via curl) — bypassed by routing `saveTransactionWithLines` through `/wcapi/save/` instead
- Item search shows old ida `BB200` instead of `qqBB200` — the `item_code` in search results uses the item's ida but the search endpoint may be returning a cached or denormalized value
- `dev/config` endpoint called excessively (dozens of times per page load) — not blocking but noisy

## What Was Decided (and Why)

- **`saveRecord` always uses `record` wrapper, never `data`** — The `data` wrapper caused FK assignment errors (`Proposal.customer must be OrgBase instance`). The save view handles `record` correctly at line 352.
- **FK normalization in save_view.py** — When a field is a ForeignKey and value is an integer, set `field_id` instead of `field`. Prevents `Cannot assign "5494": must be OrgBase instance` errors.
- **Negative line IDs treated as new lines** — React generates negative timestamps as temporary IDs for new lines. Save view now checks `id < 0` as new, not just `None` or `temp-*` strings.
- **`saveTransactionWithLines` routes to `/wcapi/save/`** — The dedicated `/wcapi/transaction/save/` endpoint has intermittent 404 issues from the browser. `/wcapi/save/` handles lines for header models (proposal/order/invoice/purchase/work_order).
- **`record` key deleted after merge in save_view** — Without this, the entire record dict (including lines) gets stored in `prefs.userdefined` as an unknown field.
- **Form layout sections added to `wc:detail_layout` Settings** — All 5 transaction models (proposal/order/invoice/purchase/work_order) now have header (3-column) + line_card + tabs sections in both App and Admin views.
- **All BB items renamed to qqBB** — 97 items prefixed with `qq` so flight sim training data is clearly separated from real data.

## Files Changed This Session

- `React2025/src/pages/admin/FlightSimConsole.tsx` — Flight sim page: select list, item summary, transaction array (DbColumns), form panel
- `React2025/src/pages/admin/FlightSimConsole.css` — Flight sim styles using --db-* CSS variables
- `React2025/src/components/cards/FlightSimCard.tsx` — dd-card launcher for flight sim (registered as `flight_sim`)
- `React2025/src/components/cards/FlightSimCard.css` — Card styles
- `React2025/src/components/cards/index.ts` — Added FlightSimCard import
- `React2025/src/components/auth/SignInForm.tsx` — Fixed Toster crash: extract error message string from AxiosError
- `React2025/src/components/common/Toster.tsx` — (unchanged but was the crash source)
- `React2025/src/api/wcapi.ts` — `saveRecord` always uses `record` wrapper; `saveTransactionWithLines` routes to `/wcapi/save/`; added fallback
- `React2025/src/apps/transactions/components/TransactionDetail.tsx` — Added `onAfterSave` callback, `dirtyLines` check, better error logging
- `React2025/src/apps/orgs/components/OrgDetail.json.tsx` — Better save error reporting
- `React2025/src/routes/Router.tsx` — Added `/flight-simulator` route
- `React2025/src/routes/Routes.ts` — Added `flightSimulator` path
- `React2025/src/routes/protectedRoutesConfig.tsx` — Added flight-simulator route config
- `React2025/src/layout/AppSidebar.tsx` — Added `flight-simulator` to icon/route/display maps
- `webClerk3/apps/core/views/save_view.py` — FK normalization, negative line ID handling, `record` key cleanup, skip list update
- `webClerk3/apps/core/views/manage_view.py` — Added `get_item_by_ida` action
- `webClerk3/apps/products/services/inventory_flight_sim.py` — Added `get_item_by_ida`; fixed pending changes parsing (dict vs list)
- `webClerk3/apps/transactions/services/line_item_service.py` — Added `item_fk_id` to item_id lookup chain
- `webClerk3/apps/transactions/signals.py` — `_resolve_item_id` checks `item_fk_id` first
