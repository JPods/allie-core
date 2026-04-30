# Startup, Running & Shutdown Protocol
**For Allie, Alice, and Claude Code in wc3/r25**

---

## Why Protocol Matters

Continuity lives in files — CarryOn, alice_log, WhatIf store, session logs. Without a proper shutdown, context is lost. Without a proper startup, agents begin blind. The protocols below are short and must be followed every session.

---

## Allie — Startup

### Step 1: Allie is always running

Allie runs from `/Users/williamjames/Allie/` — no external drive required. Three LaunchAgents start automatically on login:

| Service | What it does |
|---------|-------------|
| `com.allie.watcher` | File change monitoring + app detection; logs to `today/YYYY-MM-DD-activity.log` |
| `com.allie.sync` | Backs up to `/Volumes/Allie/` when external drive is mounted |
| `com.webclerk.server` | Starts Django + Celery + Ollama via `runserver.sh local`; serves on port 8000 |

Open a session simply with:
```bash
cd /Users/williamjames/Allie && claude
```

To reload a service after a plist change:
```bash
launchctl unload ~/Library/LaunchAgents/com.allie.watcher.plist
launchctl load   ~/Library/LaunchAgents/com.allie.watcher.plist
```

### Step 2: Orient (Allie does this automatically on first message)

1. Read `allie/carryon/carryon.json` — restore context, note elapsed time
2. Check `dashboards.mode` — offline / online / hybrid
3. Surface pending items (`dt_processed: 0`) and open threads
4. Check `allie/inbox/` for new documents
5. **If online:** `GET /wcapi/ai/report/?category=pending&role=config_suggestion&days=7` — Alice's pattern candidates
6. **If online:** Check WhatIf items in project 24 with sunset within 7 days
7. Give Bill a brief status — no narration

### Step 3: Context Depth Check

| Situation | Action |
|-----------|--------|
| Session after 3+ days away | Re-read relevant project readme before starting |
| Domain not touched recently | Read that domain's readme first |
| Cold start / first session | Read `11-bill-sovereignty-framework.md` → `19-agent-coordination.md` → relevant readme |
| CarryOn references a readme by name | Read it |

---

## Allie — Running

**Mid-session CarryOn checkpoint** (long sessions or before risky actions):
> "Update CarryOn with what we've done so far."

**WhatIf capture** — when an observation during the session is worth testing:
- Create an action in project 24 via wcapi immediately — don't wait for shutdown
- One sentence hypothesis, one sentence probe action, sunset date

**Alice pattern candidates** — if `config_suggestion` notes surface during work, action them before shutdown (promote, WhatIf, or resolve with reason). Don't accumulate.

---

## Allie — Shutdown

Tell Allie:
> "Allie, update CarryOn and shut down."

She will:

1. Update `allie/carryon/carryon.json`:
   - `log.last_session` — date and session summary
   - `log.entries` — clear after summarizing
   - `pending` — mark processed; add new with `dt_processed: 0`
   - `custom.open_threads` — add new, close resolved
   - `recent` — files and projects touched
2. **If WebClerk reachable:**
   - Log session: `POST /wcapi/ai/note/` `category=log, role=system`
   - Create WhatIf actions (project 24) from any session observations not yet captured
   - Resolve any actioned `alice_pending` items
3. Move completed workspace files to knowledge directories
4. Archive anything retired
5. Prompt Bill to backup if significant work was done.

   The sync agent (`com.allie.sync`) runs automatically when a drive mounts. To trigger manually:

   ```bash
   # See which Allie drives are mounted
   /Users/williamjames/Allie/scripts/allie-sync.sh status

   # Bidirectional sync: internal ↔ all mounted drives (newest file wins; nothing deleted)
   /Users/williamjames/Allie/scripts/allie-sync.sh auto

   # Push only: internal → all mounted drives
   /Users/williamjames/Allie/scripts/allie-sync.sh push
   ```

   Three drives:
   | Drive | Path | Role |
   |-------|------|------|
   | Internal | `~/Allie` | Working copy — always available |
   | 5TB | `/Volumes/Allie` | Home base archive |
   | Lexar | `/Volumes/Allie_Lexar` | Travel companion |

   Sync log: `~/Allie/today/YYYY-MM-DD-sync.log`

6. Confirm CarryOn is written

The external drives are backup targets. No need to eject between sessions — Allie runs locally regardless.

---

## Claude Code in wc3/r25 — Startup

When opening a wc3 or r25 coding session:

1. Read `copilot.instructions.md` — architecture, conventions, patterns
2. Read the relevant app readme for the work at hand
3. Check `.copilot-context/` for model reference before reading source
4. Check: has `generate_context` been run since the last migration? If not, run it before starting

---

## Claude Code in wc3/r25 — Running

**After any `makemigrations`:**
```bash
python manage.py migrate
python manage.py generate_context
```

**After the generate_context run:**
```bash
python manage.py index_docs --source copilot_context
```

**When crossing into Alice's domain** (search, keyword indexing, alice notes): invoke Alice as a subagent rather than acting directly. Alice owns those files.

**When spotting a cross-domain pattern** (connects to JPods, CarryOn, sovereignty framework, or anything beyond wc3/r25): create an `alice_pending` note with `role=action_required, details.for="allie"` so Allie picks it up at next session.

---

## Claude Code in wc3/r25 — Shutdown

Before closing a wc3/r25 session:

1. Confirm no uncommitted work that should be saved
2. If schema changed: confirm `generate_context` was run
3. Log significant sessions:
```bash
cd /Users/williamjames/Documents/CommerceExpert/webClerk3
./bin/python manage.py log_session --type <feature|bugfix|refactor|docs> \
  --problem "..." --solution "..." --learnings "..." --apps <app> --tags "<tags>"
```
4. Check for unresolved `alice_pending` items created this session

---

## Alice — Startup

Alice is stateless between sessions — she has no CarryOn equivalent. Her "startup" is reading the relevant context for the task at hand:

1. For search/keyword work: read `readmes/topics/architecture/keyword-denormalization-and-search.md`
2. For pattern recognition: read `readmes/topics/ai/pattern-recognition.md`
3. Check open alice_pending items: `GET /wcapi/ai/report/?category=pending&days=14`
4. Note any items with `details.for="allie"` that need routing

---

## Alice — Running

**Observation thresholds** — create `alice_pending config_suggestion` when:

| Pattern | Threshold |
|---------|-----------|
| Repeated search query | 5+ times / 7 days |
| Repeated filter | 5+ times / 7 days |
| Repeated sort | 3+ sessions |
| Zero-result search | 1 occurrence |
| Negative search feedback | 1 occurrence (auto-creates `keyword_gap`) |

**Route to Allie** (not to Bill) when the pattern has cross-domain implications or requires broader context judgment.

---

## Alice — Shutdown

Alice has no physical shutdown. At the end of any maintenance session:

1. Ensure all pending items created are properly formed (owner, next action, sunset equivalent)
2. Log health check if one was run
3. Confirm no half-resolved pending items left open without reason

---

## Troubleshooting

**Watcher not running:**
- Check: `cat /tmp/allie-watcher.pid` — if missing, watcher exited
- Reload: `launchctl unload ~/Library/LaunchAgents/com.allie.watcher.plist && launchctl load ~/Library/LaunchAgents/com.allie.watcher.plist`
- Tail log: `tail -f /Users/williamjames/Allie/today/$(date +%Y-%m-%d)-activity.log`

**WebClerk not starting:**
- Check: `lsof -ti:8000` — if empty, Django did not start
- Check logs: `tail -50 /tmp/webclerk-stderr.log`
- Reload: `launchctl unload ~/Library/LaunchAgents/com.webclerk.server.plist && launchctl load ~/Library/LaunchAgents/com.webclerk.server.plist`

**External drive not mounting (backup only — Allie still runs without it):**
- Check USB-C cable; try a different port
- Verify drive is named `Allie` in Disk Utility
- Sync will catch up automatically when drive is available

**CarryOn missing or corrupted:**
- Check `allie/carryon/carryon.json` directly
- If missing: tell Allie the current context and have her rebuild from `09-carryon.md` template

**WebClerk unreachable at startup:**
- Skip steps 5 and 6 of Allie's startup
- Note in CarryOn that WebClerk check was skipped
- Run it manually when connectivity returns: `GET /wcapi/ai/report/?category=pending&days=7`

**Claude Code context feels stale in wc3:**
- Run `python manage.py generate_context` to regenerate `.copilot-context/`
- Re-read `copilot.instructions.md`

**alice_pending backlog growing:**
- Run Alice's health check; report to Allie
- Allie reviews and routes each item: promote, WhatIf, or resolve
- Nothing should sit unactioned past its implied sunset
