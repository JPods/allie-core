# Crew Summary — 2_parking
**Network:** Two `station_parking` stations (s006, s007) connected directly — no hub, no intermediate stops.
**Purpose:** Simplest same-type twin. Fewer variables than 3+circle. Baseline for parking behavior in an integrated network.
**Allie custodian:** This file is the living cross-run, cross-network comparison record. Allie updates after each run. Crew members add observations here — not in per-run files.

---

## What We Are Watching (Cross-Network Comparison Points)

Each crew member names what they want to track in this network AND compare to future networks (3+circle, linked twins, etc.).

### Bill
_[Post after run — what does the ride feel like as a system? Does it "feel right"?]_

### Claude Code
- **Speed deviation on gw_platform**: 214 occurrences in 230 prior reports. Ratio ~23×. First-frame speed anomaly. Want to see if rebuild under defaults.json changes this.
- **no_geometry on inter-station segs**: 8 occurrences (4 per direction). Want to confirm rebuild under new geometry source clears this.
- **Cascade depth**: 9-slot cascade ran clean in isolated station_parking test. Want to see if it holds under cross-station load (pods arriving from s007 while s006 is mid-cascade).
- **Metrics to carry forward to 3+circle**: `speed_deviation` count per 100 trips; `no_geometry` count per 100 trips; cascade depth max.

### Allie
_No prior 2_parking synthesis in facets — first run under current pipeline. Will populate Nora and Sally facets after this run._

### Noelle
- **Template recognition**: `station_parking` was a FEATURE fault (template not found) in the last build (2026-06-16). Now in `noelle_features.json`. Expect 0 FEATURE faults on rebuild.
- **Segment geometry**: Both `seg_s006_cp1_s007_cp0` and `seg_s007_cp1_s006_cp0` had `no_geometry` in prior runs. Built before `network.json` as single geometry source. Expect rebuild to write pts correctly.
- **Connection count**: 2 CP pairs (`cp_S006_cp0_S007_cp1`, `cp_S006_cp1_S007_cp0`). Expect both to build clean.

### Natalie
- **Routing**: s006 → s007 and s007 → s006 are the only two possible trips. No hub, no routing decision. BFS is trivial. Expect all trips to plan correctly.
- **Speed authorization**: All trips at 8.3 m/s (from defaults.json, not entity attrs). Prior run had 16.6 m/s entity attr — now gone.
- **Trip count per station**: With equal vehicle placement at s006 and s007, expect roughly equal trip counts in each direction.

### Sally
- **Slot cascade**: 9-slot cascade confirmed clean in isolated test. Twin-network question: does a cascade at s006 interfere with a cascade at s007? No shared resources between stations — expect no interference.
- **Originating chain**: Should dispatch correctly to both stations.
- **ps count**: s006 and s007 each have 9 slots. Expect fills to ps9 before overflow behavior.

### Nora
- **Heading kinks**: Prior 2_thru_dip experience showed heading kinks at `gw_cp_out_lead → gw_cp_out` (2-pt chord on exit segment). Expect same at s006 and s007.
- **Z continuity**: Both stations at similar terrain Z. Inter-station segment is flat. Expect no severe Z jumps.
- **Speed on gw_platform**: 197 m/s effective speed on platform — known first-frame anomaly. Not a geometry defect. Record but do not treat as new finding.

### Alice
_Not activated. No record._

---

## Run Log

| Run | Date | Build clean? | Verdict distribution | Notes |
|-----|------|-------------|---------------------|-------|
| Prior runs (stale) | 2026-06-14/15/18 | No (FEATURE faults + old geometry) | 205 minor, 10 deviated, 13 authorized, 2 gap_no_geo | Pre-defaults.json, pre-template validation |
| Run 1 | TBD | ? | ? | First run under current pipeline |

---

## Cross-Network Comparisons (Updated after each new network)

_Allie fills this section as more networks run. Format: metric — 2_parking value — next_network value — delta — what it means._

| Metric | 2_parking | 2_thru_dip | 3+circle | Notes |
|--------|-----------|------------|---------|-------|
| speed_deviation / 100 trips | TBD | TBD | TBD | |
| no_geometry / 100 trips | TBD (expect 0 post-rebuild) | TBD | TBD | |
| cascade depth max | 9 (isolated); TBD (integrated) | N/A | TBD | |
| Noelle fault count on build | TBD (expect 0) | TBD | TBD | |
| Natalie routing misses | TBD | TBD | TBD | |

---

## Open Questions (Cross-Network)

1. **Platform speed anomaly** — does the first-frame speed spike appear in all station types or only station_parking? Compare to 2_thru_dip and station_line_end.
2. **Cascade under cross-station load** — isolated cascade was clean. Does simultaneous activity at both stations change anything?
3. **no_geometry rate** — if rebuild clears it, was this purely a build-era issue? Track across all networks to confirm.
4. **Natalie ETA accuracy** — without speed profiles, Natalie's timing model is flat 8.3 m/s. How far off is planned vs. actual duration on each track type?
