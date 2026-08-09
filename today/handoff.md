# Handoff — 2026-08-08 (Session 2)

## Where We Left Off
WC2 salvage session. Analyzed 182 WC_ methods, Bill assessed all 9 extractable patterns. Built 8 deliverables: Alice's denormalize stack (permanent Pending, changes[] accumulates {model,id}, pops 25/cycle), RESTful range queries (/wcapi/order/dt_created/from/to/), three-tier search (personal prefs.search[] → shared Report → delivered Report), PostgreSQL FTS with ranking + trigram fuzzy, DocSection component with 8 HELP-* Document records in Alice Dashboard, WCHQ ida prefix convention (wchq-* on 80+ Settings, seeds updated), leftshoe fire-and-forget protocol.

## Do This First Next Session
1. **Browser-test Alice Dashboard** — expand each DocSection, verify all 8 HELP-* documents load correctly
2. **Test RESTful range query** — `curl /wcapi/order/dt_created/2026-01-01/2026-08-01/` and verify results
3. **Test save-search endpoint** — POST to `/wcapi/save-search/` with scope=personal and scope=shared
4. **Verify denormalize stack** — save a contact, check that Pending record `alice.denormalize.stack` has the entry in changes[]
5. **Remove legacy hardcoded help** — the inline "How to Extend Alice" and "MCP Server Guide" JSX blocks can be removed now that HELP-EXTEND and HELP-MCP Document records exist

## Open Problems
- Denormalize stack `push_to_stack()` is not atomic under high concurrency — `get_or_create` + append could lose an append if two processes read same stack simultaneously. Low risk at current scale.
- Import pipeline backend still TODO (Alice analysis endpoint, Athena review endpoint, bundle submission)
- FileUploadPanel creates Document records but `/wcapi/upload/` endpoint not built yet
- Legacy Setting `purpose='search'` records still exist — need migration script to promote to Report records
- Alice Dashboard redesign needed — DocSection reference area is bolted on below tabs, needs proper integration

## What Was Decided (and Why)
- **Searches belong in Report, not Setting** — a saved search IS a report definition. Same spec shape at all three tiers. Promotion is a copy not a transform. TFTS: build it wrong first, the act of building reveals the right abstraction.
- **WCHQ ida prefix convention** — `wchq-*` on `ida` field. No new boolean. Convention on existing indexed field carries meaning (what + where) not just state. Zero migrations.
- **One permanent Pending for denormalize** — no flood of Pending rows. Stack in changes[], pop batches, never close.
- **Fire and forget for Allie/Alice** — don't block on their response. Point and move. Inclusion not synchronization.
- **FTS at query time, no new columns** — PostgreSQL SearchVector/SearchQuery runs on existing text fields. refs.keywords stays for JSON/tag coverage.
- **DocSection lazy-loads from Document records** — help content in DB, not JSX. Editable via databrowser without deploys.
