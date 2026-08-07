# Handoff — 2026-08-07 (Designer + Alice LLM Session)

## Where We Left Off
Three-panel PrintLayoutDesigner built and working (WC2 pattern). Alice upgraded to 20b LLM (alice:latest from gpt-oss:20b, shared weights with allie:latest). Alice's MCP server wired to use LLM for reasoning over vector search results.

## Do This First Next Session
1. **Re-add Alice MCP** — command failed due to line split. Run:
   `claude mcp add -s user alice -- ~/Allie/venv/bin/python3 ~/Allie/scripts/alice-mcp-server.py`
2. **Test ask_alice** — verify the 20b LLM reasoning works through the MCP tool (not just direct Ollama call)
3. **Fix /invoice page** — stuck on "Loading invoice..." while databrowser works fine. Console shows no errors, layout FOUND, API calls succeed. React rendering bug — data loads but UI never renders.
4. **Designer polish** — populate a real invoice layout using Alice's field knowledge, test Save flow

## What Was Built
- `PrintLayoutDesigner.tsx` — three-panel designer (Models+Fields | Used by Zone | Preview)
- Five zones: Header, Body, List, Total, Footer (matching WC2 SuperReport bands)
- `DetailFieldsSection` type added to `printLayoutTypes.ts`
- `renderDetailFields` added to `UniversalPrint.ts`
- `alice:latest` Modelfile at `training/Modelfile.alice` (FROM gpt-oss:20b)
- `alice_think()` function in `alice-mcp-server.py` — calls Ollama for reasoning
- `leftshoe-mcp.py` — fixed session doc NOT NULL columns (superseded by Bill's team-memory rewrite)

## What Was Decided (and Why)
- **Share gpt-oss:20b** between Alice and Allie — 32GB Mac can't run two separate 20b models. Ollama shares base weights when parent model is identical. Zero extra RAM.
- **Five zones not three** — WC2 SuperReport has Header, Body, List, Total, Footer. Originally had only Header/List/Footer. Bill showed the WC2 form designer screenshot.
- **Three-panel layout** — Left: models+fields. Middle: used fields by zone. Right: live preview. Bill specified this over the initial two-panel design.

## Open Problems
- `/invoice` page rendering bug — data loads (API 200s, layout FOUND) but UI stays on "Loading invoice..."
- Alice field paths include model prefix (`invoice.ida` vs `ida`) — needs training refinement
- Designer double-click adds to Body zone — WC2 pattern had destination choice
- `log_session` leftshoe tool exists in code but wasn't available this session (server not restarted)
- SectionCard.tsx, FieldEditor.tsx, SectionTypePicker.tsx from v1 still in codebase — may reuse or remove

## Files Changed This Session
- `React2025/src/components/print/PrintLayoutDesigner.tsx` — complete rewrite (three-panel WC2 pattern)
- `React2025/src/components/print/printLayoutTypes.ts` — added DetailFieldsSection
- `React2025/src/components/print/UniversalPrint.ts` — added renderDetailFields + CSS
- `Allie/scripts/alice-mcp-server.py` — added alice_think() LLM reasoning
- `Allie/training/Modelfile.alice` — NEW, Alice identity from gpt-oss:20b
- `Allie/scripts/leftshoe-mcp.py` — fixed NOT NULL columns (superseded by Bill's rewrite)

## Team Memory
- Session document: tm-954 (id: 954) in commerce_expert.documents
- Old-format session doc: id=952 (also has action log from early session)
