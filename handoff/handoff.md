# Handoff — 2026-08-30

## Where We Left Off

Massive session: security hardening, infrastructure, file restructure, backup system, Alice LLM fallback, subscription model, readme consolidation. Training videos were the original goal — deferred because the independent security review needed to be fixed first. All code committed and pushed to both bill_dev and main.

## What Was Built

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

## What Was NOT Done

1. **Training videos** — deferred to next session (security fixes took priority)
2. **Rotate NATALIE_TOKEN** — removed from source, needs new token + update allie_api_keys.json
3. **Demo database re-seed** — commerce_demo has stale old-format Settings (423 vs 102)
4. **Phosphor → Lucide icon migration** — bundle analysis recommended it, not started
5. **ClamAV installation** — pipeline degrades gracefully without it
6. **Flowchart consolidation cleanup** — enriched copies moved to WC, but Allie still has originals
7. **WCHQ-side LLM endpoint** — `/wcapi/alice/llm/` referenced but not built on Andi yet
8. **wc:security Setting seed** — needed for `athena_document_review=true` at WCHQ

## Architecture Decisions

- **Apache-2.0 license confirmed** (was MIT in React2025, Apache in combined repo)
- **No infrastructure advice** — never write docs on pg/python/celery/react; users go to source
- **Settings + Reports are the only two models with Alice-managed backups** — everything else is standard user backup
- **Subscription: $14/5 users** — Alice counts is_staff, no tiers, no feature matrix
- **Large companies run multiple sovereign installations** — each pays per its own staff count

## Next Session Priorities

1. Training videos (the original goal)
2. Demo database re-seed with current Settings
3. Rotate NATALIE_TOKEN
4. Build WCHQ LLM endpoint on Andi
