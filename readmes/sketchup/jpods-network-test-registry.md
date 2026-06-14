# JPods Network Test Registry

**Purpose:** Record which SketchUp test networks have been proven — animation runs
correctly, pods complete inter-station trips, no stuck pods, no routing failures,
no spurious FAULT files.

"Proven" means: loaded model → Build → Populate → Animate → sustained operation
with pods cycling between stations. Visual inspection confirmed. Not a proof of
formation geometry correctness (that is Noelle's job at Build time).

---

## 2-Same-Station Networks

Two stations of the same formation type, connected by one inter-station segment pair.
The simplest meaningful topology — proves that a formation round-trips correctly.

| Network | Formation | Stations | Model file | Proven | Date | Notes |
|---------|-----------|----------|-----------|--------|------|-------|
| 2_thru_dip | station_thru_dip | S006, S007 | skp_jpods/2_thru_dip/2_thru_dip.skp | ✓ | 2026-06-14 | Pods cycle s006↔s007; uturn visual artifact at gw_cp_* is animation math artifact, not routing error |
| 2_line_end | station_line_end | S008, S009 | skp_jpods/2_line_end/2_line_end.skp | ✓ | 2026-06-14 | Clean run; pods cycle both directions |
| 2_parking | JPods_station_parking | — | skp_jpods/2_parking/2_parking.skp | ✓ | 2026-06-14 | All three 2-same-station types proven same session |

---

## Multi-Station Networks

Networks with 3+ stations or mixed formation types. Not yet systematically proven.

| Network | Formations | Stations | Proven | Date | Notes |
|---------|-----------|----------|--------|------|-------|
| — | — | — | — | — | — |

---

## What "Proven" Does Not Cover

- Proof geometry scores (ok/severe counts in proof-summary.json) — those compare
  template-relative coordinates against world-space placement and are always offset
- Long-duration operation (hours of animation)
- Edge cases: full platform, no-route, personal space violations under heavy load
- Mixed-formation networks (line_end feeding thru_dip, etc.)

---

## Known System-Wide Behaviors (apply to all proven networks)

| Behavior | Root cause | Status |
|----------|-----------|--------|
| junction gap FAULTs for gw_* transitions | map.json stores physical beam endpoints, not mathematical CPs; animation runs on path.json math | Fixed 2026-06-14 — see TFTS 20260614T191539 |
| Uturn visual artifact at gw_cp_* area | Same coordinate system mismatch — visual only, routing is correct | Suppressed (no false FAULTs); no functional impact |
