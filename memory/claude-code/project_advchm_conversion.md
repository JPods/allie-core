---
name: Advance Chimney WC2→WC3 conversion
description: Active conversion project — advchm.webclerk.com testing week, cutover 2026-08-28; audit baselines, deployment plan, dump at ~/Allie/conversions/wc2_dump/advchm/
type: project
---

Advance Chimney (advchm) WC2→WC3 conversion in progress. Testing at advchm.webclerk.com through 2026-08-27, real cutover Friday 2026-08-28.

**Why:** First real WC2→WC3 customer migration. Advance Chimney is a $25M/yr company with 29K customers, 37K items, full transaction history. This conversion proves the pipeline works and becomes the pattern for all future WC2 migrations.

**How to apply:**
- Full technical readme at `readmes/71-advchm-conversion.md`
- User-facing checklist at `conversions/wc2_dump/advchm/README.md`
- Three dumps at `conversions/wc2_dump/` (jit, demo, advchm) — same schema, one converter
- UTF-8 BOM on all files — always use `encoding='utf-8-sig'`
- Plural→singular table name normalization required (Invoices→Invoice, Payments→Payment)
- Audit baseline computed from dump JSON — no separate metric exports needed
- Deploy follows demo instance pattern on Andi (new port, new DB, Nginx server block, CF DNS)
- Friday cutover: fresh dump from Bill → reconvert → deploy → READ_ONLY off
