# Athena — JPods SketchUp Console Guard
**Last Updated:** 2026-04-20  
**Domain:** JPods SketchUp 2026 Plugin  
**File:** `JPods/jpod_console.rb` → `JPods::Athena` module  
**Companion UI:** `JPods/dialogs/console.html`

---

## What this is

The JPods Console is a user-facing task runner built into the SketchUp plugin.
Instead of pasting raw Ruby into SketchUp's Ruby Console, users pick a task from
a sidebar, fill in any parameters, and click Execute.

Athena sits between the user's click and any code that runs.

---

## The two gates

### Gate 1 — On task selection
`Athena.review(task, {}, model)` is called the moment the user clicks a task name.
The result appears immediately as a colored strip in the dialog:

- Green (safe) — ready; no issues
- Yellow (caution) — modifies the model but is undoable
- Red (destructive) — requires explicit checkbox before Execute is enabled
- Red (blocked) — context check failed; Execute stays disabled

This gives the user honest feedback *before* they touch any parameters.

### Gate 2 — On Execute
`Athena.review(task, params, model)` runs again server-side, inside the Ruby
callback, **before any task proc is called**. If this gate fails, execution is
blocked regardless of what the client sent. The dialog cannot override it.

This is defence-in-depth: the UI gate is convenience; the server gate is the real lock.

---

## What Athena checks

### Selection requirement
Some tasks require a specific group type to be selected in the model.
```ruby
task[:requires_selection] = "JPods Guideway"
```
Athena checks `model.selection.first` against this.
If the wrong type (or nothing) is selected, the task is blocked with a plain explanation.

### Param bounds
Float params declare `min:` and `max:`. Athena checks every float param against
its declared bounds. Out-of-range values block execution.
```ruby
{ id: "t", type: :float, default: 0.5, min: 0.0, max: 1.0 }
```

### Vehicle ID whitelist
The "Place Vehicle" task accepts a vehicle_id string. Before use, Athena checks
it against `JPods::JPodGuideway.available_vehicles` — the actual list of template
files in `templates/r_stocks/`. An ID not on that list is blocked.
No string injection path exists.

---

## No eval

The Console contains **no eval, no load of user-supplied strings, no exec**.
Every task is a predefined Ruby proc registered at plugin load time in `JPods::TASKS`.
Users select from that list; they cannot add to it or modify it at runtime.
The task proc itself is the only code that runs.

---

## Risk classification

| Level | When to use | Behavior |
|-------|------------|----------|
| `:safe` | Read-only or side-effect-free (list, open dialog, stop animation) | Execute enabled if Athena passes |
| `:caution` | Modifies model geometry but is undoable via Edit → Undo | Yellow strip; Execute enabled if Athena passes |
| `:destructive` | Hard to recover from (erase all guideways) | Red strip; `confirm_text` checkbox must be checked; Execute disabled until checked |

### Rule for new tasks
When adding a task, choose the higher risk level if in doubt.
A `:caution` task that turns out to be safe is merely cautious.
A `:safe` task that turns out to be destructive is a security failure.

---

## Stdout capture

Each task proc runs with `$stdout` redirected to a `StringIO` buffer:

```ruby
old_out = $stdout
$stdout = StringIO.new
begin
  result = task[:run].call(model, params)
rescue => e
  $stdout.puts "ERROR: #{e.message}"
  e.backtrace.first(4).each { |l| $stdout.puts "  #{l}" }
ensure
  captured = $stdout.string
  $stdout  = old_out
end
```

All `puts` output from the task proc (and from any method it calls that uses
`puts`) is captured and returned to the dialog's output pane.
The user sees exactly what they would see in the Ruby Console.
No separate window is needed. Output is not lost.

---

## The 11 tasks (April 2026)

| Category | Task ID | Risk | Requires selection |
|----------|---------|------|--------------------|
| Setup | `reload_plugin` | safe | — |
| Network | `open_editor` | safe | — |
| Network | `build_network` | caution | — |
| Network | `erase_guideways` | destructive | — |
| Vehicles | `list_vehicles` | safe | — |
| Vehicles | `place_vehicle` | caution | "JPods Guideway" |
| Animation | `start_animation` | safe | — |
| Animation | `stop_animation` | safe | — |
| Diagnostic | `cp_monitor` | safe | — |
| Diagnostic | `stop_cp_monitor` | safe | — |
| Diagnostic | `inspect_structure` | safe | "JPods Structure" |
| Diagnostic | `inspect_guideway` | safe | "JPods Guideway" |

---

## How to add a task

In `jpod_console.rb`, append to `JPods::TASKS`:

```ruby
{ id: "my_task",          # unique snake_case
  label: "Human Label",   # shown in sidebar
  category: "Category",   # sidebar group heading
  description: "Plain English explanation — this is what the user reads before executing.",
  risk: :safe,            # :safe | :caution | :destructive
  requires_selection: nil, # or "JPods Guideway", "JPods Structure", etc.
  confirm_text: nil,       # required string for :destructive tasks
  params: [],              # see param schema below
  run: lambda { |model, params|
    # All puts output is captured and shown in the dialog.
    # Return value (String) is appended to output.
    "Done."
  }
}
```

**Param schema:**
```ruby
{ id: "my_param",
  label: "Human label for the field",
  type: :float,      # :float | :string | :select
  default: 0.5,
  min: 0.0,          # float only
  max: 1.0,          # float only
  source: :available_vehicles,  # :select only — populates options list dynamically
  options: []        # :select only — static list (alternative to source:)
}
```

No changes to `console.html` are needed for tasks with no params or standard param types.

---

## Relationship to Athena's other domain

Athena's original domain is physical pod admission (Ed25519 signing, session tokens,
hash verification of Pi filesystem). That work lives in `athena/` scripts and
`readmes/agents/athena.md`.

These two domains share the same principle but operate on different surfaces:
- **Robot admission:** authenticates a physical machine before it joins the network
- **Console guard:** authenticates a user *action* before it touches the model

Both ask the same question: *is this actor permitted to do this thing right now,
given what we know about the current state?*

The implementation is different. The standard is the same.

---

## Open questions for Athena

- Should Athena log blocked events? Where — to a file on `/Volumes/Allie/athena/logs/`?
- Should risk level be configurable (e.g. a "training mode" where all tasks require confirmation)?
- As the task list grows, should Athena have a separate policy file (JSON/YAML) rather than inline `risk:` in the task hash?
- Should destructive tasks require Bill's CarryOn token before executing, not just a checkbox?
