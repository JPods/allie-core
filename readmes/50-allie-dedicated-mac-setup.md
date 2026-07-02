# Allie Dedicated Mac Setup Guide
**Created:** 2026-07-01
**Purpose:** Move Allie to a dedicated always-on 16GB Mac

## Why

When you close your laptop, Allie stops. Alice stops. Pattern detection stops.
The message bus goes quiet. A dedicated machine that never sleeps means the
team works while you don't.

A 16GB Mac comfortably runs:
- Ollama with gpt-oss:20b (13GB) — Allie's interactive brain
- PostgreSQL with the `allie` database — all agent data
- Scheduled jobs — alice-patterns every 4 hours, nightly reflection
- Vector stores — all three ChromaDB instances
- Agent message bus — always listening

It does NOT need to run:
- WC3 Django server (stays on your MacBook)
- React dev server (stays on your MacBook)
- Claude Code (stays on your MacBook)
- 70b models interactively (too big for 16GB — batch only via swap, or skip)

---

## Prerequisites

- Mac with 16GB RAM (M1/M2/M4 any variant)
- macOS 14+ (Sonoma or later)
- Network connection to your MacBook (same LAN)
- The 5TB drive (connects to this Mac instead of your MacBook)

---

## Step 1: Initial Mac Setup

### 1.1 Set the hostname
```bash
sudo scutil --set HostName allie-mac
sudo scutil --set LocalHostName allie-mac
sudo scutil --set ComputerName "Allie Mac"
```

### 1.2 Enable remote login (SSH)
System Settings → General → Sharing → Remote Login → ON

Test from your MacBook:
```bash
ssh williamjames@allie-mac.local
```

### 1.3 Prevent sleep
System Settings → Energy → Prevent automatic sleeping when display is off → ON
System Settings → Lock Screen → Turn display off → 1 hour (or Never)

### 1.4 Auto-login (optional but recommended for always-on)
System Settings → Users & Groups → Automatic Login → your user

---

## Step 2: Install Core Software

### 2.1 Homebrew
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### 2.2 PostgreSQL
```bash
brew install postgresql@16
brew services start postgresql@16

# Create the allie database
createdb allie
```

### 2.3 Python 3.13
```bash
brew install python@3.13
```

### 2.4 Ollama
```bash
curl -fsSL https://ollama.com/install.sh | sh

# Pull Allie's model (13GB — fits in 16GB RAM)
ollama pull gpt-oss:20b

# Pull embedding model (274MB)
ollama pull nomic-embed-text
```

### 2.5 Git
```bash
brew install git
```

---

## Step 3: Copy Allie

### 3.1 Clone from GitHub
```bash
cd ~
git clone https://github.com/JPods/allie-core.git Allie
```

### 3.2 Or rsync from your MacBook
```bash
# Run FROM your MacBook:
rsync -avz --exclude='.git' --exclude='venv' --exclude='archive' \
  --exclude='.chroma_db*' --exclude='__pycache__' \
  ~/Allie/ williamjames@allie-mac.local:~/Allie/
```

### 3.3 Create Allie's Python venv
```bash
cd ~/Allie
python3.13 -m venv source
source source/bin/activate
pip install chromadb psycopg2-binary ollama mcp
```

---

## Step 4: Set Up the Database

### 4.1 Import the schema from your MacBook
```bash
# Run FROM your MacBook — dump the allie database
pg_dump -h localhost -U williamjames allie > /tmp/allie_dump.sql

# Copy to Allie Mac
scp /tmp/allie_dump.sql williamjames@allie-mac.local:/tmp/

# Run ON Allie Mac — import
psql -U williamjames allie < /tmp/allie_dump.sql
```

### 4.2 Verify tables
```bash
psql -U williamjames allie -c "\dt"
```
Should show all 12 tables: sessions, claude_memory, tfts, observations,
agent_facets, vector_index, agent_messages, noelle_log, natalie_log,
sally_log, nora_log, alice_log.

### 4.3 Configure PostgreSQL for network access

Edit `postgresql.conf` (location: `brew info postgresql@16` shows the data dir):
```
listen_addresses = '*'
```

Edit `pg_hba.conf` — add your LAN:
```
host    all    all    192.168.0.0/16    trust
host    all    all    10.0.0.0/8        trust
```

Restart:
```bash
brew services restart postgresql@16
```

Test from your MacBook:
```bash
psql -h allie-mac.local -U williamjames allie -c "SELECT COUNT(*) FROM agent_messages;"
```

---

## Step 5: Configure Agent Bus for Network

### 5.1 On Allie Mac — agent_bus.py already works locally
```bash
~/Allie/source/bin/python ~/Allie/scripts/agent_bus.py inbox alice
```

### 5.2 On your MacBook — update the WC3 bridge to point to Allie Mac

Edit `/Users/williamjames/Documents/CommerceExpert/webClerk3/apps/core/services/agent_bus_bridge.py`:

Change:
```python
DB_HOST = 'localhost'
```
To:
```python
DB_HOST = os.environ.get('ALLIE_DB_HOST', 'allie-mac.local')
```

Or set the environment variable:
```bash
export ALLIE_DB_HOST=allie-mac.local
```

### 5.3 On your MacBook — update claude-vectorstore.py

Edit `~/Allie/scripts/claude-vectorstore.py`:
Change `DB_HOST = "localhost"` to:
```python
DB_HOST = os.environ.get('ALLIE_DB_HOST', 'localhost')
```

### 5.4 On your MacBook — update the MCP server

Edit `~/Allie/scripts/allie_db_mcp.py`:
Same change — read `ALLIE_DB_HOST` from environment, default to `localhost`.

This way everything works locally when Allie Mac is off, and over network when it's on.

---

## Step 6: Build Vector Stores on Allie Mac

```bash
cd ~/Allie

# Index Allie's knowledge
source/bin/python scripts/allie-vectorstore.py index

# Index Claude's session history
source/bin/python scripts/claude-vectorstore.py index
```

---

## Step 7: Set Up Scheduled Jobs

### 7.1 Copy launchd plists
```bash
mkdir -p ~/Library/LaunchAgents

# Alice pattern detection — every 4 hours
cp ~/Allie/config/com.allie.alice-patterns.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.allie.alice-patterns.plist

# Allie nightly reflection (if plist exists)
# cp ~/Allie/config/com.allie.nightly-reflect.plist ~/Library/LaunchAgents/
# launchctl load ~/Library/LaunchAgents/com.allie.nightly-reflect.plist
```

### 7.2 Create a vector re-index weekly job
```bash
cat > ~/Library/LaunchAgents/com.allie.weekly-reindex.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.allie.weekly-reindex</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>-c</string>
        <string>~/Allie/source/bin/python ~/Allie/scripts/allie-vectorstore.py index && ~/Allie/source/bin/python ~/Allie/scripts/claude-vectorstore.py index</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Weekday</key>
        <integer>0</integer>
        <key>Hour</key>
        <integer>3</integer>
    </dict>
    <key>StandardOutPath</key>
    <string>/Users/williamjames/Allie/logs/weekly-reindex.log</string>
    <key>StandardErrorPath</key>
    <string>/Users/williamjames/Allie/logs/weekly-reindex.log</string>
</dict>
</plist>
EOF
launchctl load ~/Library/LaunchAgents/com.allie.weekly-reindex.plist
```

### 7.3 Verify scheduled jobs
```bash
launchctl list | grep com.allie
```

---

## Step 8: Connect the 5TB Drive

### 8.1 Mount the 5TB on Allie Mac
Plug the drive in. It should mount at `/Volumes/Allie/`.

### 8.2 Set Ollama to use 5TB for large models
```bash
# Add to ~/.zshrc on Allie Mac:
export OLLAMA_MODELS=/Volumes/Allie/ollama_models

# Create the directory
mkdir -p /Volumes/Allie/ollama_models
```

### 8.3 Pull large models (stored on 5TB, run from swap when needed)
```bash
# These are for overnight batch use — too big for 16GB interactive
ollama pull qwen2.5:72b      # 43 GB — Allie deep reflection
ollama pull deepseek-r1:70b  # 43 GB — Noelle validation
ollama pull llama3.3:70b     # 43 GB — Alice coaching
```

The 20b model runs from RAM (fast, interactive). The 70b models run from
swap (slow but functional — fine for overnight batch jobs).

---

## Step 9: Sync Protocol

### 9.1 Allie Mac → your MacBook (knowledge sync)
When Allie Mac generates new reflections, observations, or messages,
your MacBook needs them for Claude Code sessions.

**Option A: Git push/pull** (recommended)
```bash
# On Allie Mac (cron or launchd, every hour):
cd ~/Allie && git add -A && git commit -m "auto-sync $(date +%Y%m%dT%H%M%S)" && git push

# On your MacBook (at session start):
cd ~/Allie && git pull
```

**Option B: rsync** (simpler but no history)
```bash
# On your MacBook, pull from Allie Mac:
rsync -avz williamjames@allie-mac.local:~/Allie/thoughts/ ~/Allie/thoughts/
rsync -avz williamjames@allie-mac.local:~/Allie/handoff/ ~/Allie/handoff/
```

### 9.2 Your MacBook → Allie Mac (session output sync)
After Claude Code sessions, push session files to Allie Mac so nightly
reflection can read them.

```bash
# Add to session-end protocol:
rsync -avz ~/Allie/sessions/ williamjames@allie-mac.local:~/Allie/sessions/
rsync -avz ~/Allie/process/inbox/ williamjames@allie-mac.local:~/Allie/process/inbox/
```

### 9.3 Database sync
The `allie` database on Allie Mac is the primary. Your MacBook reads
from it over the network. No sync needed — just point `ALLIE_DB_HOST`
to `allie-mac.local`.

If Allie Mac is offline, your MacBook falls back to its local PostgreSQL
(which may be stale). This is the same dual-hosting pattern as WC3.

---

## Step 10: Verify Everything

### From Allie Mac:
```bash
# Ollama working
ollama list

# Database working
psql -U williamjames allie -c "SELECT COUNT(*) FROM agent_messages;"

# Vector store working
~/Allie/source/bin/python ~/Allie/scripts/allie-vectorstore.py stats

# Agent bus working
~/Allie/source/bin/python ~/Allie/scripts/agent_bus.py inbox alice

# Scheduled jobs loaded
launchctl list | grep com.allie

# Model router working
~/Allie/source/bin/python ~/Allie/scripts/model-router.py info
```

### From your MacBook:
```bash
# SSH access
ssh williamjames@allie-mac.local "echo 'connected'"

# Database over network
psql -h allie-mac.local -U williamjames allie -c "SELECT COUNT(*) FROM agent_messages;"

# Agent bus over network
ALLIE_DB_HOST=allie-mac.local ~/Allie/source/bin/python ~/Allie/scripts/agent_bus.py inbox claude
```

---

## Network Architecture

```
┌─────────────────────────────────┐     ┌──────────────────────────────┐
│  Your MacBook Pro (32GB)        │     │  Allie Mac (16GB)            │
│                                 │     │                              │
│  Claude Code ◄──────────────────┼─────┼── allie DB (PostgreSQL)      │
│  WC3 Django server              │     │   agent_messages             │
│  React dev server               │     │   claude_memory              │
│  commerce_expert DB             │ LAN │   agent logs                 │
│  Ollama (interactive 20b)       │     │                              │
│                                 │     │  Ollama (20b interactive     │
│  Session start → reads allie DB │     │          70b batch overnight)│
│  Session end → writes allie DB  │     │                              │
│                                 │     │  Scheduled Jobs:             │
│                                 │     │   alice-patterns (4h)        │
│                                 │     │   allie-reflect (nightly)    │
│                                 │     │   vector re-index (weekly)   │
│                                 │     │                              │
│                                 │     │  Vector Stores (ChromaDB)    │
│                                 │     │  5TB Drive (models, archive) │
└─────────────────────────────────┘     └──────────────────────────────┘
```

---

## Troubleshooting

**Can't connect to Allie Mac PostgreSQL:**
```bash
# Check it's running
ssh allie-mac.local "brew services list | grep postgresql"
# Check it's listening on network
ssh allie-mac.local "lsof -i :5432"
# Check pg_hba.conf allows your IP
```

**Ollama model too slow on 16GB:**
The 70b models swap heavily on 16GB. Use them only for batch (nightly reflection).
For interactive, stick with gpt-oss:20b (fits in RAM).

**Vector store out of date:**
```bash
ssh allie-mac.local "~/Allie/source/bin/python ~/Allie/scripts/allie-vectorstore.py index"
```

**Allie Mac went to sleep:**
Check energy settings. Caffeinate as a temporary fix:
```bash
ssh allie-mac.local "caffeinate -d &"
```

---

## Cost

| Item | Cost | Notes |
|------|------|-------|
| Mac Mini M4 24GB | ~$800 | If buying new — 24GB minimum |
| Mac Mini M4 48GB | ~$1,200 | Ideal — runs 70b with less swap |
| Existing 16GB Mac | $0 | Works fine for 20b + scheduled jobs |
| 5TB drive | Already have | Connect to Allie Mac |
| Network | Already have | Same LAN |

Using an existing 16GB Mac costs nothing and gives Allie her own always-on brain.
