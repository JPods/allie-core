---
name: Site maintenance — link checker + weekly audit
description: allie-linkcheck.py checks all JPods web properties weekly for dead links; creates Alice Actions; runs on IT15
type: project
---

Built 2026-07-22. Script at `~/Allie/scripts/allie-linkcheck.py`.

**What it checks:** 9 sites — meshmobility.com, webclerk.com, jpods.com, 5x5FreeMarket.com, ClimateChangeRootCause.com, betterphysics.com, 10xmakers.com, library.jpods.com, jpods.substack.com

**What it finds:** `<a href>`, `<script src>`, `<img src>`, `onclick window.open()`, `fetch()` API calls. Detects CF Access login walls specifically.

**Flags:** Red = customer-facing broken link. Orange = internal/dev.

**Usage:**
```bash
python3 allie-linkcheck.py              # all sites, stdout
python3 allie-linkcheck.py --site mm    # just meshmobility
python3 allie-linkcheck.py --json       # save to process/inbox/
python3 allie-linkcheck.py --actions    # create WC3 Action records
```

**Schedule:** Alice Action #392, weekly Monday on IT15 via Celery beat.

**Triggered by:** meshmobility.com audit 2026-07-22 found 16 broken links (CF Access wall + dead /videos/* + missing CityTool + missing logo).
