---
name: Demo instance on Andi
description: webclerk.com/demo/ — read-only demo with seeded data, READ_ONLY_MODE, port 8001
type: project
---

Demo instance live at webclerk.com/demo/ as of 2026-08-09.

- Gunicorn on port 8001, systemd service webclerk3-demo.service (boot-enabled)
- Database: commerce_demo, user: webclerk_demo_ro (SELECT-only)
- Login: demo@webclerk.com / demo2026
- READ_ONLY_MODE=True in .env
- Nginx routes in main server block at /etc/nginx/sites-enabled/webclerk3
- Seeded: seed_freshstart + seed_demo + seed_demo_transactions (3 complete cycles)
- Base dump: /opt/andi/apps/webclerk3-demo/webclerk3-base-install.dump (1.1MB)

**Why:** Open-source users need a demo they can browse without vandalism risk. Bill wants users to download if they want to modify.

**How to apply:** Any deployment question about the demo, READ_ONLY_MODE, or dual-instance setup — this is the reference.
