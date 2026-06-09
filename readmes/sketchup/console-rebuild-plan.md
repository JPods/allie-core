# JPods Console — Rebuild Plan
**Status:** In Progress — 2026-06-09
**Predecessor:** `jpods-console-consolidation.md` (command inventory, 2026-05-08)

---

## Governing UI Principles

> **Nav bar = primary sections. Display Panel = everything for that section.**

1. The nav bar is one line across the top. Four items. That is all.
2. Every button executes an action directly — no URL behavior, no `href`.
3. Tasks with no parameters execute on click. Tasks with parameters show their
   form first; Execute appears below the last field.
4. Binary buttons change text to describe the *next* click, not the current state.
   ("Start Animation" → "Stop Animation", "Show Overlay" → "Hide Overlay")
5. Task output lives inside the Display div that owns the task.
6. Console Log is always visible at the bottom — it is the Ruby puts() stream,
   independent of which Display div is active.

---

## Three Audiences

Every section must be usable by three distinct audiences:

| Audience | Context | What they need |
|----------|---------|----------------|
| **Student** | Building their first network | 4-step guided sequence; clear errors with "what to do" |
| **Designer** | Building a new station template | Full workflow; per-phase checklists |
| **Developer** | Debugging the plugin | Full command list; raw output; no hand-holding |

Mode is persisted via `Sketchup.write_default('JPods', 'console_mode', value)`.
Mode switch lives inside **Documentation**.

---

## Layout

```
┌─ nav (one line, ~30px) ──────────────────────────────────────────────────────┐
│  NETWORK   VEHICLES   MODELS   DOCUMENTATION      [Reload] [●Noelle] [mode▾] │
├─ display panel (flex: 1, full width) ────────────────────────────────────────┤
│  One div visible at a time.                                                   │
│  Each div owns its task buttons, params, execute, and task output.            │
├─ console log (always visible, ~100px, collapsible) ──────────────────────────┤
│  Ruby puts() stream — live feed regardless of active display div.            │
└──────────────────────────────────────────────────────────────────────────────┘
```

The sidebar is **removed**. No left panel.

---

## Agent Responsibility Map

Every error message and precondition failure is attributed to the agent
responsible for that domain. The prefix `[AgentName]` appears in every output line.

| Agent | Domain | Owns |
|-------|--------|------|
| **Noelle** | Network structure and behavior | Build validation, CP detection, tag integrity, network connectivity, feature.json preconditions |
| **Natalie** | Routing | Trip planning, O-D routing, followme.json, route overlay |
| **Sally** | Station behavior | Originating/landing/hold/parking/pass chains, per-station slot registry, Sally behavior tests |
| **Nora** | Vehicles | Vehicle placement, animation, trip execution, camera follow |
| **Alice** | Ticket sales + Small-Stings + action lists | Trip pricing, booking, invoices, payments (wcapi); Small-Stings; Project → Action → Document records in WC3 |
| **Athena** | Cyber security | Not in Console — separate domain |

Format: `[Noelle] CP0 tangent missing — re-run Extract Template.`

---

## Display Div: NETWORK

**Purpose:** Build, validate, and connect a JPods network. Primary working view.

**Left column (task buttons):**
Task buttons grouped by category. Categories visible depend on mode:
- Student: only tasks matching `student_step` for the active step
- Designer: Workflow + Routes + Developer tasks
- Developer: all tasks

**Right column / main area:**
- Network Editor iframe (connection diagram) — always visible in NETWORK
- When a task is selected: task description appears above NE iframe
- When a task has params: param form appears; Execute button follows the last field
- When no params: task executes immediately on click (Workflow / Routes tasks)
- Task output strip below the NE iframe

**Task button rules:**
- Risk dot (green/yellow/red) on left of button label
- NoelleGuard preconditions shown as ✓/✗ strip above Execute when task is selected
- Execute is disabled until all preconditions pass and (if destructive) confirm is checked

**Sub-sections in NETWORK:**
| Sub-section | Content |
|-------------|---------|
| Workflow | Builder + Workflow task buttons |
| Routes | Routes task buttons + route overlay controls |
| Noelle | Validate, fault list, CP check |

---

## Display Div: VEHICLES

**Purpose:** Place vehicles, assign trips, run animation.

**Controls (always visible):**
- **Start Animation / Stop Animation** — binary; text changes on click
- **Random On / Random Off** — binary
- Speed input + Set button
- Populate Fleet button
- Random Trips button
- Add Vehicle: station select + model select + Add button + Clear All button

**Trip table:**
- One row per vehicle: Nora ID, line count, start station, end station (editable), trip preview, action buttons
- Trip action button: **Assign / Clear** — binary; becomes "Clear" when destination is set
- 📷 camera follow button per row — binary; turns orange when active
- JSON button per row — shows trip detail

**Vehicle placement:**
No params → direct button execution.
Animation controls are binary — no Execute button needed.

---

## Display Div: MODELS

**Purpose:** Template authoring and geometry tools. Most users will not need this.

**Content:**
- Model info strip (formation name, CPs, chains status, formation map status)
- Template authoring buttons (Extract Template, Draft Chains, Generate Formation Map, etc.)
- Station behavior tests (six Sally scenarios: st_place_vehicles through st_excess_capacity)
- Model Tools reference table (command → use → menu path)

**Station behavior tests:**
Each test is a card: title, description, Run button, status indicator (gray/blue/green/red), log output.
Status states: `gray` = not run, `blue` = running, `green` = passed, `red` = failed.

---

## Display Div: DOCUMENTATION

**Purpose:** Learning, mode switch, and future reference content.

**Content:**
- **Mode switch**: Student / Designer / Developer toggle (persists)
- **Learning checklist**: 13 items across 4 groups (Console UI, Noelle Guard, Build, Animation)
  - Each item: checkbox + label + guidance detail (Do / Expect / Pass / Fail / Skip)
  - State persists in localStorage
- **Future**: DESIGNER.md rendered as static HTML reference

---

## Task Button Pattern

```
┌─ Task button ──────────────────────────────────────────────────────┐
│  ● Build Network                                          [Builder] │
└────────────────────────────────────────────────────────────────────┘

On click (no params, not destructive):
  → executes immediately
  → button shows "Running…" (disabled)
  → restores label when complete

On click (has params):
  ┌─ params form ────────────────────────────────────────────────────┐
  │  Speed (m/s): [____]                                             │
  │  Model:       [select ▾]                                         │
  │  [Execute]                                                       │
  └──────────────────────────────────────────────────────────────────┘

On click (destructive):
  ┌─ confirm row ────────────────────────────────────────────────────┐
  │  ☐ I understand this will delete all vehicles                    │
  │  [Execute] (disabled until checked)                              │
  └──────────────────────────────────────────────────────────────────┘
```

Binary button text rule:
- Text describes what the **next click will do**
- "Start Animation" means: clicking this will start animation
- "Stop Animation" means: clicking this will stop animation
- Never: "Animation (running)" — the state is the button's visual style, not its label

---

## Precondition Display

Before a task's Execute fires, NoelleGuard evaluates preconditions.
Failed preconditions render as a ✗ row with agent attribution and hint:

```
[Noelle] ✗ lines.json missing
         → Author lines.json for this template. See DESIGNER.md Step 5.
[Noelle] ✓ cp.json present
```

Execute is disabled until all preconditions pass.
Precondition strip lives inside NETWORK div, above Execute.

---

## Console Log (always visible)

Fixed strip at the bottom of the window. Never hidden.
Two buttons: Copy | Clear.
Collapsible height via drag handle — not a toggle button.
Ruby puts() stream only — not task output.

Task output (formatted result of last execution) lives inside the Display div
that owns the task, below the NE iframe or below the task button that triggered it.

---

## Nav Bar

One horizontal row. No dropdown menus. No nesting.

```html
<nav id="top-nav">
  <button class="nav-btn" data-div="network">Network</button>
  <button class="nav-btn" data-div="vehicles">Vehicles</button>
  <button class="nav-btn" data-div="models">Models</button>
  <button class="nav-btn" data-div="documentation">Documentation</button>
  <span class="nav-spacer"></span>
  <button class="nav-action-btn" onclick="reloadPlugin()">Reload</button>
  <span id="noelle-badge" class="badge-active">✓ Noelle</span>
  <select id="mode-select" onchange="cmdSetMode(this.value)">
    <option value="student">Student</option>
    <option value="designer">Designer</option>
    <option value="developer">Developer</option>
  </select>
</nav>
```

Active nav button gets a bottom border accent (no background change — keeps it light).

---

## Ruby Side — No Structural Changes

All underlying Ruby methods are preserved. The restructure is HTML/CSS/JS only:
- TASKS constant and metadata keys unchanged
- PRECONDITION_CHECKS unchanged
- NoelleGuard unchanged
- All `cmd_*` callbacks unchanged
- `context_banner` and `console_mode` methods unchanged

The only Ruby change: `initTasks` receives the display div to activate on load
(default: 'network').

---

## Implementation Order

1. **Nav bar HTML + CSS** — replace sidebar with `#top-nav`; four `data-div` buttons;
   `showDiv(name)` JS function hides all display divs, shows the named one
2. **NETWORK div** — move task-list + NE iframe into `#div-network`;
   task buttons render inside; task output strip at bottom
3. **VEHICLES div** — move trip table + animation controls into `#div-vehicles`
4. **MODELS div** — move model tools + station tests into `#div-models`
5. **DOCUMENTATION div** — move learning checklist + mode switch into `#div-documentation`
6. **Execute pattern** — remove global `#btn-execute-top`; Execute renders inside task
   display area (already mostly done for params); immediate-execute for no-param tasks
7. **Binary button audit** — verify all binary behaviors have correct label-swap behavior
8. **Console Log drag resize** — replace toggle button with drag handle on top edge
9. **Remove sidebar CSS** — clean up all sidebar-specific rules

---

## What Does NOT Change

- All underlying Ruby methods
- The trip table `JSON` button
- `Show Trip Path` orange overlay
- `Export Debug Bundle` and `Audit Network + Export Log`
- The Learning checklist content and state (localStorage)
- NoelleGuard review strip behavior

---

## Open Items

- [ ] Resizable display divs — drag handle between NETWORK columns (task list vs NE iframe)
- [ ] Student mode in NETWORK — the 4-step sidebar becomes a step indicator row
      inside the NETWORK div header, not a separate nav item
- [ ] DOCUMENTATION — DESIGNER.md as static rendered HTML (future session)
- [ ] Station behavior tests return prefix `__STATIONTASK__` — wire to MODELS div status cards
