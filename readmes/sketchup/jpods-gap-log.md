# JPods SketchUp Plugin — Gap Cause Log

This is a living record of every gap pattern observed in the JPods SketchUp plugin,
what caused it, and what fixed it.  Allie maintains this file.  When Bill reports
a gap or Check Gaps finds a problem, log it here.

---

## How to use this file

When Bill reports a gap or the Ruby Console shows a gap warning:

1. Copy the console output here under a new entry.
2. Identify the cause from the patterns below.
3. Record the fix applied.
4. If a new pattern, add it to the Pattern Reference section.

---

## Pattern Reference

### P1 — Endpoint not reaching a structure CP (red circle)
**Symptom:** `Check Gaps` places a red circle at a beam endpoint.  
**Cause:** The beam_path endpoint is > 2 m from the nearest structure CP.  
Common sub-causes:
- Wrong stub index in the JSON (`"stub": 1` instead of `"stub": 0`)
- CP position shifted after a Recompute — old beam built before Recompute, not rebuilt after
- `via_markers` list ends near the structure but not at the CP — last marker too far from stub

**Fix:** Correct the JSON stub index or add/remove a via_marker near the structure, then rebuild.

---

### P2 — Bezier jump at segment 0 or last segment (orange circle)
**Symptom:** Console shows `jump NNN m at segment 0` or `at segment N` where N is near the sample count.  
**Cause:** Fixed-n Bezier sampling produced steps longer than `FOLLOWME_MAX_JUMP` (100 m).  
This happens when the chord is long (> 300 m) and n was hardcoded at 16 — segment 0 and
segment n-1 each carry ~chord/3 of the full handle length in a single step.  
**Fix applied (2026-04-19):** `tangent_curve_pts` now uses adaptive n = `max(16, ceil(chord / 20 m))`.  
After the fix, rebuild. If jumps persist, the chord is > 5 km — investigate whether
two structures are accidentally placed very far apart, or via_markers are missing for
a long run.

---

### P3 — Collapsed path (orange circle at bounding box centre)
**Symptom:** Console shows `beam_path collapsed to N pt(s)` for a guideway.  
**Cause:** All consecutive points in the stored beam_path are within 0.5 m of each other
(the draw_beam deduplication threshold).  The entire guideway is effectively zero-length.  
Common sub-causes:
- Two CPs that are nearly coincident (station placed on top of another)
- PathBuilder returned a single point (terrain raycast failure on all points)
- via_markers all stacked at one location

**Fix:** Check the CP positions with CP Labels button.  If two structures overlap, move one.
If terrain snap is the cause, check for a sandbox mesh in the model.

---

### P4 — Stacked guideways (visual doubling, not a Check Gaps flag)
**Symptom:** Guideways appear doubled/thickened; no gap marker, but model is heavy.  
**Cause:** Build was clicked twice without clearing.  
**Fix applied (2026-04-19):** Build now purges all `"JPods Guideway"` and `"JPods Columns"`
groups before rebuilding.  This should no longer occur.  If it does, check that the user
is not using Option+Build (add mode) unintentionally.

---

### P5 — CP labels stacking (text accumulating on repeated Build)
**Symptom:** CP label text appears multiple times at the same location; getting thicker/bolder.  
**Cause:** `add_text` was called on every Build without clearing previous labels.  
**Fix applied (2026-04-19):** `StructurePlacer.refresh_cp_labels(model)` is called after
every Build — it erases all `.CP` text entities and re-adds from stored attributes.

---

## Session Log

### 2026-04-29

**Reported by:** Bill — "all the stations CP0 end have the CP offset. We are not calculating the CP the same for both ends."  
**Pattern:** P-CP — CP position/tangent asymmetric across gates (CP0 wrong, CP1 correct consistently)  
**Root cause:** Two bugs in `detect_cps_from_stub_pair_tags`:
1. `out_dir = cross_v.cross(Z)` — sign depended on entity scan order; inverted for one gate.
2. `BEAM_WIDTH/2` cross-track shift applied after `gate_ctr = midpoint(outer_pt_a, outer_pt_b)` — midpoint is already correct, shift moved CP off-center.  
**Fix applied:** `out_dir` now averages the two stubs' own tangents (each `(outer_pt−inner_pt).normalize`). Cross-track shift removed entirely.  
**Regression guard:** See `readmes/sketchup/jpods-cp-regression-guard.md` for full diagnostic checks and corrective action table.  
**Status:** Fixed. Rebuild + Recompute CPs required.

**Reported by:** Ruby Console output after Check Gaps on LazyE model  
**Console output:**
```
⚠️  JPods followme gap: guideway [seg_171555] jump 146.6 m at segment 0
⚠️  JPods followme gap: guideway [seg_171555] jump 185.0 m at segment 15
⚠️  JPods followme gap: guideway [seg_171555] jump 187.7 m at segment 0
⚠️  JPods followme gap: guideway [seg_171555] jump 145.4 m at segment 15
JPods continuity check: 0 endpoint gap(s), 4 followme gap(s), 16 endpoint(s) scanned.
```
**Pattern:** P2 — Bezier jump at segment 0 and segment 15 (n=16 fixed sampling, long chord)  
**Root cause:** `seg_171555` is a long run (estimated 2–3 km chord).  With n=16, each Bezier
step near the endpoints is ~150–185 m — far above the 100 m flag threshold.  
**Fix applied:** Made Bezier n adaptive in `tangent_curve_pts` (`jpod_network.rb`):
`n = max(16, ceil(chord / 20 m))`. Same fix applied to preview sampling in
`jpod_network_editor.rb`.  
**Status:** Fixed. Rebuild required.
