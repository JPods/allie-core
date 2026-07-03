# Handoff — 2026-07-03

## Where We Left Off
Renamed `model.data` → `model.config` on 16 models (DB, Python, React all done). Built `json_field_ops.py` for surgical JSON updates — works in Django shell but save_view.py field loop doesn't route dot-path keys to it via the API yet. Layout save changed from Pending to direct Setting save with retry-on-lock. Alice fully operational: vector store (4,656 chunks), MCP server (5 tools), quiz engine (28 questions), observation pipeline. The save reaches the backend and returns 200, but the **merge logic is wrong**: it replaces the entire `Setting.data` instead of merging the new named view into `data.views[]`. The "BillTest" view saved via curl proved the backend CAN persist views — the problem is the React `persistSetting` sends the full `data` object which overwrites existing views. Fix needed: either merge on the backend (preferred — Setting save should merge `data.views` not replace) or have the frontend fetch current views before saving.

## Do This First Next Session
1. **Wire dot-path json_field_ops through save_view** — `apply_json_op` works perfectly in Django shell (proven: upsert, merge, append, remove all work). But save_view.py's field loop skips dot-path keys like `config.views` when they arrive via the API. The field IS in the `data.items()` loop and the `'.' in field` check at line 653 should route it to `apply_json_op`, but something earlier in the loop (lines 570-593) may be skipping or consuming it. Debug: add a log at line 653 to confirm it reaches the branch. The `data→config` rename is DONE (DB columns, model fields, Python refs, React refs all updated).
2. **Clean up stale Pending records** — 3 unprocessed Pending records (ids 245-247) with `purpose=layout_change` and `dt_processed=0`. Mark them processed or delete — they're from the old Pending-based flow that never worked (Celery tasks in `tasks.py` had no `@shared_task` decorators).
3. **Reseed alice_guess + alphabetical views** — The BillTest curl test overwrote them. Run `seed_alice_layouts.py` to restore default views for contact model.
4. **Test alice_observation auto-flush** — Console capture should now save to `alice_observations` table (model registered, alias map added). Verify in browser — should see no more 400 errors in network tab.
5. **Register Alice MCP server** — Built but needs Claude Code restart to activate. After restart, `ask_alice`, `alice_search`, `alice_observe`, `alice_recall`, `alice_quiz` tools available.

## Open Problems
- **Layout save replaces instead of merging** — views get wiped when saving a new named view. Core UX blocker for DataBrowser.
- **Chrome Debug app** — works from terminal but `open` via Finder may not pass args reliably. Shell alias `chrome-debug` works. Requires `--user-data-dir` (Chrome 150 requirement) which means separate profile from normal Chrome.
- **Celery tasks have no decorators** — All functions in `apps/ai_assistant/tasks.py` are plain Python, not `@shared_task`. Celery Beat schedules them but they never execute. Not blocking since we moved to direct save, but the tasks file needs cleanup.
- **`save_hooks.py` had indentation error** — Fixed line 75, but this file should be audited for other issues.

## What Was Decided (and Why)
- **Direct Setting save, not Pending** — Pending pattern requires Celery, and the tasks had no decorators. Direct save is simpler and immediate. Audit trail via AliceObservation instead of Pending records.
- **Alice vector store separate from Allie/Claude** — Three stores, three domains. Alice indexes WC3 code + docs + legacy PDFs (3,977 → 4,521 chunks). No overlap confusion.
- **Alice MCP server** — Separate from Allie's MCP. Alice does commerce (search, observe, recall, quiz). Allie does cross-domain (ask, teach, recall, flag). Different knowledge, different tools.
- **Chrome Debug requires `--user-data-dir`** — Chrome 150 won't open debug port without it. Means separate profile. Acceptable for dev.
- **wcapi_registry `_ALIAS_MAP`** — Multi-word Django model names (e.g., `aliceobservation`) need underscore aliases (`alice_observation`) so wcapi resolves them. Added 30+ entries covering all compound model names.
- **`models_alice.py` imported in `models.py`** — Django only discovers models in `models.py` or `models/__init__.py`. Without the import, AliceObservation/AlicePreset/AliceCoachingLog were invisible to Django's app registry.

## Files Changed This Session

### Allie
- `scripts/alice-vectorstore.py` — NEW: Alice's vector store (index, search, stats, PDF support)
- `scripts/alice-mcp-server.py` — NEW: Alice MCP server (ask, search, observe, recall, quiz)
- `scripts/update_field_access.py` — Field access update script (from July 2)
- `readmes/46-chrome-devtools-mcp.md` — NEW: Chrome DevTools MCP setup guide
- `readmes/flowcharts/wc3-*.dot` — NEW: 12 WC3 flow charts (DOT source)
- `readmes/flowcharts/wc3-*.pdf` — NEW: 12 WC3 flow charts (rendered PDF)
- `.chroma_db_alice/` — NEW: Alice's ChromaDB store (4,521 chunks)
- `exchange/alice-conversation.jsonl` — NEW: Alice MCP exchange log

### WC3 (webClerk3)
- `apps/ai_assistant/models.py` — Added import of models_alice (line 7)
- `apps/core/services/wcapi_registry.py` — Added `_ALIAS_MAP` with 30+ compound model name aliases
- `apps/core/constants/save_hooks.py` — Fixed indentation error line 75
- `apps/core/views/save_view.py` — Added pre-save debug logging for Setting
- `readmes/topics/ai/alice-toolkit.md` — NEW: Complete tool registry readme
- `readmes/topics/ai/alice-observation-setup.md` — NEW: Alice observation pipeline guide
- `readmes/flowcharts/` — NEW: 12 flow chart DOT + PDF files

### React (React2025)
- `src/hooks/useDataBrowser.ts` — Changed `persistSetting` from Pending to direct Setting save with retry-on-lock

### Infrastructure
- `/Applications/Chrome Debug.app/` — NEW: Chrome launcher with debug port
- `~/.zshrc` — Added `chrome-debug` alias
- `~/.claude.json` — Registered alice MCP server

### WC3 Documents Created (via wcapi)
- 20 tool reference Documents (TOOL-GRAPHVIZ through TOOL-CHROMADB)
- 5 quiz Documents (QUIZ-INVENTORY-FLOW through QUIZ-TOOLS, 28 questions total)
- 1 AliceObservation test record
