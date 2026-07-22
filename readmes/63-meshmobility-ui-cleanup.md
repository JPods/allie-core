# MeshMobility UI Cleanup — 2026-07-21

## Changes Made

### Left Panel (Palette) — Simplified

**Before:** New, Open, Save, Refresh, Clipboard, Report, Guide, Examples, CityTool, Regulations, Root Cause, Run, Reload, Replay, Isochrone, Demand, Slots

**After:**
```
File:     New | Open | Save | 🏆 Compete | ? Guide | 📚 Examples
Lock:     🔓 Edit
Simulate: ▶ Run | ▶▶ Replay | 📄 Report | ⭕ Isochrone
Map:      [tile selector]
```

### Right Panel (Sidebar) — Reorganized

```
Row 1: 🔍 Find City | ⚙ Tools | 🌐 Overlays | ⚙ Settings
Row 2: 💰 CityTool | ⚖ Regulations | 🌱 Root Cause
```

All Row 2 buttons open `target="_blank"`.

Demand + Slots moved into Settings panel under "Passenger Demand" group.

### Removed
- **Refresh** — browser reload suffices
- **Reload** — same as Refresh
- **Clipboard** — replaced by Compete
- **CityTool from left panel** — moved to right sidebar Row 2

### Added
- **🏆 Compete** — saves network + submits to Alice for evaluation (action record)
- **Report + Isochrone grayed out until Run completes** — no results = no report

### Mobile Responsive
- Left palette: hamburger menu (☰) on phones (<768px)
- Right sidebar: slides off-screen right (◀/▶ toggle), map fills space
- Leaflet `invalidateSize()` called after transition

## Security — RED FLAG Fix

### Path Validation (Athena)

All file operations — Open, Save, Reload — now validate paths against a whitelist:

```python
ALLOWED_PATHS = [
    "~/Documents/08_JPods/.../mesh_mobility_maps/",
    "/Applications/RouteTime_JPods/",
    "~/Allie/",
    "/Volumes/Allie/",
    "/tmp/mesh_mobility/",
]
```

- Path traversal (`..`) blocked
- Violations logged as FAULT files
- Returns 403 Forbidden for any path outside whitelist

### Server-Only Save

Save no longer uses the browser file picker. No user navigation outside the blessed folder.

- `saveFile()` sends only a filename (auto-generated: `ST_City_YYYY-MM-DD.jpd`)
- Server strips path components, uses only basename
- Always writes to `mesh_mobility_maps/` (ALLOWED_PATHS[0])
- Download endpoint exists at `/api/network/download` for explicit export
- Same model as Google Docs — it just saves. Export is separate.

### On Andi (IT15)

Each user's networks save to `/{user_id}/networks/` within the blessed folder.
Same path validation applies. `ALLOWED_PATHS` configured at deployment.

## Training

10 training features with scripts, quizzes, and READMEs at:
`route_time/training/{01-10}/`

50 quiz questions across all features, loadable into Alice.

## Files Changed

- `gui/static/index.html` — left panel cleanup, right panel reorg, mobile responsive
- `gui/static/app.js` — Compete button, server-only Save (no file picker)
- `gui/static/simulator.js` — Report + Isochrone disabled until Run
- `gui/network_io.py` — `_validate_path()`, server-only save to blessed folder
