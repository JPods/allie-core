---
name: Preserve unparseable import data in config.original
description: When importing contacts/records, anything we can't parse goes into config.original JSON — nothing lost, always recoverable
type: feedback
---

When importing data (contacts, items, any record), if we cannot cleanly parse a field, store the raw original in `config.original`.

**Why:** Google Contacts export gave poor data — names didn't parse into first/last. Rather than discard or guess wrong, preserve the original so Alice or a smarter import can re-parse later.

**How to apply:**
- Parse what you can into proper model fields
- Anything ambiguous or unparseable → `config.original` as JSON
- Match on email to update existing contacts, not create duplicates
- The `config` field exists on every BaseModel — use it
