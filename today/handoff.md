# Handoff — 2026-08-05 (evening session)

## Where We Left Off
Built and wired tax calculation (customer jurisdiction → header rate → per-line application with exemption and item taxability), universal JSON-driven print system, DataBrowser field grouping, and `line_type` field on all transaction lines (product/tax/shipping/discount). The `line_type` routes line amounts to the correct total bucket in `totals.py`. Migration applied. Next step is the LineCardRenderer UI for toggling line_type on a selected line — colored underline, not a column.

## Do This First Next Session
1. **LineCardRenderer line_type toggle** — add toggle buttons (Shipping, Tax, Discount) below the selected line in the line card. Click to set `line_type`. Colored underline: amber=tax, blue=shipping, red=discount, none=product. File: `React2025/src/apps/transactions/components/detail/LineCardRenderer.tsx`.
2. **Test universal print** — Action #31161 (ACT-PRINT-TEST) due today. Open `/db/order`, select DEV-34, click Print. Verify popup renders. Test Edit Layout button. Test Cmd+P. Test invoice/proposal/purchase.
3. **Seed tax jurisdictions** — need test data. At minimum: a few US states with `tax_rate_sales` populated. Run `seed_field_access --force` on Andi after deploy.
4. **Deploy to Andi** — build React2025, rsync dist, reload nginx. Run `seed_print_layouts` and `seed_field_access --force` on Andi.
5. **Test tax flow end-to-end** — create order, set customer with jurisdiction, add lines, verify tax calculates. Change customer to exempt, verify tax zeroes. Override line tax rate manually.

## Open Problems
- **No VAT mechanism.** US sales tax only. Documented in todo-go-live.md.
- **Tax on shipping** wired in totals.py but `tax.shipping` rate not populated by `applyCustomerDefaults` yet — the jurisdiction's `tax_rate_on_shipping` needs to flow into the transaction's `tax` envelope. Currently only `finance.sales_tax_rate` flows.
- **LineCardRenderer** doesn't know about `line_type` yet — the toggle UI is the next build item.
- **No tax jurisdiction seed data** — TaxJurisdiction table is empty. Need US state rates.
- **Design tokens vs DataBrowser CSS drift** — design-tokens.json uses deeper/bluer palette (#0a0e1a) vs DataBrowser CSS (#1e1e1e). Not broken, but inconsistent.

## What Was Decided (and Why)
- **`line_type` on lines, not header fields** — tax/shipping/discount as line items with a type flag, not hidden header amounts. Reason: visible, editable, auditable, prints on documents. Each line carries its own JSON envelopes (Pydantic details for shipping labels, tax jurisdiction, etc.). Bill: "that way there is a line record with pydantic details."
- **Line_type UI = toggle + colored underline, not a column** — line card space is limited. Toggle below selected line, underline as indicator. Bill confirmed not too subtle.
- **One toolbar everywhere** — DetailToolbar is the single toolbar. TransactionToolbar archived. When standalone (`/order/34`), DetailToolbar is inserted. When inline in DataBrowser, hidden (DB has its own). Bill: "one toolbar is many times easier to maintain than 2."
- **Alice IS the report designer** — users upload PDF/image of desired report, Alice drafts JSON layout, saves as Setting record. No drawing program needed. The DataBrowser Setting editor is the layout editor.
- **Field groups ordered by user priority** — Communication 2nd (after Identity), not buried at position 7. FK IDs moved to System. Group order is as important as group membership.
- **Tax flows from customer** — customer set → check exempt code → if not exempt, fetch jurisdiction → copy rate to `finance.sales_tax_rate`. Backend applies per line, checking item taxability. User can override at line level. Matches WC2 `calcOrder`/`calcInvoice` pattern.

## Files Changed This Session

**React2025:**
- `src/components/common/FieldGroupSection.tsx` — new: collapsible detail field group component
- `src/components/print/printLayoutTypes.ts` — new: TypeScript interfaces for print layout JSON schema
- `src/components/print/UniversalPrint.ts` — new: JSON-driven HTML print renderer
- `src/hooks/usePrintLayout.ts` — new: fetch print_layout Setting, fallback to default
- `src/hooks/useDataBrowser.ts` — field groups state, collapse persistence, toggle
- `src/pages/admin/DataBrowser.tsx` — grouped detail fields, Detail Order button, Cmd+P shortcut, universal print
- `src/pages/admin/DataBrowser.css` — removed duplicate .db-list-pane definition
- `src/components/common/ReportsDialog.tsx` — wired universal print, Edit Layout button, fixed dead links
- `src/components/common/DetailToolbar.tsx` — added balance display (red when > 0)
- `src/components/common/FieldOrderDialog.tsx` — added 'flat' to protected layouts
- `src/routes/Router.tsx` — registered print routes
- `src/apps/transactions/components/TransactionDetail.tsx` — DetailToolbar replaces TransactionToolbar, inline prop hides toolbar
- `src/apps/transactions/utils/applyCustomerDefaults.ts` — tax jurisdiction + exemption flow from customer
- `readmes/sow-detail-field-grouping.md` — marked completed with implementation notes
- `readmes/databrowser-discipline.md` — updated BrowserDetail section
- `readmes/00-index.md` — added DataBrowser section
- `readmes/training-video-scripts.md` — new: 5 training video scripts
- `readmes/todo-go-live.md` — updated printing section, added VAT note, updated tax section

**webClerk3:**
- `apps/core/choices.py` — added print_layout to SETTING_PURPOSE_CHOICES
- `apps/core/management/commands/seed_field_access.py` — field groups, line_type select, FK ID reclassification
- `apps/core/management/commands/seed_databrowser.py` — flat view seeded
- `apps/core/management/commands/seed_print_layouts.py` — new: seeds 7 transaction print layouts
- `apps/transactions/models/base_line_model.py` — added line_type field (product/tax/shipping/discount)
- `apps/transactions/services/totals.py` — per-line tax calc, line_type routing, tax on shipping
- `apps/transactions/migrations/0027_add_line_type.py` — migration for line_type on 7 line models

**Allie:**
- `readmes/retrospections/2026-08-05.md` — appended Session 2 retro
