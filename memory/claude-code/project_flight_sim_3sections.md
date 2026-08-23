---
name: Flight simulator 3-section audit tool
description: Flight simulator left panel has 3 resizable sections (Counts/Money/GL); audit mode enters invoice number to see full picture; Report dropdown is universal action dispatcher
type: project
---

Flight simulator left panel now has 3 vertically-stacked resizable sections with drag handles:
1. **Counts** (inventory) — on_hand, on_so, on_po, on_p, available, pending deltas
2. **Money** (payments) — amount, applied, available, status, payment applications
3. **GL Journals** — DR/CR by account, batch, source document

**Why:** Every transaction touches three domains — physical (counts), financial (money), accounting (GL). Users see all three reacting in real time.

**How to apply:** Backend returns `payment_rows` and `gl_rows` alongside existing `rows` from `get_flight_transactions`. Frontend: `FlightSimConsole.tsx` renders 3 `fs-section` divs with `fs-vhandle` drag handles between them. CSS in `FlightSimConsole.css`.

**Audit mode:** Input field on sim select screen. Type invoice number (DEV-107, 107, or partial), calls `get_flight_by_invoice` manage action. Loads item inventory + payments + GL for that invoice. Same 3 sections, different entry point.

**Key files changed:**
- `WebClerk/backend/apps/products/services/inventory_flight_sim.py` — `_get_payment_rows`, `_get_gl_rows`, `get_flight_by_invoice`
- `WebClerk/frontend/src/pages/admin/FlightSimConsole.tsx` — 3 sections, audit input, PaymentRow/GlRow types
- `WebClerk/frontend/src/pages/admin/FlightSimConsole.css` — section styles, payment table, GL table, audit bar
- `WebClerk/backend/apps/core/views/manage_view.py` — registered `get_flight_by_invoice`, `journalize_invoice_and_payments`

**Open:** Rename sections Inventory→Counts, Payments→Money per Bill's framework.
