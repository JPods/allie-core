# 67 — WebClerk.com Deployment on Andi (IT15)

**Created:** 2026-08-01
**Status:** Live

---

## Architecture

```
Internet → Cloudflare (SSL termination) → Andi (192.168.1.114:80 Nginx)
                                            ├── /                → landing page (static HTML)
                                            ├── /assets/css/     → landing CSS/images
                                            ├── /assets/images/  → landing images
                                            ├── /assets/         → React app JS/CSS bundles
                                            ├── /app/            → React SPA (DataBrowser, Gantt, etc.)
                                            ├── /sort            → Statement Sorter (static HTML)
                                            ├── /ecosystem       → Ecosystem page (static HTML)
                                            ├── /liferequiresenergy → Life Requires Energy (static HTML)
                                            ├── /wcapi/          → Django API (Gunicorn :8000)
                                            ├── /admin/          → Django admin (Gunicorn :8000)
                                            ├── /static/         → Django collected static files
                                            └── /media/          → Django media uploads
```

---

## File Locations on Andi

| What | Path |
|------|------|
| WC3 Django app | `/opt/andi/apps/webclerk3/` |
| WC3 virtualenv | `/opt/andi/apps/webclerk3/venv/` |
| WC3 .env | `/opt/andi/apps/webclerk3/.env` |
| WC3 static files | `/opt/andi/apps/webclerk3/staticfiles/` |
| Landing page | `/opt/andi/apps/webclerk3/landing/` |
| Landing page source | `/Volumes/Allie/webclerk.net/` |
| React dist | `/opt/andi/apps/react2025/dist/` |
| Statement Sorter | `/var/www/webclerk-static/sort/` |
| Ecosystem | `/var/www/webclerk-static/ecosystem/` |
| Life Requires Energy | `/var/www/webclerk-static/liferequiresenergy/` |
| Nginx config | `/etc/nginx/sites-enabled/webclerk3` |
| Gunicorn logs | `/opt/andi/logs/wc3-access.log`, `wc3-error.log` |
| Celery logs | `/opt/andi/apps/webclerk3/logs/celery.log` |

---

## Services on Andi

| Service | What | Command |
|---------|------|---------|
| `webclerk3.service` | Gunicorn (Django API) on :8000 | `sudo systemctl restart webclerk3` |
| `webclerk3-celery.service` | Celery worker + beat | `sudo systemctl restart webclerk3-celery` |
| `react-wc3.service` | React frontend (dev only) | `sudo systemctl restart react-wc3` |
| `nginx` | Reverse proxy + static files | `sudo systemctl reload nginx` |

---

## Database

- **Database:** `commerce_expert` on PostgreSQL localhost:5432
- **DB user:** `webclerk` (password in `.env`)
- **Source:** pg_dump from Mac's `commerce_expert`, restored on Andi
- **Previous DB:** `wc_jpods` (still exists, not active)

---

## Key Configuration

### .env on Andi
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

## Deploy Workflow

### Full code deploy (Mac → Andi)
```bash
# 1. Sync WC3 code (NEVER use --delete — landing page is Andi-only)
rsync -avz \
  --exclude='.git' --exclude='venv' --exclude='__pycache__' --exclude='*.pyc' \
  --exclude='node_modules' --exclude='.env' --exclude='logs/' --exclude='media/' \
  ~/Documents/CommerceExpert/webClerk3/ \
  andi@192.168.1.114:/opt/andi/apps/webclerk3/

# 2. Sync React dist
rsync -avz --exclude='.git' --exclude='node_modules' \
  ~/Documents/CommerceExpert/React2025/dist/ \
  andi@192.168.1.114:/opt/andi/apps/react2025/dist/

# 3. Fix permissions (www-data needs traverse access)
ssh andi@192.168.1.114 "sudo chmod o+x /opt/andi && \
  sudo chmod -R o+rX /opt/andi/apps/react2025/dist/ && \
  sudo chmod -R o+rX /opt/andi/apps/webclerk3/landing/"

# 4. Collect static files
ssh andi@192.168.1.114 "cd /opt/andi/apps/webclerk3 && source venv/bin/activate && \
  python manage.py collectstatic --noinput"

# 5. Restart services
ssh andi@192.168.1.114 "sudo systemctl daemon-reload && \
  sudo systemctl restart webclerk3 && \
  sudo systemctl restart webclerk3-celery && \
  sudo systemctl reload nginx"

# 6. Re-sign Athena checkpoints
ssh andi@192.168.1.114 "cd /opt/andi/apps/webclerk3 && source venv/bin/activate && \
  python manage.py athena_sign --sign-all"
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

### Static site deploy (e.g. Statement Sorter)
```bash
# Sign if it has Athena protection
python3 ~/Allie/sites/statement_sorter/sign.py

# Rsync to Andi (via /tmp to avoid permission issues)
rsync -avz --exclude='.git' ~/Allie/sites/statement_sorter/ andi@192.168.1.114:/tmp/sort/
ssh andi@192.168.1.114 "sudo cp /tmp/sort/* /var/www/webclerk-static/sort/ && \
  sudo chown -R www-data:www-data /var/www/webclerk-static/sort/"

# Re-sign Athena
ssh andi@192.168.1.114 "cd /opt/andi/apps/webclerk3 && source venv/bin/activate && \
  python manage.py athena_sign --sign-all"
```

### Landing page update
```bash
rsync -avz /Volumes/Allie/webclerk.net/index.html \
  andi@192.168.1.114:/opt/andi/apps/webclerk3/landing/index.html
ssh andi@192.168.1.114 "sudo chmod o+r /opt/andi/apps/webclerk3/landing/index.html"
```

---

## Known Issues & Scars

### SCAR: rsync --delete destroyed landing page (2026-08-01)
The landing page (`/opt/andi/apps/webclerk3/landing/`) only existed on Andi — never in git, never on Mac. Using `rsync --delete` wiped it. Recovered from 5TB backup at `/Volumes/Allie/webclerk.net/`.

**Rule: NEVER use `rsync --delete` when deploying to Andi.** Always use plain `rsync -avz` without `--delete`. Check what exists on remote before syncing.

### SCAR: /opt/andi permissions revert to 700
After service restarts or reboots, `/opt/andi` reverts to `700` (owner-only), blocking www-data from traversing to any file. Fix: tmpfiles.d entry at `/etc/tmpfiles.d/andi-perms.conf` sets it to `701` on boot.

If webclerk.com returns 404:
```bash
ssh andi@192.168.1.114 "sudo chmod o+x /opt/andi"
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
ssh andi "cd /opt/andi/apps/webclerk3 && source venv/bin/activate && python manage.py athena_sign --list"

# Verify now
ssh andi "cd /opt/andi/apps/webclerk3 && source venv/bin/activate && python manage.py athena_sign --verify"

# Add a new file
ssh andi "cd /opt/andi/apps/webclerk3 && source venv/bin/activate && python manage.py athena_sign --add /path/to/file --type static_file"

# Re-sign all after deploy
ssh andi "cd /opt/andi/apps/webclerk3 && source venv/bin/activate && python manage.py athena_sign --sign-all"
```

Manifest stored in Document `ida='athena-manifest'`. Failures write immediate FAULT files to `~/Allie/process/inbox/`.

---

## Verification Checklist

After any deploy, verify all routes:
```bash
curl -s -o /dev/null -w "%{http_code}" https://webclerk.com/          # 200 landing
curl -s -o /dev/null -w "%{http_code}" https://webclerk.com/app/      # 200 React
curl -s -o /dev/null -w "%{http_code}" https://webclerk.com/sort      # 200 Statement Sorter
curl -s -o /dev/null -w "%{http_code}" https://webclerk.com/ecosystem # 200 Ecosystem
curl -s -o /dev/null -w "%{http_code}" https://webclerk.com/assets/css/style.css  # 200 landing CSS
curl -s -o /dev/null -w "%{http_code}" https://webclerk.com/wcapi/    # 401 (auth required = working)
```
