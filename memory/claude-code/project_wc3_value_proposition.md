---
name: WebClerk3 value proposition and feature priorities
description: Core differentiators, feature roadmap, what to polish first vs add; local+cloud sovereignty, WC_HQ data services, cross-company sync
type: project
---

**Core differentiator:** Local + cloud dual storage. Laptop IS the system of record. Cloud is backup + collaboration. When internet/power/cloud fails, business keeps running. No competitor does this.

**Why:** Individual sovereignty applied to commerce data. The merchant owns their data, not the platform.

**Revenue engine:** WC_HQ data services — clean vendor catalogs into JSON, push via sync. Tax/currency/shipping API services. Selling small businesses the one thing they can't buy: time.

**How to apply — Polish first:**
1. Sync reliability (Connection + Bundle battle-testing, conflict resolution)
2. Core transaction loop (Order→Invoice→Payment→GL — must be flawless)
3. DataBrowser as admin tool (just built, needs stabilization)

**Add next:**
- Automatic bank reconciliation (Alice matches CSV imports to payments)
- One-click vendor onboarding (email invite → sync connection → kanban visibility)
- Alice as bookkeeper agent (overdue flagging, reorder suggestions, duplicate detection)
- Customer self-service via CarryOn identity (not another account — portable identity)
- Vendor kanban visibility as published view (customer controls projection, not vendor reaching in)
- Cross-company order→PO→SO linking via sync bundles (EDI for small business at zero setup cost)

**Key identifiers:** ida = human readable, id = local FK, uuid = cross-database join key. Triple enables cross-company linking.

**Free model:** Platform is free (open source, runs on laptop). Data services are paid (catalog cleaning, tax/shipping APIs, search indexing). Value proven before money changes hands. Zero adoption barrier.

**Proximity search — the Amazon killer:** Every merchant hosts their own inventory. They publish discoverable items via sync to WCHQ. WCHQ indexes and serves a proximity query API (lat/lon + radius + terms → results ranked by distance). Local inventory beats distant warehouse because physics. This is DynamicCatalogs + WebClerk + JPods converging.

**Vendor blessed list:** Vendors see only a curated projection of fields and products they supply. Customer controls what's visible. Sovereignty principle applied to data sharing — enumerated, revocable permissions via OrgItem + Settings.

**JPods cargo integration:** Search finds product (WCHQ) → buyer orders (wc3) → JPods delivers Middle Mile → local circulator Last Mile → merchant paid (Payment) → Alice reconciles (GL). Complete bottom-up loop.
