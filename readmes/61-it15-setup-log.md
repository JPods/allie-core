# 61 — IT15 Setup Log (Andi's First Boot)
**Date:** 2026-07-20 through 2026-07-21
**Hardware:** GEEKOM IT15, Intel Core Ultra 9 285H, 32GB RAM, 100GB SSD
**OS:** Ubuntu 26.04 LTS
**Hostname:** andi

---

## Phase 0 — Hardware and Ubuntu Install

### Problems Encountered and Solutions

| Problem | Root Cause | Solution |
|---------|-----------|----------|
| First monitor showed nothing | Resolution/refresh rate incompatibility (LG monitor) | Used a different monitor |
| Monitor showed Menu/Game Mode/Source overlay | Monitor OSD, not computer output | SOURCE button cycles inputs; but real issue was resolution |
| BIOS key timing impossible | Fast Boot enabled, tiny window | Use Windows Shift+Restart → Use a device |
| `dd` command failed | sudo requires interactive TTY; no progress feedback | **Use balenaEtcher** — proven reliable |
| USB drive not bootable after `dd` | dd never ran (sudo failed silently in automated env) | balenaEtcher to 8GB SD card |
| Forgot login credentials after install | Set during install, not written down | Reinstalled (fast — 15 min with existing USB) |
| Ubuntu installer checkbox wouldn't select | Space bar toggles checkboxes, not Enter | Tab navigates sections, Space toggles, Enter activates buttons |

### Ubuntu Install Steps (What Worked)

1. Download Ubuntu Server 26.04 LTS ISO
2. Flash to USB with **balenaEtcher** (not dd)
3. Boot IT15 into Windows
4. Windows: Start → Power → **hold SHIFT + click Restart**
5. Blue menu → **Use a device** → select USB drive
6. GRUB: **Try or Install Ubuntu Server** → Enter
7. Walk through installer:
   - Language: English
   - Keyboard: US
   - Network: Configure WiFi (SSID + password)
   - Storage: **Use entire disk** (wipes Windows)
   - Username/password: **write it down**
   - **Install OpenSSH server**: YES (Space to toggle)
   - Ubuntu Pro: Skip
   - Featured snaps: Skip all
8. Reboot, remove USB

### Ubuntu Installer Navigation

| Key | Action |
|-----|--------|
| **Tab** | Move between sections/buttons |
| **Space** | Toggle checkbox on/off |
| **Enter** | Activate highlighted button (Done/Continue) |
| **Arrow keys** | Select within a section |

---

## Phase 1 — Base System (SSH, Packages, Firewall)

### SSH Setup

```bash
# From Mac — first connection by IP
ssh andi@192.168.1.122

# Copy SSH key for passwordless access (run from separate Mac terminal, not Claude Code)
ssh-copy-id andi@192.168.1.122

# Add to ~/.ssh/config on Mac
cat >> ~/.ssh/config << 'EOF'
Host andi
  HostName 192.168.1.114
  User andi
EOF

# Enable passwordless sudo on IT15 (required for remote management)
# In SSH session: sudo visudo → add at bottom:
# andi ALL=(ALL) NOPASSWD: ALL
```

### Ethernet Fix

Ubuntu installer configured WiFi but not ethernet DHCP. Fix:

```bash
sudo nano /etc/netplan/00-installer-config.yaml
```

Add `dhcp4: true` under the ethernet interface:

```yaml
network:
  version: 2
  ethernets:
    enp131s0:
      dhcp4: true
      match:
        macaddress: 38:f7:cd:df:d3:b3
      set-name: enp131s0
  wifis:
    wlp132s0f0:
      dhcp4: true
      access-points:
        JPods_5G:
          password: <password>
```

```bash
sudo netplan apply
ip addr show enp131s0  # should show 192.168.1.x
```

**Result:** WiFi at 192.168.1.122, Ethernet at 192.168.1.114

### Package Installation

```bash
sudo apt update && sudo apt upgrade -y

sudo apt install -y \
    postgresql postgresql-contrib \
    redis-server \
    nginx certbot python3-certbot-nginx \
    python3-pip python3-venv \
    git curl ufw \
    libpq-dev python3-dev build-essential cargo rustc
```

**Installed versions:**
- Python 3.14.4
- PostgreSQL 18.4
- Redis 8.0.5
- Nginx 1.28.3
- Git 2.53.0

### Firewall

```bash
sudo ufw allow OpenSSH
sudo ufw allow 'Nginx Full'
sudo ufw allow 5050/tcp    # MeshMobility
echo 'y' | sudo ufw enable
```

### PostgreSQL Databases

```bash
sudo -u postgres createuser --createdb webclerk
sudo -u postgres psql -c "ALTER USER webclerk PASSWORD '<password>';"
sudo -u postgres createdb -O webclerk wc_jpods
sudo -u postgres createdb -O webclerk wc_mobility
sudo -u postgres createdb -O webclerk wc_demo
sudo -u postgres createdb -O webclerk wc_carryon
```

---

## Phase 2 — WC3 Deployment

### Deploy Code

```bash
# From Mac — rsync (not git clone — repo is private)
rsync -avz --exclude='.git' --exclude='node_modules' --exclude='venv' \
    --exclude='__pycache__' --exclude='.env' --exclude='dump.rdb' \
    --exclude='nohup.out' --exclude='*.pyc' --exclude='media/' \
    /Users/williamjames/Documents/CommerceExpert/webClerk3/ \
    andi@192.168.1.114:/var/www/webclerk3/
```

**Gotcha:** First rsync missed files in subdirectories. Had to run twice to get all Python files.

### Python Environment

```bash
cd /var/www/webclerk3
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip

# pydantic_core pinned version won't build on Python 3.14
# Install latest pydantic first (gets compatible pydantic_core)
pip install pydantic

# Then install rest of requirements, skipping pinned pydantic
grep -v -E 'pydantic_core|pydantic==' requirements.txt | pip install -r /dev/stdin

pip install gunicorn
```

**Python 3.14 gotcha:** `pydantic_core==2.23.4` from requirements.txt fails to build (PyO3 max supported version is 3.13). Solution: install latest `pydantic` first (pulls compatible `pydantic_core` 2.46+), then install remaining requirements.

### Environment File

```bash
cat > /var/www/webclerk3/.env << 'EOF'
DB_MODE=local
LOCAL_DATABASE_NAME=wc_jpods
LOCAL_DATABASE_USER=webclerk
LOCAL_DATABASE_PASS=<password>
LOCAL_DATABASE_HOST=localhost
LOCAL_DATABASE_PORT=5432
DJANGO_SETTINGS_MODULE=webclerk3_api.settings
SECRET_KEY=<generated>
DEBUG=False
ALLOWED_HOSTS=*
SECURE_SSL_REDIRECT=False
EOF
```

### Settings.py Changes

Two changes needed for production on local network (no SSL yet):

1. `ALLOWED_HOSTS` — hardcoded in settings.py, changed to read from env:
   ```python
   ALLOWED_HOSTS = config('ALLOWED_HOSTS', default='localhost,127.0.0.1').split(',') if config('ALLOWED_HOSTS', default='') != '*' else ['*']
   ```

2. `SECURE_SSL_REDIRECT` — was `not DEBUG`, changed to read from env:
   ```python
   SECURE_SSL_REDIRECT = config("SECURE_SSL_REDIRECT", default=not DEBUG, cast=bool)
   ```

### Migrate and Collect Static

```bash
source venv/bin/activate
python manage.py migrate
python manage.py collectstatic --noinput
# 179 static files collected
```

### Systemd Services

**Gunicorn** (`/etc/systemd/system/webclerk3.service`):
- User: andi
- Bind: 127.0.0.1:8000
- Workers: 3
- Logs: /var/log/webclerk3/

**Celery** (`/etc/systemd/system/webclerk3-celery.service`):
- Worker + Beat combined
- Concurrency: 2
- Solo pool

### Nginx

`/etc/nginx/sites-available/webclerk3`:
- Listen 80, server_name `_` (any)
- `/static/` → alias to staticfiles/
- `/media/` → alias to media/
- `/*` → proxy_pass to :8000

```bash
sudo ln -sf /etc/nginx/sites-available/webclerk3 /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t && sudo systemctl reload nginx
```

---

## Phase 3 — MeshMobility Deployment

### Directory Structure

MeshMobility runs as a Python package. Needs parent directory:

```
/var/www/mesh_mobility_app/
├── mesh_mobility/          # the package (synced from Mac)
│   ├── __main__.py
│   ├── gui/
│   ├── engine/
│   ├── overlays/
│   ├── venv/
│   └── requirements.txt
├── CrashHarvester/         # data library (synced from Mac)
└── crash_harvester -> CrashHarvester   # symlink (import name differs)
```

```bash
# From Mac
rsync -avz --exclude='.git' --exclude='__pycache__' --exclude='venv' --exclude='*.pyc' --exclude='*.jpd' \
    /Users/williamjames/Documents/08_JPods/03_Technology/00_working_code/mesh_mobility/ \
    andi@192.168.1.114:/var/www/mesh_mobility_app/mesh_mobility/

rsync -avz --exclude='.git' --exclude='__pycache__' --exclude='venv' --exclude='*.pyc' \
    /Users/williamjames/Documents/08_JPods/03_Technology/00_working_code/crash_harvester/ \
    andi@192.168.1.114:/var/www/mesh_mobility_app/CrashHarvester/

# Symlink for import compatibility
ssh andi ln -sf /var/www/mesh_mobility_app/CrashHarvester /var/www/mesh_mobility_app/crash_harvester
```

### Systemd Service

`/etc/systemd/system/meshmobility.service`:
- WorkingDirectory: `/var/www/mesh_mobility_app`
- ExecStart: `venv/bin/python -m mesh_mobility.gui`
- Port: 5050

---

## Andi File Structure (Current State)

```
/var/www/
├── webclerk3/              # WC3 codebase (shared by all instances)
│   ├── .env                # JPods instance config
│   ├── venv/
│   ├── staticfiles/
│   ├── manage.py
│   ├── apps/
│   ├── common/
│   └── webclerk3_api/
├── mesh_mobility_app/      # MeshMobility parent
│   ├── mesh_mobility/      # the package
│   ├── CrashHarvester/     # data library
│   └── crash_harvester -> CrashHarvester
├── wc-jpods/               # (future) per-instance env/static/media
├── wc-mobility/            # (future)
├── wc-demo/                # (future)
└── wc-carryon/             # (future)

/etc/systemd/system/
├── webclerk3.service       # Gunicorn :8000
├── webclerk3-celery.service # Celery worker + beat
└── meshmobility.service    # MeshMobility :5050
```

---

## Still To Do

- [ ] Chroma vector store (Alice + Noelle) on :8100
- [ ] Ollama for Andi's LLM
- [ ] Static IP (DHCP reservation on router)
- [ ] Git init on server for deploy workflow
- [ ] deploy.sh scripts
- [ ] SSL (when DNS is ready)
- [ ] Create superuser in WC3
- [ ] Andi reflection service (andi-reflect.py)
- [ ] Mount 5TB drive
- [ ] Standardize Andi directory structure for replication
