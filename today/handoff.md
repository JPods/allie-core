# Handoff — 2026-07-21

## Where We Left Off
GEEKOM IT15 (Andi) fully operational. Ubuntu 26.04, all services running from `/opt/andi/`.
Both webclerk.com and meshmobility.com live through Cloudflare tunnel.
CF Access gates `/home` on webclerk.com — email OTP verification.
Landing page at webclerk.com root is open.
CloudflareAccessMiddleware in WC3 already built — reads CF email header, finds/creates Contact, logs in.

## Do This First Next Session
1. Fix CF Access app names ("WebClerk" and "MeshMobility" instead of unknown)
2. Test full auth flow: visit webclerk.com/home → CF email OTP → Django login → React routes by role
3. Create WC3 superuser on Andi (`manage.py createsuperuser`)
4. MeshMobility: add library browse from `/opt/andi/apps/mesh_mobility/library/drafts/`
5. MeshMobility: CF Access for save (user must verify email before saving networks)
6. Fix case-sensitivity issues for production build (Mac→Linux `.tsx` imports)
7. Set static IP via DHCP reservation on router

## Open Problems
- CF Access shows "unknown application" — need to set app name in dashboard
- React Vite running in dev mode (not production build) — case-sensitive import `rawJsonCard` blocks build
- WC3 database is empty (no superuser, no seed data)
- webclerk.com React proxy to :8000 — need to verify API calls work through CF tunnel
- MeshMobility library browse not yet coded
- Email not configured (cleaned out old DNS records intentionally)

## What Was Decided (and Why)
- **`/opt/andi/` as root** — clean Linux standard, not `/var/www/`. Separates code/data/logs/services.
- **Single WC3 instance first** — prove one works before multi-instance.
- **CF Access for auth, app decides roles** — CF just verifies email, passes header. WC3 middleware finds/creates Contact. React routes by Contact.is_staff/vendor/manufacturer/role.
- **Landing page open, `/home` gated** — visitors see the storefront. Sign In triggers CF Access.
- **Andi is the product** — ships with hardware. Each business owns their box + AI + data. Desktop Hosting realized.
- **balenaEtcher for Linux installers** — dd failed; Etcher proven reliable.
- **Ubuntu 26.04 LTS** — newer than planned, works fine. Python 3.14.
- **GPU packages removed** — 4.4GB of NVIDIA/CUDA/torch/triton useless on CPU-only IT15.
- **JPods3D public repo** — MIT license, Copyright JPods LLC, at github.com/JPods/jpods3d.
- **Training video scripts** — dedicated future session. Review code → write 1-4 min scripts per feature.

## Files Changed This Session
- `readmes/61-it15-setup-log.md` — complete IT15 setup documentation
- `readmes/retrospections/2026-07-21.md` — retrospection with lessons for Allie
- `process/inbox/20260721T151500-tfts.md` — TFTS for the deployment arc
- `~/.zshrc` — deploy-wc3, deploy-mm, deploy-react, andi-status aliases
- `~/.ssh/config` — Host andi entry
- Memory files: balenaEtcher, Andi hardware agent, Andi installer tool, training videos, access RBAC

## Andi Service Status
| Service | Port | Status |
|---------|------|--------|
| WC3 Gunicorn | :8000 | active |
| React (Vite) | :5173 | active |
| Celery | — | active |
| MeshMobility | :5050 | active |
| Chroma | :8100 | active |
| Ollama | :11434 | active (deepseek-r1:8b) |
| PostgreSQL | :5432 | active (4 databases) |
| Redis | :6379 | active |
| Nginx | :80 | active |
| Cloudflared | — | active (andi-tunnel) |
