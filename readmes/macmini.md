# Mac Mini Setup — Allie Infrastructure
**Trigger:** Bill says "set up the Mac Mini"
**Status:** Ready to execute — waiting for hardware

---

## What This Builds

A dedicated always-on server for the JPods/Allie ecosystem:

| Service | What it does |
|---------|-------------|
| **Gitea** | Self-hosted Git — allie-core lives on JPods hardware |
| **Allie** | Always-on nightly reflect, harvest, and synthesis |
| **Ollama** | Local LLM for allie:latest — no cloud dependency |
| **LaunchAgents** | Allie scripts run on schedule without Bill's MacBook open |

GitHub stays as a public mirror. Mac Mini becomes `origin`.

---

## What I Need Before Starting

1. **Mac Mini's dedicated IP address** — e.g. `192.168.1.50`
2. **Architecture** — M-series (arm64) or Intel (amd64)
3. Confirm Mac Mini is on and SSH-accessible from Bill's MacBook

---

## Step 1 — Install Gitea

SSH into the Mac Mini from Bill's MacBook:
```bash
ssh bill@[MAC_MINI_IP]
```

**M-series (arm64):**
```bash
curl -L https://dl.gitea.com/gitea/1.21/gitea-1.21-darwin-arm64 \
  -o /usr/local/bin/gitea
chmod +x /usr/local/bin/gitea
```

**Intel (amd64):**
```bash
curl -L https://dl.gitea.com/gitea/1.21/gitea-1.21-darwin-amd64 \
  -o /usr/local/bin/gitea
chmod +x /usr/local/bin/gitea
```

Create Gitea home directory:
```bash
mkdir -p ~/gitea/custom/conf
mkdir -p ~/gitea/data
mkdir -p ~/gitea/log
```

First run (opens browser setup):
```bash
gitea web --port 3000 --work-path ~/gitea
```

**Browser setup at `http://[MAC_MINI_IP]:3000`:**
- Database: SQLite
- Repository root path: `~/gitea/data/repositories`
- Site title: `JPods Allie`
- Admin username: `jpods`
- Admin password: (choose one — record in Allie credentials)
- Click Install

---

## Step 2 — Create allie-core Repo on Gitea

In the Gitea web UI (`http://[MAC_MINI_IP]:3000`):
1. Sign in as `jpods`
2. New organization: `JPods`
3. New repository: `allie-core`, public, empty (no README)

---

## Step 3 — Run Gitea as a LaunchAgent (always-on)

On the Mac Mini, create `~/Library/LaunchAgents/com.jpods.gitea.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.jpods.gitea</string>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/local/bin/gitea</string>
    <string>web</string>
    <string>--port</string>
    <string>3000</string>
    <string>--work-path</string>
    <string>/Users/bill/gitea</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>StandardOutPath</key>
  <string>/Users/bill/gitea/log/gitea.log</string>
  <key>StandardErrorPath</key>
  <string>/Users/bill/gitea/log/gitea-error.log</string>
</dict>
</plist>
```

Load it:
```bash
launchctl load ~/Library/LaunchAgents/com.jpods.gitea.plist
```

Verify:
```bash
curl http://[MAC_MINI_IP]:3000
```

---

## Step 4 — Add Mac Mini as Primary Remote

On **Bill's MacBook**, in `~/Allie/`:
```bash
git remote add macmini http://[MAC_MINI_IP]:3000/JPods/allie-core.git
git push macmini main
```

Set macmini as the primary push target in `allie-reflect.py`:
Claude will update the push order — macmini first, GitHub second.

---

## Step 5 — Install Ollama on Mac Mini

```bash
curl -fsSL https://ollama.com/install.sh | sh
ollama pull allie:latest
```

Verify:
```bash
ollama run allie:latest "hello"
```

Update `allie-reflect.py` `OLLAMA_URL` to point at Mac Mini if running Allie there:
```python
OLLAMA_URL = "http://[MAC_MINI_IP]:11434/api/generate"
```

---

## Step 6 — Move Allie LaunchAgents to Mac Mini

Copy `~/Allie/scripts/` and `~/Library/LaunchAgents/com.allie.*` to Mac Mini.
Update paths in each `.plist` to match Mac Mini's username and Allie drive mount point.

Key agents to transfer:
- `com.allie.reflect` — nightly synthesis (01:00)
- `com.allie.icloud-sync` — iCloud sync watcher
- `com.allie.watcher` — event capture

---

## Step 7 — Update CLAUDE.md

Replace GitHub WebFetch fallback URL with Mac Mini URL:
```
WebFetch: http://[MAC_MINI_IP]:3000/JPods/allie-core/raw/branch/main/handoff/handoff.md
```

Add Mac Mini as the primary remote note.

---

## Remote Priority After Setup

| Remote | URL | Role |
|--------|-----|------|
| `macmini` | `http://[IP]:3000/JPods/allie-core.git` | Primary — push first |
| `origin` | `https://github.com/JPods/allie-core.git` | Mirror — push second |

`allie-reflect.py` pushes to both after every nightly run.

---

## Security Note

Running plain HTTP — no SSL, no key auth. Acceptable while on local network
with dedicated IP. When IP goes public, revisit:
- Add SSL cert (Let's Encrypt via Caddy reverse proxy)
- Add SSH key auth for git operations
- Athena reviews before public exposure

Full security upgrade: trigger phrase `"secure the Mac Mini"`.

---

## Quick Verification Checklist

- [ ] `curl http://[MAC_MINI_IP]:3000` → Gitea web UI responds
- [ ] `git push macmini main` → pushes without error
- [ ] `curl http://[MAC_MINI_IP]:3000/JPods/allie-core/raw/branch/main/handoff/handoff.md` → returns file
- [ ] `ollama run allie:latest "test"` → model responds
- [ ] Gitea LaunchAgent survives reboot
