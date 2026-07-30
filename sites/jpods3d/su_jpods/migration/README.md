# Migration Runner

Iterates through codearchive → v2 migration, one function at a time.

## Usage

Tell Claude: **"migrate next"**

Claude will:
1. Read `manifest.json` — find the next `ready` item
2. Read the source file from codearchive (understand it)
3. Write the v2 version (clean, no archived dependencies)
4. Test: load both old and new, compare output for same input
5. Update manifest: mark `done`, unblock dependents
6. Remove the codearchive file from boot.rb when all its functions are migrated

## Rules

- **Never edit codearchive files** — only read them
- **One function group per iteration** — small, testable steps
- **Test before marking done** — old output must match new output
- **Update boot.rb** — remove codearchive entry only when ALL functions from that file are migrated
- **Log the migration** — write a TF to process/inbox with what was learned

## Phases

| Phase | Items | Status |
|-------|-------|--------|
| 1. Foundation | ConnectionPoint, my_geom | Ready |
| 2. Path building | PathBuilder, UprightExtruder | Ready |
| 3. Geometry | EntitiesBuilder, Platform, Network.build_segment | Blocked by Phase 2 |
| 4. Validation | Noelle validator, PathJSON export, NoelleBridge | Blocked by Phase 3 |
| 5. UI tools | ConnectTool, NetworkEditor, FollowMe viz | Blocked by Phase 4 |

## Progress

Started: 2026-06-22
Items migrated: 0/14
Codearchive files replaced: 0/13
