---
name: StatementHarvester — JSON-based statement processing
description: Bank statements → JSON files → classify → promote business lines to Payment records; personal data never enters psql; UUID per line for idempotent promotion
type: project
---

StatementHarvester reworked 2026-08-01 from psql-based to JSON-based:

- **JSON files on disk** at `~/Allie/statements/`, not database records
- **UUID per line** at harvest time — idempotent promotion (Payment.refs.source.statement_uuid)
- **Dedup** by raw_text hash on re-harvest — same CSV twice = 0 new lines
- **classification**: unknown/business/personal — user classifies, Alice suggests
- **ledger**: post/skip/review — controls whether promotion creates GL entries
- **Promote**: only business+post lines become psql Payment records
- **Export**: personal lines download as CSV, never enter company database
- **6 bank formats**: WF CC, WF checking, USAA, Wise, Domain Registrar, Generic

**Why JSON not psql:** Privacy (personal data stays on disk), sovereignty (user owns files), portability (JSON travels with user), idempotency (UUID prevents duplicates).

**Key files:**
- tools/statement_harvester.py — harvester + JSON I/O + promote
- apps/transactions/views/statement_views.py — 6 API endpoints
- readmes/statement-harvester.md — full architecture
- ~/Allie/statements/ — JSON file output directory

**How to apply:** The StatementLine psql model can be dropped in a future cleanup. The db.list for statements needs to read from JSON API endpoints instead of wcapi/get. The HarvestBar on the Statements page calls the harvest API.
