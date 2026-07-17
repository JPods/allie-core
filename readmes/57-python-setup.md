# 57 — Python Setup: Single Framework

**Created:** 2026-07-16
**Status:** Active — cleanup in progress
**Rule:** One Python, one venv per project, Homebrew ARM only

---

## The Problem We Had

Multiple Python installations accumulated over years — Framework installs, Homebrew
Intel (x86 via Rosetta), Homebrew ARM, and python.org packages. Different projects
pointed to different Pythons. Venvs broke silently when the underlying install was
updated or removed. Debugging which Python was actually running required detective work.

---

## Target State

```
/opt/homebrew/bin/python3  →  Python 3.13 (Homebrew ARM)
                               │
                               ├── ~/Allie/venv/
                               ├── ~/Documents/CommerceExpert/webClerk3/venv/
                               ├── ~/Documents/MeshMobility/venv/
                               └── (one venv per project, always named "venv/")
```

**One Python. One venv per project. No exceptions.**

---

## Current Inventory (as of 2026-07-16)

### Installed Pythons — what stays, what goes

| Python | Location | Source | Status |
|--------|----------|--------|--------|
| 3.13.3 | `/opt/homebrew/bin/python3` | Homebrew ARM | **KEEP — primary** |
| 3.12.12 | `/opt/homebrew/bin/python3.12` | Homebrew ARM | **KEEP — brew dependency** |
| 3.13.3 | `/usr/local/bin/python3` | python.org Framework | **REMOVE** |
| 3.13t | `/usr/local/bin/python3.13t` | python.org free-threaded | **REMOVE** |
| 3.10.17 | `/usr/local/bin/python3.10` | Homebrew Intel | **REMOVE** |
| 3.9.22 | `/usr/local/bin/python3.9` | Homebrew Intel | **REMOVE** |
| 3.8 | `/usr/local/Cellar/python@3.8/` | Homebrew Intel | **REMOVE** |
| 3.7 | `/usr/local/Cellar/python@3.7/` | Homebrew Intel | **REMOVE** |
| 2.7 | `/Library/Frameworks/Python.framework/Versions/2.7/` | Framework (2022) | **REMOVE** |

### Venvs — what stays, what goes

| Venv | Python | Status |
|------|--------|--------|
| `~/Allie/venv/` | 3.13 Homebrew ARM | **KEEP — primary Allie venv** |
| `~/Allie/.venv/` | 3.13 Homebrew ARM (uv) | **REMOVE — duplicate** |
| `~/Allie/source/` | 3.13 Homebrew ARM | **REMOVE — accidental** |
| `~/Allie/and/` | 3.13 Homebrew ARM | **REMOVE — accidental** |
| `~/Allie/allie/source/` | 3.13 (assumed) | **REMOVE — accidental** |
| `~/Allie/allie/and/` | 3.13 (assumed) | **REMOVE — accidental** |
| `~/Documents/CommerceExpert/webClerk3/venv/` | 3.12 Homebrew ARM | **REBUILD on 3.13** |
| `~/Documents/CommerceExpert/webClerk3/venv312/` | 3.12 Homebrew ARM | **REMOVE — duplicate** |
| `~/Documents/CommerceExpert/webClerk3/pyvenv.cfg` | 3.13 (root-level, wrong) | **REMOVE** |
| `~/Documents/CommerceExpert/webClerk3-venv/` | 3.13 (outside project) | **REMOVE** |
| `~/Documents/CommerceExpert/Motors/.venv/` | 3.13 Framework (/usr/local) | **REBUILD on Homebrew** |

---

## Cleanup Steps

### Step 1 — Remove accidental and duplicate venvs

```bash
# Allie — keep only venv/
rm -rf ~/Allie/.venv
rm -rf ~/Allie/source
rm -rf ~/Allie/and
rm -rf ~/Allie/allie/source
rm -rf ~/Allie/allie/and

# WC3 — keep only venv/ (will rebuild)
rm -rf ~/Documents/CommerceExpert/webClerk3/venv312
rm -rf ~/Documents/CommerceExpert/webClerk3/pyvenv.cfg
rm -rf ~/Documents/CommerceExpert/webClerk3-venv
```

### Step 2 — Remove python.org Framework installs

```bash
# Python 2.7 Framework (from 2022)
sudo rm -rf /Library/Frameworks/Python.framework/Versions/2.7

# Python 3.13 Framework (python.org installer — NOT Homebrew)
sudo rm -rf /Library/Frameworks/Python.framework/Versions/3.13
sudo rm -rf /Library/Frameworks/PythonT.framework

# Remove Framework symlinks from /usr/local/bin
sudo rm -f /usr/local/bin/python3
sudo rm -f /usr/local/bin/python3-config
sudo rm -f /usr/local/bin/python3-intel64
sudo rm -f /usr/local/bin/python3.13
sudo rm -f /usr/local/bin/python3.13-config
sudo rm -f /usr/local/bin/python3.13-intel64
sudo rm -f /usr/local/bin/python3.13t
sudo rm -f /usr/local/bin/python3.13t-config
sudo rm -f /usr/local/bin/python3.13t-intel64
sudo rm -f /usr/local/bin/python3t
sudo rm -f /usr/local/bin/python3t-config
sudo rm -f /usr/local/bin/python3t-intel64
sudo rm -f /usr/local/bin/pythonw
sudo rm -f /usr/local/bin/pythonw2
sudo rm -f /usr/local/bin/pythonw2.7

# Remove Framework directory if empty
sudo rmdir /Library/Frameworks/Python.framework/Versions 2>/dev/null
sudo rmdir /Library/Frameworks/Python.framework 2>/dev/null
```

### Step 3 — Remove Homebrew Intel Pythons

```bash
# These live in /usr/local/Cellar (Intel Homebrew, via Rosetta)
/usr/local/bin/brew uninstall python@3.7
/usr/local/bin/brew uninstall python@3.8
/usr/local/bin/brew uninstall python@3.9
/usr/local/bin/brew uninstall python@3.10

# Check if anything depends on them first:
/usr/local/bin/brew uses --installed python@3.9
/usr/local/bin/brew uses --installed python@3.10
```

### Step 4 — Rebuild project venvs on Homebrew ARM Python 3.13

```bash
# WC3
cd ~/Documents/CommerceExpert/webClerk3
rm -rf venv
/opt/homebrew/bin/python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
python manage.py migrate  # verify

# Motors
cd ~/Documents/CommerceExpert/Motors
rm -rf .venv
/opt/homebrew/bin/python3 -m venv venv    # rename .venv → venv
source venv/bin/activate
pip install -r requirements.txt           # if exists

# MeshMobility
cd ~/Documents/MeshMobility
rm -rf venv
/opt/homebrew/bin/python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# Allie (verify existing venv is correct)
cd ~/Allie
source venv/bin/activate
python --version   # should say 3.13.3
which python       # should say ~/Allie/venv/bin/python
```

### Step 5 — Verify clean state

```bash
# Only these should exist:
which python3                          # /opt/homebrew/bin/python3
python3 --version                      # 3.13.3
ls /usr/local/bin/python*              # should be empty or only python3.10 remnants
ls /Library/Frameworks/Python*         # should not exist
find ~/Documents ~/Allie -name "pyvenv.cfg" -maxdepth 3
# Should show exactly:
#   ~/Allie/venv/pyvenv.cfg
#   ~/Documents/CommerceExpert/webClerk3/venv/pyvenv.cfg
#   ~/Documents/CommerceExpert/Motors/venv/pyvenv.cfg
#   ~/Documents/MeshMobility/venv/pyvenv.cfg
```

---

## Rules Going Forward

### 1. One Python installation

Homebrew ARM Python 3.13 at `/opt/homebrew/bin/python3`. No Framework installs,
no pyenv, no conda, no system Python for projects.

When Python 3.14 ships, upgrade via `brew upgrade python@3.13` → rebuild all venvs.

### 2. One venv per project, always named `venv/`

```bash
cd ~/project
/opt/homebrew/bin/python3 -m venv venv
source venv/bin/activate
```

Not `.venv`, not `venv312`, not `source`, not a venv outside the project directory.
Always `venv/`. Always inside the project root.

### 3. Always activate before running

```bash
source venv/bin/activate
python manage.py runserver   # uses venv Python
```

Never call `/opt/homebrew/bin/python3` directly for project work. The venv ensures
the right packages are available and isolated.

### 4. requirements.txt is the package manifest

Every project maintains `requirements.txt`. After adding a package:

```bash
pip install newpackage
pip freeze > requirements.txt
```

Rebuilding a venv from scratch:
```bash
rm -rf venv
/opt/homebrew/bin/python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

### 5. .gitignore excludes venvs

Every project's `.gitignore` includes:
```
venv/
```

Venvs are local, machine-specific, and reproducible from `requirements.txt`.

---

## GEEKOM IT15 — Ubuntu Server 24.04

When the GEEKOM arrives (~2026-07-20), services shift from macOS to Ubuntu.
Full deployment guide: `readmes/58-production-deployment.md`.

### Python on Ubuntu

```bash
# Ubuntu 24.04 ships Python 3.12. For 3.13:
sudo add-apt-repository ppa:deadsnakes/ppa
sudo apt update
sudo apt install -y python3.13 python3.13-venv python3.13-dev
```

Same rules apply: one venv per project, always named `venv/`, always activate first.
Ubuntu's system Python stays untouched — venvs isolate everything.

### What moves to Ubuntu (always-on)

| Service | macOS (current) | Ubuntu (GEEKOM) |
|---------|----------------|-----------------|
| **WC3 Django** | `./runserver.sh` (dev server) | Gunicorn + Nginx (production) |
| **Celery** | `./runserver.sh` (background) | systemd service (always on) |
| **PostgreSQL** | Homebrew, sleeps with MacBook | `apt install`, always on |
| **Redis** | Homebrew | `apt install`, always on |
| **MeshMobility** | manual terminal | systemd service (always on) |
| **Chroma** | embedded in MCP servers | standalone HTTP server, systemd |
| **CrashHarvester** | manual | systemd service (when needed) |
| **Nginx + SSL** | none | Let's Encrypt via certbot |
| **5TB Allie drive** | mounted when MacBook awake | USB-C, always mounted |

### What stays on MacBook

| Service | Why it stays |
|---------|-------------|
| **Ollama** (allie:latest) | Needs Apple Silicon unified memory (200 GB/s) |
| **Claude Code** | Interactive sessions with Bill |
| **SketchUp** | macOS only |
| **iCloud sync** | macOS only |
| **MCP servers** | stdio processes for Claude Code (connect to GEEKOM backends) |
| **Allie capture** | Writes to ~/Allie/ (synced to GEEKOM via 5TB) |

### macOS → Ubuntu translation

| macOS | Ubuntu | Notes |
|-------|--------|-------|
| `launchctl load/unload *.plist` | `systemctl enable/start/stop *.service` | |
| `~/Library/LaunchAgents/` | `/etc/systemd/system/` | |
| `brew install` | `apt install` | |
| `brew services start/stop` | `systemctl start/stop` | |
| `manage.py runserver` | `gunicorn wsgi:application` | Behind Nginx |
| `python3 -m celery ...` | systemd service | Auto-restart on failure |
| Homebrew Python 3.13 | deadsnakes PPA Python 3.13 | Same version, different source |
| `pkill -f` | `systemctl restart` | Managed services, not loose processes |
| No firewall | `ufw` — SSH + HTTP + HTTPS only | |
| No SSL | Let's Encrypt (certbot) | Auto-renews every 90 days |

### MCP servers after migration

MCP servers stay on MacBook as stdio processes for Claude Code. Only their
backend connection strings change:

```
Before:  localhost:5432  (PostgreSQL on MacBook)
After:   geekom:5432    (PostgreSQL on GEEKOM)

Before:  embedded Chroma (in-process)
After:   geekom:8100    (Chroma HTTP on GEEKOM)
```

### Startup after migration

**On GEEKOM** — everything starts automatically via systemd at boot:
```bash
# Check all services
sudo systemctl status webclerk3 webclerk3-celery meshmobility chroma postgresql redis nginx
```

**On MacBook** — same as today:
```bash
cd ~/Allie && claude       # Claude Code + MCP servers
ollama serve               # when needed for Allie LLM
```

No more `./runserver.sh`. No more terminal management. The GEEKOM runs services;
the MacBook runs interactive tools.

---

## Running Processes (cleaned up 2026-07-16)

All processes now run on Python 3.13.3 via venvs. Problems fixed:
- ~~`allie-api.py` on Xcode Python 3.9~~ → fixed launchd plist to use `~/Allie/venv/bin/python3`
- ~~`alice-patterns.py` on `/usr/bin/python3`~~ → fixed launchd plist
- ~~`allie-reflect.py` on `/usr/bin/python3`~~ → fixed launchd plist
- ~~WC3 `runserver.sh` using `bin/python`~~ → fixed to use `venv/bin/python`
- ~~WC3 `start_celery.sh` using `source bin/activate`~~ → fixed to `source venv/bin/activate`
- ~~Duplicate MCP servers from prior sessions~~ → killed, clean restart
- ~~WC3 venv on Python 3.12~~ → rebuilt on 3.13.3
- ~~MeshMobility `.venv`~~ → rebuilt as `venv/` on 3.13.3

---

## Startup Sequence — After Python Cleanup

Run these in order after a reboot or cleanup. Each step is a separate terminal
or background process. **Copy-paste each block exactly.**

### Terminal 1 — WC3 (Django + Celery)

```bash
cd ~/Documents/CommerceExpert/webClerk3
source venv/bin/activate
python manage.py runserver &
python -m celery -A webclerk3_api worker -l info --concurrency=2 -P solo --without-heartbeat -B -s /tmp/celerybeat-webclerk3-schedule &
```

Verify: Open http://localhost:8000/admin/ — should see Django admin.

### Terminal 2 — Allie API

```bash
cd ~/Allie
source venv/bin/activate
python scripts/allie-api.py --port 5001 &
```

Verify: `curl http://localhost:5001/health` — should respond.

### Terminal 3 — MCP Servers (for Claude Code)

These start automatically when Claude Code launches, but if you need to restart
them manually:

```bash
cd ~/Allie
source venv/bin/activate
python scripts/allie-mcp-server.py &
python scripts/alice-mcp-server.py &
python scripts/noelle-mcp-server.py &
python scripts/allie_db_mcp.py &
python scripts/commerce_db_mcp.py &
python scripts/wc_mcp_server.py &
```

### Terminal 4 — Ollama (for Allie LLM)

```bash
ollama serve &
# Wait a few seconds, then verify:
ollama list   # should show allie:latest
```

### Terminal 5 — MeshMobility (when needed)

```bash
cd ~/Documents/MeshMobility    # or wherever it lives
source venv/bin/activate
python api.py &
```

Verify: Open http://localhost:5000/ (or whatever port MeshMobility uses).

---

## Kill Everything (before restart)

If you need a clean slate:

```bash
# Kill all Python processes (careful — this kills EVERYTHING Python)
pkill -f python3

# Or be surgical — kill by name:
pkill -f allie-api.py
pkill -f allie-mcp-server.py
pkill -f alice-mcp-server.py
pkill -f noelle-mcp-server.py
pkill -f allie_db_mcp.py
pkill -f commerce_db_mcp.py
pkill -f wc_mcp_server.py
pkill -f "manage.py runserver"
pkill -f celery

# Verify nothing is left:
ps aux | grep python | grep -v grep
```

---

## Master Startup Guide — All Systems

Everything runs on Python 3.13.3 via project venvs. This is the single
reference for starting all systems after a reboot or cleanup.

### What Starts Automatically (launchd — at login)

| Service | What | Python | How to check |
|---------|------|--------|-------------|
| `com.allie.api` | Allie API on port 5001 | `~/Allie/venv/bin/python3` | `curl http://localhost:5001/health` |
| `com.allie.reflect` | Nightly synthesis at 10 PM | `~/Allie/venv/bin/python3` | `launchctl list \| grep reflect` |
| `com.allie.alice-patterns` | Pattern recognition every 4 hrs | `~/Allie/venv/bin/python3` | `launchctl list \| grep alice` |
| `com.allie.watcher` | File change monitoring | shell | `launchctl list \| grep watcher` |
| `com.allie.sync` | Backup to 5TB when mounted | shell | `launchctl list \| grep sync` |
| `com.allie.icloud-sync` | iCloud sync 60s after change | shell | `launchctl list \| grep icloud` |

**You don't need to start these.** They run at login. If one dies, restart with:
```bash
launchctl unload ~/Library/LaunchAgents/com.allie.api.plist
launchctl load   ~/Library/LaunchAgents/com.allie.api.plist
```

### What You Start Manually

#### 1. WC3 — Django + Celery (Terminal 1)

```bash
cd ~/Documents/CommerceExpert/webClerk3
./runserver.sh              # starts Django + Celery + Ollama
```

Or manually:
```bash
cd ~/Documents/CommerceExpert/webClerk3
source venv/bin/activate
python manage.py runserver &
python -m celery -A webclerk3_api worker -l info --concurrency=2 -P solo --without-heartbeat -B -s /tmp/celerybeat-webclerk3-schedule &
```

**Verify:** http://localhost:8000/admin/

**Startup script:** `runserver.sh` — accepts `local` or `remote` for DB mode.
Uses `venv/bin/python`. See `readmes/startup.md` in the WC3 repo for details.

#### 2. MeshMobility (Terminal 2 — when needed)

**Run from `00_working_code/`, not from inside `mesh_mobility/`.**
Python needs `mesh_mobility/` as a package below the cwd.

```bash
cd ~/Documents/08_JPods/03_Technology/00_working_code
source mesh_mobility/venv/bin/activate
python -m mesh_mobility.gui
```

**Verify:** http://localhost:5050/

**Note:** `CrashHarvester` symlink must exist in `00_working_code/`:
`CrashHarvester → crash_harvester`. MeshMobility imports from it.

#### 3. CrashHarvester API (Terminal 3 — when needed)

```bash
cd ~/Documents/08_JPods/03_Technology/00_working_code/crash_harvester
python3 -m crash_harvester serve --port 5055
```

**Verify:** http://localhost:5055/api/schema/crash

Note: CrashHarvester is also imported as a library by MeshMobility. The API
server is only needed when harvesting new data or serving standalone.

#### 4. Ollama — Allie LLM (Terminal 4 — when needed)

```bash
ollama serve
```

**Verify:** `ollama list` — should show `allie:latest`

Ollama is also started by `runserver.sh` if installed. Check if already running
before starting manually: `curl http://localhost:11434/api/tags`

#### 5. Claude Code (any terminal)

```bash
cd ~/Allie && claude
```

MCP servers start automatically with Claude Code. No manual action needed.

#### 6. JPods Robots / Pi Fleet (when needed)

See `readmes/23-jpods-robot-startup.md` for full robot startup sequence.

```bash
# On Mac — start MQTT broker
brew services start mosquitto

# On each Pi (SSH)
sudo python launcher.py 1 "<mac_ip>"
```

### Project Locations and venvs

| Project | Location | venv | requirements.txt |
|---------|----------|------|-----------------|
| **Allie** | `~/Allie/` | `venv/` (3.13.3) | in venv |
| **WC3** | `~/Documents/CommerceExpert/webClerk3/` | `venv/` (3.13.3) | `requirements.txt` |
| **MeshMobility** | `~/Documents/08_JPods/03_Technology/00_working_code/mesh_mobility/` | `venv/` (3.13.3) | `requirements.txt` |
| **CrashHarvester** | `~/Documents/08_JPods/03_Technology/00_working_code/crash_harvester/` | (uses MM venv or system) | — |
| **JPodsSM_RPi** | `~/Documents/08_JPods/03_Technology/00_working_code/JPodsSM_RPi/` | (runs on Pi) | — |
| **SketchUp Plugin** | `su_jpods/` (SketchUp Ruby) | N/A | N/A |

### Startup Docs in Each Project

| Project | Startup doc |
|---------|------------|
| **Allie** | `readmes/06-startup-shutdown.md` — LaunchAgents, orient sequence, shutdown |
| **Allie** | `readmes/57-python-setup.md` — this file (master overview) |
| **WC3** | `readmes/startup.md` — runserver.sh, DB modes, health checks |
| **WC3** | `readmes/02-dev-setup.md` — initial venv creation, testing |
| **MeshMobility** | `README.md` — quick start, links to readmes/ |
| **CrashHarvester** | `README.md` — CLI reference, API server |
| **JPodsSM_RPi** | `readmes/23-jpods-robot-startup.md` (in Allie) |

---

## Quick Reference

```bash
# Which Python am I using?
which python3              # should be /opt/homebrew/bin/python3
python3 --version          # should be 3.13.x

# Am I in a venv?
echo $VIRTUAL_ENV          # blank = no venv active

# Create a new project venv
/opt/homebrew/bin/python3 -m venv venv
source venv/bin/activate

# Rebuild a broken venv
rm -rf venv
/opt/homebrew/bin/python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# Find all venvs on the system
find ~/Documents ~/Allie -name "pyvenv.cfg" -maxdepth 3
```
