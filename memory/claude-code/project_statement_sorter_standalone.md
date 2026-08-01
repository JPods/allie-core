---
name: Statement Sorter — standalone free tool
description: One-file Python app + pure client-side HTML version for sorting bank statements into business/personal; free WebClerk lead generator
type: project
---

Two versions built 2026-08-01:

**Python standalone** (`~/Allie/sites/statement_sorter/sort.py`):
- One file, zero dependencies, Python 3.10+
- `python3 sort.py ~/Taxes/2025/` — harvests folder, opens browser at localhost
- Built-in web server, dark theme, select/bulk classify, export CSV/JSON
- Saves to `_working.json` in the source folder
- Supports: WF CC, WF checking, USAA, Wise, GoDaddy, generic CSV

**Pure client-side HTML** (`~/Allie/sites/statement_sorter/index.html`):
- Single HTML file, zero server, zero uploads
- Data never leaves the browser — runs entirely client-side
- localStorage persistence, custom categories saved
- Drag-drop files/folders, pagination (200/page), all 6 bank parsers in JS
- Deploy as static file on webclerk.com/sort for free lead generation

**Free service strategy:** Top of funnel for WebClerk. Users sort statements for free, see "Powered by WebClerk", realize the full platform exists. Upgrade path: Alice auto-classifies, GL integration, merchant learning.

**Why:** Bill: "People will love you for this feature. What you have made possible in minutes normally requires days at tax time."

**How to apply:** Deploy index.html to webclerk.com/sort or sort.webclerk.com. No infrastructure cost — static file on Cloudflare.
