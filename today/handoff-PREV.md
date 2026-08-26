# Handoff — 2026-08-25

## Where We Left Off

Architecture review session. Full industry comparison against Odoo/ERPNext/NetSuite — 10 gaps identified and all 10 resolved with zero new models. Contact-org role architecture decided (keep 5 FKs). Shipping, currency, approval workflows, revenue recognition all wired or designed. Press release for review comparison requested but not yet written.

## What Was Done

### Architecture Decisions (all documented in readmes/topics/architecture/)
- **contact-org-roles.md** — 5 FK columns kept, junction table rejected, auto-populate rejected
- **industry-comparison.md** — 10 gaps all resolved, zero new models, complexity comparison
- **shipping-fulfillment.md** — JSON envelope on TransactionBaseModel, WC2 LoadTag/LoadItem lineage
- **currency-exchange.md** — FX settlement wired into journalize_payment, erosion, org metrics
- **approval-workflows.md** — signoff_request status, Setting rules, Action with dt_requested/dt_response

### Code Changes (WC3 backend)
- Contact: duplicate fields removed, save_after cleaned
- Transactions: signoff_request/consigned/deferred statuses, shipping JSONField, STATUS_SIGNOFF_REQUEST
- Status guard: approval gate with condition evaluator, signoff recording, sequential activation
- Journalize: FX settlement, deferred revenue guard, pricing→sell fix, org FX metrics
- Migration: 0002_add_shipping_json.py

### Deferred
- Shipping services (add_package, pack_items, ship_package) → Action #31213, ~Nov 2026
- Press release for architecture review — requested, not yet written

## Do This First Next Session

1. **Complete SMB feature comparison** — outline at knowledge/projects/smb-enterprise-feature-comparison.md; assess each of ~100 features against WC3; add as appendix to review request
2. **Run migrations** — 0002_add_shipping_json.py not yet applied
3. **Run tests** — significant changes to status_guard, journalize, choices, contact model
4. **Check** that negative invoice quantities journalize correctly (credit memo path)

## Open Problems

- `journalize_invoice` deferred check reuses `dt_needed` — may want dedicated `dt_deferred` field
- Recommendation sections in industry-comparison.md still show rejected alternatives — could confuse readers
- Approval workflow not yet tested end-to-end (Setting → status change → Action → signoff → transition)

## Architecture Notes

- **Zero-model pattern**: signed quantities, status gates, JSON envelopes solve problems that industry solves with new models
- **shipping.costs.customer** vs **shipping.costs.actual** — distinct concerns (Alice caught this)
- **contact.prefs.tooltip_level** — user-controlled, Alice adjusts over time
- **Action priority framework**: 1=Critical, 2=High (signoffs), 3=Normal, 4=Low, 5=Someday
- **Commissions** parallel currency pattern but at line level
