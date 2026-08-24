---
name: Deasy / Flatwater Fleet WC2 conversion
description: WC2→WC3 conversion completed 2026-08-23; commerce_deasy DB on Andi; download links at webclerk.com/static/downloads/deasy/
type: project
---

Flatwater Fleet, Inc. (Deasy) WC2→WC3 data conversion completed 2026-08-23.

**Source**: ~/Allie/conversions/wc2_dump/deasy/ffi_data.json.gz — 74 tables, 645K rows from flatwater_kc/jitce_mirror (older 4D export, PascalCase fields).

**Splitter**: split_ffi.py in same directory — normalizes table names (plural→singular), field names (PascalCase→camelCase), sanitizes Infinity/NaN.

**Database**: commerce_deasy on Andi (PostgreSQL). 2141 customers, 11719 items, 7648 orders, 7324 invoices, 21442 purchases, 6679 payments, 86 settings, 53 reports. 0 vendors (empty in dump).

**Company profile**: Flatwater Fleet, Inc., 5354 Twig Blvd, Saginaw MN 55779. Price levels: Domestic/International/Agent.

**Downloads**:
- https://webclerk.com/static/downloads/deasy/ffi_data.json.gz (45MB)
- https://webclerk.com/static/downloads/deasy/ffi_data.json (877MB)

**WebClerk repo**: https://github.com/JPods/WebClerk (public, Apache 2.0)

**Why:** First external WC2 conversion delivered as downloadable bundle with Settings/Reports included.

**How to apply:** Use this as the template for future WC2 conversions — split_ffi.py handles the older FFI export format. Watch for: Infinity values in price fields, missing vendor tables, model/migration drift on Andi.
