---
name: Backend is source of truth, not React
description: React is UI layer only — all authoritative calculations (prices, totals, inventory, tax, GL) happen server-side; React displays and submits, server validates and decides
type: feedback
---

The backend (Django/wc3) is the source of truth for all business data. React25 can display, pre-calculate for UX convenience, and submit — but the server validates and recalculates on save. If React and server disagree, server wins.

**The rule: all client-side calculations are visual; server-side calculations are permanent.** The client shows the user what will happen. The server decides what did happen.

**Why:** Bill: "I like that the front end can do things, but I think the backend should be the source of truth." This prevents client-side tampering, ensures consistency across all access paths (React, API, sync, admin), and keeps business rules in one place. Client-side JS is always inspectable — security and authority live on the server where the user can't touch them.

**How to apply:** Never trust client-submitted prices, totals, tax, or inventory numbers without server-side verification. The existing `verify_line_calculations()` / `verify_header_calculations()` pattern in transaction_save.py is the model — compare, warn on drift, use server values. Price resolution, inventory availability, GL posting — all run server-side. React calls services to populate UI but doesn't set authoritative values.
