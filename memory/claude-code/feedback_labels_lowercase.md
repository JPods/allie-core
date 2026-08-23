---
name: Labels match field names in lowercase
description: Column/field labels should be the actual field name in lowercase — users learn case-sensitive field names by seeing them
type: feedback
---

Labels should match field names in lowercase. Not title-cased, not prettified — the actual field name.

**Why:** Users learn case sensitivity by seeing the real field names in the UI. "total" not "Total", "balance" not "Balance", "unit_price" not "Unit Price". When users see the same names the system uses internally, they learn the data model naturally.

**How to apply:**
- Column headers: lowercase field name (underscores kept or replaced with space, but still lowercase)
- panelColumnUtils already does `field.replace(/_/g, ' ')` — just make sure it stays lowercase
- Hardcoded labels like `'Status'`, `'Total'`, `'Date'` should become `'status'`, `'total'`, `'date'`
- Print documents may be an exception — Bill hasn't specified
- This eliminates the need for a schema-driven label endpoint — the field name IS the label
