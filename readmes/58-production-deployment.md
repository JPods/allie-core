# 58 — Production Deployment: GEEKOM IT15
**Created:** 2026-07-16
**Status:** Staged — ready to execute when hardware arrives (~2026-07-20)
**Target:** GEEKOM IT15, Ubuntu Server 24.04, always-on

---

## What This Replaces

| Current (MacBook dev) | Production (GEEKOM) |
|----------------------|---------------------|
| `manage.py runserver` | **Gunicorn** behind **Nginx** |
| Django serves static files | **Nginx** serves static files directly |
| HTTP only (localhost) | **HTTPS** via Let's Encrypt (certbot) |
| launchd (macOS) | **systemd** services (Ubuntu) |
| Sleeps when MacBook closes | **Always on** |

---

## Stack

```
Internet
  │
  ▼
┌─────────────────────────────────────────────┐
│  GEEKOM IT15 — Ubuntu Server 24.04          │
│                                              │
│  Nginx (ports 80/443)                        │
│    ├── /static/ → /var/www/webclerk3/static/ │
│    ├── /media/  → /var/www/webclerk3/media/  │
│    └── /*       → proxy_pass :8000 (Gunicorn)│
│                                              │
│  Gunicorn (:8000)                            │
│    └── webclerk3_api.wsgi:application        │
│                                              │
│  Celery worker + beat                        │
│    └── webclerk3_api (Redis broker)          │
│                                              │
│  PostgreSQL (:5432)                          │
│    └── commerce_expert                       │
│                                              │
│  Redis (:6379)                               │
│    └── Celery broker + cache                 │
│                                              │
│  MeshMobility (:5050)                        │
│  Chroma (:8100)                              │
└─────────────────────────────────────────────┘
```

---

## Step 1 — System Setup

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install essentials
sudo apt install -y python3.13 python3.13-venv python3-pip \
    nginx certbot python3-certbot-nginx \
    postgresql postgresql-contrib redis-server \
    git curl ufw

# Firewall
sudo ufw allow OpenSSH
sudo ufw allow 'Nginx Full'
sudo ufw enable
```

---

## Step 2 — PostgreSQL

```bash
sudo -u postgres createuser --createdb webclerk
sudo -u postgres createdb -O webclerk commerce_expert

# Set password
sudo -u postgres psql -c "ALTER USER webclerk PASSWORD 'SET_REAL_PASSWORD';"

# Allow local connections (already default on Ubuntu)
# If needed: edit /etc/postgresql/16/main/pg_hba.conf
```

---

## Step 3 — Deploy WC3

```bash
# Create deployment user (or use your own account)
sudo mkdir -p /var/www/webclerk3
sudo chown $USER:$USER /var/www/webclerk3

# Clone or copy the repo
cd /var/www/webclerk3
git clone <wc3-repo-url> .    # or rsync from MacBook

# Create venv
python3.13 -m venv venv
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt
pip install gunicorn            # if not already in requirements

# Environment file
cat > .env << 'EOF'
DB_MODE=local
DATABASE_URL=postgres://webclerk:SET_REAL_PASSWORD@localhost:5432/commerce_expert
DJANGO_SETTINGS_MODULE=webclerk3_api.settings
SECRET_KEY=GENERATE_A_REAL_SECRET_KEY
DEBUG=False
ALLOWED_HOSTS=webclerk.com,www.webclerk.com,YOUR_DOMAIN
EOF

# Migrate and collect static
python manage.py migrate
python manage.py collectstatic --noinput
# Static files go to STATIC_ROOT (set in settings.py)
```

---

## Step 4 — Gunicorn (systemd service)

```bash
sudo tee /etc/systemd/system/webclerk3.service << 'EOF'
[Unit]
Description=WebClerk3 Gunicorn Server
After=network.target postgresql.service redis.service

[Service]
User=DEPLOY_USER
Group=www-data
WorkingDirectory=/var/www/webclerk3
EnvironmentFile=/var/www/webclerk3/.env
ExecStart=/var/www/webclerk3/venv/bin/gunicorn \
    webclerk3_api.wsgi:application \
    --bind 127.0.0.1:8000 \
    --workers 3 \
    --timeout 120 \
    --access-logfile /var/log/webclerk3/access.log \
    --error-logfile /var/log/webclerk3/error.log
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Create log directory
sudo mkdir -p /var/log/webclerk3
sudo chown DEPLOY_USER:www-data /var/log/webclerk3

# Enable and start
sudo systemctl daemon-reload
sudo systemctl enable webclerk3
sudo systemctl start webclerk3
sudo systemctl status webclerk3
```

---

## Step 5 — Celery (systemd service)

```bash
sudo tee /etc/systemd/system/webclerk3-celery.service << 'EOF'
[Unit]
Description=WebClerk3 Celery Worker + Beat
After=network.target postgresql.service redis.service

[Service]
User=DEPLOY_USER
Group=www-data
WorkingDirectory=/var/www/webclerk3
EnvironmentFile=/var/www/webclerk3/.env
ExecStart=/var/www/webclerk3/venv/bin/python -m celery \
    -A webclerk3_api worker \
    -l info \
    --concurrency=2 \
    -P solo \
    --without-heartbeat \
    -B \
    -s /tmp/celerybeat-webclerk3-schedule
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable webclerk3-celery
sudo systemctl start webclerk3-celery
sudo systemctl status webclerk3-celery
```

---

## Step 6 — Nginx (reverse proxy)

```bash
sudo tee /etc/nginx/sites-available/webclerk3 << 'EOF'
server {
    listen 80;
    server_name webclerk.com www.webclerk.com YOUR_DOMAIN;

    # Static files — served directly by Nginx, not Django
    location /static/ {
        alias /var/www/webclerk3/staticfiles/;
        expires 30d;
        add_header Cache-Control "public, immutable";
    }

    location /media/ {
        alias /var/www/webclerk3/media/;
        expires 7d;
    }

    # Everything else → Gunicorn
    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 120s;
        proxy_connect_timeout 10s;

        # WebSocket support (for Celery Flower, live updates)
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    # Security headers
    add_header X-Frame-Options SAMEORIGIN;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";

    # Max upload size
    client_max_body_size 50M;
}
EOF

# Enable site
sudo ln -s /etc/nginx/sites-available/webclerk3 /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default    # remove default page

# Test and reload
sudo nginx -t
sudo systemctl reload nginx
```

---

## Step 7 — Let's Encrypt SSL (HTTPS)

**Prerequisites:**
- Domain DNS must point to the GEEKOM's public IP
- Port 80 and 443 must be open (router port forwarding)

```bash
# Install certbot (if not already)
sudo apt install -y certbot python3-certbot-nginx

# Obtain certificate — certbot auto-configures Nginx
sudo certbot --nginx -d webclerk.com -d www.webclerk.com

# Follow prompts:
#   - Enter email for renewal notices
#   - Agree to terms
#   - Choose redirect HTTP → HTTPS (recommended)

# Verify auto-renewal is set up
sudo certbot renew --dry-run
```

Certbot automatically:
- Obtains the certificate from Let's Encrypt
- Modifies the Nginx config to add SSL listeners on port 443
- Sets up a systemd timer for auto-renewal (every 12 hours check)
- Redirects HTTP → HTTPS (if you choose that option)

**Certificate renewal is automatic.** Let's Encrypt certs expire every 90 days.
The certbot timer renews them before expiration. Verify the timer:

```bash
sudo systemctl list-timers | grep certbot
# Should show: certbot.timer — runs twice daily
```

**If your domain isn't ready yet**, use the IP address temporarily and add
SSL later when DNS is configured:

```bash
# Skip this step, come back when DNS is ready
# Nginx will serve on port 80 (HTTP) until then
```

---

## Step 8 — MeshMobility (systemd service)

```bash
sudo tee /etc/systemd/system/meshmobility.service << 'EOF'
[Unit]
Description=MeshMobility JPods Network Planner
After=network.target

[Service]
User=DEPLOY_USER
WorkingDirectory=/var/www/mesh_mobility
ExecStart=/var/www/mesh_mobility/venv/bin/python -m mesh_mobility.gui
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable meshmobility
sudo systemctl start meshmobility
```

Add Nginx proxy for MeshMobility if serving publicly (separate server block
or location block under the same domain):

```nginx
location /meshmobility/ {
    proxy_pass http://127.0.0.1:5050/;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
}
```

---

## Step 9 — Chroma Vector Store (systemd service)

```bash
sudo tee /etc/systemd/system/chroma.service << 'EOF'
[Unit]
Description=Chroma Vector Store (Alice + Noelle)
After=network.target

[Service]
User=DEPLOY_USER
ExecStart=/var/www/chroma/venv/bin/chroma run --host 0.0.0.0 --port 8100 --path /var/www/chroma/data
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable chroma
sudo systemctl start chroma
```

---

## Multi-Instance WebClerk — Multiple Businesses on One Server

Each WebClerk instance is a separate database, separate Gunicorn process, separate
systemd service. Same codebase, different data. Nginx routes by domain name.
This is the Desktop Hosting model — each business owns its own store.

### Architecture

```
Internet
  │
  ▼
┌──────────────────────────────────────────────────────────────┐
│  Nginx (ports 80/443)                                        │
│    │                                                          │
│    ├── jpods.webclerk.com    → proxy_pass :8000 (JPods)       │
│    ├── demo.webclerk.com     → proxy_pass :8001 (Demo store)  │
│    └── example.webclerk.com  → proxy_pass :8002 (Example)     │
│                                                               │
│  Gunicorn :8000  ─── DB: wc_jpods                             │
│  Gunicorn :8001  ─── DB: wc_demo                              │
│  Gunicorn :8002  ─── DB: wc_example                           │
│                                                               │
│  Celery worker (one per instance, or shared)                  │
│  PostgreSQL :5432 (all databases)                             │
│  Redis :6379 (shared broker)                                  │
└──────────────────────────────────────────────────────────────┘
```

### Memory budget (3 instances)

| Consumer | Per Instance | × 3 | Notes |
|----------|-------------|------|-------|
| Gunicorn (3 workers) | ~500 MB | 1.5 GB | Shared code pages reduce actual footprint |
| Celery worker | ~200 MB | 600 MB | Can share one worker if traffic is low |
| PostgreSQL DB | ~100 MB | 300 MB | Shared server, separate databases |
| **Total added** | | **~2.4 GB** | Well within 32 GB budget |

### Step 1 — Create databases

```bash
sudo -u postgres psql << 'SQL'
CREATE DATABASE wc_jpods OWNER webclerk;
CREATE DATABASE wc_demo OWNER webclerk;
CREATE DATABASE wc_example OWNER webclerk;
SQL
```

### Step 2 — Create instance directories

Each instance shares the same codebase (git clone or symlink) but has its
own `.env`, static files, and media.

```bash
# Shared codebase
WC3_CODE="/var/www/webclerk3"

# Per-instance config and data
for INSTANCE in jpods demo example; do
    sudo mkdir -p /var/www/wc-$INSTANCE/{staticfiles,media,logs}
    sudo chown -R $USER:www-data /var/www/wc-$INSTANCE
done
```

### Step 3 — Per-instance .env files

```bash
# /var/www/wc-jpods/.env
cat > /var/www/wc-jpods/.env << 'EOF'
DB_MODE=local
DATABASE_URL=postgres://webclerk:PASSWORD@localhost:5432/wc_jpods
DJANGO_SETTINGS_MODULE=webclerk3_api.settings
SECRET_KEY=UNIQUE_SECRET_FOR_JPODS
DEBUG=False
ALLOWED_HOSTS=jpods.webclerk.com
STATIC_ROOT=/var/www/wc-jpods/staticfiles
MEDIA_ROOT=/var/www/wc-jpods/media
INSTANCE_NAME=JPods
EOF

# /var/www/wc-demo/.env
cat > /var/www/wc-demo/.env << 'EOF'
DB_MODE=local
DATABASE_URL=postgres://webclerk:PASSWORD@localhost:5432/wc_demo
DJANGO_SETTINGS_MODULE=webclerk3_api.settings
SECRET_KEY=UNIQUE_SECRET_FOR_DEMO
DEBUG=False
ALLOWED_HOSTS=demo.webclerk.com
STATIC_ROOT=/var/www/wc-demo/staticfiles
MEDIA_ROOT=/var/www/wc-demo/media
INSTANCE_NAME=Demo Store
EOF

# /var/www/wc-example/.env — same pattern
```

### Step 4 — Initialize each instance

```bash
WC3_CODE="/var/www/webclerk3"
source $WC3_CODE/venv/bin/activate

for INSTANCE in jpods demo example; do
    echo "=== Setting up $INSTANCE ==="
    export $(cat /var/www/wc-$INSTANCE/.env | xargs)
    python $WC3_CODE/manage.py migrate
    python $WC3_CODE/manage.py collectstatic --noinput
done
```

### Step 5 — Systemd service per instance

Use a **template service** — one file serves all instances:

```bash
sudo tee /etc/systemd/system/webclerk@.service << 'EOF'
[Unit]
Description=WebClerk3 Gunicorn — %i
After=network.target postgresql.service redis.service

[Service]
User=DEPLOY_USER
Group=www-data
WorkingDirectory=/var/www/webclerk3
EnvironmentFile=/var/www/wc-%i/.env
ExecStart=/var/www/webclerk3/venv/bin/gunicorn \
    webclerk3_api.wsgi:application \
    --bind 127.0.0.1:0 \
    --workers 3 \
    --timeout 120 \
    --access-logfile /var/www/wc-%i/logs/access.log \
    --error-logfile /var/www/wc-%i/logs/error.log
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
```

But each instance needs a fixed port. Override per instance:

```bash
# JPods on :8000
sudo mkdir -p /etc/systemd/system/webclerk@jpods.service.d
sudo tee /etc/systemd/system/webclerk@jpods.service.d/port.conf << 'EOF'
[Service]
ExecStart=
ExecStart=/var/www/webclerk3/venv/bin/gunicorn \
    webclerk3_api.wsgi:application \
    --bind 127.0.0.1:8000 \
    --workers 3 \
    --timeout 120 \
    --access-logfile /var/www/wc-jpods/logs/access.log \
    --error-logfile /var/www/wc-jpods/logs/error.log
EOF

# Demo on :8001
sudo mkdir -p /etc/systemd/system/webclerk@demo.service.d
sudo tee /etc/systemd/system/webclerk@demo.service.d/port.conf << 'EOF'
[Service]
ExecStart=
ExecStart=/var/www/webclerk3/venv/bin/gunicorn \
    webclerk3_api.wsgi:application \
    --bind 127.0.0.1:8001 \
    --workers 3 \
    --timeout 120 \
    --access-logfile /var/www/wc-demo/logs/access.log \
    --error-logfile /var/www/wc-demo/logs/error.log
EOF

# Example on :8002
sudo mkdir -p /etc/systemd/system/webclerk@example.service.d
sudo tee /etc/systemd/system/webclerk@example.service.d/port.conf << 'EOF'
[Service]
ExecStart=
ExecStart=/var/www/webclerk3/venv/bin/gunicorn \
    webclerk3_api.wsgi:application \
    --bind 127.0.0.1:8002 \
    --workers 3 \
    --timeout 120 \
    --access-logfile /var/www/wc-example/logs/access.log \
    --error-logfile /var/www/wc-example/logs/error.log
EOF

# Enable and start all three
sudo systemctl daemon-reload
sudo systemctl enable webclerk@jpods webclerk@demo webclerk@example
sudo systemctl start webclerk@jpods webclerk@demo webclerk@example
```

### Step 6 — Celery per instance (or shared)

For low traffic, one shared Celery worker handles all three (use a queue prefix).
For isolation, use the same template pattern:

```bash
sudo tee /etc/systemd/system/webclerk-celery@.service << 'EOF'
[Unit]
Description=WebClerk3 Celery — %i
After=network.target postgresql.service redis.service

[Service]
User=DEPLOY_USER
Group=www-data
WorkingDirectory=/var/www/webclerk3
EnvironmentFile=/var/www/wc-%i/.env
ExecStart=/var/www/webclerk3/venv/bin/python -m celery \
    -A webclerk3_api worker \
    -l info \
    --concurrency=1 \
    -P solo \
    --without-heartbeat \
    -B \
    -s /tmp/celerybeat-wc-%i-schedule \
    -Q %i
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable webclerk-celery@jpods webclerk-celery@demo webclerk-celery@example
sudo systemctl start webclerk-celery@jpods webclerk-celery@demo webclerk-celery@example
```

### Step 7 — Nginx virtual hosts

Each instance gets its own domain (or subdomain). One Let's Encrypt cert covers all.

```bash
sudo tee /etc/nginx/sites-available/webclerk-multi << 'EOF'
# --- JPods ---
server {
    listen 80;
    server_name jpods.webclerk.com;

    location /static/ {
        alias /var/www/wc-jpods/staticfiles/;
        expires 30d;
    }
    location /media/ {
        alias /var/www/wc-jpods/media/;
    }
    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}

# --- Demo Store ---
server {
    listen 80;
    server_name demo.webclerk.com;

    location /static/ {
        alias /var/www/wc-demo/staticfiles/;
        expires 30d;
    }
    location /media/ {
        alias /var/www/wc-demo/media/;
    }
    location / {
        proxy_pass http://127.0.0.1:8001;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}

# --- Example ---
server {
    listen 80;
    server_name example.webclerk.com;

    location /static/ {
        alias /var/www/wc-example/staticfiles/;
        expires 30d;
    }
    location /media/ {
        alias /var/www/wc-example/media/;
    }
    location / {
        proxy_pass http://127.0.0.1:8002;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

sudo ln -sf /etc/nginx/sites-available/webclerk-multi /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

### Step 8 — SSL for all instances (one certbot command)

```bash
sudo certbot --nginx \
    -d jpods.webclerk.com \
    -d demo.webclerk.com \
    -d example.webclerk.com
```

Certbot adds SSL to all three server blocks automatically. One cert, multiple
subdomains. Auto-renews.

### Adding a new instance

The pattern is repeatable. To add a 4th instance:

1. `CREATE DATABASE wc_newclient OWNER webclerk;`
2. Create `/var/www/wc-newclient/.env` with unique `DATABASE_URL`, `SECRET_KEY`, `ALLOWED_HOSTS`
3. `manage.py migrate` + `collectstatic` with that env
4. Create systemd port override (`webclerk@newclient.service.d/port.conf` on `:8003`)
5. Add Nginx server block for `newclient.webclerk.com → :8003`
6. `certbot --nginx -d newclient.webclerk.com`
7. `systemctl start webclerk@newclient`

**Time to spin up a new instance: ~10 minutes.**

### MeshMobility — Separate Database, Promotion to JPods

MeshMobility (meshmobility.com) will generate high volume — students, city
planners, curious visitors. Mixing these contacts into the JPods commerce
database makes JPods contacts messy and unreliable for sales and capital work.

**Rule: MeshMobility gets its own database. Significant contacts promote to JPods.**

```
meshmobility.com                          jpods.webclerk.com
┌──────────────────┐                     ┌──────────────────┐
│  DB: wc_mobility │                     │  DB: wc_jpods    │
│                  │    promotion rule    │                  │
│  All signups     │ ──────────────────▶  │  Qualified leads │
│  All networks    │    (Alice decides)   │  Capital sources │
│  All simulations │                     │  Vendor contacts │
│  Student kits    │                     │  MOA team        │
└──────────────────┘                     └──────────────────┘
```

**What stays in wc_mobility only:**
- Every signup, every network saved, every simulation run
- Student kit purchases (Alice handles commerce in this DB)
- 10xMakers leaderboard scores
- Casual visitors who try CityTool once

**What promotes to wc_jpods:**
- City planner who runs 5+ simulations or contacts JPods
- University professor who registers a class
- Anyone who requests a quote or franchise information
- Capital source who came through MeshMobility
- Contact who explicitly opts in to JPods communications

**How promotion works:**
Alice watches `wc_mobility` for promotion triggers (activity thresholds,
explicit requests, high-value actions). When triggered, Alice creates a
Contact in `wc_jpods` with `refs.keywords: ["from-meshmobility"]` and a
link back to the original `wc_mobility` contact ID. The original stays in
`wc_mobility` — promotion is a copy, not a move.

**Alice owns this boundary.** No automatic bulk promotion. Alice evaluates
each candidate and Bill can review her promotion queue before activation.
This is the same pattern as the pattern recognition loop: observe → log →
pattern → recommend → Bill activates.

### Port and Domain Assignments (updated)

| Instance | Domain | Port | Database | Purpose |
|----------|--------|------|----------|---------|
| JPods | jpods.webclerk.com | :8000 | wc_jpods | Commerce, Alice, capital |
| MeshMobility | meshmobility.com | :8001 | wc_mobility | Network planner, students, CityTool |
| Demo | demo.webclerk.com | :8002 | wc_demo | "See how WebClerk works" |

### Operations — multi-instance

```bash
# Status of all instances
sudo systemctl status 'webclerk@*'

# Restart one instance
sudo systemctl restart webclerk@demo

# Deploy code update to all instances
cd /var/www/webclerk3
source venv/bin/activate
git pull origin main
pip install -r requirements.txt --quiet
for INSTANCE in jpods demo example; do
    export $(cat /var/www/wc-$INSTANCE/.env | xargs)
    python manage.py migrate --noinput
    python manage.py collectstatic --noinput
done
sudo systemctl restart 'webclerk@*'
sudo systemctl restart 'webclerk-celery@*'

# Logs for specific instance
tail -f /var/www/wc-jpods/logs/access.log
sudo journalctl -u webclerk@demo -f
```

---

## Operations

### Check status of all services

```bash
sudo systemctl status webclerk3
sudo systemctl status webclerk3-celery
sudo systemctl status meshmobility
sudo systemctl status chroma
sudo systemctl status nginx
sudo systemctl status postgresql
sudo systemctl status redis
```

### View logs

```bash
# Gunicorn
sudo journalctl -u webclerk3 -f
tail -f /var/log/webclerk3/access.log
tail -f /var/log/webclerk3/error.log

# Celery
sudo journalctl -u webclerk3-celery -f

# Nginx
tail -f /var/log/nginx/access.log
tail -f /var/log/nginx/error.log
```

### Deploy from Git — Code Updates

Three options, from simplest to most automated:

#### Option A — Manual Deploy (SSH in, pull, restart)

```bash
ssh geekom
cd /var/www/webclerk3
source venv/bin/activate
git pull origin main
pip install -r requirements.txt    # if deps changed
python manage.py migrate           # if models changed
python manage.py collectstatic --noinput
sudo systemctl restart webclerk3
sudo systemctl restart webclerk3-celery
```

#### Option B — One-Command Deploy Script

Create `/var/www/webclerk3/deploy.sh` on the GEEKOM:

```bash
#!/bin/bash
set -e
APP_DIR="/var/www/webclerk3"
cd "$APP_DIR"
source venv/bin/activate

echo "=== Pulling latest ==="
git pull origin main

echo "=== Installing dependencies ==="
pip install -r requirements.txt --quiet

echo "=== Running migrations ==="
python manage.py migrate --noinput

echo "=== Collecting static files ==="
python manage.py collectstatic --noinput

echo "=== Restarting services ==="
sudo systemctl restart webclerk3
sudo systemctl restart webclerk3-celery

echo "=== Verifying ==="
sleep 2
sudo systemctl is-active webclerk3
sudo systemctl is-active webclerk3-celery
echo "Deploy complete: $(git log --oneline -1)"
```

Then from MacBook:
```bash
ssh geekom 'bash /var/www/webclerk3/deploy.sh'
```

Or even simpler — add a shell alias on the MacBook:
```bash
# Add to ~/.zshrc
alias deploy-wc3='ssh geekom "bash /var/www/webclerk3/deploy.sh"'
alias deploy-mm='ssh geekom "bash /var/www/mesh_mobility/deploy.sh"'
```

Then just: `deploy-wc3`

#### Option C — Git Webhook (auto-deploy on push)

A lightweight webhook listener on the GEEKOM that triggers `deploy.sh`
whenever a push hits the main branch. No polling — instant deploy.

Create `/var/www/deploy-webhook.py` on the GEEKOM:

```python
#!/usr/bin/env python3
"""Lightweight Git webhook receiver — triggers deploy on push to main."""
from http.server import HTTPServer, BaseHTTPRequestHandler
import json
import subprocess
import hmac
import hashlib
import os

WEBHOOK_SECRET = os.environ.get('WEBHOOK_SECRET', 'SET_A_REAL_SECRET')
DEPLOY_SCRIPTS = {
    'webclerk3': '/var/www/webclerk3/deploy.sh',
    'mesh_mobility': '/var/www/mesh_mobility/deploy.sh',
    'allie-core': '/var/www/allie-core/deploy.sh',
}

class WebhookHandler(BaseHTTPRequestHandler):
    def do_POST(self):
        content_length = int(self.headers.get('Content-Length', 0))
        body = self.rfile.read(content_length)

        # Verify signature (GitHub/Gitea format)
        sig_header = self.headers.get('X-Hub-Signature-256', '')
        expected = 'sha256=' + hmac.new(
            WEBHOOK_SECRET.encode(), body, hashlib.sha256
        ).hexdigest()
        if not hmac.compare_digest(sig_header, expected):
            self.send_response(403)
            self.end_headers()
            self.wfile.write(b'Bad signature')
            return

        payload = json.loads(body)
        repo = payload.get('repository', {}).get('name', '')
        ref = payload.get('ref', '')

        if ref == 'refs/heads/main' and repo in DEPLOY_SCRIPTS:
            script = DEPLOY_SCRIPTS[repo]
            print(f"Deploying {repo} from main...")
            subprocess.Popen(['bash', script],
                             stdout=open(f'/var/log/{repo}-deploy.log', 'a'),
                             stderr=subprocess.STDOUT)
            self.send_response(200)
            self.end_headers()
            self.wfile.write(f'Deploying {repo}'.encode())
        else:
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b'Ignored (not main or unknown repo)')

    def log_message(self, format, *args):
        pass  # suppress default logging

if __name__ == '__main__':
    server = HTTPServer(('127.0.0.1', 9000), WebhookHandler)
    print("Webhook listener on :9000")
    server.serve_forever()
```

Systemd service for the webhook:
```bash
sudo tee /etc/systemd/system/deploy-webhook.service << 'EOF'
[Unit]
Description=Git Deploy Webhook Listener
After=network.target

[Service]
User=DEPLOY_USER
Environment=WEBHOOK_SECRET=SET_A_REAL_SECRET
ExecStart=/var/www/webclerk3/venv/bin/python3 /var/www/deploy-webhook.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable deploy-webhook
sudo systemctl start deploy-webhook
```

Nginx route for the webhook (add to existing server block):
```nginx
location /deploy-webhook {
    proxy_pass http://127.0.0.1:9000;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Hub-Signature-256 $http_x_hub_signature_256;
}
```

Then configure GitHub/Gitea webhook:
- URL: `https://webclerk.com/deploy-webhook`
- Secret: same as `WEBHOOK_SECRET`
- Events: Push only
- Branch filter: `main`

**Recommended path:** Start with **Option B** (one-command deploy). Move to
**Option C** (webhook) when you're pushing frequently and want zero-touch deploys.

### Deploy for each project

Each project gets its own `deploy.sh` with the same pattern:

| Project | Deploy script | Systemd services to restart |
|---------|--------------|----------------------------|
| WC3 | `/var/www/webclerk3/deploy.sh` | `webclerk3`, `webclerk3-celery` |
| MeshMobility | `/var/www/mesh_mobility/deploy.sh` | `meshmobility` |
| allie-core | `/var/www/allie-core/deploy.sh` | none (file sync only) |

### MacBook aliases (add to ~/.zshrc)

```bash
alias deploy-wc3='ssh geekom "bash /var/www/webclerk3/deploy.sh"'
alias deploy-mm='ssh geekom "bash /var/www/mesh_mobility/deploy.sh"'
alias deploy-allie='ssh geekom "cd /var/www/allie-core && git pull origin main"'
alias geekom='ssh geekom'
```

### SSL certificate status

```bash
sudo certbot certificates
# Shows: expiry date, domains, certificate path

sudo certbot renew --dry-run
# Tests renewal without actually renewing
```

---

## Django Settings Changes for Production

In `webclerk3_api/settings.py` (or via environment variables):

```python
# MUST change for production
DEBUG = False
ALLOWED_HOSTS = ['webclerk.com', 'www.webclerk.com', 'YOUR_DOMAIN']
SECRET_KEY = os.environ.get('SECRET_KEY')  # never hardcode

# Static files — Nginx serves these
STATIC_URL = '/static/'
STATIC_ROOT = BASE_DIR / 'staticfiles'    # collectstatic target

# Security — enable with HTTPS
SECURE_SSL_REDIRECT = True
SESSION_COOKIE_SECURE = True
CSRF_COOKIE_SECURE = True
SECURE_HSTS_SECONDS = 31536000
SECURE_HSTS_INCLUDE_SUBDOMAINS = True

# Trust Nginx proxy headers
SECURE_PROXY_SSL_HEADER = ('HTTP_X_FORWARDED_PROTO', 'https')
```

---

## Mapping: macOS → Ubuntu

| macOS (current) | Ubuntu (GEEKOM) |
|-----------------|-----------------|
| `launchctl load/unload` | `systemctl enable/start/stop` |
| `~/Library/LaunchAgents/*.plist` | `/etc/systemd/system/*.service` |
| `brew install` | `apt install` |
| `runserver.sh` | systemd service (always on) |
| Homebrew Python 3.13 | `apt install python3.13` or deadsnakes PPA |
| `manage.py runserver` | Gunicorn (3 workers) |
| Chrome DevTools MCP | Not needed on server |
| iCloud sync | Not applicable |

---

## Cross-Instance Sync — Connection + Bundle

Multiple WC3 instances on the same server talk to each other through the
existing Connection + Bundle sync infrastructure (`apps/sync`). This is
also the model for how MyCarryOn moves identity between databases.

### The Principle

```
uuid   = the person (universal, travels between databases)
id     = the local record (unique per database, never leaves)
bundle = the exchange event (audited, never deleted)
```

A contact exists in `wc_mobility` with `uuid=abc-123, id=47`. When Alice
promotes them to `wc_jpods`, a new record is created with `uuid=abc-123, id=312`.
Same person, different local IDs. The Bundle records the promotion — what was
copied, when, why.

This is exactly how MyCarryOn works. A traveler's CarryOn carries their `uuid`.
Each system they interact with creates a local record with a local `id`. The
`uuid` is the thread that connects them all.

### Connection Records (one per instance pair)

```
wc_mobility  ←→  wc_jpods     Connection: "mobility-to-jpods"
wc_mobility  ←→  wc_demo      Connection: "mobility-to-demo" (if needed)
wc_jpods     ←→  mycarryon    Connection: "jpods-mycarryon"
```

Each Connection defines:
- **connection.key** — unique identifier for this relationship
- **maps** — which fields sync, which transform
- **rules** — what promotes, what stays local, who decides
- **conflicts** — resolution strategy (most recent wins, source wins, etc.)

### Example: mobility-to-jpods Connection

```json
{
  "name": "mobility-to-jpods",
  "type": "internal",
  "purpose": "sync",
  "status": "active",
  "config": {
    "source_db": "wc_mobility",
    "target_db": "wc_jpods",
    "connection_key": "mob-jpods-2026"
  },
  "maps": {
    "contact": {
      "uuid": "uuid",
      "name": "name",
      "email": "email",
      "refs.keywords": "merge:['from-meshmobility']"
    }
  },
  "rules": {
    "promotion_triggers": [
      "simulation_count >= 5",
      "kit_purchase = true",
      "class_registration = true",
      "franchise_inquiry = true",
      "capital_inquiry = true",
      "explicit_opt_in = true"
    ],
    "auto_promote": false,
    "requires_approval": "alice_recommends_bill_activates",
    "never_sync": ["password", "session_tokens"]
  },
  "conflicts": {
    "strategy": "target_wins",
    "tie_break": "most_recent"
  }
}
```

### Bundle Record (one per promotion event)

When Alice promotes a contact from `wc_mobility` to `wc_jpods`:

```json
{
  "connection_key": "mob-jpods-2026",
  "direction": "push",
  "status": "success",
  "payload": {
    "model": "contact",
    "source_id": 47,
    "source_uuid": "abc-123-def",
    "fields": {
      "name": "Jane Chen",
      "email": "jchen@cityofaustin.gov",
      "refs": {"keywords": ["from-meshmobility", "city-planner"]}
    },
    "promotion_reason": "simulation_count=12, franchise_inquiry=true"
  },
  "response": {
    "target_id": 312,
    "target_uuid": "abc-123-def",
    "created": true
  }
}
```

The `uuid` is the same in both databases. The `id` is local to each.
The Bundle is the audit record of the exchange.

### MyCarryOn on the IT15

MyCarryOn is a WC3 instance — same codebase, its own database, its own domain.

| Instance | Domain | Port | Database | Purpose |
|----------|--------|------|----------|---------|
| JPods | jpods.webclerk.com | :8000 | wc_jpods | Commerce, Alice, capital |
| MeshMobility | meshmobility.com | :8001 | wc_mobility | Network planner, students |
| Demo | demo.webclerk.com | :8002 | wc_demo | "See how WebClerk works" |
| **MyCarryOn** | **mycarryon.io** | **:8003** | **wc_carryon** | **Portable identity** |

MyCarryOn is the identity broker. When a person creates a CarryOn:

1. They get a `uuid` and a record in `wc_carryon`
2. When they use MeshMobility, a local record is created in `wc_mobility`
   with the same `uuid`
3. When they buy JPods tickets at MOA, a local record is created in `wc_jpods`
   with the same `uuid`
4. Each system only sees its own local data. The person controls what travels
   via their CarryOn — enumerated permissions, not blanket access.

```
                    MyCarryOn (wc_carryon)
                    uuid: abc-123-def
                    owner: Jane Chen
                    permissions:
                      - jpods: [name, email, ride_history]
                      - meshmobility: [name, networks_saved]
                      - demo: [none]
                           │
              ┌────────────┼────────────┐
              ▼            ▼            ▼
         wc_jpods     wc_mobility   wc_demo
         id: 312      id: 47        (no record)
         uuid: abc    uuid: abc
         local data   local data
```

**The sovereignty rule:** The person owns their CarryOn. Systems get enumerated,
revocable permissions — never the whole record. A system that loses permission
keeps its local `id` and any data it already has (audit trail), but cannot pull
new data from MyCarryOn.

### MyCarryOn — Phase 1 vs Phase 2

**Phase 1 (IT15 launch):** MyCarryOn runs as a WC3 instance. This lets us
build and test the Connection + Bundle sync, the uuid flow, and the
permission model using infrastructure we already have.

**Phase 2 (transition):** MyCarryOn moves to a lightweight system that lives
on the person's phone and personal computer. The WC3 instance becomes a
relay/broker, not the store of record. The person's device is the source of
truth.

#### Phase 2 Architecture — Data Fades to Metadata

The sovereignty principle means the person's data lives on *their* device.
WebClerk instances hold data only long enough to complete a transaction,
then it fades to metadata.

```
Person's Device (phone/laptop)          WebClerk Instance (wc_jpods)
┌──────────────────────────┐           ┌──────────────────────────┐
│  CarryOn (source of truth)│          │  Contact record:         │
│                           │          │    uuid: abc-123         │
│  identity, preferences,  │          │    id: 312               │
│  permissions, history,   │  sync    │    name: Jane Chen ←─ fades
│  ride records, networks  │◄────────►│    email: jchen@... ←─ fades
│                           │          │    refs.keywords: [...]  │
│  Full data. Always.      │          │    metadata.last_seen: dt │
│                           │          │    metadata.carryon: true │
└──────────────────────────┘          │                          │
                                       │  After ~7 days:          │
                                       │    name: null            │
                                       │    email: null           │
                                       │    metadata.faded: true  │
                                       │    metadata.uuid: abc-123│
                                       │    (uuid stays forever)  │
                                       └──────────────────────────┘
```

**What fades (after ~7 days in WebClerk):**
- Name, email, phone, address — personal identifiers
- Session data, preferences, communication history
- Any field the person hasn't explicitly granted persistent access to

**What stays forever in WebClerk:**
- `transaction_uuid` — a **new uuid per transaction**, not the person's uuid.
  The person's `carryon_uuid` is encrypted inside a blockchain record of the
  transaction. Reconnecting the transaction to the person requires decrypting
  the blockchain record — which requires significant legal effort (court order,
  key holder cooperation). The business cannot casually look up "all transactions
  by Jane Chen." Jane can, because she holds her key.
- `refs.keywords`, `refs.categories` — anonymized classification
- Transaction metadata — amounts, dates, item IDs (not who bought them)
- Aggregate counts — how many rides, how many simulations
- Bundle audit records — what was exchanged, when (but payload fades too)

**What never leaves the person's device:**
- Full identity and contact details
- Permission grants and revocations
- Complete history and preferences
- Credential pointers
- The `apis.blocked` refusal list

**How reconnection works:**
When the person returns (scans QR, taps NFC, opens the app), their device
presents their `carryon_uuid`. WebClerk does NOT look up old transactions —
it can't, because previous transactions used different `transaction_uuid`s
and the `carryon_uuid` is encrypted inside blockchain records. Instead,
WebClerk creates a fresh local record for this new interaction. The person's
device pushes only what's needed for the current transaction. It fades again
after the interaction ends. The person controls every push.

The person CAN reconnect their own history — their device holds their key
and can decrypt their own blockchain records. The business cannot do this
without a court order and key holder cooperation. This is the asymmetry
that makes it sovereign: the person sees their full history, the business
sees only the current transaction.

**The usufruct boundary:** WebClerk has usufruct over the data during the
transaction — use it to serve the person, then return it. "Return" means
fading the PII while keeping the metadata the business needs for accounting,
aggregate reporting, and reconnection.

#### Phase 2 Tech Stack (future — not built yet)

| Component | Where | What |
|-----------|-------|------|
| **CarryOn app** | Phone (PWA or native) | Stores identity, manages permissions, presents uuid |
| **CarryOn file** | Phone + laptop (synced) | `carryon.json` — the full record |
| **Relay endpoint** | IT15 WC3 instance | Accepts uuid, receives pushed fields, fades after TTL |
| **Fade worker** | Celery beat task | Nightly: null PII fields where `last_seen > 7 days` |

The fade worker is a Celery beat task — simple:

```python
# Pseudocode — runs nightly via Celery beat
from django.utils import timezone
from datetime import timedelta

FADE_AFTER = timedelta(days=7)
FADE_FIELDS = ['name', 'email', 'phone', 'address']

def fade_stale_contacts():
    cutoff = timezone.now() - FADE_AFTER
    stale = Contact.objects.filter(
        metadata__carryon=True,
        metadata__faded__isnull=True,
        metadata__last_seen__lt=cutoff,
    )
    for contact in stale:
        for field in FADE_FIELDS:
            setattr(contact, field, None)
        contact.metadata['faded'] = True
        contact.metadata['faded_at'] = timezone.now().isoformat()
        contact.save()
```

#### Advertising and Privacy — Non-Negotiable Rules

**JPods never advertises to people. JPods never invades privacy.**

This is not a policy choice — it is a design constraint. The system is built
so that advertising cannot happen without the person's active, continuous
consent.

**The opt-in model:**
Each JPods vehicle has an onboard computer. If — and only if — the rider
chooses, they can use that computer to indicate where they are going and
what they are interested in. This is the rider volunteering information,
not the system extracting it.

**How advertising credits work:**
- The rider elects to see advertising. Nobody pushes it.
- Credits for watching advertising go **to the rider**, not to JPods.
- The JPods network receives a **5% support fee** on advertising revenue —
  but only if the advertising model passes privacy review.
- If any advertising mechanism leads to privacy violations, the 5% fee
  is forfeited. The network does not profit from privacy failures.

**What this means for the system design:**
- No tracking of rider behavior for advertising purposes. Ever.
- No selling of rider data. Ever.
- No "personalized" advertising based on ride history, unless the rider
  explicitly opts in on that specific ride.
- Opt-in is per-ride, not permanent. Closing the screen revokes consent.
- The rider's CarryOn never shares data with advertisers. The onboard
  computer is a separate channel the rider controls.

**Revenue flows:**
```
Advertiser pays to show ad
  → 95% goes to the rider (credit against fare or cash)
  → 5% goes to the JPods network (support fee)
  → 0% goes to data brokers, platforms, or intermediaries
```

**The privacy review:**
Before any advertising capability ships, the entire flow must pass a
privacy review that verifies:
1. No rider data leaves the vehicle computer without per-ride opt-in
2. No ride history is used for ad targeting unless rider volunteers it
3. The 5% network fee is forfeited if any privacy violation is found
4. The review is documented and repeated annually
5. Riders can see exactly what data was shared and with whom (their
   CarryOn holds this record, not JPods)

**This is the usufruct principle applied to attention:** The rider's attention
is theirs. If they lend it to an advertiser, the fruit (revenue) goes to
the rider. JPods provides the infrastructure but does not harvest the crop.

**We build Phase 1 now. Phase 2 is designed, documented, and ready to build
when the CarryOn app exists.**

### MyCarryOn systemd setup (Phase 1)

Same pattern as other instances:

```bash
# Database
sudo -u postgres createdb -O webclerk wc_carryon

# Environment
cat > /var/www/wc-carryon/.env << 'EOF'
DB_MODE=local
DATABASE_URL=postgres://webclerk:PASSWORD@localhost:5432/wc_carryon
DJANGO_SETTINGS_MODULE=webclerk3_api.settings
SECRET_KEY=UNIQUE_SECRET_FOR_CARRYON
DEBUG=False
ALLOWED_HOSTS=mycarryon.io,www.mycarryon.io
STATIC_ROOT=/var/www/wc-carryon/staticfiles
MEDIA_ROOT=/var/www/wc-carryon/media
INSTANCE_NAME=MyCarryOn
EOF

# Port override (:8003)
sudo mkdir -p /etc/systemd/system/webclerk@carryon.service.d
sudo tee /etc/systemd/system/webclerk@carryon.service.d/port.conf << 'EOF'
[Service]
ExecStart=
ExecStart=/var/www/webclerk3/venv/bin/gunicorn \
    webclerk3_api.wsgi:application \
    --bind 127.0.0.1:8003 \
    --workers 3 \
    --timeout 120 \
    --access-logfile /var/www/wc-carryon/logs/access.log \
    --error-logfile /var/www/wc-carryon/logs/error.log
EOF

# Nginx + SSL
# Add server block for mycarryon.io → :8003
# certbot --nginx -d mycarryon.io -d www.mycarryon.io

sudo systemctl enable webclerk@carryon
sudo systemctl start webclerk@carryon
```

### Connection Records to Create on Day One

| Connection Key | From | To | Type | Purpose |
|---------------|------|-----|------|---------|
| `mob-jpods-2026` | wc_mobility | wc_jpods | internal | Alice promotes qualified leads |
| `carryon-jpods` | wc_carryon | wc_jpods | sync | CarryOn ↔ JPods identity bridge |
| `carryon-mobility` | wc_carryon | wc_mobility | sync | CarryOn ↔ MeshMobility identity bridge |
| `sheets-jpods` | Google Sheets | wc_jpods | api | MOA-2026 task sync (allie-sheets-sync.py) |

---

## Checklist

### Phase 1 — Base Infrastructure
- [ ] GEEKOM arrives and Ubuntu Server 24.04 installed
- [ ] SSH key auth from MacBook (`ssh geekom` works)
- [ ] PostgreSQL installed and running
- [ ] Redis installed and running
- [ ] Firewall (ufw) — SSH + HTTP + HTTPS only
- [ ] Python 3.13 via deadsnakes PPA

### Phase 2 — First Instance (JPods)
- [ ] WC3 repo deployed to `/var/www/webclerk3/`
- [ ] venv created on Python 3.13, requirements installed
- [ ] Database `wc_jpods` created, `.env` configured
- [ ] `migrate` and `collectstatic` run
- [ ] Gunicorn systemd service running (`webclerk@jpods`)
- [ ] Celery systemd service running (`webclerk-celery@jpods`)
- [ ] Nginx reverse proxy for jpods.webclerk.com
- [ ] DNS pointing to GEEKOM public IP (or Cloudflare tunnel)
- [ ] Let's Encrypt certificate via certbot
- [ ] Auto-renewal verified (`certbot renew --dry-run`)
- [ ] `deploy.sh` script working from MacBook

### Phase 3 — Additional Instances
- [ ] Database `wc_mobility` created
- [ ] MeshMobility WC3 instance on :8001 (`webclerk@mobility`)
- [ ] Nginx + SSL for meshmobility.com
- [ ] MeshMobility GUI on :5050 (systemd service)
- [ ] Database `wc_demo` created
- [ ] Demo WC3 instance on :8002 (`webclerk@demo`)
- [ ] Nginx + SSL for demo.webclerk.com
- [ ] Database `wc_carryon` created
- [ ] MyCarryOn WC3 instance on :8003 (`webclerk@carryon`)
- [ ] Nginx + SSL for mycarryon.io

### Phase 4 — Cross-Instance Sync
- [ ] Connection record: `mob-jpods-2026` (MeshMobility → JPods promotion)
- [ ] Connection record: `carryon-jpods` (MyCarryOn ↔ JPods)
- [ ] Connection record: `carryon-mobility` (MyCarryOn ↔ MeshMobility)
- [ ] Connection record: `sheets-jpods` (Google Sheets ↔ JPods)
- [ ] Alice promotion rules tested (wc_mobility → wc_jpods)
- [ ] MyCarryOn uuid flow tested (create → use in mobility → use in jpods)

### Phase 5 — Supporting Services
- [ ] Chroma systemd service running (Alice + Noelle vector stores)
- [ ] CrashHarvester API available
- [ ] MacBook MCP servers updated to point at GEEKOM (DB host, Chroma URL)
- [ ] Webhook deploy listener (Option C — when ready)
