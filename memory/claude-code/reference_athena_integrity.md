---
name: Athena integrity verification system
description: Every node defends itself; Athena signs files, Alice patrols every 4hrs, FAULT on tampering; management command + Celery task + manifest Document
type: reference
---

**Principle:** Every node defends itself. Athena signs, Alice patrols. Failures escalate immediately if defense capacity is uncertain; batch report if defended successfully.

**Components:**
- `athena_sign` management command — `--add`, `--remove`, `--list`, `--verify`, `--sign-all`
- `task_athena_verify` Celery task — every 4 hours, hashes all checkpoints
- Document `ida='athena-manifest'` — JSON manifest with checkpoints array
- `_athena_fault()` — writes immediate FAULT to `process/inbox/` on failure
- `sign.py` (Statement Sorter) — client-side self-hash for standalone static tools
- CSP headers on Nginx for browser-level script integrity

**Manifest structure:**
```json
{ "checkpoints": [{ "path": "...", "hash": "sha256...", "signed": "ISO", "type": "static_file|wcapi|nginx|robotics|allie" }], "last_check": "ISO", "last_result": "PASS|FAIL", "check_count": N }
```

**Reporting:** Can defend → batch log, Allie reads nightly. Uncertain → immediate FAULT + error log.

**Future:** Athena gets her own processor. Can't verify Alice's integrity from inside Alice. Separation is a hardware decision, not software.

**Files:**
- `WebClerk/backend/apps/docs/management/commands/athena_sign.py`
- `WebClerk/backend/apps/support/scheduler/tasks.py` (task_athena_verify)
- `sites/statement_sorter/sign.py` (client-side signing)
