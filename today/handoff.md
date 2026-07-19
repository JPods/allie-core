# Handoff — 2026-07-18 (late evening)

## Where We Left Off

Built the JPods specs + quality + BOM infrastructure in one session. Key deliverables:

**12 unified specs** at `~/Allie/specs/` — 304 requirements, Yellow/Orange/Red flags, uniform format. 13 RED flags that need resolution before deployment (temp range conflict, HSS mismatch, battery fire protection, V2V collision avoidance, SIL classification, fail-safe decision).

**Fusion360 BOM extraction** working for both .f3d and .f3z formats. 170Meter_Full (22 components, 76 instances) and Bogie v22 (17 parts, 42 per bogie) extracted and saved as JSON.

**SEGA-style spare parts demo** at `~/Allie/Fusion/bogie_spare_parts.html` — clickable exploded view with 17 numbered callouts, detail panel, Reorder/InstallDoc/QA buttons. Bill confirmed it looks good, will get specific about parts and ordering.

**QA architecture migrated** from Setting to Document in WC3. Migration 0006 adds `document_id` FK to QuestionAnswer. QAService has new Document-based methods. 5 inspection checklists + 3 training quizzes written at `~/Allie/specs/qa-documents.json`.

**Gordy's quality manual** (29 files) read and mapped to Alice/WC3 equivalents.

**Compliance framework** mapped: ASTM F24 (F2291, F770, F1193, F2974, F3598) + FTA 49 CFR 673 (SMS 4 pillars).

## Do This First Next Session

1. **Run migration 0006** on WC3 — `python manage.py migrate docs` to add document_id column
2. **Load qa-documents.json** — create Document records for the 5 inspection checklists and 3 quizzes
3. **Resolve RED flags** — start with temperature range conflict (chassis -40C vs bogie -10C) and HSS 18/20 mismatch (email Marwan)
4. **Spare parts — real data** — Bill will provide specific manufacturer part numbers, suppliers, prices for the Bogie v22 BOM. Update `bogie_spare_parts.html` with real procurement data
5. **Andi on IT15** — hardware arrives Monday 2026-07-21. Deploy Andi per `readmes/agents/andi.md`
6. **Write `readmes/61-specs-architecture.md`** — the "clear path" document for onboarding. How Gordy's QM + spec library + Alice + Fusion360 BOMs connect

## Open Problems

- 170m BOM instance counts may be undercounted (ACT parse vs browser tree discrepancy)
- Bogie BOM has metric/imperial variants (Housing vs Housing_inch) — need to decide authoritative version
- Spare parts callout positions are approximate — need exact placement
- WC3 migration 0006 not yet applied
- qa-documents.json not yet loaded into WC3 Document records
- `andi-reflect.py` not yet written
- Cloudflare email gate still not tested
- ReportsDialog server-side filter still needed

## What Was Decided (and Why)

- **QA moves from Setting to Document** — Document has body (WHY), refs (standards), config (questions), retention, search. Settings are configuration; Documents are knowledge.
- **Mind-the-Gap: 17mm H / ±8mm V target** — 1/3 below ASCE 21.2-2008 maximum (25mm / ±12mm). Sensors at every door, both sides. Unloaded + loaded measurement. Door locked until loaded gap verified.
- **Spare parts = SEGA pattern** — Exploded view → click → order → install doc → QA. Proven zero misorders in 3 years.
- **SketchUp stays art for now** — until GIS integration gives a reason to make it real drawings. Fusion360 is the CAD authority.
- **Item numbering: pure sequential integers** — no leading zeros, no prefixes. WC3 auto-generates. Decision captured in ItemNumberingSystem gdoc.
- **Andi parks until Monday** — IT15 hardware not yet arrived
- **Flag system: Yellow/Orange/Red** — Yellow = don't understand. Orange = understand problem, no solution. Red = stop everything.

## Files Created This Session

**Allie:**
- `specs/00-TEMPLATE.md` through `specs/12-quality-program.md` (13 files)
- `specs/qa-documents.json`
- `Fusion/170Meter_Full_BOM.json`, `Fusion/Bogie_v22_BOM.json`
- `Fusion/bogie_spare_parts.html`, `Fusion/bogie_extract/` (preview images)

**WC3:**
- `apps/docs/models/question_answer.py` — added document FK
- `apps/docs/services/qa_service.py` — added Document-based methods
- `apps/docs/migrations/0006_questionanswer_document.py`

**Memory:**
- `project_specs_architecture.md`, `project_spare_parts_system.md`
