# Handoff — 2026-08-13 (Evening Session)

## What Happened

Major architecture session on the WC3 report and output system. Three fundamental rules established and implemented:

1. **WC3 is not a print design tool** — SVG templates designed externally, we populate with data
2. **WC3 is not an email/letter formatting tool** — users paste {{tokens}} into Gmail/Word/Pages
3. **Be expert in handing data to better tools** — Scar #57

TinyMCE killed before installation. Legacy print CSS deleted. Token system built.

## What Was Built

### SVG Form System
- `SvgFormGenerator.ts` — generateFormSvg(), populateFormSvg(), downloadSvg()
- PrintLayoutDesigner updated — Export/Import SVG buttons, line pagination (Pg1/Pg2+/Wrap), footer toggles (Page#/Domain), text format (plain/markdown)
- printLayoutTypes.ts — lines_page_1, lines_following, max_description_lines, show_page_numbers, show_domain, text_format, svg_template, row_height, svg_panel_id
- 5 SVG form Report records seeded (ids 442-446) — Invoice, Order, Proposal, Purchase, Payment — all staged (is_active=False, purpose=svg-form-staged)

### Token System  
- `TokenBuilder.tsx` — standalone {{token}} field picker. Click=clipboard, shift-click=build set, Copy All in Detail or List mode
- Integrated into ReportsDialog as first row — no new UI real estate
- `/tokens` and `/tokens/:model` routes for standalone access
- `TokenBuilderPage.tsx` route wrapper
- Documentation: token-system.md + wc3-token-system.dot/.svg/.pdf

### Custom Pages
- `src/custom/` directory — pages/, components/, index.ts registry, README.md
- `CustomPageLoader.tsx` — /custom/:page route
- Full WC3 component library available via @/ imports
- Separate from src/apps/ — survives updates

### Print CSS Cleanup
- Stripped print.css to structural defaults (--print-* variables, no design opinions)
- Deleted legacy-invoice-print.css (dead Vue-era file)
- Removed font props from PrintDocumentLayout (fonts live in SVG, not our JSON)
- Alice scanner: exclude_dirs added for print/ in no-dark-mode check (553→520 violations)

### Documentation
- wc3-report-system.dot/.svg/.pdf — full report system flowchart
- wc3-token-system.dot/.svg/.pdf — token data flow
- report-system-overview.md — comprehensive reference
- token-system.md — focused on handing data to better tools
- report-editor-types.md — updated (removed TinyMCE, added SVG)

## Three-Layer Architecture (Print)

| Layer | Owns | Changed by |
|-------|------|-----------|
| SVG | Fonts, positions, styling | Designer in their tool |
| CSS | Page breaks, color-adjust | Us — standard offering |
| JSON | Line counts, page numbers, toggles | User at runtime |

## Five Handoff Formats (Tokens)

| Format | Destination |
|--------|-------------|
| Clipboard | Gmail, Word, Pages — paste anywhere |
| CSV | Google Sheets, Excel — mail merge |
| JSON | Scripts, Zapier, API clients |
| Populated SVG | Printer, PDF viewer |
| Template Path | Word/Pages via AppleScript/terminal |

## Remaining Items from Session Start (Not Addressed)

1. **test_sequence_001.py** — Django shell script, not pytest. Rename or add conftest exclusion.
2. **Browser visibility** — Playwright headless capture not verified as installed
3. **SessionStart hook** — missing from ~/.claude/settings.json (script exists at ~/Allie/scripts/session-start.sh)
4. **Query editor** — Bill mentioned wanting to work on this, deferred to next session

## Next Session

- Query editor (Bill's stated priority)
- Remaining Alice items (test runner, session hook, browser visibility)
- Consider: wire TokenBuilder's Copy All (List) to actual DataBrowser CSV export with resolved tokens
