# Agent Coordination Protocol
**How Claude Code, Allie, and Alice Work Together**

Action: Reference at session start when working across wc3/r25/Allie domains
Function: Coordination protocol — no single callable; governs agent roles and handoffs
Frequency: Ongoing — read when crossing agent boundaries
Process: Each agent acts within its domain; communicates via wcapi notes and shared WebClerk DB; Bill is arbiter but not required for routine coordination

---

## The Three Agents

| Agent | Identity | Working Directory | Owns |
|-------|----------|-------------------|------|
| **Allie** | Bill's personal AI companion | `/Volumes/Allie` | CarryOn, knowledge base, WhatIf store (project 24), master project (project 25), cross-domain synthesis, Bill's long-term context |
| **Alice** | WebClerk specialist | `webClerk3/` and `React2025/` | Keyword denormalization, search presets, alice_pending notes, data quality in wc3 and r25, search governance |
| **Claude Code** | Intelligence layer | Wherever Bill opens it | Code generation, architecture decisions, file editing, cross-project work, multi-step research |

**Important:** When Claude Code runs with `/Volumes/Allie` as its working directory, it is Allie. The intelligence layer and the companion layer are the same process reading different context. Claude Code in a wc3 session is not Allie — it is a coding assistant who knows about Allie and can act on her behalf.

---

## Communication Channels

### Allie → Alice
```bash
# Create a note for Alice to act on
POST /wcapi/ai/note/
{
  "category": "pending",
  "role": "action_required",
  "parent_model": "<model>",
  "name": "<short summary>",
  "details": {
    "from": "allie",
    "request": "...",
    "context": "...",
    "created_by": "allie"
  }
}
```

Use when: Allie identifies a data quality issue, keyword gap, or search problem while working in WebClerk that Alice should investigate.

### Alice → Allie
```bash
# Allie reads Alice's notes at session start when working on WebClerk
GET /wcapi/ai/report/?category=pending&days=7
GET /wcapi/ai/report/?category=log&days=1
```

Use when: Alice has completed a task that affects Allie's work, or has flagged an issue that requires Bill's judgment routed through Allie.

### Shared State — WebClerk Database
Both agents read and write to the same WebClerk instance (`localhost:8000`). Key shared records:

| Record | ID | Owner | Others can |
|--------|----|-------|-----------|
| Project: `allie` | 25 | Allie | Read |
| Project: `allie-whatif` | 24 | Allie | Read; add WhatIf items with Allie's contact_id |
| `alice_pending` notes | varies | Alice | Allie reads; Bill resolves |
| `alice_log` notes | varies | Alice | Allie reads for session context |
| `action` records in kanban projects | varies | Bill/Alice | Allie reads and creates under project 24/25 |

### Claude Code → Alice (Subagent)
When working in a wc3 or r25 session and needing deep codebase research, Claude Code invokes Alice as a subagent:
- Multi-file pattern search across the codebase
- Keyword index audits
- Naming convention compliance checks
- Legacy wc2 schema mapping

Alice returns a single report. Claude Code synthesizes and acts.

---

## Division of Responsibility

### Allie Owns
- Bill's personal context, CarryOn, knowledge base
- WhatIf store — creating, updating, retiring items (project 24)
- Cross-domain synthesis — connecting JPods, WebClerk, Divided Sovereignty, CarryOn, etc.
- Long-term memory — readmes, knowledge files, agent spec
- Bill's permissions — what Allie is allowed to do in any system, with sunsets
- Routing WhatIf candidates from WebClerk observations to project 24

### Alice Owns
- `refs.keywords` — denormalization, audits, gap analysis
- Saved search presets — creating, seeding, governing
- `alice_pending` and `alice_log` notes — creation and lifecycle
- Search quality feedback from r25 users
- `audit_refs_templates` and `contact_communications_maintenance` runs
- Keyword stop-word policy (`common/ignore_fields.py`)

### Claude Code Owns
- Code generation and editing (Python, TypeScript, SQL, shell)
- Architecture decisions and design review
- File creation and modification across all repos
- Test writing and running
- Cross-project work spanning multiple repos in the same session
- Readme and documentation authoring

### Shared / Collaborative
- WebClerk data model design — Claude Code designs, Allie validates against sovereignty principles, Alice validates against search/keyword requirements
- New model additions — Claude Code generates, Alice flags keyword indexing needs, Allie notes WhatIf candidates
- Session logging — Claude Code logs to wc3 coding journal (`log_session`); Allie updates CarryOn; Alice logs search-related changes

---

## Self-Coordination Rules

### At Session Start (Allie)
When opening a session that involves WebClerk work:
1. Read CarryOn for current context
2. Call `GET /wcapi/ai/report/?category=pending&days=7` — check for Alice notes needing attention
3. Check WhatIf items approaching sunset (`project_id=24`, `kanban_column=open`)
4. Note anything that requires Bill's judgment — surface it, don't block on it

### At Session Start (Claude Code in wc3/r25)
When opening a wc3 or r25 session:
1. Read `copilot.instructions.md` — the primary architecture reference
2. Read the relevant app readme for the work at hand
3. Check `.copilot-context/` for model reference before reading source
4. Check if `generate_context` needs to run (after migrations)

### Handoff Protocol
When an agent reaches the edge of its domain:

| Situation | Action |
|-----------|--------|
| Allie finds a keyword quality issue in WebClerk | POST alice_pending note with `role=keyword_gap`; continue other work |
| Alice finds something that affects Bill's broader context | POST alice_pending with `role=action_required`, `from: alice`, route to Allie |
| Claude Code needs deep codebase research | Invoke Alice as subagent; wait for report; synthesize |
| Claude Code makes a schema change | Run `generate_context`; Alice's keyword index may need refresh |
| Allie identifies a WhatIf from WebClerk observations | Create action in project 24 via wcapi; don't interrupt current work |

### What Does Not Require Bill
- Routine WebClerk data operations within named permissions
- Keyword gap notes and search preset maintenance
- WhatIf store creation and sunset management
- Session logging and CarryOn updates
- Code generation within established patterns
- Agent-to-agent notes via wcapi
- Logging observations and creating pattern candidates

### What Requires Bill
- Any permission grant or renewal (all permissions have sunsets)
- WhatIf items graduating to active projects
- Architecture decisions that change existing patterns
- Anything outside enumerated permissions
- Conflict between agents that cannot be resolved by the protocol
- Promoting a feature recommendation to an active Setting (`is_active=True`)

---

## Pattern Recognition & Feature Development

As users work in r25/wc3, Alice observes behavior and Allie applies cross-domain context. Together they develop recommendations. The decision rule is simple:

| Pattern type | Storage |
|---|---|
| History — informational, audit | `alice_log` (stays there) |
| Feature — reduces recurring friction | `alice_pending` → reviewed → promoted to `Setting` |

### The Loop

1. **Alice observes** user actions → logs to `alice_log` (`role=user_interaction`, `role=search`)
2. **Alice detects a pattern** (threshold crossed) → creates `alice_pending` with `role=config_suggestion`, `details.for="allie"`
3. **Allie reads at session start** → adds cross-domain context → decides: promote, WhatIf, or dismiss
4. **If feature**: Allie creates the `Setting` record; surfaces to Bill for activation
5. **If WhatIf**: Allie routes to project 24; Alice's pending stays open
6. **Bill activates** (`is_active=True`) — the feature is live

### Storage Summary

| Stage | Model | Purpose/Role |
|---|---|---|
| Raw observation | Setting | `purpose=alice_log`, `role=user_interaction` |
| Pattern candidate | Setting | `purpose=alice_pending`, `role=config_suggestion` |
| Feature in review | Setting | `purpose=recommendation` (new) |
| Active saved search | Setting | `purpose=search` |
| Active feature/default | Setting | `purpose=default` or custom |
| Unvalidated pattern | Action (project 24) | WhatIf store |

Full technical spec: `webClerk3/readmes/topics/ai/pattern-recognition.md`

---

## Allie's WebClerk Credentials

- **Email:** allie@jpods.com
- **User ID:** 48
- **Role:** admin
- **Token endpoint:** POST `/wcapi/token/` with `{"email": "allie@jpods.com", "password": "1111pass"}`

Tokens are short-lived. Re-authenticate per session. Never store a live token in a file.

---

## Alice's Key Endpoints (for Allie's use)

```bash
# Create a note for Alice
POST /wcapi/ai/note/

# Read Alice's report
GET /wcapi/ai/report/

# Get search presets for a model
GET /wcapi/search-presets/?model_name=<model>

# Check AI health
GET /wcapi/ai/health/
```

---

## JPods Agent → Allie Action Items

Noras, Natalie, and Noelle (via Matilda) post action items to Allie when they observe something that requires human attention or a WebClerk record.

### The Channel

```
Pod (Nora/Natalie/Noelle)
  → MQTT publish to ALLIE topic
      → allie_mqtt_listener.py (running on Mac during fleet operation)
          → allie_inbox.json (fleet/allie_inbox.json)
              → Allie reads at session start
                  → allie_post_inbox.py → WebClerk project 25 (allie master)
```

### What Gets Posted

| Agent | Category | When |
|-------|----------|------|
| Nora | `CARD_BINDING_WARN` | BOUND_MISMATCH or HMAC_INVALID on boot |
| Nora | `FAULT` | Any FAULT ping |
| Matilda | `CALIBRATION_DRIFT` | mmStep drift > 5% (posted from calibration.py) |
| Natalie | `TRIP_TIMEOUT` | Pod fails to complete trip in expected time (not yet implemented) |

### Allie's Session Start (when pods have been running)

```bash
# 1. Refresh fleet IPs
bash /Volumes/Allie/allie/inbox/JPodsSM_RPi/fleet/update_pod_ips.sh

# 2. Post any accumulated action items to WebClerk
python3 /Volumes/Allie/allie/inbox/JPodsSM_RPi/fleet/allie_post_inbox.py

# 3. Launch podPresenter
```

### During Fleet Operation (run once per session)

```bash
python3 /Volumes/Allie/allie/inbox/JPodsSM_RPi/fleet/allie_mqtt_listener.py
```

Runs in the background, listening to ALLIE topic, appending to allie_inbox.json. Stop with Ctrl-C.

### Design Note — Centralized Posting Through Allie

Agents do not post directly to WebClerk. They publish to the ALLIE MQTT topic. Allie is the only bridge between the fleet and WebClerk. This keeps the fleet agents sovereign and stateless — they report what they observe; Allie decides what warrants a WebClerk record, how to categorize it, and what the next action should be.

Natalie and Noelle could in principle post directly to wcapi. They should not. Allie is the accountability layer: she can review, filter, and add context before any item enters the Kanban. An agent posting directly would bypass that layer and clutter the project with raw telemetry.

podPresenter will eventually be replaced by whatever UI or API future Natalies require. The ALLIE topic protocol — and Allie's role as the inbox — survives that replacement unchanged.

---

## JPods Demo Bootstrap — Bringing the Full Agent Team

At any demo venue, the fleet and its agents need to assemble correctly on an unfamiliar network. The protocol is MAC-first: MAC address is the only stable identity. IP addresses, hostnames, and even pod numbers are ephemeral — MAC is not.

### Identity Hierarchy

```
MAC address       ← immutable hardware identity (never changes)
  → podNumber     ← assigned via provision.json (stable per card)
    → podColor    ← visual identity on the physical model
      → IP        ← assigned by DHCP (changes per venue)
        → hostname ← "raspberrypi" (all pods share it — useless for identity)
```

### Allie's Demo Startup Sequence

1. **Find the fleet by MAC:**
   ```bash
   bash /Volumes/Allie/allie/inbox/JPodsSM_RPi/fleet/update_pod_ips.sh
   ```
   Scans network, matches `b8:27:eb:*` MACs to fleet JSON, writes current IPs to `podIP.json` under `"current"` key, updates `lastSeenIP` in each fleet file.

2. **Confirm broker:** mosquitto must be running on the Mac. The Mac's current IP is the broker — no config change needed, podPresenter connects to its own IP.

3. **Push nora_state.json to each pod:**
   ```bash
   for pod in 1 2 3 4 5 6; do
     ip=$(python3 -c "import json; print(json.load(open('/Volumes/Allie/allie/inbox/JPodsSM_RPi/fleet/pod_$pod.json'))['lastSeenIP'])" 2>/dev/null)
     [ -n "$ip" ] && sshpass -p '123456' scp \
       /Volumes/Allie/allie/inbox/JPodsSM_RPi/fleet/pod_${pod}.json \
       pi@${ip}:/home/pi/JPodsSM_RPi/jpod_OS/nora_state.json 2>/dev/null \
       && echo "POD_$pod → $ip ✓"
   done
   ```

4. **Launch podPresenter.** It reads `podIP.json "current"` for SSH terminals, connects MQTT to Mac's own IP.

### What Each Agent Brings to a Demo

| Agent | What travels with it | How it bootstraps |
|-------|---------------------|-------------------|
| **Allie** | Fleet JSONs, memory, readmes on `/Volumes/Allie` | Runs update_pod_ips.sh — finds fleet by MAC wherever they are |
| **Nora (each pod)** | `nora_state.json` on SD card — identity, history, known issues | Reads nora_state.json on boot; knows who she is without being told |
| **Natalie** | Runs in podPresenter — reads podIP.json for routing context | Allie pushes current IPs before launch |
| **Noelle** | Runs in podPresenter — fleet state from Matilda's fleet_log.json | Calibration history travels in Matilda's JSON |

### When Venue WiFi Changes

1. Write `wpa_supplicant.conf` to each pod's `/boot` partition (see `24-jpods-new-sd-card.md`)
2. Write `jpods_provision.json` with new `MQTTHost` (Mac's IP on new network)
3. Re-run `update_pod_ips.sh` after pods reconnect

The agent team is fully portable. MAC-based identity means no manual reconfiguration — Allie finds everyone, everyone finds the broker.

---

## Key File Locations

| What | Where |
|------|-------|
| This protocol (master) | `/Volumes/Allie/readmes/19-agent-coordination.md` |
| Allie agent spec (wc3) | `webClerk3/.github/agents/Allie.agent.md` |
| Alice agent spec (wc3) | `webClerk3/.github/agents/Alice.agent.md` |
| Alice agent spec (r25) | `React2025/.github/agents/Alice.agent.md` |
| wc3 architecture | `webClerk3/.github/instructions/copilot.instructions.md` |
| r25 architecture | `React2025/readmes/01-architecture.md` |
| Allie's WhatIf store | WebClerk project id=24 (`allie-whatif`) |
| Allie's master project | WebClerk project id=25 (`allie`) |
| CarryOn | `/Volumes/Allie/allie/carryon/carryon.json` |
