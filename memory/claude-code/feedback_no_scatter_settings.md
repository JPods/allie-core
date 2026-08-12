---
name: No scattering like behaviors across many records
description: When a behavior applies uniformly across models, use one base Setting record — not 60+ per-model copies
type: feedback
---

Never scatter a like behavior across 60+ individual records. One base record with multiple patterns is always better than per-model copies.

**Why:** Bill explicitly said "whenever I suggest scattering a like behavior across 60 places remind me that it is a mistake." Users need one place to look, one place to edit, one place to see all patterns side-by-side. Per-model duplication makes patterns invisible and maintenance impossible.

**How to apply:** When designing Settings architecture, if all models share the same structure (dd_card, field_access, layouts), use a single base Setting with model keys in the JSON — not per-model Setting records. Dashboard/context overrides reference the base and override specific fields. Push back if Bill or anyone suggests the scattered approach.
