# Handoff — 2026-07-17

## Where We Left Off
MeshMobility Draw tool enhancement session. Changed drawn line colors from yellow/orange to bright blue (#00bfff/#0099ff) for visibility against map roads. Fixed modifier-key bug where Shift+click, Shift+dblclick, and Option+click were unreachable in Draw mode (latched check swallowed all clicks before modifier checks). Added hide/show toggle button (eye icon) for drawn lines. Fixed double-click duplicate point bug in `_finishLine`. Replaced the crude vertex-proximity crossing detection in `build_on_lines` with true segment-segment intersection math. Added debug print statements to verify crossing detection fires. **Not yet tested after restart** — Bill stopped for the night before restarting MeshMobility. Vector store pushes for GEEKOM IT15 architecture completed (Claude, Noelle, Alice stores).

## Do This First Next Session
1. **Restart MeshMobility and test crossing detection** — draw two crossing lines, hit Build on Lines, check terminal for `[build_on_lines] CROSSING` messages. If crossings detected but no traffic circle appears, debug the circle placement code in `builders.py:1191+`. File: `mesh_mobility/gui/builders.py`
2. **Test all Draw tool modifiers** — Shift+click (delete point), Shift+dblclick (delete line), Option+click (insert/drag point), hide/show button. File: `mesh_mobility/gui/static/index.html`
3. **Capital and MOA plan** — Bill's priority for tomorrow. Review MOA-2026 actions in Google Sheet. Pull with: `~/Allie/venv/bin/python3 ~/Allie/scripts/allie-sheets-sync.py --pull`
4. **Fix MeshMobility bugs** — Bill mentioned other bugs besides the Draw tool. Ask what they are.
5. **Verify IT15 readiness** — GEEKOM expected ~2026-07-20. Review readmes/58 checklist.

## Open Problems
- Crossing detection code is in place but untested after server restart — unknown if traffic circles actually appear at intersections
- The crossing-to-circle heading calculation uses overall line direction (first→last point), not local heading at the crossing — may produce misaligned circle arms
- Google Drive MCP auth doesn't work from CLI — only web app. Workaround: allie-sheets-sync.py
- MeshMobility has other unspecified bugs Bill wants to fix

## What Was Decided (and Why)
- **True segment intersection replaces vertex proximity** — old code checked if any vertex on line A was within 400m of any vertex on line B. This missed crossings between vertices entirely. New code computes exact lat/lon where line segments cross.
- **Modifier keys checked before latched-draw handler** — Shift and Alt clicks must take priority over plain draw-mode clicks, otherwise the user can't edit lines while in Draw mode.
- **Bright blue (#00bfff active, #0099ff finished) for drawn lines** — yellow/orange was invisible against the yellow roads on the map. Blue stands out on all map tiles.
- **Duplicate trailing points stripped in _finishLine** — double-click fires a click event (adding a point) then dblclick (finishing). The duplicate caused zero-length segments.

## Files Changed This Session
- `mesh_mobility/gui/static/index.html` — Draw tool: blue colors, modifier-key priority fix, hide/show toggle button, duplicate point fix, help table color update
- `mesh_mobility/gui/builders.py` — `build_on_lines`: replaced vertex-proximity crossing detection with true segment-segment intersection math, added debug logging
