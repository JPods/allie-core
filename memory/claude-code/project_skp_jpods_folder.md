---
name: skp_jpods folder management
description: Plugin-managed project folder system in ~/Documents/skp_jpods/; first-run agreement, open-model check, Finder button, organize.sh
type: project
---

Students scatter JPods files across arbitrary folders. The plugin now guides them to:

    ~/Documents/skp_jpods/<ModelName>/
      <ModelName>.skp
      <ModelName>.followme.json
      <ModelName>.vehicles.json
      <ModelName>.map.json
      trips/
    utilities/
      projects.json     ← registry of all known project paths
      organize.sh       ← last-used move script (inspectable, not /tmp)
    README.md

**Why:** Reproducible student workflow. Files for one project stay together.
Plugin can always find the followme.json without asking.

**How to apply:** Any code that reads or writes project files should go through
`JPods::Project` path helpers. Do not hardcode paths beside .skp; use
`default_json_path(model)`, `default_map_json_path`, etc.

## Agreement flow (two chances, then done)

Preference key: `Sketchup.read_default("JPods", "skp_jpods_setup")`
Values: nil → "offered_once" → "agreed" | "declined"

- **Plugin load** (3 s timer, boot.rb): first offer if nil
- **First Build** (cmd_build, jpod_network_editor.rb): second offer if "offered_once"
- After two NO answers: status = "declined", no more prompts

Declined users still get `utilities/projects.json` updated on every Connect Guideways
commit (via `JPods::Project.note_unmanaged_project`).

## Open-model location check

AppObserver `onOpenModel` → `JPods::Project.check_model_location_deferred(model)`
Fires 1.5 s after open. Skips: unsaved models, models already inside skp_jpods,
status != "agreed".

Dialog: YES = script moves + restart | NO = quit, user moves | CANCEL = keep working.

## Finder button

Network Editor toolbar → `cmd_show_in_finder` → `NetworkEditor.show_in_finder_or_organize`.
Already in skp_jpods: reveals followme.json with `open -R`.
Outside: shows the move dialog.

## Connect Guideways canonical JSON rule

`commit()` uses `default_json_path` unless `saved_json_path` is in the same directory
as the model. Prevents copy-saved models from writing back to the original's followme.json.
First commit creates `<ModelName>.followme.json` beside the .skp automatically.

## Key files

- `jpod_project.rb` — all setup/agreement/registry/path logic
- `jpod_network_editor.rb` — Finder button, organize dialog, launch_organize_script
- `boot.rb` — startup timer, AppObserver hook
- `jpod_connect_tool.rb` — canonical JSON path rule, note_unmanaged_project call
