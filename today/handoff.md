# Handoff — 2026-08-23 (PJPV + Underscore Convention)

## Where We Left Off

Andi deployment PARTIAL — backend and React dist rsync'd but services not restarted.
Bill wants to change to git-pull deployment model. New session should handle this.

## What Was Done

### PJPV Compliance
- Audited all backend/React/Pydantic for PJPV compliance — fixed 14 violations
- `update_received()` in totals.py — single owner for payment-side balance
- Fixed margin formula (subtotal-cost not total-cost) in transaction_save.py
- Fail-hard validation — `_validate_totals()` raises, no soft fallback
- "Shadow field" = standard term for scalars shadowing JSON envelopes

### 21 Pydantic Schemas
- `common/schemas/transaction_envelopes.py` — 21 classes covering all business envelopes
- `field_behaviors.py` LEAF_BEHAVIORS now schema-derived
- `/wcapi/_pjpv_fields/` endpoint serves schema metadata to React

### Underscore Prefix Convention
- All 26 system endpoints: `wcapi/name/` → `wcapi/_name/`
- 32 React files, 62 URL replacements
- SystemDispatchView handles extensible `_` actions

### Codebase Consolidation
- WebClerk/ is the ONLY codebase — webClerk3/ and React2025/ deleted
- Committed `86fe942d`, merged to main, pushed to JPods/WebClerk

## Scars #66-71
66: Document paths not outcomes | 67: Fail hard fix fast | 68: Underscore prefix |
69: Suffer now once | 70: Check which files server reads | 71: Backups are traps

## Next Session TODO

### 1. Andi Git-Pull Deployment
Have Andi pull from github.com/JPods/WebClerk instead of rsync from Mac.
- SSH to andi@192.168.1.114
- Set up git on Andi pointing at JPods/WebClerk
- Handle backend/ subfolder (Andi expects flat at /opt/andi/apps/webclerk3/)
- Install deps, collectstatic, migrate, athena_sign, restart services
- Verify: curl https://webclerk.com/wcapi/_system_info/
- Update readmes/67-webclerk-com-deployment.md

### 2. Stale Path References
- Allie memory files reference webClerk3/ and React2025/
- CLAUDE.md references old paths
- Update to WebClerk/backend + WebClerk/frontend

### 3. Alice Weekly Schema Scan
- Schedule Wednesday coordination day
- Diff schemas vs production JSON
