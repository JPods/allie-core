# Handoff — 2026-08-21

## Where We Left Off

Built the full MVP distribution system for WebClerk3. Bill is testing `install-webclerk.sh` when he wakes up.

## What Was Done This Session

### Demo Baseline Bundle
- `pack_demo_bundle`: exports 85 Settings + 80 data records → `demo-bundle.json`
- `load_demo_data`: imports bundle with FK resolution via uuid→new_pk array
- `remove_demo_data`: raw SQL delete by `refs.source=demo-baseline`, bypasses signals
- Updated `seed_demo.py`: removed `qqdemo-` prefix, added `refs.source` tagging, `bulk_create`
- Updated `seed_demo_transactions.py`: same tagging, `bulk_create` for lines
- Full round-trip tested: seed→pack→remove→reload→verify (all 80 records survive)

### FK Resolution Design
- Bundle carries `id` (old PK) + `uuid` for every record
- On import: build `old_pk→uuid` from bundle, then `uuid→new_pk` as records are inserted
- 25 FK fields remapped across 12 model types
- Demo case is simpler than full sync: empty target DB, no ida collisions

### Installation Infrastructure
- `install-webclerk.sh`: Mac/Linux native installer (checks deps, creates DB, venv, builds React, migrates, seeds)
- `docker-compose.yml`: PostgreSQL + Redis + Django + Celery (all platforms including Windows)
- `Dockerfile` + `docker-build.sh`: handles React2025 as separate repo
- `tools/webclerk-entrypoint.sh`: first-run detection (empty DB → migrate → seed → optional demo data)
- `.env.template`: documented defaults

### Setting Consolidation (from prior session, committed this session)
- 77 field_access + 19 detail_layout records merged into wc:model Settings
- Field behaviors service extracted
- BehaviorOverrideDialog, AdminTools page, audit commands

### Documentation
- `readmes/topics/architecture/demo-bundle-install.md`: full readme
- `readmes/flowcharts/demo-bundle-install.dot/.svg`: install + bundle flow

## Bugs Found (pre-existing, worked around)
1. `resolve_contact_ids_for_customer_org` scans all 5,687 contacts on every customer org save
2. `requisition_lines.commission` column missing from DB (added via ALTER TABLE)
3. Transaction line `post_save` signal crashes on `source.get()` when source is a string

## TODO — Next Session

### Immediate (Bill testing)
- Bill runs `install-webclerk.sh` — fix whatever breaks
- Test Docker path if native works

### High Priority
1. **Customer Care + Advanced Chimney data conversion** — Bill has two WC2 datasets to convert
2. **Portal UI (customer vs employee browser behavior)** — RBAC `is_portal` flag exists, need portal landing page
3. **Fix OrgBase.save() performance** — skip contact scan for new records (no contacts can reference a just-created org)
4. **Fix transaction line signal** — `source.get()` crash when source is string not dict

### Medium Priority
5. Consolidate 3 stale `wc:workbench_fields` into `wc:model`
6. Audit/prune `choices.py` purpose list
7. Wire `audit_field_behaviors --json` into Alice's code_standards scanner

## Key Files Changed

| File | Change |
|------|--------|
| `install-webclerk.sh` | NEW — native installer |
| `docker-compose.yml` | NEW — Docker setup |
| `Dockerfile` | NEW — container image |
| `docker-build.sh` | NEW — multi-repo Docker build |
| `.env.template` | NEW — config template |
| `tools/webclerk-entrypoint.sh` | NEW — first-run detection |
| `demo-bundle.json` | NEW — portable demo data |
| `apps/core/management/commands/pack_demo_bundle.py` | NEW |
| `apps/core/management/commands/load_demo_data.py` | NEW |
| `apps/core/management/commands/remove_demo_data.py` | NEW |
| `apps/core/management/commands/seed_admin_tool_reports.py` | NEW |
| `apps/core/management/commands/seed_demo.py` | Rewritten — refs.source tagging, bulk_create |
| `apps/transactions/.../seed_demo_transactions.py` | Rewritten — same |
| `apps/core/views/manage_view.py` | Added 5 commands to admin tools allowlist |
