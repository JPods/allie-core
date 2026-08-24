# Handoff — 2026-08-23

## What Was Done

### Backend Bug Fixes
1. **Migration cleanup** — Deleted 861 duplicate " 2" files (macOS sync artifacts). Created migration 0037 for `payment.parent_id`/`parent_model` + PendingPaymentApplication removal. Fake-applied (columns already existed via SQL). Graph clean.

2. **Invoice line extended price fix** — `BaseLineCore.save()` in `WebClerk/backend/apps/transactions/models/base_line_model.py` now auto-adds `price` and `cost` to `update_fields` when `quantity` is present. Root cause: `save(update_fields=['quantity'])` called `_calculate_extended_price()` which recalculated in memory, but the recalculated `price.extended` was never written to DB because `price` wasn't in `update_fields`.

3. **Touch Setting form layout** — `wc-model-touch` Setting had `{list: "default", detail: "default"}` at `layout.form.default` instead of `{sections: [...]}`. Fixed with proper 3-section layout (header/tabs/json_tree). `useDetailLayout` now resolves correctly.

4. **Serializer fixes (schema 500 blocker)**:
   - `ConnectionSerializer`: `comment` → `comments` (field renamed, not dropped)
   - `PaymentSerializer`: Stripped dead `payment_method` FK code. Field is now `method` (CharField). Removed `payment_method_id` explicit field, FK lookups in create/update.
   - `PaymentViewSet.filterset_fields`: `payment_method` → `method`

5. **model_name/list route fix** — DataBrowser was 404ing on `/wcapi/model_name/list/` because the backend only served it at `/wcapi/_model_list/`. Added legacy routes for both `model_name/list/` and `model_name/detail/`. This was blocking ALL DataBrowser model loading.

### Frontend Changes
6. **TransactionItemSearch column reorder** — New order: Add | Qty | Item | Description | On Hand | Unit Price | % | Disc Price | Total

7. **TransactionItemSearch → DbColumns** — Refactored from raw HTML table to DbColumns component. Users can now configure/reorder columns via the gear icon. Storage key: `panel:item_search`.

### Workspace Confirmation
- **WebClerk/ is the active codebase** (scar #70). `webClerk3/` and `React2025/` are retired. Running servers confirmed at `WebClerk/backend/` and `WebClerk/frontend/`.

## What Was NOT Done (interrupted by restart)

### Fake Customer Seeding
Script ready — 10 fake customers with `.fake` email domains, wholesale price_level. Run:
```python
# In WebClerk/backend — the script from the session will work
# Names: Acme Sporting Goods, Bravo Construction, Cascade Outdoor, Delta Athletics,
#        Echo Hardware, Foxtrot Landscaping, Golf Academy West, Hotel Supply Group,
#        India Tech Services, Juliet Garden Center
```

### Flight Simulator Live Testing
- Item search column changes need browser verification
- DbColumns gear icon needs testing
- Full inventory flow (Proposal → Order → Invoice → Payment) not tested this session

### Statement Sorter Connection + Bundle Review
TODO sent to Alice (message #1084). Review existing Connection record and Bundle config for bank/credit card statement import flow. Real-time gateway payments skip Bundles; batch reconciliation uses Bundles.

## Key Files Changed

| File | What |
|------|------|
| `WebClerk/backend/apps/transactions/models/base_line_model.py` | update_fields auto-expansion for price/cost |
| `WebClerk/backend/apps/sync/serializers/connection.py` | comment → comments |
| `WebClerk/backend/apps/transactions/serializers/payment_serializers.py` | Removed payment_method FK code |
| `WebClerk/backend/apps/transactions/views/transaction_views.py` | filterset_fields payment_method → method |
| `WebClerk/backend/apps/core/urls.py` | Added model_name/list/ and model_name/detail/ routes |
| `WebClerk/frontend/src/apps/transactions/components/TransactionItemSearch.tsx` | DbColumns refactor + column reorder |

## Architecture Notes for Next Session
- Payment gateways managed via sync app Connection records
- Real-time gateway payments do NOT need Bundles (Payment record is audit trail)
- Batch reconciliation (bank statements, settlement files) DO need Bundles
- `PaymentMethod` table still exists as lookup/registry but is not FK'd from Payment
- `method` CharField is freehand or select list: "visa_3425", "check-WellsFargo", "cash"
