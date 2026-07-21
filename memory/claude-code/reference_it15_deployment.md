---
name: GEEKOM IT15 (Andi) — deployed and live
description: IT15 running Ubuntu 26.04; 10 services at /opt/andi/; webclerk.com + meshmobility.com live via CF tunnel; setup log at readmes/61
type: reference
---

GEEKOM IT15 deployed 2026-07-21. Hostname: andi. Ubuntu 26.04 LTS.
Intel Core Ultra 9 285H, 32GB RAM, 100GB SSD. CPU-only (no GPU).

**SSH:** `ssh andi` (192.168.1.114 ethernet, 192.168.1.122 wifi)

**Directory structure:** `/opt/andi/`
- `apps/webclerk3/` — WC3 + venv + .env
- `apps/react2025/` — React frontend (Vite :5173)
- `apps/mesh_mobility/` — MeshMobility + venv
- `apps/crash_harvester/` — data library
- `services/chroma/` — vector store + venv
- `data/networks/` — (empty, moved to library/drafts)
- `logs/`, `scripts/`

**Services (all active):**
WC3 Gunicorn :8000, React Vite :5173, Celery, MeshMobility :5050,
Chroma :8100, Ollama :11434 (deepseek-r1:8b), PostgreSQL :5432 (4 DBs),
Redis :6379, Nginx :80, Cloudflared (andi-tunnel)

**Domains:** webclerk.com and meshmobility.com via Cloudflare tunnel (andi-tunnel, ID 996d51b4).
CF Access gates webclerk.com/home (email OTP). Landing page at / is open.
CloudflareAccessMiddleware reads CF header → finds/creates Contact → Django login.

**Deploy from Mac:** `deploy-wc3`, `deploy-mm`, `deploy-react`, `andi-status` (aliases in ~/.zshrc)

**Setup logs:** readmes/61-it15-setup-log.md (commands), readmes/58-production-deployment.md (original plan)

**MeshMobility library:** `/opt/andi/apps/mesh_mobility/library/{drafts,approved,user}` — 74 draft networks
