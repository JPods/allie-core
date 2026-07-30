# Phase 1: Validation

## Purpose

Read the designer section of lines.json and verify that the topology is
complete and internally consistent. Accept or reject before any geometry
extraction begins.

## What Is Checked

### Required Sections

| Section | Required For | What Must Be Present |
|---------|-------------|---------------------|
| `designer.tracks` | All templates | Hash of gw_ track entries |
| `designer.cps` | All templates | Array of EP definitions |
| `designer.parking_slots` | Platform stations | Slot count (may be 0 for circles) |

### Per-Track Checks

For each `gw_*` entry in `designer.tracks`:

| Check | Failure Message |
|-------|----------------|
| `successors` key exists | `gw_X: missing 'successors' key` |
| Each successor is a declared track | `gw_X: successor 'gw_Y' not declared in designer.tracks` |
| Track is reachable from at least one CP | `gw_X: orphan track — not reachable from any CP` |

### Per-EP Checks

For each entry in `designer.cps`:

| Check | Failure Message |
|-------|----------------|
| `type` is one of: merge, diverge, 1-1, open | `EP N: invalid type 'foo'` |
| `in` tracks are declared | `EP N: in track 'gw_X' not declared` |
| `out` tracks are declared | `EP N: out track 'gw_X' not declared` |

### Connectivity

| Check | Failure Message |
|-------|----------------|
| Every track reachable from a CP via successor walk | `gw_X: unreachable from any CP` |
| No cycles that don't include gw_platform | `gw_X → gw_Y → gw_X: cycle without platform` |

## Output

- **Accept:** returns empty defect list, Compute proceeds to Phase 2
- **Reject:** returns defect list, each with section + track + specific message.
  Compute stops. Designer fixes lines.json.

## What Is NOT Checked

- Geometry (Phase 3's job)
- Chain completeness (Phase 2 will attempt to build and report failures)
- Physical feasibility (arc radii, clearance heights — Noelle's job at Build time)
