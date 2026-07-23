# Handoff — 2026-07-23

## Where We Left Off

GL account modernization complete: `account_number` removed, `ida` is sole identifier with `1000-Cash` format. Three seed commands written and tested (`seed_gl_accounts`, `seed_terms`, `seed_freshstart`). Three-tier database architecture designed (wc_jpods/wc_demo/wc_freshstart). Select lists design complete — goes into `field_access` Setting config as `select_lists` key. WC2 popup/popupchoices data analyzed and mapped to WC3 models.

JPods specs repo live at `JPods/jpods-specs` with ruleset protection. Google Docs uploaded for non-git reviewers.

**`seed_select_lists` command is scoped and ready to write** — this is the immediate next task.

## Do This First Next Session

1. **Write `seed_select_lists`** — merge select_lists into existing field_access Settings for order, proposal, purchase, invoice, work_order, requisition, contact, item, action, payment
2. **Write `seed_demo`** — curated demo data (realistic contacts, items, order→invoice→payment cycle)
3. **Build three databases** — dump Mac, restore to Andi as wc_jpods; run seed_freshstart for wc_freshstart; run seed_freshstart + seed_demo for wc_demo
4. Fix `seed_coaching` field name issue (`action` vs `task`)
5. Fix audit_log not-null user_agent issue that breaks `seed_gl_defaults` in atomic block

## Open Problems

- **webclerk.com React on Vite dev server** — :5173 is dev, needs built bundle served by Nginx
- **Mac vs Andi migration gap** — 122 vs 90 migrations. Must align before sync experiment
- **SPEC-11 Sensors** — empty spec, content pending
- **Allie model capacity** — 20B insufficient for synthesis quality demanded by architecture
- **seed_coaching** — references `action` field that doesn't exist (should be `task`)
- **audit_log user_agent** — not-null constraint fails when management commands trigger saves (no HTTP request = no user_agent)

## Three-Tier Database Architecture

| Database | Built by | Contains |
|----------|----------|----------|
| `wc_jpods` | Dump of commerce_expert | Our real data — settings, actions, reports + JPods contacts, specs, GL |
| `wc_demo` | `seed_freshstart` + `seed_demo` | System + curated example data for learning |
| `wc_freshstart` | `seed_freshstart` only | System config only — empty, ready for new company |

**Sacred data (survives any rebuild):** Settings, Actions, Reports

## Bill's State

Productive session — infrastructure day. Engaged with the GL modernization design decisions (account numbering, ida as sole identifier). Wants Allie and Alice awake and learning from these architecture decisions. Wants to get all three databases set up today/tomorrow. Reminded that we have no legacy — clean breaks are fine.
