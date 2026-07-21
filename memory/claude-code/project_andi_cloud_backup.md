---
name: Andi Google Cloud backup
description: Set up automated backup of Andi (IT15) to Google Cloud; /opt/andi/ apps, data, configs, PostgreSQL dumps
type: project
---

Set up automated backup of Andi's critical data to Google Cloud.

**What to back up:**
- `/opt/andi/apps/` — application code and configs (.env files)
- `/opt/andi/data/` — network files, overlays
- `/opt/andi/services/chroma/data/` — vector store
- PostgreSQL dumps (all 4 databases: wc_jpods, wc_mobility, wc_demo, wc_carryon)
- `/etc/cloudflared/config.yml` — tunnel config
- `/etc/systemd/system/` — service files
- Ollama models list (not the models themselves — re-pullable)

**What NOT to back up:**
- `venv/` directories — recreatable from requirements.txt
- `node_modules/` — recreatable from package.json
- Logs — ephemeral

**Why:** Andi is the production server. Hardware failure = all services down. Cloud backup enables recovery to new hardware in hours, not days. Also needed for the Andi-as-product model — backup/restore is part of the offering.

**How to apply:** Set up gsutil or rclone with a Google Cloud Storage bucket. Cron job on Andi for nightly incremental backup. PostgreSQL pg_dump before each backup run.
