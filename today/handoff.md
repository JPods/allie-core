# Handoff — 2026-08-07 (DesignMode Session)

## Where We Left Off
Built DesignMode for print reports — a visual PrintLayout editor inside ReportsDialog. Two commits pushed to React2025 `bill_dev`: v1 section cards (`92915f43`) and v2 two-list field picker (`4265b615`). The designer works: shift-click a report row or click Design, two lists on left (Available fields / Used fields by zone), live preview on right, auto-arrange engine handles alignment/formatting/widths. Hard modal, 95vw, report list collapses. Session Document id=950.

## Do This First Next Session
1. **Polish to WC2 pattern** — read the reference image at `~/Documents/Screenshots/Screenshot 2026-08-07 at 5.15.34 AM.png`. The WC2 form designer shows: double-click to add fields, field types visible (string/date/number), drag reorder in Used list, table selector at bottom. Implement these in `PrintLayoutDesigner.tsx`.
2. **Fix leftshoe session document creation** — the `is_deleted` column on Document has no default. Leftshoe passes null. Fix in `leftshoe-mcp.py` to pass `is_deleted=false` explicitly. Same for `is_archived`, `is_locked`, `comment`, and all NOT NULL fields.
3. **Add rightshoe reminder** — if session document was not created at startup (server not running), rightshoe should remind Bill to start the server so Claude has Allie + Alice for memory.
4. **Test Save flow** — click Save in the designer to write `Report.config.form`. Verify the layout persists and prints correctly via the normal print path.
5. **Django slow startup** — system check takes minutes. No fix found. Allie has no notes on a prior fix. Investigate `--skip-checks` or `--noreload` for dev.

## Open Problems
- DesignMode v2 uses small H/L/F badge buttons — needs double-click to add (WC2 pattern)
- Available field list doesn't show types (string, date, currency)
- Drag reorder in Used list works but is basic HTML5 drag — could be smoother
- No model/table selector yet (currently uses model from ReportsDialog context)
- SectionCard.tsx, FieldEditor.tsx, SectionTypePicker.tsx from v1 still in codebase — may reuse or remove

## What Was Decided (and Why)
- **PrintLayout JSON is the only format** — Bill said "only use print.json unless very special circumstances." No pdfme templates for reports.
- **Two-list design** — user picks WHAT fields and WHERE (Header/List/Footer zones). Claude/Alice arrange HOW (alignment, formatting, widths). This separates user intent from layout mechanics.
- **Hard modal** — user requested it. DesignMode is 95vw/92vh, click-outside blocked, report list collapses. Prevents losing the editor behind the parent window.
- **Auto-arrange engine** — `guessFormat()`, `guessAlign()`, `guessWidth()` functions in PrintLayoutDesigner.tsx convert field assignments into proper PrintLayout sections. Currency right-aligned, dates formatted, descriptions get 25% width, etc.
- **Scar #37** — Claude must self-assess compression risk and tell Bill when to stop. Don't wait to be asked.

## Files Changed This Session
- `React2025/src/components/print/UniversalPrint.ts` — extracted generatePrintHtml + PRINT_CSS export
- `React2025/src/components/print/FieldEditor.tsx` — NEW inline field property editor
- `React2025/src/components/print/SectionCard.tsx` — NEW section editor (3 shapes)
- `React2025/src/components/print/SectionTypePicker.tsx` — NEW section type dropdown
- `React2025/src/components/print/PrintLayoutDesigner.tsx` — NEW main designer (rewritten v1→v2)
- `React2025/src/components/common/ReportsDialog.tsx` — design mode state, shift-click, hard modal, collapsed list
