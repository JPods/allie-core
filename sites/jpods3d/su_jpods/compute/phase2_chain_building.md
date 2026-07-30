# Phase 2: Chain Building

## Purpose

Derive all Natalie chains from the designer topology. The designer declares
tracks and successors. Natalie computes the chains by walking the successor
graph. No hand-authored chains.

## Algorithm

### Input

- `designer.tracks` — Hash of `{ tag → { successors: [...] } }`
- `designer.cps` — Array of EP definitions with in/out tracks
- CP indices derived from `gw_cp_in_N` / `gw_cp_out_N` tag names

### Successor Graph

Build a directed graph: `tag → [successor_tags]`

```
gw_cp_in_0 → [gw_cp_in_lead_0]
gw_cp_in_lead_0 → [gw_platform_in, gw_lift_in]
gw_platform_in → [gw_platform_parking]
gw_platform_parking → [gw_platform]
gw_platform → [gw_uturn_1]
gw_uturn_1 → [gw_far_main]
...
```

### Chain Types

#### Landing Chain (one per CP)

- **Start:** `gw_cp_in_N`
- **End:** `gw_platform`
- **Method:** BFS through successor graph
- **Result:** ordered track list from CP stub to platform

```
in_cp0: [gw_cp_in_0, gw_cp_in_lead_0, gw_platform_in, gw_platform_parking, gw_platform]
```

#### Exit Chain (one per CP)

- **Start:** `gw_platform`
- **End:** `gw_cp_out_N`
- **Method:** BFS through successor graph
- **Result:** ordered track list from platform to CP stub

```
out_cp0: [gw_platform, gw_uturn_1, gw_far_main, gw_far_main_2, gw_cp_out_lead_0, gw_cp_out_0]
```

#### Originating Chain (one per CP)

- Same tracks as exit chain
- `clip_start: true` — trims gw_platform to the pod's current slot position
- Used when pod departs from a parking slot (not from platform entry)

#### Parking Chain

- Always `[gw_platform]`
- Slot 1 = entry end, slot N = exit end

#### Hold Loop Chain

- **Start:** `gw_platform`
- **End:** `gw_platform_parking` (then appends `gw_platform` to close the loop)
- **Method:** BFS through successor graph, avoiding `gw_cp_out_*` (stay inside station)

```
loop: [gw_platform, gw_uturn_1, gw_far_main, ..., gw_platform_parking, gw_platform]
```

#### Pass Chains (traffic circles only)

- For each CP pair (N, M): BFS from `gw_cp_in_N` → ring CCW → `gw_cp_out_M`
- 16 chains for a 4-CP circle (including self-loops N→N that traverse full ring)
- Ring direction enforced: only follow CCW successors on `gw_c_*` tracks

### Switch Detection

At diverge EPs, the BFS path determines which successor the switch selects:

```json
{
  "ep_id": 7,
  "at_track": "gw_c_0_1",
  "setting": "gw_out_1"
}
```

The diverge EP has `in: [gw_c_0_1]` and `out: [gw_c_1_1, gw_out_1]`. If the
chain takes `gw_out_1`, the switch at EP 7 is set to `gw_out_1`.

### Failure Handling

If BFS can't find a path from start to end:

```
[Natalie] ⚠ could not build landing chain for cp0:
   BFS from gw_cp_in_0 cannot reach gw_platform.
   Check successors: gw_cp_in_lead_0 → [gw_platform_in] — is gw_platform_in declared?
```

The designer fixes the topology. Natalie does not guess.

## Output

Written into `template_data['natalie']`:
- `landing_chains` — Hash of `{ in_cpN → { tracks: [...], switches: [...] } }`
- `exit_chains` — Hash of `{ out_cpN → { tracks: [...], switches: [...] } }`
- `originating_chains` — Hash of `{ out_cpN → { tracks: [...], clip_start: true } }`
- `parking_chain` — `{ tracks: [gw_platform] }`
- `hold_loop_chain` — `{ loop: [...], from_platform: [], to_platform: [] }`
- `pass_chains` (circles) — Hash of `{ from_cpN_to_cpM → { tracks: [...], switches: [...] } }`
