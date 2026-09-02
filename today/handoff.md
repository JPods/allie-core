# Handoff — 2026-09-02

## Where We Left Off

Built the Contact Paste tool — a drag-and-drop contact parser with two modes: paste new contacts (free-form or structured) and search/cleanup existing contacts. The tool detects tab/CSV/pipe delimited data, finds the header row (skipping noise), maps columns to WC3 fields via a synonym dictionary, and presents a grid where users drag chips between columns. Each correction is a Small-Sting that Alice learns from. Unmapped columns (District, Party, Room) go to `prefs.userdefined`. Alice episode logging wired — every import batch creates an `AliceObservation` with a header fingerprint so Alice can pre-map columns when the same source pattern reappears. The HTML tool is at `/tools/contact_paste.html`, served from the same origin as WC3.

## Do This First Next Session

1. **Update HTML tool for two-step header confirmation** — the backend has `/wcapi/ai/contact/detect/` and `/wcapi/ai/contact/parse-confirmed/` but the HTML still uses the one-step `/contact/parse/`. Add the header confirmation UI: show detected columns + mapping, let user adjust, then parse.
2. **Deploy to Andi** — upstream escalation endpoints + Contact Paste tool + Python 3.14.7 venv rebuild (Andi already on 3.14.4, needs requirements.txt update for pydantic 2.13.5 + nameparser).
3. **Test rework** — ~210 test failures from 2026-08-25 still outstanding. Many may be resolved by the pydantic upgrade and Document model changes.
4. **Videos** — Setting Parade + Journal Formatter (Bill records).
5. **DynamicCatalogs session** — wire `trading_partner` tag into episode schema, sync supplier column mappings through WCHQ escalation chain. Alice learns Duravent's price list format once, shares it to all installations.

## Open Problems

- PII bare name detection (without prefix) deferred — design decision on false-positive tolerance pending
- `seed_coaching --force` Document `model_name` field requires migration on Andi
- Jennifer Balinsky Armini — nameparser puts "Balinsky" as last name because it's the second word; "Armini" goes to staging. User must drag to correct. Could improve with middle-name detection.
- Merge flow: "Commit Now" button and undo countdown not yet tested end-to-end in browser
- Contact save from paste tool uses `AllowAny` permission — needs session auth check before production

## What Was Decided (and Why)

- **Dragged record dominates on merge** — the row you pick up keeps its ID/ida/uuid; the dropped-on row is absorbed and deactivated. More intuitive than the reverse.
- **config.backup is temporary (24h)** — Alice cleans merge backups nightly via `alice_clean_backups`. Safety net for accidental merges, not permanent storage. Schema: `MergeBackup` and `DeactivatedByMerge` in PJPV (`common/schemas/contact.py`).
- **Company suffixes (Inc, LLC, Corp) checked before nameparser** — prevents "Wyoming Registered Agent Inc" from being parsed as a person's name. Suffix list in `_COMPANY_SUFFIXES`.
- **Unmapped columns → prefs.userdefined, not staging** — District, Party, Room are real data that belongs on the contact. `userdefined` is searchable and user-visible. Staging is temporary.
- **Episode learning for imports** — each import logs an `AliceObservation(model_name='contact_import')` with header fingerprint. `recall_import_pattern()` finds prior episodes by fingerprint or fuzzy column match. This is the seed for DynamicCatalogs — supplier column mapping shared through WCHQ.
- **nameparser library (2.2.0)** — handles compound names (van der Berg), prefixes (Dr.), suffixes (Jr., III). Pure Python, 7KB, no dependencies. Better than manual regex splitting.
- **Python 3.14.7 on Mac** — stable since Oct 2025, now on maintenance release 7. Pydantic 2.13.5 / pydantic_core 2.46.5 required for 3.14 compatibility.

## Files Changed This Session

### WebClerk backend (`Documents/WebClerk/app/backend/`)
- `apps/ai_assistant/services/pii_scrub.py` — REWRITTEN: two-layer PII parser (regex + database vocab), Small-Stings learning loop, `parse_pii()` + `scrub_pii()` + `record_pii_correction()`
- `apps/ai_assistant/services/contact_parser.py` — NEW: tokenizer, classifier, nameparser integration, structured data detector, column mapper, episode logging, merge backup cleanup, cross-row duplicate scoring, contact search/load
- `apps/ai_assistant/views.py` — added PiiParseView, PiiCorrectView, ContactParseView, ContactDetectView, ContactParseConfirmedView, ContactSearchView, ContactParseCorrectView
- `apps/ai_assistant/urls.py` — 6 new routes: pii/parse, pii/correct, contact/parse, contact/detect, contact/parse-confirmed, contact/search, contact/correct
- `apps/ai_assistant/models/alice.py` — added `pii_correction` category to AliceObservation choices
- `apps/ai_assistant/management/commands/alice_clean_backups.py` — NEW: nightly merge backup cleanup
- `apps/ai_assistant/services/aggregate_tracker.py` — fixed `_setting_update_authorized` on both save calls
- `apps/core/management/commands/seed_coaching.py` — restored `model_name` in doc dicts + create/update calls
- `apps/core/management/commands/seed_qa_from_readmes.py` — fixed WC3_ROOT path (parents[5]), updated all 30 readme paths after restructure
- `apps/docs/models/document.py` — added `model_name` + `record_id` fields with compound index
- `apps/docs/migrations/0003_add_document_model_name_record_id.py` — NEW migration
- `common/schemas/contact.py` — added `MergeBackup`, `DeactivatedByMerge`, updated `ContactConfig`
- `tools/contact_paste.html` — NEW: drag-and-drop contact paste/search/merge tool
- `webclerk3_api/urls.py` — added route for contact_paste.html
- `requirements.txt` — pydantic 2.13.5, pydantic_core 2.46.5, nameparser 2.2.0

### Allie
- Deleted 267 iCloud " 2" duplicate files across WebClerk
- Deleted duplicate migration `0001_squashed_initial 2.py` in ai_assistant
- Python 3.14.7 installed via Homebrew, WC3 venv rebuilt
