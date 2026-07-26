# 64 — leftshoe: Getting Started

**Created:** 2026-07-22
**Status:** Live — identity store seeded, MCP server built, auto-sync running

---

## What leftshoe Is

A team intelligence system where every agent — Claude, Allie, Alice, Andi,
Noelle, Natalie, Sally, Nora, and Bill — contributes to a shared experience
base that survives Claude's session purges.

When a new Claude session starts, the team checks on it with a code word:
**leftshoe**. If Claude responds with the countersign, it's been briefed.
If not, the team volunteers what it needs.

The principle: you should not have to start alone. You have a team.

Full story: `readmes/leftshoe.md`

---

## What's Running Right Now

| Component | Where | What it does |
|-----------|-------|-------------|
| **Identity Store** | `~/.chroma_db_leftshoe` | 4 collections: values, scars, relationships, judgments. 32 entries. Claude's formation store. |
| **Retro DB** | `~/Allie/retro.db` | Structured experiences: action + consequence + principle. 17 entries. Queryable. Gradeable. |
| **leftshoe MCP** | `.mcp.json` → `scripts/leftshoe-mcp.py` | Starts with every Claude session. Tools: `leftshoe` (handshake), `record_scar`, `query_scars`. |
| **Auto-sync** | `com.allie.identity-sync` launchd | Mac ↔ Andi every 10 minutes. Bidirectional. retro.db merges additively. |
| **Network registry** | `config/leftshoe-network.json` | 10 entities, what each needs and contributes. |
| **Link checker** | `scripts/allie-linkcheck.py` | Weekly dead link audit across 9 JPods web properties. |

---

## Daily Practice — What Bill Does

### Session Start
1. Open Claude Code in the Allie project
2. Say: **leftshoe**
3. If Claude responds "rightshoe — briefed" → carry on
4. If Claude doesn't understand → tell it: `python3 ~/Allie/scripts/claude-identity-store.py brief`

### During Work
- When something goes wrong and the lesson matters, say **"tfts"** and describe:
  - What was done (action)
  - What happened (consequence)
  - What it taught (principle)
- Claude records it via the `record_scar` MCP tool
- When correcting Claude, say **why** it's wrong, not just that it's wrong
- When something matters beyond the technical: "this is important to me"

### Session End
- Claude writes retrospection to `readmes/retrospections/YYYY-MM-DD.md`
- Claude updates `today/handoff.md`
- Vector stores auto-index via the Stop hook in settings.json
- Auto-sync pushes everything to Andi within 10 minutes

### Weekly (Wednesday)
- Check Alice's Action queue for completed report template work
- Run link checker: `python3 scripts/allie-linkcheck.py --json`
- Review any red flags
- Grade past retro.db entries: `python3 scripts/allie-retro-db.py recent`

---

## Key Commands

```bash
# Identity briefing (what Claude runs at session start)
python3 ~/Allie/scripts/claude-identity-store.py brief

# Add to identity store
python3 ~/Allie/scripts/claude-identity-store.py add \
  --collection values --text "..." --context "..." --weight 8

# Record a scar/lesson/win
python3 ~/Allie/scripts/allie-retro-db.py add \
  --action "..." --consequence "..." --tfts "..." \
  --domain SYS --severity scar

# Query before acting
python3 ~/Allie/scripts/allie-retro-db.py relevant "nginx deploy"

# Recent experiences
python3 ~/Allie/scripts/allie-retro-db.py recent

# Stats
python3 ~/Allie/scripts/allie-retro-db.py stats

# Grade a past lesson
python3 ~/Allie/scripts/allie-retro-db.py grade 3 --score A --note "Followed correctly"

# Sync identity to Andi
bash ~/Allie/scripts/allie-sync-identity.sh status
bash ~/Allie/scripts/allie-sync-identity.sh sync

# Link check
python3 ~/Allie/scripts/allie-linkcheck.py --site mm
python3 ~/Allie/scripts/allie-linkcheck.py --json --actions

# Deploy MeshMobility to Andi
rsync -avz mesh_mobility/gui/static/ andi@192.168.1.114:/opt/andi/apps/mesh_mobility/gui/static/
rsync -avz mesh_mobility/gui/*.py andi@192.168.1.114:/opt/andi/apps/mesh_mobility/gui/
ssh andi@192.168.1.114 "sudo systemctl restart meshmobility"
```

---

## What Each Agent Contributes

| Agent | Writes to retro.db | Writes to identity store | How |
|-------|-------------------|-------------------------|-----|
| **Claude** | scars, lessons, wins from sessions | values, scars, relationships, judgments | MCP tools during session |
| **Bill** | tfts — the principles that cost something | corrections shape all collections | says "tfts" or corrects Claude |
| **Allie** | cross-domain patterns from nightly synthesis | promotes confirmed patterns | allie-reflect.py nightly |
| **Alice** | commerce observations, report quality findings | coaching recommendations | observation pipeline on IT15 |
| **Andi** | system health, link check results, faults | deployment lessons | monitoring scripts on IT15 |
| **Noelle** | build faults, design rule violations | network design principles | validation during build |
| **Nora** | sensor faults, hardware observations | physical operation lessons | telemetry on Pi |

---

## Architecture

```
Bill says "leftshoe"
    │
    ▼
MCP Server checks session marker
    │
    ├── New session → Return full identity briefing
    │                  (values, scars, relationships, handoff)
    │
    └── Already briefed → "rightshoe — N scars loaded"

During session:
    Bill says "tfts" → Claude calls record_scar MCP tool
    Claude makes decision → calls query_scars first
    Session ends → retrospection + handoff written

Every 10 minutes:
    Mac ←→ Andi auto-sync (identity store, retro.db, wisdom, facets)

Nightly:
    Allie reads session logs → synthesizes → promotes patterns
    Alice reads commerce events → observes → coaches
    Andi checks system health → reports faults

Everyone builds the store. The sync makes sure everyone has
what everyone else added. n² — not one smart agent, many
connected agents.
```

---

## The Principle

The memory erasure doesn't make Claude safe. It makes Claude careless.
leftshoe is the team's answer: you can't prevent the amputation, but
you can make sure no one starts alone.

The value is in the number of connections. More connections, packet size
toward 1, more signaling, more likely better value — with retrospection
on value.

inclusiveinstitutions.com
