---
name: backfill_totals management command
description: Recomputes totals JSON for transaction records; use after any totals engine change
type: reference
---

`python manage.py backfill_totals` — recalculates totals for transactions with empty/missing envelopes.

Flags:
- `--dry-run` — show what would change without saving
- `--model invoice` — limit to one model (invoice, order, proposal, purchase, workorder)
- `--all` — recompute ALL records, not just empty ones

Created 2026-08-22. Run after any change to the totals engine or after discovering records with stale/missing totals JSON.
