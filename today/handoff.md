# Handoff — 2026-08-02

## Where We Left Off
Massive session spanning Statement Sorter, Athena security, and webclerk.com deployment. Statement Sorter is live at `webclerk.com/sort` — free client-side bank statement classifier with merchant learning, recommendation engine, grouped categories, row-click selection, A+- font sizing, draggable column widths. Full WC3 stack deployed to Andi with `commerce_expert` database (9,412 contacts). Athena integrity system running — 5 checkpoints verified every 4 hours via Celery. Built `liferequiresenergy.com` site (fork choice layout, presidential quotes, energy cliff/peak oil images, Edison quotes). All five webclerk.com routes stable after fixing `/opt/andi` permissions with immutable flag.

## Do This First Next Session
1. **Set up Hostinger for liferequiresenergy.com** — git repo at `github.com/JPods/liferequiresenergy` is ready; point domain and deploy.
2. **Light/dark theme for Statement Sorter** — CSS custom properties system, reusable across all WC list views. This becomes the db.list theme standard.
3. **Draggable column ORDER** — not just width; users reorder columns by dragging headers. Save to localStorage prefs.
4. **Fix TransactionDetail issues** — Setting #480 not loading, transaction save 500 (`Pending` model missing `data` field), epoch date formatting, customer FK display. These were open before this session.
5. **Write Athena self-defense readme** — `readmes/athena-self-defense.md`. Every node defends itself. Reporting: batch for defended, immediate for uncertain.

## Open Problems
- `/opt/andi` permissions were cycling to 700 — fixed with `chattr +i` (immutable flag). If anyone needs to modify `/opt/andi` itself: `sudo chattr -i /opt/andi` first.
- Statement Sorter `showSaveFilePicker` only works in Chrome/Edge — Firefox users get fallback download (no location picker).
- CSP hash in Nginx for Statement Sorter must be updated manually when script changes — `sign.py` handles the self-check hash but Nginx CSP hash is separate.
- Landing page source lives ONLY at `/Volumes/Allie/webclerk.net/` — not in git. Should be added to a repo.
- React app base path: assets served via Nginx split (`/assets/css/` → landing, `/assets/` → React). Works but fragile. Proper fix: rebuild React with `VITE_BASE_PATH=/app/`.

## What Was Decided (and Why)
- **No checkboxes in list views** — row is the selection target (click/shift/cmd). Documented as WC standard at `webClerk3/readmes/topics/ui/list-selection-standard.md`. Bill: "avoid selecting lists by clicking a tiny checkbox."
- **Category implies classification** — picking a Business or Personal category auto-sets the classification. One action, two fields. Less is more.
- **Decision columns centered, description right** — left-justified description pushes action columns far away. Put date→recommended→category→class→amount first, description after. Center of screen is where the action is.
- **Tools above where they are applied** — toolbar row order matches data column positions below.
- **Never rsync --delete to Andi** — destroyed landing page that only existed on remote. Recovered from 5TB. Scar documented in readmes/67.
- **Athena inside Alice for now** — Celery task, Alice's database. Separation to own processor is a hardware decision, not software. Architecture is ready.
- **Every node defends itself** — not a central firewall. Browser checks its own script hash. Server checks its own files. Pi checks its own code on boot. Reporting: batch if defended, immediate if uncertain.
- **db.list standard behaviors** — row selection, A+-, draggable column widths, column reorder, tools above data, user prefs in localStorage. Statement Sorter is the reference implementation.

## Files Changed This Session
- `sites/statement_sorter/index.html` — Complete rebuild: toast, folder drop, row selection, grouped categories, merchant learning, recommendations, A+-, column resize, Athena self-check
- `sites/statement_sorter/sign.py` — Athena signing script for client-side integrity
- `sites/statement_sorter/readme.md` — User folder organization guide
- `sites/liferequiresenergy/index.html` — New site: fork choice, presidents, oil wars, energy cliff, Edison, solar budget
- `sites/liferequiresenergy/ForkChoice.png` — Fork choice graphic (dark-to-gold gradient)
- `sites/liferequiresenergy/energy-cliff.jpg` — Energy cliff budget graphic
- `sites/liferequiresenergy/peak-oil.png` — Peak oil/fracking 2025 graphic
- `sites/ecosystem/index.html` — Updated nucleus URL to liferequiresenergy.com, hover glow doubled
- `readmes/67-webclerk-com-deployment.md` — Full deployment guide for Andi/webclerk.com
- `readmes/retrospections/2026-08-01.md` — Session 2 retrospection appended
- `webClerk3/apps/support/scheduler/tasks.py` — Added `task_athena_verify` Celery task
- `webClerk3/apps/docs/management/commands/athena_sign.py` — Athena manifest management command
- `webClerk3/webclerk3_api/settings.py` — Added Athena beat schedule + `SECURE_PROXY_SSL_HEADER`
- `webClerk3/readmes/topics/ui/list-selection-standard.md` — WC list selection standard
- Andi: `/etc/nginx/sites-enabled/webclerk3` — Routes for /sort /ecosystem /liferequiresenergy /app/, asset splitting, X-Forwarded-Proto fix
- Andi: `/etc/tmpfiles.d/andi-perms.conf` + `chattr +i /opt/andi` — Permanent permission fix
