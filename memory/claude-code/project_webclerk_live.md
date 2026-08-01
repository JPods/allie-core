---
name: WebClerk.com live deployment
description: Full WC3 stack deployed to Andi (IT15) via Cloudflare; /sort, /app/, /wcapi/, /admin/ all live; commerce_expert DB synced
type: project
---

**Deployed 2026-08-01:**

| URL | What | Source |
|-----|------|--------|
| webclerk.com/sort | Statement Sorter (static HTML) | /var/www/webclerk-static/sort/ |
| webclerk.com/app/ | React app (DataBrowser, Gantt) | /opt/andi/apps/react2025/dist/ |
| webclerk.com/wcapi/ | Django API (requires auth) | Gunicorn :8000 |
| webclerk.com/admin/ | Django admin | Gunicorn :8000 |

**Database:** `commerce_expert` on Andi (pg_dump from Mac, restored). User: `webclerk`.

**Key config on Andi:**
- `.env`: `LOCAL_DATABASE_NAME=commerce_expert`, `DB_MODE=local`
- `SECURE_PROXY_SSL_HEADER` in settings.py (Cloudflare terminates SSL)
- Nginx: `X-Forwarded-Proto: https` forced (CF→Nginx is HTTP)
- `/assets/` → React dist (not landing page)
- Services: `webclerk3.service` (Gunicorn), `webclerk3-celery.service`, `react-wc3.service`

**Deploy workflow:** rsync code → rsync React dist → pg_dump/restore if DB changed → collectstatic → restart services → athena_sign --sign-all

**Why:** Bill wants to show WC3 to others. Public-facing demo with real data.
