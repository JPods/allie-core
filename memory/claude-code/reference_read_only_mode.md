---
name: READ_ONLY_MODE setting
description: General-purpose .env boolean that locks any WC3 database read-only with 4 enforcement layers
type: reference
---

READ_ONLY_MODE=True in .env locks any WC3 database. Four layers:
1. WriteGateMiddleware — blocks POST/PUT/PATCH/DELETE
2. SaveWcapiView.post() — returns 405 before any processing
3. WCAPIDeleteView._do_delete() — returns 405
4. Admin URL removed from urlconf

Optional 5th layer: SELECT-only PostgreSQL user.

Originally named DEMO_READ_ONLY, renamed 2026-08-09 because it's general-purpose (demos, archives, audits, compliance, training).

Files: common/middleware/security.py, apps/core/views/save_view.py, apps/core/views/wcapi.py, webclerk3_api/settings.py, webclerk3_api/urls.py.

Readme: readmes/topics/infrastructure/read-only-mode.md
