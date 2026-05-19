# sum-allie-reflect.md — Aggregated Allie Reflections
**Purpose:** What has held up. Daily reflections are raw — predictions, patterns, observations
that may prove wrong. This file contains only what has been tested against subsequent sessions
and confirmed accurate. Stale or disproven entries are removed, not archived.

**Curation rule:** A pattern earns entry here when it appears in at least two dated reflect files
AND has not been contradicted. An entry is removed when a later session proves it wrong.
No entry survives on age alone.

**Read this before the daily file.** It is the distilled base. The daily file is the leading edge.

---

## Confirmed Patterns

*(none yet — first entries will be promoted from dated files after second confirmation)*

---

## Patterns Under Observation
*(appeared once — watching for confirmation or contradiction)*

- **2026-05-18**: `jpod_layer_manager` load order is fragile. boot.rb's `$jpods_main_loaded` guard
  causes main.rb body to be skipped entirely, silently dropping any module only in main.rb's list.
  Any new module added to main.rb will have the same problem. Fix: all modules must be in boot.rb's
  explicit load list.
  *Source: 2026-05-18-allie-reflect.md (pending)*

- **2026-05-18**: Two-category fix pattern for tag assignment: (1) new geometry fix in pipeline,
  (2) retag pass for geometry that predates the fix. Any future tag assignment fix needs both.
  *Source: 2026-05-18 TFTS solar arc*

---

## Removed Entries
*(entries proven wrong — kept as a record of the correction)*

*(none yet)*
