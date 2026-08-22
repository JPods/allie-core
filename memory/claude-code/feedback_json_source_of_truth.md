---
name: JSON envelope is the only source of truth
description: Every model's JSON fields are authoritative; scalars are indexes; display is projection; temporary collections derive from server JSON — never compute independently
type: feedback
---

JSON envelope is the ONLY source of truth — for every model, every temporary collection, every display value.

**Why:** Two totals engines produced different JSON for the same transaction. Denormalized scalars drifted from JSON. UI temporary arrays computed their own totals that disagreed with the server. Users made decisions on bad numbers. Scar #62 and #63.

**How to apply:**
- Denormalized scalar fields (total, balance, on_hand, available) are indexes for query performance. They are NEVER authoritative. If scalar and JSON disagree, JSON wins.
- Display values are projections of JSON. Never read a display value back as an input.
- Temporary UI collections (line item arrays, payment lists, selected record sets) must derive totals from server JSON responses, not compute independently in the browser.
- One compute engine per domain. If you find two functions computing the same value, consolidate immediately.
- Applies to ALL models: Item (price/cost/quantity), Serial (config), BOM (cost_snapshot), Contact (refs), Setting (config), Report (config), every transaction (totals/sell/cost).
- Compute from data → display from computation → never the reverse.
- **All calculations are json.path.value based. Fundamental and unbreakable.** Every computed value resolves through an explicit JSON path (totals.balance, price.extended, quantity.on_hand). Never from a scalar, never from a display element, never from a temporary sum. Users will work with JSON arrays extensively — the system teaches discipline or it teaches sloppiness. There is no neutral position. Scar #64.
