# Sally Sequencer — Station Vehicle Routing

**Created:** 2026-06-01  
**Updated:** 2026-06-02  
**Status:** Design — ready to implement  
**Domain:** SU (simulation) → Physical (MQTT)

---

## The Problem

Natalie currently plans full routes including intra-station tracks. She has no visibility
into live track occupancy inside a station. If the platform is full when a pod arrives,
there is no place to hold — the pod would stack at the CP gate and block all other traffic.

## The Solution

**Sally owns every track inside her station.** Natalie routes between stations. Sally
sequences pods within her station, one track at a time, and holds pods in a `hold_loop`
when the platform is not ready.

---

## Authority Boundary

Sally's authority begins the moment Nora crosses `gw_cp_in_*`.

```
Natalie domain           Sally domain                    Natalie domain
──────────────    ──────────────────────────────────    ──────────────
seg_A_cp0  ──→  [ gw_cp_in_N                      ] ──→  seg_B_cp0
                [ gw_cp_in_lead_N                  ]
                [ ... intra-station tracks ...      ]
                [ gw_cp_out_lead_M  (exit side)    ]
                [ gw_cp_out_M                      ]
                       ↑
                Sally sequences, one track per tick.
                Sally decides: hold_loop or landing chain.
                Sally signals Natalie on exit.
```

**Natalie's contribution at handoff:**  
Before assigning Nora's trip, Natalie writes one field to the trip state:
```
pod_type: "landing" | "pass_through"
arrival_cp: 0 | 1
```
Sally reads these at CP entry. All subsequent decisions are Sally's.

---

## The hold_loop

When the platform is full and a pod arrives at `gw_cp_in_*`, Sally routes the pod
onto the `hold_loop` — a continuous outer ring that keeps the pod moving without
occupying platform tracks and without blocking the CP gate.

### hold_loop is derived from discovered_chains.CCW — not separately authored

Each lines.json already contains `discovered_chains.CCW` — an ordered array of every
track in CCW traversal order, starting from `gw_cp_out_lead_0`. This is the complete
topology ring. The hold_loop outer ring is **derived at runtime** by filtering CCW:

**Filter rule — remove tracks matching any of:**
- `gw_cp_out_\d+` — CP stub dead-ends (exactly digit suffix; `gw_cp_out_lead_*` is kept)
- `gw_cp_in_\d+` — CP stub dead-ends (same rule)
- `gw_platform.*` — platform branch tracks
- `gw_lift.*` — lift branch tracks

What remains after filtering is the outer ring — the hold_loop.

**Why derive instead of author?**  
The template designer authors CCW once. If CCW is correct, hold_loop is correct
automatically. No second source of truth. No desync.

### hold_loop outer rings by template (derived)

| Template | hold_loop tracks |
|----------|-----------------|
| `station_thru_dip` | cp_out_lead_0, uturn_0, cp_in_lead_0, near_main_1, near_main_2, cp_out_lead_1, uturn_1, cp_in_lead_1, far_main |
| `station_parking` | cp_out_lead_0, uturn_0, cp_in_lead_0, near_main, cp_out_lead_1, uturn_1, cp_in_lead_1, far_main |
| `station_line_end` | cp_out_lead_0, uturn_0, cp_in_lead_0, uturn_1, far_main, far_ramp_out |
| `cpu` / `cps` | no hold_loop — component only |
| `traffic_circle7` | no hold_loop — uses pass_chains |

**hold_loop detection:** a station supports hold_loop if any track in its CCW contains
`gw_uturn`. No u-turn tracks → no hold_loop → Natalie diversion is required.

### Entry and promotion points

**`entry_from_cpN`** — the track where a pod arriving at CPN first joins the outer ring.
For all current templates this is `gw_cp_in_lead_N`: the pod arrives at `gw_cp_in_N`,
advances to `gw_cp_in_lead_N`, and is now on the outer ring.

**Promotion check** — at every tick, when a pod in hold_loop is at `gw_cp_in_lead_N`
(the same entry track), Sally checks: is a platform slot available? If yes → promote to
`landing.in_cpN`. The promotion point is always the entry point — no special tracking
needed.

### Templates with hold_loop support

| Template | CPs | hold_loop | Note |
|----------|-----|-----------|------|
| `station_thru_dip` | 2 | yes | far_main shared with pass-through pods |
| `station_parking` | 2 | yes | |
| `station_line_end` | 1 | yes | far_ramp_out closes the ring back to CP0 |
| `cpu` / `cps` | 1–2 | no | component only — no platform tracks |
| `traffic_circle7` | 2+ | no | uses pass_chains instead |

Templates without hold_loop support require Natalie diversion (see §Fallback below).

---

## Sally Sequencer — State Machine

### Pod states

```
ARRIVING     — pod is on seg_, approaching CP gate (Natalie's domain)
IN_HOLD_LOOP — pod is on hold_loop tracks, platform full
IN_LANDING   — pod is on landing_chain tracks, heading to platform
ON_PLATFORM  — pod is parked at a platform slot
IN_EXIT      — pod is on exit_chain tracks, heading to CP stub
```

### State transitions

```
ARRIVING ──→ IN_HOLD_LOOP   (platform full at CP arrival)
ARRIVING ──→ IN_LANDING     (platform has slot at CP arrival)

IN_HOLD_LOOP ──→ IN_LANDING (platform slot opens; pod at promotion point)
IN_HOLD_LOOP ──→ IN_HOLD_LOOP (loop wraps; platform still full)

IN_LANDING ──→ ON_PLATFORM  (pod reaches gw_platform)
ON_PLATFORM ──→ IN_EXIT     (departure assigned by Natalie)
IN_EXIT ──→ ARRIVING        (pod clears gw_cp_out_* — Natalie takes over)
```

### Per-pod state structure

```ruby
{
  nora_id:      "NORA_0003",
  station_id:   "S004",
  state:        :in_hold_loop,   # :in_hold_loop | :in_landing | :on_platform | :in_exit
  arrival_cp:   1,               # which CP the pod entered
  pod_type:     :landing,        # :landing | :pass_through
  chain:        [...],           # current track list (hold_loop or landing chain)
  chain_index:  3,               # current position in chain
  current_track: "gw_near_main_2"
}
```

### Tick logic (SU simulation)

Called every animation tick for each station:

```ruby
def self.tick(station_id)
  st = @@stations[station_id]
  return unless st

  st[:pods].each do |nora_id, pod|
    case pod[:state]
    when :in_hold_loop
      # Check for platform slot at promotion point
      if pod[:current_track] == promotion_track(station_id, pod[:arrival_cp])
        slot = reserve_slot(station_id, nora_id)
        if slot
          # Transition to landing chain — start from the promotion track
          pod[:state]   = :in_landing
          pod[:chain]   = landing_chain(station_id, pod[:arrival_cp])
          pod[:chain_index] = 0
          puts "[Sally #{station_id}] #{nora_id} promoted from hold_loop to landing.in_cp#{pod[:arrival_cp]} — slot #{slot}"
        else
          # Platform still full — advance loop (wraps automatically)
          advance_one_track(pod)
        end
      else
        advance_one_track(pod)
      end
    when :in_landing
      advance_one_track(pod)
      if pod[:chain_index] >= pod[:chain].size
        pod[:state] = :on_platform
        puts "[Sally #{station_id}] #{nora_id} on platform"
      end
    when :in_exit
      advance_one_track(pod)
      if pod[:chain_index] >= pod[:chain].size
        # Pod has cleared gw_cp_out_* — signal Natalie
        pod[:state] = :cleared
        notify_natalie_exit(station_id, nora_id, pod)
      end
    end
  end
end
```

### In physical (MQTT)

Each track advance is one MQTT publish from Sally to Nora:

```
Topic:   S004/track_clear/NORA_0003
Payload: { "next_track": "gw_near_main_2", "switches": {...} }
```

Nora subscribes to `{station_id}/track_clear/{pod_id}`. She moves only when Sally
publishes. No polling.

Sally subscribes to `{station_id}/pod_entered/{pod_id}` to detect CP arrival. Natalie
publishes to this topic when she assigns the last inter-station seg.

---

## Fallback: Natalie Diversion

When a station has no `hold_loop` declared in lines.json, Sally cannot hold the pod
internally. She signals Natalie:

```
Sally → Natalie: { event: "divert", station_id: "S004", nora_id: "NORA_0003",
                   reason: "platform_full_no_hold_loop" }
```

Natalie re-routes Nora to the nearest station with platform capacity, then back.
This is a more expensive operation and only applies to minimal pass-through stations
without u-turn geometry.

**Not implemented in Phase 1.** Phase 1 covers only templates with hold_loop.

---

## Console Command: Hold Loop Test

A new command in the **Models** category of JPods Console:

**Label:** `Hold Loop`  
**Step:** (none — diagnostic tool, not part of student workflow)  
**Category:** `Models`

### Behavior

1. User clicks "Hold Loop" in the console
2. Console shows a picker: select station, select arrival CP (0 or 1)
3. A vehicle is placed at `gw_cp_in_N` of the selected station (same placement as Station Platform Demo)
4. Sally is initialised for that station from lines.json
5. The vehicle enters `IN_HOLD_LOOP` state — platform intentionally reported as full for the first N loops
6. After N loops (configurable, default 3), Sally "opens" the platform slot → vehicle transitions to landing chain → parks

This lets the developer verify:
- hold_loop track geometry renders correctly
- Loop wraps cleanly (no position jump)
- Promotion fires at the right track
- Landing chain executes without error after promotion

### Parameters (console UI)

```json
{ "station_id": "S004", "arrival_cp": 1, "hold_loops": 3 }
```

`hold_loops`: number of full loops to complete before Sally grants platform access.
Default 3. Set to 0 to skip hold and go directly to landing.

---

## lines.json Changes

**No changes required.** The hold_loop is derived from `discovered_chains.CCW` at
`Sally.init_sequencer` time. No new keys are needed in lines.json.

The `discovered_chains.CCW` array is already the complete and correct topology ring
for each template. Sally's filter (remove stubs + platform + lift) produces the
hold_loop outer ring without any additional authoring.

**Note on `gw_far_main` and pass-through pods (station_thru_dip):**  
The hold_loop for station_thru_dip includes `gw_far_main` — the same track
pass-through pods need. Sally's track occupancy table gates both. A pass-through pod
arriving at CP1 while `gw_far_main` is held by a hold_loop pod must wait one track
advance (typically < 1 tic). Acceptable in simulation. In physical, MQTT track_clear
signals naturally prevent simultaneous occupation.

---

## Implementation Sequence

| Step | What | File |
|------|------|------|
| 1 | Add `Sally.init_sequencer` — derives hold_loop from `discovered_chains.CCW`; builds per-station state | jpod_sally.rb |
| 2 | Add `Sally.pod_arrived_at_cp` — entry point; decides hold_loop or landing based on platform state | jpod_sally.rb |
| 3 | Add `Sally.tick` — advances pods one track per call; handles loop wrap + promotion check | jpod_sally.rb |
| 4 | Hook `Sally.tick` into animation loop after each Nora position update | jpod_animator.rb |
| 5 | Add "Hold Loop" console task (Models category) | jpod_console.rb |
| 6 | Add `JPodGuideway.station_hold_loop_demo` — places vehicle at CP gate, starts hold_loop | jpod_vehicle_runtime.rb |

**No lines.json changes required.**

---

## Non-Negotiable Rules for Sally

1. **Sally does not move a pod to the next track unless it has confirmed the track is clear.**
   In SU: check `@@active_tracks[station_id][track_name]`. In physical: wait for track_clear MQTT.

2. **Sally never routes a pod to `gw_platform` directly.** All platform access goes
   through `reserve_slot`. If `reserve_slot` returns nil, the pod stays on hold_loop.

3. **Natalie declares pod_type before Nora enters Sally's territory.** Sally reads it;
   she does not derive it. If pod_type is missing, Sally defaults to `:landing` and logs a warning.

4. **hold_loop tracks are read from lines.json at `init_sequencer` time.** Never hardcoded
   in Ruby. The template author owns the loop geometry.

5. **On animation stop, `Sally.reset` clears all sequencer state.** No orphaned pod
   state survives across animation runs.
