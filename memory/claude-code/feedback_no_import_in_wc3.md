---
name: No import parsing inside WC3
description: All data transformation happens outside WC3 via Alice/Claude/DynamicCatalogs; WC3 only receives clean bundles; no CSV/TSV parsers in operational code
type: feedback
---

No raw import code inside WC3. Individual records come through wcapi CRUD. Bulk is always and only a bundle via `/sync/receive/`.

**Why:** Import parsing logic grows without bound, breaks silently, and buries the real schema under translation layers. The noise belongs to Alice's domain (alice_conversion DB), not WC3. WC3's job is to record a bundle that's already correct.

**How to apply:** Never write CSV/TSV/Excel parsing code in WC3. Never add ImportExportModelAdmin to admin classes. All transformation work happens in apps/conversion/ (which writes to alice_conversion, not commerce_expert). If someone needs to import data, point them to the conversion pipeline or give them a free WC3 copy to produce valid bundles themselves.

**Corollary — no commented-out code:** Old imports are archived at `archive/import_removed_2026-08-04/`, not commented out in operational files. Commented-out code is dead weight pretending to be a lesson. The lesson belongs in the archive where someone can study it. The operational code says what we do now — nothing else.
