---
name: qqq/zzz prefix = dead code, delete unless hold date
description: Files prefixed qqq_ or zzz_ are temp/dead archive — delete if no hold-until-date > today
type: feedback
---

qqq_ and zzz_ prefixed files are either temp or dead code kept for archive. If they do not have a hold-until-date > today, they should be deleted. Also applies across all projects, not just React2025.

**Why:** Bill uses these prefixes to mark code for retirement. They accumulate and bloat the codebase if not cleaned.

**How to apply:** At session start or when touching a directory, check for qqq_/zzz_ files and delete them unless they contain an explicit hold-until date that hasn't passed.
