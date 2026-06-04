# JPods Station Template — Designer Risk List

**Purpose:** Known failure modes when authoring or editing station template `.skp` files.
Each item is a real defect encountered during the 2026-06-04 extraction session.
The `Models › Extract Template` command in the SketchUp console will flag most of these.

---

## 1. vector_in Edge — Must Be INSIDE the Component Definition

**What Extract Template checks:** "vector_in: none found in gw_cp_in_N"

The 172mm edge tagged `vector_in` must be drawn while the `gw_cp_in_N` component is
**open for editing** (double-click to enter). If drawn at the station level (not inside
the component), it is invisible to the detector.

**How to fix:** Double-click `gw_cp_in_N` to open it. Draw a 172mm edge on the `vector_in`
tag pointing in pod travel direction (the direction a pod arrives into the station).
Close the component. Re-run Extract Template.

**Applies to:** `gw_cp_in_0`, `gw_cp_in_1`, `gw_cp_in_2`, `gw_cp_in_3` (one per CP).
Does NOT apply to `gw_cp_in_lead_*` — these use CCW fallback direction only.

---

## 2. lines.json Track IDs Must Exactly Match SketchUp Tag Names

**What Extract Template checks:** "in model but not declared in lines.json — designer-undefined track"

Track IDs in lines.json `lines` section are exact SketchUp tag name strings.
- Case-sensitive: `gw_Uturn_0` ≠ `gw_uturn_0`
- `_#` suffix is literal: `gw_cp_in_#` is a track named with the `#` character, not a
  placeholder for a number

**Common mistake:** Using a simplified name in lines.json that doesn't match the actual
tag in the model. The extractor will scan 20 tags, update 19, and report 1 undeclared.

**How to fix:** Open Entity Info for the actual guideway edge in the model, copy the exact
tag name, paste it into lines.json.

---

## 3. Every Model Track Must Be Declared in lines.json

**What Extract Template checks:** "🚫 gw_XXXX: in model but not declared in lines.json"

Any `gw_*` tagged edge in the model that has no entry in lines.json `lines` section is
a routing gap. Natalie cannot plan a route through a track that has no successors defined.

**Consequence:** Silent routing failure. The topology looks complete but Natalie will
reject any trip that requires that track.

**How to fix:** Add an entry to lines.json `lines` with the exact tag name and correct
`successors` list. Save lines.json. Re-run Extract Template to confirm count clears.

---

## 4. Arc Radius Check Uses Inside Rail — Minimum 1500mm

**What Extract Template checks:** "🚫 gw_uturn_N: arc radius Xmm < 1500mm minimum (inside-rail radius)"

SketchUp's ArcCurve traces the **inside rail** of the guideway, not the centerline.
The three concentric radii for a standard uturn are:

| Rail | Radius | Notes |
|------|--------|-------|
| Inside rail | 1500 mm | What SketchUp measures; what the check enforces |
| Centerline | 1750 mm | Pod travel path; physical minimum for vehicle dynamics |
| Outside rail | 2000 mm | Outer envelope |

**Common mistake:** Drawing the arc on the centerline (1750mm) then getting a 1500mm
report and thinking it failed. It did not — the ArcCurve measure is correct.

**If the check fails (radius < 1500mm):** The arc was drawn too tight. Move endpoints
farther apart. The minimum chord for a semicircular uturn (chord = 2r = diameter) is
3000mm for inside rail.

---

## 5. Junction Endpoint Gaps — Exact Vertex Required

**What Extract Template checks:** "junction gap: Nmm — endpoint not shared; fix by snapping"
and severity levels: ok (0mm), warn (<5mm), severe (>15mm)

Chain junctions (where one track ends and another begins) must share an **exact vertex** —
proximity is not enough. A 15mm gap still produces a warning. 0mm gap is required
for clean routing.

**How to fix:** In SketchUp, zoom in to the junction. Enable "snap to endpoint". Move
the end vertex of one edge onto the start vertex of the next until they merge into one
point. The "junction gap" count will drop to 0 on the next Extract Template run.

**Root cause:** Edges drawn separately and placed near each other. Use SketchUp's
Lock Axis and Snap tools to draw connected track from the endpoint of the previous edge.

---

## 6. cp_marker_* Components Must Be in the Template Model

**What Extract Template checks:** "cp.json: no cp_marker_* found"

The CP Calculate tool places `cp_marker_N` components when run on the template model.
If the template `.skp` was opened without having had CP Calculate run, or if the markers
were accidentally deleted, cp.json will be empty after Extract Template.

**How to fix:**
1. Close and reopen the SketchUp Console after opening the template model
2. Run `Models › CP Calculate` (or the equivalent in Workflow)
3. Confirm green CP rings appear in the viewport
4. Then run `Models › Extract Template`

**Note:** The console captures the active model at open time. If you switch models
without reopening the console, CP Calculate and Extract Template will run against
the old model reference and produce no output.

---

## 7. Reopen Console After Switching Template Models

**Symptom:** Extract Template runs but produces no output, or output references the
wrong formation name.

The SketchUp console captures `Sketchup.active_model` at the time the console window
is opened. Switching from one template model to another without reopening the console
causes all console commands to run against the first model's stale reference.

**Rule:** After opening a new template `.skp` file, close and reopen the JPods Console
before running any Extract Template, CP Calculate, or Proof Lines commands.

---

## 8. hold_loop from_platform and to_platform May Be Intentionally Empty

**What Extract Template warns:** "⚠ hold_loop_chain.from_platform: empty" or "...to_platform: empty"

For **end-of-line stations** (`station_line_end`), the pod enters the platform directly
from the loop without a dedicated `from_platform` or `to_platform` segment. These
chains being empty is correct topology — NOT a defect.

**The only genuine violation:** `hold_loop_chain.loop` being empty. An empty hold loop
means pods have nowhere to wait and the station cannot queue traffic.

**If you see from_platform or to_platform warnings** on a non-end-of-line template,
check that those segment tags exist in the model and are declared in lines.json.

---

## 9. Template Model Must Be Open — Not a Network Model

Extract Template reads live SketchUp geometry from the open file. It expects a
**template definition** (the station geometry alone), not a full JPods network model.

Running Extract Template with a network model open will produce wrong geometry data —
the extractor will attempt to scan all component definitions in the model, many of which
will not have the expected tag structure.

**Rule:** Always run Extract Template with the standalone template `.skp` file open
(e.g., `JPods_station_parking/model.skp`), not a network model.

---

## Summary Checklist

Before Extract Template, verify:

| # | Check | How |
|---|-------|-----|
| 1 | vector_in edge inside each gw_cp_in_N | Double-click component, check Entity Info |
| 2 | lines.json track IDs match SketchUp tags exactly | Entity Info on each edge |
| 3 | Every gw_* track in model declared in lines.json | Run Extract Template; check for 🚫 undeclared |
| 4 | Uturn arc radius ≥ 1500mm (inside rail) | Run Extract Template; check arc violations |
| 5 | Junction endpoints share exact vertex (0mm gap) | Zoom in, snap endpoints together |
| 6 | cp_marker_* components present | Run CP Calculate first |
| 7 | Console reopened after model switch | Always close/reopen Console when switching |
| 8 | hold_loop.loop not empty (from_platform/to_platform ok if empty) | Topology intent |
| 9 | Template model open, not network model | Check file title bar |
