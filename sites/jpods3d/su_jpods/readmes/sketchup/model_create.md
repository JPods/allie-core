# JPods Station Template — Model Creation and Lines Verification

**Audience:** Template authors — people creating or maintaining the station `.skp` files
that students place into their network projects.

**Not for:** Students building networks. If you are placing stations and connecting
guideways, you are in the right tool — just run Build (Console > Workflow > Build).

---

## Why This Exists

Every station template has an internal track topology: which segment flows into which,
where pods enter, where they exit, how the parking loop connects back to the main line.
Noelle needs this topology to route pods correctly through a station.

Noelle can infer topology automatically from geometry — but inference is imperfect.
Two segments that share an endpoint can be arriving at the same junction from opposite
directions, or they can both be departing. Geometry alone cannot always tell the difference.

`lines.json` is the human-verified record. It is the topology Noelle trusts.
Every template must have a verified `lines.json` before it can be used in a project.
Build blocks if one is missing.

**This matters beyond simulation.** When a station design moves from SketchUp to a
physical JPods installation, Nora (the vehicle controller) follows the same segment
sequences that Noelle declared in `lines.json`. A wrong topology in simulation becomes
a wrong route in steel and aluminum. The verification step here is also a construction
safety review.

---

## Sovereignty First — Two Paths

Your design is yours. You choose what to do with it.

**Path A — Share (Community Service):**
Submit your verified template to Noelle. It ships in the plugin, gets posted to the
SketchUp Warehouse, and becomes part of the JPods commons. If your design is novel —
a configuration Noelle has not seen before — you are recognized and rewarded (see below).

**Path B — Keep (Local Review Only):**
Run Noelle's review locally inside the plugin. No data leaves your machine. Your
`lines.json` stays private. You use your template in your own projects and physical
builds. You improve Noelle's local reasoning for your own use without contributing
to the community dataset.

This is not a lesser path. Some station designs are proprietary to a city contract,
a research project, or a commercial installation not yet ready for disclosure.
The local tools work the same either way.

---

## Attribution and Reward for Novel Contributions

When you submit a template, Noelle compares your geometry to every template already
in the community dataset. If your design is **novel** — a configuration, junction
type, or parking arrangement that does not exist in any prior submission — that fact
is recorded.

**What novel means:** Noelle measures novelty by topology, not appearance. A traffic
circle with six connection points where all prior circles had four is novel. A
station with a split-platform that allows simultaneous loading and unloading is
novel. A re-skin of an existing four-CP terminal is not novel, and that is fine —
it is still a valid contribution.

**Attribution:**
Every `lines.json` that ships in the plugin carries a `contributors` field:

```json
"contributors": [
  { "name": "Jane Smith", "handle": "jsmith_jpods", "submitted_at": "2026-06-01",
    "novel": true, "description": "First six-CP traffic circle in the dataset" }
]
```

Your name (or handle — anonymous is also accepted) is permanent. It ships in the
plugin and appears in the SketchUp Warehouse listing. If your design is built
physically, the construction record references your contribution.

**Reward:**
Novel contributions earn a share of the value they generate:

- **Recognition:** Named in the plugin, the Warehouse listing, and the JPods
  contributor registry at jpods.com
- **Commercial use fee:** If a physical JPods installation is built using your
  template design, you receive a one-time design acknowledgment fee. The amount
  is declared in the JPods Community License (published at jpods.com/license).
  This is not a royalty — the design is open source — but the community recognizes
  that novel physical infrastructure has a different weight than a software patch.
- **Improvement credit:** If Noelle's algorithm improves because of rules extracted
  from your corrections, that is recorded. You contributed to Noelle's education,
  which benefits every future template author.

The reward mechanism is simple by design. It is not a marketplace. It is an
acknowledgment that the people who build the Physical Internet deserve to be seen.

---

## Community and Open Source

Station templates and their `lines.json` files are **free and open source**. The workflow:

1. Build and verify your template locally (steps below)
2. Submit to Noelle via the JPods Community Service (no account required)
3. Post the `.skp` model to the [SketchUp 3D Warehouse](https://3dwarehouse.sketchup.com)
   under the JPods collection
4. Your `lines.json` is merged into the plugin's `templates/track_formations/` folder
   and ships to all users in the next release

Every verified template is a permanent contribution to the JPods Physical Internet.
A station you design today may be built in a city a decade from now. The topology
you verify is the route Nora will run.

---

## The Three Lines Tools (Console > Tools)

All three are grayed out unless the frontmost SketchUp file is inside the `su_jpods`
plugin folder — a template model, not a student project. To use them:

1. Open the template model (e.g. `su_jpods/templates/track_formations/traffic_circle7/model.skp`)
2. Make it the frontmost SketchUp window
3. Open or reload JPods Console

| Tool | What it does |
|------|-------------|
| **Lines Scan** | Reports all `su_jpods_feature` instances and whether `lines.json` exists |
| **Lines Build from Template** | Scans `gw_*` geometry, infers topology, writes `lines.json` |
| **Lines Map Feature** | Extracts topology from a built project's `map.json` into `lines.json` |

For a new or edited template, the primary tool is **Lines Build from Template**.

---

## Backup Convention

Every time a Lines tool writes `lines.json`, the existing file is automatically
copied to `lines~YYYYMMDDTHHMMSS.json` in the same folder before the new file
is written. Example after three runs:

```
track_formations/station_parking/
  lines.json                  ← current verified state
  lines~20260526T143022.json  ← previous version (algorithm inferred)
  lines~20260527T091544.json  ← second pass (partial human correction)
```

**Never delete backup files manually.** Each one is a labeled training example:
- `lines~<older>` → `lines~<newer>` = one correction pass, timestamped
- `lines~<newest>` → `lines.json` = the final human verification

The delta between consecutive files is the signal Noelle reads to improve her
BFS classification rules. When you submit to the Community Service, all backup
files travel with the submission. The history is the lesson.

### Cleaning Stale Backups

Once a template is stable and submitted, intermediate backups become redundant.
Two Console tools manage this (both require the template model as the frontmost file):

| Tool | What it does |
|------|-------------|
| **Lines List Backups** | Shows all backup files, ages, and roles across all formations |
| **Lines Clean Backups** | Deletes stale intermediates; always keeps the oldest and most recent N |

**What is always kept:**
- The **oldest** backup — the original algorithm baseline; the full journey starts there
- The **most recent N** (default 3) — the last correction passes

**What is a candidate for deletion:**
- Intermediate backups older than the stale threshold (default 30 days)
- Files between the oldest and recent-N that Noelle has already seen

**Always run List first, then Clean with dry run = true, then confirm.**
The default is dry run — nothing is deleted until you explicitly set dry run to false.

**When to clean:**
- After a submission to the Community Service is acknowledged
- When a template has been stable (no changes to `lines.json`) for 60+ days
- Before a plugin release, to keep the distribution lean

The oldest backup is permanent. It is the record of what the algorithm produced
before any human touched the file. Do not delete it.

### Adding Human Judgment Notes

The backup files record what the topology was. Notes record what you knew about it.

> Console → Tools → **Lines Add Note**

Fields:

| Field | Meaning |
|-------|---------|
| Formation name | Which template (e.g. `station_parking`) |
| Status | `worked` / `broke` / `observation` |
| Note | Your judgment in plain text |
| Backup timestamp | The `YYYYMMDDTHHMMSS` from Lines List Backups — blank = most recent |
| Author | Your name or handle (optional) |

The note is written as `lines~YYYYMMDDTHHMMSS.note.md` alongside the backup.
Example:

```
lines~20260526T143022.note.md:

  formation:  station_parking
  backup:     lines~20260526T143022.json
  status:     worked
  added_at:   2026-05-27T09:15:44Z
  author:     Bill

  ## Note

  gw_platform_out → gw_uturn_0 was correct in this version. Pods traversed
  the parking loop cleanly on 5V test. Broke after geometry edit on 2026-05-27
  when gw_uturn_0 endpoint moved ~200mm — see lines~20260527T091544.json.
```

**Note files are never auto-deleted.** `clean_backups` removes backup `.json`
files only; `.note.md` files survive. If the associated backup is cleaned, the
note remains as a standalone record of what was true at that point in time.

Lines List Backups shows `[note:worked]` or `[note:broke]` next to any backup
that has a note, so you can see the judgment history at a glance.

When you submit to the Community Service, all note files travel with the
submission. Noelle reads the notes alongside the diffs — "worked at this
timestamp, broke at the next" is precisely the training signal that tells her
which topology change caused the regression.

### Allie's Registry — ~/Allie/process/lines_backups.json

Every backup file is registered the moment it is created. Allie holds a pointer
file — not the data — so she can track the lifecycle without reading the
formation folders directly.

Each registry entry records:

| Field | Meaning |
|-------|---------|
| `formation` | Template name |
| `path` | Absolute path to the backup file |
| `created_at` | UTC timestamp |
| `submitted` | false until sent to Noelle Community Service |
| `acknowledged_at` | UTC timestamp when Noelle confirmed receipt |
| `alice_doc_id` | WebClerk document ID once Alice has a record |
| `status` | `active` → `submitted` → `cleaned` |

**Allie reads this nightly and:**
- Flags unsubmitted active entries as open TFTS arcs
- Identifies entries acknowledged by Noelle that are safe to clean
- When total active entries reach the threshold (default 20), flags Alice

**Alice's role:**
When Allie passes the threshold flag to Alice, Alice creates a document record
in WebClerk pointing to the backup files. The document is a pointer, not a copy —
the files stay where they are. Alice's record allows the full correction history
to be retrieved without keeping all backup files on disk indefinitely.

This follows the Project → Action → Document pattern: the correction arc is the
Action; the backup files are the evidence; Alice's document is the permanent
pointer once the arc is closed.

Use **Lines Registry** (Console → Tools) to see the current state of Allie's
registry without opening the JSON file directly.

---

## Step 1 — Build lines.json from Template Geometry

Open the template model as the frontmost file. Run:

> Console > Tools > Lines Build from Template

Noelle scans every `gw_*` tagged edge group in the model. For each segment she records:
- `start_point` and `end_point` in mm
- `length_mm`
- `in` — segments that flow INTO this one
- `out` — segments this one flows OUT TO
- `eps` — list of EP ids where this segment participates
- `model_error: true` — set only when this segment is at a junction that cannot be
  classified as binary (see below)

At the top level of `lines.json`, Noelle also writes an `eps` array — one entry per
junction where two or more segments meet.

**Junction-based binary topology (tolerance 1500mm):**

Every segment has a start (departure) and end (arrival). All endpoints are grouped
by proximity into junctions. Each junction is classified by counting arrivals vs departures:

```
1 arrive + 1 depart  →  straight  (1-in/1-out)
2 arrive + 1 depart  →  merge     (2-in/1-out)  — e.g. uturn re-enters mainline
1 arrive + 2 depart  →  diverge   (1-in/2-out)  — e.g. mainline splits to siding
1 member only        →  open end  (network boundary — no error, no EP created)
anything else        →  model_error — fix the geometry
```

Each EP becomes an entry in `lines.json`:
```json
{ "id": 1, "type": "merge", "in": ["gw_cp_in", "gw_uturn"], "out": ["gw_cp_in_lead"] }
```

The 1500mm tolerance is intentionally wide — raw template geometry often has small
gaps between endpoints that would be snapped in a built model.

---

## Step 2 — Check and Correct ins and outs

Open `su_jpods/templates/track_formations/{name}/lines.json` in a text editor.

**First: check for `model_error` junctions.** If any segment has `"model_error": true`,
a junction in your model has the wrong number of arriving or departing segments.
Every junction must be exactly one of:

- `straight` — 1 segment arrives, 1 departs
- `merge` — 2 segments arrive, 1 departs (e.g. uturn re-enters mainline)
- `diverge` — 1 segment arrives, 2 depart (e.g. siding branches off mainline)

Go back to the `.skp` model and fix the geometry until every junction is one of these
three types, then re-run Lines Build from Template.

**Then: check the `eps` array** to confirm each EP has the expected `in` and `out` lists.
For each EP, ask: does the direction assignment match physical pod flow?
- `in` segments arrive at this EP (their ends touch the junction)
- `out` segments depart from this EP (their starts touch the junction)

If an EP's direction is backwards, the segment geometry is reversed in the model —
the `start_point` and `end_point` of the guideway edge are the wrong way around.
Fix in SketchUp by reversing the edge direction.

**Finally: check the `in`/`out` lists per segment.** Confirm the chains are complete:

A pod entering the station follows a chain:
```
gw_cp_in → gw_cp_in_lead → ... → gw_cp_out_lead → gw_cp_out
```
Or for a through-station:
```
gw_cp_in → gw_near_main → gw_far_main → gw_cp_out
```

Every chain should have a clear entry point (segment with empty `in`) and a clear
exit point (segment with empty `out`) — or an explicit recirculation back via `gw_uturn`.

**Role name conventions:**

| Role | Direction |
|------|-----------|
| `gw_cp_in` | External inbound — pod arriving from inter-station guideway |
| `gw_cp_out` | External outbound — pod departing to inter-station guideway |
| `gw_cp_in_lead` | Internal inbound lead — pod moving toward platform |
| `gw_cp_out_lead` | Internal outbound lead — pod moving toward exit |
| `gw_platform` | Dwell zone — pod waits here for passengers |
| `gw_uturn` | Recirculation — >90° turn; re-enters mainline at a merge EP |

**Common mistakes:**
- A junction with `model_error` — fix geometry so it is exactly 1+1, 2+1, or 1+2
- A segment with no `out` that is not a terminal parking slot — pod has no exit
- An EP with `in` and `out` swapped — reverse the edge in SketchUp

---

## Step 3 — Test in a Project

After editing `lines.json`, confirm the topology works in a real network:

1. Open a project model that uses this template (in `skp_jpods/`)
2. Run Build (Console > Workflow > Build)
3. Watch the Ruby Console for:
   ```
   Noelle map: S003 — topology replaced from traffic_circle7/lines.json (N new links)
   ```
4. Run 5V Standard Test and watch pods traverse the station
5. If pods flow through cleanly — `lines.json` is correct
6. If pods stall inside the station — a chain is broken; return to Step 2

The Ruby Console will show which segments have no successors at animation time:
```
[Nora] no successor for S003.gw_platform_out — pod stopped
```
That segment name is your entry point for the next correction.

---

## Step 4 — Noelle Review: Local or Community

**If you are keeping the template private (Path B):**

Run the local Noelle review inside the plugin:

> Console > Tools > Lines Scan

Noelle checks your `lines.json` for internal consistency: chains with no exit,
`model_error` EPs, disconnected subgraphs, duplicate entries. She reports problems
with enough detail to find and fix them. No data leaves your machine.

This review does not improve Noelle's algorithm — it is a one-way tool. You
benefit from everything the community has already contributed, but your corrections
stay local.

---

**If you are sharing the template (Path A):**

The JPods Community Service is **free, no account required**. It is not a gatekeeper —
it is a learning service. Noelle reviews your corrected `lines.json`, compares it to
what her algorithm inferred, and returns a report. Your submission also improves
Noelle's inference for every future template author.

### Current: Noelle API (thin Claude wrapper)

Noelle is currently implemented as a thin wrapper around Claude (claude-opus-4-6).
She has deep context about JPods station topology, the `gw_*` role naming conventions,
the BFS algorithm, and the physical constraints of pod routing through a station.

When you submit a corrected `lines.json`, Noelle:
1. Reads your geometry (the `start_point`, `end_point`, `length_mm` fields)
2. Reads the `eps` array — each EP's type and `in`/`out` assignments
3. Compares against what the algorithm inferred from geometry
4. Explains any EP that required a geometry fix (edge reversal, endpoint gap) to classify correctly
5. Returns rule candidates to the development team for the next release

This is the same reasoning Claude Code and Allie use today to improve the algorithm —
made available directly to template authors.

### Future: Dedicated Noelle Model

As corrections accumulate across all submitted templates, the dataset grows:
- Input: template geometry (segment endpoints, role names, lengths)
- Output: human-verified EP classifications (straight/merge/diverge) and `in`/`out` lists
- Corrections: which EPs had wrong direction assignments and why

This dataset trains a dedicated Noelle model — fine-tuned specifically on JPods
station topology. The fine-tuned model will:
- Classify every EP correctly on first pass (no `model_error` junctions)
- Recognize recirculation loop structures that challenge junction grouping
- Generalize to novel station geometries not yet in the training set
- Run faster and cheaper than the Claude wrapper, enabling real-time assistance
  in the SketchUp Console

**Why this matters for physical builds:**

The fine-tuned model is not just a convenience for SketchUp users. Every physical
JPods installation depends on the same segment topology. When a city commissions a
station, Nora's trip sequences are derived from the same `lines.json` that Noelle
verified in SketchUp. A model with 1000 training examples is more reliable than a
human making a judgment call at 11pm before a construction deadline.

The goal is a Noelle that has seen enough station geometries that she can look at
a new design and say: "this will work," "this will cause pods to loop," or "this
parking configuration will deadlock under high load" — before a single beam is bent.

### Submission Workflow (when the API is live)

```
Console > Tools > Submit lines.json to Noelle
```

Noelle receives:
- Your corrected `lines.json`
- The original inferred version (before corrections)
- The template name and SketchUp Warehouse URL (if posted)

Noelle returns:
- Confirmation that the topology is internally consistent
- A diff: what changed from inference to correction, and why
- Rule candidates extracted from your corrections
- A community credit entry — your name (or handle) in the template's contributor list

Submissions are not moderated before use — they go directly into the community
dataset. The plugin's canonical `lines.json` files are updated on each release
after automated consistency checks pass.

---

## Step 5 — Post to SketchUp 3D Warehouse

After Noelle confirms the topology:

1. Open the template model in SketchUp
2. File > 3D Warehouse > Share Model
3. Title format: `JPods Station — {descriptive name}` (e.g. `JPods Station — Traffic Circle 7`)
4. Tags: `jpods`, `transit`, `guideway`, `station`
5. Description: include the formation name (e.g. `traffic_circle7`), the number of
   connection points, and whether it is a terminal, through, or parking station
6. Upload `lines.json` as an attachment or include the link to the plugin repository

Post the Warehouse URL in a message to the JPods community so it appears in the
plugin's template browser in the next release.

---

## lines.json Schema Reference

Location: `su_jpods/templates/track_formations/{formation_name}/lines.json`

```json
{
  "schema": "jpods-station-line-v2",
  "formation": "cp",
  "generated_at": "2026-05-26T00:00:00Z",
  "generated_by": "MapFeatureTool.run_from_template",
  "source_model": "model.skp",
  "note": "Built from template geometry using junction-based binary topology. External CP wiring added by Noelle at Build time.",
  "eps": [
    { "id": 1, "type": "merge",  "in": ["gw_cp_in", "gw_uturn"], "out": ["gw_cp_in_lead"] },
    { "id": 2, "type": "merge",  "in": ["gw_cp_out_lead", "gw_uturn"], "out": ["gw_cp_out"] }
  ],
  "lines": {
    "gw_cp_in": {
      "length_mm": 3500.0,
      "start_point": [x, y, z],
      "end_point":   [x, y, z],
      "in":          [],
      "out":         ["gw_cp_in_lead"],
      "eps":         [1]
    },
    "gw_cp_in_lead": {
      "length_mm": 8200.0,
      "start_point": [x, y, z],
      "end_point":   [x, y, z],
      "in":          ["gw_cp_in", "gw_uturn"],
      "out":         [],
      "eps":         [1]
    },
    "gw_uturn": {
      "length_mm": 5600.0,
      "start_point": [x, y, z],
      "end_point":   [x, y, z],
      "in":          [],
      "out":         ["gw_cp_in_lead", "gw_cp_out"],
      "eps":         [1, 2]
    }
  }
}
```

**Top-level fields:**

| Field | Type | Meaning |
|-------|------|---------|
| `eps` | array | One EP per junction; each has `id`, `type`, `in`, `out` |

**EP types:**

| Type | Arrivals | Departures | Example |
|------|----------|------------|---------|
| `straight` | 1 | 1 | mainline pass-through |
| `merge` | 2 | 1 | uturn re-enters mainline |
| `diverge` | 1 | 2 | siding branches off mainline |
| `model_error` | other | other | geometry error — fix in SketchUp |

**Per-segment fields:**

| Field | Type | Meaning |
|-------|------|---------|
| `in` | string array | Role names that flow INTO this segment |
| `out` | string array | Role names this segment flows OUT TO |
| `eps` | int array | EP ids where this segment participates |
| `model_error` | bool | Present and true only when segment is at a bad junction |
| `start_point` | [x,y,z] mm | Template-local coordinate of segment start |
| `end_point` | [x,y,z] mm | Template-local coordinate of segment end |
| `length_mm` | float | Arc length of the segment |

Role names in `in`/`out` are bare (no station ID prefix). Noelle prefixes them
with the instance's `structure_id` at Build time. External CP wiring
(gw_cp_in/out ↔ inter-station guideway) is always added by Noelle at Build time
and is never stored in `lines.json`.

---

## Current Template Status

| Template | lines.json | Notes |
|----------|-----------|-------|
| `traffic_circle7` | generated | Check EPs for correct type and direction |
| `station_line_end` | generated | Needs gw_* tagged geometry — scan will return no segments |
| `station_thru_dip` | generated | Has malformed segment name — fix in SketchUp model first |
| `station_parking` | generated | Check EPs for correct type and direction |
| `cp` | pending | New cp_unit design — run Lines Build from Template after tagging |

Run **Lines Scan** on each template model to see current status.

---

## Noelle's Topology Algorithm — Current State and Improvement Path

Noelle's current algorithm in `run_from_template`:

1. Scan all `gw_*` entities → extract centerline pts, start and end points
2. Group all endpoints by proximity (1500mm, transitive) into junctions
3. Classify each junction by arrivals vs departures → straight / merge / diverge / model_error
4. Wire `in`/`out` maps from junction classifications
5. Write `eps` array and per-segment `eps` membership to `lines.json`

**Binary topology rule:**
Every junction is 1-in/1-out, 2-in/1-out, or 1-in/2-out. Any other count is a
`model_error`. This eliminates the old `uncertain` list — ambiguity now means the
geometry is wrong, not that the algorithm is uncertain.

**Known gaps:**

- **Edge direction**: if a `gw_*` edge was drawn backwards in SketchUp (start and end
  reversed), the algorithm classifies that junction correctly but assigns the segment
  to the wrong direction. Fix: reverse the edge in the model.

- **Tolerance sensitivity**: 1500mm is wide enough to group endpoints that are truly
  at the same junction but physically close to a different junction. Dense geometry
  may require tighter tolerance or more precise endpoint placement.

- **Multi-segment junctions**: a 3-in/1-out junction (not yet a known JPods topology)
  would be flagged as `model_error`. If a new station design legitimately requires
  such a junction, the algorithm must be extended — and the new type added to the EP
  type vocabulary.

**Improvement path (each submission feeds this):**

1. For each `model_error` EP, record:
   - The segment roles and their kinds (arriving/departing) at that junction
   - The gap distances between endpoints
   - Whether the fix was an edge reversal or a geometry correction
2. Extract rules: e.g. "if a junction has 3 arrivals, check whether one is a doubled
   edge (same role, two edges) — if so, merge them first"
3. Add rules as pre-classification passes before the junction grouping step
4. Reduce `model_error` cases until they only fire on genuinely novel geometry

The fine-tuned Noelle model is the end state of this loop run at scale — not a
replacement for human judgment, but the distillation of all human judgments made
by template authors across every station geometry the JPods community has built.
