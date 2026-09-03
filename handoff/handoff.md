# Handoff — 2026-09-03

## Where We Left Off

Major session 2026-09-03. Cleared 6 handoff items, built WebServing routing app, 7 flowcharts (4 updated, 3 new), webserving.com + empoweringeveryone.com sites. All pushed to GitHub.

## What Was Built (2026-08-30 session)

### Critical Path Changes
1. **PostgreSQL 14 → 16** — all databases migrated, PG14 unlinked, PG16 client tools linked
2. **17 security fixes** from two independent reviews (see retrospection for full list)
3. **File restructure** — `~/Documents/WebClerk/app/` (code) + `data/` (user files)
4. **Document sanitization pipeline** — three-layer quarantine (sanitize/Alice/Athena)
5. **Bundle optimization** — 8.6 MB → 2.6 MB main bundle
6. **Backup system** — Settings + Reports + all models + pg_dump, 7-day rolling
7. **Alice WCHQ LLM fallback** — local Ollama first, cloud fallback if subscribed
8. **Registration + subscription** — $14/mo per 5 staff users, onboarding at /setup
9. **Readme consolidation** — system-based classification, no backend/frontend split

### File Locations Changed
- WebClerk repo: `~/Documents/WebClerk/app/` (was `~/Documents/CommerceExpert/WebClerk/`)
- User data: `~/Documents/WebClerk/data/` (uploads, logs, chroma, media, backups, exports)
- Start command: `cd ~/Documents/WebClerk && ./start.sh`
- 5TB sync path: `/Volumes/Andi_5T/Allie` (updated in allie-sync.sh)

## Completed Since 2026-08-30

1. ~~**Rotate NATALIE_TOKEN**~~ — ✅ removed from source; reads from env var `NATALIE_ALICE_TOKEN`; token in `allie_api_keys.json`
2. ~~**Demo database re-seed**~~ — ✅ commerce_demo now has 102 active Settings (was 423 stale)
3. **Contact Paste tool** — built (drag-and-drop contact parser, two modes, Small-Sting learning)
4. ~~**Phosphor → Lucide icon migration**~~ — ✅ 2026-09-03: all 12 Phosphor icons replaced with Lucide equivalents across 4 toolbar files; `@phosphor-icons/react` removed from package.json; TypeScript clean
5. ~~**ClamAV installation**~~ — ✅ 2026-09-03: ClamAV 1.5.4 installed via brew; clamd daemon running on `/tmp/clamd.sock`; pyclamd installed in venv; document_sanitizer.py updated to use socket path; virus definitions current
6. **Dependency audit + rule** — 2026-09-03: aligned requirements.txt, package.json, and THIRD-PARTY-NOTICES.md (added nameparser, django-extensions, humanize, pytest-cov, @hookform/resolvers; removed Phosphor Icons; fixed Pydantic version). New mandatory "Dependency Discipline" rule added to CLAUDE.md and THIRD-PARTY-NOTICES.md header — any add/remove of an outside dependency must update both files in the same commit
7. ~~**Athena integrity fault**~~ — ✅ 2026-09-03: production path `/var/www/webclerk-static/sort/index.html` was in local dev manifest but file only exists on Andi; removed checkpoint from local; Athena verify now passes clean; Andi should have its own manifest
8. ~~**wc:security Setting seed**~~ — ✅ 2026-09-03: created Setting id=893 (ida=wc-security, purpose=wc:security) with `athena_document_review=true`, `clamav_enabled=true`, `clamav_socket=/tmp/clamd.sock`; `athena_required_for_installation()` now returns True

## What Was NOT Done

1. **Training videos** — deferred to next session (security fixes took priority)
2. **Flowchart consolidation cleanup** — enriched copies moved to WC, but Allie still has originals
3. **WCHQ-side LLM endpoint** — `/wcapi/alice/llm/` referenced but not built on Andi yet
4. **clamd startup** — needs to be added to login startup or started manually (`/opt/homebrew/opt/clamav/sbin/clamd`); `freshclam` should run periodically to update virus definitions

## Architecture Decisions

- **Apache-2.0 license confirmed** (was MIT in React2025, Apache in combined repo)
- **No infrastructure advice** — never write docs on pg/python/celery/react; users go to source
- **Settings + Reports are the only two models with Alice-managed backups** — everything else is standard user backup
- **Subscription: $14/5 users** — Alice counts is_staff, no tiers, no feature matrix
- **Large companies run multiple sovereign installations** — each pays per its own staff count
- **webserving.com is the tool name** — not localwebserving; empoweringeveryone.com is the vision/pitch page
- **Option A hosting** — Hostinger for static pages, webclerk.com/wcapi/ for the API, CORS bridge
- **Free tier registers in routing network** — network effect does the selling; subscriptions get priority placement
- **Dependency Discipline** — any add/remove of outside dependency must update requirements AND THIRD-PARTY-NOTICES in same commit
- **Compression risk alerts** — alert Bill at 50/75/90% context; mandatory rightshoe above 80% before each new task

## What Was Built (2026-09-03 session)

### WebServing Routing App
- New Django app: `apps/webserving/` — local inventory routing for webserving.com
- 4 endpoints: search (public), register, heartbeat, stats
- Models: RegisteredInstance (location, tier, health) + SearchLog (demand patterns for Alice)
- Haversine radius search, concurrent fan-out, result merging
- CORS added for webserving.com

### Flowcharts
- 4 updated: Master Flow (01a), Athena (02c), Payment GL (06a), Alice Architecture (12a)
- 3 new: Episodes (13a), WebServing (14a), Subscription/Escalation (15a)
- Combined PDF: 45 pages, 2.6MB
- INDEX.md updated

### Sites
- webserving.com — search UI + getting-started SVG + architecture flowchart (github.com/JPods/webserving)
- empoweringeveryone.com — vision/pitch page (github.com/JPods/empoweringeveryone)
- Combined 2-page brief: empowering-everyone-webserving.md + .pdf (in webserving repo)

### Infrastructure
- Phosphor → Lucide icon migration (12 icons, @phosphor-icons/react removed)
- ClamAV 1.5.4 installed, clamd running on /tmp/clamd.sock, pyclamd in venv
- Dependency Discipline rule in CLAUDE.md + THIRD-PARTY-NOTICES.md
- Athena integrity fault fixed (production path removed from local manifest)
- wc:security Setting created (id=893, athena_document_review=true)

## Next Session Priorities

1. Deploy WC3 + webserving to Andi (SSH unreachable this session)
2. Cloudflare DNS: webserving.com + empoweringeveryone.com → Hostinger
3. Upload static pages to Hostinger (or connect GitHub repos)
4. Training videos (deferred — original goal from 2026-08-30)
5. Build WCHQ LLM endpoint on Andi
6. Update wc-works page with new flowcharts
7. Note: clamd needs startup automation; freshclam should run periodically
