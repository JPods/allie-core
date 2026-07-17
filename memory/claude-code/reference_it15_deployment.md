---
name: GEEKOM IT15 production deployment
description: IT15 Ubuntu Server deployment guide; multi-instance WebClerk; Gunicorn+Nginx+SSL; MyCarryOn; git deploy; at readmes/58
type: reference
---

GEEKOM IT15 arriving ~2026-07-20. Ubuntu Server 24.04, always-on.

Full guide: readmes/58-production-deployment.md

**4 WebClerk instances, one codebase:**
- jpods.webclerk.com :8000 (wc_jpods) — commerce, Alice, capital
- meshmobility.com :8001 (wc_mobility) — network planner, students (separate DB from JPods — Alice promotes qualified leads)
- demo.webclerk.com :8002 (wc_demo) — demo store
- mycarryon.io :8003 (wc_carryon) — portable identity

**Stack:** Gunicorn + Nginx + Let's Encrypt + systemd template services + PostgreSQL + Redis

**Deploy:** Option A (SSH manual), Option B (deploy.sh + MacBook aliases), Option C (git webhook)

**How to apply:** When IT15 arrives, follow the 5-phase checklist in readmes/58.
