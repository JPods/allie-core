# Handoff — 2026-08-31

## Where We Left Off

AI Escalation Chain built and pushed to bill_dev + main. Three tiers:
Alice local → Alice at WCHQ ($4/person/mo) → Alice+Claude at WCHQ ($9/person/mo).
Individual installations never need a Claude API key — WCHQ manages Claude centrally.
Upstream endpoints (`/wcapi/alice/ask/`, `/wcapi/alice/ask-claude/`) are standard WC3
code — any WC3 can be upstream, not just WCHQ.

GL Journal Bundle produces canonical bundle.json with company Setting UUID as source.
Journal Formatter is a standalone HTML+JS tool at `/tools/journal_formatter.html`.
`gl_journal_export` command writes to `data/bundles/journal/`. Format adapters are
in the formatter tool, not in WC3 — same pattern as Statement Sorter but outbound.

flow.py renamed to transaction_flow.py, dead 101-line utility deleted.

14 tests passing. Seed records created (Setting, Connection, Report, coaching). Docs written.

## Do This First Next Session

1. **Deploy to Andi** — upstream endpoints need deploy to go live
2. **Videos** — Setting Parade + Journal Formatter (Bill plans to record)
3. **Confidence threshold tuning** — 40% is a guess, needs real traffic
4. **Test rework** — ~210 test failures from 2026-08-25 still outstanding
5. **Wire useFieldHelp into BehaviorField** — quick win, hook exists

## Open Problems

- `seed_coaching --force` has a pre-existing bug: tries to update Document with `model_name` field that doesn't exist on Document model
- PII name detection only catches names after prefixes (Customer, Mr., Dr.) — names without prefixes pass through
- `products_itemxref.item_ida` column doesn't exist in DB — model/migration mismatch
- Aggregate tracker fires ValidationError on every transaction save — needs `_setting_update_authorized=True`
- Andi venv: Python 3.14 can't build pydantic_core — needs downgrade to 3.13

## What Was Decided (and Why)

- **No individual Claude API keys** — WCHQ manages the Claude relationship centrally. Bill: individual businesses won't maintain API keys, that burden kills adoption.
- **Per-person pricing** — $4/person/mo standard, $9/person/mo professional. Simpler and fairer than per-batch-of-5.
- **GL journals at HQ are Bundles, never GL records** — HQ is a consolidator, not a ledger. Curates for accounting program handoff.
- **Journal Formatter is external, not in WC3** — Accounting program formats change. WC3 produces bundle.json. The formatter tool owns format specs. Same pattern as Statement Sorter (inbound) reversed (outbound).
- **Company UUID as source stamp** — Every bundle.json carries `source.uuid` from `Setting(purpose='wc:company_profile')`. Accountant sees same format whether one location or fifty.

## Files Changed This Session

### AI Escalation Chain
- `apps/ai_assistant/services/escalation.py` — NEW: confidence scoring + WCHQ escalation + PII scrub
- `apps/ai_assistant/services/pii_scrub.py` — NEW: regex PII scrubber
- `apps/ai_assistant/services/rag.py` — wired escalation chain into ask()
- `apps/ai_assistant/views.py` — upstream endpoints + escalation metadata in ask response
- `apps/ai_assistant/urls.py` — upstream routes
- `apps/ai_assistant/services/ollama_client.py` — updated pricing constants
- `readmes/alice/escalation.md` — rewritten for three-tier chain
- `tests/test_escalation.py` — NEW: 14 tests

### GL Journal Bundle + Formatter
- `apps/sync/services/gl_journal_bundle.py` — NEW: canonical bundle builder + upstream send
- `tools/journal_formatter.html` — NEW: standalone HTML+JS formatter
- `apps/accounts/management/commands/gl_journal_export.py` — NEW: export command
- `webclerk3_api/urls.py` — route for journal_formatter.html
- `readmes/transactions/journal-formatter.md` — NEW: full docs

### Naming Fix
- `apps/transactions/services/transaction_flow.py` — renamed from flow.py
- `apps/transactions/services/transaction_flow.py` (old utility) — DELETED
- `apps/transactions/__init__.py` — updated import
- `apps/transactions/views/actions.py` — updated import
- `apps/transactions/views/transaction_views.py` — updated import
- `tests/test_line_copy_field_parity.py` — updated import

### Seeds
- `apps/core/management/commands/seed_wchq_settings.py` — escalation + subscription Settings
- `apps/core/management/commands/seed_connections.py` — escalation + upstream-hq Connections
- `apps/core/management/commands/seed_reports.py` — 4 alice_observation reports
- `apps/core/management/commands/seed_admin_tool_reports.py` — GL Export + Journal Formatter cards
- `apps/core/management/commands/seed_coaching.py` — GL journal coaching + formatter document
