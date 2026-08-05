---
name: Alice data conversion pipeline
description: apps/conversion/ Django app with separate alice_conversion DB; Claude Haiku maps columns; multi-pass oddity resolution; bundle output to /sync/receive/
type: project
---

Alice's data conversion framework built 2026-08-04. Converts messy supplier files into clean WC3 bundles.

**Architecture:**
- Django app: `apps/conversion/` in WC3
- Database: `alice_conversion` (separate PostgreSQL DB, same server as commerce_expert)
- Router: `apps/conversion/db_router.py` — conversion models never touch commerce_expert
- LLM: Claude Haiku 4.5 via Anthropic SDK for column mapping
- API key: `~/Allie/config/allie_api_keys.json` → `keys.anthropic`

**Models (6 tables in alice_conversion):**
- ConversionProject — one per conversion effort
- SourceFile — each uploaded file with headers, samples, hash
- ColumnMap — Claude's proposed column→WC3 field mappings with confidence scores
- Oddity — every data quality problem found (severity, category, resolution)
- StagingRow — converted rows in WC3 schema format awaiting bundle assembly
- PassLog — record of each pass with Claude API usage tracking

**CLI:** `python manage.py convert_data {start|review|confirm|run|oddities|bundle|list}`

**Pipeline:** File → Pass 1 (Claude maps columns) → Review → Confirm → Pass 2+ (convert rows, find oddities) → Resolve → Bundle JSON → /sync/receive/

**Rule:** All bulk data enters WC3 only through bundles. No CSV/TSV import commands inside WC3. Individual records through wcapi CRUD. Bulk always through /sync/receive/.

**What was removed:** import_items_tsv.py, import_bom_tsv.py, import_actions_from_csv.py, ImportExportModelAdmin mixins — archived at `archive/import_removed_2026-08-04/`

**WC2 test data:** `/Volumes/TempFiles/zzzDataDump/` — 120+ JSON files. Item.json has 3,315 records, 142 fields. Known oddities: BOM-encoded UTF-8, "0000-00-00" null dates, Unix timestamps as ints, 4D relational objects (Link_63, ParentVendor), non-UOM values, bare GL numbers.

**Actions:** DEV-31139 (review framework, due 2026-08-25), DEV-31140 (run WC2 conversion, due 2026-08-25)

**Readmes:** `readmes/topics/architecture/data-conversion-framework.md`, `readmes/topics/architecture/bundle-import.md`
