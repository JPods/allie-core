# 55 — Hybrid Server Architecture: GEEKOM + MacBook Pro

**Created:** 2026-07-14
**Updated:** 2026-07-16
**Status:** Active — GEEKOM IT15 ordered 2026-07-16, expected ~2026-07-20
**Decision:** Hybrid split — MacBook keeps Allie (LLM), GEEKOM hosts services + storage

---

## Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                       Home Network                            │
│                                                               │
│  ┌──────────────┐    Ethernet    ┌────────────────────────┐  │
│  │    Router     │──────────────▶│   GEEKOM IT15        │  │
│  └──────────────┘               │   Ultra 9 285H, 32GB     │  │
│         │                       │   Ubuntu Server 24.04   │  │
│        WiFi                     │                          │  │
│         │                       │   USB-C:                 │  │
│  ┌──────────────┐               │   ┌──────────────────┐  │  │
│  │  MacBook Pro  │              │   │ 5TB Allie Drive   │  │  │
│  │  M1 Max 32GB  │             │   │ (always mounted)  │  │  │
│  │               │              │   └──────────────────┘  │  │
│  │  Allie (LLM)  │             └────────────────────────┘  │
│  │  Claude Code   │                                         │
│  │  SketchUp      │   Lexar: USB-C to whichever machine    │
│  └──────────────┘                                           │
└──────────────────────────────────────────────────────────────┘
```

### What runs where

| MacBook Pro M1 Max | GEEKOM IT15 |
|-------------------|---------------|
| **Ollama** — allie:latest (20b), agent models | **PostgreSQL** — commerce_expert |
| **Allie intelligence** — reflect, whatif, synthesis | **Django** — WC3 backend (0.0.0.0:8000) |
| **Claude Code** — sessions, MCP clients | **React** — dev servers (5173-5176) |
| **SketchUp** — plugin development | **MeshMobility** — simulations (5000) |
| **iCloud sync** — launchd agent | **Chroma** — Alice + Noelle vector stores (8100) |
| **Capture pipeline** — _allie_capture writes | **5TB Allie drive** — always mounted, NFS shared |
| **Browser** — Chrome, DevTools | **Backups** — allie-sync.sh (local disk-to-disk) |

### Why this split works

The MacBook keeps what needs Apple Silicon unified memory (LLM inference at 200 GB/s
bandwidth) and what needs macOS (iCloud sync, SketchUp, launchd agents).

The GEEKOM runs what needs to be always-on and doesn't need an LLM: database, web
servers, simulations, vector stores, persistent storage. 32GB is generous for this
workload — no Ollama means no memory pressure.

**The problem this solves:** When Bill closes his MacBook, PostgreSQL, WC3, MeshMobility,
and the 5TB all go offline. The GEEKOM stays on 24/7. Allie (Ollama) still sleeps with
the MacBook — that's acceptable because LLM queries only happen during active sessions.

---

## GEEKOM Memory Budget (32GB, Ubuntu Server)

| Consumer | Estimate | Notes |
|----------|----------|-------|
| Ubuntu Server (headless) | 1-2 GB | No desktop environment |
| PostgreSQL | 4-6 GB | Full tuning room |
| Django (WC3 backend) | 1-2 GB | Single process + workers |
| React dev servers (×4) | 2-4 GB | Vite HMR — consider `npm run build` for idle servers |
| MeshMobility | 2-4 GB | Python + network data, always available |
| Chroma (Alice + Noelle) | 2-4 GB | 53K+ chunks, HTTP mode |
| NFS server overhead | <1 GB | Serving 5TB to MacBook |
| **Total** | **13-23 GB** | |
| **Headroom** | **9-19 GB** | Room to grow |

---

## MCP Server Wiring (after migration)

| MCP Server | Runs on | Connects to | Config change |
|------------|---------|-------------|--------------|
| **allie** | MacBook (stdio) | Ollama on MacBook (localhost:11434) | None |
| **commerce-db** | MacBook (stdio) | PostgreSQL on GEEKOM (geekom:5432) | Change DB host |
| **alice** | MacBook (stdio) | Chroma on GEEKOM (geekom:8100) | Change Chroma URL |
| **noelle** | MacBook (stdio) | Chroma on GEEKOM (geekom:8100) | Change Chroma URL |
| **chrome-devtools** | MacBook | Browser on MacBook (localhost) | None |

All MCP servers stay as stdio processes on the MacBook. Only their backend connection
strings change to point at the GEEKOM. No SSH tunnels, no HTTP adapters needed.

---

## Migration Steps

### Phase 0 — Inventory (before GEEKOM arrives)

While everything runs on the MacBook, dump the current state:

```bash
mkdir -p ~/Desktop/geekom-migration

# Running services
brew services list > ~/Desktop/geekom-migration/brew-services.txt
launchctl list | grep -E "com\.(allie|jpods)" > ~/Desktop/geekom-migration/launchd-agents.txt

# MCP server configs
cp ~/.claude/settings.json ~/Desktop/geekom-migration/mcp-config.json

# Credential files (inventory only — transfer via Lexar)
ls -la ~/Allie/config/allie_api_keys.json ~/Allie/config/wc_credentials.json

# PostgreSQL database size
psql -c "SELECT pg_size_pretty(pg_database_size('commerce_expert'));"

# Python packages (WC3 + MeshMobility)
pip freeze > ~/Desktop/geekom-migration/pip-freeze.txt

# Chroma store sizes
du -sh ~/.chroma_db_* ~/Allie/.chroma_db_* > ~/Desktop/geekom-migration/chroma-sizes.txt
```

### Phase 1 — GEEKOM setup (day 1)

1. **Install Ubuntu Server 24.04 LTS** (wipe Windows 11 Pro)
   - Boot from USB installer
   - Minimal install — no desktop environment
   - Set hostname: `geekom`
   - Create user: `bill`
   - Enable OpenSSH server during install
   - Connect Ethernet to router

2. **Static IP**
   ```bash
   # On GEEKOM — edit netplan
   sudo nano /etc/netplan/01-netcfg.yaml
   ```
   ```yaml
   network:
     version: 2
     ethernets:
       enp1s0:  # verify interface name with `ip a`
         dhcp4: no
         addresses: [192.168.1.50/24]
         routes:
           - to: default
             via: 192.168.1.1
         nameservers:
           addresses: [8.8.8.8, 8.8.4.4]
   ```
   ```bash
   sudo netplan apply
   ```

3. **Add to MacBook /etc/hosts**
   ```
   192.168.1.50   geekom
   ```

4. **SSH key access** (from MacBook)
   ```bash
   ssh-copy-id bill@geekom
   ssh bill@geekom   # verify passwordless
   ```

5. **Mount 5TB Allie drive**
   ```bash
   # On GEEKOM
   sudo apt install exfatprogs   # if drive is exFAT
   sudo mkdir -p /mnt/allie5tb
   # Find drive UUID
   sudo blkid
   # Add to /etc/fstab for auto-mount
   echo "UUID=<drive-uuid> /mnt/allie5tb exfat defaults,nofail 0 0" | sudo tee -a /etc/fstab
   sudo mount -a
   ls /mnt/allie5tb/readmes/   # verify
   ```

6. **NFS share the 5TB to MacBook**
   ```bash
   sudo apt install nfs-kernel-server
   echo "/mnt/allie5tb 192.168.1.0/24(ro,sync,no_subtree_check)" | sudo tee -a /etc/exports
   sudo exportfs -ra
   sudo systemctl enable nfs-kernel-server
   ```
   On MacBook:
   ```bash
   sudo mkdir -p /Volumes/Allie
   sudo mount -t nfs geekom:/mnt/allie5tb /Volumes/Allie
   # Add to /etc/fstab for persistence (or mount on demand)
   ```

### Phase 2 — PostgreSQL (day 1)

1. **Install and configure**
   ```bash
   sudo apt install postgresql-16
   sudo systemctl enable postgresql

   # Allow network connections
   sudo nano /etc/postgresql/16/main/postgresql.conf
   # listen_addresses = '0.0.0.0'

   sudo nano /etc/postgresql/16/main/pg_hba.conf
   # Add: host all bill 192.168.1.0/24 md5

   sudo systemctl restart postgresql
   ```

2. **Export from MacBook, import on GEEKOM**
   ```bash
   # On MacBook
   pg_dump -Fc commerce_expert > ~/Desktop/commerce_expert.dump
   scp ~/Desktop/commerce_expert.dump bill@geekom:~/

   # On GEEKOM
   sudo -u postgres createuser bill
   sudo -u postgres createdb -O bill commerce_expert
   pg_restore -d commerce_expert ~/commerce_expert.dump
   ```

3. **Test from MacBook**
   ```bash
   psql -h geekom -d commerce_expert -c "SELECT count(*) FROM contacts_contact;"
   ```

### Phase 3 — Django / WC3 (day 1)

```bash
# On GEEKOM
sudo apt install python3.12 python3.12-venv python3-pip git nodejs npm

# Clone and set up
mkdir -p ~/Documents/CommerceExpert
git clone <wc3-repo> ~/Documents/CommerceExpert/webClerk3
cd ~/Documents/CommerceExpert/webClerk3
python3 -m venv venv && source venv/bin/activate
pip install -r requirements.txt

# Update settings.py — database HOST stays localhost (PG is on this machine)
python manage.py migrate
python manage.py runserver 0.0.0.0:8000
```

Test from MacBook: `http://geekom:8000`

### Phase 4 — React dev servers (day 1)

```bash
git clone <react-joint-repo> ~/Documents/CommerceExpert/react-joint
cd ~/Documents/CommerceExpert/react-joint
npm install
npm run dev -- --host 0.0.0.0
```

**Note:** If you're not actively developing frontend on the MacBook, consider serving
built static files instead of running 4 Vite HMR servers:
```bash
npm run build
npx serve dist -l 5173   # lighter than Vite dev server
```

Test from MacBook: `http://geekom:5173`

### Phase 5 — MeshMobility (day 1-2)

```bash
git clone <meshmobility-repo> ~/Documents/MeshMobility
cd ~/Documents/MeshMobility
python3 -m venv venv && source venv/bin/activate
pip install -r requirements.txt
python3 api.py   # or however it starts — binds to 0.0.0.0:5000
```

Test from MacBook: `http://geekom:5000`

### Phase 6 — Chroma vector stores (day 2)

```bash
pip install chromadb

# Copy vector store data from MacBook
scp -r ~/Allie/.chroma_db_claude bill@geekom:~/chroma_stores/
scp -r ~/Allie/.chroma_db_noelle bill@geekom:~/chroma_stores/

# Start Chroma in HTTP server mode (so MacBook MCP servers can connect)
chroma run --path ~/chroma_stores --host 0.0.0.0 --port 8100
```

Test from MacBook:
```bash
curl http://geekom:8100/api/v1/heartbeat
```

Update MCP server configs on MacBook to use `http://geekom:8100` as Chroma endpoint.

### Phase 7 — Credential migration (day 2)

WC3 on the GEEKOM needs database credentials and possibly API keys.

```bash
# Transfer via Lexar — NEVER over network unencrypted
# On MacBook
cp ~/Allie/config/wc_credentials.json /Volumes/ALLIE_LEXAR/credentials/

# Move Lexar to GEEKOM
# On GEEKOM
cp /media/bill/ALLIE_LEXAR/credentials/wc_credentials.json ~/config/
rm /media/bill/ALLIE_LEXAR/credentials/wc_credentials.json
```

### Phase 8 — Systemd services (day 2)

Make everything auto-start on boot. Create systemd unit files:

```bash
# /etc/systemd/system/wc3-django.service
[Unit]
Description=WebClerk3 Django
After=postgresql.service

[Service]
User=bill
WorkingDirectory=/home/bill/Documents/CommerceExpert/webClerk3
ExecStart=/home/bill/Documents/CommerceExpert/webClerk3/venv/bin/python manage.py runserver 0.0.0.0:8000
Restart=always

[Install]
WantedBy=multi-user.target
```

```bash
# /etc/systemd/system/wc3-react.service
[Unit]
Description=WebClerk3 React

[Service]
User=bill
WorkingDirectory=/home/bill/Documents/CommerceExpert/react-joint
ExecStart=/usr/bin/npx serve dist -l 5173
Restart=always

[Install]
WantedBy=multi-user.target
```

```bash
# /etc/systemd/system/meshmobility.service
[Unit]
Description=MeshMobility

[Service]
User=bill
WorkingDirectory=/home/bill/Documents/MeshMobility
ExecStart=/home/bill/Documents/MeshMobility/venv/bin/python api.py
Restart=always

[Install]
WantedBy=multi-user.target
```

```bash
# /etc/systemd/system/chroma.service
[Unit]
Description=Chroma Vector Store

[Service]
User=bill
ExecStart=/home/bill/.local/bin/chroma run --path /home/bill/chroma_stores --host 0.0.0.0 --port 8100
Restart=always

[Install]
WantedBy=multi-user.target
```

Enable all:
```bash
sudo systemctl enable --now wc3-django wc3-react meshmobility chroma
```

### Phase 9 — Firewall (day 2)

```bash
sudo apt install ufw
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow from 192.168.1.0/24 to any port 22     # SSH
sudo ufw allow from 192.168.1.0/24 to any port 5432   # PostgreSQL
sudo ufw allow from 192.168.1.0/24 to any port 8000   # Django
sudo ufw allow from 192.168.1.0/24 to any port 5173   # React
sudo ufw allow from 192.168.1.0/24 to any port 5000   # MeshMobility
sudo ufw allow from 192.168.1.0/24 to any port 8100   # Chroma
sudo ufw allow from 192.168.1.0/24 to any port 2049   # NFS
sudo ufw enable
```

### Phase 10 — MacBook cutover (day 2-3)

1. **Update MCP configs** — point commerce-db, alice, noelle to GEEKOM endpoints

2. **Update allie-sync.sh** — the 5TB is now on the GEEKOM, not local USB-C:
   ```bash
   # Old: rsync to /Volumes/Allie/
   # New: rsync to bill@geekom:/mnt/allie5tb/
   ```

3. **Capture pipeline** — `_allie_capture()` still writes to `~/Allie/process/inbox/`
   on the MacBook. This stays local — Allie's working copy is on the MacBook. No change.

4. **Stop local services on MacBook**
   ```bash
   brew services stop postgresql@16
   # Keep PostgreSQL data as backup for 1 week
   ```

5. **Verify checklist**
   - [ ] `psql -h geekom -d commerce_expert` works from MacBook
   - [ ] `http://geekom:8000` serves WC3
   - [ ] `http://geekom:5173` serves React
   - [ ] `http://geekom:5000` runs MeshMobility simulations
   - [ ] `curl http://geekom:8100/api/v1/heartbeat` returns OK
   - [ ] `/Volumes/Allie/` mounts via NFS on MacBook
   - [ ] MCP servers connect to GEEKOM backends
   - [ ] Close MacBook lid → services on GEEKOM stay up
   - [ ] Reboot GEEKOM → all services auto-restart

---

## Backup Architecture (hybrid)

| Copy | Location | How it stays current |
|------|----------|---------------------|
| **Working** | `~/Allie/` on MacBook | Source of truth for Allie intelligence |
| **5TB** | `/mnt/allie5tb/` on GEEKOM (USB-C) | `allie-sync.sh` over network from MacBook |
| **iCloud** | iCloud Drive | launchd agent on MacBook, auto 60s after change |
| **allie-core** | GitHub | git push from MacBook |

The three-copy model stays intact. The 5TB moves from "sometimes mounted on MacBook"
to "always mounted on GEEKOM, NFS-shared to MacBook." The MacBook remains the primary
Allie working copy — the GEEKOM is storage + services, not intelligence.

---

## Allie Nightly Jobs

These stay on the MacBook (they need Ollama for LLM inference):
- `allie-reflect.py` — nightly synthesis
- `allie-whatif.py` — Monday morning WhatIf posts
- `allie-harvest-processors.py` — session file processing
- iCloud sync agent

**MacBook sleep concern:** These jobs miss runs when the lid is closed. Bridge options:
1. `caffeinate -s` in a terminal before bed
2. `sudo pmset repeat wakeorpoweron MTWRFSU 03:00:00` — wake at 3 AM for cron jobs
3. Accept it — nightly jobs run next time the lid opens, catch up is fine

Future option: when/if a Mac Mini replaces the MacBook as Allie's LLM host, the
nightly jobs move to the Mini and never miss again.

---

## Future: Mac Mini M4 Pro Upgrade Path

If/when a Mac Mini M4 Pro (48GB) becomes available, it replaces the MacBook as
Allie's LLM home. The GEEKOM stays as the application server:

```
Mac Mini M4 Pro    →  Ollama, allie-reflect, allie-whatif, iCloud sync
GEEKOM IT15      →  PostgreSQL, Django, React, MeshMobility, Chroma, 5TB
MacBook Pro         →  Claude Code, SketchUp, browser (pure workstation)
```

This is the three-machine endgame. Each machine does what it's best at.
The GEEKOM purchase is not a stepping stone — it's permanent infrastructure.

---

## Alternatives Considered

### Mac Mini M4 Pro 48GB (all-in-one)

**Verdict:** Best single-machine solution but 10-12 week lead time (est. late September).
$1,799. Would run everything on one box. Still a valid future addition — see upgrade
path above.

### Mac Mini M4 base 32GB

**Verdict:** Available now but undersized. 32GB tight for LLM + services. Memory
bandwidth (120 GB/s vs M4 Pro's 273 GB/s) means Allie thinks at half speed permanently.
If bought now, becomes redundant when M4 Pro arrives. Rejected 2026-07-16.

### GEEKOM IT15 as sole Allie host

**Verdict:** 32GB too tight for Ollama 20b + all services. OS mismatch (Windows or
Linux) loses iCloud sync and requires full infrastructure rewrite. AMD CPU-only
inference dramatically slower than Apple Silicon unified memory. Rejected as sole
host 2026-07-16. **Accepted as application server in hybrid split.**

### Intel MacBook Pro 16GB

**Verdict:** 16GB can't run 20b model. Thermal throttling under sustained load.
Setup/teardown cost for temporary use not worthwhile. Better donated to a student
or kept as backup boot drive. Rejected 2026-07-16.

---

## GEEKOM IT15 Specs (ordered 2026-07-16)

```
GEEKOM IT15
├── CPU:      Intel Core Ultra 9 285H (16 cores, 16 threads, up to 5.4 GHz)
├── GPU:      Intel Arc 140T (integrated)
├── NPU:      99 TOPS (not used — Ollama stays on MacBook)
├── Memory:   32GB DDR5-5600 (upgradeable to 128GB)
├── Storage:  1TB NVMe Gen 4 SSD
├── Network:  2.5 GbE Ethernet + WiFi 7 (use Ethernet)
├── USB:      Dual USB4 40Gbps (for 5TB drive)
├── OS:       Ubuntu Server 24.04 LTS (wipe Windows 11 Pro)
├── Size:     117×112×45.5mm (0.46L)
├── Power:    Always-on, headless
└── Price:    ~$900
```
