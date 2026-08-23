---
name: WC3 tax + commission status
description: Built-in tax and commission are complete; external services + script commission deferred to Phase 5 (Action TAX-COMM-PHASE5, due 2026-09-16)
type: project
---

## Tax Calculation — COMPLETE 2026-08-05

Built-in tax is fully wired end-to-end:
- **Customer → jurisdiction → rate flow** via applyCustomerDefaults
- **Per-line tax** with priority chain: line sales_rate override > line sales amount > header rate > item exempt > customer exempt
- **Line type routing**: product/tax/shipping/discount toggle buttons in footer bar (amber/blue/red)
- **Tax% column** on sell-side lines, editable per line, bulk-editable via header click
- **Tax audit trail**: metadata.tax_decisions written on every recalculate_totals() — per-line entries with source tracking
- **Tax Jurisdiction seed**: seed_tax_jurisdictions command, 50 states + DC
- **Tax exemption**: cert fields (id, expiration, verified_by/dt) on OrgFinancialCommon, amber warning when expired
- **Tax report**: TaxReportPrintDocument.tsx (jurisdiction/period summary)

**Why:** Phase 2 Money required built-in tax before payment processing.
**How to apply:** Tax is done for built-in case. External services (Avalara/TaxJar) deferred — full build prompt at readmes/todo-tax-services.md.

## Commission — COMPLETE 2026-08-05

Backend service was already built (commission.py). Frontend wiring added:
- **Hidden by default** — C button (purple) toggles comm%, eff%, comm$ columns + footer total + CommissionPanel
- **WC2 pattern preserved**: rep rate_pct × level_factor (retail 100%, wholesale 70%, distributor 50%) × split_pct
- **Per-line comm_rate editing** with override protection (override=true prevents auto-populate from clobbering)
- **Populate trigger**: applyCustomerDefaults detects has_reps, handleSave calls populateCommission() after save
- **CommissionPanel**: rep summary cards + per-line table + selection-aware totals
- **CommissionReportPrintDocument**: by rep with accrued/paid/pending
- **Backend endpoints**: populate_commission action on Proposal, Order, Invoice ViewSets
- Works for both salesperson and rep (multiple entries in commission.reps[] array)

**Why:** Commission mirrors tax — same per-line pattern. Backend was done, frontend needed wiring.
**How to apply:** Commission is functional for revenue and margin basis. Script basis and commission payment are deferred to Phase 5.

## Deferred — Action TAX-COMM-PHASE5 (id=31162, due 2026-09-16)

- Avalara + TaxJar connection records and integration
- Tax service dispatcher + base class
- Address validation UI
- Script-based commission
- Commission payment (pay accrued, create payment records, update rep financials)

## Key Files

| File | What |
|------|------|
| `WebClerk/backend/apps/transactions/services/totals.py` | Tax engine + audit trail |
| `WebClerk/backend/apps/transactions/services/commission.py` | Commission calculate/populate/accrue/GL |
| `WebClerk/frontend/src/hooks/useLineCard.ts` | Line grid: tax%, comm%, eff%, comm$ columns |
| `WebClerk/frontend/src/apps/transactions/components/detail/LineCardRenderer.tsx` | Line type toggle, C button, footer totals |
| `WebClerk/frontend/src/apps/transactions/components/panels/CommissionPanel.tsx` | Commission detail panel |
| `WebClerk/frontend/readmes/topics/transactions/tax-calculation.md` | Tax architecture readme |
| `WebClerk/frontend/readmes/topics/transactions/commissions.md` | Commission architecture readme |
| `WebClerk/frontend/readmes/todo-tax-services.md` | External tax services build prompt |
| `WebClerk/frontend/readmes/todo-go-live.md` | Master checklist — Phase 1 done, Phase 2 tax done |
