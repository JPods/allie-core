---
name: zz/qq prefixed records never tally into reports
description: Records with ida starting zz or qq are training/disposable data — exclude from all reporting, GL, dashboards, and decision data
type: feedback
---

Records whose `ida` starts with `zz` or `qq` are training/test data. They must NEVER tally into reports, accounting, dashboards, or any data that feeds decisions.

**Why:** Users train new people on the production system with real forms. The zz/qq prefix lets them create proposals, orders, invoices, purchases — the full flow — without polluting reports or financials. There are no words that begin with zz or qq, so the prefix is unambiguous.

**How to apply:**
- Every reporting query, tally, GL aggregation, and dashboard metric must exclude `WHERE ida NOT LIKE 'zz%' AND ida NOT LIKE 'qq%'` (or Django `.exclude(ida__startswith='zz').exclude(ida__startswith='qq')`)
- This applies to the record itself AND its lines (if the parent ida starts with zz/qq, lines are excluded too)
- The `metadata.training=True` flag is a secondary marker (set by the automated training flow) but the ida prefix is the primary, universal filter
- Applies to all WC3 models: proposals, orders, invoices, purchases, payments, items, customers, contacts
- The same convention applies to filenames (qqq_/zzz_ = dead code, delete) — see separate memory
