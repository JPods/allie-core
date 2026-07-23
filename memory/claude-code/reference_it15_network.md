---
name: IT15 network and deployment paths
description: IT15 (Andi) IP address, file paths, deployment commands, Cloudflare tunnel config
type: reference
---

**IT15 IP:** 192.168.1.114 (was 192.168.4.69 on old network)
**SSH:** `ssh andi@192.168.1.114`
**User:** andi

**File paths on IT15:**
- MeshMobility: `/opt/andi/apps/mesh_mobility/`
- MeshMobility static: `/opt/andi/apps/mesh_mobility/gui/static/`
- WebClerk3: `/opt/andi/apps/webclerk3/`
- WC3 landing: `/opt/andi/apps/webclerk3/landing/`
- WC3 staticfiles: `/opt/andi/apps/webclerk3/staticfiles/`
- Logs: `/opt/andi/logs/`
- Cloudflared config: `/etc/cloudflared/config.yml`
- Nginx config: `/etc/nginx/sites-enabled/default`

**Cloudflare tunnel ingress:**
- webclerk.com → localhost:80 (Nginx)
- *.webclerk.com → localhost:80
- meshmobility.com → localhost:5050 (Flask direct)
- *.meshmobility.com → localhost:5050
- jpods.us → localhost:80

**Deployment (MeshMobility):**
```bash
rsync -avz mesh_mobility/gui/static/ andi@192.168.1.114:/opt/andi/apps/mesh_mobility/gui/static/
rsync -avz mesh_mobility/gui/*.py andi@192.168.1.114:/opt/andi/apps/mesh_mobility/gui/
ssh andi@192.168.1.114 "sudo systemctl restart meshmobility"
```

**Services:**
- meshmobility.service — Flask/Gunicorn on :5050
- webclerk3.service — Django/Gunicorn on :8000
- cloudflared.service — CF tunnel
- nginx — port 80 (serves WC3 landing + proxies to Django/React)

**Nginx note:** `/opt/andi` must be 755 (not 700) or www-data can't traverse to serve files.
