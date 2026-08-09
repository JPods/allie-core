# Handoff — 2026-08-09

## Where We Left Off
Production deployment and demo instance session. Set up webclerk.com/demo/ as a read-only demo with seeded transaction data. Created READ_ONLY_MODE — a general-purpose setting that locks any WC3 database with four enforcement layers. Wrote three new infrastructure readmes and a deployment flowchart. Fixed two production bugs in email notifications and order signals. Taught Allie and Alice everything from this session.

## Demo Instance — Live
- **URL:** https://webclerk.com/demo/app/
- **Login:** demo@webclerk.com / demo2026
- **DB:** commerce_demo (SELECT-only user webclerk_demo_ro)
- **Service:** webclerk3-demo.service on port 8001 (boot-enabled)
- **Data:** 12 items, 5 customers, 7 contacts, 3 complete transaction cycles (proposal→order→invoice→payment→GL)
- **Base dump:** /opt/andi/apps/webclerk3-demo/webclerk3-base-install.dump (1.1MB)

## READ_ONLY_MODE
- `.env` boolean — locks any WC3 database
- Layer 1: WriteGateMiddleware blocks write HTTP methods
- Layer 2: SaveWcapiView.post() returns 405
- Layer 3: WCAPIDeleteView._do_delete() returns 405
- Layer 4: Admin URL removed from urlconf
- Layer 5 (optional): SELECT-only PostgreSQL user
- Readme: readmes/topics/infrastructure/read-only-mode.md

## Files Created/Modified (WC3 repo)
- `apps/transactions/management/commands/seed_demo_transactions.py` — NEW
- `apps/transactions/services/email_notifications.py` — bug fix (refs.links.email dict handling)
- `apps/transactions/signals.py` — bug fix (order notification) + logger import
- `common/middleware/security.py` — READ_ONLY_MODE support
- `apps/core/views/save_view.py` — READ_ONLY_MODE check
- `apps/core/views/wcapi.py` — READ_ONLY_MODE check
- `webclerk3_api/settings.py` — READ_ONLY_MODE from .env
- `webclerk3_api/urls.py` — conditional admin URL
- `readmes/topics/infrastructure/production-deployment.md` — NEW
- `readmes/topics/infrastructure/minimal-viable-install.md` — NEW
- `readmes/topics/infrastructure/read-only-mode.md` — NEW
- `readmes/charts/flowcharts/wc3-deployment.dot` + `.pdf` — NEW (#34)
- `readmes/charts/flowcharts/README.md` — updated
- `readmes/67-webclerk-com-deployment.md` — updated

## Bug Fixes
1. `email_notifications.py` — refs.links.email contains dicts not plain IDs; extract id before filter
2. `signals.py` — order.name doesn't exist; wrapped in try/except (needs proper fix)

## Open Items for Next Session
- `seed_coaching` has stale `model_name` field on Document model — crashes seed_freshstart
- `seed_gl_accounts` has `used_for='payables'` choice validation error
- Demo save/delete message is hardcoded to webclerk.com — should be configurable
- `order.name` in send_order_created_notification needs proper fix, not just try/except
- Key lesson: use explicit `_id` FK assignment in seed commands to avoid post_save signal crashes
