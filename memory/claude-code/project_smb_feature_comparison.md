---
name: SMB Enterprise Feature Comparison
description: Comprehensive WC3 feature assessment against SMB enterprise standards — 116 features, 15 categories, critical review in progress
type: project
---

Full assessment at `~/Allie/knowledge/projects/smb-enterprise-feature-comparison.md`.

**Key findings from Bill's review (2026-08-25):**

1. **WC3 is more complete than initial code scan showed (59% → 75%+).** Many features that appear "not built" when scanning for dedicated models are actually built using Actions, Projects, Touches, and JSON envelopes as universal building blocks. The pattern: Action records + config JSON + status_guard replaces what other systems build as separate modules.

2. **The "Divided" concept is critical.** WC3 deliberately hands off to accounting software at the GL journal boundary. AP aging, bank reconciliation, financial statements, vendor invoicing/3-way match, labor tracking, fixed assets — these are accounting territory, not gaps. The document now tracks these as "Divided" not "Not built."

3. **Progress billing = terms creating ledger records.** Milestone billing (30/40/30) is a terms configuration, not a special billing flag. Terms generate scheduled ledger entries.

4. **CRM philosophy: disqualify, don't nurture.** 80% of shoppers never buy. Touches are for sorting (budget, need, alignment, motive), not nurturing. Train reps to disqualify 70% so they spend 80% of time with sincere buyers. `win_loss` field to be added to Proposal model. `insincere` is a key outcome value.

5. **Portal is built, not missing.** Four RBAC portal roles (customer, vendor, manufacturer, rep) with query-filtered data isolation, PortalDashboard, and route separation exist. Shopping cart component exists but needs server-side pricing endpoint (PJPV gap).

6. **Credit management is built.** `check_credit_limit` service, `credit_available = credit_limit - balance_due`, Flight Simulator training covers it.

7. **Several items flagged [VERIFY]** — need end-to-end testing before claiming Built: portal login flow, blanket PO workflow, inventory transfers (both-side decrement/increment), Action-based work order routing.

8. **Health metric IS the lead score.** No leads table needed. Health derives from Touch behavior — three unanswered follow-ups → health drops toward zero → stop investing time. Alice coaches reps on touch frequency relative to health value.

9. **Email tracking integration planned.** Connection record to Mailsuite (or similar) for open/click data. Alice's Celery beat enriches Touch records. Opened-but-no-reply ≠ never-opened — different signals, different health decay rates.

10. **WC3 owns full AR cycle.** Billing → aging → collections → payment → GL journal. Not a sale until the check clears. Accountant gets GL journals for statements and tax filings.

11. **Progress billing real-world example:** Gift industry — order placed April, 5% at placement, 60% Dec 10, 35% Jan 10 for Christmas season. Terms create the ledger records at each date.

**Still to build:**
- `win_loss` CharField on Proposal with select list (won, lost_price, lost_competitor, lost_timing, lost_no_decision, lost_scope, lost_other, insincere, canceled)
- `.prefs` fields for CRM qualifying (budget, need_date, impact, motive)
- Server-side cart pricing endpoint
- Scrap/yield production actuals tracking
- GL export in QuickBooks format (the handoff mechanism for the Divided philosophy)
- Connection record for email tracking service (Mailsuite) — Alice Celery integration
- Vendor scorecard report (derived from existing transaction data)
- Run assessment against Bill's actual commerce_expert data

**How to apply:** When assessing WC3 capabilities, always check whether Actions, Projects, Touches, config JSON, or status_guard already serve the function before concluding "not built." WC3 uses fewer models with more JSON flexibility rather than many dedicated models.
