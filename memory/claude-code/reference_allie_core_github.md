---
name: allie-core GitHub repository
description: Private GitHub repo for Allie's intelligence layer — handoff/, process/, snippets/, wisdom/. Pull at session start to get latest.
type: reference
---

**Repo:** https://github.com/JPods/allie-core.git
**Org:** JPods
**Visibility:** public — WebFetch works from any Claude session without authentication

## What's in it
- `handoff/` — daily allie-reflect, claude-recall, sum files, current handoff.md
- `process/snippets/` — code patterns with When/Why/axiom headers
- `process/inbox/` — TF, DNW, TFTS, WI files
- `readmes/wisdom/` — scars, bill.md, clearance-height, rejected-paths, whatif
- `CLAUDE.md` — the session seed document
- `scripts/allie-reflect.py` — nightly synthesis script

## What's NOT in it
Credentials, config/*.json, logs, archive/, knowledge/ (too large), venv/

## Access patterns

**Local drive mounted (normal):**
```bash
git -C ~/Allie pull origin main
```

**Drive not mounted (fallback — needs public repo):**
```
WebFetch: https://raw.githubusercontent.com/JPods/allie-core/main/handoff/handoff.md
WebFetch: https://raw.githubusercontent.com/JPods/allie-core/main/CLAUDE.md
```

## Auto-push
`allie-reflect.py` pushes `handoff/`, `process/`, `readmes/wisdom/` after every nightly run.
Also pulls `--ff-only` at the start of each run to stay current.
