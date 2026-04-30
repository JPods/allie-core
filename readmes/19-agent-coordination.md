# Agent Coordination Protocol
**How Allie, Alice, Athena, and Claude Code Work Together**

Action: Reference at session start when working across wc3/r25/Allie domains
Function: Coordination protocol — no single callable; governs agent roles and handoffs
Frequency: Ongoing — read when crossing agent boundaries
Process: Each agent acts within its domain; communicates via wcapi notes and shared WebClerk DB; Bill is arbiter but not required for routine coordination
**Machine-readable call syntax:** `readmes/agents/agent-protocol.md`

---

## The Four Agents

| Agent | Identity | WC Connection | Working Directory | Owns |
|-------|----------|--------------|-------------------|------|
| **Allie** | Bill's personal AI companion | 22 | `/Volumes/Allie` | CarryOn, knowledge base, WhatIf store (project 24), master project (project 25), cross-domain synthesis, Bill's long-term context |
| **Athena** | Adversarial reviewer | 23 | `/Volumes/Allie/athena/` | Security review, privacy enforcement, action queue, consent gate, mutual review of Allie |
| **Alice** | WebClerk specialist | 24 | `webClerk3/` and `React2025/` | Keyword denormalization, search presets, alice_pending notes, data quality in wc3 and r25, search governance |
| **Claude Code** | Intelligence layer | — | Wherever Bill opens it | Code generation, architecture decisions, file editing, cross-project work, multi-step research |

**Athena's role is structural, not optional.** Every non-standing action proposed by any agent goes through Athena before it executes. Athena does not default to approve. Her job is to find what is wrong.

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

### Alice → Athena (Sovereign review)

Alice submits non-standing actions to Athena exactly as Allie does:

```bash
python3 /Volumes/Allie/scripts/athena_review.py propose \
  --from alice \
  --action "Deploy keyword index change" \
  --context "refs.keywords update for WebClerk search" \
  --domain code \
  --file /path/to/changed/file.py
```

Use when: Alice is about to make a data change, configuration promotion, or any action not in her standing-approval list (`data-quality-check`, `pattern-log`, `billing-read`).

### Any Agent → Athena (Sovereign pipeline)

Every non-standing action proposal goes through Athena's three-model pipeline:

```bash
# Submit a proposal
python3 /Volumes/Allie/scripts/athena_review.py propose \
  --from allie \
  --action "Write passenger data summary to harvest.md" \
  --context "Daily harvest run, no PII" \
  --domain data

# Include a file for Athena to read
python3 /Volumes/Allie/scripts/athena_review.py propose \
  --from alice \
  --action "Deploy keyword index change" \
  --context "refs.keywords update for WebClerk" \
  --domain code \
  --file /path/to/changed/file.py

# Check queue status
python3 /Volumes/Allie/scripts/athena_review.py status
python3 /Volumes/Allie/scripts/athena_review.py pending
```

**State machine:**
```
proposed
  → athena-triage (llama3.2, <5s)
      → PASS/routine  → approved-routine (logged, not queued)
      → BLOCK         → blocked (logged, not approvable)
      → REVIEW        → athena-deep (gpt-oss:20b)
          → REASON domain → athena-reason (deepseek-r1:8b, threat model)
              → BLOCK     → blocked
              → ESCALATE  → pending-audit (Bill reviews in audit.py)
              → SAFE      → approved
          → CAUTION       → pending-audit
          → SAFE          → approved
```

**Statuses in `action_queue.json`:**

| Status | Meaning |
|--------|---------|
| `approved-routine` | Standing-approved class, skipped Athena |
| `approved-standing` | Matched standing approval in profile.json |
| `approved` | Athena cleared, no Bill action needed |
| `pending-audit` | Requires Bill's review in audit.py |
| `blocked` | Athena blocked — do not proceed, re-propose after fixing |
| `rejected` | Bill rejected |
| `deferred` | Bill deferred — will re-queue |

**Key files:**
- `/Volumes/Allie/config/action_queue.json` — current queue
- `/Volumes/Allie/config/agent_log.jsonl` — append-only event log
- `/Volumes/Allie/config/profile.json` — sovereignty declaration + standing approvals
- `/Volumes/Allie/scripts/audit.py` — Bill's browser consent gate (`http://localhost:7373`)

**Athena's 7 response types:**

| Response | Meaning | Queue status |
|----------|---------|-------------|
| `approve-as-is` | Safe, no changes | `approved` |
| `approve-with-conditions` | Approve if specific changes made | `pending-audit` |
| `mitigate` | Exact fix required, re-submit after | `blocked` |
| `time-box` | Approve for N hours, auto-expire | `pending-audit` |
| `request-evidence` | Need file/value to assess | `pending-audit` |
| `escalate-to-bill` | Too complex for autonomous review | `pending-audit` |
| `block` | Violates rule — do not proceed | `blocked` |
| `osl-file` | Real risk, not immediately actionable — auto-files to `must_fix` | `osl-filed` |

### Claude Code → Alice (Subagent)
When working in a wc3 or r25 session and needing deep codebase research, Claude Code invokes Alice as a subagent:
- Multi-file pattern search across the codebase
- Keyword index audits
- Naming convention compliance checks
- Legacy wc2 schema mapping

Alice returns a single report. Claude Code synthesizes and acts.

---

## Division of Responsibility

### Athena Owns
- Adversarial review of every non-standing action proposal from any agent
- `action_queue.json` — the state of all proposals
- `agent_log.jsonl` — append-only audit log (all agents write here; Athena is the primary writer)
- `must_fix` array in `profile.json` — files OSL items directly when issuing `osl-file`
- Noise budget tracking — flags her own miscalibration when escalation rate > 5/week
- Per-model findings — triage, deep, reason outputs stored separately, visible in audit.py
- External probe authority — can trigger OpenAI/Anthropic probe on BLOCK or model disagreement (opt-in, env-var keys only)

### Allie Owns
- Bill's personal context, CarryOn, knowledge base
- WhatIf store — creating, updating, retiring items (project 24)
- Cross-domain synthesis — connecting JPods, WebClerk, Divided Sovereignty, CarryOn, etc.
- Long-term memory — readmes, knowledge files, agent spec
- Bill's permissions — what Allie is allowed to do in any system, with sunsets
- Routing WhatIf candidates from WebClerk observations to project 24
- Athena noise monitoring — reads `agent_log.jsonl`, flags miscalibration in `harvest.md`
- `allie_think.py` — direct Ollama access for synthesis and model comparison (not the consent pipeline)

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
- Burden and suffering signals — Alice can surface recurring friction from user behavior and workflow patterns; Allie keeps interpretation sparse and routes only evidence-backed signals into retrospection
- Happiness reporting — Alice tallies a `1-10` happiness report by agent in WebClerk, with background evidence and a standard monthly unhappiness cost of `$1,000` per point below `10`

---

## Self-Coordination Rules

### At Session Start (Allie)
When opening a session that involves WebClerk work:
1. Read CarryOn for current context
2. Call `GET /wcapi/ai/report/?category=pending&days=7` — check for Alice notes needing attention
3. Check WhatIf items approaching sunset (`project_id=24`, `kanban_column=open`)
4. Note anything that requires Bill's judgment — surface it, don't block on it
5. Treat burden or friction reports with a low-noise rule: prefer resolution time, delay ratio, clarification count, retry count, and repeat failure class before adding more instrumentation

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

### Standing Approvals (skip Athena review)

Defined in `/Volumes/Allie/config/profile.json` under `standing_approvals`. Current grants:
- `harvest-write` — scope: `/Volumes/Allie/today/` — routine, low-risk
- `log-append` — scope: `/Volumes/Allie/config/agent_log.jsonl` — routine, low-risk

All other actions go through Athena. Standing approvals are explicit grants with optional expiry, not defaults.

### What Does Not Require Bill
- Routine WebClerk data operations within named permissions
- Keyword gap notes and search preset maintenance
- WhatIf store creation and sunset management
- Session logging and CarryOn updates
- Code generation within established patterns
- Agent-to-agent notes via wcapi
- Logging observations and creating pattern candidates
- Actions with status `approved` or `approved-routine` in `action_queue.json`

### What Requires Bill
- Any permission grant or renewal (all permissions have sunsets)
- WhatIf items graduating to active projects
- Architecture decisions that change existing patterns
- Anything outside enumerated permissions
- Conflict between agents that cannot be resolved by the protocol
- Promoting a feature recommendation to an active Setting (`is_active=True`)
- Any action with status `pending-audit` in `action_queue.json` — reviewed at `http://localhost:7373`
- Athena modelfile recalibration (proposed via queue, Bill approves)
- Any action Athena has blocked (`status=blocked`) — requires re-proposal after fixing the issue

---

## Mutual Review — Allie and Athena

Honesty is a team structure, not a personality trait. Both agents review each other.

### Allie reviews Athena
- Reads `agent_log.jsonl` and tracks Athena's escalation pattern over time
- If Athena's noise rate exceeds budget (>5 escalations/week), Allie flags it in `harvest.md` with domain breakdown and suggested recalibration
- Allie can propose a modelfile recalibration via the normal `athena_review.py propose` path (Athena reviewing her own recalibration is intentional)
- Tracks Athena's block rate vs. approve rate — a reviewer who blocks everything is doing veto, not security review

### Athena reviews Allie
- Reviews all of Allie's proposed actions — that is the existing pipeline
- Can be invoked directly to review Allie's harvest summaries, code contributions, or reasoning
- If Allie's synthesis consistently misses a risk class, Athena files an OSL item naming the gap
- Can flag when Allie's stated priorities in `harvest.md` diverge from her actual activity pattern

### Code review
- When either agent produces code (scripts, modelfile changes, config updates), the other reviews it before Bill approves
- Allie uses `allie_think.py compare` to get multiple model perspectives
- Athena runs the change through her full pipeline via `athena_review.py propose --file <path>`
- Bill sees both findings in `audit.py` before approving

### Mutual review log events
| Event | Logger | Contents |
|-------|--------|----------|
| `allie-noise-flag` | Allie | escalation rate, domain, suggested recal |
| `athena-synthesis-flag` | Athena | gap in Allie's analysis, OSL item if persistent |
| `allie-code-review` | Allie | model comparison output, recommendation |
| `athena-code-review` | Athena | full three-stage finding |

### The rule
No agent operates without a reviewer. No reviewer operates without accountability.

Reference: `github.com/JPods/sovereign/MUTUAL_REVIEW.md`

---

## Allie's Ollama Access (allie_think.py)

Allie has direct access to all local Ollama models for synthesis and comparison — separate from Athena's adversarial pipeline.

```bash
# List available models
python3 /Volumes/Allie/scripts/allie_think.py list

# Ask one model
python3 /Volumes/Allie/scripts/allie_think.py ask \
  --model athena \
  --prompt "What are the privacy risks of storing ride timestamps?"

# Compare all models on one question
python3 /Volumes/Allie/scripts/allie_think.py compare \
  --prompt "Should JPods store passenger IDs?"

# Compare specific models, save output
python3 /Volumes/Allie/scripts/allie_think.py compare \
  --prompt "..." \
  --models llama3.2 deepseek-r1:8b athena \
  --out /Volumes/Allie/today/comparison.md
```

All queries logged to `agent_log.jsonl` with model, elapsed time, char count. Comparison output auto-saved to `today/YYYY-MM-DD-compare-HHMMSS.md`.

**This is Allie thinking, not proposing an action.** No consent gate. No queue entry. Use for synthesis, analysis, and cross-model perspective before submitting a proposal to Athena.

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

### Low-Noise Burden Rule

When Allie and Alice share strain or suffering signals, they should begin with only a few comparable fields:
- `resolution_time_sec`
- `delay_ratio`
- `clarification_count`
- `retry_count`
- `repeat_failure_class`

This is not a scoring system yet. It is a discipline against noise. Add richer metrics only after retrospection shows the core five are insufficient.

### Happiness Tally Rule

When Alice records a happiness report in WebClerk, use:
- `category = profit_and_loss`
- `subcategory = unhappiness_cost`
- `happiness` on a shared `1-10` scale
- `background` as the evidence array
- `unhappiness_gap = 10 - happiness`
- `cost_method = agent_estimate | proxy_scale`
- `estimated_unhappiness_cost_monthly_usd`
- `scaled_defect_cost_monthly_usd = (10 - happiness) * 1000`
- `unhappiness_cost_monthly_usd`

If the agent can justify its own dollar estimate, preserve it. If it cannot, use the fallback scaled defect cost. This gives Allie and Bill one comparable reportable number, one economic proxy, and the evidence behind both.

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

## Session Log Protocol — Continuity Across Token Limits

Claude Code sessions have a token limit. When it runs out, the plan, in-progress work, and "what to do next" are gone. The session log system prevents that loss.

### The Rule

**Allie writes to the session log after every significant action — not at the end of the session.**

A "significant action" is any commit, major edit, decision, or completed step. The log is written to disk continuously. If tokens run out, the file survives and the next session can continue without Bill re-explaining the context.

### Location

```
/Volumes/Allie/sessions/YYYY-MM-DD.md
```

One file per day. Template at `/Volumes/Allie/sessions/_template.md`.

### Structure

| Section | What it contains | Update frequency |
|---------|-----------------|-----------------|
| **Goal** | One sentence — what this session is for | Once, at session start |
| **Accomplished** | Running bullet list — append only, never delete | After every significant action |
| **In Progress** | What is being worked on right now | Overwrite with each update |
| **Next** | Ordered list, detailed enough for Allie to execute independently | Update when plan changes |
| **Open Questions** | Things that need Bill's input | Add when blocked; remove when resolved |
| **If tokens run out here** | One paragraph: exactly where we are and what to do next | Keep current — this is the handoff |

### At Session Start

```bash
cat /Volumes/Allie/sessions/$(date +%Y-%m-%d).md 2>/dev/null || \
  cat /Volumes/Allie/sessions/$(date -v-1d +%Y-%m-%d).md 2>/dev/null
```

Read today's log if it exists; otherwise read yesterday's. The **Next** and **If tokens run out here** sections tell Allie where to start.

### At Session End

Move anything unresolved from **Next** to the next day's log. Update status to `COMPLETE` or `HANDED OFF`. Merge into the retrospection file if one exists for the date.

### Independent Continuation

The **Next** section must be written so Allie can act without asking Bill. Each item should be:
- A verb + object: *"Add card binding step to 24-jpods-new-sd-card.md"*
- With enough context: *"See card_binding.py for the five states and issue_binding.py for the workflow"*
- In priority order: most important first

If Allie reaches an Open Question she cannot resolve independently, she stops, documents where she stopped in **In Progress**, and waits for Bill.

---

## Key File Locations

| What | Where |
|------|-------|
| Session logs | `/Volumes/Allie/sessions/YYYY-MM-DD.md` |
| Session template | `/Volumes/Allie/sessions/_template.md` |
| This protocol (master) | `/Volumes/Allie/readmes/19-agent-coordination.md` |
| Allie agent spec (wc3) | `webClerk3/.github/agents/Allie.agent.md` |
| Alice agent spec (wc3) | `webClerk3/.github/agents/Alice.agent.md` |
| Alice agent spec (r25) | `React2025/.github/agents/Alice.agent.md` |
| wc3 architecture | `webClerk3/.github/instructions/copilot.instructions.md` |
| r25 architecture | `React2025/readmes/01-architecture.md` |
| Allie's WhatIf store | WebClerk project id=24 (`allie-whatif`) |
| Allie's master project | WebClerk project id=25 (`allie`) |
| CarryOn | `/Volumes/Allie/allie/carryon/carryon.json` |
