# JPods Console — Reload Plugin and Restart Detection

**Button:** "Reload Plugin" in the JPods Console header  
**Callback:** `cmd_reload_plugin` in `jpod_console.rb`  
**Helper methods:** `JPods::Console.snapshot_mtimes`, `changed_restart_files`  
**Restart list:** `JPods::Console::RESTART_REQUIRED_FILES`

---

## What Reload Does

The Reload Plugin button performs a full plugin reload in a single click:

1. Closes the Network Editor if open
2. Resets `$jpods_main_loaded` and `$jpods_booted` load guards
3. Snapshots file modification times for restart-sensitive files
4. Calls `load main.rb` — re-executes all plugin files in dependency order
5. Compares post-reload mtimes against the snapshot (see below)
6. Closes the old console dialog
7. Immediately reopens a fresh console via `JPods::Console.open(Sketchup.active_model)`

The reopened console gets a cache-busted URL (`?v=<timestamp>`), a rebuilt TASKS list, and clean `setup_callbacks` with no accumulated duplicate handlers.

---

## Why Auto-Reopen

After a reload, the old dialog is stale in three ways:

| What changed | Effect on old dialog |
|---|---|
| `console.html` edited | Old dialog runs old JS forever |
| TASKS added or removed | Sidebar shows pre-reload list |
| `setup_callbacks` re-called | Callbacks accumulate on old dialog |

Closing and immediately reopening solves all three. The developer gets a clean slate without a manual reopen step.

---

## Restart Detection

Some changes cannot take effect on reload alone. `main.rb` contains two registration guards that execute only once per SketchUp session:

```ruby
unless $jpods_registered          # menu items, toolbar buttons
  $jpods_registered = true
  ...
end

unless @@jpods_toolbar_registered  # toolbar object creation
  @@jpods_toolbar_registered = true
  ...
end
```

Resetting `$jpods_main_loaded` before reload re-executes the file load loop, but `$jpods_registered` is never reset — so menu and toolbar code does not re-run. Only a fresh SketchUp process clears that guard.

### Detection mechanism

Before calling `load loader`, the reload callback snapshots `File.mtime` for every file in `RESTART_REQUIRED_FILES`. After the reload, it compares. If any file's mtime changed:

```
Plugin reloaded.

The following files were modified and require a SketchUp restart
to take full effect (menu items and toolbar buttons won't update until then):

  • main.rb

Save your work and quit SketchUp now?   [Yes] [No]
```

- **Yes** → `Sketchup.quit` (triggers SketchUp's normal save-changes flow)
- **No** → the reload still applied for all non-guarded code; console closes and reopens normally

### Current restart list

```ruby
RESTART_REQUIRED_FILES = %w[
  main.rb
].freeze
```

`main.rb` is the only current entry because it is the only file containing registration-guarded blocks. The constant is defined with `remove_const` protection so it re-evaluates cleanly on reload.

---

## Adding to the Restart List

Add a filename to `RESTART_REQUIRED_FILES` when a file contains code that:
- Uses a session-level guard (`unless $some_global`, `unless @@some_flag`)
- Registers with SketchUp's extension system in a way that cannot be undone at runtime
- Creates a `UI::Toolbar` object (SketchUp accumulates toolbars — creating a duplicate causes visual artifacts)
- Calls `Sketchup.add_observer` without a corresponding `remove_observer` path

Do **not** add files to the restart list just because they define constants or rebuild data structures — `load` re-executes those fine.

---

## What Does and Does Not Require Restart

| Change | Reload sufficient? | Why |
|---|---|---|
| Any `.rb` logic outside registration guards | Yes | `load` re-executes the file |
| `console.html` / CSS / JS | Yes | Reopen uses cache-busted URL |
| TASKS array entries | Yes | Rebuilt fresh in `cmd_ready` |
| Constants in `jpod_constants.rb` | Yes | `load` reassigns them (with Ruby warning, suppressed by `$VERBOSE = nil`) |
| Menu items in `main.rb` | **No** | Inside `$jpods_registered` block |
| Toolbar buttons in `main.rb` | **No** | Inside `@@jpods_toolbar_registered` block |
| `Sketchup.add_observer` calls | **No** | Observer stays registered; reload would double-register without the guard |
| Extension registration (`Sketchup::Extension`) | **No** | SketchUp caches extension entries per session |

---

## Ruby Console Reload (Developer Shortcut)

For reloading a single file during active development, use the Ruby Console directly — faster than the button, no auto-reopen:

```ruby
load Sketchup.find_support_file('noelle.rb', 'Plugins/su_jpods')
load Sketchup.find_support_file('jpod_trip_planner.rb', 'Plugins/su_jpods')
load Sketchup.find_support_file('jpod_console.rb', 'Plugins/su_jpods')
```

Always use `Sketchup.find_support_file` — never a literal path. The path `Application Support/SketchUp 2026` contains spaces that break backtick-formatted commands when rendered in markdown or pasted from documentation.

The Reload Plugin button is the right tool when multiple files changed or when you want the console HTML refreshed.

---

## The Reload Button as a Signalling Tool

The reload button marks the exact boundary between **editing code** and **testing it**.
That moment is the highest-value point to log because:

- Developer intent is unambiguous (a specific change was just made)
- Context is richest (what changed, and why, is still in working memory)
- The result is seconds away (DNW or TF is about to be known)

This connects the reload button to the FAULT→DNW→TF→TFTS process capture cycle:

```
[edit code]
    ↓
[click Reload Plugin]   ← test boundary crossed
    ↓
[fresh console opens]   ← intent is unambiguous here
    ↓
  → if the fix worked:  write a TF or TFTS to process/inbox/
  → if it didn't:       write a DNW before the next attempt
  → if exploring:       no log needed
```

**Future direction:** After the fresh console opens, the output area can prompt the developer
to classify the reload — "Fixed a fault / Testing a fix / Just reloading" — and write the
appropriate process file automatically. The reload button does not just apply code changes;
it signals a moment of experience that feeds Allie's learning cycle.

**This principle generalizes:** every tool boundary (Route-Time "Run Simulation," Pi pod
start, WebClerk deploy) is the same kind of signal. Reload and run buttons are logging
infrastructure, not just convenience features.

---

## Log Output

All reload events are logged to `jpod_console.log` (plain-text append) and to the SketchUp Ruby Console, regardless of whether the dialog is open:

```
[JPods cmd_reload_plugin] starting full plugin reload
[JPods cmd_reload_plugin] reload complete
[JPods cmd_reload_plugin] restart-required files changed: main.rb
[JPods cmd_reload_plugin] user confirmed — calling Sketchup.quit
```

The log file persists across dialog close/reopen cycles, so no output is lost.
