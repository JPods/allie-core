# JPods Console — Rebuild Plan
**Status:** Draft — 2026-06-09
**Predecessor:** `jpods-console-consolidation.md` (command inventory, 2026-05-08)

---

## Governing UI Principle

> **Nav Panel = primary categories. Display Panel = action buttons + input + outcomes.**

The Nav Panel defines what you are doing (category / agent / phase).
The Display Panel shows the tools and results for that selection.
Nothing that belongs in the Display Panel goes in the Nav Panel sidebar.

---

## Three Audiences

Every tool must be usable by three distinct audiences:

| Audience | Context | What they need |
|----------|---------|----------------|
| **Student** | Building their first network | 4-step guided sequence; clear errors with "what to do" |
| **Designer** | Building a new station template | 10-phase designer workflow; per-phase checklists |
| **Developer** | Debugging the plugin | Full command list; raw output; no hand-holding |

Mode is persisted via `Sketchup.write_default('JPods', 'console_mode', value)`.

---

## Agent Responsibility Map

Every Console error message and every precondition failure is attributed to the agent
responsible for that domain. The prefix `[AgentName]` appears in every output line.

| Agent | Domain | Owns |
|-------|--------|------|
| **Noelle** | Network structure and behavior | Build validation, CP detection, tag integrity, network connectivity, feature.json preconditions |
| **Natalie** | Routing | Trip planning, O-D routing, followme.json, route overlay |
| **Sally** | Station behavior | Originating/landing/hold/parking/pass chains, per-station slot registry, Sally behavior tests |
| **Nora** | Vehicles | Vehicle placement, animation, trip execution, camera follow |
| **Athena** | Cyber security | Not in Console — separate domain; do not rename/reuse |

Format: `[Noelle] CP0 tangent missing — re-run Extract Template.`

---

## Step 1 — TASKS Metadata Keys

Add four keys to every entry in the `TASKS` constant:

```ruby
{
  id:              :build_network_noelle,
  label:           'Build Network',
  category:        'Builder',
  audience:        :all,           # :student | :designer | :developer | :all
  student_step:    5,              # nil if not in student flow
  designer_phase:  :build,         # nil if not in designer flow; see phase list below
  preconditions:   [:lines_json_exists, :cp_json_exists, :geometry_json_exists],
  panel:           :default        # :default | :station_tasks
}
```

**Designer phases** (matches 10-step authoring guide in DESIGNER.md):
`:model`, `:tag`, `:extract`, `:lines`, `:draft_chains`, `:geometry`, `:verify_tracks`,
`:build_validate`, `:commit`

---

## Step 2 — PRECONDITION_CHECKS + NoelleGuard

Replace `module Athena` with `module NoelleGuard`.

Add `PRECONDITION_CHECKS` constant — each entry names a symbol used in TASKS `preconditions:`:

```ruby
PRECONDITION_CHECKS = {
  model_open: {
    agent: 'Noelle',
    label: 'Model open',
    check: ->(m) { !m.nil? },
    hint:  'Open a SketchUp model first.'
  },
  lines_json_exists: {
    agent: 'Noelle',
    label: 'lines.json present',
    check: ->(m) { File.exist?(lines_json_path(m)) },
    hint:  'Author lines.json for this template. See DESIGNER.md Step 5.'
  },
  cp_json_exists: {
    agent: 'Noelle',
    label: 'cp.json present',
    check: ->(m) { File.exist?(cp_json_path(m)) },
    hint:  'Run Extract Template to generate cp.json.'
  },
  geometry_json_exists: {
    agent: 'Noelle',
    label: 'geometry.json present',
    check: ->(m) { File.exist?(geometry_json_path(m)) },
    hint:  'Run Extract Template to generate geometry.json.'
  },
  model_is_template: {
    agent: 'Noelle',
    label: 'Model is a station template',
    check: ->(m) { template_folder(m) != nil },
    hint:  'Open a station template model (not a network model).'
  },
  followme_json_exists: {
    agent: 'Natalie',
    label: 'followme.json present',
    check: ->(m) { File.exist?(followme_json_path(m)) },
    hint:  'Run Build Network to generate followme.json.'
  },
  vehicles_placed: {
    agent: 'Nora',
    label: 'Vehicles placed',
    check: ->(m) { nora_count(m) > 0 },
    hint:  'Place vehicles first (Place 5V at Platform or Run 5V).'
  }
}.freeze
```

Each failed precondition prints: `[AgentName] Precondition failed: <label>. <hint>`

---

## Step 3 — Context Banner (Ruby)

`Console.context_banner(model)` returns a hash:

```ruby
{
  mode:        'student' | 'designer' | 'developer',
  model_name:  model.name,
  is_template: true | false,
  student_step: 1..4 | nil,        # inferred from model state
  designer_phase: :tag | :extract | ...,
  missing_files: ['lines.json', 'geometry.json', ...],
  agent_warnings: ['[Noelle] ...', '[Sally] ...']
}
```

Called on Console open and on every task completion. Sent to HTML as JSON.

---

## Step 4 — Mode Switch State

```ruby
def self.console_mode
  Sketchup.read_default('JPods', 'console_mode', 'student')
end

def self.console_mode=(mode)
  Sketchup.write_default('JPods', 'console_mode', mode)
end
```

Mode selector appears in the banner row (top of Console). Persists between sessions.

---

## Step 5 — Student 4-Step Sidebar (JS/HTML)

The Nav Panel sidebar in student mode shows exactly four numbered steps:

```
1  Geolocate
2  Place Stations
3  Connect + Build
4  Animate
```

Each step lights up green when its preconditions are satisfied.
Clicking a step shows only the tools relevant to that step in the Display Panel.

Students never see the full command list. Errors use "What happened. What to do." format only.

---

## Step 6 — Designer Workflow Phase Panel (JS/HTML)

In designer mode the Nav Panel shows a collapsible 10-phase checklist matching DESIGNER.md:

```
☐  1. Design model.skp
☐  2. Tag guideway groups
☐  3. Place gw_stub_pair + dead_cap_end
☐  4. Extract Template           ← generates cp.json + geometry.json
☐  5. Author lines.json
☐  6. Sally: Draft Chains
☐  7. Hand-correct geometry.json
☐  8. Verify Show Formation Tracks
☐  9. Build + Validate
☐  10. Commit
```

Each phase expands to show the relevant tools in the Display Panel.
Completed phases are checked and collapsed. State persisted in `Sketchup.write_default`.

---

## Step 7 — CP Tangent Purity Check Inside extract_template

After writing cp.json, `extract_template` runs a purity check:

```ruby
cp_data['cps'].each do |cp|
  tx, ty = cp['tangent'][0].abs, cp['tangent'][1].abs
  unless (tx > 0.999 && ty < 0.01) || (ty > 0.999 && tx < 0.01)
    Console.warn "[Noelle] CP#{cp['index']} tangent is not cardinal: " \
                 "[#{cp['tangent'].map { |v| v.round(3) }.join(', ')}]. " \
                 "Check gw_stub_pair placement and re-run Extract Template."
  end
end
```

Non-cardinal tangents are the symptom of the bounding-box-bias defect (TFTS 2026-06-09).
This check catches regressions before they reach Build.

---

## Step 8 — NoelleGuard Precondition Display (HTML)

Before running any task, the Console checks all preconditions in `TASKS[id][:preconditions]`.
Failed preconditions show in the Display Panel as a red card:

```
[Noelle] geometry.json missing
→ Run Extract Template to generate it.
```

The task button is disabled until all preconditions pass. No silent failures.

---

## Step 9 — Error Message Rewrite Pass

Every `raise`, `puts`, and `Console.error` call is rewritten to "What happened. What to do." format with agent attribution:

```
[Noelle] Track gw_platform_in not found in lines.json.
→ Open lines.json and confirm the track name matches the SketchUp Tag exactly.
```

```
[Sally] chains_header.approved_by is empty.
→ Sally will not operate this station. Bill must sign chains_header.approved_by in lines.json.
```

---

## Step 10 — Context Banner HTML

A persistent banner div at the top of the Console (always visible):

```html
<div id="context-banner">
  <span id="cb-mode-badge">Student</span>
  <span id="cb-model-name">CA_Gilroy_Clean</span>
  <span id="cb-step-hint">Step 3: Connect + Build</span>
  <div id="cb-warnings"></div>
</div>
```

Updated on every `context_banner` call. Warnings appear inline (not modal) — no interruption.

---

## Step 11 — Station Behavior Tests (Display Panel)

**Location:** Display Panel only — `<div id="station-tasks">`.
**Not in Nav Panel sidebar.** These are test actions, not workflow categories.
**Audience:** `:designer` mode only (hidden in student mode).

### Six Sally Behavior Scenarios

Each scenario is a card with: title, description, Run button, status indicator, log output.

| ID | Label | What it tests |
|----|-------|--------------|
| `st_place_vehicles` | Place Vehicles | Places one vehicle at each parking slot. Verifies slot count from lines.json `parking_chain`. |
| `st_parking` | Parking | Routes a vehicle from CP to a parking slot. Verifies `landing_chains` → `parking_chain` sequence completes. |
| `st_station_looping` | Station Looping | Places more vehicles than parking capacity. Verifies overflow vehicles execute `hold_loop_chain`. |
| `st_shuffle_parking` | Shuffle Parking | Fills all slots, departs the first-slot vehicle, verifies remaining vehicles advance one slot. |
| `st_courtesy_loop` | Courtesy Loop | Places vehicle with pending trip in non-front slot. Verifies vehicles ahead execute `pass_chains` loop and return. |
| `st_excess_capacity` | Excess Capacity | Places one vehicle beyond capacity. Verifies it executes `originating_chains` → `gw_cp_out_*` and exits the station. |

### Status States

```
gray   — not run
blue   — running
green  — passed
red    — failed (reason shown in log)
```

### Ruby Side — TASKS Entries

```ruby
[:st_place_vehicles, :st_parking, :st_station_looping,
 :st_shuffle_parking, :st_courtesy_loop, :st_excess_capacity].each do |task_id|
  TASKS << {
    id:             task_id,
    label:          STATION_TASK_LABELS[task_id],
    category:       'Station Tests',
    audience:       :designer,
    preconditions:  [:model_is_template, :lines_json_exists, :geometry_json_exists],
    panel:          :station_tasks
  }
end
```

Return prefix for JS interception: `"__STATIONTASK__:#{task_id}:pass"` or `"__STATIONTASK__:#{task_id}:fail:<reason>"`

### HTML Structure

```html
<div id="station-tasks" class="display-panel" style="display:none">
  <div class="st-header">
    <span class="st-title">Station Behavior Tests</span>
    <select id="st-station-select">
      <option value="">— select template —</option>
    </select>
    <button onclick="stClearAll()">Clear</button>
  </div>
  <div class="st-grid">
    <div class="st-card" data-task="st_place_vehicles">
      <div class="st-card-title">Place Vehicles</div>
      <div class="st-card-desc">Verify slot count from parking_chain.</div>
      <button class="st-run-btn" onclick="stRun('st_place_vehicles')">Run</button>
      <span class="st-status st-gray">—</span>
    </div>
    <!-- ... five more cards ... -->
  </div>
  <div id="st-log" class="st-log">
    <div class="st-log-empty">Run a test to see output here.</div>
  </div>
</div>
```

### Nav Panel Entry

The Nav Panel sidebar (designer mode) includes one entry that opens the station-tasks Display Panel:

```
[ ] Station Tests
```

Clicking it shows `<div id="station-tasks">` — it does not expand inline in the sidebar.

---

## Implementation Order

Steps build on each other. Implement in sequence:

1. **Step 1** — TASKS metadata keys (foundation; all other steps reference it)
2. **Step 2** — PRECONDITION_CHECKS + NoelleGuard rename
3. **Step 8** — Precondition display in HTML (quick win — uses Step 2)
4. **Step 3** — Context banner Ruby
5. **Step 10** — Context banner HTML
6. **Step 4** — Mode switch state
7. **Step 5** — Student sidebar (simplest layout change)
8. **Step 6** — Designer workflow phase panel
9. **Step 7** — CP tangent purity check (self-contained; add to extract_template lambda)
10. **Step 9** — Error message rewrite pass (do last — touches every message)
11. **Step 11** — Station behavior tests (add after mode switch works; designer mode only)

---

## What Does NOT Change (from consolidation plan)

- All underlying Ruby methods are preserved — only TASKS entries and HTML change
- The trip table `JSON` button stays as-is
- `Show Trip Path` orange overlay stays
- `Export Debug Bundle` and `Audit Network + Export Log` are unchanged
- `Shuffle to Departure End` stays in Developer category
