---
name: List columns — ida first, never id or uuid
description: Never show id or uuid in list columns. Use ida as the first column. id is internal FK, uuid is sync key — neither is user-facing.
type: feedback
---

In list views (DataGrid, DataBrowser, any list page):
- **First column = ida** (human readable identifier)
- **Never show id** (internal FK, not meaningful to users)
- **Never show uuid** (sync key, not meaningful to users)

**Why:** ida is what you say on the phone. id and uuid are system fields. Users don't need to see them in lists.

**How to apply:** All seeded workbench_fields layouts should start with ida, not id. All list page column definitions should use ida as first column. DataBrowser default list fields should be ['ida', ...] not ['id', 'ida', ...].
