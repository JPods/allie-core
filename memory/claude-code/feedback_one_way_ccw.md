---
name: One-way travel, CCW circulation — Rule 12
description: All guideways one-way. Station circulation CCW. in/out swaps between CPs by design. Pass chains in lines.json are authoritative. Never infer in/out from geometry.
type: feedback
---

All JPods guideways are one-way. All station circulation is counter-clockwise (CCW). This is Rule 12 in su_jpods/CLAUDE.md.

**Pass chains define the one-way flow (from lines.json):**
- from_cp0_to_cp1: gw_cp_in_0 → gw_cp_in_lead_0 → gw_near_main → gw_cp_out_lead_1 → gw_cp_out_1
- from_cp1_to_cp0: gw_cp_in_1 → gw_cp_in_lead_1 → gw_far_main → gw_cp_out_lead_0 → gw_cp_out_0

**The in/out rail swaps between CPs by design:**
- CP 0: gw_cp_in uses near_main rail, gw_cp_out uses far_main rail
- CP 1: gw_cp_in uses far_main rail, gw_cp_out uses near_main rail
- This is the CCW loop, not a bug. Any code that assumes in_tip is always on the same side will produce 180° rotated tracks at one end.

**Why:** Landing from CP1 requires traversing 3/4 of the CCW loop to reach the platform (on near_main side). This is the designed one-way path — bidirectional tracks do not exist in JPods.

**How to apply:** Never determine in/out from model.bounds.center, bounding boxes, cross products, or coordinate comparisons. The topology in lines.json defines the flow. The physical tip positions must come from the model geometry (cp_marker vertices), and lines.json maps track names to those positions.
