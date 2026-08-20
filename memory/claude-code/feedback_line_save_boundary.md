---
name: Line save boundary — front end sends data, backend manages relationships
description: React sends plain IDs in JSON envelopes; server derives FK columns; never send Django FK descriptor names in payloads
type: feedback
---

Front end sends data. Backend manages data and relationships.

React sends plain numbers and JSON envelopes (e.g., `item: {item_id: 421}`). Never Django FK descriptor names (`item_fk`) or internal column names (`item_fk_id`). The server derives FK relationships from the data envelope (`item.item_id` → `item_fk_id`).

**Why:** `setattr(line_obj, 'item_fk', 421)` throws `ValueError` — Django FK descriptors reject raw integers, they want model instances. This silently killed all flight simulator line saves (2026-08-19). The exception was caught, the header save returned "success", but zero lines were persisted.

**How to apply:** When building line payloads in React, put IDs inside JSON envelopes. In save_view.py, the field copy loop skips FK descriptors and derives FK columns from envelopes. Same pattern for any FK on any subordinate model. Matches WC2 approach — Bill managed related values as plain integers.

Full doc: `readmes/80-line-save-boundary.md`
