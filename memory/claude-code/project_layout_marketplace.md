---
name: Layout library — share, credit, check out
description: Users submit detail + list layouts to WC_HQ library for credit; both layout types (detail_layout + workbench_fields); Alice curates; adoption-tracked
type: project
---

Users share layouts (both detail forms and list views) to a WC_HQ library. Other users browse, preview, and check out layouts. Creators get credit (recognition, subscription credit, cash at threshold).

**Why:** Bottom-up, same pattern as Small-Stings and Pydantic schema evolution. Users who do the work design the best layouts. The network surfaces the best through adoption. Creators are rewarded for value created.

**How to apply:**
- Two layout types: `detail_layout` (ui.json, Data-Driven UI forms) and `workbench_fields` (DataBrowser list views)
- Transport: existing sync infrastructure (Setting → Bundle → Connection → WC_HQ)
- Alice at HQ curates: flags duplicates, groups variants, surfaces most-adopted
- Creator attribution tracked per layout; adoption count visible in library
- Checked-out layouts install as Setting at user's chosen scope (user/role/org/system)
- User gets a copy, never modifies the original
- Full doc: data-driven-ui.md (both Allie + WC3 copies)
