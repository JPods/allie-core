# Handoff — 2026-08-09

## Where We Left Off

Massive infrastructure session: built 10 connection classes with seed records + flowcharts + consolidated readme. Overhauled serial tracking — actions now embedded in `serial.config.actions[]` (self-contained, travels with the serial). Built 4 R25 serial panels (action submission, shipping selector with auto-select, line panel, print section). Added serial number rendering to pdfme print system — test PDF verified. Created bulk receive/ship services and Alice's standard serial load JSON format. Added Claude API connection (`conn-ai-claude`) so Alice can escalate beyond her local model.

## Do This First Next Session

1. **Polish 19 pdfme print reports** — cycle through each, verify field mappings against actual data, add serial integration where applicable, test PDF output. This is the primary task.
2. Read `readmes/connections/connection-classes.md` for context on integration architecture
3. Read `readmes/connections/serial-tracking.md` for the config.actions[] architecture
4. Read `readmes/connections/refs-links-and-linkage.md` for the travel-with pattern

## Files Created This Session

**Allie repo:**
- `readmes/connections/connection-classes.md` — consolidated connection class readme
- `readmes/connections/refs-links-and-linkage.md` — refs.links + LinkageEntry documentation
- `readmes/connections/serial-tracking.md` — config.actions[] + serial_trends architecture
- `readmes/flowcharts/wc3-conn-*.dot` + `.pdf` — 10 connection flowcharts
- `readmes/flowcharts/wc3-refs-linkage.dot` + `.pdf` — refs/linkage flowchart
- `readmes/flowcharts/wc3-serial-actions.dot` + `.pdf` — serial actions flowchart

**WC3 repo:**
- `apps/core/management/commands/seed_connections.py` — 20 connection records (was 9, now 20)
- `apps/products/models/serial.py` — config.actions[], updated log_action()
- `apps/products/services/serial_trends.py` — trend consolidation service
- `apps/products/services/serial_bulk.py` — bulk receive, auto-select, issue serials
- `common/schemas/serial.py` — SerialActionEntry Pydantic schema

**React2025 repo:**
- `src/apps/products/models/serial/pages/SerialActionPanel.tsx` — action submission
- `src/apps/products/models/serial/pages/SerialSelectPanel.tsx` — shipping serial selector
- `src/apps/products/models/serial/pages/SerialLinePanel.tsx` — view serials on any line
- `src/apps/transactions/components/print/SerialPrintSection.tsx` — serial print component
- `src/apps/transactions/components/print/printTypes.ts` — added PrintSerial, serials[] on PrintLineItem
- `src/services/pdfme/fieldRegistry.ts` — added serial fields
- `src/services/pdfme/generateCommercePdf.ts` — serial number rendering under line items

## Open Items

- 19 print reports need individual polish cycle (next session priority)
- Serial lifecycle methods do double-save (model save + log_action save) — refactor to single save
- `auto_select_serials()` JSON ordering needs Postgres version verification
- `seed_coaching` has stale `model_name` on Document — crashes seed_freshstart (from prior session)
- `seed_gl_accounts` has `used_for='payables'` validation error (from prior session)

## Key Decisions Made

- Serial actions embedded in config, not separate table (self-contained records)
- Serialized items auto-get Document(purpose=serial_trends) — sequence overflow for large datasets
- Alice normalizes vendor docs into standard serial load JSON — count must match len(serials)
- Exact count match for serial shipping — no partial, selected must equal line qty
- conn-ai-claude gives Alice a Claude API bridge — she frames, Claude answers, she learns
- Connection classes: 10 day-one, 4 future (WMS, catalog sync, marketing, customs)
