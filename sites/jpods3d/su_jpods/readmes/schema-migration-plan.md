# JPods Schema Migration Plan
**Date:** 2026-06-15
**Status:** Approved — execution sequence begins at Step 1

---

## Why This Exists

The CW traffic circle bug (2026-06-15) revealed the core problem: `generate_map_json`
derived routing from `followme.json` geometry (CW scan result) instead of from
`lines.json` pass_chains (CCW declaration). Two documents claimed routing authority —
the wrong one won. The fix required reading pass_chains explicitly. The deeper fix is
this plan: one source of truth at each layer, no geometry scan ever produces routing data.

---

## Terminology

| Term | Definition |
|------|-----------|
| **model** | Single su_jpods formation file (.skp + JSONs) — one station |
| **network** | Multi-station deployment, multiple models connected |
| **lines.json** | Template definition — `su_jpods/templates/track_formations/{name}/` |
| **model.json** | Generated for single-station .skp (replaces map.json) |
| **network.json** | Generated for multi-station .skp (same schema as model.json) |

model.json and network.json share identical 5-section schema. A model is a network
of one. Different filenames, same structure, different content.

---

## Agents and Their Authorities

| Agent | Subject to | Owns | Queries |
|-------|-----------|------|---------|
| **Noelle** | lines.json rules | model.json / network.json | — |
| **Natalie** | network.json routing_graph | animation.json | Sally slot state |
| **Sally** | lines.json parking_slots | animation.json sally section | Natalie (activation) |
| **Nora** | animation.json dispatch | trip.json (consumes) | — |
| **Alice** | WebClerk / HTML Travel | ticket.json | Natalie |

Natalie is **subject to** network.json (it constrains her routing graph) and **owns**
animation.json (she writes it, she controls dispatch state).

---

## File Map (Target State)

### Template folder
`su_jpods/templates/track_formations/{name}/`
```
lines.json        ← model definition, 5 sections (never changes at runtime)
geometry.json     ← local-coord track pts (absorbed into lines.json.designer long-term)
cp.json           ← local-coord CPs (absorbed into lines.json.designer long-term)
model.skp         ← the formation's SketchUp source model
```

### Single-station .skp folder
```
{name}.skp
{name}.model.json       ← replaces map.json; Noelle writes at Build
{name}.animation.json   ← Natalie owns; vehicle states, trips, Sally slot states
{name}.log.json         ← append-only retrospection; all agents write
trips/
  {trip_id}.json        ← per-Nora dispatch object (Natalie writes, Nora consumes)
tickets/
  {ticket_id}.json      ← Alice→Natalie handoff
```

### Multi-station .skp folder
```
{name}.skp
{name}.network.json     ← same schema as model.json; multiple stations + connections
{name}.animation.json
{name}.log.json
trips/
tickets/
```

---

## lines.json Schema (5 sections)

Lives in the template folder. Never written at runtime. One file per formation type.

```json
{
  "schema_version": "5.0",
  "formation": "traffic_circle7",

  "designer": {
    "tracks": {},
    "cps": [],
    "parking_slots": [],
    "geometry_local": {}
  },

  "noelle": {
    "required_tracks": [],
    "validation_rules": {}
  },

  "natalie": {
    "pass_chains": {},
    "speed_limits": {},
    "headway_rules": {}
  },

  "nora": {
    "state_machine": {
      "states": ["idle","dispatched","in_transit","arriving","dwell","departing","parked"]
    },
    "arc_radii": {},
    "physical_limits": {}
  },

  "deployment": {
    "adjacency_constraints": [],
    "clearance_notes": ""
  }
}
```

**lines.json is model-limited.** It defines what is permanently true about this
formation type. It cannot know how many vehicles are in the network, what state they
are in, or what the world coordinates are. All of that belongs in model.json /
network.json and animation.json.

---

## model.json / network.json Schema (5 sections)

Written by Noelle at Build. Authoritative for world-coordinate structure and routing.
`beam_paths` lives here — not only as SketchUp entity attributes. Entity attributes
are invisible to animation.json; network.json is not.

**Step 2 validated against:** 2_thru_dip (2 stations, station_thru_dip template),
2_line_end, 2_parking, 3+circle (4 stations, traffic_circle7 + station_thru_dip).
All data currently in map.json maps cleanly to this schema — nothing is lost.

```json
{
  "schema_version": "1.0",
  "mode": "model | network",
  "build_state": "partial | complete",

  "summary": {
    "templates_used": [
      {
        "template": "traffic_circle7",
        "count": 1,
        "instance_ids": ["s001"],
        "rules": {}
      }
    ],
    "station_count": 1,
    "connection_count": 0
  },

  "designer": {
    "stations": [
      {
        "id": "s001",
        "template": "traffic_circle7",
        "build_state": "built | unbuilt",

        "transform": {
          "translation_mm": { "x": 0.0, "y": 0.0, "z": 0.0 },
          "rotation_deg": 0.0
        },

        "cps": [
          {
            "index": 0,
            "center_mm": { "x": 0.0, "y": 0.0, "z": 0.0 },
            "tangent": { "x": 1.0, "y": 0.0, "z": 0.0 },
            "half_offset_mm": 500.0
          }
        ],

        "tracks": {
          "gw_cp_in_0": {
            "direction": "inbound",
            "length_mm": 8583.2,
            "grade_pct": 0.0,
            "speedMin": 50,
            "speedMax": 2000,
            "pts": [
              { "x": 0.0, "y": 0.0, "z": 0.0 },
              { "x": 100.0, "y": 0.0, "z": 0.0 }
            ],
            "successors": ["s001.gw_cp_in_lead_0"],
            "predecessors": []
          }
        },

        "beam_paths": {
          "gw_uturn_0": {
            "pts": [ { "x": 0.0, "y": 0.0, "z": 0.0 } ],
            "source": "build_math"
          }
        },

        "platform_capacity": 1,
        "dwell_time_s": 30,
        "cargo_direction": "bidirectional",
        "parking_slots": [],
        "platforms": [
          {
            "id": "s001.P1",
            "structure_id": "s001",
            "platform_index": 1,
            "connection_id": "gw_platform",
            "parking_slots": 3,
            "spawn_t": 0.12,
            "length_m": 7.68,
            "midpoint_m": { "x_m": 0.0, "y_m": 0.0, "z_m": 0.0 },
            "start_m": { "x_m": 0.0, "y_m": 0.0, "z_m": 0.0 },
            "end_m":   { "x_m": 0.0, "y_m": 0.0, "z_m": 0.0 }
          }
        ],
        "deviations": []
      }
    ],

    "connections": [
      {
        "id": "seg_s001_cp0_s002_cp0",
        "from": { "station": "s001", "cp_index": 0 },
        "to":   { "station": "s002", "cp_index": 0 },
        "direction": "outbound",
        "length_mm": 140271.0,
        "grade_pct": 1.688,
        "speedMin": 500,
        "speedMax": 13900,
        "pts": [ { "x": 0.0, "y": 0.0, "z": 0.0 } ]
      }
    ]
  },

  "noelle": {
    "validation_state": "valid | partial | faulted",
    "faults": [],
    "formation_registry": { "s001": "traffic_circle7" }
  },

  "natalie": {
    "routing_graph": {
      "s001.gw_cp_in_0":      ["s001.gw_cp_in_lead_0"],
      "s001.gw_cp_in_lead_0": ["s001.gw_near_main_1", "s001.gw_lift_in"]
    },
    "routes": {}
  },

  "nora": {},

  "deployment": {
    "model_id": "",
    "built_at": "",
    "geolocation": null,
    "ezones": [],
    "metadata": {
      "bbox": {}
    }
  }
}
```

### Field Notes (Step 2 decisions)

**`designer.stations[].transform`** — `translation_mm` is the world-coordinate center
of the formation (replaces `center_mm` in map.json). `rotation_deg` is yaw only
(JPods stations are always upright — one degree of freedom in placement).

**`designer.stations[].tracks[role]`** — keyed by role name (not numeric id).
`direction` is `inbound | outbound | internal`. `pts` are world coordinates;
2 pts for chord (unbuilt or straight); N pts for arc after beam_path upgrade.
`successors` and `predecessors` use qualified names (`station_id.role`).
Dropped from map.json: numeric `id`, `nominal_time_s` (derived), `segments[]`
(derived), `markers[]` (always empty), `dx`/`dy`/`dz` (derived from pts[0]→pts[1]).

**`designer.stations[].platforms[]`** — platform records written at Build time by
`generate_network_json` via `StructureTool.detect_platform_guideways_on_structure`.
Each entry: `id` (e.g. "s001.P1"), `structure_id`, `platform_index`, `connection_id`
(tag name, e.g. "gw_platform"), `parking_slots` (from entity attribute or length formula),
`spawn_t` (0.12 = spawn near track start), `length_m`, `midpoint_m`, `start_m`, `end_m`
(all in meters, world space). `load_followme_platforms` reads from here first; falls back
to followme.json for models not yet rebuilt. This eliminates followme.json as a second
source of truth for vehicle placement. (Added 2026-06-17.)

**`designer.stations[].beam_paths[role]`** — dense arc pts written at Build time.
`source: "build_math"` means generated from lines.json arc_radii.
`source: "build_scan"` means extracted from SketchUp geometry.
Authoritative source for arc tracks — animator reads here first.

**`designer.connections[]`** — inter-station guideways. Replaces `seg_*` entries
embedded in map.json `lines`. Same pts/grade/speed structure as intra-station tracks.

**`natalie.routing_graph`** — fully-qualified successor graph for the whole network.
`station_id.role → [station_id.role]`. This is what generate_network_json writes
from pass_chains + connection stubs. Natalie reads this for BFS routing; she does
not re-scan followme.json or geometry.

**`deployment.geolocation`** — null until the model is geolocated. Carries lat/lng
bounds from the SketchUp geolocation when set.

**Dropped from map.json** (not carried forward):
- `followme_hash` — model.json is the authority; hash is redundant
- `dead_end_nodes` — derivable from routing_graph (nodes with no successors)
- `network_summary` — derivable from summary + designer at read time
- `su_jpods_feature` — same as `template`; one key is sufficient
- Numeric track `id` — role name within station is the identity

**Partial build is not a fault.** `build_state: "partial"` means some stations are
built and some are not — the normal state during design. Unbuilt stations have
`build_state: "unbuilt"` and empty `tracks` / `beam_paths`. Noelle reports missing
tracks as informational, not blocking, until the user requests animation.

**Source hierarchy for arc geometry (TFTS 2026-05-27, 2026-06-15):**
`beam_paths in model.json` > math synthesis > BLOCK.
beam_paths are written here at Build time. The animator reads from model.json first.
SketchUp entity attributes are a secondary cache, not the authority.

---

## animation.json Schema (Natalie owns)

Written by Natalie at Build (initialization) and on every state transition at runtime.

```json
{
  "schema_version": "1.0",
  "write_mode": "verbose | normal | minimal",

  "natalie": {
    "active_dispatches": {},
    "pending_tickets": []
  },

  "vehicles": [
    {
      "id": "NORA_0001",
      "state": "in_transit",
      "current_track": "s001.gw_c_0_1",
      "position_t": 0.45,
      "trip_id": "",
      "headway_reservation": {}
    }
  ],

  "sally": {
    "active": false,
    "cycle_s": 4.0,
    "last_activity_at": null,
    "slot_states": {}
  }
}
```

**Nora state machine:** `idle → dispatched → in_transit → arriving → dwell → departing → parked`

---

## animation.json Write Triggers

**Write on** (state transitions — infrequent):
- Natalie dispatches a Nora (trip_id assigned)
- Any Nora state transition
- Sally changes any slot state
- Any fault event
- Session start (initialize) and session end (flush)

**Keep in memory only** (too frequent to write):
- Interpolated position within a segment (every animation frame)
- Per-frame speed and headway calculations
- Sally's in-progress slot availability check

**Rationale:** State transitions happen at most ~1/second per vehicle at normal speed.
Position interpolation runs at 60fps. Writing position to disk on every frame blocks
the Ruby main thread and kills the SU renderer. Transitions are the meaningful events;
position between transitions is derived and reconstructable.

**Write mode** — controlled by `write_mode` in animation.json itself:
- `verbose`: every Nora telemetry tick — use when debugging faults
- `normal`: state transitions only — default
- `minimal`: trip complete and faults only — use when stable

**Retrospection:** log.json records write count per session. If writes/minute > 30,
flag high-activity mode. Review at session end whether write_mode should change.
Start at `normal`. Raise to `verbose` when a fault repeats. Lower to `minimal`
when a route runs clean for 3+ consecutive sessions.

---

## Sally's Cycle Rate

Sally runs independently. Natalie activates her by setting `animation.json.sally.active = true`
before any dispatch that terminates at a parking station.

**Cycle rate — adaptive:**
- **4 seconds** when no vehicle has interacted with Sally's station in the last 30 seconds
- **Scales toward 1 second** as recent activity increases (linear: last activity 0s ago = 1s cycle)
- Returns to 4 seconds after 30 seconds of inactivity

`cycle_s` in animation.json.sally reflects the current rate. Sally updates it herself.

In SU (animation mode): Sally runs on a Ruby timer at the current `cycle_s` interval.
On Pi (physical mode): Sally runs as a process on the station chip at the same interval.
Same logical behavior, different transport.

**Sally's two arrays:**
1. `vehicles[]` — vehicles currently interacting with her station (approaching, docked, departing)
2. `slot_states{}` — parking slot occupancy (available / reserved / occupied)

Sally reads vehicles from animation.json. She owns slot_states. Natalie reads slot_states
before any dispatch to a terminal station. Natalie does not write Sally's section.

---

## Build Button Sequence

```
User clicks Build
  1. Noelle: validate model, write model.json / network.json (all 5 sections)
             beam_paths written per-track in designer section
  2. Natalie: read routing_graph from model.json, initialize animation.json
              (empty vehicles[], sally.active=false, write_mode=normal)
  3. log.json: append build_complete event
```

Noelle goes first. Natalie needs the routing_graph from model.json before she
can initialize animation.json. If Noelle and Natalie produce conflicting data,
write a TFTS — iterate until resolved. network.json is the authority.

---

## Trip and Ticket Objects

### trip.json (per-Nora, per-trip)
```json
{
  "trip_id": "",
  "nora_id": "NORA_0001",
  "ticket_id": "",
  "route": [],
  "authorized_speed_ms": 8.3,
  "headway_reservation": { "track": "", "reserved_until": "" },
  "slot_assignment": { "station_id": "", "slot_id": "" },
  "state": "",
  "created_at": "",
  "departed_at": null,
  "arrived_at": null
}
```

### ticket.json (Alice→Natalie handoff)
```json
{
  "ticket_id": "",
  "origin_cp": { "station": "", "cp_index": 0 },
  "destination_cp": { "station": "", "cp_index": 0 },
  "passenger_count": 1,
  "cargo_type": null,
  "priority": "normal",
  "requested_departure_window": "",
  "source": "alice_api | html_travel_button",
  "status": "pending | dispatched | complete | cancelled"
}
```

`cargo_type` is reserved null. No schema break required when cargo is implemented.

---

## Migration Approach

Big-bang: make the changes, fix what breaks.

**One exception:** keep `map.json` as a read fallback in the animator until
model.json passes validation on 2+ of the 4 test models. This is not backward-compat
timidity — it preserves the visual test feedback loop. Without animation working,
nothing else is testable. After 2 models pass, remove the map.json read path.

---

## 4 Test Models (Standalone Validation)

Run Steps 1–7 against all 4 models before applying to any multi-station network.
Each exercises a different part of the schema.

| Model | Path | Tests |
|-------|------|-------|
| `station_thru_dip` | `…/templates/track_formations/station_thru_dip/model.skp` | Straight-through routing, no arcs |
| `station_line_end` | `…/templates/track_formations/station_line_end/model.skp` | Terminal station, U-turn arc, Sally parking |
| `traffic_circle7` | `…/templates/track_formations/traffic_circle7/model.skp` | Ring arcs, CCW enforcement, multi-CP routing |
| `station_parking` | `…/templates/track_formations/station_parking/model.skp` | parking_slots, Sally slot management |

All 4 must pass before network-level work begins.

---

## Execution Sequence

| Step | What | Validates against |
|------|------|-------------------|
| 1 | Finalize lines.json schema (5 sections) — schema only, no code | All 4 models by inspection |
| 2 | Define model.json / network.json schema — schema only | Same |
| 3 | `generate_network_json` replaces `generate_map_json`; Noelle writes model.json | model.json written on Build; **map.json fallback kept** in animator |
| 4 | Animator reads model.json; passes on 2+ models → remove map.json fallback | Animation works from model.json |
| 5 | animation.json + Natalie dispatch protocol | Dispatch logged; state transitions written |
| 6 | Sally slot management — adaptive cycle, two arrays | Parking activated by Natalie query |
| 7 | ticket.json from Alice (WebClerk API + HTML Travel button) | Full request→dispatch→complete loop |

**TFTS for every step.** Allie harvests. Build Understanding candidates from each arc.
Each step is independently testable. Steps 1–4 are structural. Steps 5–7 are behavioral.

---

## Cargo

Deferred. Lift stations not yet implemented. `ticket.json` reserves `cargo_type: null`.
No schema break required when cargo is implemented (lift stations, cargo-only slots,
continuous waste routing).

---

## Open Items Deferred to Later

- Physical equivalence: animation.json schema maps to MQTT message format (same logical
  object, two transports). Formal mapping deferred until animation.json is stable.
- Noelle load balancing data (segment occupancy, queue depths, weather/price factors).
- Alice Small-Stings integration with log.json feedback loop.
- 5X5 standard performance targets vs. actuals in deployment section.
