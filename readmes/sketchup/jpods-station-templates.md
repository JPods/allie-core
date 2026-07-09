# JPods Station Templates

**Covers:** How to author lines.json, the eps[] rules, and the complete topology reference
for every station template in `su_jpods/templates/track_formations/`.

**Who reads this:** Anyone building a new template model, anyone debugging a station topology,
Natalie (trip planning), Nora (ezone boundaries and travel distance), Alice (fare calculation).

---

## Contents

1. [What lines.json Declares](#what-linesjson-declares)
2. [Authoring Rules](#authoring-rules)
3. [Lines JSON Build Tool](#lines-json-build-tool)
4. [station_line_end](#station_line_end)
5. [JPods_station_parking](#jpods_station_parking)
6. [station_thru_dip](#station_thru_dip)
7. [traffic_circle7 — Ring Topology](#traffic_circle7--ring-topology)
8. [Quick Reference](#quick-reference)

---

## Division of Authority

Before touching any template file, understand who owns what:

| Owner | What they own | Enforcement |
|-------|--------------|-------------|
| **Model designer** | `eps[]` — the topological contract of the station | `eps_header` signs the contract; `run_from_template` is blocked once eps_header exists |
| **build_from_eps tool** | Geometry — fills start_point/end_point from model scan, preserves eps_header | The only legitimate tool for updating a signed lines.json |
| **Noelle** | Reports topology defects; refuses to route through unsigned templates | Fault issued if eps_header or eps[] is absent; eps[] never modified |
| **BUILD** | World-transforms local lines.json coords into map.json/path.json per network instance | Never touches lines.json; reads it as pre-built template topology |

**map.json and path.json are always per-network, never per-template.** lines.json (local coords + topology) is the template-level pre-build. BUILD reads it, applies the instance world transform, and emits world-coordinate network files. Adding a template-level map.json would duplicate lines.json at a different coordinate level with no benefit.

---

## What lines.json Declares

A station template's `lines.json` is the **math declaration** — the authoritative record of:

1. **eps_header** — who approved the topology, when, and from which source
2. **eps[]** — the topological contract: which segments connect to which, and the junction type
3. **lines{}** — geometry: each segment's start_point, end_point, and length_mm

You write #2 and sign with #1. The Lines JSON Build tool fills in #3 from the model geometry.
Once signed, lines.json is the authority. `run_from_template` is blocked. Only `build_from_eps`
may update geometry while preserving the signed eps.

**lines.json is not a SketchUp concept.** The same segment names and topology appear in:
- SketchUp tags on guideway edges
- trip.json (Natalie's route sequences)
- Nora's ezone boundaries and encoder distance tracking
- Alice's fare calculation (sums length_mm across the trip path)
- MeshMobility station throughput and capacity

A topology error in lines.json is not a software bug — it is a description of a physical
layout that cannot work. The vehicle that fails to route in SketchUp stalls or derails on
the physical track for the same reason.

---

## Authoring Rules

### Junction Types

| Type | in count | out count | Meaning |
|------|----------|-----------|---------|
| `1-1` | 1 | 1 | Pass-through — no routing choice |
| `diverge` | 1 | 2 | Branch — vehicle routed to one of two segments |
| `merge` | 2 | 1 | Combine — two segments feed one |
| `open` | 0 | 1 | Source — segment originates here (CP in stub, no upstream) |
| `open` | 1 | 0 | Terminal — segment ends here (parking stub, lift, no downstream) |

Any other combination is a topology error.

### Rule 1 — Every Segment Appears in Exactly Two EPs (or One for Terminals)

Each gw_* segment has two ends. Each end is a junction. A normal segment appears in:
- The EP where it is in `out[]` — the junction it departs from
- The EP where it is in `in[]` — the junction it arrives at

Terminal stubs appear in only one EP (the diverge or open where they are an `out`).
Source stubs appear in only one EP (the open where they are an `out` with empty `in`).

The tool derives `segment.in`, `segment.out`, and `segment.eps` from this automatically:
```
Segment appears in ep.out → segment.in  = that ep's in[]
Segment appears in ep.in  → segment.out = that ep's out[]
segment.eps = [EP_where_it_is_out, EP_where_it_is_in]
```

### Rule 2 — Every Diverge and Merge Requires Distinct Segment Names

A segment name cannot appear as both `in` and `out` at the same EP. A diverge is a
physical switch — two different guideway arms depart from it. They must have two
different names.

**The gw_near_main lesson (2026-05-30):**

Wrong — self-referential:
```json
{ "id": 7, "type": "diverge",
  "in": ["gw_near_main"],
  "out": ["gw_near_main", "gw_platform_in"] }
```

Correct — split at the switch:
```json
{ "id": 7, "type": "diverge",
  "in": ["gw_near_main_1"],
  "out": ["gw_near_main_2", "gw_platform_in"] }
```
`gw_near_main_1` = east segment (CP0 → diverge junction).
`gw_near_main_2` = west segment (diverge junction → CP1).

### Rule 3 — EPs Are Numbered CCW from the Top View, Starting at CP0 Out

Start at the out-lead of CP0 (or the first segment vehicles encounter entering from CP0).
Number EPs following the circuit counterclockwise. This makes the EP table readable as a
tour of the station layout.

### Rule 4 — Uturns Are Always Math, Never Scanner

The scanner measures the chord between arc endpoints (~25172.5mm). The correct arc length
is π × 1750mm = **5497.8mm**. The Lines JSON Build tool overrides this automatically for
any segment whose name contains `uturn`. Uturn endpoints are derived from neighboring
segment geometry (junction points), not the arc chord the scanner would report.

---

## Lines JSON Build Tool

**Console:** `Models › Lines JSON Build` — runs immediately on click, no Execute button.

**Prerequisite:** Open a template model from `su_jpods/templates/track_formations/`.
Write `lines.json` with an `eps[]` array before running.

**What it does:**
1. Reads `eps[]` from the existing `lines.json`
2. Scans `gw_*` tagged geometry in the model for segment coordinates
3. Derives `segment.in`, `segment.out`, `segment.eps` from your eps topology
4. Overrides uturn `length_mm` with π×1750=5497.8mm
5. Derives uturn endpoints from neighboring segments (junction geometry, not chord)
6. Backs up the old `lines.json`, writes the new one

**The tool is disabled** when the front-most model is not inside the `su_jpods` folder.

**Checklist before running:**
- [ ] Every junction is declared in eps[]
- [ ] Every segment name in eps[] matches a `gw_*` tag in the model
- [ ] No segment name appears as both `in` and `out` at the same EP
- [ ] Every merge has exactly 2 in `in[]`, 1 in `out[]`
- [ ] Every diverge has exactly 1 in `in[]`, 2 in `out[]`
- [ ] Terminal stubs appear in only one EP as `out`
- [ ] Source stubs appear in only one EP as `out` with empty `in`
- [ ] `eps_header` added to lines.json with approved_by, dt, and note after verification

---

## station_line_end

**Template:** `track_formations/station_line_end`
**Status:** Math declaration complete 2026-05-30. Awaiting network test.

A terminus station with one CP (CP0). Vehicles arrive from the network, process through
CP0, and either park at the lift or circulate through the platform loop and return to CP0.

### CCW Flow

```
far_ramp_out ──EP1──► cp_out_lead_0 ──EP2──► cp_out_0 (park, EP3)
                                         └──► uturn_0 ──────────────────────┐
                                                                             ▼
                  EP4 (source) ──► cp_in_0 ──────────────────────────► EP5 merge
                                                                             │
                                                                      cp_in_lead_0
                                                                             │
                                                                        EP6 diverge
                                                              ┌──────────────┴──────────────┐
                                                           lift_in                     platform_in
                                                              │                              │
                                                           EP7 1-1                      EP10 1-1
                                                              │                              │
                                                        lift_parking                 platform_parking
                                                              │                              │
                                                           EP8 1-1                      EP11 1-1
                                                              │                              │
                                                            lift                        platform
                                                          (EP9 end)                         │
                                                                                        EP12 1-1
                                                                                            │
                                                                                         uturn_1
                                                                                            │
                                                                                        EP13 1-1
                                                                                            │
                                                                                         far_main
                                                                                            │
                                                                                        EP14 1-1
                                                                                            │
                                                                                      far_ramp_out
```

### CP0 Geometry

| Lane | Y (mm) | Z (mm) |
|------|--------|--------|
| Out (south) | −4615.1 | 8201.9 |
| In (north) | −1115.1 | 8201.9 |

- Y-separation: 3500mm → radius = 1750mm → uturn arc = **5497.8mm**
- CP stub elevation: Z = 8201.9mm (250mm above ramp tops at Z = 7951.9)
- Station level: Z = 5951.9mm

### EP Table

| EP | Type | In | Out | Notes |
|----|------|----|-----|-------|
| 1 | 1-1 | gw_far_ramp_out | gw_cp_out_lead_0 | Station entry |
| 2 | diverge | gw_cp_out_lead_0 | gw_cp_out_0, gw_uturn_0 | Park or bypass |
| 3 | open | gw_cp_out_0 | — | Out stub terminus |
| 4 | open | — | gw_cp_in_0 | In stub source |
| 5 | merge | gw_cp_in_0, gw_uturn_0 | gw_cp_in_lead_0 | CP0 merge |
| 6 | diverge | gw_cp_in_lead_0 | gw_lift_in, gw_platform_in | Lift or platform |
| 7 | 1-1 | gw_lift_in | gw_lift_parking | Lift entry |
| 8 | 1-1 | gw_lift_parking | gw_lift | Lift |
| 9 | open | gw_lift | — | Lift terminus |
| 10 | 1-1 | gw_platform_in | gw_platform_parking | Platform entry |
| 11 | 1-1 | gw_platform_parking | gw_platform | Platform |
| 12 | 1-1 | gw_platform | gw_uturn_1 | Platform exit → far-end uturn |
| 13 | 1-1 | gw_uturn_1 | gw_far_main | Uturn → return lane |
| 14 | 1-1 | gw_far_main | gw_far_ramp_out | Return lane → ramp up |

### Segment Dimensions

| Segment | Length (mm) | Z | Notes |
|---------|------------|---|-------|
| gw_cp_out_lead_0 | 2500.0 | 8201.9 | CP lead — out lane |
| gw_cp_out_0 | 2500.0 | 8201.9 | CP parking stub |
| gw_uturn_0 | 5497.8 | 8201.9 | π×1750 |
| gw_cp_in_0 | 2500.0 | 8201.9 | CP return stub |
| gw_cp_in_lead_0 | 2500.0 | 8201.9 | CP lead — in lane |
| gw_lift_in | 20810.7 | 5951.9→7951.9 | Ramp + lateral to lift |
| gw_lift_parking | 6265.2 | 5951.9 | Lift parking |
| gw_lift | 6124.3 | 5951.9 | Lift terminus |
| gw_platform_in | 20358.9 | 5951.9→7951.9 | Ramp down to platform |
| gw_platform_parking | 12986.6 | 5951.9 | Platform parking |
| gw_platform | 7682.9 | 5951.9 | Platform proper |
| gw_uturn_1 | 5497.8 | 5951.9 | π×1750 |
| gw_far_main | 20442.3 | 5951.9 | Return south lane |
| gw_far_ramp_out | 20358.9 | 5951.9→7951.9 | Ramp up to CP level |

### Known Model Issues

| Issue | Detail |
|-------|--------|
| 4 scanner model_errors | ep3, ep8, ep9, ep13 — geometry gaps and uturn chord confusion; topology correct |
| Uturn chord | Scanner reports 25172.5mm; override with 5497.8mm |

---

## JPods_station_parking

**Template:** `track_formations/JPods_station_parking`
**Status:** Math declaration complete 2026-05-30. Awaiting network test.

A through-station with two CPs. Vehicles enter from either end, process through the CP,
and either park at the lift (permanent terminus), loop through the platform, or bypass
on the near_main and exit at the other CP.

### CCW Flow

```
far_main ──EP1──► cp_out_lead_0 ──EP2──► cp_out_0 (park)
(east)                               └──► uturn_0 ──────────────────────────────────┐
                                                                                     ▼
                    EP3 (source) ──► cp_in_0 ──────────────────────────────────► EP4 merge
                                                                                     │
                                                                             cp_in_lead_0
                                                                                     │
                                                                                EP5 diverge
                                                                   ┌─────────────────┴──────────────┐
                                                               near_main                      platform_in1
                                                            (west to CP1)                          │
                                                                   │                           EP6 diverge
                                                                   │                    ┌──────────┴──────────┐
                                                                   │                 lift_in            platform_in2
                                                                   │                    │                     │
                                                                   │                 EP7 1-1              EP9 1-1
                                                                   │                    │                     │
                                                                   │              lift_parking            platform
                                                                   │                    │                     │
                                                                   │                 EP8 1-1             EP10 1-1
                                                                   │                    │                     │
                                                                   │                  lift            platform_out1
                                                                   │                 (end)                    │
                                                                   │                                     EP11 1-1
                                                                   │                                          │
                                                                   │                                   platform_out2
                                                                   │                                          │
                                                                   └──────────────────────────────► EP12 merge
                                                                                                          │
                                                                                                  cp_out_lead_1
                                                                                                          │
                                                                                                     EP13 diverge
                                                                                              ┌──────────┴──────────┐
                                                                                           cp_out_1              uturn_1
                                                                                            (park)                   │
                                                                                                               EP15 merge ◄── cp_in_1 (EP14)
                                                                                                                    │
                                                                                                            cp_in_lead_1
                                                                                                                    │
                                                                                                               EP16 1-1
                                                                                                                    │
                                                                                                            far_main (east)
```

### CP Layout

| CP | Side | X range (mm) | Out lane Y (mm) | In lane Y (mm) | Z (mm) |
|----|------|-------------|-----------------|----------------|--------|
| CP0 | East (+x) | 39945–44945 | −8039.3 | −4539.3 | 5456.4 |
| CP1 | West (−x) | −23618 to −28618 | −4539.3 | −8039.3 | 5456.4 |

- Y-separation: 3500mm → radius = 1750mm → uturn arc = **5497.8mm**
- CP stub elevation: Z = 5456.4mm (250mm above main track Z = 5206.4)
- CP0 and CP1 lanes are crossed — CP0 out on far/south lane, CP1 out on near/north lane

### EP Table

| EP | Type | In | Out | Notes |
|----|------|----|-----|-------|
| 1 | 1-1 | gw_far_main | gw_cp_out_lead_0 | CP0 station entry from east |
| 2 | diverge | gw_cp_out_lead_0 | gw_cp_out_0, gw_uturn_0 | CP0 park or bypass |
| 3 | open | — | gw_cp_in_0 | CP0 in stub source |
| 4 | merge | gw_cp_in_0, gw_uturn_0 | gw_cp_in_lead_0 | CP0 merge |
| 5 | diverge | gw_cp_in_lead_0 | gw_near_main, gw_platform_in1 | CP0 bypass or platform |
| 6 | diverge | gw_platform_in1 | gw_lift_in, gw_platform_in2 | Lift or platform loop |
| 7 | 1-1 | gw_lift_in | gw_lift_parking | Lift entry |
| 8 | 1-1 | gw_lift_parking | gw_lift | Lift |
| 9 | 1-1 | gw_platform_in2 | gw_platform | Platform entry |
| 10 | 1-1 | gw_platform | gw_platform_out1 | Platform exit step 1 |
| 11 | 1-1 | gw_platform_out1 | gw_platform_out2 | Platform exit step 2 |
| 12 | merge | gw_platform_out2, gw_near_main | gw_cp_out_lead_1 | Platform + bypass → CP1 |
| 13 | diverge | gw_cp_out_lead_1 | gw_cp_out_1, gw_uturn_1 | CP1 park or bypass |
| 14 | open | — | gw_cp_in_1 | CP1 in stub source |
| 15 | merge | gw_cp_in_1, gw_uturn_1 | gw_cp_in_lead_1 | CP1 merge |
| 16 | 1-1 | gw_cp_in_lead_1 | gw_far_main | CP1 exit to east mainline |

### Segment Dimensions

| Segment | Length (mm) | Y (mm) | Z (mm) | Notes |
|---------|------------|--------|--------|-------|
| gw_far_main | 63563.6 | −8039.3 | 5206.4 | South mainline |
| gw_cp_out_lead_0 | 2500.0 | −8039.3 | 5456.4 | CP0 out lead |
| gw_cp_out_0 | 2500.0 | −8039.3 | 5456.4 | CP0 parking stub |
| gw_uturn_0 | 5497.8 | — | 5456.4 | π×1750 |
| gw_cp_in_0 | 2500.0 | −4539.3 | 5456.4 | CP0 return stub |
| gw_cp_in_lead_0 | 2500.0 | −4539.3 | 5456.4 | CP0 in lead |
| gw_near_main | 63563.6 | −4539.3 | 5206.4 | North mainline |
| gw_platform_in1 | 10129.9 | — | 5206.4 | Diverge arm to platform/lift junction |
| gw_lift_in | 7908.8 | — | 5206.4 | Arm to lift |
| gw_lift_parking | 1351.4 | — | 4956→5456 | Vertical elevator segment |
| gw_lift | 6022.8 | — | 5206.4 | Lift terminus |
| gw_platform_in2 | 10129.9 | — | 5206.4 | Arm to platform |
| gw_platform | 23864.6 | −1039.3 | 5206.4 | Platform proper |
| gw_platform_out1 | 10129.9 | — | 5206.4 | Platform exit step 1 |
| gw_platform_out2 | 10129.9 | — | 5206.4 | Platform exit step 2 |
| gw_cp_out_lead_1 | 2500.0 | −4539.3 | 5456.4 | CP1 out lead |
| gw_cp_out_1 | 2500.0 | −4539.3 | 5456.4 | CP1 parking stub |
| gw_uturn_1 | 5497.8 | — | 5456.4 | π×1750 |
| gw_cp_in_1 | 2500.0 | −8039.3 | 5456.4 | CP1 return stub |
| gw_cp_in_lead_1 | 2500.0 | −8039.3 | 5456.4 | CP1 in lead |

### Known Model Issues

| Issue | Detail |
|-------|--------|
| Lift geometry gap | gw_lift_in end to gw_lift_parking start ≈ 10127mm apart — model geometry needs repair; topology correct |
| gw_lift_parking | Vertical segment: Z changes 4956.4→5456.4 (500mm vertical travel) |
| CP Z step | CP stubs 250mm above mainline — scanner sees junction gap at Z transition |

---

## station_thru_dip

**Template:** `track_formations/station_thru_dip`
**Status:** Math declaration complete 2026-05-30. Awaiting network test.

A through-station with two CPs. The platform **dips** below the main track level —
vehicles descend from the mainline (Z ≈ 8136mm) to the platform (Z ≈ 5976mm) and
climb back up. The lift takes vehicles to a building at platform level.

**near_main is split** into `gw_near_main_1` (east, CP0→platform junction) and
`gw_near_main_2` (west, platform junction→CP1) at EP7. A single gw_near_main would
be self-referential at the diverge — the split is structurally required.

### CCW Flow

```
far_main ──EP1──► cp_out_lead_0 ──EP2──► cp_out_0 (park)
(east)                               └──► uturn_0 ──────────────────────────────────┐
                                                                                     ▼
                    EP3 ──► cp_in_0 ──────────────────────────────────────────► EP4 merge
                                                                                     │
                                                                             cp_in_lead_0
                                                                                     │
                                                                                EP5 diverge
                                                                   ┌─────────────────┴──────────┐
                                                               near_main_1                   lift_in
                                                                   │                             │
                                                               EP7 diverge                   EP6 1-1
                                                     ┌─────────────┴─────────────┐               │
                                                near_main_2                platform_in           lift
                                                     │                          │              (end)
                                                  EP11 merge                EP8 1-1
                                                     ▲                          │
                                                     │                   platform_parking
                                                     │                          │
                                                     │                       EP9 1-1
                                                     │                          │
                                                     │                      platform
                                                     │                          │
                                                     │                      EP10 1-1
                                                     │                          │
                                                     └──────────────── platform_out
                                                                               │
                                                                       cp_out_lead_1
                                                                               │
                                                                          EP12 diverge
                                                                 ┌─────────────┴────────────┐
                                                              cp_out_1                   uturn_1
                                                               (park)                       │
                                                                                  EP14 merge ◄── cp_in_1 (EP13)
                                                                                       │
                                                                               cp_in_lead_1
                                                                                       │
                                                                                   EP15 1-1
                                                                                       │
                                                                                far_main (east)
```

### CP Layout

| CP | Side | X range (mm) | Out lane Y (mm) | In lane Y (mm) | Z (mm) |
|----|------|-------------|-----------------|----------------|--------|
| CP0 | East (+x) | 40661–45661 | −8038.8 | −4538.8 | 8385.9 |
| CP1 | West (−x) | −22902 to −27902 | −4538.8 | −8038.8 | 8385.9 |

- Y-separation: 3500mm → radius = 1750mm → uturn arc = **5497.8mm**
- CP stub elevation: Z = 8385.9mm (250mm above main track Z = 8135.9)
- Platform level: Z = 5975.9mm (2160mm below main track — the dip)
- CP0 and CP1 lanes are crossed (see JPods_station_parking for the pattern)

### EP Table

| EP | Type | In | Out | Notes |
|----|------|----|-----|-------|
| 1 | 1-1 | gw_far_main | gw_cp_out_lead_0 | CP0 start of stub pair |
| 2 | diverge | gw_cp_out_lead_0 | gw_cp_out_0, gw_uturn_0 | CP0 park or bypass |
| 3 | open | — | gw_cp_in_0 | CP0 in stub source |
| 4 | merge | gw_cp_in_0, gw_uturn_0 | gw_cp_in_lead_0 | CP0 merge |
| 5 | diverge | gw_cp_in_lead_0 | gw_near_main_1, gw_lift_in | CP0 bypass or lift |
| 6 | 1-1 | gw_lift_in | gw_lift | Lift entry |
| 7 | diverge | gw_near_main_1 | gw_near_main_2, gw_platform_in | Platform diverge |
| 8 | 1-1 | gw_platform_in | gw_platform_parking | Platform entry (dip) |
| 9 | 1-1 | gw_platform_parking | gw_platform | Platform |
| 10 | 1-1 | gw_platform | gw_platform_out | Platform exit |
| 11 | merge | gw_platform_out, gw_near_main_2 | gw_cp_out_lead_1 | Platform + bypass → CP1 |
| 12 | diverge | gw_cp_out_lead_1 | gw_cp_out_1, gw_uturn_1 | CP1 park or bypass |
| 13 | open | — | gw_cp_in_1 | CP1 in stub source |
| 14 | merge | gw_cp_in_1, gw_uturn_1 | gw_cp_in_lead_1 | CP1 merge |
| 15 | 1-1 | gw_cp_in_lead_1 | gw_far_main | CP1 to far_main |

### Segment Dimensions

| Segment | Length (mm) | Z | Notes |
|---------|------------|---|-------|
| gw_far_main | 63563.6 | 8135.9 | South mainline |
| gw_cp_out_lead_0 | 2500.0 | 8385.9 | CP0 out lead |
| gw_cp_out_0 | 2500.0 | 8385.9 | CP0 parking stub |
| gw_uturn_0 | 5497.8 | 8385.9 | π×1750 |
| gw_cp_in_0 | 2500.0 | 8385.9 | CP0 return stub |
| gw_cp_in_lead_0 | 2500.0 | 8385.9 | CP0 in lead |
| gw_near_main_1 | 6680.5 | 8135.9 | Near main east (CP0 → platform junction) |
| gw_lift_in | 23563.8 | 8135.9→5975.9 | Ramp + lateral to lift |
| gw_lift | 14350.6 | 5975.9 | Lift terminus |
| gw_near_main_2 | 56883.1 | 8135.9 | Near main west (platform junction → CP1) |
| gw_platform_in | 15981.0 | 8135.9→5975.9 | Dip ramp to platform |
| gw_platform_parking | 14350.6 | 5975.9 | Platform parking |
| gw_platform | 11243.7 | 5975.9 | Platform proper |
| gw_platform_out | 19027.3 | 5975.9→8135.9 | Climb ramp from platform to CP1 |
| gw_cp_out_lead_1 | 2500.0 | 8385.9 | CP1 out lead |
| gw_cp_out_1 | 2500.0 | 8385.9 | CP1 parking stub |
| gw_uturn_1 | 5497.8 | 8385.9 | π×1750 |
| gw_cp_in_1 | 2500.0 | 8385.9 | CP1 return stub |
| gw_cp_in_lead_1 | 2500.0 | 8385.9 | CP1 in lead |

### Known Model Issues

| Issue | Detail |
|-------|--------|
| 6 scanner model_errors | ep1/ep2/ep11/ep12/ep16/ep17 — geometry junction gaps and vector_in direction issues; topology correct |
| near_main split | gw_near_main split into _1 and _2 at EP7 — scanner without this split would produce self-referential diverge |

---

## traffic_circle7 — Ring Topology

**Template:** `track_formations/traffic_circle7`
**Status:** Math declaration complete 2026-05-29. Awaiting network test.

**This is a different topology class from the linear stations above.**
There is no mainline, no platform dip, no near/far lane pair. The ring is a continuous
CCW loop. CPs are spaced around the ring at four compass points.

### Ring Flow

The ring runs **CCW** (counterclockwise when viewed from above).

All ring arc segments are drawn **start→end in the CW direction** in SketchUp.
Vehicles travel **end→start** on every ring arc — opposite to the drawn direction.

| Arc | Drawn direction | Vehicle direction | Position |
|-----|----------------|-------------------|----------|
| gw_c_0_0 | South | North | East side (long) |
| gw_c_0_1 | SE | NW | NE corner |
| gw_c_1_1 | East | West | North arc (long) |
| gw_c_1_2 | NE | SW | NW corner |
| gw_c_2_2 | North | South | West side (long) |
| gw_c_2_3 | NW | SE | SW corner |
| gw_c_3_3 | West | East | South arc (long) |
| gw_c_3_0 | SW | NE | SE corner |

CCW vehicle sequence: `c_0_0 → c_0_1 → c_1_1 → c_1_2 → c_2_2 → c_2_3 → c_3_3 → c_3_0 → c_0_0`

### CP Positions

| CP | Side | Approximate coord (mm) |
|----|------|------------------------|
| CP0 | East (+x) | x ≈ 13323 |
| CP1 | North (+y) | y ≈ 26076 |
| CP2 | West (−x) | x ≈ −13440 |
| CP3 | South (−y) | y ≈ −688 |

### Per-CP EP Pattern (6 EPs per CP, 24 total)

Each CP uses this sequence: **diverge → 1-1 → open → open → 1-1 → merge**

| EP offset | Type | In | Out |
|-----------|------|----|-----|
| +0 | diverge | prev corner arc | [out arm, long arc] |
| +1 | 1-1 | out arm | cp_out stub |
| +2 | open | cp_out stub | — |
| +3 | open | — | cp_in stub |
| +4 | 1-1 | cp_in stub | in arm |
| +5 | merge | [long arc, in arm] | next corner arc |

EP numbering: CP0 = EPs 1–6, CP1 = EPs 7–12, CP2 = EPs 13–18, CP3 = EPs 19–24.

### Corner Arc Connectivity

Corner arcs carry both the merge inputs and the diverge outputs (they sit between those two junctions):
```
gw_c_0_1.in  = [gw_c_0_0, gw_0_in]   ← from EP6 merge
gw_c_0_1.out = [gw_1_out, gw_c_1_1]  ← from EP7 diverge
```
Long arcs carry one predecessor and one successor on the main ring path:
```
gw_c_0_0.in  = [gw_c_3_0]   gw_c_0_0.out = [gw_c_0_1]
```

### Segment Dimensions

| Type | Count | Length (mm) | Z (mm) |
|------|-------|-------------|--------|
| Long ring arcs | 4 | 11011.3 | 8289.6 |
| Corner ring arcs | 4 | 1000.0 | 8289.6 |
| Approach arms (in and out) | 8 | 8583.2 | 8289.6 |
| CP stubs (in and out) | 8 | 2500.0 | 8539.6 |

### Why the Scanner Always Fails Here

Corner arcs are 1000mm — shorter than `PROX_TOL_MM` (1500mm). The scanner merges adjacent
junction endpoints into one cluster and the topology cascade breaks on every scan. Author
lines.json from geometry math only. Never overwrite with scan output for this template.

---

## Quick Reference

### Standard Dimensions

| Parameter | Value | Notes |
|-----------|-------|-------|
| Uturn centerline radius | 1750mm | (outer 2000 + inner 1500) / 2 |
| Uturn arc length | **5497.8mm** | π × 1750 |
| Uturn span (chord) | 3500mm | 2 × 1750 |
| CP guideway separation | 3500mm | Y distance between out and in centerlines |
| CP lead length | 2500mm | gw_cp_out_lead, gw_cp_in_lead |
| CP stub length | 2500mm | gw_cp_out, gw_cp_in |
| CP stub elevation | main Z + 250mm | e.g. 5206.4 → 5456.4 |

### Template Status

| Template | CPs | EPs | Segments | Status |
|----------|-----|-----|----------|--------|
| cps | 1 | — | — | Clean math declaration |
| cpu | 1 | — | — | Clean math declaration |
| station_line_end | 1 | 14 | 14 | Math declaration complete 2026-05-30 |
| JPods_station_parking | 2 | 16 | 20 | Math declaration complete 2026-05-30 |
| station_thru_dip | 2 | 15 | 19 | Math declaration complete 2026-05-30 |
| traffic_circle7 | 4 | 24 | 20 | Math declaration complete 2026-05-29 |

All templates: network test pending.

### See Also

- `jpods-path-geometry.md` — arc math, straight segment math, Bezier for inter-station connections
- `jpods-connection-point-rule.md` — CP color standard (red=inbound, blue=outbound)
- `readmes/agents/noelle.md` — Noelle's validation rules and feature.json schema
