# 67 — WebClerk.com Deployment on Andi (IT15)

**Created:** 2026-08-01
**Updated:** 2026-08-23 — git-pull deployment model replaces rsync
**Status:** Live

---

## Architecture

```
Internet → Cloudflare (SSL termination) → Andi (192.168.1.114:80 Nginx)
                                            ├── /                → landing page (static HTML)
                                            ├── /assets/css/     → landing CSS/images
                                            ├── /assets/images/  → landing images
                                            ├── /assets/         → React app JS/CSS bundles
                                            ├── /app/            → React SPA (databrowser, Gantt, etc.)
                                            ├── /sort            → Statement Sorter (static HTML)
                                            ├── /ecosystem       → Ecosystem page (static HTML)
                                            ├── /liferequiresenergy → Life Requires Energy (static HTML)
                                            ├── /wcapi/          → Django API (Gunicorn :8000)
                                            ├── /admin/          → Django admin (Gunicorn :8000)
                                            ├── /static/         → Django collected static files
                                            ├── /media/          → Django media uploads
                                            ├── /demo/app/       → Demo React SPA (Gunicorn :8001)
                                            └── advchm.webclerk.com → AdvChm instance (Gunicorn :8002)
```

---

## Deployment Model — Git Pull (established 2026-08-23)

One git clone, three instances. All share the same codebase and venv.
Each instance has its own `.env` file with its own database and port.

```
/opt/andi/apps/WebClerk/              ← git clone of github.com/JPods/WebClerk
├── backend/                          ← Django app (WorkingDirectory for all services)
│   ├── .env                          ← main instance (commerce_expert, port 8000)
│   ├── .env.demo                     ← demo instance (commerce_demo, port 8001)
│   ├── .env.advchm                   ← advchm instance (commerce_advchm, port 8002)
│   ├── venv/                         ← shared Python virtualenv
│   └── staticfiles/                  ← collectstatic output
├── frontend/
│   └── dist → /opt/andi/apps/react2025/dist/   ← symlink to built React
└── landing → /opt/andi/apps/webclerk3/landing/  ← symlink to landing page
```

**Previous model (retired):** rsync from Mac → Andi. Three separate code copies
(`webclerk3/`, `webclerk3-demo/`, `webclerk3-advchm/`), each with its own venv.
The old directories remain on disk as fallback but are not used by services.

---

## Three Instances

| Instance | Port | Database | .env file | Service | Domain |
|----------|------|----------|-----------|---------|--------|
| **Main** | 8000 | commerce_expert | `.env` | webclerk3.service | webclerk.com |
| **Demo** | 8001 | commerce_demo | `.env.demo` | webclerk3-demo.service | webclerk.com/demo/ |
| **AdvChm** | 8002 | commerce_advchm | `.env.advchm` | webclerk3-advchm.service | advchm.webclerk.com |

---

## File Locations on Andi

| What | Path |
|------|------|
| WebClerk git clone | `/opt/andi/apps/WebClerk/` |
| Django backend | `/opt/andi/apps/WebClerk/backend/` |
| Python virtualenv | `/opt/andi/apps/WebClerk/backend/venv/` |
| Main .env | `/opt/andi/apps/WebClerk/backend/.env` |
| Demo .env | `/opt/andi/apps/WebClerk/backend/.env.demo` |
| AdvChm .env | `/opt/andi/apps/WebClerk/backend/.env.advchm` |
| Static files | `/opt/andi/apps/WebClerk/backend/staticfiles/` |
| React dist | `/opt/andi/apps/WebClerk/frontend/dist/` (symlink) |
| Landing page | `/opt/andi/apps/WebClerk/landing/` (symlink) |
| Statement Sorter | `/var/www/webclerk-static/sort/` |
| Ecosystem | `/var/www/webclerk-static/ecosystem/` |
| Life Requires Energy | `/var/www/webclerk-static/liferequiresenergy/` |
| Nginx configs | `/etc/nginx/sites-enabled/webclerk3`, `webclerk3-advchm` |
| Gunicorn logs | `/opt/andi/logs/wc3-access.log`, `wc3-error.log` |
| Demo logs | `/opt/andi/logs/wc3-demo-access.log`, `wc3-demo-error.log` |
| AdvChm logs | `/opt/andi/logs/wc3-advchm-access.log`, `wc3-advchm-error.log` |

---

## Services on Andi

| Service | What | Command |
|---------|------|---------|
| `webclerk3.service` | Gunicorn (Django API) on :8000 | `sudo systemctl restart webclerk3` |
| `webclerk3-demo.service` | Demo Gunicorn on :8001 (commerce_demo DB) | `sudo systemctl restart webclerk3-demo` |
| `webclerk3-advchm.service` | AdvChm Gunicorn on :8002 (commerce_advchm DB) | `sudo systemctl restart webclerk3-advchm` |
| `webclerk3-celery.service` | Celery worker + beat | `sudo systemctl restart webclerk3-celery` |
| `nginx` | Reverse proxy + static files | `sudo systemctl reload nginx` |

---

## Database

| Instance | Database | DB User | Password |
|----------|----------|---------|----------|
| Main | commerce_expert | webclerk | (in .env) |
| Demo | commerce_demo | webclerk_demo | (in .env.demo) |
| AdvChm | commerce_advchm | webclerk_advchm | (in .env.advchm) |

All on PostgreSQL localhost:5432.

---

## Deploy Workflow

### Standard deploy (git pull)

This is the normal deploy. Run from any machine with SSH access to Andi.

```bash
ssh andi@192.168.1.114 "
  cd /opt/andi/apps/WebClerk && git pull origin main &&
  cd backend && source venv/bin/activate &&
  python manage.py collectstatic --noinput &&
  python manage.py migrate &&
  python manage.py athena_sign --sign-all &&
  sudo systemctl restart webclerk3 &&
  sudo systemctl restart webclerk3-celery &&
  sudo systemctl restart webclerk3-demo &&
  sudo systemctl restart webclerk3-advchm &&
  sudo systemctl reload nginx
"
```

### React frontend rebuild (if Node changes were pushed)

```bash
ssh andi@192.168.1.114 "
  cd /opt/andi/apps/WebClerk/frontend &&
  npm install && npm run build
"
```

**Note:** The `dist/` directory is currently a symlink to `/opt/andi/apps/react2025/dist/`.
When you first build from the git clone, remove the symlink and build in place:
```bash
ssh andi@192.168.1.114 "
  rm /opt/andi/apps/WebClerk/frontend/dist &&
  cd /opt/andi/apps/WebClerk/frontend &&
  npm install && npm run build
"
```

### Database sync (Mac → Andi)
```bash
# Dump local
pg_dump -Fc commerce_expert -f /tmp/commerce_expert.dump

# Send to Andi
rsync -avz /tmp/commerce_expert.dump andi@192.168.1.114:/tmp/

# Restore on Andi (drops and recreates)
ssh andi@192.168.1.114 "sudo -u postgres dropdb commerce_expert && \
  sudo -u postgres createdb commerce_expert && \
  sudo -u postgres pg_restore -d commerce_expert /tmp/commerce_expert.dump && \
  sudo -u postgres psql -c 'GRANT ALL PRIVILEGES ON DATABASE commerce_expert TO webclerk' && \
  sudo -u postgres psql -d commerce_expert -c 'GRANT ALL ON ALL TABLES IN SCHEMA public TO webclerk; GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO webclerk;'"
```

### Landing page update
```bash
rsync -avz /Volumes/Allie/webclerk.net/index.html \
  andi@192.168.1.114:/opt/andi/apps/webclerk3/landing/index.html
ssh andi@192.168.1.114 "sudo chmod o+r /opt/andi/apps/webclerk3/landing/index.html"
```

### Static site deploy (e.g. Statement Sorter)
```bash
# Sign if it has Athena protection
python3 ~/Allie/sites/statement_sorter/sign.py

# Rsync to Andi (via /tmp to avoid permission issues)
rsync -avz --exclude='.git' ~/Allie/sites/statement_sorter/ andi@192.168.1.114:/tmp/sort/
ssh andi@192.168.1.114 "sudo cp /tmp/sort/* /var/www/webclerk-static/sort/ && \
  sudo chown -R www-data:www-data /var/www/webclerk-static/sort/"

# Re-sign Athena
ssh andi@192.168.1.114 "cd /opt/andi/apps/WebClerk/backend && source venv/bin/activate && \
  python manage.py athena_sign --sign-all"
```

---

## First-Time Setup on a New Machine

Follow these steps to deploy WebClerk on a fresh Ubuntu/Debian server.

### 1. Prerequisites

```bash
# Install system packages
sudo apt update
sudo apt install -y python3 python3-venv git nginx postgresql redis-server

# Optional: Node.js for building React frontend
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt install -y nodejs
```

### 2. Create directory structure

```bash
sudo mkdir -p /opt/andi/apps /opt/andi/logs
sudo chown -R $USER:$USER /opt/andi
# www-data needs traverse access
sudo chmod o+x /opt/andi
```

### 3. Clone the repository

```bash
cd /opt/andi/apps
git clone https://github.com/JPods/WebClerk.git
```

### 4. Set up Python virtualenv

```bash
cd /opt/andi/apps/WebClerk/backend
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
```

**Python 3.14 note:** pydantic_core requires Rust to build from source.
If `pip install` fails on pydantic_core, either:
- Install Rust: `curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh`
- Or copy a working venv from another machine with the same Python version

### 5. Create the database

```bash
sudo -u postgres createuser webclerk
sudo -u postgres createdb commerce_expert -O webclerk
sudo -u postgres psql -c "ALTER USER webclerk PASSWORD 'your_password_here';"
```

### 6. Configure environment

Create `/opt/andi/apps/WebClerk/backend/.env`:
```
DB_MODE=local
LOCAL_DATABASE_NAME=commerce_expert
LOCAL_DATABASE_USER=webclerk
LOCAL_DATABASE_PASS=your_password_here
LOCAL_DATABASE_HOST=localhost
LOCAL_DATABASE_PORT=5432
DEBUG=False
SECRET_KEY=generate-a-random-key-here
ALLOWED_HOSTS=your-domain.com,localhost
```

For additional instances, create `.env.demo` and `.env.advchm` with different
database names, ports, and credentials.

### 7. Django setup

```bash
cd /opt/andi/apps/WebClerk/backend
source venv/bin/activate
python manage.py migrate
python manage.py collectstatic --noinput
python manage.py createsuperuser
python manage.py athena_sign --sign-all
```

### 8. Build React frontend

```bash
cd /opt/andi/apps/WebClerk/frontend
npm install
npm run build
# dist/ directory is created here
```

### 9. Create systemd services

**Gunicorn** — `/etc/systemd/system/webclerk3.service`:
```ini
[Unit]
Description=WebClerk3 Gunicorn Server
After=network.target postgresql.service redis.service

[Service]
User=andi
Group=andi
WorkingDirectory=/opt/andi/apps/WebClerk/backend
EnvironmentFile=/opt/andi/apps/WebClerk/backend/.env
ExecStart=/opt/andi/apps/WebClerk/backend/venv/bin/gunicorn \
    webclerk3_api.wsgi:application \
    --bind 127.0.0.1:8000 \
    --workers 3 \
    --timeout 120 \
    --access-logfile /opt/andi/logs/wc3-access.log \
    --error-logfile /opt/andi/logs/wc3-error.log
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

**Celery** — `/etc/systemd/system/webclerk3-celery.service`:
```ini
[Unit]
Description=WebClerk3 Celery Worker + Beat
After=network.target postgresql.service redis.service

[Service]
User=andi
Group=andi
WorkingDirectory=/opt/andi/apps/WebClerk/backend
EnvironmentFile=/opt/andi/apps/WebClerk/backend/.env
ExecStart=/opt/andi/apps/WebClerk/backend/venv/bin/python -m celery \
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
```

**Additional instances** — duplicate the Gunicorn service file, changing:
- Service name (e.g., `webclerk3-demo.service`)
- EnvironmentFile (e.g., `.env.demo`)
- Port in `--bind` (e.g., `127.0.0.1:8001`)
- Log file names

### 10. Configure Nginx

Create `/etc/nginx/sites-enabled/webclerk3`:

```nginx
server {
    listen 80;
    server_name your-domain.com;

    # Landing page
    location = / {
        root /opt/andi/apps/WebClerk/landing;
        try_files /index.html =404;
    }

    # React app assets (JS/CSS bundles)
    location /assets/ {
        alias /opt/andi/apps/WebClerk/frontend/dist/assets/;
        expires 30d;
    }

    # Django static + media
    location /static/ {
        alias /opt/andi/apps/WebClerk/backend/staticfiles/;
        expires 30d;
    }
    location /media/ {
        alias /opt/andi/apps/WebClerk/backend/media/;
        expires 7d;
    }

    # API + admin → Gunicorn
    location /wcapi/ {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_read_timeout 120s;
    }
    location /admin/ {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
    }

    # React SPA
    location = /app {
        return 301 /app/;
    }
    location /app/ {
        alias /opt/andi/apps/WebClerk/frontend/dist/;
        try_files $uri $uri/ /app/index.html;
    }

    add_header X-Frame-Options SAMEORIGIN;
    add_header X-Content-Type-Options nosniff;
    client_max_body_size 50M;
}
```

### 11. Start services

```bash
sudo systemctl daemon-reload
sudo systemctl enable webclerk3 webclerk3-celery
sudo systemctl start webclerk3 webclerk3-celery
sudo systemctl reload nginx

# Fix permissions (critical — www-data needs traverse)
sudo chmod o+x /opt/andi
sudo chmod -R o+rX /opt/andi/apps/WebClerk/frontend/dist/
sudo chmod -R o+rX /opt/andi/apps/WebClerk/backend/staticfiles/
```

### 12. Verify

```bash
curl -s -o /dev/null -w "%{http_code}" http://localhost/          # 200 landing
curl -s -o /dev/null -w "%{http_code}" http://localhost/app/      # 200 React
curl -s -o /dev/null -w "%{http_code}" http://localhost/wcapi/_system_info/  # 200 API
curl -s -o /dev/null -w "%{http_code}" http://localhost/admin/    # 302 (login redirect)
curl -s -o /dev/null -w "%{http_code}" http://localhost/static/admin/css/base.css  # 200
```

---

## Key Configuration

### .env on Andi (main instance)
```
DB_MODE=local
LOCAL_DATABASE_NAME=commerce_expert
LOCAL_DATABASE_USER=webclerk
LOCAL_DATABASE_PASS=pinkcoconut637
LOCAL_DATABASE_HOST=localhost
LOCAL_DATABASE_PORT=5432
```

### Django settings — critical for Cloudflare
```python
SECURE_SSL_REDIRECT = not DEBUG
SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")
```

### Nginx — critical for Cloudflare
```nginx
proxy_set_header X-Forwarded-Proto https;  # NOT $scheme — CF→Nginx is HTTP
```

Without these two settings, Django returns 301 redirect loops because it thinks the connection is HTTP.

---

## Known Issues & Scars

### SCAR: rsync --delete destroyed landing page (2026-08-01)
The landing page (`/opt/andi/apps/webclerk3/landing/`) only existed on Andi — never in git, never on Mac. Using `rsync --delete` wiped it. Recovered from 5TB backup at `/Volumes/Allie/webclerk.net/`.

**Rule: NEVER use `rsync --delete` when deploying to Andi.** Always use plain `rsync -avz` without `--delete`.

### SCAR: /opt/andi permissions revert to 700
After service restarts or reboots, `/opt/andi` reverts to `700` (owner-only), blocking www-data from traversing to any file. Fix: tmpfiles.d entry at `/etc/tmpfiles.d/andi-perms.conf` sets it to `701` on boot.

If webclerk.com returns 404:
```bash
ssh andi@192.168.1.114 "sudo chmod o+x /opt/andi"
```

### SCAR: pydantic_core won't build on Python 3.14 without Rust (2026-08-23)
`pip install pydantic_core` fails because no pre-built wheel exists for Python 3.14.
Workaround: copy a working venv from another machine with the same Python version.
Long-term: install Rust compiler on Andi, or wait for wheel availability.

### SCAR: country field data too long for migration (2026-08-23)
Migration `communications.0011` shrinks `country` to `varchar(2)` (ISO alpha-2).
Andi's `locations` table had full names ("United States", "Ecuador", etc.).
Fix: convert to ISO codes before running migration:
```sql
UPDATE locations SET country = 'US' WHERE country IN ('United States', 'USA');
UPDATE locations SET country = 'EC' WHERE country = 'Ecuador';
-- etc.
```

### Cloudflare HTTP→HTTPS
Cloudflare terminates SSL and forwards HTTP to Nginx. Django sees HTTP and tries to redirect to HTTPS (infinite loop). Two settings required:
- `SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")` in Django settings
- `proxy_set_header X-Forwarded-Proto https;` in Nginx (hardcoded, not `$scheme`)

### React assets at /assets/
Landing page and React app both use `/assets/`. Nginx resolves by specificity:
- `/assets/css/` and `/assets/images/` → landing page assets
- `/assets/` (catch-all) → React dist bundles

---

## Athena Integrity System

Athena verifies file integrity every 4 hours via Celery beat.

```bash
# List checkpoints
ssh andi "cd /opt/andi/apps/WebClerk/backend && source venv/bin/activate && python manage.py athena_sign --list"

# Verify now
ssh andi "cd /opt/andi/apps/WebClerk/backend && source venv/bin/activate && python manage.py athena_sign --verify"

# Re-sign all after deploy
ssh andi "cd /opt/andi/apps/WebClerk/backend && source venv/bin/activate && python manage.py athena_sign --sign-all"
```

---

## Verification Checklist

After any deploy, verify all routes:
```bash
curl -s -o /dev/null -w "%{http_code}" https://webclerk.com/          # 200 landing
curl -s -o /dev/null -w "%{http_code}" https://webclerk.com/app/      # 200 React
curl -s -o /dev/null -w "%{http_code}" https://webclerk.com/sort      # 200 Statement Sorter
curl -s -o /dev/null -w "%{http_code}" https://webclerk.com/ecosystem # 200 Ecosystem
curl -s -o /dev/null -w "%{http_code}" https://webclerk.com/assets/css/style.css  # 200 landing CSS
curl -s -o /dev/null -w "%{http_code}" https://webclerk.com/wcapi/_system_info/   # 200 API
curl -s -o /dev/null -w "%{http_code}" https://webclerk.com/demo/app/ # 200 Demo
curl -s -o /dev/null -w "%{http_code}" https://advchm.webclerk.com/app/ # 200 AdvChm
```
